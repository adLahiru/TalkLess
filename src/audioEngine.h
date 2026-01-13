#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

// miniaudio implementation is in miniaudio_impl.cpp
#include "miniaudio.h"

// ===============================
// AudioEngine
// - Main duplex device: playback + mic capture
// - Monitor playback-only device: plays clips only (secondary output)
// - Optional recording input capture device: separate capture device
// - Clips decoded in background threads into ring buffers
// - Recording produces WAV 48kHz stereo 16-bit PCM
// ===============================

class AudioEngine
{
public:
    struct AudioDeviceInfo {
        std::string name;
        std::string id;      // for your UI you used name as id
        bool isDefault = false;
        ma_device_id deviceId{};
    };

    using ClipFinishedCallback = std::function<void(int slotId)>;
    using ClipErrorCallback    = std::function<void(int slotId)>;
    using ClipLoopedCallback   = std::function<void(int slotId)>;

    static constexpr int MAX_CLIPS = 16;
    static constexpr ma_uint32 ENGINE_SR = 48000;

    AudioEngine();
    explicit AudioEngine(void* parent);
    ~AudioEngine();

    // ---------------------------
    // Devices (Main)
    // ---------------------------
    bool startAudioDevice();
    bool stopAudioDevice();
    bool isDeviceRunning() const;

    // ---------------------------
    // Devices (Monitor)
    // ---------------------------
    bool startMonitorDevice();
    bool stopMonitorDevice();
    bool isMonitorRunning() const;

    // ---------------------------
    // Device enumeration
    // ---------------------------
    std::vector<AudioDeviceInfo> enumeratePlaybackDevices();
    std::vector<AudioDeviceInfo> enumerateCaptureDevices();

    // Re-scan devices after hotplug.
    // This will rebuild the context and re-init devices (optionally restarting running devices).
    bool refreshPlaybackDevices(); // for headphones/speakers hotplug
    bool refreshInputDevices();    // for mic/inputs hotplug

    // ---------------------------
    // Device selection
    // ---------------------------
    // Pre-select devices (use before starting, does not reinitialize)
    bool preselectPlaybackDevice(const std::string& deviceId);
    bool preselectCaptureDevice(const std::string& deviceId);
    bool preselectMonitorPlaybackDevice(const std::string& deviceId);
    
    // Set devices (use after starting, reinitializes device)
    bool setPlaybackDevice(const std::string& deviceId);
    bool setCaptureDevice(const std::string& deviceId);
    bool setMonitorPlaybackDevice(const std::string& deviceId);

    // Recording extra input device (capture-only).
    // Pass "-1" or "" to disable.
    bool setRecordingDevice(const std::string& deviceId);

    // ---------------------------
    // Mixer controls
    // ---------------------------
    void  setMicEnabled(bool enabled);
    bool  isMicEnabled() const;

    void  setMicPassthroughEnabled(bool enabled);
    bool  isMicPassthroughEnabled() const;

    void  setMicGainDB(float gainDB);
    float getMicGainDB() const;

    void  setMicGainLinear(float linear);
    float getMicGainLinear() const;

    void  setMasterGainDB(float gainDB);
    float getMasterGainDB() const;

    void  setMasterGainLinear(float linear);
    float getMasterGainLinear() const;

    // Balance: 0.0 mic only, 0.5 both full, 1.0 clips only
    void  setMicSoundboardBalance(float balance);
    float getMicSoundboardBalance() const;

    // Peaks
    float getMicPeakLevel() const;
    float getMasterPeakLevel() const;
    float getMonitorPeakLevel() const;
    void  resetPeakLevels();

    // ---------------------------
    // Clips API
    // ---------------------------
    std::pair<double, double> loadClip(int slotId, const std::string& filepath);
    void playClip(int slotId);
    void pauseClip(int slotId);
    void resumeClip(int slotId);
    void stopClip(int slotId);

    void setClipLoop(int slotId, bool loop);
    void setClipGain(int slotId, float gainDB);
    float getClipGain(int slotId) const;

    void setClipTrim(int slotId, double startMs, double endMs);
    void seekClip(int slotId, double positionMs);

    bool isClipPlaying(int slotId) const;
    bool isClipPaused(int slotId) const;

    double getClipPlaybackPositionMs(int slotId) const;
    double getFileDuration(const std::string& filepath);

    void unloadClip(int slotId);

    // ---------------------------
    // Recording (WAV)
    // - Records: Mic (if enabled) + Clips + RecordingInputDevice (if enabled and not "-1")
    // - Always outputs stereo 48kHz
    // ---------------------------
    bool startRecording(const std::string& outputPath);
    bool stopRecording();
    bool isRecording() const;
    float getRecordingDuration() const;

    // ---------------------------
    // Callbacks
    // ---------------------------
    void setClipFinishedCallback(ClipFinishedCallback callback);
    void setClipErrorCallback(ClipErrorCallback callback);
    void setClipLoopedCallback(ClipLoopedCallback callback);

private:
    enum class ClipState { Stopped, Playing, Paused, Draining, Stopping };

    struct ClipSlot {
        std::atomic<ClipState> state{ClipState::Stopped};

