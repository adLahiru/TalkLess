#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

// DO NOT put MINIAUDIO_IMPLEMENTATION in a header.
// Define it in exactly one .cpp (e.g., audioEngine.cpp).
#include "miniaudio.h"

class AudioEngine
{
public:
    // ------------------------------------------------------------
    // Types
    // ------------------------------------------------------------
    struct AudioDeviceInfo {
        std::string name;
        std::string id;     // using name as ID (matches your UI behavior)
        bool isDefault = false;
        ma_device_id deviceId{};
    };

    using ClipFinishedCallback = std::function<void(int)>;
    using ClipErrorCallback    = std::function<void(int)>;
    using ClipLoopedCallback   = std::function<void(int)>;

    // ------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------
    static constexpr ma_uint32 DEFAULT_SAMPLE_RATE     = 48000;
    static constexpr ma_uint32 DEFAULT_BUFFER_SIZE     = 512;
    static constexpr ma_uint32 DEFAULT_BUFFER_PERIODS  = 3;
    static constexpr ma_uint32 DEFAULT_CHANNELS        = 2;
    static constexpr int       MAX_CLIPS               = 8;

    // ------------------------------------------------------------
    // CTOR/DTOR
    // ------------------------------------------------------------
    AudioEngine();
    explicit AudioEngine(void* parent);
    ~AudioEngine();

    // ------------------------------------------------------------
    // Audio Configuration
    // ------------------------------------------------------------
    void setAudioConfig(ma_uint32 sampleRate, ma_uint32 bufferSize, ma_uint32 periods, ma_uint32 channels);

    // ------------------------------------------------------------
    // Devices / context
    // ------------------------------------------------------------
    bool initContext();

    // Two-device main pipeline:
    bool initPlaybackDevice();
    bool initCaptureDevice();

    bool startAudioDevice();
    bool stopAudioDevice();
    bool isDeviceRunning() const;

    // Monitor device (clips-only output)
    bool initMonitorDevice();
    bool startMonitorDevice();
    bool stopMonitorDevice();
    bool isMonitorRunning() const;

    // Optional recording-input device (capture-only)
    bool initRecordingInputDevice();
    bool startRecordingInputDevice();
    bool stopRecordingInputDevice();
    void shutdownRecordingInputDevice();
    bool reinitializeRecordingInputDevice(bool restart);

    // Hotplug refresh
    bool refreshPlaybackDevices();
    bool refreshInputDevices();
    bool rebuildContextAndDevices(bool restartRunning);
    void refreshDeviceIdStructs();

    // Enumeration
    std::vector<AudioDeviceInfo> enumeratePlaybackDevices();
    std::vector<AudioDeviceInfo> enumerateCaptureDevices();

    // Device selection
    bool preselectPlaybackDevice(const std::string& deviceId);
    bool preselectCaptureDevice(const std::string& deviceId);
    bool preselectMonitorPlaybackDevice(const std::string& deviceId);

    bool setPlaybackDevice(const std::string& deviceId);
    bool setCaptureDevice(const std::string& deviceId);
    bool setMonitorPlaybackDevice(const std::string& deviceId);

    // Recording extra input device selection
    bool setRecordingDevice(const std::string& deviceId);

    // ------------------------------------------------------------
    // Mixer controls
    // ------------------------------------------------------------
    void setMicEnabled(bool enabled);
    bool isMicEnabled() const;

    void setMicPassthroughEnabled(bool enabled);
    bool isMicPassthroughEnabled() const;

    void setMicGainDB(float gainDB);
    float getMicGainDB() const;
    void setMicGainLinear(float linear);
    float getMicGainLinear() const;

    void setMasterGainDB(float gainDB);
    float getMasterGainDB() const;
    void setMasterGainLinear(float linear);
    float getMasterGainLinear() const;

    void setMicSoundboardBalance(float balance);
    float getMicSoundboardBalance() const;

    // Peak meters
    float getMicPeakLevel() const;
    float getMasterPeakLevel() const;
    float getMonitorPeakLevel() const;
    void resetPeakLevels();

    // ------------------------------------------------------------
    // Callbacks
    // ------------------------------------------------------------
    void setClipFinishedCallback(ClipFinishedCallback cb);
    void setClipErrorCallback(ClipErrorCallback cb);
    void setClipLoopedCallback(ClipLoopedCallback cb);

    // ------------------------------------------------------------
    // Clips API
    // ------------------------------------------------------------
    std::pair<double, double> loadClip(int slotId, const std::string& filepath);
    void unloadClip(int slotId);

