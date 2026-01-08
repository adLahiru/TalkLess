#pragma once
#include "miniaudio.h"

#include <atomic>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// Callback types
using ClipFinishedCallback = std::function<void(int slotId)>;
using ClipErrorCallback = std::function<void(int slotId, const std::string& error)>;

// Maximum number of simultaneous clips
#define MAX_CLIPS 16
// Ring buffer size (in frames)
#define RING_BUFFER_SIZE_IN_FRAMES (48000 * 2)

enum class ClipState {
    Stopped = 0,
    Playing = 1,
    Stopping = 2
};

// Two ring buffers are required because reads consume data.
// - ringBufferMain: consumed by main device callback
// - ringBufferMon : consumed by monitor device callback
struct ClipSlot
{
    ma_pcm_rb ringBufferMain{};
    void* ringBufferMainData = nullptr;

    ma_pcm_rb ringBufferMon{};
    void* ringBufferMonData = nullptr;

    std::thread decoderThread;

    std::atomic<ClipState> state{ClipState::Stopped};
    std::atomic<bool> loop{false};
    std::atomic<float> gain{1.0f};

    std::string filePath;

    std::atomic<int> sampleRate{0};
    std::atomic<int> channels{0};
};

class AudioEngine
{
public:
    AudioEngine();
    explicit AudioEngine(void* parent);
    ~AudioEngine();

           // Main device control (duplex)
    bool startAudioDevice();
    bool stopAudioDevice();
    bool isDeviceRunning() const;

           // Monitor device control (playback-only, clips-only)
    bool startMonitorDevice();
    bool stopMonitorDevice();
    bool isMonitorRunning() const;

    bool setMonitorPlaybackDevice(const std::string& deviceId);
    void setMonitorGainDB(float gainDB);
    float getMonitorGainDB() const;

           // Clip control
    bool loadClip(int slotId, const std::string& filepath);
    void playClip(int slotId);
    void stopClip(int slotId);
    void setClipLoop(int slotId, bool loop);
    void setClipGain(int slotId, float gainDB);
    float getClipGain(int slotId) const;
    bool isClipPlaying(int slotId) const;
    void unloadClip(int slotId);

           // Microphone gain
    void setMicGainDB(float gainDB);
    float getMicGainDB() const;

           // Master output gain
    void setMasterGainDB(float gainDB);
    float getMasterGainDB() const;

    void setMasterGainLinear(float linear);
    float getMasterGainLinear() const;
    void setMicGainLinear(float linear);
    float getMicGainLinear() const;

           // Peak monitoring
    float getMicPeakLevel() const;
    float getMasterPeakLevel() const;
    void resetPeakLevels();
    
           // Mic control
    void setMicEnabled(bool enabled);
    bool isMicEnabled() const;

    // Mic passthrough control
    void setMicPassthroughEnabled(bool enabled);
    bool isMicPassthroughEnabled() const;
    
    // Mic/Soundboard balance control
    void setMicSoundboardBalance(float balance);  // 0.0 = full mic, 1.0 = full soundboard
    float getMicSoundboardBalance() const;

           // Event callbacks
    void setClipFinishedCallback(ClipFinishedCallback callback);
    void setClipErrorCallback(ClipErrorCallback callback);

           // Device enumeration
    struct AudioDeviceInfo
    {
        std::string id;       // simple index-based id as string
        std::string name;
        bool isDefault;
        ma_device_id deviceId; // concrete device id for selection
    };

    std::vector<AudioDeviceInfo> enumeratePlaybackDevices();
    std::vector<AudioDeviceInfo> enumerateCaptureDevices();
    bool setPlaybackDevice(const std::string& deviceId);
    bool setCaptureDevice(const std::string& deviceId);

           // Recording
    bool startRecording(const std::string& outputPath);
    bool stopRecording();
    bool isRecording() const;
    float getRecordingDuration() const;

private:
    // Main callback (duplex)
    static void audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    void processAudio(void* output,
                      const void* input,
                      ma_uint32 frameCount,
                      ma_uint32 playbackChannels,
                      ma_uint32 captureChannels);

           // Monitor callback (playback-only, clips-only)
    static void monitorCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    void processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels);

           // Decoder thread
    static void decoderThreadFunc(ClipSlot* slot, int slotId);

           // Helpers
    bool initContext();
    bool initDevice();
    bool initMonitorDevice();
    float dBToLinear(float db);

    bool reinitializeDevice(bool restart = true);
    bool applyDeviceSelection(ma_device_config& config);

    bool reinitializeMonitorDevice(bool restart = true);

           // Miniaudio main
    ma_device* device = nullptr;
    ma_context* context = nullptr;
    std::atomic<bool> deviceRunning{false};

           // Miniaudio monitor
    ma_device* monitorDevice = nullptr;
    std::atomic<bool> monitorRunning{false};

           // Clip slots
    ClipSlot clips[MAX_CLIPS];

           // Gains
    std::atomic<float> micGain{1.0f};
    std::atomic<float> micGainDB{0.0f};

    std::atomic<float> masterGain{1.0f};
    std::atomic<float> masterGainDB{0.0f};

    std::atomic<float> monitorGain{1.0f};
    std::atomic<float> monitorGainDB{0.0f};

           // Peak monitoring
    std::atomic<float> micPeakLevel{0.0f};
    std::atomic<float> masterPeakLevel{0.0f};
    
    // Mic control
    std::atomic<bool> micEnabled{true};
    std::atomic<bool> micPassthroughEnabled{true};
    std::atomic<float> micBalance{0.5f}; // 0.0 = full mic, 1.0 = full soundboard

           // Callbacks
    std::mutex callbackMutex;
    ClipFinishedCallback clipFinishedCallback;
    ClipErrorCallback clipErrorCallback;

           // Main device selection
    std::string selectedPlaybackDeviceId;
    std::string selectedCaptureDeviceId;
    ma_device_id selectedPlaybackDeviceIdStruct{};
    ma_device_id selectedCaptureDeviceIdStruct{};
    bool selectedPlaybackSet = false;
    bool selectedCaptureSet = false;

           // Monitor device selection
    std::string selectedMonitorPlaybackDeviceId;
    ma_device_id selectedMonitorPlaybackDeviceIdStruct{};
    bool selectedMonitorPlaybackSet = false;

           // Recording state
    std::atomic<bool> recording{false};
    std::string recordingOutputPath;
    std::vector<float> recordingBuffer;
    std::mutex recordingMutex;
    std::atomic<uint64_t> recordedFrames{0};

    bool writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels);
};
