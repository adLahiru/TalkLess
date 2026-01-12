
#include "audioEngine.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <thread>

// ------------------------------------------------------------
// CTOR/DTOR
// ------------------------------------------------------------
AudioEngine::AudioEngine() = default;

AudioEngine::AudioEngine(void* parent) : AudioEngine()
{
    (void)parent;
}

AudioEngine::~AudioEngine()
{
    // stop recording-input device
    shutdownRecordingInputDevice();

    // stop monitor first
    if (monitorRunning.load(std::memory_order_acquire)) {
        stopMonitorDevice();
    }
    if (monitorDevice) {
        ma_device_uninit(monitorDevice);
        delete monitorDevice;
        monitorDevice = nullptr;
    }

    // stop main device
    if (deviceRunning.load(std::memory_order_acquire)) {
        stopAudioDevice();
    }

    // stop/free clips
    for (int i = 0; i < MAX_CLIPS; ++i) {
        unloadClip(i);
    }

    // cleanup main device
    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }

    // cleanup context
    if (context) {
        ma_context_uninit(context);
        delete context;
        context = nullptr;
    }
}

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
float AudioEngine::dBToLinear(float db)
{
    return std::pow(10.0f, db / 20.0f);
}

void AudioEngine::computeBalanceMultipliers(float balance, float& micMul, float& clipMul)
{
    balance = std::max(0.0f, std::min(1.0f, balance));

    if (balance <= 0.5f) {
        micMul  = 1.0f;
        clipMul = balance * 2.0f;          // 0..1
    } else {
        clipMul = 1.0f;
        micMul  = (1.0f - balance) * 2.0f; // 1..0
    }
}

