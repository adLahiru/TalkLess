#pragma once

#include "models/AppState.h"
#include "models/clip.h"
#include "models/soundboard.h"
#include "services/storageRepository.h"

#include <QHash>
#include <QMutex>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <QVector>

#include <memory>
#include <optional>

// Forward declaration
class AudioEngine;

class SoundboardService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList activeBoardIds READ activeBoardIdsList NOTIFY activeBoardChanged)
    // Legacy single-board support (returns first active or -1)
    Q_PROPERTY(int activeBoardId READ activeBoardId NOTIFY activeBoardChanged)
    Q_PROPERTY(QString activeBoardName READ activeBoardName NOTIFY activeBoardChanged)

public:
    explicit SoundboardService(QObject* parent = nullptr);
    ~SoundboardService();

    // ---- Saving ----
    Q_INVOKABLE void saveAllChanges();

    // ---- Index / Settings ----
    Q_PROPERTY(double masterGainDb READ masterGainDb WRITE setMasterGainDb NOTIFY settingsChanged)
    Q_PROPERTY(double micGainDb READ micGainDb WRITE setMicGainDb NOTIFY settingsChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY settingsChanged)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY settingsChanged)
    Q_PROPERTY(QString slotSize READ slotSize WRITE setSlotSize NOTIFY settingsChanged)
    Q_PROPERTY(double slotSizeScale READ slotSizeScale WRITE setSlotSizeScale NOTIFY settingsChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY settingsChanged)
    Q_PROPERTY(QString hotkeyMode READ hotkeyMode WRITE setHotkeyMode NOTIFY settingsChanged)
    Q_PROPERTY(QString selectedCaptureDeviceId READ selectedCaptureDeviceId NOTIFY settingsChanged)
    Q_PROPERTY(QString selectedPlaybackDeviceId READ selectedPlaybackDeviceId NOTIFY settingsChanged)
    Q_PROPERTY(QString selectedMonitorDeviceId READ selectedMonitorDeviceId NOTIFY settingsChanged)
    Q_PROPERTY(bool micEnabled READ isMicEnabled WRITE setMicEnabled NOTIFY settingsChanged)
    Q_PROPERTY(
        bool micPassthroughEnabled READ isMicPassthroughEnabled WRITE setMicPassthroughEnabled NOTIFY settingsChanged)
    Q_PROPERTY(
        float micSoundboardBalance READ getMicSoundboardBalance WRITE setMicSoundboardBalance NOTIFY settingsChanged)
    Q_PROPERTY(bool canPaste READ canPaste NOTIFY clipboardChanged)

    // Audio buffer settings
    Q_PROPERTY(int bufferSizeFrames READ bufferSizeFrames WRITE setBufferSizeFrames NOTIFY settingsChanged)
    Q_PROPERTY(int bufferPeriods READ bufferPeriods WRITE setBufferPeriods NOTIFY settingsChanged)
    Q_PROPERTY(int sampleRate READ sampleRate WRITE setSampleRate NOTIFY settingsChanged)
    Q_PROPERTY(int audioChannels READ audioChannels WRITE setAudioChannels NOTIFY settingsChanged)

    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingStateChanged)
    Q_PROPERTY(QString lastRecordingPath READ lastRecordingPath NOTIFY recordingStateChanged)
    Q_PROPERTY(float recordingDuration READ recordingDuration NOTIFY recordingStateChanged)
    Q_PROPERTY(float recordingPeakLevel READ getRecordingPeakLevel NOTIFY recordingStateChanged)
    Q_PROPERTY(
        bool recordWithInputDevice READ recordWithInputDevice WRITE setRecordWithInputDevice NOTIFY settingsChanged)
    Q_PROPERTY(bool recordWithClipboard READ recordWithClipboard WRITE setRecordWithClipboard NOTIFY settingsChanged)
    Q_PROPERTY(QString selectedRecordingDeviceId READ selectedRecordingDeviceId NOTIFY settingsChanged)
    Q_PROPERTY(bool isRecordingPreviewPlaying READ isRecordingPreviewPlaying NOTIFY recordingStateChanged)

    // ---- Index / Settings ----
    double masterGainDb() const { return m_state.settings.masterGainDb; }
    double micGainDb() const { return m_state.settings.micGainDb; }

    QString selectedCaptureDeviceId() const { return m_state.settings.selectedCaptureDeviceId; }
    QString selectedPlaybackDeviceId() const { return m_state.settings.selectedPlaybackDeviceId; }
    QString selectedMonitorDeviceId() const { return m_state.settings.selectedMonitorDeviceId; }
    QString selectedRecordingDeviceId() const { return m_selectedRecordingDeviceId; }

    Q_INVOKABLE void setMasterGainDb(double db);
    Q_INVOKABLE void setMicGainDb(double db);

    QString theme() const { return m_state.settings.theme; }
    Q_INVOKABLE void setTheme(const QString& theme);

    QString accentColor() const { return m_state.settings.accentColor; }
    Q_INVOKABLE void setAccentColor(const QString& color);

    QString slotSize() const { return m_state.settings.slotSize; }
    Q_INVOKABLE void setSlotSize(const QString& size);

    double slotSizeScale() const { return m_state.settings.slotSizeScale; }
    Q_INVOKABLE void setSlotSizeScale(double scale);

    QString language() const { return m_state.settings.language; }
    Q_INVOKABLE void setLanguage(const QString& lang);

    QString hotkeyMode() const { return m_state.settings.hotkeyMode; }
    Q_INVOKABLE void setHotkeyMode(const QString& mode);

    // Audio buffer settings getters/setters
    int bufferSizeFrames() const { return m_state.settings.bufferSizeFrames; }
    Q_INVOKABLE void setBufferSizeFrames(int frames);

    int bufferPeriods() const { return m_state.settings.bufferPeriods; }
    Q_INVOKABLE void setBufferPeriods(int periods);

    int sampleRate() const { return m_state.settings.sampleRate; }
    Q_INVOKABLE void setSampleRate(int rate);

    int audioChannels() const { return m_state.settings.channels; }
    Q_INVOKABLE void setAudioChannels(int channels);

    Q_INVOKABLE bool exportSettings(const QString& filePath);
    Q_INVOKABLE bool importSettings(const QString& filePath);
    Q_INVOKABLE void triggerSettingsChanged() { emit settingsChanged(); }
    Q_INVOKABLE void resetSettings();

    Q_INVOKABLE int createBoard(const QString& name);
    Q_INVOKABLE int createBoardWithArtwork(const QString& name, const QString& artworkPath);
    Q_INVOKABLE bool renameBoard(int boardId, const QString& newName);
    Q_INVOKABLE bool deleteBoard(int boardId);

    QVector<SoundboardInfo> listBoards() const { return m_state.soundboards; }
    Q_INVOKABLE QString getBoardName(int boardId) const;
    Q_INVOKABLE QString getBoardHotkey(int boardId) const;
    Q_INVOKABLE QString getBoardArtwork(int boardId) const;
    Q_INVOKABLE bool setBoardHotkey(int boardId, const QString& hotkey);
    Q_INVOKABLE bool setBoardArtwork(int boardId, const QString& artworkPath);
    Q_INVOKABLE void reloadIndex(); // re-read index.json

    // ---- Active boards (multiple can be active) ----
    int activeBoardId() const;                         // Returns first active board ID or -1
    QString activeBoardName() const;                   // Returns first active board name
    QVariantList activeBoardIdsList() const;           // Returns all active board IDs
    Q_INVOKABLE bool isBoardActive(int boardId) const; // Check if a specific board is active
    Q_INVOKABLE bool toggleBoardActive(int boardId);   // Toggle active state of a board

    Q_INVOKABLE bool activate(int boardId);   // Activate a board (adds to active set)
    Q_INVOKABLE bool deactivate(int boardId); // Deactivate a board (removes from active set)
    bool saveActive();                        // Save all active boards

    // ---- Clip operations (board-wise) ----
    Q_INVOKABLE bool addClip(int boardId, const QString& filePath);
    Q_INVOKABLE bool addClips(int boardId, const QStringList& filePaths);
    Q_INVOKABLE bool addClipWithTitle(int boardId, const QString& filePath, const QString& title);
    Q_INVOKABLE bool addClipWithSettings(int boardId, const QString& filePath, const QString& title, double trimStartMs,
                                         double trimEndMs);
    Q_INVOKABLE bool deleteClip(int boardId, int clipId);
    bool addClipToBoard(int boardId, const Clip& draft);
    bool updateClipInBoard(int boardId, int clipId, const Clip& updatedClip);
    Q_INVOKABLE bool updateClipInBoard(int boardId, int clipId, const QString& title, const QString& hotkey,
                                       const QStringList& tags);
    Q_INVOKABLE bool updateClipImage(int boardId, int clipId, const QString& imagePath);
    Q_INVOKABLE bool updateClipAudioSettings(int boardId, int clipId, int volume, double speed);
    Q_INVOKABLE void setClipVolume(int boardId, int clipId, int volume);
    Q_INVOKABLE void setClipRepeat(int boardId, int clipId, bool repeat);
    Q_INVOKABLE void setClipReproductionMode(int boardId, int clipId, int mode);
    Q_INVOKABLE void setClipStopOtherSounds(int boardId, int clipId, bool stop);
    Q_INVOKABLE void setClipMuteOtherSounds(int boardId, int clipId, bool mute);
    Q_INVOKABLE void setClipMuteMicDuringPlayback(int boardId, int clipId, bool mute);
    Q_INVOKABLE void setClipTrim(int boardId, int clipId, double startMs, double endMs);
    Q_INVOKABLE void seekClip(int boardId, int clipId, double positionMs);
    Q_INVOKABLE bool moveClip(int boardId, int fromIndex, int toIndex);
    Q_INVOKABLE void copyClip(int clipId);
    Q_INVOKABLE bool pasteClip(int boardId);
    Q_INVOKABLE bool canPaste() const;
    QVector<Clip> getClipsForBoard(int boardId) const;
    QVector<Clip> getActiveClips() const;
    Q_INVOKABLE QVariantMap getClipData(int boardId, int clipId) const;

    // Cross-soundboard clip operations
    Q_INVOKABLE QVariantList getBoardsWithClipStatus(int clipId) const;
    Q_INVOKABLE bool copyClipToBoard(int sourceClipId, int targetBoardId);
    Q_INVOKABLE bool removeClipByFilePath(int boardId, const QString& filePath);

    // ---- Playback controls ----
    Q_INVOKABLE void clipClicked(int clipId);
    Q_INVOKABLE void setCurrentlySelectedClip(int clipId);
    Q_INVOKABLE void playClip(int clipId);
    Q_INVOKABLE void playClipFromPosition(int clipId, double positionMs);
    Q_INVOKABLE void stopClip(int clipId);
    Q_INVOKABLE void stopAllClips();
    Q_INVOKABLE bool isClipPlaying(int clipId) const;
    Q_INVOKABLE double getClipPlaybackPositionMs(int clipId) const;
    Q_INVOKABLE double getClipPlaybackProgress(int clipId) const; // Returns 0.0 to 1.0
    Q_INVOKABLE double getClipDurationMs(int clipId) const;
    Q_INVOKABLE QVariantList playingClipIDs() const;

    // ---- Audio Device Selection ----
    Q_INVOKABLE QVariantList getInputDevices() const;
    Q_INVOKABLE QVariantList getOutputDevices() const;
    Q_INVOKABLE bool setInputDevice(const QString& deviceId);
    Q_INVOKABLE bool setOutputDevice(const QString& deviceId);
    Q_INVOKABLE bool setMonitorOutputDevice(const QString& deviceId);
    Q_INVOKABLE bool setRecordingInputDevice(const QString& deviceId);
    Q_INVOKABLE void refreshAudioDevices();

    // ---- Audio Level Monitoring ----
    Q_INVOKABLE float getMicPeakLevel() const;
    Q_INVOKABLE float getMasterPeakLevel() const;
    Q_INVOKABLE float getMonitorPeakLevel() const;
    Q_INVOKABLE void resetPeakLevels();

    // ---- Mixer Controls ----
    Q_INVOKABLE void setMicSoundboardBalance(float balance);
    Q_INVOKABLE float getMicSoundboardBalance() const;
    Q_INVOKABLE void setMicPassthroughEnabled(bool enabled);
    Q_INVOKABLE bool isMicPassthroughEnabled() const;
    Q_INVOKABLE void setMicEnabled(bool enabled);
    Q_INVOKABLE bool isMicEnabled() const;
    Q_INVOKABLE double getFileDuration(const QString& filePath) const;

    // ---- Recording ----
    Q_INVOKABLE bool startRecording();
    Q_INVOKABLE bool stopRecording();
    bool isRecording() const;

    QString lastRecordingPath() const { return m_lastRecordingPath; }
    float recordingDuration() const;
    Q_INVOKABLE QString getRecordingOutputPath() const;

    // pending recording lifecycle (prevents duplicate saves)
    Q_INVOKABLE bool hasPendingRecording() const;
    Q_INVOKABLE QString consumePendingRecordingPath(); // returns path once, then clears it
    Q_INVOKABLE void cancelPendingRecording();         // stops + deletes file + clears state

    // ---- Recording options ----
    Q_INVOKABLE float getRecordingPeakLevel() const;
    Q_INVOKABLE QVariantList getWaveformPeaks(const QString& filePath, int numBars = 100) const;
    Q_INVOKABLE QVariantList getClipWaveformPeaks(int clipId, int numBars = 100) const; // Get waveform by clip ID
    bool recordWithInputDevice() const { return m_recordWithInputDevice; }
    void setRecordWithInputDevice(bool enabled);
    bool recordWithClipboard() const { return m_recordWithClipboard; }
    void setRecordWithClipboard(bool enabled);

    // ---- Name validation ----
    Q_INVOKABLE bool boardNameExists(const QString& name) const;
    Q_INVOKABLE bool clipTitleExistsInBoard(int boardId, const QString& title) const;
    Q_INVOKABLE QString generateUniqueClipTitle(int boardId, const QString& baseTitle) const;

    Q_INVOKABLE void logFromQml(const QString& msg) const { qDebug() << "[QML]" << msg; }

    // ---- Application Control ----
    Q_INVOKABLE void restartApplication();

    // ---- Waveform Caching ----
    Q_INVOKABLE void cacheActiveBoardWaveforms();

    // ---- Recording preview (NO soundboard add) ----
    Q_INVOKABLE QVariantList listBoardsForDropdown() const;
    Q_INVOKABLE bool playLastRecordingPreview();
    Q_INVOKABLE bool playLastRecordingPreviewTrimmed(double trimStartMs, double trimEndMs);
    Q_INVOKABLE void stopLastRecordingPreview();
    Q_INVOKABLE bool isRecordingPreviewPlaying() const;
    Q_INVOKABLE double getPreviewPlaybackPositionMs() const;

    // ---- Hotkey (active only) ----
    int findActiveClipIdByHotkey(const QString& hotkey) const;

    // ---- Playback state (active only) ----
    bool setClipPlaying(int clipId, bool playing);

    // ---- Hotkey Action Handler ----
    Q_INVOKABLE void handleHotkeyAction(const QString& actionId);

