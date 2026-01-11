#define MINIAUDIO_IMPLEMENTATION
#include "audioEngine.h"

#include <QDebug>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <thread>

// ============================================================================
// CTOR/DTOR
// ============================================================================

AudioEngine::AudioEngine() = default;
AudioEngine::AudioEngine(void* parent) : AudioEngine() { (void)parent; }

AudioEngine::~AudioEngine()
{
    if (monitorRunning.load(std::memory_order_acquire)) {
        stopMonitorDevice();
    }
    if (monitorDevice) {
        ma_device_uninit(monitorDevice);
        delete monitorDevice;
        monitorDevice = nullptr;
    }

    stopRecordingInputDevice();
    if (recordingInputDevice) {
        ma_device_uninit(recordingInputDevice);
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
    }
    if (recordingInputRbData) {
        ma_pcm_rb_uninit(&recordingInputRb);
        std::free(recordingInputRbData);
        recordingInputRbData = nullptr;
    }

    if (deviceRunning.load(std::memory_order_acquire)) {
        stopAudioDevice();
    }

    for (int i = 0; i < MAX_CLIPS; ++i) {
        unloadClip(i);
    }

    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

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

    const float micFactor  = std::min(1.0f, (1.0f - currentBalance) * 2.0f);
    const float clipFactor = std::min(1.0f, currentBalance * 2.0f);

    const ma_uint32 totalOutputSamples = frameCount * playbackChannels;
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) out[i] = 0.0f;

    const bool doRecording = recording.load(std::memory_order_relaxed);
    std::vector<float> recMix;
    if (doRecording) {
        recMix.assign(frameCount * 2, 0.0f); // stereo interleaved
    }

           // Mic processing
    float micPeak = 0.0f;
    const bool passthroughEnabled = micPassthroughEnabled.load(std::memory_order_relaxed);
    const bool micIsEnabled       = micEnabled.load(std::memory_order_relaxed); // if false => muted => do NOT record

    if (mic && captureChannels > 0 && micIsEnabled) {
        for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
            float monoSample = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                monoSample += mic[frame * captureChannels + ch];
            }
            monoSample = (monoSample / static_cast<float>(captureChannels)) * currentMicGain;

            float absSample = std::abs(monoSample);
            if (absSample > micPeak) micPeak = absSample;

            if (passthroughEnabled) {
                ma_uint32 outIdx = frame * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels && (outIdx + ch) < totalOutputSamples; ++ch) {
                    out[outIdx + ch] += monoSample * micFactor;
                }
            }

                   // ✅ record mic ONLY if not muted
            if (doRecording) {
                const ma_uint32 ridx = frame * 2;
                recMix[ridx + 0] += monoSample * micFactor;
                recMix[ridx + 1] += monoSample * micFactor;
            }
        }

        float currentPeak = micPeakLevel.load(std::memory_order_relaxed);
        if (micPeak > currentPeak) micPeakLevel.store(micPeak, std::memory_order_relaxed);
    }

           // Mix clips
    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];

        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining) continue;

        const float clipGain      = slot.gain.load(std::memory_order_relaxed);
        const float finalClipGain = clipGain * clipFactor;

        void* pReadBuffer = nullptr;
        ma_uint32 availableFrames = frameCount;

        ma_result result = ma_pcm_rb_acquire_read(&slot.ringBufferMain, &availableFrames, &pReadBuffer);
        if (result == MA_SUCCESS && availableFrames > 0 && pReadBuffer) {
            auto* clipSamples = static_cast<float*>(pReadBuffer); // stereo interleaved (2ch)

                   // Output
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

                   // ✅ recording always includes clips
            if (doRecording) {
                const ma_uint32 n = std::min(availableFrames, frameCount);
                for (ma_uint32 frame = 0; frame < n; ++frame) {
                    const ma_uint32 ridx = frame * 2;
                    recMix[ridx + 0] += clipSamples[frame * 2]     * finalClipGain;
                    recMix[ridx + 1] += clipSamples[frame * 2 + 1] * finalClipGain;
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMain, availableFrames);

            slot.playbackFrameCount.fetch_add((long long)availableFrames, std::memory_order_relaxed);
            slot.queuedMainFrames.fetch_sub((long long)availableFrames, std::memory_order_relaxed);
        }
    }

           // ✅ Add recordingInputDevice ONLY if not disabled (-1)
    if (doRecording && selectedRecordingInputSet && recordingInputRunning.load(std::memory_order_relaxed)) {
        mixExtraInputIntoRecording(recMix.data(), frameCount);
    }

           // Master gain + peak (OUTPUT)
    const float currentMasterGain = masterGain.load(std::memory_order_relaxed);
    float outputPeak = 0.0f;

    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        out[i] *= currentMasterGain;
        float absSample = std::abs(out[i]);
        if (absSample > outputPeak) outputPeak = absSample;
    }

    float currentPeak = masterPeakLevel.load(std::memory_order_relaxed);
    if (outputPeak > currentPeak) masterPeakLevel.store(outputPeak, std::memory_order_relaxed);

           // Limiter (OUTPUT)
    for (ma_uint32 i = 0; i < totalOutputSamples; ++i) {
        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

           // Recording finalization
    if (doRecording) {
        for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
            const ma_uint32 ridx = frame * 2;
            recMix[ridx + 0] *= currentMasterGain;
            recMix[ridx + 1] *= currentMasterGain;

            recMix[ridx + 0] = std::max(-1.0f, std::min(1.0f, recMix[ridx + 0]));
            recMix[ridx + 1] = std::max(-1.0f, std::min(1.0f, recMix[ridx + 1]));
        }

        std::lock_guard<std::mutex> lock(recordingMutex);
        recordingBuffer.insert(recordingBuffer.end(), recMix.begin(), recMix.end());
        recordedFrames.fetch_add(frameCount, std::memory_order_relaxed);
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

        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining) continue;

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

        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

    float currentPeak = monitorPeakLevel.load(std::memory_order_relaxed);
    if (outputPeak > currentPeak) monitorPeakLevel.store(outputPeak, std::memory_order_relaxed);
}