// ------------------------------------------------------------
// Context / Device init
// ------------------------------------------------------------
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

    // try a few configs for capture robustness
    struct TryCfg { ma_format fmt; ma_uint32 ch; ma_uint32 sr; };
    TryCfg tries[] = {
        { ma_format_f32, 2, ENGINE_SR },
        { ma_format_f32, 1, ENGINE_SR },
        { ma_format_s16, 2, ENGINE_SR },
        { ma_format_s16, 1, ENGINE_SR },
        { ma_format_unknown, 0, 0 } // auto
    };

    for (auto& t : tries) {
        ma_device_config cfg = ma_device_config_init(ma_device_type_duplex);
        cfg.playback.format   = ma_format_f32;
        cfg.playback.channels = 2;
        cfg.capture.format    = t.fmt;
        cfg.capture.channels  = t.ch;
        cfg.sampleRate        = (t.sr == 0 ? ENGINE_SR : t.sr);
        cfg.dataCallback      = &AudioEngine::audioCallback;
        cfg.pUserData         = this;
        
        // Use larger buffer for better compatibility with virtual audio cables
        // and to reduce crackling/popping
        cfg.periodSizeInFrames = 1024;  // ~21ms at 48kHz
        cfg.periods = 3;  // Triple buffering for stability

        applyDeviceSelection(cfg);

        if (ma_device_init(context, &cfg, device) == MA_SUCCESS) {
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

// ------------------------------------------------------------
// Monitor device
// ------------------------------------------------------------
bool AudioEngine::initMonitorDevice()
{
    if (monitorDevice) return true;
    if (!initContext()) return false;

    monitorDevice = new ma_device();
    ma_device_config cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format   = ma_format_f32;
    cfg.playback.channels = 2;
    cfg.sampleRate        = ENGINE_SR;
    cfg.dataCallback      = &AudioEngine::monitorCallback;
    cfg.pUserData         = this;
    cfg.periodSizeInFrames = 1024;  // ~21ms at 48kHz - helps with VB-Cable
    cfg.periods            = 3;    // Triple buffering for stability

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

// ------------------------------------------------------------
// Recording-input device (capture-only)
// ------------------------------------------------------------
bool AudioEngine::initRecordingInputDevice()
{
    if (recordingInputDevice) return true;
    if (!initContext()) return false;

    recordingInputDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
    cfg.capture.format   = ma_format_f32;
    cfg.capture.channels = 2;        // we’ll accept mono too (device may override)
    cfg.sampleRate       = ENGINE_SR;
    cfg.dataCallback     = &AudioEngine::recordingInputCallback;
    cfg.pUserData        = this;
    cfg.periodSizeInFrames = 1024;  // ~21ms at 48kHz - helps with VB-Cable
    cfg.periods            = 3;     // Triple buffering for stability

    if (selectedRecordingCaptureSet) {
        cfg.capture.pDeviceID = &selectedRecordingCaptureDeviceIdStruct;
    }

    if (ma_device_init(context, &cfg, recordingInputDevice) != MA_SUCCESS) {
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
        return false;
    }

    // init mono ringbuffer if not
    if (!recordingInputRbData) {
        const size_t bytes = RECINPUT_RB_SIZE_FRAMES * 1 * sizeof(float);
        recordingInputRbData = std::malloc(bytes);
        if (!recordingInputRbData) return false;

        ma_pcm_rb_init(ma_format_f32, 1, RECINPUT_RB_SIZE_FRAMES,
                       recordingInputRbData, nullptr, &recordingInputRb);
    } else {
        ma_pcm_rb_reset(&recordingInputRb);
    }

    recordingInputCaptureChannels.store((int)recordingInputDevice->capture.channels, std::memory_order_relaxed);
    return true;
}

bool AudioEngine::startRecordingInputDevice()
{
    if (!recordingInputDevice && !initRecordingInputDevice()) return false;
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

void AudioEngine::shutdownRecordingInputDevice()
{
    if (recordingInputRunning.load(std::memory_order_acquire)) {
        stopRecordingInputDevice();
    }
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
    recordingInputEnabled.store(false, std::memory_order_release);
    selectedRecordingCaptureSet = false;
}

bool AudioEngine::reinitializeRecordingInputDevice(bool restart)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    bool wasRunning = recordingInputRunning.load(std::memory_order_acquire);
    if (wasRunning) {
        stopRecordingInputDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }

    if (recordingInputDevice) {
        ma_device_uninit(recordingInputDevice);
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
    }

    if (!initRecordingInputDevice()) return false;

    if (restart || wasRunning) {
        return startRecordingInputDevice();
    }
    return true;
}

// ------------------------------------------------------------
// Hotplug refresh: rebuild context and devices
// ------------------------------------------------------------
bool AudioEngine::rebuildContextAndDevices(bool restartRunning)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    std::cout << "[AudioEngine] Rebuilding context and devices..." << std::endl;

    const bool mainWasRunning    = deviceRunning.load(std::memory_order_acquire);
    const bool monWasRunning     = monitorRunning.load(std::memory_order_acquire);
    const bool recInWasRunning   = recordingInputRunning.load(std::memory_order_acquire);

    // stop devices
    if (mainWasRunning) stopAudioDevice();
    if (monWasRunning)  stopMonitorDevice();
    if (recInWasRunning) stopRecordingInputDevice();

    std::this_thread::sleep_for(std::chrono::milliseconds(30));

    // uninit devices (but keep selection string IDs)
    if (device) {
        ma_device_uninit(device);
        delete device;
        device = nullptr;
    }
    if (monitorDevice) {
        ma_device_uninit(monitorDevice);
        delete monitorDevice;
        monitorDevice = nullptr;
    }
    if (recordingInputDevice) {
        ma_device_uninit(recordingInputDevice);
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
    }

    // rebuild context
    if (context) {
        ma_context_uninit(context);
        delete context;
        context = nullptr;
    }
    if (!initContext()) return false;

    // CRITICAL: Refresh device ID structs after rebuilding context
    // The ma_device_id structs become stale after context rebuild
    refreshDeviceIdStructs();

    // reinit devices with refreshed device ID structs
    if (!initDevice()) return false;
    // monitor optional
    if (selectedMonitorPlaybackSet) {
        initMonitorDevice();
    }
    // recording-input optional
    if (recordingInputEnabled.load(std::memory_order_relaxed) && selectedRecordingCaptureSet) {
        initRecordingInputDevice();
    }

    if (restartRunning) {
        if (mainWasRunning) startAudioDevice();
        if (monWasRunning)  startMonitorDevice();
        if (recInWasRunning) startRecordingInputDevice();
    }
    
    std::cout << "[AudioEngine] Context and devices rebuilt successfully" << std::endl;
    return true;
}

bool AudioEngine::refreshPlaybackDevices()
{
    // rebuild and restart anything that was running
    return rebuildContextAndDevices(true);
}

bool AudioEngine::refreshInputDevices()
{
    // rebuild and restart anything that was running
    return rebuildContextAndDevices(true);
}

// ------------------------------------------------------------
// Refresh device ID structs after context rebuild
// ------------------------------------------------------------
void AudioEngine::refreshDeviceIdStructs()
{
    // After rebuilding context, the ma_device_id structs are stale.
    // We need to re-lookup each device by its string ID.
    
    if (selectedPlaybackSet && !selectedPlaybackDeviceId.empty()) {
        auto devices = enumeratePlaybackDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedPlaybackDeviceId || d.name == selectedPlaybackDeviceId) {
                selectedPlaybackDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed playback device struct: " << d.name << std::endl;
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected playback device not found: " << selectedPlaybackDeviceId << std::endl;
            selectedPlaybackSet = false;  // Device no longer available
        }
    }
    
    if (selectedCaptureSet && !selectedCaptureDeviceId.empty()) {
        auto devices = enumerateCaptureDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedCaptureDeviceId || d.name == selectedCaptureDeviceId) {
                selectedCaptureDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed capture device struct: " << d.name << std::endl;
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected capture device not found: " << selectedCaptureDeviceId << std::endl;
            selectedCaptureSet = false;  // Device no longer available
        }
    }
    
    if (selectedMonitorPlaybackSet && !selectedMonitorPlaybackDeviceId.empty()) {
        auto devices = enumeratePlaybackDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedMonitorPlaybackDeviceId || d.name == selectedMonitorPlaybackDeviceId) {
                selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed monitor device struct: " << d.name << std::endl;
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected monitor device not found: " << selectedMonitorPlaybackDeviceId << std::endl;
            selectedMonitorPlaybackSet = false;  // Device no longer available
        }
    }
    
    if (selectedRecordingCaptureSet && !selectedRecordingCaptureDeviceId.empty()) {
        auto devices = enumerateCaptureDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedRecordingCaptureDeviceId || d.name == selectedRecordingCaptureDeviceId) {
                selectedRecordingCaptureDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed recording input device struct: " << d.name << std::endl;
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected recording input device not found: " << selectedRecordingCaptureDeviceId << std::endl;
            selectedRecordingCaptureSet = false;  // Device no longer available
        }
    }
}

