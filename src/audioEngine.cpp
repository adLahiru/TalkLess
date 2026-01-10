#define MINIAUDIO_IMPLEMENTATION
#include "audioEngine.h"

#include <QDebug>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>

AudioEngine::AudioEngine() = default;

AudioEngine::AudioEngine(void* parent) : AudioEngine()
{
    (void)parent;
}

AudioEngine::~AudioEngine()
{
    // Stop monitor first
    if (monitorRunning.load(std::memory_order_acquire)) {
        stopMonitorDevice();
    }
    if (monitorDevice) {
        ma_device_uninit(monitorDevice);
        delete monitorDevice;
        monitorDevice = nullptr;
    }

           // Stop main
    if (deviceRunning.load(std::memory_order_acquire)) {
        stopAudioDevice();
    }

           // Stop & free clips
    for (int i = 0; i < MAX_CLIPS; ++i) {
        unloadClip(i);
    }

           // Cleanup main device
    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

           // Cleanup context
    if (context) {
        ma_context_uninit(context);
        delete context;
        context = nullptr;
    }
}

// ============================================================================
// MAIN DEVICE CALLBACK (duplex)
// ============================================================================

void AudioEngine::audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (engine && engine->deviceRunning.load(std::memory_order_acquire)) {
        engine->processAudio(pOutput, pInput, frameCount, pDevice->playback.channels, pDevice->capture.channels);
    } else if (pOutput) {
        std::memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
    }
}

void AudioEngine::processAudio(void* output,
                               const void* input,
                               ma_uint32 frameCount,
                               ma_uint32 playbackChannels,
                               ma_uint32 captureChannels)
{
    if (!output) return;

    auto* out = static_cast<float*>(output);
    const auto* mic = static_cast<const float*>(input);

    const float currentMicGain = micGain.load(std::memory_order_relaxed);
    const float currentBalance = micBalance.load(std::memory_order_relaxed);
    
    // Calculate factors: 0.0 = full mic, 1.0 = full soundboard. 0.5 = full both.
    const float micFactor = std::min(1.0f, (1.0f - currentBalance) * 2.0f);
    const float clipFactor = std::min(1.0f, currentBalance * 2.0f);

    const ma_uint32 totalOutputSamples = frameCount * playbackChannels;
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) out[i] = 0.0f;

    // Mic processing: peak monitoring, recording, and passthrough to output
    float micPeak = 0.0f;
    const bool passthroughEnabled = micPassthroughEnabled.load(std::memory_order_relaxed);
    const bool enabled = micEnabled.load(std::memory_order_relaxed);
    
    if (mic && captureChannels > 0 && enabled) {
        for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
            // Calculate mono sample from all capture channels
            float monoSample = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                monoSample += mic[frame * captureChannels + ch];
            }
            monoSample = (monoSample / static_cast<float>(captureChannels)) * currentMicGain;

            // Peak level tracking
            float absSample = std::abs(monoSample);
            if (absSample > micPeak) micPeak = absSample;
            
            // Route mic to output if passthrough is enabled
            if (passthroughEnabled) {
                ma_uint32 outIdx = frame * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels && (outIdx + ch) < totalOutputSamples; ++ch) {
                    out[outIdx + ch] += monoSample * micFactor;
                }
            }
        }

        // Update peak level
        float currentPeak = micPeakLevel.load(std::memory_order_relaxed);
        if (micPeak > currentPeak) micPeakLevel.store(micPeak, std::memory_order_relaxed);

        // Recording capture
        if (recording.load(std::memory_order_relaxed)) {
            std::lock_guard<std::mutex> lock(recordingMutex);
            for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
                float monoSample = 0.0f;
                for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                    monoSample += mic[frame * captureChannels + ch];
                }
                monoSample = (monoSample / static_cast<float>(captureChannels)) * currentMicGain;

                recordingBuffer.push_back(monoSample);
                recordingBuffer.push_back(monoSample);
            }
            recordedFrames.fetch_add(frameCount, std::memory_order_relaxed);
        }
    }

    // Mix clips from MAIN ring buffers
    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        if (slot.state.load(std::memory_order_relaxed) != ClipState::Playing) continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed);
        const float finalClipGain = clipGain * clipFactor;

        void* pReadBuffer = nullptr;
        ma_uint32 availableFrames = frameCount;

        ma_result result = ma_pcm_rb_acquire_read(&slot.ringBufferMain, &availableFrames, &pReadBuffer);
        if (result == MA_SUCCESS && availableFrames > 0 && pReadBuffer) {
            auto* clipSamples = static_cast<float*>(pReadBuffer);

            // ring buffer stereo (2ch)
            if (playbackChannels == 2) {
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    const ma_uint32 outIdx = frame * 2;
                    if (outIdx + 1 < totalOutputSamples) {
                        out[outIdx]     += clipSamples[frame * 2]     * finalClipGain;
                        out[outIdx + 1] += clipSamples[frame * 2 + 1] * finalClipGain;
                    }
                }
            } else {
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    float left  = clipSamples[frame * 2]     * finalClipGain;
                    float right = clipSamples[frame * 2 + 1] * finalClipGain;
                    float mono  = (left + right) * 0.5f;

                    ma_uint32 outIdx = frame * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels && (outIdx + ch) < totalOutputSamples; ++ch) {
                        out[outIdx + ch] += mono;
                    }
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMain, availableFrames);
        }
    }

           // Master gain + peak
    const float currentMasterGain = masterGain.load(std::memory_order_relaxed);
    float outputPeak = 0.0f;

    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        out[i] *= currentMasterGain;
        float absSample = std::abs(out[i]);
        if (absSample > outputPeak) outputPeak = absSample;
    }

    float currentPeak = masterPeakLevel.load(std::memory_order_relaxed);
    if (outputPeak > currentPeak) masterPeakLevel.store(outputPeak, std::memory_order_relaxed);

           // Limiter
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }
}

