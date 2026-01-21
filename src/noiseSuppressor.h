#pragma once

#include <cstdint>
#include <memory>
#include <vector>

/**
 * @brief Noise suppression level options
 * 
 * These map to SpeexDSP noise suppression attenuation levels in dB
 */
enum class NoiseSuppressionLevel {
    Off = 0,      // No noise suppression
    Low = 1,      // Light suppression (-15 dB)
    Moderate = 2, // Moderate suppression (-30 dB)
    High = 3,     // Strong suppression (-45 dB)
    VeryHigh = 4  // Maximum suppression (-60 dB)
};

/**
 * @brief NoiseSuppressor wraps SpeexDSP for real-time noise cancellation
 * 
 * This class provides a simple interface for processing audio with SpeexDSP's
 * noise suppression preprocessor, removing background noise from microphone input.
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
     * @param sampleRate Audio sample rate (typically 16000, 32000, or 48000 Hz)
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
     * Note: SpeexDSP processes in fixed frame sizes. Larger frames will be 
     * processed in chunks internally.
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

private:
    int m_sampleRate;
    NoiseSuppressionLevel m_level;
    NoiseSuppressionLevel m_previousLevel; // For enable/disable toggling
    bool m_initialized = false;

    // Frame size for SpeexDSP (typically 20ms at sample rate)
    int m_frameSize = 0;

    // Private implementation (pimpl) to hide SpeexDSP dependencies
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