// ------------------------------------------------------------
// Enumeration
// ------------------------------------------------------------
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

    devices.reserve(playbackCount);
    for (ma_uint32 i = 0; i < playbackCount; ++i) {
        AudioDeviceInfo info;
        info.name = (pPlaybackInfos[i].name[0] != '\0') ? std::string(pPlaybackInfos[i].name) : std::string();
        info.id = info.name; // your UI uses name as ID
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

    devices.reserve(captureCount);
    for (ma_uint32 i = 0; i < captureCount; ++i) {
        AudioDeviceInfo info;
        info.name = (pCaptureInfos[i].name[0] != '\0') ? std::string(pCaptureInfos[i].name) : std::string();
        info.id = info.name;
        info.isDefault = pCaptureInfos[i].isDefault;
        info.deviceId = pCaptureInfos[i].id;
        devices.push_back(info);
    }
    return devices;
}

// ------------------------------------------------------------
// Set devices
// ------------------------------------------------------------
bool AudioEngine::reinitializeDevice(bool restart)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    bool wasRunning = deviceRunning.load(std::memory_order_acquire);
    if (wasRunning) {
        stopAudioDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
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

bool AudioEngine::reinitializeMonitorDevice(bool restart)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    bool wasRunning = monitorRunning.load(std::memory_order_acquire);
    if (wasRunning) {
        stopMonitorDevice();
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
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

// ------------------------------------------------------------
// Preselect devices (for use before starting audio)
// These just set the internal selection without reinitializing
// ------------------------------------------------------------
bool AudioEngine::preselectPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedPlaybackDeviceId       = d.id;
            selectedPlaybackDeviceIdStruct = d.deviceId;
            selectedPlaybackSet            = true;
            return true;
        }
    }
    return false;
}

bool AudioEngine::preselectCaptureDevice(const std::string& deviceId)
{
    auto devices = enumerateCaptureDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedCaptureDeviceId       = d.id;
            selectedCaptureDeviceIdStruct = d.deviceId;
            selectedCaptureSet            = true;
            return true;
        }
    }
    return false;
}

bool AudioEngine::preselectMonitorPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedMonitorPlaybackDeviceId       = d.id;
            selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
            selectedMonitorPlaybackSet            = true;
            return true;
        }
    }
    return false;
}

// ------------------------------------------------------------
// Set devices (reinitializes running device)
// ------------------------------------------------------------
bool AudioEngine::setPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedPlaybackDeviceId       = d.id;
            selectedPlaybackDeviceIdStruct = d.deviceId;
            selectedPlaybackSet            = true;
            std::cout << "[AudioEngine] Switching playback device to: " << d.name << std::endl;
            return reinitializeDevice(true);
        }
    }
    std::cerr << "[AudioEngine] Playback device not found: " << deviceId << std::endl;
    return false;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId)
{
    auto devices = enumerateCaptureDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedCaptureDeviceId       = d.id;
            selectedCaptureDeviceIdStruct = d.deviceId;
            selectedCaptureSet            = true;
            std::cout << "[AudioEngine] Switching capture device to: " << d.name << std::endl;
            return reinitializeDevice(true);
        }
    }
    std::cerr << "[AudioEngine] Capture device not found: " << deviceId << std::endl;
    return false;
}

bool AudioEngine::setMonitorPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedMonitorPlaybackDeviceId       = d.id;
            selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
            selectedMonitorPlaybackSet            = true;
            std::cout << "[AudioEngine] Switching monitor playback device to: " << d.name << std::endl;
            return reinitializeMonitorDevice(true);
        }
    }
    std::cerr << "[AudioEngine] Monitor playback device not found: " << deviceId << std::endl;
    return false;
}

