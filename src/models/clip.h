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

    // Per-clip audio settings
    int volume = 100;         // 0-100 percentage
    double speed = 1.0;       // 0.5 - 2.0 playback speed

    QString title;

    bool isPlaying = false;   // UI state
    bool isRepeat  = false;   // loop flag
    bool locked    = false;   // read-only while playing
    
    // Reproduction mode (0=Overlay, 1=Play/Pause, 2=Play/Stop, 3=Loop/Repeat)
    int reproductionMode = 1;  // Defaults to Play/Pause mode
    
    // Playback behavior options
    bool stopOtherSounds = false;       // Stop other clips when this plays
    bool muteOtherSounds = false;       // Mute (pause) other clips when this plays
    bool muteMicDuringPlayback = false; // Mute mic while this clip is playing
};