// ============================================================================
// MONITOR DEVICE CALLBACK (playback-only, clips-only)
// ============================================================================

void AudioEngine::monitorCallback(ma_device* pDevice, void* pOutput, const void*, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !engine->monitorRunning.load(std::memory_order_acquire)) {
        if (pOutput) {
            std::memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
        }
        return;
    }
    engine->processMonitorAudio(pOutput, frameCount, pDevice->playback.channels);
}

void AudioEngine::processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels)
{
    if (!output) return;

    auto* out = static_cast<float*>(output);
    const ma_uint32 totalOutputSamples = frameCount * playbackChannels;

    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) out[i] = 0.0f;

    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        if (slot.state.load(std::memory_order_relaxed) != ClipState::Playing) continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed);

        void* pReadBuffer = nullptr;
        ma_uint32 availableFrames = frameCount;

        ma_result result = ma_pcm_rb_acquire_read(&slot.ringBufferMon, &availableFrames, &pReadBuffer);
        if (result == MA_SUCCESS && availableFrames > 0 && pReadBuffer) {
            auto* clipSamples = static_cast<float*>(pReadBuffer);

            if (playbackChannels == 2) {
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    const ma_uint32 outIdx = frame * 2;
                    if (outIdx + 1 < totalOutputSamples) {
                        out[outIdx]     += clipSamples[frame * 2]     * clipGain;
                        out[outIdx + 1] += clipSamples[frame * 2 + 1] * clipGain;
                    }
                }
            } else {
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    float left  = clipSamples[frame * 2]     * clipGain;
                    float right = clipSamples[frame * 2 + 1] * clipGain;
                    float mono  = (left + right) * 0.5f;

                    ma_uint32 outIdx = frame * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels && (outIdx + ch) < totalOutputSamples; ++ch) {
                        out[outIdx + ch] += mono;
                    }
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMon, availableFrames);
        }
    }

    const float g = monitorGain.load(std::memory_order_relaxed);
    float outputPeak = 0.0f;

    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        out[i] *= g;
        
        float absSample = std::abs(out[i]);
        if (absSample > outputPeak) outputPeak = absSample;

        // Simple limiter
        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

    float currentPeak = monitorPeakLevel.load(std::memory_order_relaxed);
    if (outputPeak > currentPeak) monitorPeakLevel.store(outputPeak, std::memory_order_relaxed);
}

// ============================================================================
// DECODER THREAD (fills ringBufferMain always, ringBufferMon best-effort)
// ============================================================================