// Recording extra input device
bool AudioEngine::setRecordingDevice(const std::string& deviceId)
{
    // Disable if "-1" or empty
    if (deviceId.empty() || deviceId == "-1") {
        recordingInputEnabled.store(false, std::memory_order_release);
        selectedRecordingCaptureSet = false;
        // stop device if running
        shutdownRecordingInputDevice();
        return true;
    }

    auto devices = enumerateCaptureDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedRecordingCaptureDeviceId       = d.id;
            selectedRecordingCaptureDeviceIdStruct = d.deviceId;
            selectedRecordingCaptureSet            = true;
            recordingInputEnabled.store(true, std::memory_order_release);
            return reinitializeRecordingInputDevice(true);
        }
    }
    return false;
}

// ------------------------------------------------------------
// Mixer controls
// ------------------------------------------------------------
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

void AudioEngine::setMicGainDB(float gainDB_)
{
    micGainDB.store(gainDB_, std::memory_order_relaxed);
    micGain.store(dBToLinear(gainDB_), std::memory_order_relaxed);
}

float AudioEngine::getMicGainDB() const
{
    return micGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMicGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    micGain.store(linear, std::memory_order_relaxed);
    micGainDB.store(20.0f * std::log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMicGainLinear() const
{
    return micGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainDB(float gainDB_)
{
    masterGainDB.store(gainDB_, std::memory_order_relaxed);
    masterGain.store(dBToLinear(gainDB_), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainDB() const
{
    return masterGainDB.load(std::memory_order_relaxed);
}

void AudioEngine::setMasterGainLinear(float linear)
{
    if (linear < 0.0f) linear = 0.0f;
    masterGain.store(linear, std::memory_order_relaxed);
    masterGainDB.store(20.0f * std::log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}

float AudioEngine::getMasterGainLinear() const
{
    return masterGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMicSoundboardBalance(float balance)
{
    balance = std::max(0.0f, std::min(1.0f, balance));
    micSoundboardBalance.store(balance, std::memory_order_relaxed);
}

float AudioEngine::getMicSoundboardBalance() const
{
    return micSoundboardBalance.load(std::memory_order_relaxed);
}

// Peaks
float AudioEngine::getMicPeakLevel() const { return micPeakLevel.load(std::memory_order_relaxed); }
float AudioEngine::getMasterPeakLevel() const { return masterPeakLevel.load(std::memory_order_relaxed); }
float AudioEngine::getMonitorPeakLevel() const { return monitorPeakLevel.load(std::memory_order_relaxed); }

void AudioEngine::resetPeakLevels()
{
    micPeakLevel.store(0.0f, std::memory_order_relaxed);
    masterPeakLevel.store(0.0f, std::memory_order_relaxed);
    monitorPeakLevel.store(0.0f, std::memory_order_relaxed);
}

// ------------------------------------------------------------
// Callbacks
// ------------------------------------------------------------
void AudioEngine::setClipFinishedCallback(ClipFinishedCallback cb)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipFinishedCallback = std::move(cb);
}

void AudioEngine::setClipErrorCallback(ClipErrorCallback cb)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipErrorCallback = std::move(cb);
}

// ------------------------------------------------------------
// Main callback + processing
// ------------------------------------------------------------
void AudioEngine::audioCallback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (engine && engine->deviceRunning.load(std::memory_order_acquire)) {
        engine->processAudio(pOutput, pInput, frameCount, pDevice->playback.channels, pDevice->capture.channels);
    } else if (pOutput) {
        std::memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
    }
}

void AudioEngine::processAudio(void* output, const void* input, ma_uint32 frameCount,
                               ma_uint32 playbackChannels, ma_uint32 captureChannels)
{
    if (!output) return;

    float* out = static_cast<float*>(output);
    const float* micIn = static_cast<const float*>(input);

    const ma_uint32 totalSamples = frameCount * playbackChannels;
    std::memset(out, 0, totalSamples * sizeof(float));

    // Balance multipliers
    float micMul = 1.0f, clipMul = 1.0f;
    computeBalanceMultipliers(micSoundboardBalance.load(std::memory_order_relaxed), micMul, clipMul);

    // Optional recording temp (stereo)
    const bool recActive = recording.load(std::memory_order_relaxed);
    thread_local std::vector<float> recTemp;
    if (recActive) {
        if (recTemp.size() != totalSamples) recTemp.resize(totalSamples);
        std::fill(recTemp.begin(), recTemp.end(), 0.0f);
    }

    // -------------------------
    // Mic
    // -------------------------
    float micPeak = 0.0f;
    const bool passthrough = micPassthroughEnabled.load(std::memory_order_relaxed);
    const bool micOn = micEnabled.load(std::memory_order_relaxed);
    const float micG = micGain.load(std::memory_order_relaxed);

    if (micIn && captureChannels > 0 && micOn) {
        for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
            float mono = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                mono += micIn[frame * captureChannels + ch];
            }
            mono = (mono / (float)captureChannels) * micG * micMul;

            micPeak = std::max(micPeak, std::abs(mono));

            // playback routing (only if passthrough ON)
            if (passthrough) {
                const ma_uint32 o = frame * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                    out[o + ch] += mono;
                }
            }

            // recording always records mic when micEnabled==true (even if passthrough OFF)
            if (recActive) {
                const ma_uint32 o = frame * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                    recTemp[o + ch] += mono;
                }
            }
        }

        // peak update
        float cur = micPeakLevel.load(std::memory_order_relaxed);
        if (micPeak > cur) micPeakLevel.store(micPeak, std::memory_order_relaxed);
    }

    // -------------------------
    // Clips mixing (MAIN ring buffers)
    // -------------------------
    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining) continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed) * clipMul;

        void* pRead = nullptr;
        ma_uint32 availFrames = frameCount;
        if (ma_pcm_rb_acquire_read(&slot.ringBufferMain, &availFrames, &pRead) == MA_SUCCESS && availFrames > 0 && pRead) {
            float* clip = static_cast<float*>(pRead); // stereo (2ch)

            if (playbackChannels == 2) {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    const ma_uint32 o = f * 2;
                    out[o]     += clip[f * 2]     * clipGain;
                    out[o + 1] += clip[f * 2 + 1] * clipGain;

                    if (recActive) {
                        recTemp[o]     += clip[f * 2]     * clipGain;
                        recTemp[o + 1] += clip[f * 2 + 1] * clipGain;
                    }
                }
            } else {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    float L = clip[f * 2]     * clipGain;
                    float R = clip[f * 2 + 1] * clipGain;
                    float mono = (L + R) * 0.5f;

                    const ma_uint32 o = f * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                        out[o + ch] += mono;
                        if (recActive) recTemp[o + ch] += mono;
                    }
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMain, availFrames);
            slot.playbackFrameCount.fetch_add((long long)availFrames, std::memory_order_relaxed);
            slot.queuedMainFrames.fetch_sub((long long)availFrames, std::memory_order_relaxed);
        }
    }

    // -------------------------
    // Recording-input device (optional)
    // If "-1" => disabled => not recorded.
    // -------------------------
    if (recActive && recordingInputEnabled.load(std::memory_order_relaxed)) {
        // ring buffer is mono frames
        void* pRead = nullptr;
        ma_uint32 want = frameCount;
        if (recordingInputRbData &&
            ma_pcm_rb_acquire_read(&recordingInputRb, &want, &pRead) == MA_SUCCESS && want > 0 && pRead) {
            float* mono = static_cast<float*>(pRead);
            for (ma_uint32 f = 0; f < want; ++f) {
                const float s = mono[f];
                const ma_uint32 o = f * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                    recTemp[o + ch] += s; // record only (not routed to playback)
                }
            }
            ma_pcm_rb_commit_read(&recordingInputRb, want);
        }
        // if not enough frames, missing portion is silence (fine)
    }

    // -------------------------
    // Master gain + peak + limiter (playback)
    // -------------------------
    const float mg = masterGain.load(std::memory_order_relaxed);
    float outPeak = 0.0f;

    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        out[i] *= mg;
        outPeak = std::max(outPeak, std::abs(out[i]));
        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

    float cur = masterPeakLevel.load(std::memory_order_relaxed);
    if (outPeak > cur) masterPeakLevel.store(outPeak, std::memory_order_relaxed);

    // -------------------------
    // Write recording buffer (post-master, post-limiter)
    // -------------------------
    if (recActive) {
        // apply master + limiter to recording too (matches what user hears)
        for (ma_uint32 i = 0; i < totalSamples; ++i) {
            float v = recTemp[i] * mg;
            if (v > 1.0f) v = 1.0f;
            if (v < -1.0f) v = -1.0f;
            recTemp[i] = v;
        }

        std::lock_guard<std::mutex> lock(recordingMutex);
        recordingBuffer.insert(recordingBuffer.end(), recTemp.begin(), recTemp.end());
        recordedFrames.fetch_add(frameCount, std::memory_order_relaxed);
    }
}

