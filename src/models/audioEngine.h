#pragma once
#include <string>
#include <vector>
#include <atomic>
#include <thread>
#include <memory>
#include <functional>
#include <mutex>

#include "miniaudio.h"

// Callback types
using ClipFinishedCallback = std::function<void(int slotId)>;
using ClipErrorCallback = std::function<void(int slotId, const std::string& error)>;

// Maximum number of simultaneous clips
#define MAX_CLIPS 16
// Ring buffer size (in frames) - ~1 second at 48kHz stereo
#define RING_BUFFER_SIZE_IN_FRAMES (48000 * 2)

enum class ClipState {
    Stopped = 0,
    Playing = 1,
    Stopping = 2  // Decoder should stop
};

// Per-clip data structure
struct ClipSlot {
    // Ring buffer for decoded audio (lock-free)
    ma_pcm_rb ringBuffer;
    void* ringBufferData;  // Backing memory
    
    // Decoder thread
    std::thread decoderThread;
    
    // Atomic state flags (safe to read/write from any thread)
    std::atomic<ClipState> state;
    std::atomic<bool> loop;
    std::atomic<float> gain;  // Linear gain
    
    // File path (set before starting decoder thread, read-only after)
    std::string filePath;
    
    // Format info (set by decoder thread)
    std::atomic<int> sampleRate;
    std::atomic<int> channels;
    
    ClipSlot() 
        : ringBufferData(nullptr)
        , state(ClipState::Stopped)
        , loop(false)
        , gain(1.0f)
        , sampleRate(0)
        , channels(0)
    {}
};

class AudioEngine {
public:
    AudioEngine();
    explicit AudioEngine(void* parent);
    ~AudioEngine();
    
    // Device control
    bool startAudioDevice();
    bool stopAudioDevice();
    bool isDeviceRunning() const;
    
    // Clip control (thread-safe, can call from Qt UI)
    // UI manages slot assignments - just pass slotId and filepath
    bool loadClip(int slotId, const std::string& filepath);  // Returns true on success
    void playClip(int slotId);
    void stopClip(int slotId);
    void setClipLoop(int slotId, bool loop);
    void setClipGain(int slotId, float gainDB);
    float getClipGain(int slotId) const;  // Returns gain in dB
    bool isClipPlaying(int slotId) const;
    void unloadClip(int slotId);  // Stop and free resources
    
    // Microphone gain
    void setMicGainDB(float gainDB);
    float getMicGainDB() const;
    
    // Master output gain (affects all audio)
    void setMasterGainDB(float gainDB);
    float getMasterGainDB() const;

    // Expose linear gains for UI sliders (0.0 - 1.0 typical, but not clamped)
    void setMasterGainLinear(float linear);
    float getMasterGainLinear() const;
    void setMicGainLinear(float linear);
    float getMicGainLinear() const;
    
    // Real-time audio level monitoring (peak detection)
    float getMicPeakLevel() const;      // Returns 0.0 to 1.0
    float getMasterPeakLevel() const;   // Returns 0.0 to 1.0
    void resetPeakLevels();
    
    // Event callbacks
    void setClipFinishedCallback(ClipFinishedCallback callback);
    void setClipErrorCallback(ClipErrorCallback callback);
    
    // Device enumeration
    struct AudioDeviceInfo {
        std::string id;           // simple index-based id as string
        std::string name;
        bool isDefault;
        ma_device_id deviceId;    // concrete device id for selection
    };
    std::vector<AudioDeviceInfo> enumeratePlaybackDevices();
    std::vector<AudioDeviceInfo> enumerateCaptureDevices();
    bool setPlaybackDevice(const std::string& deviceId);
    bool setCaptureDevice(const std::string& deviceId);
    
private:
    // Audio callback (REAL-TIME SAFE)
    static void audioCallback(ma_device* pDevice, void* pOutput, 
                             const void* pInput, ma_uint32 frameCount);
    void processAudio(void* output, const void* input, 
                     ma_uint32 frameCount, ma_uint32 channels);
    
    // Decoder thread function (runs in background)
    static void decoderThreadFunc(ClipSlot* slot, int slotId);
    
    // Helper functions
    bool initContext();
    bool initDevice();
    float dBToLinear(float db);
    
    // Miniaudio members
    ma_device* device;
    ma_context* context;
    std::atomic<bool> deviceRunning;
    
    // Clip slots
    ClipSlot clips[MAX_CLIPS];
    
    // Mic gain (atomic for thread-safety)
    std::atomic<float> micGain;
    std::atomic<float> micGainDB;
    
    // Master gain (atomic for thread-safety)
    std::atomic<float> masterGain;
    std::atomic<float> masterGainDB;
    
    // Peak level monitoring (atomic for thread-safety)
    std::atomic<float> micPeakLevel;
    std::atomic<float> masterPeakLevel;
    
    // Event callbacks (protected by mutex)
    std::mutex callbackMutex;
    ClipFinishedCallback clipFinishedCallback;
    ClipErrorCallback clipErrorCallback;
    
    // Device selection
    std::string selectedPlaybackDeviceId;
    std::string selectedCaptureDeviceId;
    ma_device_id selectedPlaybackDeviceIdStruct{};
    ma_device_id selectedCaptureDeviceIdStruct{};
    bool selectedPlaybackSet = false;
    bool selectedCaptureSet = false;

    bool reinitializeDevice(bool restart = true);
    bool applyDeviceSelection(ma_device_config& config);
};
