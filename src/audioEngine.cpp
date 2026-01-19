// ============================================================
// IMPORTANT: MINIAUDIO_IMPLEMENTATION is defined in miniaudio_impl.cpp
// Do NOT define it here or you will get multiply defined symbol errors
// ============================================================

#include "audioEngine.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>  // FILE*
#include <cstdlib> // malloc/free
#include <cstring>
#include <iostream>
#include <thread>

#include "ffmpeg_decoder.h"

#ifdef _WIN32
#include <windows.h>

// Helper function to convert UTF-8 string to wide string for Windows file APIs
static std::wstring utf8ToWide(const std::string& utf8)
{
    if (utf8.empty())
        return std::wstring();
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    if (wlen <= 0)
        return std::wstring();
    std::wstring wstr(wlen, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wstr[0], wlen);
    // Remove trailing null if present
    if (!wstr.empty() && wstr.back() == L'\0')
        wstr.pop_back();
    return wstr;
}
#endif

// ------------------------------------------------------------
// Local helper
// ------------------------------------------------------------
static inline float clamp01(float x)
{
    return std::max(0.0f, std::min(1.0f, x));
}

// ------------------------------------------------------------
// CTOR/DTOR
// ------------------------------------------------------------
AudioEngine::AudioEngine()
{
    // keep pointers null until init
    context = nullptr;
    playbackDevice = nullptr;
    captureDevice = nullptr;
    monitorDevice = nullptr;
    recordingInputDevice = nullptr;
}

AudioEngine::AudioEngine(void* parent) : AudioEngine()
{
    (void)parent;
}

AudioEngine::~AudioEngine()
{
    // stop recording first
    stopRecording();

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

    // stop main devices
    if (deviceRunning.load(std::memory_order_acquire)) {
        stopAudioDevice();
    }

    // stop/free clips
    for (int i = 0; i < MAX_CLIPS; ++i) {
        unloadClip(i);
    }

    // cleanup main devices
    if (playbackDevice) {
        ma_device_uninit(playbackDevice);
        delete playbackDevice;
        playbackDevice = nullptr;
    }
    if (captureDevice) {
        ma_device_uninit(captureDevice);
        delete captureDevice;
        captureDevice = nullptr;
    }

    // ringbuffers
    shutdownCaptureRingBuffer();
    shutdownRecordingRingBuffer();

    // cleanup context
    if (context) {
        ma_context_uninit(context);
        delete context;
        context = nullptr;
    }
}

// ------------------------------------------------------------
// Audio Configuration
// ------------------------------------------------------------
void AudioEngine::setAudioConfig(ma_uint32 sampleRate, ma_uint32 bufferSize, ma_uint32 periods, ma_uint32 channels)
{
    if (sampleRate != 44100 && sampleRate != 48000 && sampleRate != 96000) {
        std::cout << "[AudioEngine] Invalid sample rate: " << sampleRate << ", using default\n";
        sampleRate = DEFAULT_SAMPLE_RATE;
    }
    if (bufferSize != 256 && bufferSize != 512 && bufferSize != 1024 && bufferSize != 2048 && bufferSize != 4096) {
        std::cout << "[AudioEngine] Invalid buffer size: " << bufferSize << ", using default\n";
        bufferSize = DEFAULT_BUFFER_SIZE;
    }
    if (periods < 2 || periods > 4) {
        std::cout << "[AudioEngine] Invalid buffer periods: " << periods << ", using default\n";
        periods = DEFAULT_BUFFER_PERIODS;
    }
    if (channels != 1 && channels != 2) {
        std::cout << "[AudioEngine] Invalid channels: " << channels << ", using default\n";
        channels = DEFAULT_CHANNELS;
    }

    m_sampleRate = sampleRate;
    m_bufferSizeFrames = bufferSize;
    m_bufferPeriods = periods;
    m_channels = channels;

    std::cout << "[AudioEngine] Configured: SR=" << m_sampleRate << ", BufferSize=" << m_bufferSizeFrames
              << ", Periods=" << m_bufferPeriods << ", Channels=" << m_channels << "\n";
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
    balance = clamp01(balance);

    if (balance <= 0.5f) {
        micMul = 1.0f;
        clipMul = balance * 2.0f; // 0..1
    } else {
        clipMul = 1.0f;
        micMul = (1.0f - balance) * 2.0f; // 1..0
    }
}

// ------------------------------------------------------------
// Ring buffer sizing helpers
// ------------------------------------------------------------
ma_uint32 AudioEngine::getRingBufferSize() const
{
    // Clip ring buffers: a few blocks worth so decoder can run ahead
    // (stereo frames)
    const ma_uint32 blocks = m_bufferPeriods * 8;
    return std::max<ma_uint32>(m_bufferSizeFrames * blocks, 4096);
}

ma_uint32 AudioEngine::getRecInputRbSize() const
{
    // Recording-input mono RB: keep a couple seconds buffered
    const ma_uint32 seconds = 2;
    return std::max<ma_uint32>(m_sampleRate * seconds, 4096);
}

// ------------------------------------------------------------
// Context
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

// ------------------------------------------------------------
// Capture ringbuffer (mono f32)
// ------------------------------------------------------------
bool AudioEngine::initCaptureRingBuffer(ma_uint32 sampleRate)
{
    (void)sampleRate;

    if (captureRbData) {
        ma_pcm_rb_reset(&captureRb);
        return true;
    }

    captureRbFrames = std::max<ma_uint32>(m_sampleRate * 2, 4096); // ~2 seconds mono
    const size_t bytes = (size_t)captureRbFrames * sizeof(float);

    captureRbData = std::malloc(bytes);
    if (!captureRbData) {
        captureRbFrames = 0;
        return false;
    }

    if (ma_pcm_rb_init(ma_format_f32, 1, captureRbFrames, captureRbData, nullptr, &captureRb) != MA_SUCCESS) {
        std::free(captureRbData);
        captureRbData = nullptr;
        captureRbFrames = 0;
        return false;
    }
    return true;
}

void AudioEngine::shutdownCaptureRingBuffer()
{
    if (captureRbData) {
        ma_pcm_rb_uninit(&captureRb);
        std::free(captureRbData);
        captureRbData = nullptr;
        captureRbFrames = 0;
    }
}

// ------------------------------------------------------------
// Recording ringbuffer (float32 channels)
// ------------------------------------------------------------
bool AudioEngine::initRecordingRingBuffer(ma_uint32 sampleRate, ma_uint32 channels)
{
    // Keep ~30 seconds in RAM
    const ma_uint32 seconds = 30;
    const ma_uint32 frames = sampleRate * seconds;

    shutdownRecordingRingBuffer();

    const size_t bytes = (size_t)frames * (size_t)channels * sizeof(float);
    recordingRbData = std::malloc(bytes);
    if (!recordingRbData) {
        recordingRbFrames = 0;
        return false;
    }

    ma_result r = ma_pcm_rb_init(ma_format_f32, channels, frames, recordingRbData, nullptr, &recordingRb);
    if (r != MA_SUCCESS) {
        std::free(recordingRbData);
        recordingRbData = nullptr;
        recordingRbFrames = 0;
        return false;
    }

    recordingRbFrames = frames;
    return true;
}

void AudioEngine::shutdownRecordingRingBuffer()
{
    if (recordingRbData) {
        ma_pcm_rb_uninit(&recordingRb);
        std::free(recordingRbData);
        recordingRbData = nullptr;
        recordingRbFrames = 0;
    }
}