// ------------------------------------------------------------
// Monitor callback + processing (clips only)
// ------------------------------------------------------------
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

    float* out = static_cast<float*>(output);
    const ma_uint32 totalSamples = frameCount * playbackChannels;
    std::memset(out, 0, totalSamples * sizeof(float));

    // apply same balance to monitor clips
    float micMul = 1.0f, clipMul = 1.0f;
    computeBalanceMultipliers(micSoundboardBalance.load(std::memory_order_relaxed), micMul, clipMul);

    float peak = 0.0f;

    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining) continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed) * clipMul;

        void* pRead = nullptr;
        ma_uint32 availFrames = frameCount;
        if (ma_pcm_rb_acquire_read(&slot.ringBufferMon, &availFrames, &pRead) == MA_SUCCESS && availFrames > 0 && pRead) {
            float* clip = static_cast<float*>(pRead); // stereo

            if (playbackChannels == 2) {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    const ma_uint32 o = f * 2;
                    out[o]     += clip[f * 2]     * clipGain;
                    out[o + 1] += clip[f * 2 + 1] * clipGain;
                }
            } else {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    float L = clip[f * 2]     * clipGain;
                    float R = clip[f * 2 + 1] * clipGain;
                    float mono = (L + R) * 0.5f;

                    const ma_uint32 o = f * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                        out[o + ch] += mono;
                    }
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMon, availFrames);
        }
    }

    // limiter + peak
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        peak = std::max(peak, std::abs(out[i]));
        if (out[i] > 1.0f) out[i] = 1.0f;
        if (out[i] < -1.0f) out[i] = -1.0f;
    }

    float cur = monitorPeakLevel.load(std::memory_order_relaxed);
    if (peak > cur) monitorPeakLevel.store(peak, std::memory_order_relaxed);
}

