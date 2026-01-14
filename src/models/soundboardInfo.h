#pragma once

#include <QString>

struct SoundboardInfo
{
    int id = -1;
    QString name;
    QString hotkey;  // Hotkey to activate this soundboard
    QString artwork; // Path to cover image (empty = use default)
    int clipCount = 0;
};