// ------------------------------------------------------------
// Enumeration
// ------------------------------------------------------------
std::vector<AudioEngine::AudioDeviceInfo> AudioEngine::enumeratePlaybackDevices()
{
    std::vector<AudioDeviceInfo> devices;
    if (!initContext())
        return devices;

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
        info.id = info.name; // UI uses name as ID
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
// Preselect devices
// ------------------------------------------------------------
bool AudioEngine::preselectPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedPlaybackDeviceId = d.id;
            selectedPlaybackDeviceIdStruct = d.deviceId;
            selectedPlaybackSet = true;
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
            selectedCaptureDeviceId = d.id;
            selectedCaptureDeviceIdStruct = d.deviceId;
            selectedCaptureSet = true;
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
            selectedMonitorPlaybackDeviceId = d.id;
            selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
            selectedMonitorPlaybackSet = true;
            return true;
        }
    }
    return false;
}

// ------------------------------------------------------------
// Refresh device ID structs after context rebuild
// ------------------------------------------------------------
void AudioEngine::refreshDeviceIdStructs()
{
    if (selectedPlaybackSet && !selectedPlaybackDeviceId.empty()) {
        auto devices = enumeratePlaybackDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedPlaybackDeviceId || d.name == selectedPlaybackDeviceId) {
                selectedPlaybackDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed playback device struct: " << d.name << "\n";
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected playback device not found: " << selectedPlaybackDeviceId
                      << "\n";
            selectedPlaybackSet = false;
        }
    }

    if (selectedCaptureSet && !selectedCaptureDeviceId.empty()) {
        auto devices = enumerateCaptureDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedCaptureDeviceId || d.name == selectedCaptureDeviceId) {
                selectedCaptureDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed capture device struct: " << d.name << "\n";
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected capture device not found: " << selectedCaptureDeviceId
                      << "\n";
            selectedCaptureSet = false;
        }
    }

    if (selectedMonitorPlaybackSet && !selectedMonitorPlaybackDeviceId.empty()) {
        auto devices = enumeratePlaybackDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedMonitorPlaybackDeviceId || d.name == selectedMonitorPlaybackDeviceId) {
                selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed monitor device struct: " << d.name << "\n";
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected monitor device not found: "
                      << selectedMonitorPlaybackDeviceId << "\n";
            selectedMonitorPlaybackSet = false;
        }
    }

    if (selectedRecordingCaptureSet && !selectedRecordingCaptureDeviceId.empty()) {
        auto devices = enumerateCaptureDevices();
        bool found = false;
        for (const auto& d : devices) {
            if (d.id == selectedRecordingCaptureDeviceId || d.name == selectedRecordingCaptureDeviceId) {
                selectedRecordingCaptureDeviceIdStruct = d.deviceId;
                found = true;
                std::cout << "[AudioEngine] Refreshed recording input device struct: " << d.name << "\n";
                break;
            }
        }
        if (!found) {
            std::cout << "[AudioEngine] Previously selected recording input device not found: "
                      << selectedRecordingCaptureDeviceId << "\n";
            selectedRecordingCaptureSet = false;
        }
    }
}

// ------------------------------------------------------------
// Device init (split pipeline)
// ------------------------------------------------------------
bool AudioEngine::initPlaybackDevice()
{
    if (playbackDevice)
        return true;
    if (!initContext())
        return false;

    playbackDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_f32;
    cfg.playback.channels = m_channels;
    cfg.sampleRate = m_sampleRate;
    cfg.dataCallback = &AudioEngine::playbackCallback;
    cfg.pUserData = this;
    cfg.periodSizeInFrames = m_bufferSizeFrames;
    cfg.periods = m_bufferPeriods;

    if (selectedPlaybackSet) {
        cfg.playback.pDeviceID = &selectedPlaybackDeviceIdStruct;
    }

    if (ma_device_init(context, &cfg, playbackDevice) != MA_SUCCESS) {
        delete playbackDevice;
        playbackDevice = nullptr;
        return false;
    }

    playbackRunning.store(false, std::memory_order_release);
    return true;
}

bool AudioEngine::initCaptureDevice()
{
    if (captureDevice)
        return true;
    if (!initContext())
        return false;

    captureDevice = new ma_device();

    // Try a few capture formats for robustness (same idea as your old duplex tries)
    struct TryCfg
    {
        ma_format fmt;
        ma_uint32 ch;
    };
    TryCfg tries[] = {
        {ma_format_f32, 2},
        {ma_format_f32, 1},
        {ma_format_s16, 2},
        {ma_format_s16, 1},
    };

    for (auto& t : tries) {
        ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
        cfg.capture.format = t.fmt;
        cfg.capture.channels = t.ch;
        cfg.sampleRate = m_sampleRate;
        cfg.dataCallback = &AudioEngine::captureCallback;
        cfg.pUserData = this;
        cfg.periodSizeInFrames = m_bufferSizeFrames;
        cfg.periods = m_bufferPeriods;

        if (selectedCaptureSet) {
            cfg.capture.pDeviceID = &selectedCaptureDeviceIdStruct;
        }

        if (ma_device_init(context, &cfg, captureDevice) == MA_SUCCESS) {
            // init capture ringbuffer after we know capture is alive
            if (!initCaptureRingBuffer(m_sampleRate)) {
                ma_device_uninit(captureDevice);
                continue;
            }
            captureRunning.store(false, std::memory_order_release);
            return true;
        }
    }

    delete captureDevice;
    captureDevice = nullptr;
    return false;
}