// ------------------------------------------------------------
// Recording-input callback
// ------------------------------------------------------------
void AudioEngine::recordingInputCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !engine->recordingInputRunning.load(std::memory_order_acquire)) return;
    if (!pInput) return;
    engine->processRecordingInput(pInput, frameCount, pDevice->capture.channels);
}

void AudioEngine::processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels)
{
    if (!recordingInputRbData) return;

    const float* in = static_cast<const float*>(input);

    // write mono averaged samples into ring buffer
    // best-effort: if rb full, drop frames
    void* pWrite = nullptr;
    ma_uint32 toWrite = frameCount;

    if (ma_pcm_rb_acquire_write(&recordingInputRb, &toWrite, &pWrite) == MA_SUCCESS && toWrite > 0 && pWrite) {
        float* dst = static_cast<float*>(pWrite);
        for (ma_uint32 f = 0; f < toWrite; ++f) {
            float mono = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                mono += in[f * captureChannels + ch];
            }
            mono /= (float)captureChannels;
            dst[f] = mono;
        }
        ma_pcm_rb_commit_write(&recordingInputRb, toWrite);
    }
}

// ------------------------------------------------------------
// Clips - Decoder thread
// ------------------------------------------------------------
void AudioEngine::decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId)
{
    const std::string filepath = slot->filePath;
    if (filepath.empty()) {
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, ENGINE_SR);
    ma_decoder dec;
    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) != MA_SUCCESS) {
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        std::lock_guard<std::mutex> lock(engine->callbackMutex);
        if (engine->clipErrorCallback) engine->clipErrorCallback(slotId);
        return;
    }

    slot->sampleRate.store((int)dec.outputSampleRate, std::memory_order_relaxed);
    slot->channels.store((int)dec.outputChannels, std::memory_order_relaxed);

    // initial trim start
    double startMs = slot->trimStartMs.load(std::memory_order_relaxed);
    if (startMs > 0.0) {
        ma_uint64 startFrame = (ma_uint64)((startMs / 1000.0) * dec.outputSampleRate);
        ma_decoder_seek_to_pcm_frame(&dec, startFrame);
    }

    constexpr ma_uint32 kFrames = 1024;
    float buf[kFrames * 2];

    bool naturalEnd = false;

    while (true) {
        // stop
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;

        // pause holds decoder
        while (slot->state.load(std::memory_order_acquire) == ClipState::Paused) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;

        // seek request
        double seekMs = slot->seekPosMs.exchange(-1.0, std::memory_order_relaxed);
        if (seekMs >= 0.0) {
            ma_uint64 target = (ma_uint64)((seekMs / 1000.0) * dec.outputSampleRate);
            ma_decoder_seek_to_pcm_frame(&dec, target);
        }

        ma_uint64 framesRead = 0;
        ma_result rr = ma_decoder_read_pcm_frames(&dec, buf, kFrames, &framesRead);
        if (rr != MA_SUCCESS && rr != MA_AT_END) break;

        if (framesRead == 0) {
            if (slot->loop.load(std::memory_order_relaxed)) {
                double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                ma_uint64 sFrame = (ma_uint64)((sMs / 1000.0) * dec.outputSampleRate);
                ma_decoder_seek_to_pcm_frame(&dec, sFrame);
                continue;
            }
            naturalEnd = true;
            break;
        }

        // trim end check
        double endMs = slot->trimEndMs.load(std::memory_order_relaxed);
        if (endMs > 0.0) {
            ma_uint64 curFrame = 0;
            ma_decoder_get_cursor_in_pcm_frames(&dec, &curFrame);
            ma_uint64 endFrame = (ma_uint64)((endMs / 1000.0) * dec.outputSampleRate);
            if (curFrame >= endFrame) {
                if (slot->loop.load(std::memory_order_relaxed)) {
                    double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                    ma_uint64 sFrame = (ma_uint64)((sMs / 1000.0) * dec.outputSampleRate);
                    ma_decoder_seek_to_pcm_frame(&dec, sFrame);
                } else {
                    naturalEnd = true;
                    break;
                }
            }
        }

        ma_uint32 remaining = (ma_uint32)framesRead;
        float* cursor = buf;

        while (remaining > 0) {
            auto st = slot->state.load(std::memory_order_acquire);
            if (st == ClipState::Stopping) break;
            if (st == ClipState::Paused) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                continue;
            }

            void* wMain = nullptr;
            ma_uint32 toWrite = remaining;

            if (ma_pcm_rb_acquire_write(&slot->ringBufferMain, &toWrite, &wMain) == MA_SUCCESS && toWrite > 0 && wMain) {
                std::memcpy(wMain, cursor, toWrite * 2 * sizeof(float));
                ma_pcm_rb_commit_write(&slot->ringBufferMain, toWrite);
                slot->queuedMainFrames.fetch_add((long long)toWrite, std::memory_order_relaxed);

                // best-effort monitor
                void* wMon = nullptr;
                ma_uint32 toWriteMon = toWrite;
                if (ma_pcm_rb_acquire_write(&slot->ringBufferMon, &toWriteMon, &wMon) == MA_SUCCESS && toWriteMon > 0 && wMon) {
                    const ma_uint32 n = std::min(toWriteMon, toWrite);
                    std::memcpy(wMon, cursor, n * 2 * sizeof(float));
                    ma_pcm_rb_commit_write(&slot->ringBufferMon, n);
                }

                cursor += toWrite * 2;
                remaining -= toWrite;
            } else {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
            }
        }
    }

    ma_decoder_uninit(&dec);

    if (naturalEnd) {
        slot->state.store(ClipState::Draining, std::memory_order_release);

        // wait drain
        while (slot->queuedMainFrames.load(std::memory_order_relaxed) > 0) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping) break;
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }

        slot->state.store(ClipState::Stopped, std::memory_order_release);

        std::lock_guard<std::mutex> lock(engine->callbackMutex);
        if (engine->clipFinishedCallback) engine->clipFinishedCallback(slotId);
        return;
    }

    slot->state.store(ClipState::Stopped, std::memory_order_release);
}

