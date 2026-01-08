#pragma once

#include <QString>
#include <QStringList>
#include <QtGlobal>

struct Clip
{
    int id = -1;

    QString filePath;
    QString imgPath;
    QString hotkey;        // e.g. "Ctrl+1", "F5"
    QStringList tags;


    qint64 trimStartMs = 0;   // seek start
    qint64 trimEndMs   = 0;   // stop at end (0 = no end limit)

    QString title;

    bool isPlaying = false;   // UI state
    bool isRepeat  = false;   // loop flag
    bool locked    = false;   // read-only while playing
};
