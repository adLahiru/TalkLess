#pragma once

#include <QString>
#include <optional>

#include "models/appState.h"
#include "models/soundboard.h"   // your Soundboard (contains QVector<Clip>)
#include "models/clip.h"         // your Clip

class StorageRepository
{
public:
    StorageRepository();

    // ---- index.json (settings + soundboard list + active board) ----
    AppState loadIndex() const;
    bool saveIndex(const AppState& state) const;

    // Convenience
    QVector<SoundboardInfo> listBoards() const;

    // ---- board_<id>.json ----
    std::optional<Soundboard> loadBoard(int boardId) const;
    bool saveBoard(const Soundboard& board);     // updates index.json name + clipCount too

    // ---- helpers ----
    int createBoard(const QString& name);        // creates board file and updates index
    bool deleteBoard(int boardId);               // deletes board file and updates index

private:
    QString baseDir() const;        // AppDataLocation/TalkLess/soundboards
    QString indexPath() const;      // .../index.json
    QString boardsDir() const;      // .../boards
    QString boardPath(int boardId) const; // .../boards/board_<id>.json

    bool ensureDirs() const;

    int nextBoardId(const QVector<SoundboardInfo>& items) const;
};