// ------------------------------------------------------------
// Clips API
// ------------------------------------------------------------
std::pair<double, double> AudioEngine::loadClip(int slotId, const std::string& filepath)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return {0.0, 0.0};
    if (filepath.empty()) return {0.0, 0.0};

    ClipSlot& slot = clips[slotId];
    if (slot.state.load(std::memory_order_relaxed) != ClipState::Stopped) return {0.0, 0.0};

    const size_t bytes = RING_BUFFER_SIZE_IN_FRAMES * 2 * sizeof(float);

    if (!slot.ringBufferMainData) {
        slot.ringBufferMainData = std::malloc(bytes);
        if (!slot.ringBufferMainData) return {0.0, 0.0};
        ma_pcm_rb_init(ma_format_f32, 2, RING_BUFFER_SIZE_IN_FRAMES,
                       slot.ringBufferMainData, nullptr, &slot.ringBufferMain);
    }
    if (!slot.ringBufferMonData) {
        slot.ringBufferMonData = std::malloc(bytes);
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

    // duration
    double endSec = -1.0;
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, ENGINE_SR);
    ma_decoder dec;
    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS && dec.outputSampleRate > 0 && totalFrames > 0) {
            endSec = (double)totalFrames / (double)dec.outputSampleRate;
            slot.totalDurationMs.store(endSec * 1000.0, std::memory_order_relaxed);
        }
        ma_decoder_uninit(&dec);
    } else {
        return {0.0, 0.0};
    }

    return {0.0, endSec};
}

void AudioEngine::playClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    ClipSlot& slot = clips[slotId];
    if (slot.filePath.empty()) return;

    // resume if paused
    if (slot.state.load(std::memory_order_acquire) == ClipState::Paused) {
        slot.state.store(ClipState::Playing, std::memory_order_release);
        return;
    }

    // ensure at least one output running so it drains
    if (!isDeviceRunning() && !isMonitorRunning()) return;

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
    slot.decoderThread = std::thread(&AudioEngine::decoderThreadFunc, this, &slot, slotId);
}

void AudioEngine::pauseClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    auto st = clips[slotId].state.load(std::memory_order_acquire);
    if (st == ClipState::Playing || st == ClipState::Draining) {
        clips[slotId].state.store(ClipState::Paused, std::memory_order_release);
    }
}

void AudioEngine::resumeClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    if (clips[slotId].state.load(std::memory_order_acquire) == ClipState::Paused) {
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

void AudioEngine::setClipGain(int slotId, float gainDB)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].gain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getClipGain(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return 0.0f;
    float lin = clips[slotId].gain.load(std::memory_order_relaxed);
    return 20.0f * std::log10(std::max(lin, 0.000001f));
}

void AudioEngine::setClipTrim(int slotId, double startMs, double endMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].trimStartMs.store(startMs, std::memory_order_relaxed);
    clips[slotId].trimEndMs.store(endMs, std::memory_order_relaxed);
}

