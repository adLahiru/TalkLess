#pragma once

#include <QString>

struct SoundboardInfo
{
    int id = -1;
    QString name;
    QString hotkey;  // Hotkey to activate this soundboard
    int clipCount = 0;
};
