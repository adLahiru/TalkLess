#define MINIAUDIO_IMPLEMENTATION
#include "audioEngine.h"

#include <QDebug>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>

AudioEngine::AudioEngine()
    : device(nullptr), context(nullptr), deviceRunning(false), micGain(1.0f), micGainDB(0.0f), masterGain(1.0f),
      masterGainDB(0.0f), micPeakLevel(0.0f), masterPeakLevel(0.0f)
{
    // Initialize all clip slots
    for (int i = 0; i < MAX_CLIPS; ++i) {
        clips[i].ringBufferData = nullptr;
    }
}

AudioEngine::AudioEngine(void* parent) : AudioEngine()
{
    (void)parent;
}

AudioEngine::~AudioEngine()
{
    // Stop device first
    if (deviceRunning.load()) {
        stopAudioDevice();
    }

    // Stop all decoder threads
    for (int i = 0; i < MAX_CLIPS; ++i) {
        unloadClip(i);
    }

    // Clean up miniaudio
    if (device) {
        ma_device_uninit(device);
        delete device;
    }
    if (context) {
        ma_context_uninit(context);
        delete context;
    }
}

// ============================================================================
// AUDIO CALLBACK (REAL-TIME SAFE - NO ALLOCATIONS, NO LOCKS, NO BLOCKING)
// ============================================================================

void AudioEngine::audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount)
{
    AudioEngine* engine = (AudioEngine*)pDevice->pUserData;
    if (engine && engine->deviceRunning.load(std::memory_order_acquire)) {
        engine->processAudio(pOutput, pInput, frameCount, pDevice->playback.channels, pDevice->capture.channels);
    } else if (pOutput) {
        // Safety: silence output if engine not ready
        memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
    }
}

void AudioEngine::processAudio(void* output, const void* input, ma_uint32 frameCount, ma_uint32 playbackChannels,
                               ma_uint32 captureChannels)
{
    if (!output)
        return;

    float* out = (float*)output;
    const float* mic = (const float*)input;

    // Load mic gain once (atomic read)
    float currentMicGain = micGain.load(std::memory_order_relaxed);

    // Zero output buffer first
    const ma_uint32 totalOutputSamples = frameCount * playbackChannels;
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        out[i] = 0.0f;
    }

    // Mix microphone input and detect peak level
    // Handle channel mismatch: capture may be mono while playback is stereo
    float micPeak = 0.0f;
    if (mic && captureChannels > 0) {
        for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
            // Get mono sample from capture (average if stereo)
            float monoSample = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                monoSample += mic[frame * captureChannels + ch];
            }
            monoSample = (monoSample / captureChannels) * currentMicGain;

            // Distribute to all playback channels
            for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                out[frame * playbackChannels + ch] += monoSample;
            }

            // Track peak level
            float absSample = std::abs(monoSample);
            if (absSample > micPeak) {
                micPeak = absSample;
            }
        }

        // Update mic peak level (atomic)
        float currentPeak = micPeakLevel.load(std::memory_order_relaxed);
        if (micPeak > currentPeak) {
            micPeakLevel.store(micPeak, std::memory_order_relaxed);
        }
    }

    // Mix all active clips from ring buffers
    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];

        // Check if clip is playing (atomic read, no lock)
        if (slot.state.load(std::memory_order_relaxed) != ClipState::Playing) {
            continue;
        }

        // Load gain once
        float clipGain = slot.gain.load(std::memory_order_relaxed);

        // Try to acquire samples from ring buffer (lock-free)
        void* pReadBuffer;
        ma_uint32 availableFrames = frameCount;

        ma_result result = ma_pcm_rb_acquire_read(&slot.ringBuffer, &availableFrames, &pReadBuffer);

        if (result == MA_SUCCESS && availableFrames > 0) {
            float* clipSamples = (float*)pReadBuffer;

            // CRITICAL: Ring buffer is ALWAYS stereo (2 channels)
            // Device may have different channel count - need to mix correctly
            if (playbackChannels == 2) {
                // Device is stereo - direct copy
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    ma_uint32 outIdx = frame * 2;
                    if (outIdx + 1 < totalOutputSamples) {
                        out[outIdx] += clipSamples[frame * 2] * clipGain;         // Left
                        out[outIdx + 1] += clipSamples[frame * 2 + 1] * clipGain; // Right
                    }
                }
            } else {
                // Device has different channels - mix down/up as needed
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    float left = clipSamples[frame * 2] * clipGain;
                    float right = clipSamples[frame * 2 + 1] * clipGain;
                    float mono = (left + right) * 0.5f; // Mix to mono

                    ma_uint32 outIdx = frame * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels && outIdx + ch < totalOutputSamples; ++ch) {
                        out[outIdx + ch] += mono; // Distribute to all channels
                    }
                }
            }

            // Commit read (lock-free)
            ma_pcm_rb_commit_read(&slot.ringBuffer, availableFrames);
        }
    }

    // Apply master gain to all output and detect peak level
    float currentMasterGain = masterGain.load(std::memory_order_relaxed);
    float outputPeak = 0.0f;

    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        out[i] *= currentMasterGain;

        // Track output peak level
        float absSample = std::abs(out[i]);
        if (absSample > outputPeak) {
            outputPeak = absSample;
        }
    }

    // Update master peak level (atomic)
    float currentPeak = masterPeakLevel.load(std::memory_order_relaxed);
    if (outputPeak > currentPeak) {
        masterPeakLevel.store(outputPeak, std::memory_order_relaxed);
    }

    // Simple limiter (prevent clipping)
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        if (out[i] > 1.0f)
            out[i] = 1.0f;
        if (out[i] < -1.0f)
            out[i] = -1.0f;
    }
}