bool AudioEngine::startAudioDevice()
{
    // Ensure devices exist
    if (!playbackDevice && !initPlaybackDevice())
        return false;
    if (!captureDevice && !initCaptureDevice())
        return false;

    // Start capture first so playback has data
    if (ma_device_start(captureDevice) != MA_SUCCESS)
        return false;
    captureRunning.store(true, std::memory_order_release);

    if (ma_device_start(playbackDevice) != MA_SUCCESS) {
        ma_device_stop(captureDevice);
        captureRunning.store(false, std::memory_order_release);
        return false;
    }
    playbackRunning.store(true, std::memory_order_release);

    deviceRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopAudioDevice()
{
    if (!playbackDevice && !captureDevice)
        return false;

    deviceRunning.store(false, std::memory_order_release);

    if (playbackDevice) {
        ma_device_stop(playbackDevice);
        playbackRunning.store(false, std::memory_order_release);
    }
    if (captureDevice) {
        ma_device_stop(captureDevice);
        captureRunning.store(false, std::memory_order_release);
    }
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
    if (monitorDevice)
        return true;
    if (!initContext())
        return false;

    monitorDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_f32;
    cfg.playback.channels = m_channels;
    cfg.sampleRate = m_sampleRate;
    cfg.dataCallback = &AudioEngine::monitorCallback;
    cfg.pUserData = this;
    cfg.periodSizeInFrames = m_bufferSizeFrames;
    cfg.periods = m_bufferPeriods;

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
    if (!monitorDevice && !initMonitorDevice())
        return false;
    if (ma_device_start(monitorDevice) != MA_SUCCESS)
        return false;
    monitorRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopMonitorDevice()
{
    if (!monitorDevice)
        return false;
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
    if (recordingInputDevice)
        return true;
    if (!initContext())
        return false;

    recordingInputDevice = new ma_device();

    ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
    cfg.capture.format = ma_format_f32;
    cfg.capture.channels = m_channels;
    cfg.sampleRate = m_sampleRate;
    cfg.dataCallback = &AudioEngine::recordingInputCallback;
    cfg.pUserData = this;
    cfg.periodSizeInFrames = m_bufferSizeFrames;
    cfg.periods = m_bufferPeriods;

    if (selectedRecordingCaptureSet) {
        cfg.capture.pDeviceID = &selectedRecordingCaptureDeviceIdStruct;
    }

    if (ma_device_init(context, &cfg, recordingInputDevice) != MA_SUCCESS) {
        delete recordingInputDevice;
        recordingInputDevice = nullptr;
        return false;
    }

    // init mono ringbuffer
    if (!recordingInputRbData) {
        const size_t bytes = (size_t)getRecInputRbSize() * sizeof(float);
        recordingInputRbData = std::malloc(bytes);
        if (!recordingInputRbData)
            return false;

        if (ma_pcm_rb_init(ma_format_f32, 1, getRecInputRbSize(), recordingInputRbData, nullptr, &recordingInputRb) !=
            MA_SUCCESS) {
            std::free(recordingInputRbData);
            recordingInputRbData = nullptr;
            return false;
        }
    } else {
        ma_pcm_rb_reset(&recordingInputRb);
    }

    recordingInputCaptureChannels.store((int)recordingInputDevice->capture.channels, std::memory_order_relaxed);
    return true;
}

bool AudioEngine::startRecordingInputDevice()
{
    if (!recordingInputDevice && !initRecordingInputDevice())
        return false;
    if (ma_device_start(recordingInputDevice) != MA_SUCCESS)
        return false;
    recordingInputRunning.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopRecordingInputDevice()
{
    if (!recordingInputDevice)
        return false;
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

    if (!initRecordingInputDevice())
        return false;

    if (restart || wasRunning)
        return startRecordingInputDevice();
    return true;
}

// ------------------------------------------------------------
// Hotplug refresh: rebuild context and devices
// ------------------------------------------------------------
bool AudioEngine::rebuildContextAndDevices(bool restartRunning)
{
    static std::mutex m;
    std::lock_guard<std::mutex> lock(m);

    std::cout << "[AudioEngine] Rebuilding context and devices...\n";

    const bool mainWasRunning = deviceRunning.load(std::memory_order_acquire);
    const bool monWasRunning = monitorRunning.load(std::memory_order_acquire);
    const bool recInWasRunning = recordingInputRunning.load(std::memory_order_acquire);

    if (mainWasRunning)
        stopAudioDevice();
    if (monWasRunning)
        stopMonitorDevice();
    if (recInWasRunning)
        stopRecordingInputDevice();

    std::this_thread::sleep_for(std::chrono::milliseconds(30));

    // uninit devices
    if (playbackDevice) {
        ma_device_uninit(playbackDevice);
        delete playbackDevice;
        playbackDevice = nullptr;
    }
    if (captureDevice) {
        ma_device_uninit(captureDevice);
        delete captureDevice;
        captureDevice = nullptr;
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
    if (!initContext())
        return false;

    refreshDeviceIdStructs();

    if (!initPlaybackDevice())
        return false;
    if (!initCaptureDevice())
        return false;

    if (selectedMonitorPlaybackSet) {
        initMonitorDevice();
    }
    if (recordingInputEnabled.load(std::memory_order_relaxed) && selectedRecordingCaptureSet) {
        initRecordingInputDevice();
    }

    if (restartRunning) {
        if (mainWasRunning)
            startAudioDevice();
        if (monWasRunning)
            startMonitorDevice();
        if (recInWasRunning)
            startRecordingInputDevice();
    }

    std::cout << "[AudioEngine] Context and devices rebuilt successfully\n";
    return true;
}

bool AudioEngine::refreshPlaybackDevices()
{
    return rebuildContextAndDevices(true);
}
bool AudioEngine::refreshInputDevices()
{
    return rebuildContextAndDevices(true);
}

// ------------------------------------------------------------
// Set devices (reinit)
// ------------------------------------------------------------
bool AudioEngine::setPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedPlaybackDeviceId = d.id;
            selectedPlaybackDeviceIdStruct = d.deviceId;
            selectedPlaybackSet = true;

            std::cout << "[AudioEngine] Switching playback device to: " << d.name << "\n";
            return rebuildContextAndDevices(true);
        }
    }
    std::cerr << "[AudioEngine] Playback device not found: " << deviceId << "\n";
    return false;
}

bool AudioEngine::setCaptureDevice(const std::string& deviceId)
{
    auto devices = enumerateCaptureDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedCaptureDeviceId = d.id;
            selectedCaptureDeviceIdStruct = d.deviceId;
            selectedCaptureSet = true;

            std::cout << "[AudioEngine] Switching capture device to: " << d.name << "\n";
            return rebuildContextAndDevices(true);
        }
    }
    std::cerr << "[AudioEngine] Capture device not found: " << deviceId << "\n";
    return false;
}

bool AudioEngine::setMonitorPlaybackDevice(const std::string& deviceId)
{
    auto devices = enumeratePlaybackDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedMonitorPlaybackDeviceId = d.id;
            selectedMonitorPlaybackDeviceIdStruct = d.deviceId;
            selectedMonitorPlaybackSet = true;

            std::cout << "[AudioEngine] Switching monitor playback device to: " << d.name << "\n";
            return rebuildContextAndDevices(true);
        }
    }
    std::cerr << "[AudioEngine] Monitor playback device not found: " << deviceId << "\n";
    return false;
}

// Recording extra input device
bool AudioEngine::setRecordingDevice(const std::string& deviceId)
{
    if (deviceId.empty() || deviceId == "-1") {
        recordingInputEnabled.store(false, std::memory_order_release);
        selectedRecordingCaptureSet = false;
        shutdownRecordingInputDevice();
        return true;
    }

    auto devices = enumerateCaptureDevices();
    for (const auto& d : devices) {
        if (d.id == deviceId || d.name == deviceId) {
            selectedRecordingCaptureDeviceId = d.id;
            selectedRecordingCaptureDeviceIdStruct = d.deviceId;
            selectedRecordingCaptureSet = true;
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
    if (linear < 0.0f)
        linear = 0.0f;
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
    if (linear < 0.0f)
        linear = 0.0f;
    masterGain.store(linear, std::memory_order_relaxed);
    masterGainDB.store(20.0f * std::log10(std::max(linear, 0.000001f)), std::memory_order_relaxed);
}
float AudioEngine::getMasterGainLinear() const
{
    return masterGain.load(std::memory_order_relaxed);
}

void AudioEngine::setMicSoundboardBalance(float balance)
{
    micSoundboardBalance.store(clamp01(balance), std::memory_order_relaxed);
}
float AudioEngine::getMicSoundboardBalance() const
{
    return micSoundboardBalance.load(std::memory_order_relaxed);
}

// Peaks
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

// ------------------------------------------------------------
// Clip callbacks
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

void AudioEngine::setClipLoopedCallback(ClipLoopedCallback cb)
{
    std::lock_guard<std::mutex> lock(callbackMutex);
    clipLoopedCallback = std::move(cb);
}

// ------------------------------------------------------------
// Capture callback + processing
// ------------------------------------------------------------
void AudioEngine::captureCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine)
        return;

    if (!engine->deviceRunning.load(std::memory_order_acquire))
        return;
    engine->processCaptureInput(pInput, frameCount, pDevice->capture.channels, pDevice->capture.format);
}

void AudioEngine::processCaptureInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels, ma_format fmt)
{
    if (!captureRbData)
        return;

    const bool micOn = micEnabled.load(std::memory_order_relaxed);
    const float micG = micGain.load(std::memory_order_relaxed);

    float peak = 0.0f;

    void* pWrite = nullptr;
    ma_uint32 framesToWrite = frameCount;

    if (ma_pcm_rb_acquire_write(&captureRb, &framesToWrite, &pWrite) != MA_SUCCESS || framesToWrite == 0 || !pWrite) {
        return; // drop if full
    }

    float* dst = static_cast<float*>(pWrite);

    auto readSample = [&](ma_uint32 frame, ma_uint32 ch) -> float {
        if (!input || captureChannels == 0)
            return 0.0f;
        switch (fmt) {
        case ma_format_f32: {
            const float* in = static_cast<const float*>(input);
            return in[frame * captureChannels + ch];
        }
        case ma_format_s16: {
            const int16_t* in = static_cast<const int16_t*>(input);
            return (float)in[frame * captureChannels + ch] / 32768.0f;
        }
        default:
            return 0.0f;
        }
    };

    for (ma_uint32 f = 0; f < framesToWrite; ++f) {
        float mono = 0.0f;
        if (micOn && input && captureChannels > 0) {
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch) {
                mono += readSample(f, ch);
            }
            mono = (mono / (float)captureChannels) * micG;
        } else {
            mono = 0.0f;
        }

        peak = std::max(peak, std::abs(mono));
        dst[f] = mono;
    }

    ma_pcm_rb_commit_write(&captureRb, framesToWrite);

    // peak meter
    float cur = micPeakLevel.load(std::memory_order_relaxed);
    if (peak > cur)
        micPeakLevel.store(peak, std::memory_order_relaxed);
}

