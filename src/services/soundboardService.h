#pragma once

#include <QObject>
#include <QHash>
#include <optional>

#include "models/appState.h"
#include "models/soundboard.h"
#include "models/clip.h"
#include "services/storageRepository.h"

class SoundboardService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int activeBoardId READ activeBoardId NOTIFY activeBoardChanged)
    Q_PROPERTY(QString activeBoardName READ activeBoardName NOTIFY activeBoardChanged)

public:
    explicit SoundboardService(QObject* parent = nullptr);

    // ---- Index / Settings ----
    AppSettings settings() const { return m_state.settings; }
    Q_INVOKABLE double masterGainDb() const { return m_state.settings.masterGainDb; }
    Q_INVOKABLE double micGainDb() const { return m_state.settings.micGainDb; }
    Q_INVOKABLE void setMasterGainDb(double db);
    Q_INVOKABLE void setMicGainDb(double db);

    QVector<SoundboardInfo> listBoards() const { return m_state.soundboards; }
    Q_INVOKABLE void reloadIndex();          // re-read index.json

    // ---- Active board ----
    int activeBoardId() const;
    QString activeBoardName() const;

    bool activate(int boardId);
    bool saveActive();

    // ---- Clip operations (board-wise) ----
    bool addClipToBoard(int boardId, const Clip& draft);
    bool updateClipInBoard(int boardId, int clipId, const Clip& updatedClip);

    // ---- Hotkey (active only) ----
    int findActiveClipIdByHotkey(const QString& hotkey) const;

    // ---- Playback state (active only) ----
    bool setClipPlaying(int clipId, bool playing);

signals:
    void boardsChanged();
    void activeBoardChanged();
    void activeClipsChanged();
    void settingsChanged();

private:
    void rebuildHotkeyIndex();
    Clip* findActiveClipById(int clipId);

    static QString normalizeHotkey(const QString& hotkey);

private:
    StorageRepository m_repo;

    AppState m_state;                      // index.json data in memory
    std::optional<Soundboard> m_active;    // active board in memory
    QHash<QString, int> m_hotkeyToClipId;  // hotkey -> clipId (active only)
};