// ============================================================================
// DECODER THREAD (RUNS IN BACKGROUND, FILLS RING BUFFER)
// ============================================================================

void AudioEngine::decoderThreadFunc(ClipSlot* slot, int slotId)
{
    // Snapshot filepath
    std::string filepath = slot->filePath;

    std::cout << "[Decoder " << slotId << "] Starting: " << filepath << std::endl;

    if (filepath.empty()) {
        std::cerr << "[Decoder " << slotId << "] FATAL: empty filepath" << std::endl;
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    // Configure miniaudio decoder to output stereo 48kHz float
    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 2, 48000);
    ma_decoder decoder;
    if (ma_decoder_init_file(filepath.c_str(), &config, &decoder) != MA_SUCCESS) {
        std::cerr << "[Decoder " << slotId << "] Failed to open file" << std::endl;
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    // Save format info
    slot->sampleRate.store((int)decoder.outputSampleRate, std::memory_order_relaxed);
    slot->channels.store((int)decoder.outputChannels, std::memory_order_relaxed);

    // Decode buffer
    constexpr ma_uint32 kDecodeFrames = 1024;
    float decodeBuffer[kDecodeFrames * 2];
    int framesWritten = 0;
    bool shouldLoop = false;

    std::cout << "[Decoder " << slotId << "] Decoding started" << std::endl;
    std::cout << "[Decoder " << slotId << "] Ring buffer capacity: " << RING_BUFFER_SIZE_IN_FRAMES << " frames"
              << std::endl;

    // Decode loop
    while (true) {
        // Stop requested?
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) {
            std::cout << "[Decoder " << slotId << "] Stop requested" << std::endl;
            break;
        }

        ma_uint64 framesRead = 0;
        ma_result readResult = ma_decoder_read_pcm_frames(&decoder, decodeBuffer, kDecodeFrames, &framesRead);
        if (readResult != MA_SUCCESS && readResult != MA_AT_END) {
            std::cerr << "[Decoder " << slotId << "] Read error: " << readResult << std::endl;
            break;
        }

        if (framesRead == 0) {
            shouldLoop = slot->loop.load(std::memory_order_relaxed);
            if (shouldLoop) {
                std::cout << "[Decoder " << slotId << "] Looping" << std::endl;
                ma_decoder_seek_to_pcm_frame(&decoder, 0);
                continue;
            } else {
                std::cout << "[Decoder " << slotId << "] Finished" << std::endl;
                break;
            }
        }

        void* pWrite = nullptr;
        ma_uint32 framesToWrite = static_cast<ma_uint32>(framesRead);
        if (ma_pcm_rb_acquire_write(&slot->ringBuffer, &framesToWrite, &pWrite) == MA_SUCCESS && framesToWrite > 0) {
            memcpy(pWrite, decodeBuffer, framesToWrite * 2 * sizeof(float));
            ma_pcm_rb_commit_write(&slot->ringBuffer, framesToWrite);
            framesWritten += static_cast<int>(framesToWrite);
            if (framesWritten < 5000) {
                std::cout << "[Decoder " << slotId << "] Wrote " << framesToWrite << " frames to ring buffer"
                          << std::endl;
            }
        }
    }

    ma_decoder_uninit(&decoder);

    slot->state.store(ClipState::Stopped, std::memory_order_release);
    std::cout << "[Decoder " << slotId << "] Thread exiting" << std::endl;
}

