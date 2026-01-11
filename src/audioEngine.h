#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "miniaudio.h"

static constexpr int MAX_CLIPS = 64;
static constexpr ma_uint32 RING_BUFFER_SIZE_IN_FRAMES = 48000; // ~1s @48k

class AudioEngine
{
public:
    struct AudioDeviceInfo {
        std::string name;
        std::string id;       // you currently use name as id
        bool isDefault = false;
        ma_device_id deviceId{};
    };

    enum class ClipState : int {
        Stopped = 0,
        Playing,
        Paused,
        Draining,
        Stopping
    };

    using ClipFinishedCallback = std::function<void(int)>;
    using ClipErrorCallback    = std::function<void(int, const std::string&)>;

    AudioEngine();
    explicit AudioEngine(void* parent);
    ~AudioEngine();

           // ===== Device control =====
    bool startAudioDevice();
    bool stopAudioDevice();
    bool isDeviceRunning() const;

    bool startMonitorDevice();
    bool stopMonitorDevice();
    bool isMonitorRunning() const;

    bool setPlaybackDevice(const std::string& deviceId);
    bool setCaptureDevice(const std::string& deviceId);
    bool setMonitorPlaybackDevice(const std::string& deviceId);

           // ===== NEW: Recording input device (3rd source) =====
           // deviceId == "-1" => disable recording input device
    bool setRecordingInputDevice(const std::string& deviceId);

           // Compatibility with your SoundboardService call:
    bool setRecodingDevice(const std::string& deviceId) { return setRecordingInputDevice(deviceId); }

           // ===== Hotplug refresh =====
    std::vector<AudioDeviceInfo> refreshPlaybackDevices();
    std::vector<AudioDeviceInfo> refreshInputDevices();

    std::vector<AudioDeviceInfo> enumeratePlaybackDevices();
    std::vector<AudioDeviceInfo> enumerateCaptureDevices();

           // ===== Clips =====
    std::pair<double, double> loadClip(int slotId, const std::string& filepath);
    void playClip(int slotId);
    void pauseClip(int slotId);
    void resumeClip(int slotId);
    void stopClip(int slotId);
    void unloadClip(int slotId);

    void setClipLoop(int slotId, bool loop);
    void setClipGain(int slotId, float gainDB);
    float getClipGain(int slotId) const;

    void setClipTrim(int slotId, double startMs, double endMs);
    void seekClip(int slotId, double positionMs);
    double getClipPlaybackPositionMs(int slotId) const;

    double getFileDuration(const std::string& filepath);

    bool isClipPlaying(int slotId) const;
    bool isClipPaused(int slotId) const;

           // ===== Gains / UI =====
    void setMicGainDB(float gainDB);
    float getMicGainDB() const;

    void setMasterGainDB(float gainDB);
    float getMasterGainDB() const;

    void setMasterGainLinear(float linear);
    float getMasterGainLinear() const;

    void setMicGainLinear(float linear);
    float getMicGainLinear() const;

    void setMonitorGainDB(float gainDB);
    float getMonitorGainDB() const;

    float getMicPeakLevel() const;
    float getMasterPeakLevel() const;
    float getMonitorPeakLevel() const;
    void resetPeakLevels();

    void setMicEnabled(bool enabled);           // This is your "mute" toggle
    bool isMicEnabled() const;

    void setMicPassthroughEnabled(bool enabled);
    bool isMicPassthroughEnabled() const;

    void setMicSoundboardBalance(float balance);
    float getMicSoundboardBalance() const;

           // ===== Recording =====
    bool startRecording(const std::string& outputPath);
    bool stopRecording();
    bool isRecording() const;
    float getRecordingDuration() const;

           // ===== Callbacks =====
    void setClipFinishedCallback(ClipFinishedCallback callback);
    void setClipErrorCallback(ClipErrorCallback callback);

private:
    struct ClipSlot {
        std::string filePath;

        std::atomic<ClipState> state{ClipState::Stopped};

        ma_pcm_rb ringBufferMain{};
        ma_pcm_rb ringBufferMon{};
        void* ringBufferMainData = nullptr;
        void* ringBufferMonData  = nullptr;

