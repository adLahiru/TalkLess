#include "noiseSuppressor.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <iostream>
#include <vector>

#if TALKLESS_HAS_RNNOISE

    // RNNoise header
    #include <rnnoise.h>

// Implementation struct containing RNNoise state
struct NoiseSuppressor::Impl
{
    DenoiseState* denoiseState = nullptr;

    // Buffer for RNNoise processing (480 samples at 48kHz)
    std::vector<float> rnnoiseBuffer;

    // Resampling buffers (for non-48kHz audio)
    std::vector<float> resampleInputBuffer;
    std::vector<float> resampleOutputBuffer;

    // Leftover samples from previous process() call
    std::vector<float> leftoverSamples;

    ~Impl()
    {
        if (denoiseState) {
            rnnoise_destroy(denoiseState);
            denoiseState = nullptr;
        }
    }
};

NoiseSuppressor::NoiseSuppressor(int sampleRate, NoiseSuppressionLevel level)
    : m_sampleRate(sampleRate), m_level(level), m_previousLevel(level), m_impl(std::make_unique<Impl>())
{
    // Update attenuation factor based on level
    setSuppressionLevel(level);
}

NoiseSuppressor::~NoiseSuppressor() = default;

NoiseSuppressor::NoiseSuppressor(NoiseSuppressor&&) noexcept = default;
NoiseSuppressor& NoiseSuppressor::operator=(NoiseSuppressor&&) noexcept = default;

bool NoiseSuppressor::init()
{
    if (m_initialized) {
        return true;
    }

    try {
        // Destroy existing state if any
        if (m_impl->denoiseState) {
            rnnoise_destroy(m_impl->denoiseState);
            m_impl->denoiseState = nullptr;
        }

        // Create RNNoise state (uses default model)
        m_impl->denoiseState = rnnoise_create(nullptr);
        if (!m_impl->denoiseState) {
            std::cerr << "[NoiseSuppressor] Failed to create RNNoise state\n";
            return false;
        }

        // Allocate buffer for RNNoise (fixed 480 samples)
        m_impl->rnnoiseBuffer.resize(RNNOISE_FRAME_SIZE);

        // Allocate resampling buffers if needed
        if (m_sampleRate != RNNOISE_SAMPLE_RATE) {
            // Calculate max buffer size needed for resampling
            // For simplicity, we'll use a generous buffer
            int maxFrames = (RNNOISE_FRAME_SIZE * m_sampleRate) / RNNOISE_SAMPLE_RATE + 16;
            m_impl->resampleInputBuffer.resize(maxFrames);
            m_impl->resampleOutputBuffer.resize(maxFrames);
        }

        m_impl->leftoverSamples.clear();

        m_initialized = true;
        std::cout << "[NoiseSuppressor] RNNoise initialized with sample rate " << m_sampleRate << ", level "
                  << static_cast<int>(m_level) << "\n";
        return true;

    } catch (const std::exception& e) {
        std::cerr << "[NoiseSuppressor] Exception during init: " << e.what() << "\n";
        return false;
    }
}

// Simple linear resampling helper
static void resampleLinear(const float* input, int inputLen, float* output, int outputLen)
{
    if (inputLen <= 0 || outputLen <= 0)
        return;

    float ratio = static_cast<float>(inputLen - 1) / static_cast<float>(outputLen - 1);
    for (int i = 0; i < outputLen; ++i) {
        float srcIdx = i * ratio;
        int idx0 = static_cast<int>(srcIdx);
        int idx1 = std::min(idx0 + 1, inputLen - 1);
        float frac = srcIdx - idx0;
        output[i] = input[idx0] * (1.0f - frac) + input[idx1] * frac;
    }
}