// ============================================================================
// PUBLIC API (THREAD-SAFE, CALLED FROM QT UI THREAD)
// ============================================================================

bool AudioEngine::loadClip(int slotId, const std::string& filepath)
{
    // CRITICAL: Validate slot ID (UI's responsibility to manage slots)
    if (slotId < 0 || slotId >= MAX_CLIPS) {
        std::cerr << "ERROR: Invalid slot ID: " << slotId << std::endl;
        return false;
    }

    // CRITICAL: Reject empty file paths immediately
    if (filepath.empty()) {
        std::cerr << "ERROR: Cannot load clip - filepath is empty" << std::endl;
        return false;
    }

    // Ensure slot is not currently in use
    ClipSlot& slot = clips[slotId];
    if (slot.state.load(std::memory_order_relaxed) != ClipState::Stopped) {
        std::cerr << "ERROR: Slot " << slotId << " is currently in use. Stop it first." << std::endl;
        return false;
    }

    // Allocate ring buffer if not already done
    if (!slot.ringBufferData) {
        const size_t bufferSizeInBytes = RING_BUFFER_SIZE_IN_FRAMES * 2 * sizeof(float);
        slot.ringBufferData = malloc(bufferSizeInBytes);

        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES, slot.ringBufferData, nullptr, &slot.ringBuffer);
    }

    // Reset ring buffer
    ma_pcm_rb_reset(&slot.ringBuffer);

    // Set file path
    slot.filePath = filepath;
    slot.gain.store(1.0f, std::memory_order_relaxed);
    slot.loop.store(false, std::memory_order_relaxed);

    std::cout << "Loaded clip to slot " << slotId << ": " << filepath << std::endl;
    return true;
}

void AudioEngine::playClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) {
        std::cerr << "ERROR: Invalid clip slot ID: " << slotId << std::endl;
        return;
    }

    ClipSlot& slot = clips[slotId];

    // CRITICAL: Validate that clip is loaded before playing
    if (slot.filePath.empty()) {
        std::cerr << "ERROR: Cannot play clip " << slotId << " - not loaded (empty filepath)" << std::endl;
        return;
    }

    // Stop existing decoder thread if any
    if (slot.decoderThread.joinable()) {
        slot.state.store(ClipState::Stopping, std::memory_order_release);
        slot.decoderThread.join();
    }

    // Reset ring buffer
    ma_pcm_rb_reset(&slot.ringBuffer);

    // Start decoder thread
    slot.state.store(ClipState::Playing, std::memory_order_release);
    slot.decoderThread = std::thread(decoderThreadFunc, &slot, slotId);

    std::cout << "Playing clip slot " << slotId << std::endl;
}

void AudioEngine::stopClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;

    ClipSlot& slot = clips[slotId];

    // Signal decoder to stop
    slot.state.store(ClipState::Stopping, std::memory_order_release);

    // Wait for decoder thread to finish
    if (slot.decoderThread.joinable()) {
        slot.decoderThread.join();
    }

    std::cout << "Stopped clip slot " << slotId << std::endl;
}