// ============================================================================
// DECODER THREAD (your original, unchanged)
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
        std::cerr << "Decoder init failed for slot " << slotId << "\n";
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    slot->sampleRate.store((int)decoder.outputSampleRate, std::memory_order_relaxed);
    slot->channels.store((int)decoder.outputChannels, std::memory_order_relaxed);

    double initialStartMs = slot->trimStartMs.load(std::memory_order_relaxed);
    if (initialStartMs > 0) {
        ma_uint64 startFrame = static_cast<ma_uint64>((initialStartMs / 1000.0) * decoder.outputSampleRate);
        ma_decoder_seek_to_pcm_frame(&decoder, startFrame);
    }

    constexpr ma_uint32 kDecodeFrames = 1024;
    float decodeBuffer[kDecodeFrames * 2];

    bool naturalEnd = false;

    while (true) {

        while (slot->state.load(std::memory_order_acquire) == ClipState::Paused) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) {
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;

        double seekReq = slot->seekPosMs.exchange(-1.0, std::memory_order_relaxed);
        if (seekReq >= 0.0) {
            ma_uint64 targetFrame = static_cast<ma_uint64>((seekReq / 1000.0) * decoder.outputSampleRate);
            ma_decoder_seek_to_pcm_frame(&decoder, targetFrame);
            continue;
        }

        ma_uint64 framesRead = 0;
        ma_result readResult = ma_decoder_read_pcm_frames(&decoder, decodeBuffer, kDecodeFrames, &framesRead);

        if (readResult != MA_SUCCESS && readResult != MA_AT_END) break;

        if (framesRead == 0) {
            if (slot->loop.load(std::memory_order_relaxed)) {
                double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                ma_uint64 sFrame = static_cast<ma_uint64>((sMs / 1000.0) * decoder.outputSampleRate);
                ma_decoder_seek_to_pcm_frame(&decoder, sFrame);
                continue;
            }
            naturalEnd = true;
            break;
        }

        double endMs = slot->trimEndMs.load(std::memory_order_relaxed);
        if (endMs > 0) {
            ma_uint64 currentFrame = 0;
            ma_decoder_get_cursor_in_pcm_frames(&decoder, &currentFrame);
            ma_uint64 endFrame = static_cast<ma_uint64>((endMs / 1000.0) * decoder.outputSampleRate);

            if (currentFrame >= endFrame) {
                if (slot->loop.load(std::memory_order_relaxed)) {
                    double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                    ma_uint64 sFrame = static_cast<ma_uint64>((sMs / 1000.0) * decoder.outputSampleRate);
                    ma_decoder_seek_to_pcm_frame(&decoder, sFrame);
                } else {
                    naturalEnd = true;
                    break;
                }
            }
        }

        ma_uint32 framesRemaining = static_cast<ma_uint32>(framesRead);
        float* pReadCursor = decodeBuffer;

        while (framesRemaining > 0) {

            auto st = slot->state.load(std::memory_order_acquire);
            if (st == ClipState::Stopping) break;

            if (st == ClipState::Paused) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                continue;
            }

            void* wMain = nullptr;
            ma_uint32 toWriteMain = framesRemaining;

            ma_result a = ma_pcm_rb_acquire_write(&slot->ringBufferMain, &toWriteMain, &wMain);
            if (a == MA_SUCCESS && toWriteMain > 0 && wMain) {
                std::memcpy(wMain, pReadCursor, toWriteMain * 2 * sizeof(float));
                ma_pcm_rb_commit_write(&slot->ringBufferMain, toWriteMain);

                slot->queuedMainFrames.fetch_add((long long)toWriteMain, std::memory_order_relaxed);

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

    if (naturalEnd) {

        while (slot->state.load(std::memory_order_acquire) == ClipState::Paused) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }

        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) {
            slot->state.store(ClipState::Stopped, std::memory_order_release);
            return;
        }

        slot->state.store(ClipState::Draining, std::memory_order_release);

        while (true) {
            auto st = slot->state.load(std::memory_order_acquire);
            if (st == ClipState::Stopping) break;

            if (st == ClipState::Paused) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                continue;
            }

            const bool anyOutputRunning =
                engine->deviceRunning.load(std::memory_order_acquire) ||
                engine->monitorRunning.load(std::memory_order_acquire);
            if (!anyOutputRunning) break;

            if (slot->queuedMainFrames.load(std::memory_order_relaxed) <= 0) break;

            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }

        if (slot->state.load(std::memory_order_acquire) != ClipState::Stopping) {
            slot->state.store(ClipState::Stopped, std::memory_order_release);

            std::lock_guard<std::mutex> lock(engine->callbackMutex);
            if (engine->clipFinishedCallback) {
                engine->clipFinishedCallback(slotId);
            }
        }

        return;
    }

    slot->state.store(ClipState::Stopped, std::memory_order_release);
}

