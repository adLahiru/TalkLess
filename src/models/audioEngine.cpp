#include "audioEngine.h"
#include <cmath>
#include <iostream>
#include <algorithm>
#include <QDebug>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
}

AudioEngine::AudioEngine()
    : device(nullptr)
    , context(nullptr)
    , deviceRunning(false)
    , micGain(1.0f)
    , micGainDB(0.0f)
    , masterGain(1.0f)
    , masterGainDB(0.0f)
    , micPeakLevel(0.0f)
    , masterPeakLevel(0.0f)
{
    avformat_network_init();
    
    // Initialize all clip slots
    for (int i = 0; i < MAX_CLIPS; ++i) {
        clips[i].ringBufferData = nullptr;
    }
}

AudioEngine::AudioEngine(void* parent) : AudioEngine() {
    (void)parent;
}

AudioEngine::~AudioEngine() {
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

void AudioEngine::audioCallback(ma_device* pDevice, void* pOutput, 
                                const void* pInput, ma_uint32 frameCount) {
    AudioEngine* engine = (AudioEngine*)pDevice->pUserData;
    if (engine) {
        engine->processAudio(pOutput, pInput, frameCount, 
                           pDevice->playback.channels);
    }
}

void AudioEngine::processAudio(void* output, const void* input, 
                               ma_uint32 frameCount, ma_uint32 channels) {
    float* out = (float*)output;
    const float* mic = (const float*)input;
    
    // Load mic gain once (atomic read)
    float currentMicGain = micGain.load(std::memory_order_relaxed);
    
    // Zero output buffer first
    const ma_uint32 totalSamples = frameCount * channels;
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        out[i] = 0.0f;
    }
    
    // Mix microphone input and detect peak level
    float micPeak = 0.0f;
    if (mic) {
        for (ma_uint32 i = 0; i < totalSamples; ++i) {
            float sample = mic[i] * currentMicGain;
            out[i] += sample;
            
            // Track peak level
            float absSample = std::abs(sample);
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
        
        ma_result result = ma_pcm_rb_acquire_read(&slot.ringBuffer, 
                                                   &availableFrames, 
                                                   &pReadBuffer);
        
        if (result == MA_SUCCESS && availableFrames > 0) {
            float* clipSamples = (float*)pReadBuffer;
            
            // CRITICAL: Ring buffer is ALWAYS stereo (2 channels)
            // Device may have different channel count - need to mix correctly
            if (channels == 2) {
                // Device is stereo - direct copy
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    ma_uint32 outIdx = frame * 2;
                    if (outIdx + 1 < totalSamples) {
                        out[outIdx] += clipSamples[frame * 2] * clipGain;      // Left
                        out[outIdx + 1] += clipSamples[frame * 2 + 1] * clipGain; // Right
                    }
                }
            } else {
                // Device has different channels - mix down/up as needed
                for (ma_uint32 frame = 0; frame < availableFrames; ++frame) {
                    float left = clipSamples[frame * 2] * clipGain;
                    float right = clipSamples[frame * 2 + 1] * clipGain;
                    float mono = (left + right) * 0.5f; // Mix to mono
                    
                    ma_uint32 outIdx = frame * channels;
                    for (ma_uint32 ch = 0; ch < channels && outIdx + ch < totalSamples; ++ch) {
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
    
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
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
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        if (out[i] > 1.0f)  out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }
}

// ============================================================================
// DECODER THREAD (RUNS IN BACKGROUND, FILLS RING BUFFER)
// ============================================================================

void AudioEngine::decoderThreadFunc(ClipSlot* slot, int slotId) {
    // Snapshot filepath
    std::string filepath = slot->filePath;

    std::cout << "[Decoder " << slotId << "] Starting: " << filepath << std::endl;

    if (filepath.empty()) {
        std::cerr << "[Decoder " << slotId << "] FATAL: empty filepath" << std::endl;
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    // FFmpeg objects (declared at function scope to avoid goto issues)
    AVFormatContext* fmtCtx = nullptr;
    AVCodecContext* codecCtx = nullptr;
    SwrContext* swr = nullptr;
    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    uint8_t* outData = nullptr;
    int outLinesize = 0;
    int audioStreamIndex = -1;
    int maxOutSamples = 0;
    bool shouldLoop = false;
    int framesWritten = 0;

    // Suppress FFmpeg warnings
    av_log_set_level(AV_LOG_ERROR);

    // Open input file
    if (avformat_open_input(&fmtCtx, filepath.c_str(), nullptr, nullptr) < 0 ||
        avformat_find_stream_info(fmtCtx, nullptr) < 0) {
        std::cerr << "[Decoder " << slotId << "] Failed to open file" << std::endl;
        goto cleanup;
    }

    // Find audio stream
    for (unsigned i = 0; i < fmtCtx->nb_streams; ++i) {
        if (fmtCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex = i;
            break;
        }
    }

    if (audioStreamIndex < 0) {
        std::cerr << "[Decoder " << slotId << "] No audio stream" << std::endl;
        goto cleanup;
    }

    // Open decoder
    {
        const AVCodec* codec = avcodec_find_decoder(fmtCtx->streams[audioStreamIndex]->codecpar->codec_id);
        if (!codec) {
            std::cerr << "[Decoder " << slotId << "] Codec not found" << std::endl;
            goto cleanup;
        }

        codecCtx = avcodec_alloc_context3(codec);
        avcodec_parameters_to_context(codecCtx, fmtCtx->streams[audioStreamIndex]->codecpar);
        
        if (avcodec_open2(codecCtx, codec, nullptr) < 0) {
            std::cerr << "[Decoder " << slotId << "] Failed to open codec" << std::endl;
            goto cleanup;
        }
    }

    // Fix missing channel layout
    if (codecCtx->ch_layout.nb_channels == 0) {
        av_channel_layout_default(&codecCtx->ch_layout, 2);
    }

    // Save format info
    slot->sampleRate.store(codecCtx->sample_rate, std::memory_order_relaxed);
    slot->channels.store(2, std::memory_order_relaxed);

    // Setup resampler (use modern channel layout API)
    {
        AVChannelLayout outLayout = AV_CHANNEL_LAYOUT_STEREO;
        swr = swr_alloc();
        av_opt_set_chlayout(swr, "in_chlayout", &codecCtx->ch_layout, 0);
        av_opt_set_chlayout(swr, "out_chlayout", &outLayout, 0);
        av_opt_set_int(swr, "in_sample_rate", codecCtx->sample_rate, 0);
        av_opt_set_int(swr, "out_sample_rate", 48000, 0);
        av_opt_set_sample_fmt(swr, "in_sample_fmt", codecCtx->sample_fmt, 0);
        av_opt_set_sample_fmt(swr, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
        
        if (swr_init(swr) < 0) {
            std::cerr << "[Decoder " << slotId << "] Failed to init resampler" << std::endl;
            goto cleanup;
        }
    }

    // Pre-allocate output buffer (generous size to handle any frame)
    maxOutSamples = av_rescale_rnd(4096, 48000, codecCtx->sample_rate, AV_ROUND_UP);
    if (av_samples_alloc(&outData, &outLinesize, 2, maxOutSamples, AV_SAMPLE_FMT_FLT, 0) < 0) {
        std::cerr << "[Decoder " << slotId << "] Failed to allocate output buffer" << std::endl;
        goto cleanup;
    }

    std::cout << "[Decoder " << slotId << "] Decoding started" << std::endl;
    std::cout << "[Decoder " << slotId << "] Ring buffer capacity: " << RING_BUFFER_SIZE_IN_FRAMES << " frames" << std::endl;

    // Decode loop
    do {
        // Stop requested?
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) {
            std::cout << "[Decoder " << slotId << "] Stop requested" << std::endl;
            break;
        }

        int ret = av_read_frame(fmtCtx, pkt);
        if (ret < 0) {  // EOF or error
            if (ret == AVERROR_EOF) {
                // Flush decoder
                avcodec_send_packet(codecCtx, nullptr);
                while (avcodec_receive_frame(codecCtx, frame) == 0) {
                    // Resample and write to ring buffer
                    int outSamples = swr_get_out_samples(swr, frame->nb_samples);
                    int converted = swr_convert(swr, &outData, outSamples,
                                              (const uint8_t**)frame->data, frame->nb_samples);
                    if (converted > 0) {
                        void* pWrite;
                        ma_uint32 frames = converted;
                        if (ma_pcm_rb_acquire_write(&slot->ringBuffer, &frames, &pWrite) == MA_SUCCESS && frames > 0) {
                            memcpy(pWrite, outData, frames * 2 * sizeof(float));
                            ma_pcm_rb_commit_write(&slot->ringBuffer, frames);
                        }
                        // Drop remaining samples if ring buffer is full (non-blocking)
                    }
                }

                // Check loop
                shouldLoop = slot->loop.load(std::memory_order_relaxed);
                if (shouldLoop) {
                    std::cout << "[Decoder " << slotId << "] Looping" << std::endl;
                    av_seek_frame(fmtCtx, audioStreamIndex, 0, AVSEEK_FLAG_BACKWARD);
                    avcodec_flush_buffers(codecCtx);
                    continue;
                } else {
                    std::cout << "[Decoder " << slotId << "] Finished" << std::endl;
                    break;
                }
            } else {
                std::cerr << "[Decoder " << slotId << "] Read error: " << ret << std::endl;
                break;
            }
        }

        if (pkt->stream_index == audioStreamIndex) {
            avcodec_send_packet(codecCtx, pkt);
            
            while (avcodec_receive_frame(codecCtx, frame) == 0) {
                // Resample and write to ring buffer
                int outSamples = swr_get_out_samples(swr, frame->nb_samples);
                int converted = swr_convert(swr, &outData, outSamples,
                                          (const uint8_t**)frame->data, frame->nb_samples);
                if (converted > 0) {
                    void* pWrite;
                    ma_uint32 frames = converted;
                    if (ma_pcm_rb_acquire_write(&slot->ringBuffer, &frames, &pWrite) == MA_SUCCESS && frames > 0) {
                        memcpy(pWrite, outData, frames * 2 * sizeof(float));
                        ma_pcm_rb_commit_write(&slot->ringBuffer, frames);
                        framesWritten += frames;
                        if (framesWritten < 5000) { // Debug first few writes
                            std::cout << "[Decoder " << slotId << "] Wrote " << frames << " frames to ring buffer" << std::endl;
                        }
                    } else if (frames == 0) {
                        // Ring buffer full - drop samples (non-blocking)
                        if (framesWritten % 10000 == 0) {
                            std::cout << "[Decoder " << slotId << "] Ring buffer full, dropping samples" << std::endl;
                        }
                    }
                }
            }
        }

        av_packet_unref(pkt);
    } while (true);

cleanup:
    if (outData) av_freep(&outData);
    av_frame_free(&frame);
    av_packet_free(&pkt);
    swr_free(&swr);
    avcodec_free_context(&codecCtx);
    if (fmtCtx) avformat_close_input(&fmtCtx);

    slot->state.store(ClipState::Stopped, std::memory_order_release);
    std::cout << "[Decoder " << slotId << "] Thread exiting" << std::endl;
}


// ============================================================================
// PUBLIC API (THREAD-SAFE, CALLED FROM QT UI THREAD)
// ============================================================================

bool AudioEngine::loadClip(int slotId, const std::string& filepath) {
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
        
        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES, 
                      slot.ringBufferData, nullptr, &slot.ringBuffer);
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

void AudioEngine::playClip(int slotId) {
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

void AudioEngine::stopClip(int slotId) {
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    
    ClipSlot& slot = clips[slotId];
    
    // Signal decoder to stop
    slot.state.store(ClipState::Stopping, std::memory_order_release);
    
    // Wait for decoder thread to finish
    if (slot.decoderThread.joinable()) {
        slot.decoderThread.join();
    }
    
    std::cout << "Stopped clip slot " << slotId << std::endl;
}

void AudioEngine::setClipLoop(int slotId, bool loop) {
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].loop.store(loop, std::memory_order_relaxed);
    qDebug() << "Set clip" << slotId << "loop to" << loop;
}

void AudioEngine::setClipGain(int slotId, float gainDB) {
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    float linear = dBToLinear(gainDB);
    clips[slotId].gain.store(linear, std::memory_order_relaxed);
    qDebug() << "Set clip" << slotId << "gain to" << gainDB << "dB (linear:" << linear << ")";
}

float AudioEngine::getClipGain(int slotId) const {
    if (slotId < 0 || slotId >= MAX_CLIPS) return 0.0f;
    float linear = clips[slotId].gain.load(std::memory_order_relaxed);
    float gainDB = 20.0f * log10(linear);
    qDebug() << "Getting clip" << slotId << "gain:" << gainDB << "dB";
    return gainDB;
}

bool AudioEngine::isClipPlaying(int slotId) const {
    if (slotId < 0 || slotId >= MAX_CLIPS) return false;
    return clips[slotId].state.load(std::memory_order_relaxed) == ClipState::Playing;
}

void AudioEngine::unloadClip(int slotId) {
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    
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

void AudioEngine::setMicGainDB(float gainDB) {
    micGainDB.store(gainDB, std::memory_order_relaxed);
    micGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
    qDebug() << "Set mic gain dB to:" << gainDB;
}

float AudioEngine::getMicGainDB() const {
    qDebug() << "Getting mic gain dB:" << micGainDB.load(std::memory_order_relaxed);
    return micGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainDB(float gainDB) {
    masterGainDB.store(gainDB, std::memory_order_relaxed);
    masterGain.store(dBToLinear(gainDB), std::memory_order_relaxed);
    qDebug() << "Set master gain to" << gainDB << "dB (linear:" << dBToLinear(gainDB) << ")";
}

float AudioEngine::getMasterGainDB() const {
    return masterGainDB.load(std::memory_order_relaxed);
}

// Real-time audio level monitoring
float AudioEngine::getMicPeakLevel() const {
    return micPeakLevel.load(std::memory_order_relaxed);
}

float AudioEngine::getMasterPeakLevel() const {
    return masterPeakLevel.load(std::memory_order_relaxed);
}

void AudioEngine::resetPeakLevels() {
    micPeakLevel.store(0.0f, std::memory_order_relaxed);
    masterPeakLevel.store(0.0f, std::memory_order_relaxed);
}

// Event callbacks
void AudioEngine::setClipFinishedCallback(ClipFinishedCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipFinishedCallback = callback;
}

void AudioEngine::setClipErrorCallback(ClipErrorCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipErrorCallback = callback;
}


// ============================================================================
// DEVICE INITIALIZATION
// ============================================================================

bool AudioEngine::initContext() {
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

bool AudioEngine::initDevice() {
    if (device) return true;
    
    if (!initContext()) return false;
    
    device = new ma_device();
    ma_device_config config = ma_device_config_init(ma_device_type_duplex);
    config.playback.format   = ma_format_f32;
    config.playback.channels = 2;
    config.capture.format    = ma_format_f32;
    config.capture.channels  = 2;
    config.sampleRate        = 48000;
    config.dataCallback      = AudioEngine::audioCallback;
    config.pUserData         = this;
    
    if (ma_device_init(context, &config, device) != MA_SUCCESS) {
        std::cerr << "Failed to initialize audio device" << std::endl;
        delete device;
        device = nullptr;
        return false;
    }
    
    std::cout << "Audio device initialized" << std::endl;
    return true;
}

bool AudioEngine::startAudioDevice() {
    if (!device && !initDevice()) return false;
    
    if (ma_device_start(device) != MA_SUCCESS) {
        std::cerr << "Failed to start audio device" << std::endl;
        return false;
    }
    
    deviceRunning.store(true, std::memory_order_release);
    std::cout << "Audio device started" << std::endl;
    return true;
}

bool AudioEngine::stopAudioDevice() {
    if (!device) return false;
    
    if (ma_device_stop(device) != MA_SUCCESS) {
        std::cerr << "Failed to stop audio device" << std::endl;
        return false;
    }
    
    deviceRunning.store(false, std::memory_order_release);
    std::cout << "Audio device stopped" << std::endl;
    return true;
}

bool AudioEngine::isDeviceRunning() const {
    return deviceRunning.load(std::memory_order_relaxed);
}

// ============================================================================
// HELPERS
// ============================================================================

float AudioEngine::dBToLinear(float db) {
    return pow(10.0f, db / 20.0f);
}

// Device enumeration (same as before)
std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumeratePlaybackDevices() {
    std::vector<AudioDeviceInfo> devices;
    if (!initContext()) return devices;
    
    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;
    
    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, 
                               &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }
    
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pPlaybackInfos[i].name);
        info.id = std::to_string(i);
        info.isDefault = pPlaybackInfos[i].isDefault;
        devices.push_back(info);
    }
    
    return devices;
}

std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumerateCaptureDevices() {
    std::vector<AudioDeviceInfo> devices;
    if (!initContext()) return devices;
    
    ma_device_info* pPlaybackInfos;
    ma_uint32 playbackCount;
    ma_device_info* pCaptureInfos;
    ma_uint32 captureCount;
    
    if (ma_context_get_devices(context, &pPlaybackInfos, &playbackCount, 
                               &pCaptureInfos, &captureCount) != MA_SUCCESS) {
        return devices;
    }
    
    for (ma_uint32 i = 0; i < captureCount; ++i) {
        AudioDeviceInfo info;
        info.name = std::string(pCaptureInfos[i].name);
        info.id = std::to_string(i);
        info.isDefault = pCaptureInfos[i].isDefault;
        devices.push_back(info);
    }
    
    return devices;
}

bool AudioEngine::setPlaybackDevice(const std::string& deviceId) {
    if (deviceRunning.load(std::memory_order_relaxed)) {
        std::cerr << "Stop device before changing" << std::endl;
        return false;
    }
    selectedPlaybackDeviceId = deviceId;
    return true;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId) {
    if (deviceRunning.load(std::memory_order_relaxed)) {
        std::cerr << "Stop device before changing" << std::endl;
        return false;
    }
    selectedCaptureDeviceId = deviceId;
    return true;
}