void NoiseSuppressor::process(float* samples, int frameCount)
{
    if (!m_initialized || !m_impl->denoiseState || m_level == NoiseSuppressionLevel::Off) {
        return; // Pass through unchanged
    }

    // RNNoise expects audio at 48kHz
    // If our sample rate is different, we need to resample

    if (m_sampleRate == RNNOISE_SAMPLE_RATE) {
        // Direct processing at 48kHz
        // Combine leftover samples with new samples
        std::vector<float> combinedSamples;
        combinedSamples.reserve(m_impl->leftoverSamples.size() + frameCount);
        combinedSamples.insert(combinedSamples.end(), m_impl->leftoverSamples.begin(), m_impl->leftoverSamples.end());
        combinedSamples.insert(combinedSamples.end(), samples, samples + frameCount);

        int totalSamples = static_cast<int>(combinedSamples.size());
        int processedSamples = 0;
        int outputIdx = 0;

        // Process complete frames
        while (processedSamples + RNNOISE_FRAME_SIZE <= totalSamples) {
            // Copy to RNNoise buffer (RNNoise expects values in range [-32768, 32767])
            for (int i = 0; i < RNNOISE_FRAME_SIZE; ++i) {
                m_impl->rnnoiseBuffer[i] = combinedSamples[processedSamples + i] * 32767.0f;
            }

            // Process with RNNoise
            float vad =
                rnnoise_process_frame(m_impl->denoiseState, m_impl->rnnoiseBuffer.data(), m_impl->rnnoiseBuffer.data());
            m_lastVadProbability = vad;

            // Apply attenuation based on suppression level and copy back
            // The attenuation factor adjusts how aggressively we suppress
            for (int i = 0; i < RNNOISE_FRAME_SIZE; ++i) {
                float processed = m_impl->rnnoiseBuffer[i] / 32767.0f;

                // Blend between original and processed based on attenuation
                float original = combinedSamples[processedSamples + i];
                combinedSamples[processedSamples + i] =
                    processed * m_attenuationFactor + original * (1.0f - m_attenuationFactor);
            }

            processedSamples += RNNOISE_FRAME_SIZE;
        }

        // Copy processed samples back to output (only the new samples, not leftovers)
        int leftoverCount = static_cast<int>(m_impl->leftoverSamples.size());
        int outputCount = std::min(frameCount, static_cast<int>(combinedSamples.size()) - leftoverCount);
        for (int i = 0; i < outputCount; ++i) {
            samples[i] = combinedSamples[leftoverCount + i];
        }

        // Save leftover samples for next call
        m_impl->leftoverSamples.clear();
        if (processedSamples < totalSamples) {
            // Keep unprocessed samples as leftovers
            int remainingNew = totalSamples - processedSamples;
            // But only keep what came from the new input
            int newLeftovers = std::max(0, remainingNew - leftoverCount);
            if (newLeftovers > 0) {
                m_impl->leftoverSamples.insert(m_impl->leftoverSamples.end(),
                                               combinedSamples.begin() + processedSamples, combinedSamples.end());
            }
        }

    } else {
        // Need to resample to 48kHz, process, then resample back
        // Calculate equivalent frame count at 48kHz
        int frames48k = (frameCount * RNNOISE_SAMPLE_RATE) / m_sampleRate;

        if (frames48k < RNNOISE_FRAME_SIZE) {
            // Not enough samples for a full RNNoise frame
            // Just pass through for now (could accumulate for better handling)
            return;
        }

        // Ensure buffers are large enough
        if (m_impl->resampleInputBuffer.size() < static_cast<size_t>(frames48k)) {
            m_impl->resampleInputBuffer.resize(frames48k);
        }
        if (m_impl->resampleOutputBuffer.size() < static_cast<size_t>(frames48k)) {
            m_impl->resampleOutputBuffer.resize(frames48k);
        }

        // Upsample to 48kHz
        resampleLinear(samples, frameCount, m_impl->resampleInputBuffer.data(), frames48k);

        // Process at 48kHz
        int processed = 0;
        while (processed + RNNOISE_FRAME_SIZE <= frames48k) {
            // Copy to RNNoise buffer
            for (int i = 0; i < RNNOISE_FRAME_SIZE; ++i) {
                m_impl->rnnoiseBuffer[i] = m_impl->resampleInputBuffer[processed + i] * 32767.0f;
            }

            // Process
            float vad =
                rnnoise_process_frame(m_impl->denoiseState, m_impl->rnnoiseBuffer.data(), m_impl->rnnoiseBuffer.data());
            m_lastVadProbability = vad;

            // Copy back with attenuation
            for (int i = 0; i < RNNOISE_FRAME_SIZE; ++i) {
                float processedSample = m_impl->rnnoiseBuffer[i] / 32767.0f;
                float original = m_impl->resampleInputBuffer[processed + i];
                m_impl->resampleOutputBuffer[processed + i] =
                    processedSample * m_attenuationFactor + original * (1.0f - m_attenuationFactor);
            }

            processed += RNNOISE_FRAME_SIZE;
        }

        // Copy remaining unprocessed samples
        for (int i = processed; i < frames48k; ++i) {
            m_impl->resampleOutputBuffer[i] = m_impl->resampleInputBuffer[i];
        }

        // Downsample back to original sample rate
        resampleLinear(m_impl->resampleOutputBuffer.data(), frames48k, samples, frameCount);
    }
}