// ============================================================================
// CLIPS API (same behavior as your original)
// ============================================================================

std::pair<double, double> AudioEngine::loadClip(int slotId, const std::string& filepath)
{
    double startSec = 0.0;
    double endSec   = 0.0;

    if (slotId < 0 || slotId >= MAX_CLIPS) return {0.0, 0.0};
    if (filepath.empty()) return {0.0, 0.0};

    ClipSlot& slot = clips[slotId];

    if (slot.state.load(std::memory_order_relaxed) != ClipState::Stopped) return {0.0, 0.0};

    const size_t bufferSizeInBytes = RING_BUFFER_SIZE_IN_FRAMES * 2 * sizeof(float);

    if (slot.ringBufferMainData == nullptr) {
        slot.ringBufferMainData = std::malloc(bufferSizeInBytes);
        if (!slot.ringBufferMainData) return {0.0, 0.0};

        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES,
                       slot.ringBufferMainData, nullptr, &slot.ringBufferMain);
    }

    if (slot.ringBufferMonData == nullptr) {
        slot.ringBufferMonData = std::malloc(bufferSizeInBytes);
        if (!slot.ringBufferMonData) return {0.0, 0.0};

        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES,
                       slot.ringBufferMonData, nullptr, &slot.ringBufferMon);
    }

    ma_pcm_rb_reset(&slot.ringBufferMain);
    ma_pcm_rb_reset(&slot.ringBufferMon);

    slot.filePath = filepath;
    slot.gain.store(1.0f, std::memory_order_relaxed);
    slot.loop.store(false, std::memory_order_relaxed);
    slot.queuedMainFrames.store(0, std::memory_order_relaxed);
    slot.seekPosMs.store(-1.0, std::memory_order_relaxed);
    slot.playbackFrameCount.store(0, std::memory_order_relaxed);

    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, 48000);
    ma_decoder dec;

    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS &&
            dec.outputSampleRate > 0 && totalFrames > 0) {
            endSec = static_cast<double>(totalFrames) / static_cast<double>(dec.outputSampleRate);
            slot.totalDurationMs.store(endSec * 1000.0, std::memory_order_relaxed);
        } else {
            endSec = -1.0;
        }
        ma_decoder_uninit(&dec);
    } else {
        return {0.0, 0.0};
    }

    return {startSec, endSec};
}