        std::thread decoderThread;

        std::atomic<float> gain{1.0f};
        std::atomic<bool>  loop{false};

        std::atomic<double> trimStartMs{0.0};
        std::atomic<double> trimEndMs{0.0};

        std::atomic<double> seekPosMs{-1.0};

        std::atomic<long long> playbackFrameCount{0};
        std::atomic<long long> queuedMainFrames{0};

        std::atomic<int> sampleRate{48000};
        std::atomic<int> channels{2};

        std::atomic<double> totalDurationMs{0.0};
    };

private:
    // ===== Context and devices =====
    bool initContext();
    bool initDevice();
    bool initMonitorDevice();
    bool reinitializeDevice(bool restart);
    bool reinitializeMonitorDevice(bool restart);
    bool applyDeviceSelection(ma_device_config& config);

    static void audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
    static void monitorCallback(ma_device* pDevice, void* pOutput, const void*, ma_uint32 frameCount);

    void processAudio(void* output,
                      const void* input,
                      ma_uint32 frameCount,
                      ma_uint32 playbackChannels,
                      ma_uint32 captureChannels);

    void processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels);

           // ===== Decoder thread =====
    static void decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId);

           // ===== Helpers =====
    static float dBToLinear(float db);

           // ===== Recording helpers =====
    bool writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels);

           // ===== Recording input device (3rd source) =====
    bool initRecordingInputDevice();
    bool startRecordingInputDevice();
    bool stopRecordingInputDevice();
    bool reinitializeRecordingInputDevice(bool restart);

    static void recordingInputCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount);
    void processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels);

    void mixExtraInputIntoRecording(float* recStereoOut, ma_uint32 frameCount);

private:
    ma_context* context = nullptr;

    ma_device* device = nullptr;
    std::atomic<bool> deviceRunning{false};

    ma_device* monitorDevice = nullptr;
    std::atomic<bool> monitorRunning{false};

           // Actual running sample rate for correct WAV
    std::atomic<int> mainSampleRate{48000};

           // Selection
    std::string selectedPlaybackDeviceId;
    ma_device_id selectedPlaybackDeviceIdStruct{};
    bool selectedPlaybackSet = false;

    std::string selectedCaptureDeviceId;
    ma_device_id selectedCaptureDeviceIdStruct{};
    bool selectedCaptureSet = false;

    std::string selectedMonitorPlaybackDeviceId;
    ma_device_id selectedMonitorPlaybackDeviceIdStruct{};
    bool selectedMonitorPlaybackSet = false;

           // Clips
    ClipSlot clips[MAX_CLIPS];

           // Gains/controls
    std::atomic<float> micGainDB{0.0f};
    std::atomic<float> micGain{1.0f};

    std::atomic<float> masterGainDB{0.0f};
    std::atomic<float> masterGain{1.0f};

    std::atomic<float> monitorGainDB{0.0f};
    std::atomic<float> monitorGain{1.0f};

    std::atomic<float> micPeakLevel{0.0f};
    std::atomic<float> masterPeakLevel{0.0f};
    std::atomic<float> monitorPeakLevel{0.0f};

    std::atomic<bool> micEnabled{true};               // if false => mic is muted, do NOT record mic
    std::atomic<bool> micPassthroughEnabled{true};
    std::atomic<float> micBalance{0.5f};

           // Callbacks
    std::mutex callbackMutex;
    ClipFinishedCallback clipFinishedCallback;
    ClipErrorCallback clipErrorCallback;

           // Recording buffer (mixed output)
    std::atomic<bool> recording{false};
    std::mutex recordingMutex;
    std::vector<float> recordingBuffer; // interleaved stereo float
    std::string recordingOutputPath;
    std::atomic<uint64_t> recordedFrames{0};

           // 3rd input recording device
    ma_device* recordingInputDevice = nullptr;
    std::atomic<bool> recordingInputRunning{false};

    std::string selectedRecordingInputDeviceId;
    ma_device_id selectedRecordingInputDeviceIdStruct{};
    bool selectedRecordingInputSet = false;

    ma_pcm_rb recordingInputRb{};
    void* recordingInputRbData = nullptr;
};
