#pragma once
#include "AppSettings.h"
#include "soundboardInfo.h"

#include <QVector>

struct AppState
{
    int version = 1;
    AppSettings settings;
    QVector<SoundboardInfo> soundboards;
    int activeBoardId = -1;
};