void AudioEngine::playClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    ClipSlot& slot = clips[slotId];
    if (slot.filePath.empty()) return;

    if (slot.state.load(std::memory_order_acquire) == ClipState::Paused) {
        slot.state.store(ClipState::Playing, std::memory_order_release);
        return;
    }

    if (!isDeviceRunning() && !isMonitorRunning()) {
        return;
    }

    if (slot.decoderThread.joinable()) {
        slot.state.store(ClipState::Stopping, std::memory_order_release);
        slot.decoderThread.join();
    }

    ma_pcm_rb_reset(&slot.ringBufferMain);
    ma_pcm_rb_reset(&slot.ringBufferMon);

    slot.queuedMainFrames.store(0, std::memory_order_relaxed);

    if (slot.seekPosMs.load(std::memory_order_relaxed) < 0.0) {
        slot.playbackFrameCount.store(0, std::memory_order_relaxed);
    }

    slot.state.store(ClipState::Playing, std::memory_order_release);
    slot.decoderThread = std::thread(decoderThreadFunc, this, &slot, slotId);
}

double AudioEngine::getClipPlaybackPositionMs(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return 0.0;
    const ClipSlot& slot = clips[slotId];
    int sr = slot.sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0) sr = 48000;

    double frames = static_cast<double>(slot.playbackFrameCount.load(std::memory_order_relaxed));
    double startMs = slot.trimStartMs.load(std::memory_order_relaxed);

    double currentMs = (frames / static_cast<double>(sr)) * 1000.0;
    return startMs + currentMs;
}

void AudioEngine::seekClip(int slotId, double positionMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    clips[slotId].seekPosMs.store(positionMs, std::memory_order_relaxed);

    double startMs = clips[slotId].trimStartMs.load(std::memory_order_relaxed);
    double diffMs = positionMs - startMs;
    if (diffMs < 0) diffMs = 0;

    int sr = clips[slotId].sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0) sr = 48000;

    long long newFrames = static_cast<long long>(diffMs * sr / 1000.0);
    clips[slotId].playbackFrameCount.store(newFrames, std::memory_order_relaxed);
}

double AudioEngine::getFileDuration(const std::string& filepath)
{
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, 48000);
    ma_decoder dec;
    double duration = -1.0;

    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS &&
            dec.outputSampleRate > 0) {
            duration = static_cast<double>(totalFrames) / static_cast<double>(dec.outputSampleRate);
        }
        ma_decoder_uninit(&dec);
    }

    return duration;
}

void AudioEngine::pauseClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    auto state = clips[slotId].state.load(std::memory_order_acquire);
    if (state == ClipState::Playing || state == ClipState::Draining) {
        clips[slotId].state.store(ClipState::Paused, std::memory_order_release);
    }
}

void AudioEngine::resumeClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;

    auto state = clips[slotId].state.load(std::memory_order_acquire);
    if (state == ClipState::Paused) {
        clips[slotId].state.store(ClipState::Playing, std::memory_order_release);
    }
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

float AudioEngine::dBToLinear(float db)
{
    return pow(10.0f, db / 20.0f);
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

void AudioEngine::setClipTrim(int slotId, double startMs, double endMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].trimStartMs.store(startMs, std::memory_order_relaxed);
    clips[slotId].trimEndMs.store(endMs, std::memory_order_relaxed);
}

bool AudioEngine::isClipPlaying(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return false;
    auto st = clips[slotId].state.load(std::memory_order_relaxed);
    return (st == ClipState::Playing || st == ClipState::Draining || st == ClipState::Paused);
}

bool AudioEngine::isClipPaused(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return false;
    return clips[slotId].state.load(std::memory_order_relaxed) == ClipState::Paused;
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

    clips[slotId].queuedMainFrames.store(0, std::memory_order_relaxed);
}

// ============================================================================
// GAIN + PEAK API
// ============================================================================

