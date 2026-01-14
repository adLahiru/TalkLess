#pragma once

#include <QString>
#include <QVector>
#include "clip.h"


struct Soundboard
{
    int id = -1;
    QString name;
    QString hotkey;
    QString artwork; // Path to cover image (empty = use default)
    QVector<Clip> clips;
    bool isActive = false;
};