    void playClip(int slotId);
    void pauseClip(int slotId);
    void resumeClip(int slotId);
    void stopClip(int slotId);

    void setClipLoop(int slotId, bool loop);
    void setClipGain(int slotId, float gainDB);
    float getClipGain(int slotId) const;

    void setClipTrim(int slotId, double startMs, double endMs);
    void seekClip(int slotId, double positionMs);
    void setClipStartPosition(int slotId, double positionMs);  // Sets position BEFORE playClip is called

    bool isClipPlaying(int slotId) const;
    bool isClipPaused(int slotId) const;
    double getClipPlaybackPositionMs(int slotId) const;

    double getFileDuration(const std::string& filepath);

    // ------------------------------------------------------------
    // Recording
    // ------------------------------------------------------------
    // recordMic: include microphone/input device in recording
    // recordPlayback: include soundboard clips output in recording
    bool startRecording(const std::string& outputPath, bool recordMic = true, bool recordPlayback = false);
    bool stopRecording();
    bool isRecording() const;
    float getRecordingDuration() const;

private:
    // ------------------------------------------------------------
    // Clip internals
    // ------------------------------------------------------------
    enum class ClipState {
        Stopped,
        Playing,
        Paused,
        Draining,
        Stopping
    };

    struct ClipSlot {
        std::atomic<ClipState> state{ClipState::Stopped};
        std::atomic<float> gain{1.0f};
        std::atomic<bool> loop{false};

        std::atomic<double> trimStartMs{0.0};
        std::atomic<double> trimEndMs{-1.0};
        std::atomic<double> seekPosMs{-1.0};

        std::atomic<long long> playbackFrameCount{0};
        std::atomic<long long> queuedMainFrames{0};

        std::atomic<int> sampleRate{0};
        std::atomic<int> channels{0};
        std::atomic<double> totalDurationMs{0.0};

        std::atomic<uint64_t> playToken{0};

        std::string filePath;

        // ring buffers (stereo)
        ma_pcm_rb ringBufferMain{};
        void* ringBufferMainData = nullptr;

        ma_pcm_rb ringBufferMon{};
        void* ringBufferMonData = nullptr;

        std::thread decoderThread;
    };

    // Decoder thread
    static void decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId, uint64_t token);

    // ------------------------------------------------------------
    // Main pipeline callbacks
    // ------------------------------------------------------------
    static void captureCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    static void playbackCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);

    void processCaptureInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels, ma_format fmt);
    void processPlaybackAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels);

    // ------------------------------------------------------------
    // Monitor device callbacks (clips only)
    // ------------------------------------------------------------
    static void monitorCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    void processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels);

    // ------------------------------------------------------------
    // Recording-input device callbacks
    // ------------------------------------------------------------
    static void recordingInputCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    void processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels);

    // ------------------------------------------------------------
    // Ringbuffers
    // ------------------------------------------------------------
    bool initCaptureRingBuffer(ma_uint32 sampleRate);
    void shutdownCaptureRingBuffer();

    bool initRecordingRingBuffer(ma_uint32 sampleRate, ma_uint32 channels);
    void shutdownRecordingRingBuffer();

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------
    static float dBToLinear(float db);
    static void computeBalanceMultipliers(float balance, float& micMul, float& clipMul);

    // rb sizing
    ma_uint32 getRingBufferSize() const;     // clip ringbuffers
    ma_uint32 getRecInputRbSize() const;     // recording input rb

    // file writer (legacy; you are using encoder thread now)
    static bool writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels);