void AudioEngine::setMicGainDB(float gainDB)
{
    micGainDB.store(gainDB, std::memory_order_relaxed);
    micGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMicGainDB() const { return micGainDB.load(std::memory_order_relaxed); }

void AudioEngine::setMasterGainDB(float gainDB)
{
    masterGainDB.store(gainDB, std::memory_order_relaxed);
    masterGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainDB() const { return masterGainDB.load(std::memory_order_relaxed); }

void AudioEngine::setMasterGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    masterGain.store(linear, std::memory_order_relaxed);
    masterGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainLinear() const { return masterGain.load(std::memory_order_relaxed); }

void AudioEngine::setMicGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    micGain.store(linear, std::memory_order_relaxed);
    micGainDB.store(20.0f * log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMicGainLinear() const { return micGain.load(std::memory_order_relaxed); }

void AudioEngine::setMonitorGainDB(float gainDB)
{
    monitorGainDB.store(gainDB, std::memory_order_relaxed);
    monitorGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getMonitorGainDB() const { return monitorGainDB.load(std::memory_order_relaxed); }

float AudioEngine::getMicPeakLevel() const { return micPeakLevel.load(std::memory_order_relaxed); }
float AudioEngine::getMasterPeakLevel() const { return masterPeakLevel.load(std::memory_order_relaxed); }
float AudioEngine::getMonitorPeakLevel() const { return monitorPeakLevel.load(std::memory_order_relaxed); }

void AudioEngine::resetPeakLevels()
{
    micPeakLevel.store(0.0f, std::memory_order_relaxed);
    masterPeakLevel.store(0.0f, std::memory_order_relaxed);
    monitorPeakLevel.store(0.0f, std::memory_order_relaxed);
}

void AudioEngine::setMicEnabled(bool enabled) { micEnabled.store(enabled, std::memory_order_relaxed); }
bool AudioEngine::isMicEnabled() const { return micEnabled.load(std::memory_order_relaxed); }

void AudioEngine::setMicPassthroughEnabled(bool enabled) { micPassthroughEnabled.store(enabled, std::memory_order_relaxed); }
bool AudioEngine::isMicPassthroughEnabled() const { return micPassthroughEnabled.load(std::memory_order_relaxed); }

void AudioEngine::setMicSoundboardBalance(float balance) { micBalance.store(balance, std::memory_order_relaxed); }
float AudioEngine::getMicSoundboardBalance() const { return micBalance.load(std::memory_order_relaxed); }

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

bool AudioEngine::applyDeviceSelection(ma_device_config& config)
{
    if (selectedPlaybackSet) config.playback.pDeviceID = &selectedPlaybackDeviceIdStruct;
    if (selectedCaptureSet)  config.capture.pDeviceID  = &selectedCaptureDeviceIdStruct;
    return true;
}

bool AudioEngine::initDevice()
{
    if (device) return true;
    if (!initContext()) return false;

    device = new ma_device();

    struct DeviceConfigTry {
        ma_format captureFormat;
        ma_uint32 captureChannels;
        ma_uint32 sampleRate;
        const char* description;
    };

    DeviceConfigTry configs[] = {
        { ma_format_f32, 2, 48000, "48kHz stereo f32" },
        { ma_format_f32, 1, 48000, "48kHz mono f32" },
        { ma_format_f32, 2, 44100, "44.1kHz stereo f32" },
        { ma_format_f32, 1, 44100, "44.1kHz mono f32" },
        { ma_format_s16, 2, 48000, "48kHz stereo s16" },
        { ma_format_s16, 1, 48000, "48kHz mono s16" },
        { ma_format_s16, 2, 44100, "44.1kHz stereo s16" },
        { ma_format_s16, 1, 44100, "44.1kHz mono s16" },
        { ma_format_unknown, 0, 0, "auto-detect all" },
        };

    ma_result result = MA_ERROR;

    for (const auto& cfgTry : configs) {
        ma_device_config config = ma_device_config_init(ma_device_type_duplex);
        config.playback.format   = ma_format_f32;
        config.playback.channels = 2;
        config.capture.format    = cfgTry.captureFormat;
        config.capture.channels  = cfgTry.captureChannels;
        config.sampleRate        = cfgTry.sampleRate;
        config.dataCallback      = AudioEngine::audioCallback;
        config.pUserData         = this;

        applyDeviceSelection(config);

        result = ma_device_init(context, &config, device);
        if (result == MA_SUCCESS) {
            mainSampleRate.store((int)device->sampleRate, std::memory_order_relaxed);
            return true;
        }
    }

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

bool AudioEngine::reinitializeDevice(bool restart)
{
    static std::mutex reinitMutex;
    std::lock_guard<std::mutex> lock(reinitMutex);

    bool wasRunning = deviceRunning.load(std::memory_order_acquire);

    if (wasRunning) {
        stopAudioDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

    if (!initDevice()) return false;

    if (restart || wasRunning) return startAudioDevice();
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
    cfg.playback.format   = ma_format_f32;
    cfg.playback.channels = 2;
    cfg.sampleRate        = 48000;
    cfg.dataCallback      = AudioEngine::monitorCallback;
    cfg.pUserData         = this;

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

// ============================================================================
// ENUMERATION + REFRESH
// ============================================================================

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
        info.id = info.name;
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
        info.id = info.name;
        info.isDefault = pCaptureInfos[i].isDefault;
        info.deviceId = pCaptureInfos[i].id;
        devices.push_back(info);
    }

    return devices;
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::refreshPlaybackDevices()
{
    return enumeratePlaybackDevices();
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::refreshInputDevices()
{
    return enumerateCaptureDevices();
}

// ============================================================================
// SELECTION
// ============================================================================

bool AudioEngine::setPlaybackDevice(const std::string& deviceId)
{
    auto devices = refreshPlaybackDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedPlaybackDeviceId       = dev.id;
            selectedPlaybackDeviceIdStruct = dev.deviceId;
            selectedPlaybackSet            = true;
            return reinitializeDevice(true);
        }
    }
    return false;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId)
{
    auto devices = refreshInputDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedCaptureDeviceId       = dev.id;
            selectedCaptureDeviceIdStruct = dev.deviceId;
            selectedCaptureSet            = true;
            return reinitializeDevice(true);
        }
    }
    return false;
}

bool AudioEngine::setMonitorPlaybackDevice(const std::string& deviceId)
{
    auto devices = refreshPlaybackDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedMonitorPlaybackDeviceId       = dev.id;
            selectedMonitorPlaybackDeviceIdStruct = dev.deviceId;
            selectedMonitorPlaybackSet            = true;
            return reinitializeMonitorDevice(true);
        }
    }
    return false;
}

// ============================================================================
// RECORDING INPUT DEVICE (3rd source)
// ============================================================================

bool AudioEngine::setRecordingInputDevice(const std::string& deviceId)
{
    // ✅ If user passes "-1": disable extra input recording (still record mic+clips)
    if (deviceId == "-1" || deviceId.empty()) {
        selectedRecordingInputSet = false;
        selectedRecordingInputDeviceId.clear();
        stopRecordingInputDevice();
        return true;
    }

    auto devices = refreshInputDevices();
    for (const auto& dev : devices) {
        if (dev.id == deviceId || dev.name == deviceId) {
            selectedRecordingInputDeviceId       = dev.id;
            selectedRecordingInputDeviceIdStruct = dev.deviceId;
            selectedRecordingInputSet            = true;

                   // If currently recording, restart the extra device immediately.
            const bool shouldRestart = recording.load(std::memory_order_relaxed);
            return reinitializeRecordingInputDevice(shouldRestart);
        }
    }
    return false;
}

bool AudioEngine::initRecordingInputDevice()
{
    if (!selectedRecordingInputSet) return true;
    if (recordingInputDevice) return true;
    if (!initContext()) return false;

    recordingInputDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
    cfg.capture.format   = ma_format_f32;
    cfg.capture.channels = 2;
    cfg.sampleRate       = (ma_uint32)mainSampleRate.load(std::memory_order_relaxed);
    cfg.dataCallback     = AudioEngine::recordingInputCallback;
    cfg.pUserData        = this;

    cfg.capture.pDeviceID = &selectedRecordingInputDeviceIdStruct;

    if (!recordingInputRbData) {
        const size_t bytes = (size_t)RING_BUFFER_SIZE_IN_FRAMES * 2 * sizeof(float);
        recordingInputRbData = std::malloc(bytes);
        if (!recordingInputRbData) return false;
        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES, recordingInputRbData, nullptr, &recordingInputRb);
    } else {
        ma_pcm_rb_reset(&recordingInputRb);
    }

    if (ma_device_init(context, &cfg, recordingInputDevice) != MA_SUCCESS) {
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
        return false;
    }

    return true;
}