void AudioEngine::decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId)
{
    const std::string filepath = slot->filePath;
    if (filepath.empty()) {
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 2, 48000);
    ma_decoder decoder;

    if (ma_decoder_init_file(filepath.c_str(), &config, &decoder) != MA_SUCCESS) {
        // error callback
        ClipErrorCallback cb;
        {
          // We cannot access AudioEngine instance here directly from slot.
          // Keep errors visible via stderr at minimum.
        }
        std::cerr << "Decoder init failed for slot " << slotId << "\n";
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    slot->sampleRate.store((int)decoder.outputSampleRate, std::memory_order_relaxed);
    slot->channels.store((int)decoder.outputChannels, std::memory_order_relaxed);

    constexpr ma_uint32 kDecodeFrames = 1024;
    float decodeBuffer[kDecodeFrames * 2];

    bool naturalEnd = false;

    while (true) {
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;

        ma_uint64 framesRead = 0;
        ma_result readResult = ma_decoder_read_pcm_frames(&decoder, decodeBuffer, kDecodeFrames, &framesRead);

        if (readResult != MA_SUCCESS && readResult != MA_AT_END) break;

        if (framesRead == 0) {
            if (slot->loop.load(std::memory_order_relaxed)) {
                ma_decoder_seek_to_pcm_frame(&decoder, 0);
                continue;
            }
            naturalEnd = true;
            break;
        }

        ma_uint32 framesRemaining = static_cast<ma_uint32>(framesRead);
        float* pReadCursor = decodeBuffer;

        while (framesRemaining > 0) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;

                   // MAIN: back-pressure (retry until written)
            void* wMain = nullptr;
            ma_uint32 toWriteMain = framesRemaining;

            ma_result a = ma_pcm_rb_acquire_write(&slot->ringBufferMain, &toWriteMain, &wMain);
            if (a == MA_SUCCESS && toWriteMain > 0 && wMain) {
                std::memcpy(wMain, pReadCursor, toWriteMain * 2 * sizeof(float));
                ma_pcm_rb_commit_write(&slot->ringBufferMain, toWriteMain);

                       // MONITOR: best-effort, do not block
                void* wMon = nullptr;
                ma_uint32 toWriteMon = toWriteMain;
                ma_result b = ma_pcm_rb_acquire_write(&slot->ringBufferMon, &toWriteMon, &wMon);

                if (b == MA_SUCCESS && toWriteMon > 0 && wMon) {
                    const ma_uint32 n = std::min(toWriteMon, toWriteMain);
                    std::memcpy(wMon, pReadCursor, n * 2 * sizeof(float));
                    ma_pcm_rb_commit_write(&slot->ringBufferMon, n);
                }

                pReadCursor += toWriteMain * 2;
                framesRemaining -= toWriteMain;
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
        }
    }

    ma_decoder_uninit(&decoder);

    slot->state.store(ClipState::Stopped, std::memory_order_release);

    if (naturalEnd) {
        std::cout << "Clip finished slot " << slotId << "\n";
        
        std::lock_guard<std::mutex> lock(engine->callbackMutex);
        if (engine->clipFinishedCallback) {
            engine->clipFinishedCallback(slotId);
        }
    }
}

// ============================================================================
// CLIPS API
// ============================================================================

bool AudioEngine::loadClip(int slotId, const std::string& filepath)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return false;
    if (filepath.empty()) return false;

    ClipSlot& slot = clips[slotId];

    if (slot.state.load(std::memory_order_relaxed) != ClipState::Stopped) return false;

    const size_t bufferSizeInBytes = RING_BUFFER_SIZE_IN_FRAMES * 2 * sizeof(float);

    if (slot.ringBufferMainData == nullptr) {
        slot.ringBufferMainData = std::malloc(bufferSizeInBytes);
        if (!slot.ringBufferMainData) return false;

        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES,
                       slot.ringBufferMainData, nullptr, &slot.ringBufferMain);
    }

    if (slot.ringBufferMonData == nullptr) {
        slot.ringBufferMonData = std::malloc(bufferSizeInBytes);
        if (!slot.ringBufferMonData) return false;

        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES,
                       slot.ringBufferMonData, nullptr, &slot.ringBufferMon);
    }

    ma_pcm_rb_reset(&slot.ringBufferMain);
    ma_pcm_rb_reset(&slot.ringBufferMon);

    slot.filePath = filepath;
    slot.gain.store(1.0f, std::memory_order_relaxed);
    slot.loop.store(false, std::memory_order_relaxed);

    return true;
}

