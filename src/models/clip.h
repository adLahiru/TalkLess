#pragma once

#include <QString>
#include <QStringList>
#include <QtGlobal>

struct Clip
{
    int id = -1;

    QString filePath;
    QString originalFilePath; // Original file path before any effects/normalization
    QString imgPath;
    QString hotkey; // e.g. "Ctrl+1", "F5"
    QStringList tags;

    // Track applied audio processing
    QStringList appliedEffects; // e.g. "Normalized (-16 LUFS)", "Bass Boost", "Treble Boost"

    double trimStartMs = 0.0; // seek start
    double trimEndMs = 0.0;   // stop at end (0 = no end limit)

    // Per-clip audio settings
    int volume = 100;   // 0-100 percentage
    double speed = 1.0; // 0.5 - 2.0 playback speed

    QString title;

    bool isPlaying = false; // UI state
    bool isRepeat = false;  // loop flag
    bool locked = false;    // read-only while playing

    // Reproduction mode (0=Overlay, 1=Play/Pause, 2=Play/Stop, 3=Repeat,   4=Loop)
    int reproductionMode = 2; // Defaults to Play/Stop mode

    // Playback behavior options
    bool stopOtherSounds = false;       // Stop other clips when this plays
    bool muteOtherSounds = false;       // Mute (pause) other clips when this plays
    bool muteMicDuringPlayback = false; // Mute mic while this clip is playing

    double durationSec = 0.0;     // Duration in seconds (or -1.0 if unknown)
    double lastPlayedPosMs = 0.0; // Saved playback position for resuming

    // Teleprompter script text for this clip
    QString teleprompterText;

    // Track which boards this clip is shared with (for "send to board" feature)
    QList<int> sharedBoardIds; // List of board IDs where this clip exists
};