// ------------------------------------------------------------
// Playback callback + processing
// ------------------------------------------------------------
void AudioEngine::playbackCallback(ma_device* pDevice, void* pOutput, const void*, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !pOutput)
        return;

    if (!engine->deviceRunning.load(std::memory_order_acquire)) {
        std::memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
        return;
    }

    engine->processPlaybackAudio(pOutput, frameCount, pDevice->playback.channels);
}

void AudioEngine::processPlaybackAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels)
{
    float* out = static_cast<float*>(output);
    const ma_uint32 totalSamples = frameCount * playbackChannels;
    std::memset(out, 0, totalSamples * sizeof(float));

    // balance
    float micMul = 1.0f, clipMul = 1.0f;
    computeBalanceMultipliers(micSoundboardBalance.load(std::memory_order_relaxed), micMul, clipMul);

    const bool micOn = micEnabled.load(std::memory_order_relaxed);
    const bool passthrough = micPassthroughEnabled.load(std::memory_order_relaxed);

    const bool recActive = recording.load(std::memory_order_relaxed);

    // recording scratch
    if (recActive) {
        if (recTempScratch.size() != (size_t)totalSamples)
            recTempScratch.resize(totalSamples);
        std::fill(recTempScratch.begin(), recTempScratch.end(), 0.0f);
    }

    // --------------------------------------------------------
    // MIC from captureRb (mono float) -> playback (optional), recording (always if micOn)
    // --------------------------------------------------------
    std::vector<float> micMono;
    micMono.resize(frameCount, 0.0f);

    if (captureRbData) {
        void* pRead = nullptr;
        ma_uint32 want = frameCount;

        if (ma_pcm_rb_acquire_read(&captureRb, &want, &pRead) == MA_SUCCESS && want > 0 && pRead) {
            float* src = static_cast<float*>(pRead);
            for (ma_uint32 f = 0; f < want; ++f)
                micMono[f] = src[f];
            ma_pcm_rb_commit_read(&captureRb, want);
        }
    }

    const bool recordMic = recordMicEnabled.load(std::memory_order_relaxed);
    const bool recordClips = recordPlaybackEnabled.load(std::memory_order_relaxed);

    if (micOn) {
        for (ma_uint32 f = 0; f < frameCount; ++f) {
            // Use full mic gain (without balance) for recording
            const float monoFull = micMono[f];
            // Apply balance multiplier only for live playback monitoring
            const float monoBalanced = monoFull * micMul;

            // to playback only if passthrough (use balanced audio)
            if (passthrough) {
                const ma_uint32 o = f * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels; ++ch)
                    out[o + ch] += monoBalanced;
            }

            // NOTE: Main microphone is NOT recorded - only recording input device is used
        }
    }

    // --------------------------------------------------------
    // Clips mixing (MAIN ring buffers)
    // --------------------------------------------------------
    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining)
            continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed) * clipMul;
        const bool isMonitorOnly = slot.monitorOnly.load(std::memory_order_relaxed);

        void* pRead = nullptr;
        ma_uint32 availFrames = frameCount;

        if (ma_pcm_rb_acquire_read(&slot.ringBufferMain, &availFrames, &pRead) == MA_SUCCESS && availFrames > 0 &&
            pRead) {
            float* clip = static_cast<float*>(pRead); // stereo 2ch

            // Only mix into main output if NOT monitor-only
            if (!isMonitorOnly) {
                if (playbackChannels == 2) {
                    for (ma_uint32 f = 0; f < availFrames; ++f) {
                        const ma_uint32 o = f * 2;
                        const float L = clip[f * 2] * clipGain;
                        const float R = clip[f * 2 + 1] * clipGain;

                        out[o] += L;
                        out[o + 1] += R;

                        // Only add clips to recording if recordClips is enabled
                        if (recActive && recordClips) {
                            recTempScratch[o] += L;
                            recTempScratch[o + 1] += R;
                        }
                    }
                } else {
                    for (ma_uint32 f = 0; f < availFrames; ++f) {
                        const float L = clip[f * 2] * clipGain;
                        const float R = clip[f * 2 + 1] * clipGain;
                        const float mono = (L + R) * 0.5f;

                        const ma_uint32 o = f * playbackChannels;
                        for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                            out[o + ch] += mono;
                            // Only add clips to recording if recordClips is enabled
                            if (recActive && recordClips)
                                recTempScratch[o + ch] += mono;
                        }
                    }
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMain, availFrames);
            slot.playbackFrameCount.fetch_add((long long)availFrames, std::memory_order_relaxed);
            slot.queuedMainFrames.fetch_sub((long long)availFrames, std::memory_order_relaxed);
        }
    }

    // --------------------------------------------------------
    // Recording-input device mono rb (always recorded when active)
    // --------------------------------------------------------
    if (recActive && recordingInputEnabled.load(std::memory_order_relaxed)) {
        void* pRead = nullptr;
        ma_uint32 want = frameCount;

        if (recordingInputRbData && ma_pcm_rb_acquire_read(&recordingInputRb, &want, &pRead) == MA_SUCCESS &&
            want > 0 && pRead) {
            float* mono = static_cast<float*>(pRead);

            for (ma_uint32 f = 0; f < want; ++f) {
                const float s = mono[f];
                const ma_uint32 o = f * playbackChannels;
                for (ma_uint32 ch = 0; ch < playbackChannels; ++ch) {
                    recTempScratch[o + ch] += s;
                }
            }

            ma_pcm_rb_commit_read(&recordingInputRb, want);
        }
    }

    // --------------------------------------------------------
    // Master gain + transparent limiter
    // --------------------------------------------------------
    const float mg = masterGain.load(std::memory_order_relaxed);
    constexpr float targetPeak = 0.95f;

    float prePeak = 0.0f;
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        float v = out[i] * mg;
        out[i] = v;
        prePeak = std::max(prePeak, std::abs(v));
    }

    if (prePeak > targetPeak && prePeak > 0.000001f) {
        const float limiterGain = targetPeak / prePeak;
        for (ma_uint32 i = 0; i < totalSamples; ++i)
            out[i] *= limiterGain;
    }

    // master peak meter (post)
    float outPeak = 0.0f;
    for (ma_uint32 i = 0; i < totalSamples; ++i)
        outPeak = std::max(outPeak, std::abs(out[i]));
    float cur = masterPeakLevel.load(std::memory_order_relaxed);
    if (outPeak > cur)
        masterPeakLevel.store(outPeak, std::memory_order_relaxed);

    // --------------------------------------------------------
    // Recording output (push to recordingRb, realtime-safe)
    // --------------------------------------------------------
    if (recActive && recordingRbData) {
        // Apply same mg + limiter to recorded mix
        float rPeak = 0.0f;
        for (ma_uint32 i = 0; i < totalSamples; ++i) {
            float v = recTempScratch[i] * mg;
            recTempScratch[i] = v;
            rPeak = std::max(rPeak, std::abs(v));
        }

        if (rPeak > targetPeak && rPeak > 0.000001f) {
            const float rLimiter = targetPeak / rPeak;
            for (ma_uint32 i = 0; i < totalSamples; ++i)
                recTempScratch[i] *= rLimiter;
        }

        void* pWrite = nullptr;
        ma_uint32 framesToWrite = frameCount;

        if (ma_pcm_rb_acquire_write(&recordingRb, &framesToWrite, &pWrite) == MA_SUCCESS && framesToWrite > 0 &&
            pWrite) {
            const size_t samplesToCopy = (size_t)framesToWrite * (size_t)playbackChannels;
            std::memcpy(pWrite, recTempScratch.data(), samplesToCopy * sizeof(float));
            ma_pcm_rb_commit_write(&recordingRb, framesToWrite);
            recordedFrames.fetch_add(framesToWrite, std::memory_order_relaxed);
        }
        // If full: drop frames (prefer glitch-free playback)
    }
}

