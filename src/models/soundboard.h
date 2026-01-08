#pragma once

#include <QString>
#include <QVector>
#include "clip.h"


struct Soundboard
{
    int id = -1;
    QString name;
    QString hotkey;
    QVector<Clip> clips;
    bool isActive = false;
};
