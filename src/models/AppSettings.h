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
};