void AudioEngine::playClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    ClipSlot& slot = clips[slotId];
    if (slot.filePath.empty()) return;

           // Ensure at least one output is running, otherwise decoder will eventually block
    if (!isDeviceRunning() && !isMonitorRunning()) {
        // You can choose to auto-start main here instead:
        // startAudioDevice();
        return;
    }

    if (slot.decoderThread.joinable()) {
        slot.state.store(ClipState::Stopping, std::memory_order_release);
        slot.decoderThread.join();
    }

    ma_pcm_rb_reset(&slot.ringBufferMain);
    ma_pcm_rb_reset(&slot.ringBufferMon);

    slot.state.store(ClipState::Playing, std::memory_order_release);
    slot.decoderThread = std::thread(decoderThreadFunc, this, &slot, slotId);
}

void AudioEngine::stopClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    ClipSlot& slot = clips[slotId];
    slot.state.store(ClipState::Stopping, std::memory_order_release);

    if (slot.decoderThread.joinable()) {
        slot.decoderThread.join();
    }

    slot.state.store(ClipState::Stopped, std::memory_order_release);
}

void AudioEngine::setClipLoop(int slotId, bool loop)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].loop.store(loop, std::memory_order_relaxed);
}

void AudioEngine::setClipGain(int slotId, float gainDB)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].gain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getClipGain(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return 0.0f;
    float linear = clips[slotId].gain.load(std::memory_order_relaxed);
    return 20.0f * log10(std::max(linear, 0.000001f));
}

bool AudioEngine::isClipPlaying(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return false;
    return clips[slotId].state.load(std::memory_order_relaxed) == ClipState::Playing;
}

void AudioEngine::unloadClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    stopClip(slotId);
    clips[slotId].filePath.clear();

    if (clips[slotId].ringBufferMainData) {
        ma_pcm_rb_uninit(&clips[slotId].ringBufferMain);
        std::free(clips[slotId].ringBufferMainData);
        clips[slotId].ringBufferMainData = nullptr;
    }

    if (clips[slotId].ringBufferMonData) {
        ma_pcm_rb_uninit(&clips[slotId].ringBufferMon);
        std::free(clips[slotId].ringBufferMonData);
        clips[slotId].ringBufferMonData = nullptr;
    }
}

// ============================================================================
// GAIN + PEAK API
// ============================================================================