private:
    // ------------------------------------------------------------
    // Core config
    // ------------------------------------------------------------
    ma_uint32 m_sampleRate = DEFAULT_SAMPLE_RATE;
    ma_uint32 m_bufferSizeFrames = DEFAULT_BUFFER_SIZE;
    ma_uint32 m_bufferPeriods = DEFAULT_BUFFER_PERIODS;
    ma_uint32 m_channels = DEFAULT_CHANNELS;

    // ------------------------------------------------------------
    // Miniaudio context + devices (REAL STORAGE)
    // ------------------------------------------------------------
    ma_context m_context{};
    bool m_contextInitialized = false;

    ma_device m_playbackDevice{};
    bool m_playbackInitialized = false;

    ma_device m_captureDevice{};
    bool m_captureInitialized = false;

    ma_device m_monitorDevice{};
    bool m_monitorInitialized = false;

    ma_device m_recordingInputDevice{};
    bool m_recordingInputInitialized = false;

    // ------------------------------------------------------------
    // Compatibility aliases (OPTIONAL)
    // If your .cpp currently expects pointers like `context`, `playbackDevice`,
    // these point to the value members above when initialized.
    // ------------------------------------------------------------
    ma_context* context = nullptr;
    ma_device* playbackDevice = nullptr;      // main output
    ma_device* captureDevice  = nullptr;      // main input
    ma_device* monitorDevice  = nullptr;
    ma_device* recordingInputDevice = nullptr;

    // ------------------------------------------------------------
    // Running flags
    // ------------------------------------------------------------
    std::atomic<bool> deviceRunning{false};
    std::atomic<bool> playbackRunning{false};
    std::atomic<bool> captureRunning{false};

    // capture -> playback mono ringbuffer
    ma_pcm_rb captureRb{};
    void* captureRbData = nullptr;
    ma_uint32 captureRbFrames = 0;

    // ------------------------------------------------------------
    // Monitor device (clips-only)
    // ------------------------------------------------------------
    std::atomic<bool> monitorRunning{false};

    // ------------------------------------------------------------
    // Recording-input device (extra capture-only, record-only)
    // ------------------------------------------------------------
    std::atomic<bool> recordingInputRunning{false};
    std::atomic<bool> recordingInputEnabled{false};

    ma_pcm_rb recordingInputRb{};
    void* recordingInputRbData = nullptr;
    std::atomic<int> recordingInputCaptureChannels{0};

    // ------------------------------------------------------------
    // Recording main mix (writer thread drains this rb)
    // ------------------------------------------------------------
    std::atomic<bool> recording{false};
    std::atomic<bool> recordingWriterRunning{false};
    std::thread recordingWriterThread;

    ma_pcm_rb recordingRb{};
    void* recordingRbData = nullptr;
    ma_uint32 recordingRbFrames = 0;

    std::atomic<uint64_t> recordedFrames{0};
    std::atomic<bool> recordingWriteOk{false};
    std::string recordingOutputPath;
    int recordingChannels = 2;
    
    // Recording source selection flags
    std::atomic<bool> recordMicEnabled{true};       // include mic input in recording
    std::atomic<bool> recordPlaybackEnabled{false}; // include soundboard clips in recording

    // ------------------------------------------------------------
    // Scratch buffers (avoid realloc in audio callback)
    // ------------------------------------------------------------
    std::vector<float> recTempScratch; // size = bufferSizeFrames * playbackChannels

    // ------------------------------------------------------------
    // Mixer parameters
    // ------------------------------------------------------------
    std::atomic<bool>  micEnabled{true};
    std::atomic<bool>  micPassthroughEnabled{false};

    std::atomic<float> micGainDB{0.0f};
    std::atomic<float> micGain{1.0f};

    std::atomic<float> masterGainDB{0.0f};
    std::atomic<float> masterGain{1.0f};

    std::atomic<float> micSoundboardBalance{0.5f}; // 0..1

    // ------------------------------------------------------------
    // Peaks
    // ------------------------------------------------------------
    std::atomic<float> micPeakLevel{0.0f};
    std::atomic<float> masterPeakLevel{0.0f};
    std::atomic<float> monitorPeakLevel{0.0f};

    // ------------------------------------------------------------
    // Clips
    // ------------------------------------------------------------
    ClipSlot clips[MAX_CLIPS];

    // ------------------------------------------------------------
    // Device selections (strings + device-id structs)
    // ------------------------------------------------------------
    bool selectedPlaybackSet = false;
    std::string selectedPlaybackDeviceId;
    ma_device_id selectedPlaybackDeviceIdStruct{};

    bool selectedCaptureSet = false;
    std::string selectedCaptureDeviceId;
    ma_device_id selectedCaptureDeviceIdStruct{};

    bool selectedMonitorPlaybackSet = false;
    std::string selectedMonitorPlaybackDeviceId;
    ma_device_id selectedMonitorPlaybackDeviceIdStruct{};

    bool selectedRecordingCaptureSet = false;
    std::string selectedRecordingCaptureDeviceId;
    ma_device_id selectedRecordingCaptureDeviceIdStruct{};

    // ------------------------------------------------------------
    // Clip callbacks
    // ------------------------------------------------------------
    std::mutex callbackMutex;
    ClipFinishedCallback clipFinishedCallback;
    ClipErrorCallback clipErrorCallback;
    ClipLoopedCallback clipLoopedCallback;
};
