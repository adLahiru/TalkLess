#pragma once
#include <QString>

struct AppSettings
{
    double masterGainDb = 0.0;
    double micGainDb = 0.0;

    QString selectedPlaybackDeviceId; 
    QString selectedCaptureDeviceId;
    QString selectedMonitorDeviceId;

    QString theme = "Dark"; // "Dark" or "Light"
    QString accentColor = "#3B82F6"; // Default blue
    QString slotSize = "Standard"; // "Compact", "Standard", "Comfortable" (legacy)
    double slotSizeScale = 1.0; // Continuous scale factor: 0.5 (small) to 1.5 (large)
    QString language = "English";
    QString hotkeyMode = "ActiveBoardOnly";

    bool micEnabled = true;
    bool micPassthroughEnabled = true;
    float micSoundboardBalance = 0.5f;

    // Noise cancellation settings (WebRTC APM)
    // Level: 0=Off, 1=Low, 2=Moderate, 3=High, 4=VeryHigh
    int noiseSuppressionLevel = 2; // Default to Moderate

    // Audio buffer settings
    int bufferSizeFrames = 1024;    // Period size in frames (512, 1024, 2048, 4096)
    int bufferPeriods = 3;          // Number of periods (2, 3, 4)
    int sampleRate = 48000;         // Sample rate (44100, 48000, 96000)
    int channels = 2;               // Channels (1=Mono, 2=Stereo)
};