// ------------------------------------------------------------
// Monitor callback + processing (clips only)
// ------------------------------------------------------------
void AudioEngine::monitorCallback(ma_device* pDevice, void* pOutput, const void*, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !engine->monitorRunning.load(std::memory_order_acquire) || !pOutput) {
        if (pOutput)
            std::memset(pOutput, 0, frameCount * pDevice->playback.channels * sizeof(float));
        return;
    }
    engine->processMonitorAudio(pOutput, frameCount, pDevice->playback.channels);
}

void AudioEngine::processMonitorAudio(void* output, ma_uint32 frameCount, ma_uint32 playbackChannels)
{
    float* out = static_cast<float*>(output);
    const ma_uint32 totalSamples = frameCount * playbackChannels;
    std::memset(out, 0, totalSamples * sizeof(float));

    float micMul = 1.0f, clipMul = 1.0f;
    computeBalanceMultipliers(micSoundboardBalance.load(std::memory_order_relaxed), micMul, clipMul);

    for (int slotId = 0; slotId < MAX_CLIPS; ++slotId) {
        ClipSlot& slot = clips[slotId];
        auto st = slot.state.load(std::memory_order_relaxed);
        if (st != ClipState::Playing && st != ClipState::Draining)
            continue;

        const float clipGain = slot.gain.load(std::memory_order_relaxed) * clipMul;

        void* pRead = nullptr;
        ma_uint32 availFrames = frameCount;

        if (ma_pcm_rb_acquire_read(&slot.ringBufferMon, &availFrames, &pRead) == MA_SUCCESS && availFrames > 0 &&
            pRead) {
            float* clip = static_cast<float*>(pRead); // stereo

            if (playbackChannels == 2) {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    const ma_uint32 o = f * 2;
                    out[o] += clip[f * 2] * clipGain;
                    out[o + 1] += clip[f * 2 + 1] * clipGain;
                }
            } else {
                for (ma_uint32 f = 0; f < availFrames; ++f) {
                    const float L = clip[f * 2] * clipGain;
                    const float R = clip[f * 2 + 1] * clipGain;
                    const float mono = (L + R) * 0.5f;

                    const ma_uint32 o = f * playbackChannels;
                    for (ma_uint32 ch = 0; ch < playbackChannels; ++ch)
                        out[o + ch] += mono;
                }
            }

            ma_pcm_rb_commit_read(&slot.ringBufferMon, availFrames);
        }
    }

    const float mg = masterGain.load(std::memory_order_relaxed);

    float prePeak = 0.0f;
    for (ma_uint32 i = 0; i < totalSamples; ++i) {
        const float v = out[i] * mg;
        out[i] = v;
        prePeak = std::max(prePeak, std::abs(v));
    }

    constexpr float targetPeak = 0.95f;
    if (prePeak > targetPeak && prePeak > 0.000001f) {
        const float limiterGain = targetPeak / prePeak;
        for (ma_uint32 i = 0; i < totalSamples; ++i)
            out[i] *= limiterGain;
    }

    float peak = 0.0f;
    for (ma_uint32 i = 0; i < totalSamples; ++i)
        peak = std::max(peak, std::abs(out[i]));
    float cur = monitorPeakLevel.load(std::memory_order_relaxed);
    if (peak > cur)
        monitorPeakLevel.store(peak, std::memory_order_relaxed);
}

// ------------------------------------------------------------
// Recording-input callback
// ------------------------------------------------------------
void AudioEngine::recordingInputCallback(ma_device* pDevice, void*, const void* pInput, ma_uint32 frameCount)
{
    auto* engine = static_cast<AudioEngine*>(pDevice->pUserData);
    if (!engine || !engine->recordingInputRunning.load(std::memory_order_acquire))
        return;
    if (!pInput)
        return;
    engine->processRecordingInput(pInput, frameCount, pDevice->capture.channels);
}

void AudioEngine::processRecordingInput(const void* input, ma_uint32 frameCount, ma_uint32 captureChannels)
{
    if (!recordingInputRbData)
        return;

    const float* in = static_cast<const float*>(input);

    void* pWrite = nullptr;
    ma_uint32 toWrite = frameCount;

    // Apply mic gain to recording input for consistent levels
    const float micG = micGain.load(std::memory_order_relaxed);

    if (ma_pcm_rb_acquire_write(&recordingInputRb, &toWrite, &pWrite) == MA_SUCCESS && toWrite > 0 && pWrite) {
        float* dst = static_cast<float*>(pWrite);
        for (ma_uint32 f = 0; f < toWrite; ++f) {
            float mono = 0.0f;
            for (ma_uint32 ch = 0; ch < captureChannels; ++ch)
                mono += in[f * captureChannels + ch];
            mono = (mono / (float)captureChannels) * micG;  // Apply mic gain
            dst[f] = mono;
        }
        ma_pcm_rb_commit_write(&recordingInputRb, toWrite);
    }
}

// ------------------------------------------------------------
// Clips - Decoder thread
// ------------------------------------------------------------
void AudioEngine::decoderThreadFunc(AudioEngine* engine, ClipSlot* slot, int slotId, uint64_t token)
{
    const std::string filepath = slot->filePath;
    if (filepath.empty()) {
        slot->state.store(ClipState::Stopped, std::memory_order_release);
        return;
    }

    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, engine->m_sampleRate);
    ma_decoder dec;
    bool usingMiniaudio = false;
    FFmpegDecoder ffmpegDec;

#ifdef _WIN32
    std::wstring wpath = utf8ToWide(filepath);
    if (ma_decoder_init_file_w(wpath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        usingMiniaudio = true;
    }
#else
    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
        usingMiniaudio = true;
    }