void AudioEngine::setClipLoop(int slotId, bool loop)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].loop.store(loop, std::memory_order_relaxed);
    qDebug() << "Set clip" << slotId << "loop to" << loop;
}

void AudioEngine::setClipGain(int slotId, float gainDB)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    float linear = dBToLinear(gainDB);
    clips[slotId].gain.store(linear, std::memory_order_relaxed);
    qDebug() << "Set clip" << slotId << "gain to" << gainDB << "dB (linear:" << linear << ")";
}

float AudioEngine::getClipGain(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return 0.0f;
    float linear = clips[slotId].gain.load(std::memory_order_relaxed);
    float gainDB = 20.0f * log10(linear);
    qDebug() << "Getting clip" << slotId << "gain:" << gainDB << "dB";
    return gainDB;
}

bool AudioEngine::isClipPlaying(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return false;
    return clips[slotId].state.load(std::memory_order_relaxed) == ClipState::Playing;
}

void AudioEngine::unloadClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;

    stopClip(slotId);

    // Clear filepath (slot is now free)
    clips[slotId].filePath.clear();

    // Free ring buffer
    if (clips[slotId].ringBufferData) {
        ma_pcm_rb_uninit(&clips[slotId].ringBuffer);
        free(clips[slotId].ringBufferData);
        clips[slotId].ringBufferData = nullptr;
    }
}

void AudioEngine::setMicGainDB(float gainDB)
{
    micGainDB.store(gainDB, std::memory_order_relaxed);
    micGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
    qDebug() << "Set mic gain dB to:" << gainDB;
}

