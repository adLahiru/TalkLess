#pragma once

#include <cstdint>
#include <memory>
#include <vector>

/**
 * @brief Noise suppression level options
 *
 * These map to different processing behaviors. RNNoise provides consistent
 * high-quality noise suppression, but we can adjust post-processing gain
 * to achieve different effective suppression levels.
 */
enum class NoiseSuppressionLevel {
    Off = 0,      // No noise suppression
    Low = 1,      // Light suppression (preserve more ambient sound)
    Moderate = 2, // Moderate suppression (balanced)
    High = 3,     // Strong suppression
    VeryHigh = 4  // Maximum suppression (aggressive)
};

/**
 * @brief NoiseSuppressor wraps RNNoise for real-time noise cancellation
 *
 * This class provides a simple interface for processing audio with RNNoise's
 * AI-based noise suppression, removing background noise from microphone input.
 *
 * RNNoise is a recurrent neural network-based noise suppressor that provides
 * high-quality noise removal with low computational cost.
 *
 * Note: RNNoise operates at 48kHz with a fixed frame size of 480 samples (10ms).
 * Audio at different sample rates will be resampled internally.
 *
 * Usage:
 *   1. Create instance with sample rate and desired suppression level
 *   2. Call process() on audio frames in your audio callback
 *   3. Adjust suppression level at runtime if needed
 */
class NoiseSuppressor
{
public:
    /**
     * @brief Construct a NoiseSuppressor
     * @param sampleRate Audio sample rate (will be resampled to 48kHz internally)
     * @param level Initial noise suppression level
     */
    explicit NoiseSuppressor(int sampleRate = 48000, NoiseSuppressionLevel level = NoiseSuppressionLevel::Moderate);
    ~NoiseSuppressor();

    // Non-copyable
    NoiseSuppressor(const NoiseSuppressor&) = delete;
    NoiseSuppressor& operator=(const NoiseSuppressor&) = delete;

    // Movable
    NoiseSuppressor(NoiseSuppressor&&) noexcept;
    NoiseSuppressor& operator=(NoiseSuppressor&&) noexcept;

    /**
     * @brief Initialize the noise suppressor
     * @return true if initialization succeeded
     */
    bool init();

    /**
     * @brief Check if the suppressor is initialized and ready
     */
    bool isInitialized() const { return m_initialized; }

    /**
     * @brief Process audio samples in-place with noise suppression
     * @param samples Pointer to mono float audio samples (modified in-place)
     * @param frameCount Number of samples to process
     *
     * Note: RNNoise processes in fixed frame sizes of 480 samples at 48kHz.
     * Larger frames will be processed in chunks internally.
     */
    void process(float* samples, int frameCount);

    /**
     * @brief Set the noise suppression level
     * @param level New suppression level
     */
    void setSuppressionLevel(NoiseSuppressionLevel level);

    /**
     * @brief Get the current noise suppression level
     */
    NoiseSuppressionLevel getSuppressionLevel() const { return m_level; }

    /**
     * @brief Check if noise suppression is enabled (level != Off)
     */
    bool isEnabled() const { return m_level != NoiseSuppressionLevel::Off; }

    /**
     * @brief Enable or disable noise suppression
     * @param enabled If false, sets level to Off; if true, restores previous level
     */
    void setEnabled(bool enabled);

    /**
     * @brief Get the sample rate
     */
    int getSampleRate() const { return m_sampleRate; }

    /**
     * @brief Reinitialize with a new sample rate
     * @param sampleRate New sample rate
     * @return true if reinitialization succeeded
     */
    bool setSampleRate(int sampleRate);

    /**
     * @brief Get the last VAD (Voice Activity Detection) probability
     * @return Probability between 0.0 and 1.0 that voice is present
     */
    float getLastVadProbability() const { return m_lastVadProbability; }

private:
    int m_sampleRate;
    NoiseSuppressionLevel m_level;
    NoiseSuppressionLevel m_previousLevel; // For enable/disable toggling
    bool m_initialized = false;

    // RNNoise frame size (fixed at 480 samples for 48kHz = 10ms)
    static constexpr int RNNOISE_FRAME_SIZE = 480;
    static constexpr int RNNOISE_SAMPLE_RATE = 48000;

    // Last VAD probability from RNNoise
    float m_lastVadProbability = 0.0f;

    // Attenuation factor based on suppression level
    float m_attenuationFactor = 1.0f;

    // Private implementation (pimpl) to hide RNNoise dependencies
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