#endif

    // If miniaudio failed, try FFmpeg as fallback (for Opus, etc.)
    if (!usingMiniaudio) {
        std::cout << "[AudioEngine] miniaudio failed for: " << filepath << ", trying FFmpeg...\n";
        if (ffmpegDec.open(filepath, engine->m_sampleRate, 2)) {
            std::cout << "[AudioEngine] FFmpeg decoder opened successfully\n";
        } else {
            std::cerr << "[AudioEngine] Both miniaudio and FFmpeg failed for: " << filepath << "\n";
            slot->state.store(ClipState::Stopped, std::memory_order_release);
            std::lock_guard<std::mutex> lock(engine->callbackMutex);
            if (engine->clipErrorCallback)
                engine->clipErrorCallback(slotId);
            return;
        }
    }

    // Set sample rate and channels based on which decoder is being used
    if (usingMiniaudio) {
        slot->sampleRate.store((int)dec.outputSampleRate, std::memory_order_relaxed);
        slot->channels.store((int)dec.outputChannels, std::memory_order_relaxed);
    } else {
        slot->sampleRate.store((int)ffmpegDec.getSampleRate(), std::memory_order_relaxed);
        slot->channels.store((int)ffmpegDec.getChannels(), std::memory_order_relaxed);
    }

    const uint32_t decoderSampleRate = usingMiniaudio ? dec.outputSampleRate : ffmpegDec.getSampleRate();

    double startMs = slot->trimStartMs.load(std::memory_order_relaxed);
    if (startMs > 0.0) {
        ma_uint64 startFrame = (ma_uint64)((startMs / 1000.0) * decoderSampleRate);
        if (usingMiniaudio) {
            ma_decoder_seek_to_pcm_frame(&dec, startFrame);
        } else {
            ffmpegDec.seekToPcmFrame(startFrame);
        }
    }

    constexpr ma_uint32 kFrames = 1024;
    float buf[kFrames * 2];

    bool naturalEnd = false;

    while (true) {
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
            break;

        while (slot->state.load(std::memory_order_acquire) == ClipState::Paused) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                break;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
            break;

        double seekMs = slot->seekPosMs.exchange(-1.0, std::memory_order_relaxed);
        if (seekMs >= 0.0) {
            ma_uint64 target = (ma_uint64)((seekMs / 1000.0) * decoderSampleRate);
            if (usingMiniaudio) {
                ma_decoder_seek_to_pcm_frame(&dec, target);
            } else {
                ffmpegDec.seekToPcmFrame(target);
            }
        }

        ma_uint64 framesRead = 0;
        bool readError = false;

        if (usingMiniaudio) {
            ma_result rr = ma_decoder_read_pcm_frames(&dec, buf, kFrames, &framesRead);
            if (rr != MA_SUCCESS && rr != MA_AT_END)
                readError = true;
        } else {
            framesRead = ffmpegDec.readPcmFrames(buf, kFrames);
        }

        if (readError)
            break;

        if (framesRead == 0) {
            if (slot->loop.load(std::memory_order_relaxed)) {
                while (slot->queuedMainFrames.load(std::memory_order_relaxed) > 0) {
                    if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                        break;
                    std::this_thread::sleep_for(std::chrono::milliseconds(2));
                }
                if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                    break;

                double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                ma_uint64 sFrame = (ma_uint64)((sMs / 1000.0) * decoderSampleRate);
                if (usingMiniaudio) {
                    ma_decoder_seek_to_pcm_frame(&dec, sFrame);
                } else {
                    ffmpegDec.seekToPcmFrame(sFrame);
                }

                slot->playbackFrameCount.store(0, std::memory_order_relaxed);

                {
                    std::lock_guard<std::mutex> lock(engine->callbackMutex);
                    if (engine->clipLoopedCallback)
                        engine->clipLoopedCallback(slotId);
                }
                continue;
            }
            naturalEnd = true;
            break;
        }

        double endMs = slot->trimEndMs.load(std::memory_order_relaxed);
        if (endMs > 0.0) {
            ma_uint64 curFrame = 0;
            if (usingMiniaudio) {
                ma_decoder_get_cursor_in_pcm_frames(&dec, &curFrame);
            } else {
                curFrame = ffmpegDec.getCursorInPcmFrames();
            }
            ma_uint64 endFrame = (ma_uint64)((endMs / 1000.0) * decoderSampleRate);
            if (curFrame >= endFrame) {
                if (slot->loop.load(std::memory_order_relaxed)) {
                    while (slot->queuedMainFrames.load(std::memory_order_relaxed) > 0) {
                        if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                            break;
                        std::this_thread::sleep_for(std::chrono::milliseconds(2));
                    }
                    if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                        break;

                    double sMs = slot->trimStartMs.load(std::memory_order_relaxed);
                    ma_uint64 sFrame = (ma_uint64)((sMs / 1000.0) * decoderSampleRate);
                    if (usingMiniaudio) {
                        ma_decoder_seek_to_pcm_frame(&dec, sFrame);
                    } else {
                        ffmpegDec.seekToPcmFrame(sFrame);
                    }

                    slot->playbackFrameCount.store(0, std::memory_order_relaxed);

                    {
                        std::lock_guard<std::mutex> lock(engine->callbackMutex);
                        if (engine->clipLoopedCallback)
                            engine->clipLoopedCallback(slotId);
                    }
                    continue;
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
            if (st == ClipState::Stopping)
                break;
            if (st == ClipState::Paused) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                continue;
            }

            void* wMain = nullptr;
            ma_uint32 toWrite = remaining;

            if (ma_pcm_rb_acquire_write(&slot->ringBufferMain, &toWrite, &wMain) == MA_SUCCESS && toWrite > 0 &&
                wMain) {
                std::memcpy(wMain, cursor, toWrite * 2 * sizeof(float));
                ma_pcm_rb_commit_write(&slot->ringBufferMain, toWrite);
                slot->queuedMainFrames.fetch_add((long long)toWrite, std::memory_order_relaxed);

                // best-effort monitor buffer
                void* wMon = nullptr;
                ma_uint32 toWriteMon = toWrite;
                if (ma_pcm_rb_acquire_write(&slot->ringBufferMon, &toWriteMon, &wMon) == MA_SUCCESS && toWriteMon > 0 &&
                    wMon) {
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

    // Clean up decoder
    if (usingMiniaudio) {
        ma_decoder_uninit(&dec);
    } else {
        ffmpegDec.close();
    }

    if (naturalEnd) {
        slot->state.store(ClipState::Draining, std::memory_order_release);

        while (slot->queuedMainFrames.load(std::memory_order_relaxed) > 0) {
            if (slot->state.load(std::memory_order_acquire) == ClipState::Stopping)
                break;
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }

        slot->state.store(ClipState::Stopped, std::memory_order_release);

        const bool stillCurrent = (slot->playToken.load(std::memory_order_acquire) == token);
        const bool wasStopped = (slot->state.load(std::memory_order_acquire) == ClipState::Stopping);

        if (stillCurrent && !wasStopped) {
            std::lock_guard<std::mutex> lock(engine->callbackMutex);
            if (engine->clipFinishedCallback)
                engine->clipFinishedCallback(slotId);
        }
        return;
    }

    slot->state.store(ClipState::Stopped, std::memory_order_release);
}

// ------------------------------------------------------------
// Clips API
// ------------------------------------------------------------
std::pair<double, double> AudioEngine::loadClip(int slotId, const std::string& filepath)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return {0.0, 0.0};
    if (filepath.empty())
        return {0.0, 0.0};

    ClipSlot& slot = clips[slotId];
    if (slot.state.load(std::memory_order_relaxed) != ClipState::Stopped)
        return {0.0, 0.0};

    const size_t bytes = (size_t)getRingBufferSize() * 2 * sizeof(float);

    if (!slot.ringBufferMainData) {
        slot.ringBufferMainData = std::malloc(bytes);
        if (!slot.ringBufferMainData)
            return {0.0, 0.0};
        ma_pcm_rb_init(ma_format_f32, 2, getRingBufferSize(), slot.ringBufferMainData, nullptr, &slot.ringBufferMain);
    }
    if (!slot.ringBufferMonData) {
        slot.ringBufferMonData = std::malloc(bytes);
        if (!slot.ringBufferMonData)
            return {0.0, 0.0};
        ma_pcm_rb_init(ma_format_f32, 2, getRingBufferSize(), slot.ringBufferMonData, nullptr, &slot.ringBufferMon);
    }

    ma_pcm_rb_reset(&slot.ringBufferMain);
    ma_pcm_rb_reset(&slot.ringBufferMon);

    slot.filePath = filepath;
    slot.gain.store(1.0f, std::memory_order_relaxed);
    slot.loop.store(false, std::memory_order_relaxed);
    slot.queuedMainFrames.store(0, std::memory_order_relaxed);
    slot.seekPosMs.store(-1.0, std::memory_order_relaxed);
    slot.playbackFrameCount.store(0, std::memory_order_relaxed);

    // duration - try miniaudio first, then FFmpeg as fallback
    double endSec = -1.0;
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, m_sampleRate);
    ma_decoder dec;
    bool gotDuration = false;

#ifdef _WIN32
    std::wstring wpath = utf8ToWide(filepath);
    ma_result initResult = ma_decoder_init_file_w(wpath.c_str(), &cfg, &dec);
#else
    ma_result initResult = ma_decoder_init_file(filepath.c_str(), &cfg, &dec);
#endif
    if (initResult == MA_SUCCESS) {
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS && dec.outputSampleRate > 0 &&
            totalFrames > 0) {
            endSec = (double)totalFrames / (double)dec.outputSampleRate;
            slot.totalDurationMs.store(endSec * 1000.0, std::memory_order_relaxed);
            gotDuration = true;
        }
        ma_decoder_uninit(&dec);
    }

    // If miniaudio failed, try FFmpeg (for Opus, etc.)
    if (!gotDuration) {
        FFmpegDecoder ffmpegDec;
        if (ffmpegDec.open(filepath, m_sampleRate, 2)) {
            uint64_t totalFrames = ffmpegDec.getLengthInPcmFrames();
            if (totalFrames > 0) {
                endSec = (double)totalFrames / (double)ffmpegDec.getSampleRate();
                slot.totalDurationMs.store(endSec * 1000.0, std::memory_order_relaxed);
                gotDuration = true;
                std::cout << "[AudioEngine] loadClip: Got duration from FFmpeg: " << endSec << "s\n";
            }
            ffmpegDec.close();
        }
    }

    if (!gotDuration) {
        return {0.0, 0.0};
    }

    return {0.0, endSec};
}

void AudioEngine::unloadClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;

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

void AudioEngine::playClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    ClipSlot& slot = clips[slotId];
    if (slot.filePath.empty())
        return;

    if (slot.state.load(std::memory_order_acquire) == ClipState::Paused) {
        slot.state.store(ClipState::Playing, std::memory_order_release);
        return;
    }

    // ensure some output is running
    if (!isDeviceRunning() && !isMonitorRunning())
        return;

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

    const uint64_t token = slot.playToken.fetch_add(1, std::memory_order_acq_rel) + 1;
    slot.state.store(ClipState::Playing, std::memory_order_release);

    slot.decoderThread = std::thread(&AudioEngine::decoderThreadFunc, this, &slot, slotId, token);
}

