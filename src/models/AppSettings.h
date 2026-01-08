#pragma once
#include <QString>

struct AppSettings
{
    double masterGainDb = 0.0;
    double micGainDb = 0.0;

    QString selectedPlaybackDeviceId; 
    QString selectedCaptureDeviceId;

    QString theme = "Dark";
    QString hotkeyMode = "ActiveBoardOnly";
};