bool AudioEngine::startRecordingInputDevice()
{
    if (!selectedRecordingInputSet) return true;
    if (!recordingInputDevice && !initRecordingInputDevice()) return false;

    if (recordingInputRunning.load(std::memory_order_relaxed)) return true;

    ma_pcm_rb_reset(&recordingInputRb);

    if (ma_device_start(recordingInputDevice) != MA_SUCCESS) return false;
    recordingInputRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopRecordingInputDevice()
{
    if (!recordingInputDevice) return false;
    recordingInputRunning.store(false, std::memory_order_release);
    ma_device_stop(recordingInputDevice);
    return true;
}

bool AudioEngine::reinitializeRecordingInputDevice(bool restart)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    const bool wasRunning = recordingInputRunning.load(std::memory_order_acquire);
    if (wasRunning) {
        stopRecordingInputDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    if (recordingInputDevice) {
        ma_device_uninit(recordingInputDevice);
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
    }

    if (!selectedRecordingInputSet) return true;

    if (!initRecordingInputDevice()) return false;

    if (restart || wasRunning) return startRecordingInputDevice();
    return true;
}

void AudioEngine::recordingInputCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !engine->recordingInputRunning.load(std::memory_order_acquire)) return;
    engine->processRecordingInput(pInput, frameCount, pDevice->capture.channels);
}