float AudioEngine::getMicGainDB() const
{
    qDebug() << "Getting mic gain dB:" << micGainDB.load(std::memory_order_relaxed);
    return micGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainDB(float gainDB)
{
    masterGainDB.store(gainDB, std::memory_order_relaxed);
    masterGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
    qDebug() << "Set master gain to" << gainDB << "dB (linear:" << dBToLinear(gainDB) << ")";
}

float AudioEngine::getMasterGainDB() const
{
    return masterGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainLinear(float linear)
{
    if (linear < 0.0f)
        linear = 0.0f;
    masterGain.store(linear, std::memory_order_relaxed);
    masterGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainLinear() const
{
    return masterGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMicGainLinear(float linear)
{
    if (linear < 0.0f)
        linear = 0.0f;
    micGain.store(linear, std::memory_order_relaxed);
    micGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMicGainLinear() const
{
    return micGain.load(std::memory_order_relaxed);
}

// Real-time audio level monitoring
float AudioEngine::getMicPeakLevel() const
{
    return micPeakLevel.load(std::memory_order_relaxed);
}

float AudioEngine::getMasterPeakLevel() const
{
    return masterPeakLevel.load(std::memory_order_relaxed);
}

void AudioEngine::resetPeakLevels()
{
    micPeakLevel.store(0.0f, std::memory_order_relaxed);
    masterPeakLevel.store(0.0f, std::memory_order_relaxed);
}

// Event callbacks
void AudioEngine::setClipFinishedCallback(ClipFinishedCallback callback)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipFinishedCallback = callback;
}

void AudioEngine::setClipErrorCallback(ClipErrorCallback callback)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipErrorCallback = callback;
}

// ============================================================================
// DEVICE INITIALIZATION
// ============================================================================

bool AudioEngine::initContext()
{
    if (!context) {
        context = new ma_context();
        if (ma_context_init(nullptr, 0, nullptr, context) != MA_SUCCESS) {
            std::cerr << "Failed to initialize miniaudio context" << std::endl;
            delete context;
            context = nullptr;
            return false;
        }
    }
    return true;
}

bool AudioEngine::initDevice()
{
    if (device)
        return true;

    if (!initContext())
        return false;

    device = new ma_device();
    ma_device_config config = ma_device_config_init(ma_device_type_duplex);
    config.playback.format = ma_format_f32;
    config.playback.channels = 2;
    config.capture.format = ma_format_f32;
    config.capture.channels = 2;
    config.sampleRate = 48000;
    config.dataCallback = AudioEngine::audioCallback;
    config.pUserData = this;
    applyDeviceSelection(config);

    if (ma_device_init(context, &config, device) != MA_SUCCESS) {
        std::cerr << "Failed to initialize audio device" << std::endl;
        delete device;
        device = nullptr;
        return false;
    }

    std::cout << "Audio device initialized" << std::endl;
    return true;
}

bool AudioEngine::startAudioDevice()
{
    if (!device && !initDevice())
        return false;

    if (ma_device_start(device) != MA_SUCCESS) {
        std::cerr << "Failed to start audio device" << std::endl;
        return false;
    }

    deviceRunning.store(true, std::memory_order_release);
    std::cout << "Audio device started" << std::endl;
    return true;
}

bool AudioEngine::stopAudioDevice()
{
    if (!device)
        return false;

    if (ma_device_stop(device) != MA_SUCCESS) {
        std::cerr << "Failed to stop audio device" << std::endl;
        return false;
    }

    deviceRunning.store(false, std::memory_order_release);
    std::cout << "Audio device stopped" << std::endl;
    return true;
}

bool AudioEngine::isDeviceRunning() const
{
    return deviceRunning.load(std::memory_order_relaxed);
}

bool AudioEngine::applyDeviceSelection(ma_device_config& config)
{
    if (selectedPlaybackSet) {
        config.playback.pDeviceID = &selectedPlaybackDeviceIdStruct;
    }
    if (selectedCaptureSet) {
        config.capture.pDeviceID = &selectedCaptureDeviceIdStruct;
    }
    return true;
}

bool AudioEngine::reinitializeDevice(bool restart)
{
    // Use a mutex to prevent concurrent reinitialization
    static std::mutex reinitMutex;
    std::lock_guard<std::mutex> lock(reinitMutex);

    bool wasRunning = deviceRunning.load(std::memory_order_acquire);

    // Stop device first and ensure callback won't access invalid state
    if (wasRunning) {
        stopAudioDevice();
        // Small delay to ensure audio callback has exited
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

    if (!initDevice()) {
        std::cerr << "Failed to reinitialize audio device" << std::endl;
        return false;
    }

    if (restart || wasRunning) {
        return startAudioDevice();
    }
    return true;
}

// ============================================================================
// HELPERS
// ============================================================================

float AudioEngine::dBToLinear(float db)
{
    return pow(10.0f, db / 20.0f);
}

// Device enumeration (same as before)
std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumeratePlaybackDevices()
{
    std::vector<AudioDeviceInfo> devices;
    if (!initContext())
        return devices;

    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;

    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }

    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pPlaybackInfos[i].name);
        info.id = std::to_string(i);
        info.isDefault = pPlaybackInfos[i].isDefault;
        info.deviceId = pPlaybackInfos[i].id;
        devices.push_back(info);
    }

    return devices;
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumerateCaptureDevices()
{
    std::vector<AudioDeviceInfo> devices;
    if (!initContext())
        return devices;

    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;

    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }

    for (ma_uint32 i = 0; i < captureCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pCaptureInfos[i].name);
        info.id = std::to_string(i);
        info.isDefault = pCaptureInfos[i].isDefault;
        info.deviceId = pCaptureInfos[i].id;
        devices.push_back(info);
    }

    return devices;
}

bool AudioEngine::setPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedPlaybackDeviceId = dev.id;
            selectedPlaybackDeviceIdStruct = dev.deviceId;
            selectedPlaybackSet = true;
            return reinitializeDevice(true);
        }
    }
    std::cerr << "Playback device not found: " << deviceId << std::endl;
    return false;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId)
{
    auto devices = enumerateCaptureDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedCaptureDeviceId = dev.id;
            selectedCaptureDeviceIdStruct = dev.deviceId;
            selectedCaptureSet = true;
            return reinitializeDevice(true);
        }
    }
    std::cerr << "Capture device not found: " << deviceId << std::endl;
    return false;
}