signals:
    void boardsChanged();
    void activeBoardChanged();
    void activeClipsChanged();
    void settingsChanged();
    void clipPlaybackStarted(int clipId);
    void clipPlaybackStopped(int clipId);
    void clipPlaybackPaused(int clipId);
    void clipLooped(int clipId); // Emitted when a looping clip restarts from the beginning
    void clipUpdated(int boardId, int clipId);

    void playSelectedRequested();
    void clipSelectionRequested(int clipId);
    void clipboardChanged();
    void recordingStateChanged();
    void audioDevicesChanged();

    // Error notification for UI
    void errorOccurred(const QString& message);

private:
    void rebuildHotkeyIndex();
    Clip* findActiveClipById(int clipId);
    std::optional<Clip> findClipByIdAnyBoard(int clipId, int* outBoardId = nullptr) const;
    int getOrAssignSlot(int clipId);
    void reproductionPlayingClip(const QVariantList& playingClipIds, int mode);
    static QString normalizeHotkey(const QString& hotkey);
    void finalizeClipPlayback(int clipId);
    void syncSharedBoardIds(const QString& filePath, const QList<int>& sharedBoardIds);
    void removeFromSharedBoardIds(const QString& filePath, int boardId);
    QString extractAudioArtwork(const QString& audioFilePath);

