#pragma once
#include "AppSettings.h"
#include "soundboardInfo.h"

#include <QSet>
#include <QVector>

struct AppState
{
    int version = 1;
    AppSettings settings;
    QVector<SoundboardInfo> soundboards;
    QSet<int> activeBoardIds;  // Multiple boards can be active simultaneously
};
