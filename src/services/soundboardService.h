#pragma once

#include "models/AppState.h"
#include "models/clip.h"
#include "models/soundboard.h"
#include "services/storageRepository.h"

#include <QHash>
#include <QObject>

#include <memory>
#include <optional>

// Forward declaration
class AudioEngine;

class SoundboardService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int activeBoardId READ activeBoardId NOTIFY activeBoardChanged)
    Q_PROPERTY(QString activeBoardName READ activeBoardName NOTIFY activeBoardChanged)

public:
    explicit SoundboardService(QObject* parent = nullptr);
    ~SoundboardService();

    // ---- Index / Settings ----
    AppSettings settings() const { return m_state.settings; }
    Q_INVOKABLE double masterGainDb() const { return m_state.settings.masterGainDb; }
    Q_INVOKABLE double micGainDb() const { return m_state.settings.micGainDb; }
    Q_INVOKABLE void setMasterGainDb(double db);
    Q_INVOKABLE void setMicGainDb(double db);
    Q_INVOKABLE int createBoard(const QString& name);
    Q_INVOKABLE bool renameBoard(int boardId, const QString& newName);
    Q_INVOKABLE bool deleteBoard(int boardId);

    QVector<SoundboardInfo> listBoards() const { return m_state.soundboards; }
    Q_INVOKABLE QString getBoardName(int boardId) const;
    Q_INVOKABLE void reloadIndex(); // re-read index.json

    // ---- Active board ----
    int activeBoardId() const;
    QString activeBoardName() const;

    bool activate(int boardId);
    bool saveActive();

    // ---- Clip operations (board-wise) ----
    Q_INVOKABLE bool addClip(int boardId, const QString& filePath);
    Q_INVOKABLE bool addClipWithTitle(int boardId, const QString& filePath, const QString& title);
    Q_INVOKABLE bool deleteClip(int boardId, int clipId);
    bool addClipToBoard(int boardId, const Clip& draft);
    bool updateClipInBoard(int boardId, int clipId, const Clip& updatedClip);
    QVector<Clip> getClipsForBoard(int boardId) const; // Get all clips for a board
    QVector<Clip> getActiveClips() const;              // Get clips from active board

    // ---- Audio Playback ----
    Q_INVOKABLE void playClip(int clipId);
    Q_INVOKABLE void stopClip(int clipId);
    Q_INVOKABLE void stopAllClips();
    Q_INVOKABLE bool isClipPlaying(int clipId) const;

    // ---- Audio Device Selection ----
    Q_INVOKABLE QVariantList getInputDevices() const;
    Q_INVOKABLE QVariantList getOutputDevices() const;
    Q_INVOKABLE bool setInputDevice(const QString& deviceId);
    Q_INVOKABLE bool setOutputDevice(const QString& deviceId);
    Q_INVOKABLE bool setMonitorOutputDevice(const QString& deviceId);

    // ---- Audio Level Monitoring ----
    Q_INVOKABLE float getMicPeakLevel() const;
    Q_INVOKABLE float getMasterPeakLevel() const;
    Q_INVOKABLE float getMonitorPeakLevel() const;
    Q_INVOKABLE void resetPeakLevels();

    // ---- Mixer Controls ----
    Q_INVOKABLE void setMicSoundboardBalance(float balance);  // 0.0 = full mic, 1.0 = full soundboard
    Q_INVOKABLE float getMicSoundboardBalance() const;
    Q_INVOKABLE void setMicPassthroughEnabled(bool enabled);  // Enable/disable mic in output
    Q_INVOKABLE bool isMicPassthroughEnabled() const;
    Q_INVOKABLE void setMicEnabled(bool enabled);             // Enable/disable capture
    Q_INVOKABLE bool isMicEnabled() const;

    // ---- Hotkey (active only) ----
    int findActiveClipIdByHotkey(const QString& hotkey) const;

    // ---- Playback state (active only) ----
    bool setClipPlaying(int clipId, bool playing);

signals:
    void boardsChanged();
    void activeBoardChanged();
    void activeClipsChanged();
    void settingsChanged();
    void clipPlaybackStarted(int clipId);
    void clipPlaybackStopped(int clipId);

private:
    void rebuildHotkeyIndex();
    Clip* findActiveClipById(int clipId);
    int getOrAssignSlot(int clipId); // Get audio engine slot for clip

    static QString normalizeHotkey(const QString& hotkey);

private:
    StorageRepository m_repo;

    AppState m_state;                     // index.json data in memory
    std::optional<Soundboard> m_active;   // active board in memory
    QHash<QString, int> m_hotkeyToClipId; // hotkey -> clipId (active only)

    // Audio playback
    std::unique_ptr<AudioEngine> m_audioEngine;
    QHash<int, int> m_clipIdToSlot; // clipId -> audio engine slot
    int m_nextSlot = 0;             // next available slot
};