void AudioEngine::pauseClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    auto st = clips[slotId].state.load(std::memory_order_acquire);
    if (st == ClipState::Playing || st == ClipState::Draining) {
        clips[slotId].state.store(ClipState::Paused, std::memory_order_release);
    }
}

void AudioEngine::resumeClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    if (clips[slotId].state.load(std::memory_order_acquire) == ClipState::Paused) {
        clips[slotId].state.store(ClipState::Playing, std::memory_order_release);
    }
}

void AudioEngine::stopClip(int slotId)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;

    ClipSlot& slot = clips[slotId];
    slot.state.store(ClipState::Stopping, std::memory_order_release);

    if (slot.decoderThread.joinable()) {
        slot.decoderThread.join();
    }
    slot.state.store(ClipState::Stopped, std::memory_order_release);
}

void AudioEngine::setClipLoop(int slotId, bool loop)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].loop.store(loop, std::memory_order_relaxed);
}

void AudioEngine::setClipGain(int slotId, float gainDB)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].gain.store(dBToLinear(gainDB), std::memory_order_relaxed);
}

float AudioEngine::getClipGain(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return 0.0f;
    float lin = clips[slotId].gain.load(std::memory_order_relaxed);
    return 20.0f * std::log10(std::max(lin, 0.000001f));
}

void AudioEngine::setClipTrim(int slotId, double startMs, double endMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].trimStartMs.store(startMs, std::memory_order_relaxed);
    clips[slotId].trimEndMs.store(endMs, std::memory_order_relaxed);
}

void AudioEngine::seekClip(int slotId, double positionMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].seekPosMs.store(positionMs, std::memory_order_relaxed);

    double startMs = clips[slotId].trimStartMs.load(std::memory_order_relaxed);
    double diffMs = positionMs - startMs;
    if (diffMs < 0)
        diffMs = 0;

    int sr = clips[slotId].sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0)
        sr = (int)m_sampleRate;

    long long frames = (long long)(diffMs * sr / 1000.0);
    clips[slotId].playbackFrameCount.store(frames, std::memory_order_relaxed);
}

void AudioEngine::setClipStartPosition(int slotId, double positionMs)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;

    // Just set the seekPosMs - the decoder thread will pick this up and seek immediately
    // This is meant to be called AFTER loadClip but BEFORE playClip
    clips[slotId].seekPosMs.store(positionMs, std::memory_order_relaxed);

    // Also pre-calculate playbackFrameCount for correct progress display
    double startMs = clips[slotId].trimStartMs.load(std::memory_order_relaxed);
    double diffMs = positionMs - startMs;
    if (diffMs < 0)
        diffMs = 0;

    int sr = clips[slotId].sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0)
        sr = (int)m_sampleRate;

    long long frames = (long long)(diffMs * sr / 1000.0);
    clips[slotId].playbackFrameCount.store(frames, std::memory_order_relaxed);
}

void AudioEngine::setClipMonitorOnly(int slotId, bool monitorOnly)
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return;
    clips[slotId].monitorOnly.store(monitorOnly, std::memory_order_relaxed);
}

bool AudioEngine::isClipPlaying(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return false;
    auto st = clips[slotId].state.load(std::memory_order_relaxed);
    return (st == ClipState::Playing || st == ClipState::Draining || st == ClipState::Paused);
}

bool AudioEngine::isClipPaused(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return false;
    return clips[slotId].state.load(std::memory_order_relaxed) == ClipState::Paused;
}

double AudioEngine::getClipPlaybackPositionMs(int slotId) const
{
    if (slotId < 0 || slotId >= MAX_CLIPS)
        return 0.0;

    const ClipSlot& slot = clips[slotId];
    int sr = slot.sampleRate.load(std::memory_order_relaxed);
    if (sr <= 0)
        sr = (int)m_sampleRate;

    double frames = (double)slot.playbackFrameCount.load(std::memory_order_relaxed);
    double startMs = slot.trimStartMs.load(std::memory_order_relaxed);
    double curMs = (frames / (double)sr) * 1000.0;
    return startMs + curMs;
}