void AudioEngine::setMicGainDB(float gainDB)
{
    micGainDB.store(gainDB, std::memory_order_relaxed);
    micGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMicGainDB() const
{
    return micGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainDB(float gainDB)
{
    masterGainDB.store(gainDB, std::memory_order_relaxed);
    masterGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainDB() const
{
    return masterGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    masterGain.store(linear, std::memory_order_relaxed);
    masterGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainLinear() const
{
    return masterGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMicGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    micGain.store(linear, std::memory_order_relaxed);
    micGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMicGainLinear() const
{
    return micGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMonitorGainDB(float gainDB)
{
    monitorGainDB.store(gainDB, std::memory_order_relaxed);
    monitorGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMonitorGainDB() const
{
    return monitorGainDB.load(std::memory_order_relaxed);
}

float AudioEngine::getMicPeakLevel() const
{
    return micPeakLevel.load(std::memory_order_relaxed);
}

float AudioEngine::getMasterPeakLevel() const
{
    return masterPeakLevel.load(std::memory_order_relaxed);
}

float AudioEngine::getMonitorPeakLevel() const
{
    return monitorPeakLevel.load(std::memory_order_relaxed);
}

void AudioEngine::resetPeakLevels()
{
    micPeakLevel.store(0.0f, std::memory_order_relaxed);
    masterPeakLevel.store(0.0f, std::memory_order_relaxed);
    monitorPeakLevel.store(0.0f, std::memory_order_relaxed);
}

void AudioEngine::setMicEnabled(bool enabled)
{
    micEnabled.store(enabled, std::memory_order_relaxed);
}

bool AudioEngine::isMicEnabled() const
{
    return micEnabled.load(std::memory_order_relaxed);
}

void AudioEngine::setMicPassthroughEnabled(bool enabled)
{
    micPassthroughEnabled.store(enabled, std::memory_order_relaxed);
}

bool AudioEngine::isMicPassthroughEnabled() const
{
    return micPassthroughEnabled.load(std::memory_order_relaxed);
}

void AudioEngine::setMicSoundboardBalance(float balance)
{
    micBalance.store(balance, std::memory_order_relaxed);
}

float AudioEngine::getMicSoundboardBalance() const
{
    return micBalance.load(std::memory_order_relaxed);
}

// ============================================================================
// CALLBACK SETTERS
// ============================================================================

void AudioEngine::setClipFinishedCallback(ClipFinishedCallback callback)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipFinishedCallback = std::move(callback);
}

void AudioEngine::setClipErrorCallback(ClipErrorCallback callback)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipErrorCallback = std::move(callback);
}

// ============================================================================
// DEVICE INIT (MAIN)
// ============================================================================

bool AudioEngine::initContext()
{
    if (!context) {
        context = new ma_context();
        if (ma_context_init(nullptr, 0, nullptr, context) != MA_SUCCESS) {
            delete context;
            context = nullptr;
            return false;
        }
    }
    return true;
}

bool AudioEngine::initDevice()
{
    qDebug() << "AudioEngine::initDevice called";
    
    if (device) {
        qDebug() << "Device already exists, reusing";
        return true;
    }
    if (!initContext()) {
        qWarning() << "Failed to initialize context";
        return false;
    }

    device = new ma_device();

    // Try multiple configurations in order of preference
    struct DeviceConfig {
        ma_format captureFormat;
        ma_uint32 captureChannels;
        ma_uint32 sampleRate;
        const char* description;
    };
    
    // Configuration attempts - from most specific to most flexible
    DeviceConfig configs[] = {
        { ma_format_f32, 2, 48000, "48kHz stereo f32" },
        { ma_format_f32, 1, 48000, "48kHz mono f32" },
        { ma_format_f32, 2, 44100, "44.1kHz stereo f32" },
        { ma_format_f32, 1, 44100, "44.1kHz mono f32" },
        { ma_format_s16, 2, 48000, "48kHz stereo s16" },
        { ma_format_s16, 1, 48000, "48kHz mono s16" },
        { ma_format_s16, 2, 44100, "44.1kHz stereo s16" },
        { ma_format_s16, 1, 44100, "44.1kHz mono s16" },
        { ma_format_unknown, 0, 0, "auto-detect all" },  // Let miniaudio pick everything
    };
    
    ma_result result = MA_ERROR;
    
    for (const auto& cfg : configs) {
        ma_device_config config = ma_device_config_init(ma_device_type_duplex);
        config.playback.format = ma_format_f32;
        config.playback.channels = 2;
        config.capture.format = cfg.captureFormat;
        config.capture.channels = cfg.captureChannels;
        config.sampleRate = cfg.sampleRate;
        config.dataCallback = AudioEngine::audioCallback;
        config.pUserData = this;

        applyDeviceSelection(config);
        
        qDebug() << "Trying device config:" << cfg.description;

        result = ma_device_init(context, &config, device);
        if (result == MA_SUCCESS) {
            qDebug() << "ma_device_init succeeded with config:" << cfg.description;
            qDebug() << "  Playback device:" << device->playback.name;
            qDebug() << "  Capture device:" << device->capture.name;
            qDebug() << "  Sample rate:" << device->sampleRate;
            qDebug() << "  Capture channels:" << device->capture.channels;
            qDebug() << "  Capture format:" << device->capture.format;
            return true;
        }
        
        qDebug() << "  Failed with result:" << result;
    }
    
    // All configurations failed
    qWarning() << "All device configurations failed! Last error:" << result;
    delete device;
    device = nullptr;
    return false;
}

bool AudioEngine::startAudioDevice()
{
    if (!device && !initDevice()) return false;

    if (ma_device_start(device) != MA_SUCCESS) return false;

    deviceRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopAudioDevice()
{
    if (!device) return false;

    if (ma_device_stop(device) != MA_SUCCESS) return false;

    deviceRunning.store(false, std::memory_order_release);
    return true;
}

bool AudioEngine::isDeviceRunning() const
{
    return deviceRunning.load(std::memory_order_relaxed);
}

bool AudioEngine::applyDeviceSelection(ma_device_config& config)
{
    if (selectedPlaybackSet) config.playback.pDeviceID = &selectedPlaybackDeviceIdStruct;
    if (selectedCaptureSet)  config.capture.pDeviceID  = &selectedCaptureDeviceIdStruct;
    return true;
}

bool AudioEngine::reinitializeDevice(bool restart)
{
    qDebug() << "AudioEngine::reinitializeDevice called, restart:" << restart;
    
    static std::mutex reinitMutex;
    std::lock_guard<std::mutex> lock(reinitMutex);

    bool wasRunning = deviceRunning.load(std::memory_order_acquire);
    qDebug() << "Device was running:" << wasRunning;

    if (wasRunning) {
        qDebug() << "Stopping audio device...";
        stopAudioDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    if (device) {
        qDebug() << "Uninitializing existing device...";
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

    qDebug() << "Initializing new device with capture device set:" << selectedCaptureSet
             << "playback device set:" << selectedPlaybackSet;
    
    if (!initDevice()) {
        qWarning() << "Failed to initialize device!";
        return false;
    }
    
    qDebug() << "Device initialized successfully";

    if (restart || wasRunning) {
        bool started = startAudioDevice();
        qDebug() << "Started audio device:" << started;
        return started;
    }
    return true;
}

// ============================================================================
// DEVICE INIT (MONITOR)
// ============================================================================

bool AudioEngine::initMonitorDevice()
{
    if (monitorDevice) return true;
    if (!initContext()) return false;

    monitorDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_f32;
    cfg.playback.channels = 2;
    cfg.sampleRate = 48000;
    cfg.dataCallback = AudioEngine::monitorCallback;
    cfg.pUserData = this;

    if (selectedMonitorPlaybackSet) {
        cfg.playback.pDeviceID = &selectedMonitorPlaybackDeviceIdStruct;
    }

    if (ma_device_init(context, &cfg, monitorDevice) != MA_SUCCESS) {
        delete monitorDevice;
        monitorDevice = nullptr;
        return false;
    }

    return true;
}

bool AudioEngine::startMonitorDevice()
{
    if (!monitorDevice && !initMonitorDevice()) return false;

    if (ma_device_start(monitorDevice) != MA_SUCCESS) return false;

    monitorRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopMonitorDevice()
{
    if (!monitorDevice) return false;

    monitorRunning.store(false, std::memory_order_release);
    ma_device_stop(monitorDevice);
    return true;
}

bool AudioEngine::isMonitorRunning() const
{
    return monitorRunning.load(std::memory_order_relaxed);
}

bool AudioEngine::reinitializeMonitorDevice(bool restart)
{
    static std::mutex reinitMutex;
    std::lock_guard<std::mutex> lock(reinitMutex);

    bool wasRunning = monitorRunning.load(std::memory_order_acquire);

    if (wasRunning) {
        stopMonitorDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    if (monitorDevice) {
        ma_device_uninit(monitorDevice);
        delete monitorDevice;
        monitorDevice = nullptr;
    }

    if (!initMonitorDevice()) return false;

    if (restart || wasRunning) return startMonitorDevice();
    return true;
}

bool AudioEngine::setMonitorPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedMonitorPlaybackDeviceId = dev.id;
            selectedMonitorPlaybackDeviceIdStruct = dev.deviceId;
            selectedMonitorPlaybackSet = true;
            return reinitializeMonitorDevice(true);
        }
    }
    return false;
}

// ============================================================================
// HELPERS + ENUMERATION
// ============================================================================

float AudioEngine::dBToLinear(float db)
{
    return pow(10.0f, db / 20.0f);
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumeratePlaybackDevices()
{
    std::vector<AudioDeviceInfo> devices;
    if (!initContext()) return devices;

    ma_device_info* pPlaybackInfos = nullptr;
    ma_uint32 playbackCount = 0;
    ma_device_info* pCaptureInfos = nullptr;
    ma_uint32 captureCount = 0;

    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }

    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pPlaybackInfos[i].name);
        info.id = info.name;  // Use name as ID for stable identification
        info.isDefault = pPlaybackInfos[i].isDefault;
        info.deviceId = pPlaybackInfos[i].id;
        devices.push_back(info);
    }

    return devices;
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumerateCaptureDevices()
{
    std::vector<AudioDeviceInfo> devices;
    if (!initContext()) return devices;

    ma_device_info* pPlaybackInfos = nullptr;
    ma_uint32 playbackCount = 0;
    ma_device_info* pCaptureInfos = nullptr;
    ma_uint32 captureCount = 0;

    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }

    for (ma_uint32 i = 0; i < captureCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pCaptureInfos[i].name);
        info.id = info.name;  // Use name as ID for stable identification
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
    return false;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId)
{
    qDebug() << "AudioEngine::setCaptureDevice called with deviceId:" << QString::fromStdString(deviceId);
    
    auto devices = enumerateCaptureDevices();
    qDebug() << "Found" << devices.size() << "capture devices:";
    for (const auto& dev : devices) {
        qDebug() << "  Device id:" << QString::fromStdString(dev.id)
                 << "name:" << QString::fromStdString(dev.name)
                 << "isDefault:" << dev.isDefault;
    }
    
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            qDebug() << "Found matching device:" << QString::fromStdString(dev.name);
            selectedCaptureDeviceId = dev.id;
            selectedCaptureDeviceIdStruct = dev.deviceId;
            selectedCaptureSet = true;
            bool result = reinitializeDevice(true);
            qDebug() << "reinitializeDevice result:" << result;
            return result;
        }
    }
    qWarning() << "Capture device not found with id:" << QString::fromStdString(deviceId);
    return false;
}

// ============================================================================
// RECORDING
// ============================================================================

bool AudioEngine::startRecording(const std::string& outputPath)
{
    if (recording.load(std::memory_order_relaxed)) return false;
    if (outputPath.empty()) return false;

    if (!deviceRunning.load(std::memory_order_relaxed)) {
        if (!startAudioDevice()) return false;
    }

    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        recordingBuffer.clear();
        recordingBuffer.reserve(48000 * 2 * 60);
    }

    recordingOutputPath = outputPath;
    recordedFrames.store(0, std::memory_order_relaxed);
    recording.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopRecording()
{
    if (!recording.load(std::memory_order_relaxed)) return false;

    recording.store(false, std::memory_order_release);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    std::vector<float> samples;
    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        samples = std::move(recordingBuffer);
        recordingBuffer.clear();
    }

    if (samples.empty()) return false;

    return writeWavFile(recordingOutputPath, samples, 48000, 2);
}

bool AudioEngine::isRecording() const
{
    return recording.load(std::memory_order_relaxed);
}

float AudioEngine::getRecordingDuration() const
{
    uint64_t frames = recordedFrames.load(std::memory_order_relaxed);
    return static_cast<float>(frames) / 48000.0f;
}

bool AudioEngine::writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels)
{
    if (samples.empty() || path.empty()) return false;

    FILE* file = fopen(path.c_str(), "wb");
    if (!file) return false;

    uint32_t dataSize = static_cast<uint32_t>(samples.size() * sizeof(int16_t));
    uint32_t fileSize = 36 + dataSize;

    fwrite("RIFF", 1, 4, file);
    fwrite(&fileSize, 4, 1, file);
    fwrite("WAVE", 1, 4, file);

    fwrite("fmt ", 1, 4, file);
    uint32_t fmtSize = 16;
    fwrite(&fmtSize, 4, 1, file);

    uint16_t audioFormat = 1;
    fwrite(&audioFormat, 2, 1, file);

    uint16_t numChannels = static_cast<uint16_t>(channels);
    fwrite(&numChannels, 2, 1, file);

    uint32_t sampleRateU = static_cast<uint32_t>(sampleRate);
    fwrite(&sampleRateU, 4, 1, file);

    uint32_t byteRate = sampleRateU * numChannels * 2;
    fwrite(&byteRate, 4, 1, file);

    uint16_t blockAlign = static_cast<uint16_t>(numChannels * 2);
    fwrite(&blockAlign, 2, 1, file);

    uint16_t bitsPerSample = 16;
    fwrite(&bitsPerSample, 2, 1, file);

    fwrite("data", 1, 4, file);
    fwrite(&dataSize, 4, 1, file);

    for (size_t i = 0; i < samples.size(); ++i) {
        float sample = samples[i];
        if (sample > 1.0f) sample = 1.0f;
        if (sample < -1.0f) sample = -1.0f;

        int16_t pcmSample = static_cast<int16_t>(sample * 32767.0f);
        fwrite(&pcmSample, 2, 1, file);
    }

    fclose(file);
    return true;
}