void AudioEngine::processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels)
{
    if (!input || captureChannels == 0) return;

    const float* in = static_cast<const float*>(input);

    ma_uint32 framesToWrite = frameCount;
    void* w = nullptr;

    while (framesToWrite > 0) {
        ma_uint32 n = framesToWrite;
        ma_result r = ma_pcm_rb_acquire_write(&recordingInputRb, &n, &w);
        if (r != MA_SUCCESS || n == 0 || !w) break;

        float* dst = static_cast<float*>(w);
        for (ma_uint32 f = 0; f < n; ++f) {
            float L = 0.0f, R = 0.0f;
            if (captureChannels == 1) {
                float s = in[f];
                L = s; R = s;
            } else {
                L = in[f * captureChannels + 0];
                R = in[f * captureChannels + 1];
            }
            dst[f * 2 + 0] = L;
            dst[f * 2 + 1] = R;
        }

        ma_pcm_rb_commit_write(&recordingInputRb, n);

        in += n * captureChannels;
        framesToWrite -= n;
    }
}

void AudioEngine::mixExtraInputIntoRecording(float* recStereoOut, ma_uint32 frameCount)
{
    if (!recStereoOut) return;

    void* pRead = nullptr;
    ma_uint32 availableFrames = frameCount;

    ma_result r = ma_pcm_rb_acquire_read(&recordingInputRb, &availableFrames, &pRead);
    if (r != MA_SUCCESS || availableFrames == 0 || !pRead) return;

    const float* src = static_cast<const float*>(pRead);

    for (ma_uint32 f = 0; f < availableFrames; ++f) {
        const ma_uint32 idx = f * 2;
        recStereoOut[idx + 0] += src[idx + 0];
        recStereoOut[idx + 1] += src[idx + 1];
    }

    ma_pcm_rb_commit_read(&recordingInputRb, availableFrames);
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

           // ✅ Start extra recording input device only if enabled (not "-1")
    if (selectedRecordingInputSet) {
        startRecordingInputDevice();
    }

    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        recordingBuffer.clear();
        const int sr = mainSampleRate.load(std::memory_order_relaxed);
        recordingBuffer.reserve((size_t)sr * 2 * 60);
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

           // ✅ stop extra input device (if running)
    if (selectedRecordingInputSet) {
        stopRecordingInputDevice();
    }

    std::vector<float> samples;
    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        samples = std::move(recordingBuffer);
        recordingBuffer.clear();
    }

    if (samples.empty()) return false;

    const int sr = mainSampleRate.load(std::memory_order_relaxed);
    return writeWavFile(recordingOutputPath, samples, sr, 2);
}

bool AudioEngine::isRecording() const
{
    return recording.load(std::memory_order_relaxed);
}

float AudioEngine::getRecordingDuration() const
{
    uint64_t frames = recordedFrames.load(std::memory_order_relaxed);
    int sr = mainSampleRate.load(std::memory_order_relaxed);
    if (sr <= 0) sr = 48000;
    return static_cast<float>(frames) / static_cast<float>(sr);
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
        float s = samples[i];
        s = std::max(-1.0f, std::min(1.0f, s));
        int16_t pcmSample = static_cast<int16_t>(s * 32767.0f);
        fwrite(&pcmSample, 2, 1, file);
    }

    fclose(file);
    return true;
}