double AudioEngine::getFileDuration(const std::string& filepath)
{
    ma_decoder_config cfg = ma_decoder_config_init(ma_format_f32, 2, m_sampleRate);
    ma_decoder dec;
    double duration = -1.0;

#ifdef _WIN32
    std::wstring wpath = utf8ToWide(filepath);
    if (ma_decoder_init_file_w(wpath.c_str(), &cfg, &dec) == MA_SUCCESS) {
#else
    if (ma_decoder_init_file(filepath.c_str(), &cfg, &dec) == MA_SUCCESS) {
#endif
        ma_uint64 totalFrames = 0;
        if (ma_decoder_get_length_in_pcm_frames(&dec, &totalFrames) == MA_SUCCESS && dec.outputSampleRate > 0) {
            duration = (double)totalFrames / (double)dec.outputSampleRate;
        }
        ma_decoder_uninit(&dec);
    }
    return duration;
}

bool AudioEngine::exportTrimmedAudio(const std::string& sourcePath, const std::string& destPath, double trimStartMs,
                                     double trimEndMs)
{
    // Initialize decoder for source file
    ma_decoder_config decCfg = ma_decoder_config_init(ma_format_f32, 2, m_sampleRate);
    ma_decoder decoder;

#ifdef _WIN32
    std::wstring wsourcePath = utf8ToWide(sourcePath);
    if (ma_decoder_init_file_w(wsourcePath.c_str(), &decCfg, &decoder) != MA_SUCCESS) {
#else
    if (ma_decoder_init_file(sourcePath.c_str(), &decCfg, &decoder) != MA_SUCCESS) {
#endif
        std::cerr << "exportTrimmedAudio: Failed to open source file: " << sourcePath << std::endl;
        return false;
    }

    // Get source file info
    ma_uint64 totalFrames = 0;
    ma_decoder_get_length_in_pcm_frames(&decoder, &totalFrames);
    const ma_uint32 sampleRate = decoder.outputSampleRate;
    const ma_uint32 channels = decoder.outputChannels;

    // Calculate frame ranges from milliseconds
    const ma_uint64 startFrame = static_cast<ma_uint64>((trimStartMs / 1000.0) * sampleRate);
    ma_uint64 endFrame = static_cast<ma_uint64>((trimEndMs / 1000.0) * sampleRate);

    // If endFrame is 0 or past total, use total frames
    if (endFrame == 0 || endFrame > totalFrames) {
        endFrame = totalFrames;
    }

    // Validate range
    if (startFrame >= endFrame) {
        std::cerr << "exportTrimmedAudio: Invalid trim range - start:" << startFrame << " end:" << endFrame
                  << std::endl;
        ma_decoder_uninit(&decoder);
        return false;
    }

    const ma_uint64 framesToWrite = endFrame - startFrame;

    // Seek to start position
    if (ma_decoder_seek_to_pcm_frame(&decoder, startFrame) != MA_SUCCESS) {
        std::cerr << "exportTrimmedAudio: Failed to seek to frame: " << startFrame << std::endl;
        ma_decoder_uninit(&decoder);
        return false;
    }

    // Initialize encoder for destination file
    ma_encoder encoder;
    ma_encoder_config encCfg = ma_encoder_config_init(ma_encoding_format_wav, ma_format_f32, channels, sampleRate);

    if (ma_encoder_init_file(destPath.c_str(), &encCfg, &encoder) != MA_SUCCESS) {
        std::cerr << "exportTrimmedAudio: Failed to create output file: " << destPath << std::endl;
        ma_decoder_uninit(&decoder);
        return false;
    }

    // Read and write in chunks
    constexpr ma_uint32 kChunkFrames = 4096;
    std::vector<float> buffer(static_cast<size_t>(kChunkFrames) * channels);

    ma_uint64 framesWritten = 0;
    while (framesWritten < framesToWrite) {
        const ma_uint64 framesRemaining = framesToWrite - framesWritten;
        const ma_uint32 framesToRead =
            static_cast<ma_uint32>(std::min(static_cast<ma_uint64>(kChunkFrames), framesRemaining));

        ma_uint64 framesRead = 0;
        ma_result res = ma_decoder_read_pcm_frames(&decoder, buffer.data(), framesToRead, &framesRead);

        if (framesRead == 0 || res != MA_SUCCESS) {
            break; // End of file or error
        }

        ma_encoder_write_pcm_frames(&encoder, buffer.data(), framesRead, nullptr);
        framesWritten += framesRead;
    }

    // Cleanup
    ma_encoder_uninit(&encoder);
    ma_decoder_uninit(&decoder);

    std::cout << "exportTrimmedAudio: Exported " << framesWritten << " frames to " << destPath << std::endl;
    return true;
}

// ------------------------------------------------------------
// Recording
// ------------------------------------------------------------
// Recording sources:
// - Recording Input Device: Always recorded when enabled and active
// - Clips/Soundboard Playback: Optional, controlled by recordPlayback parameter
// - Main Microphone Input: NOT recorded (recordMic parameter is ignored)
bool AudioEngine::startRecording(const std::string& outputPath, bool recordMic, bool recordPlayback)
{
    if (recording.load(std::memory_order_relaxed))
        return false;
    if (outputPath.empty())
        return false;

    // Store recording source settings
    // NOTE: recordMic is ignored - main mic is never recorded, only recording input device
    recordMicEnabled.store(false, std::memory_order_relaxed);  // Main mic never recorded
    recordPlaybackEnabled.store(recordPlayback, std::memory_order_relaxed);  // Clips optional

    // Ensure main devices running so playback callback executes
    if (!deviceRunning.load(std::memory_order_relaxed)) {
        if (!startAudioDevice())
            return false;
    }

    // Determine channel count from playback device
    recordingChannels = (playbackDevice ? (int)playbackDevice->playback.channels : (int)m_channels);
    if (recordingChannels <= 0)
        recordingChannels = 2;

    recordingOutputPath = outputPath;
    recordedFrames.store(0, std::memory_order_relaxed);
    recordingWriteOk.store(false, std::memory_order_relaxed);

    if (!initRecordingRingBuffer(m_sampleRate, (ma_uint32)recordingChannels))
        return false;
    ma_pcm_rb_reset(&recordingRb);

    // Start optional extra recording input device
    if (recordingInputEnabled.load(std::memory_order_relaxed)) {
        startRecordingInputDevice();
        ma_pcm_rb_reset(&recordingInputRb);
    }

    // Start writer thread
    recordingWriterRunning.store(true, std::memory_order_release);

    recordingWriterThread = std::thread([this]() {
        ma_encoder encoder;
        ma_encoder_config ecfg =
            ma_encoder_config_init(ma_encoding_format_wav, ma_format_f32, (ma_uint32)recordingChannels, m_sampleRate);

        ma_result er = ma_encoder_init_file(recordingOutputPath.c_str(), &ecfg, &encoder);
        if (er != MA_SUCCESS) {
            recordingWriteOk.store(false, std::memory_order_release);

            // drain/discard while running
            while (recordingWriterRunning.load(std::memory_order_acquire)) {
                void* pRead = nullptr;
                ma_uint32 frames = 4096;
                if (ma_pcm_rb_acquire_read(&recordingRb, &frames, &pRead) == MA_SUCCESS && frames > 0 && pRead) {
                    ma_pcm_rb_commit_read(&recordingRb, frames);
                } else {
                    std::this_thread::sleep_for(std::chrono::milliseconds(2));
                }
            }
            return;
        }

        auto drainOnce = [&](ma_uint32 framesWanted) -> bool {
            void* pRead = nullptr;
            ma_uint32 frames = framesWanted;

            if (ma_pcm_rb_acquire_read(&recordingRb, &frames, &pRead) == MA_SUCCESS && frames > 0 && pRead) {
                ma_encoder_write_pcm_frames(&encoder, pRead, frames, nullptr);
                ma_pcm_rb_commit_read(&recordingRb, frames);
                return true;
            }
            return false;
        };

        while (recordingWriterRunning.load(std::memory_order_acquire)) {
            if (!drainOnce(4096))
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }

        while (drainOnce(4096)) { /* final drain */
        }

        ma_encoder_uninit(&encoder);
        recordingWriteOk.store(true, std::memory_order_release);
    });

    // Enable recording for playback callback
    recording.store(true, std::memory_order_release);
    return true;
}

bool AudioEngine::stopRecording()
{
    if (!recording.load(std::memory_order_relaxed))
        return false;

    recording.store(false, std::memory_order_release);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    if (recordingInputRunning.load(std::memory_order_relaxed)) {
        stopRecordingInputDevice();
    }

    recordingWriterRunning.store(false, std::memory_order_release);
    if (recordingWriterThread.joinable())
        recordingWriterThread.join();

    shutdownRecordingRingBuffer();
    return recordingWriteOk.load(std::memory_order_acquire);
}

bool AudioEngine::isRecording() const
{
    return recording.load(std::memory_order_relaxed);
}

float AudioEngine::getRecordingDuration() const
{
    uint64_t frames = recordedFrames.load(std::memory_order_relaxed);
    return (float)frames / (float)m_sampleRate;
}

// ------------------------------------------------------------
// Legacy WAV writer (kept, but not used by the streaming writer)
// ------------------------------------------------------------
bool AudioEngine::writeWavFile(const std::string& path, const std::vector<float>& samples, int sampleRate, int channels)
{
    if (samples.empty() || path.empty())
        return false;

    FILE* file = fopen(path.c_str(), "wb");
    if (!file)
        return false;

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
        s = std::max(-1.0f, std::min(1.0f, s));
        int16_t pcm = (int16_t)(s * 32767.0f);
        fwrite(&pcm, 2, 1, file);
    }

    fclose(file);
    return true;
}
