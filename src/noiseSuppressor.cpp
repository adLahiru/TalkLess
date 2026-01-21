#include "noiseSuppressor.h"

#include <algorithm>
#include <cstring>
#include <iostream>

#if TALKLESS_HAS_SPEEXDSP

// SpeexDSP headers
#include <speex/speex_preprocess.h>

// Implementation struct containing SpeexDSP preprocessor state
struct NoiseSuppressor::Impl {
    SpeexPreprocessState* preprocessState = nullptr;
    std::vector<spx_int16_t> int16Buffer;  // SpeexDSP works with int16
    std::vector<float> processingBuffer;
    
    ~Impl() {
        if (preprocessState) {
            speex_preprocess_state_destroy(preprocessState);
            preprocessState = nullptr;
        }
    }
    
    void updateNoiseLevel(NoiseSuppressionLevel level) {
        if (!preprocessState)
            return;
        
        int denoise = (level != NoiseSuppressionLevel::Off) ? 1 : 0;
        speex_preprocess_ctl(preprocessState, SPEEX_PREPROCESS_SET_DENOISE, &denoise);
        
        if (denoise) {
            // Set noise suppression level in dB (negative values)
            int noiseSuppress = 0;
            switch (level) {
            case NoiseSuppressionLevel::Low:
                noiseSuppress = -15;
                break;
            case NoiseSuppressionLevel::Moderate:
                noiseSuppress = -30;
                break;
            case NoiseSuppressionLevel::High:
                noiseSuppress = -45;
                break;
            case NoiseSuppressionLevel::VeryHigh:
                noiseSuppress = -60;
                break;
            default:
                noiseSuppress = -30;
                break;
            }
            speex_preprocess_ctl(preprocessState, SPEEX_PREPROCESS_SET_NOISE_SUPPRESS, &noiseSuppress);
        }
    }
};

NoiseSuppressor::NoiseSuppressor(int sampleRate, NoiseSuppressionLevel level)
    : m_sampleRate(sampleRate), m_level(level), m_previousLevel(level), m_impl(std::make_unique<Impl>())
{
    // Frame size is 20ms worth of samples (SpeexDSP standard)
    m_frameSize = m_sampleRate / 50; // 20ms
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
        if (m_impl->preprocessState) {
            speex_preprocess_state_destroy(m_impl->preprocessState);
        }
        
        // Create preprocessor state
        m_impl->preprocessState = speex_preprocess_state_init(m_frameSize, m_sampleRate);
        if (!m_impl->preprocessState) {
            std::cerr << "[NoiseSuppressor] Failed to create SpeexDSP preprocessor state\n";
            return false;
        }

        // Allocate buffers
        m_impl->int16Buffer.resize(m_frameSize);
        m_impl->processingBuffer.resize(m_frameSize);
        
        // Configure noise suppression
        m_impl->updateNoiseLevel(m_level);

        m_initialized = true;
        std::cout << "[NoiseSuppressor] SpeexDSP initialized with sample rate " << m_sampleRate
                  << ", frame size " << m_frameSize << ", level " << static_cast<int>(m_level) << "\n";
        return true;

    } catch (const std::exception& e) {
        std::cerr << "[NoiseSuppressor] Exception during init: " << e.what() << "\n";
        return false;
    }
}

void NoiseSuppressor::process(float* samples, int frameCount)
{
    if (!m_initialized || !m_impl->preprocessState || m_level == NoiseSuppressionLevel::Off) {
        return; // Pass through unchanged
    }

    // Process in chunks of m_frameSize (20ms)
    int processed = 0;
    while (processed < frameCount) {
        int chunkSize = std::min(m_frameSize, frameCount - processed);

        // Convert float to int16 (SpeexDSP uses int16)
        for (int i = 0; i < chunkSize; ++i) {
            float sample = samples[processed + i];
            // Clamp and convert to int16
            sample = std::max(-1.0f, std::min(1.0f, sample));
            m_impl->int16Buffer[i] = static_cast<spx_int16_t>(sample * 32767.0f);
        }
        
        // Pad with zeros if partial chunk
        for (int i = chunkSize; i < m_frameSize; ++i) {
            m_impl->int16Buffer[i] = 0;
        }

        // Run the preprocessor (noise suppression)
        speex_preprocess_run(m_impl->preprocessState, m_impl->int16Buffer.data());

        // Convert back to float
        for (int i = 0; i < chunkSize; ++i) {
            samples[processed + i] = static_cast<float>(m_impl->int16Buffer[i]) / 32767.0f;
        }

        processed += chunkSize;
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

    if (m_initialized && m_impl) {
        m_impl->updateNoiseLevel(level);
    }

    std::cout << "[NoiseSuppressor] Level set to " << static_cast<int>(level) << "\n";
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
    m_frameSize = m_sampleRate / 50; // 20ms
    m_initialized = false;

    return init();
}

#else // TALKLESS_HAS_SPEEXDSP not defined

// Stub implementation when SpeexDSP is not available
// The noise suppressor becomes a pass-through

struct NoiseSuppressor::Impl {
    // Empty implementation
};

NoiseSuppressor::NoiseSuppressor(int sampleRate, NoiseSuppressionLevel level)
    : m_sampleRate(sampleRate), m_level(level), m_previousLevel(level), m_impl(nullptr)
{
    m_frameSize = m_sampleRate / 50;
}

NoiseSuppressor::~NoiseSuppressor() = default;
NoiseSuppressor::NoiseSuppressor(NoiseSuppressor&&) noexcept = default;
NoiseSuppressor& NoiseSuppressor::operator=(NoiseSuppressor&&) noexcept = default;

bool NoiseSuppressor::init()
{
    std::cout << "[NoiseSuppressor] SpeexDSP not available - noise suppression disabled\n";
    m_initialized = true; // Mark as "initialized" so it passes through
    return true;
}

void NoiseSuppressor::process(float* /*samples*/, int /*frameCount*/)
{
    // Pass-through: no processing when SpeexDSP is not available
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
    m_frameSize = m_sampleRate / 50;
    return true;
}

#endif // TALKLESS_HAS_SPEEXDSP
