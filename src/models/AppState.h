#pragma once
#include <QVector>
#include "appSettings.h"
#include "soundboardInfo.h"

struct AppState
{
    int version = 1;
    AppSettings settings;
    QVector<SoundboardInfo> soundboards;
    int activeBoardId = -1;
};