void AudioEngine::seekClip(int slotId, double positionMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return;
    clips[slotId].seekPosMs.store(positionMs, std::memory_order_relaxed);

    // update playbackFrameCount so UI reads correct position immediately
    double startMs = clips[slotId].trimStartMs.load(std::memory_order_relaxed);
    double diffMs = positionMs - startMs;
    if (diffMs < 0) diffMs = 0;

    int sr = clips[slotId].sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0) sr = (int)ENGINE_SR;

    long long frames = (long long)(diffMs * sr / 1000.0);
    clips[slotId].playbackFrameCount.store(frames, std::memory_order_relaxed);
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

double AudioEngine::getClipPlaybackPositionMs(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS) return 0.0;
    const ClipSlot& slot = clips[slotId];

    int sr = slot.sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0) sr = (int)ENGINE_SR;

    double frames = (double)slot.playbackFrameCount.load(std::memory_order_relaxed);
    double startMs = slot.trimStartMs.load(std::memory_order_relaxed);
    double curMs = (frames / (double)sr) * 1000.0;
    return startMs + curMs;
}

double AudioEngine::getFileDuration(const std::string& filepath)
{
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, ENGINE_SR);
    ma_decoder dec;
    double duration = -1.0;

    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS && dec.outputSampleRate > 0) {
            duration = (double)totalFrames / (double)dec.outputSampleRate;
        }
        ma_decoder_uninit(&dec);
    }
    return duration;
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

// ------------------------------------------------------------
// Recording
// ------------------------------------------------------------
bool AudioEngine::startRecording(const std::string& outputPath)
{
    if (recording.load(std::memory_order_relaxed)) return false;
    if (outputPath.empty()) return false;

    // Ensure main device running
    if (!deviceRunning.load(std::memory_order_relaxed)) {
        if (!startAudioDevice()) return false;
    }

    // If recording-input device is enabled, start it (it may be selected already).
    if (recordingInputEnabled.load(std::memory_order_relaxed)) {
        // safe start
        startRecordingInputDevice();
        ma_pcm_rb_reset(&recordingInputRb);
    }

    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        recordingBuffer.clear();
        recordingBuffer.reserve(ENGINE_SR * 2 * 60); // 60s stereo
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

    // stop recording input device if it was running (optional)
    if (recordingInputRunning.load(std::memory_order_relaxed)) {
        stopRecordingInputDevice();
    }

    std::vector<float> samples;
    {
        std::lock_guard<std::mutex> lock(recordingMutex);
        samples = std::move(recordingBuffer);
        recordingBuffer.clear();
    }

    if (samples.empty()) return false;

    return writeWavFile(recordingOutputPath, samples, (int)ENGINE_SR, 2);
}

bool AudioEngine::isRecording() const
{
    return recording.load(std::memory_order_relaxed);
}

float AudioEngine::getRecordingDuration() const
{
    uint64_t frames = recordedFrames.load(std::memory_order_relaxed);
    return (float)frames / (float)ENGINE_SR;
}

// ------------------------------------------------------------
// WAV writer (float [-1..1] -> int16 PCM)
// ------------------------------------------------------------
bool AudioEngine::writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels)
{
    if (samples.empty() || path.empty()) return false;

    FILE* file = fopen(path.c_str(), "wb");
    if (!file) return false;

    const uint32_t dataSize = (uint32_t)(samples.size() * sizeof(int16_t));
    const uint32_t fileSize = 36 + dataSize;

    fwrite("RIFF", 1, 4, file);
    fwrite(&fileSize, 4, 1, file);
    fwrite("WAVE", 1, 4, file);

    fwrite("fmt ", 1, 4, file);
    uint32_t fmtSize = 16;
    fwrite(&fmtSize, 4, 1, file);

    uint16_t audioFormat = 1; // PCM
    fwrite(&audioFormat, 2, 1, file);

    uint16_t numChannels = (uint16_t)channels;
    fwrite(&numChannels, 2, 1, file);

    uint32_t sr = (uint32_t)sampleRate;
    fwrite(&sr, 4, 1, file);

    uint32_t byteRate = sr * numChannels * 2;
    fwrite(&byteRate, 4, 1, file);

    uint16_t blockAlign = (uint16_t)(numChannels * 2);
    fwrite(&blockAlign, 2, 1, file);

    uint16_t bitsPerSample = 16;
    fwrite(&bitsPerSample, 2, 1, file);

    fwrite("data", 1, 4, file);
    fwrite(&dataSize, 4, 1, file);

    for (float s : samples) {
        if (s > 1.0f) s = 1.0f;
        if (s < -1.0f) s = -1.0f;
        int16_t pcm = (int16_t)(s * 32767.0f);
        fwrite(&pcm, 2, 1, file);
    }

    fclose(file);
    return true;
}