private:
    // Reserve last engine slot for recording preview so it never collides with normal clip slots.
    static constexpr int kEngineSlotsTotal = 8; // AudioEngine::MAX_CLIPS
    static constexpr int kPreviewSlot = 7;      // Last slot reserved for preview (must be < MAX_CLIPS)
    static constexpr int kClipSlotsUsable = 7;  // 0..6 used by normal clips, 7 reserved for preview

    StorageRepository m_repo;

    AppState m_state;
    QHash<int, Soundboard> m_activeBoards;
    QHash<QString, int> m_hotkeyToClipId;
    QHash<int, int> m_slotToClipId;

    std::unique_ptr<AudioEngine> m_audioEngine;
    QHash<int, int> m_clipIdToSlot;
    int m_nextSlot = 0;
    QSet<int> m_clipsThatMutedMic;
    QHash<int, QList<int>> m_pausedByClip; // Maps clipId -> list of clip IDs that were paused when this clip started

    std::optional<Clip> m_clipboardClip;
    QString m_lastRecordingPath;

    // Recording state
    bool m_recordingPreviewPlaying = false;
    bool m_hasUnsavedRecording = false;
    QTimer* m_recordingTickTimer = nullptr;
    bool m_recordWithInputDevice = true;
    bool m_recordWithClipboard = false;
    QString m_selectedRecordingDeviceId;               // Track the selected recording input device
    bool m_micPassthroughDisabledForRecording = false; // Track if we disabled passthrough for recording

    // Dirty flags to track unsaved changes
    bool m_indexDirty = false;
    QSet<int> m_dirtyBoards;

    // Waveform cache (clipId -> peaks)
    mutable QMap<int, QVariantList> m_waveformCache;
    mutable QMutex m_waveformCacheMutex;
};