void NoiseSuppressor::setSuppressionLevel(NoiseSuppressionLevel level)
{
    if (m_level == level)
        return;

    m_level = level;
    if (level != NoiseSuppressionLevel::Off) {
        m_previousLevel = level;
    }

    // Set attenuation factor based on level
    // Higher attenuation = more noise suppression effect
    switch (level) {
    case NoiseSuppressionLevel::Off:
        m_attenuationFactor = 0.0f; // No processing
        break;
    case NoiseSuppressionLevel::Low:
        m_attenuationFactor = 0.5f; // 50% RNNoise + 50% original
        break;
    case NoiseSuppressionLevel::Moderate:
        m_attenuationFactor = 0.75f; // 75% RNNoise
        break;
    case NoiseSuppressionLevel::High:
        m_attenuationFactor = 0.9f; // 90% RNNoise
        break;
    case NoiseSuppressionLevel::VeryHigh:
        m_attenuationFactor = 1.0f; // 100% RNNoise (full suppression)
        break;
    }

    std::cout << "[NoiseSuppressor] Level set to " << static_cast<int>(level)
              << " (attenuation: " << m_attenuationFactor << ")\n";
}

void NoiseSuppressor::setEnabled(bool enabled)
{
    if (enabled) {
        if (m_level == NoiseSuppressionLevel::Off) {
            setSuppressionLevel(m_previousLevel != NoiseSuppressionLevel::Off ? m_previousLevel
                                                                              : NoiseSuppressionLevel::Moderate);
        }
    } else {
        if (m_level != NoiseSuppressionLevel::Off) {
            m_previousLevel = m_level;
            setSuppressionLevel(NoiseSuppressionLevel::Off);
        }
    }
}

bool NoiseSuppressor::setSampleRate(int sampleRate)
{
    if (sampleRate == m_sampleRate && m_initialized) {
        return true;
    }

    m_sampleRate = sampleRate;
    m_initialized = false;

    return init();
}

#else // TALKLESS_HAS_RNNOISE not defined

// Stub implementation when RNNoise is not available
// The noise suppressor becomes a pass-through

struct NoiseSuppressor::Impl
{
    // Empty implementation
};

NoiseSuppressor::NoiseSuppressor(int sampleRate, NoiseSuppressionLevel level)
    : m_sampleRate(sampleRate), m_level(level), m_previousLevel(level), m_impl(nullptr)
{}

NoiseSuppressor::~NoiseSuppressor() = default;
NoiseSuppressor::NoiseSuppressor(NoiseSuppressor&&) noexcept = default;
NoiseSuppressor& NoiseSuppressor::operator=(NoiseSuppressor&&) noexcept = default;

bool NoiseSuppressor::init()
{
    std::cout << "[NoiseSuppressor] RNNoise not available - noise suppression disabled\n";
    m_initialized = true; // Mark as "initialized" so it passes through
    return true;
}

void NoiseSuppressor::process(float* /*samples*/, int /*frameCount*/)
{
    // Pass-through: no processing when RNNoise is not available
}

void NoiseSuppressor::setSuppressionLevel(NoiseSuppressionLevel level)
{
    m_level = level;
    if (level != NoiseSuppressionLevel::Off) {
        m_previousLevel = level;
    }
}

void NoiseSuppressor::setEnabled(bool enabled)
{
    if (enabled) {
        m_level = m_previousLevel != NoiseSuppressionLevel::Off ? m_previousLevel : NoiseSuppressionLevel::Moderate;
    } else {
        m_previousLevel = m_level;
        m_level = NoiseSuppressionLevel::Off;
    }
}

bool NoiseSuppressor::setSampleRate(int sampleRate)
{
    m_sampleRate = sampleRate;
    return true;
}

#endif // TALKLESS_HAS_RNNOISE