        std::string filePath;

        std::atomic<float> gain{1.0f};
        std::atomic<bool>  loop{false};

        std::atomic<double> trimStartMs{0.0};
        std::atomic<double> trimEndMs{0.0};

        std::atomic<double> seekPosMs{-1.0};

        std::atomic<long long> playbackFrameCount{0};
        std::atomic<long long> queuedMainFrames{0};

        std::atomic<int> sampleRate{(int)ENGINE_SR};
        std::atomic<int> channels{2};
        std::atomic<double> totalDurationMs{0.0};

        std::atomic<uint64_t> playToken {0};

        // Ring buffers (float stereo)
        void*     ringBufferMainData = nullptr;
        void*     ringBufferMonData  = nullptr;
        
        ma_pcm_rb ringBufferMain{};
        ma_pcm_rb ringBufferMon{};

        std::thread decoderThread;
    };

private:
    // Core init
    bool initContext();
    bool initDevice();
    bool initMonitorDevice();

    bool applyDeviceSelection(ma_device_config& config);
    bool reinitializeDevice(bool restart);
    bool reinitializeMonitorDevice(bool restart);

    // Recording-input capture device (separate)
    bool initRecordingInputDevice();
    bool startRecordingInputDevice();
    bool stopRecordingInputDevice();
    bool reinitializeRecordingInputDevice(bool restart);
    void shutdownRecordingInputDevice();

    // Context rebuild (hotplug refresh)
    bool rebuildContextAndDevices(bool restartRunning);
    
    // Refresh device ID structs after context rebuild (lookup by string ID)
    void refreshDeviceIdStructs();

    // DSP helpers
    static float dBToLinear(float db);
    static void  computeBalanceMultipliers(float balance, float& micMul, float& clipMul);

    // Main audio callback
    static void audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    
    void processAudio(void* output,
                               const void* input,
                               ma_uint32 frameCount,
                               ma_uint32 playbackChannels,
                               ma_uint32 captureChannels,
                               ma_format captureFormat);

    // Monitor callback
    static void monitorCallback(ma_device* pDevice, void* pOutput, const void*, ma_uint32 frameCount);
    void processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels);

    // Recording-input callback
    static void recordingInputCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount);
    void processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels);

    // Decoder thread
    static void decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId, uint64_t token);

    // WAV writer
    bool writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels);

private:
    // Context
    ma_context* context = nullptr;

    // Main duplex device
    ma_device* device = nullptr;
    std::atomic<bool> deviceRunning{false};

    // Monitor device
    ma_device* monitorDevice = nullptr;
    std::atomic<bool> monitorRunning{false};

    // Optional recording input capture device
    ma_device* recordingInputDevice = nullptr;
    std::atomic<bool> recordingInputRunning{false};
    std::atomic<bool> recordingInputEnabled{false};

    // ring buffer for recording-input mono frames
    void*     recordingInputRbData = nullptr;
    ma_pcm_rb recordingInputRb{};
    std::atomic<int> recordingInputCaptureChannels{0};

    // Selected device IDs
    bool selectedPlaybackSet = false;
    bool selectedCaptureSet = false;
    bool selectedMonitorPlaybackSet = false;
    bool selectedRecordingCaptureSet = false;

    std::string selectedPlaybackDeviceId;
    std::string selectedCaptureDeviceId;
    std::string selectedMonitorPlaybackDeviceId;
    std::string selectedRecordingCaptureDeviceId;

    ma_device_id selectedPlaybackDeviceIdStruct{};
    ma_device_id selectedCaptureDeviceIdStruct{};
    ma_device_id selectedMonitorPlaybackDeviceIdStruct{};
    ma_device_id selectedRecordingCaptureDeviceIdStruct{};

    // Mixer
    std::atomic<float> micGainDB{0.0f};
    std::atomic<float> micGain{1.0f};

    std::atomic<float> masterGainDB{0.0f};
    std::atomic<float> masterGain{1.0f};

    std::atomic<bool> micEnabled{true};
    std::atomic<bool> micPassthroughEnabled{true};

    std::atomic<float> micSoundboardBalance{0.5f};

    // Peaks
    std::atomic<float> micPeakLevel{0.0f};
    std::atomic<float> masterPeakLevel{0.0f};
    std::atomic<float> monitorPeakLevel{0.0f};

    // Clips
    ClipSlot clips[MAX_CLIPS];

    static constexpr ma_uint32 RING_BUFFER_SIZE_IN_FRAMES = ENGINE_SR * 2; // ~2 seconds stereo
    static constexpr ma_uint32 RECINPUT_RB_SIZE_FRAMES    = ENGINE_SR * 5; // 5 seconds mono

    // Callbacks
    std::mutex callbackMutex;
    ClipFinishedCallback clipFinishedCallback;
    ClipErrorCallback clipErrorCallback;
    ClipLoopedCallback clipLoopedCallback;

    // Recording
    std::atomic<bool> recording{false};
    std::mutex recordingMutex;
    std::vector<float> recordingBuffer; // float stereo interleaved
    std::string recordingOutputPath;
    std::atomic<uint64_t> recordedFrames{0};
};
