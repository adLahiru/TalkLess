#pragma once

#include <QString>
#include <QVector>
#include "clip.h"

#define MAX_CLIPS 11


struct Soundboard
{
    int id = -1;
    QString name;
    QString hotkey;
    QVector<Clip[MAX_CLIPS]> clips;
    bool isActive = false;
};
