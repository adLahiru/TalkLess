#include "soundboardService.h"

#include "audioEngine.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

SoundboardService::SoundboardService(QObject* parent) : QObject(parent), m_audioEngine(std::make_unique<AudioEngine>())
{
    // 1) Load index (might not exist) - BEFORE starting audio to apply saved devices
    m_state = m_repo.loadIndex();

    // 2) First launch: no boards -> create one
    if (m_state.soundboards.isEmpty()) {
        int id = m_repo.createBoard("Default"); // creates board_1.json and updates index
        m_state = m_repo.loadIndex();
        m_state.activeBoardIds.insert(id);
        m_indexDirty = true; // Mark as dirty instead of immediate save
    }

    // 3) Activate all saved active boards
    if (m_state.activeBoardIds.isEmpty() && !m_state.soundboards.isEmpty()) {
        // No active boards saved, activate the first one
        activate(m_state.soundboards.first().id);
    } else {
        // Activate all saved active boards
        for (int boardId : m_state.activeBoardIds) {
            activate(boardId);
        }
    }

    // 4) Pre-select saved audio devices BEFORE starting audio engine
    //    This ensures we initialize with the correct devices from the start
    if (m_audioEngine) {
        // Pre-select devices (just sets internal state without initializing)
        if (!m_state.settings.selectedCaptureDeviceId.isEmpty()) {
            qDebug() << "Pre-selecting saved capture device:" << m_state.settings.selectedCaptureDeviceId;
            m_audioEngine->preselectCaptureDevice(m_state.settings.selectedCaptureDeviceId.toStdString());
        }
        if (!m_state.settings.selectedPlaybackDeviceId.isEmpty()) {
            qDebug() << "Pre-selecting saved playback device:" << m_state.settings.selectedPlaybackDeviceId;
            m_audioEngine->preselectPlaybackDevice(m_state.settings.selectedPlaybackDeviceId.toStdString());
        }
        if (!m_state.settings.selectedMonitorDeviceId.isEmpty()) {
            qDebug() << "Pre-selecting saved monitor device:" << m_state.settings.selectedMonitorDeviceId;
            m_audioEngine->preselectMonitorPlaybackDevice(m_state.settings.selectedMonitorDeviceId.toStdString());
        }

        // Apply other audio settings
        m_audioEngine->setMasterGainDB(static_cast<float>(m_state.settings.masterGainDb));
        m_audioEngine->setMicGainDB(static_cast<float>(m_state.settings.micGainDb));
        m_audioEngine->setMicEnabled(m_state.settings.micEnabled);
        m_audioEngine->setMicPassthroughEnabled(m_state.settings.micPassthroughEnabled);
        m_audioEngine->setMicSoundboardBalance(m_state.settings.micSoundboardBalance);

        m_recordingTickTimer = new QTimer(this);
        m_recordingTickTimer->setInterval(100); // 10 updates/sec (smooth timer)
        connect(m_recordingTickTimer, &QTimer::timeout, this, [this]() {
            if (isRecording()) {
                emit recordingStateChanged(); // QML property recordingDuration will update
            } else {
                m_recordingTickTimer->stop();
            }
        });

        qDebug() << "Applied saved audio settings - Master:" << m_state.settings.masterGainDb
                 << "dB, Mic:" << m_state.settings.micGainDb << "dB";
    }

    // 5) Apply audio configuration (sample rate, buffer size, periods, channels)
    //    These settings require app restart to take effect
    if (m_audioEngine) {
        m_audioEngine->setAudioConfig(static_cast<ma_uint32>(m_state.settings.sampleRate),
                                      static_cast<ma_uint32>(m_state.settings.bufferSizeFrames),
                                      static_cast<ma_uint32>(m_state.settings.bufferPeriods),
                                      static_cast<ma_uint32>(m_state.settings.channels));
        qDebug() << "Applied audio config - SampleRate:" << m_state.settings.sampleRate
                 << "Hz, Buffer:" << m_state.settings.bufferSizeFrames
                 << "frames, Periods:" << m_state.settings.bufferPeriods << ", Channels:" << m_state.settings.channels;
    }

    // 6) Now start audio device with correct devices and config already configured
    if (!m_audioEngine->startAudioDevice()) {
        qWarning() << "Failed to start audio device";
    }

    // 7) Start monitor device if a monitor output was configured
    if (!m_state.settings.selectedMonitorDeviceId.isEmpty()) {
        if (!m_audioEngine->startMonitorDevice()) {
            qWarning() << "Failed to start monitor device";
        }
    }

    // 7) Setup AudioEngine callbacks
    if (m_audioEngine) {
        m_audioEngine->setClipFinishedCallback([this](int slotId) {
            const int finishedClipId = m_slotToClipId.value(slotId, -1);
            if (finishedClipId != -1) {
                QMetaObject::invokeMethod(
                    this, [this, finishedClipId]() { finalizeClipPlayback(finishedClipId); }, Qt::QueuedConnection);
            }
        });

        m_audioEngine->setClipLoopedCallback([this](int slotId) {
            // Find which clipId was in this slot
            int loopedClipId = -1;
            for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end(); ++it) {
                if (it.value() == slotId) {
                    loopedClipId = it.key();
                    break;
                }
            }

            if (loopedClipId != -1) {
                // Emit signal on the main thread
                QMetaObject::invokeMethod(
                    this, [this, loopedClipId]() { emit clipLooped(loopedClipId); }, Qt::QueuedConnection);
            }
        });
    }

    // 8) Notify UI
    emit boardsChanged();
    emit activeBoardChanged();
    emit activeClipsChanged();
}

SoundboardService::~SoundboardService()
{
    // Stop all clips before shutting down
    if (m_audioEngine) {
        for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end(); ++it) {
            m_audioEngine->stopClip(it.value());
        }
        m_audioEngine->stopAudioDevice();
    }
}

void SoundboardService::saveAllChanges()
{
    qDebug() << "Saving all changes on application close...";

    // Save index if dirty
    if (m_indexDirty) {
        qDebug() << "Saving index...";
        m_repo.saveIndex(m_state);
        m_indexDirty = false;
    }

    // Save all dirty boards
    if (!m_dirtyBoards.isEmpty()) {
        qDebug() << "Saving" << m_dirtyBoards.size() << "dirty boards...";
        for (int boardId : m_dirtyBoards) {
            if (m_activeBoards.contains(boardId)) {
                // Save active board
                m_repo.saveBoard(m_activeBoards[boardId]);
            } else {
                // Load and save inactive board
                auto loaded = m_repo.loadBoard(boardId);
                if (loaded) {
                    m_repo.saveBoard(*loaded);
                }
            }
        }
        m_dirtyBoards.clear();
    }

    qDebug() << "All changes saved successfully.";
}

void SoundboardService::reloadIndex()
{
    m_state = m_repo.loadIndex();
    emit boardsChanged();
    emit settingsChanged();
}

int SoundboardService::activeBoardId() const
{
    // Returns first active board ID for backward compatibility
    if (m_activeBoards.isEmpty())
        return -1;
    return m_activeBoards.begin().key();
}

QString SoundboardService::activeBoardName() const
{
    // Returns first active board name for backward compatibility
    if (m_activeBoards.isEmpty())
        return QString();
    return m_activeBoards.begin().value().name;
}

QVariantList SoundboardService::activeBoardIdsList() const
{
    QVariantList list;
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        list.append(it.key());
    }
    return list;
}

bool SoundboardService::isBoardActive(int boardId) const
{
    return m_activeBoards.contains(boardId);
}

bool SoundboardService::toggleBoardActive(int boardId)
{
    if (m_activeBoards.contains(boardId)) {
        // Deactivate this board
        return deactivate(boardId);
    } else {
        // Activate this board
        return activate(boardId);
    }
}

void SoundboardService::setMasterGainDb(double db)
{
    m_state.settings.masterGainDb = db;
    m_indexDirty = true; // Mark as dirty instead of immediate save

    // Apply to audio engine
    if (m_audioEngine) {
        m_audioEngine->setMasterGainDB(static_cast<float>(db));
    }

    emit settingsChanged();
}

void SoundboardService::setMicGainDb(double db)
{
    m_state.settings.micGainDb = db;
    m_indexDirty = true; // Mark as dirty instead of immediate save

    // Apply to audio engine
    if (m_audioEngine) {
        m_audioEngine->setMicGainDB(static_cast<float>(db));
    }

    emit settingsChanged();
}

QString SoundboardService::getBoardName(int boardId) const
{
    for (const auto& b : m_state.soundboards) {
        if (b.id == boardId)
            return b.name;
    }
    return QString("");
}

bool SoundboardService::activate(int boardId)
{
    // Check if already active
    if (m_activeBoards.contains(boardId)) {
        return true;
    }

    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    m_activeBoards[boardId] = *loaded;
    rebuildHotkeyIndex();

    // Update index activeBoardIds
    m_state.activeBoardIds.insert(boardId);
    m_indexDirty = true; // Mark as dirty instead of immediate save

    emit activeBoardChanged();
    emit activeClipsChanged();
    emit boardsChanged();
    return true;
}

bool SoundboardService::deactivate(int boardId)
{
    if (!m_activeBoards.contains(boardId)) {
        return true; // Already not active
    }

    // Mark the board as dirty before removing
    m_dirtyBoards.insert(boardId);
    m_activeBoards.remove(boardId);
    rebuildHotkeyIndex();

    // Update index activeBoardIds
    m_state.activeBoardIds.remove(boardId);
    m_indexDirty = true; // Mark as dirty instead of immediate save

    emit activeBoardChanged();
    emit activeClipsChanged();
    emit boardsChanged();
    return true;
}

bool SoundboardService::saveActive()
{
    if (m_activeBoards.isEmpty())
        return false;

    // Mark all active boards as dirty
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        m_dirtyBoards.insert(it.key());
    }

    // Will be saved on application close
    return true;
}

QString SoundboardService::normalizeHotkey(const QString& hotkey)
{
    return hotkey.trimmed();
}

void SoundboardService::rebuildHotkeyIndex()
{
    m_hotkeyToClipId.clear();

    // Build hotkey index from all active boards
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        for (const auto& c : it.value().clips) {
            const QString hk = normalizeHotkey(c.hotkey);
            if (!hk.isEmpty()) {
                m_hotkeyToClipId[hk] = c.id;
            }
        }
    }
}

int SoundboardService::findActiveClipIdByHotkey(const QString& hotkey) const
{
    const QString hk = normalizeHotkey(hotkey);
    if (hk.isEmpty())
        return -1;
    return m_hotkeyToClipId.value(hk, -1);
}

Clip* SoundboardService::findActiveClipById(int clipId)
{
    // Search in all active boards
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        Soundboard& board = it.value();
        for (auto& c : board.clips) {
            if (c.id == clipId)
                return &c;
        }
    }
    return nullptr;
}

std::optional<Clip> SoundboardService::findClipByIdAnyBoard(int clipId, int* outBoardId) const
{
    // First search in active boards (faster)
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        const Soundboard& board = it.value();
        for (const auto& c : board.clips) {
            if (c.id == clipId) {
                if (outBoardId)
                    *outBoardId = it.key();
                return c;
            }
        }
    }

    // Search in inactive boards
    for (const auto& boardInfo : m_state.soundboards) {
        if (m_activeBoards.contains(boardInfo.id))
            continue; // Already searched

        auto loaded = m_repo.loadBoard(boardInfo.id);
        if (loaded) {
            for (const auto& c : loaded->clips) {
                if (c.id == clipId) {
                    if (outBoardId)
                        *outBoardId = boardInfo.id;
                    return c;
                }
            }
        }
    }

    return std::nullopt;
}

QVector<Clip> SoundboardService::getActiveClips() const
{
    // Return clips from all active boards combined
    QVector<Clip> allClips;
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        allClips.append(it.value().clips);
    }
    return allClips;
}

QVector<Clip> SoundboardService::getClipsForBoard(int boardId) const
{
    // If it's an active board, return from memory
    if (m_activeBoards.contains(boardId)) {
        return m_activeBoards.value(boardId).clips;
    }

    // Otherwise load from repository
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return {};
    return loaded->clips;
}

QVariantMap SoundboardService::getClipData(int boardId, int clipId) const
{
    const Clip* clip = nullptr;
    if (m_activeBoards.contains(boardId)) {
        const Soundboard& board = m_activeBoards.value(boardId);
        for (const auto& c : board.clips) {
            if (c.id == clipId) {
                clip = &c;
                break;
            }
        }
    } else {
        auto loaded = m_repo.loadBoard(boardId);
        if (loaded) {
            for (const auto& c : loaded->clips) {
                if (c.id == clipId) {
                    QVariantMap map;
                    map["id"] = c.id;
                    map["title"] = c.title;
                    map["filePath"] = c.filePath;
                    map["imgPath"] = c.imgPath;
                    map["hotkey"] = c.hotkey;
                    map["volume"] = c.volume;
                    map["speed"] = c.speed;
                    map["isPlaying"] = c.isPlaying; // Use stored state, not audio engine state
                    map["isRepeat"] = c.isRepeat;
                    map["tags"] = c.tags;
                    map["reproductionMode"] = c.reproductionMode;
                    map["stopOtherSounds"] = c.stopOtherSounds;
                    map["muteOtherSounds"] = c.muteOtherSounds;
                    map["muteMicDuringPlayback"] = c.muteMicDuringPlayback;
                    double duration = c.durationSec;
                    if (duration <= 0.0 && m_audioEngine) {
                        duration = m_audioEngine->getFileDuration(c.filePath.toStdString());
                    }
                    map["durationSec"] = duration;
                    map["trimStartMs"] = c.trimStartMs;
                    map["trimEndMs"] = c.trimEndMs;
                    map["lastPlayedPosMs"] = c.lastPlayedPosMs; // For resuming playback
                    return map;
                }
            }
        }
    }

    if (clip) {
        QVariantMap map;
        map["id"] = clip->id;
        map["title"] = clip->title;
        map["filePath"] = clip->filePath;
        map["imgPath"] = clip->imgPath;
        map["hotkey"] = clip->hotkey;
        map["volume"] = clip->volume;
        map["speed"] = clip->speed;
        map["isPlaying"] = clip->isPlaying; // Use stored state, not audio engine state
        map["isRepeat"] = clip->isRepeat;
        map["tags"] = clip->tags;
        map["reproductionMode"] = clip->reproductionMode;
        map["stopOtherSounds"] = clip->stopOtherSounds;
        map["muteOtherSounds"] = clip->muteOtherSounds;
        map["muteMicDuringPlayback"] = clip->muteMicDuringPlayback;
        double duration = clip->durationSec;
        if (duration <= 0.0 && m_audioEngine) {
            duration = m_audioEngine->getFileDuration(clip->filePath.toStdString());
        }
        map["durationSec"] = duration;
        map["trimStartMs"] = clip->trimStartMs;
        map["trimEndMs"] = clip->trimEndMs;
        map["lastPlayedPosMs"] = clip->lastPlayedPosMs; // For resuming playback
        return map;
    }

    return {};
}

bool SoundboardService::setClipPlaying(int clipId, bool playing)
{
    Clip* c = findActiveClipById(clipId);
    if (!c)
        return false;

    c->isPlaying = playing;
    c->locked = playing;
    emit activeClipsChanged();
    return true;
}

bool SoundboardService::addClip(int boardId, const QString& filePath)
{
    if (filePath.isEmpty())
        return false;

    QString localPath = filePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }

    Clip draft;
    draft.filePath = localPath;
    draft.title = QFileInfo(draft.filePath).baseName();
    // other defaults are handled inside addClipToBoard

    return addClipToBoard(boardId, draft);
}

bool SoundboardService::addClips(int boardId, const QStringList& filePaths)
{
    if (filePaths.isEmpty())
        return false;

    // If adding to an active board, we can batch and save once
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        int maxId = 0;
        for (const auto& x : board.clips)
            maxId = std::max(maxId, x.id);

        for (const QString& filePath : filePaths) {
            QString localPath = filePath;
            if (localPath.startsWith("file:")) {
                localPath = QUrl(localPath).toLocalFile();
            }
            if (localPath.isEmpty())
                continue;

            Clip c;
            c.filePath = localPath;
            c.title = QFileInfo(localPath).baseName();
            c.id = ++maxId;
            c.isPlaying = false;
            c.locked = false;

            if (m_audioEngine) {
                c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
            }

            board.clips.push_back(c);
        }
        rebuildHotkeyIndex();
        emit activeClipsChanged();
        return saveActive();
    }

    // Inactive board: load -> modify -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    int maxId = 0;
    for (const auto& x : b.clips)
        maxId = std::max(maxId, x.id);

    for (const QString& filePath : filePaths) {
        QString localPath = filePath;
        if (localPath.startsWith("file:")) {
            localPath = QUrl(localPath).toLocalFile();
        }
        if (localPath.isEmpty())
            continue;

        Clip c;
        c.filePath = localPath;
        c.title = QFileInfo(localPath).baseName();
        c.id = ++maxId;
        c.isPlaying = false;
        c.locked = false;

        if (m_audioEngine) {
            c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
        }

        b.clips.push_back(c);
    }

    // Save the updated board to repository
    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::addClipWithTitle(int boardId, const QString& filePath, const QString& title)
{
    if (filePath.isEmpty())
        return false;

    QString localPath = filePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }

    Clip draft;
    draft.filePath = localPath;
    // Use custom title if provided, otherwise fall back to filename
    draft.title = title.trimmed().isEmpty() ? QFileInfo(draft.filePath).baseName() : title.trimmed();

    return addClipToBoard(boardId, draft);
}

bool SoundboardService::addClipWithSettings(int boardId, const QString& filePath, const QString& title,
                                            double trimStartMs, double trimEndMs)
{
    if (filePath.isEmpty())
        return false;

    QString localPath = filePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }

    Clip draft;
    draft.filePath = localPath;
    draft.title = title.trimmed().isEmpty() ? QFileInfo(draft.filePath).baseName() : title.trimmed();
    draft.trimStartMs = trimStartMs;
    draft.trimEndMs = trimEndMs;

    return addClipToBoard(boardId, draft);
}

bool SoundboardService::deleteClip(int boardId, int clipId)
{
    // if deleting from an active board (in memory)
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        bool found = false;
        for (int i = 0; i < board.clips.size(); ++i) {
            if (board.clips[i].id == clipId) {
                if (board.clips[i].locked)
                    return false; // can't delete locked clip

                // STOP the clip if it's playing before deleting
                if (m_audioEngine && m_clipIdToSlot.contains(clipId)) {
                    int slotId = m_clipIdToSlot[clipId];
                    m_audioEngine->stopClip(slotId);
                    m_audioEngine->unloadClip(slotId);
                    m_clipIdToSlot.remove(clipId);
                    qDebug() << "Stopped and unloaded clip" << clipId << "before deletion";
                }

                board.clips.removeAt(i);
                found = true;
                break;
            }
        }
        if (!found)
            return false;

        rebuildHotkeyIndex();
        emit activeClipsChanged();
        emit clipPlaybackStopped(clipId); // Notify UI that clip stopped
        return saveActive();
    }

    // inactive board: load -> modify -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    bool found = false;
    for (int i = 0; i < b.clips.size(); ++i) {
        if (b.clips[i].id == clipId) {
            b.clips.removeAt(i);
            found = true;
            break;
        }
    }
    if (!found)
        return false;

    // Save the updated board to repository
    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::addClipToBoard(int boardId, const Clip& draft)
{
    if (draft.filePath.trimmed().isEmpty())
        return false;

    // Sanitize file path - convert file:// URL to local path and fix double slashes
    QString sanitizedPath = draft.filePath;
    if (sanitizedPath.startsWith("file:")) {
        sanitizedPath = QUrl(sanitizedPath).toLocalFile();
    }
    // Remove any duplicate leading slashes (e.g., "//Users" -> "/Users")
    while (sanitizedPath.startsWith("//")) {
        sanitizedPath = sanitizedPath.mid(1);
    }

    // if adding to an active board (in memory)
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        Clip c = draft;
        c.filePath = sanitizedPath; // Use sanitized path

        // default title if empty
        if (c.title.trimmed().isEmpty()) {
            c.title = QFileInfo(c.filePath).baseName();
        } else {
            c.title = c.title.trimmed();
        }

        // Extract artwork if no image set
        if (c.imgPath.isEmpty()) {
            c.imgPath = extractAudioArtwork(c.filePath);
        }

        // runtime defaults
        c.isPlaying = false;
        c.locked = false;

        // generate clip id (simple)
        int maxId = 0;
        for (const auto& x : board.clips)
            maxId = std::max(maxId, x.id);
        c.id = maxId + 1;

        // Get duration
        if (m_audioEngine) {
            c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
        }

        // Ensure shared board IDs includes current board if not already set
        if (c.sharedBoardIds.isEmpty() || !c.sharedBoardIds.contains(boardId)) {
            if (!c.sharedBoardIds.contains(boardId)) {
                c.sharedBoardIds.append(boardId);
            }
        }

        board.clips.push_back(c);
        rebuildHotkeyIndex();

        emit activeClipsChanged();
        return saveActive();
    }

    // inactive board: load -> modify -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;

    Clip c = draft;
    c.filePath = sanitizedPath; // Use sanitized path
    if (c.title.trimmed().isEmpty())
        c.title = QFileInfo(c.filePath).baseName();

    // Extract artwork if no image set
    if (c.imgPath.isEmpty()) {
        c.imgPath = extractAudioArtwork(c.filePath);
    }

    c.isPlaying = false;
    c.locked = false;

    int maxId = 0;
    for (const auto& x : b.clips)
        maxId = std::max(maxId, x.id);
    c.id = maxId + 1;

    // Get duration
    if (m_audioEngine) {
        c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
    }

    // Ensure shared board IDs includes current board if not already set
    if (c.sharedBoardIds.isEmpty() || !c.sharedBoardIds.contains(boardId)) {
        if (!c.sharedBoardIds.contains(boardId)) {
            c.sharedBoardIds.append(boardId);
        }
    }

    b.clips.push_back(c);

    // Save the updated board to repository
    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::updateClipInBoard(int boardId, int clipId, const Clip& updatedClip)
{
    // active board update (enforce locked)
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            if (c.locked)
                return false;

            Clip n = updatedClip;
            n.id = clipId;

            if (n.title.trimmed().isEmpty())
                n.title = QFileInfo(n.filePath).baseName();
            n.isPlaying = c.isPlaying;
            n.locked = c.locked;

            if (n.reproductionMode == 4)
                n.isRepeat = true;
            c = n;

            rebuildHotkeyIndex();
            emit activeClipsChanged();
            return saveActive();
        }
        return false;
    }

    // inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id != clipId)
            continue;

        Clip n = updatedClip;
        n.id = clipId;
        if (n.title.trimmed().isEmpty())
            n.title = QFileInfo(n.filePath).baseName();
        n.isPlaying = false;
        n.locked = false;

        if (n.reproductionMode == 4)
            n.isRepeat = true;
        c = n;

        // Save the updated board to repository
        const bool ok = m_repo.saveBoard(b);
        if (ok) {
            m_state = m_repo.loadIndex();
            emit boardsChanged();
        }
        return ok;
    }
    return false;
}

bool SoundboardService::updateClipInBoard(int boardId, int clipId, const QString& title, const QString& hotkey,
                                          const QStringList& tags)
{
    // active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            if (c.locked)
                return false;

            // Update title, hotkey, and tags
            c.title = title.trimmed().isEmpty() ? QFileInfo(c.filePath).baseName() : title.trimmed();
            c.hotkey = hotkey;
            c.tags = tags;

            rebuildHotkeyIndex();
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            return saveActive();
        }
        return false;
    }

    // inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id != clipId)
            continue;

        // Update title, hotkey, and tags
        c.title = title.trimmed().isEmpty() ? QFileInfo(c.filePath).baseName() : title.trimmed();
        c.hotkey = hotkey;
        c.tags = tags;

        // Save the updated board to repository
        const bool ok = m_repo.saveBoard(b);
        if (ok) {
            m_state = m_repo.loadIndex();
            emit boardsChanged();
        }
        return ok;
    }
    return false;
}

bool SoundboardService::updateClipImage(int boardId, int clipId, const QString& imagePath)
{
    // Convert file:// URL to local path if needed
    QString localPath = imagePath;
    if (localPath.startsWith("file:")) {
        localPath = QUrl(localPath).toLocalFile();
    }

    // active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            if (c.locked)
                return false;

            // Update image path
            c.imgPath = localPath;

            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            return saveActive();
        }
        return false;
    }

    // inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id != clipId)
            continue;

        // Update image path
        c.imgPath = localPath;

        // Save the updated board to repository
        const bool ok = m_repo.saveBoard(b);
        if (ok) {
            m_state = m_repo.loadIndex();
            emit boardsChanged();
        }
        return ok;
    }
    return false;
}

bool SoundboardService::updateClipAudioSettings(int boardId, int clipId, int volume, double speed)
{
    // Clamp values to valid ranges
    volume = std::max(0, std::min(100, volume));
    speed = std::max(0.5, std::min(2.0, speed));

    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            if (c.locked)
                return false;

            // Update volume and speed
            c.volume = volume;
            c.speed = speed;

            // Apply to audio engine if clip is loaded
            if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                int slotId = m_clipIdToSlot[clipId];
                // Convert volume (0-100) to dB gain (-60 to 0)
                float gainDb = (volume <= 0) ? -60.0f : 20.0f * std::log10(volume / 100.0f);
                m_audioEngine->setClipGain(slotId, gainDb);
                // Note: Speed changes would require reloading the clip with pitch shift
                // This is a placeholder for future implementation
            }

            emit activeClipsChanged();
            return saveActive();
        }
        return false;
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id != clipId)
            continue;

        // Update volume and speed
        c.volume = volume;
        c.speed = speed;

        // Save the updated board to repository
        const bool ok = m_repo.saveBoard(b);
        if (ok) {
            m_state = m_repo.loadIndex();
            emit boardsChanged();
        }
        return ok;
    }
    return false;
}

void SoundboardService::setClipVolume(int boardId, int clipId, int volume)
{
    // Clamp volume to valid range
    volume = std::max(0, std::min(100, volume));

    // Only apply to active board (real-time, no save)
    if (!m_activeBoards.contains(boardId))
        return;

    Soundboard& board = m_activeBoards[boardId];
    for (auto& c : board.clips) {
        if (c.id != clipId)
            continue;

        // Update in-memory volume
        c.volume = volume;

        // Apply to audio engine if clip is loaded
        if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
            int slotId = m_clipIdToSlot[clipId];
            // Convert volume (0-100) to dB gain (-60 to 0)
            float gainDb = (volume <= 0) ? -60.0f : 20.0f * std::log10(volume / 100.0f);
            m_audioEngine->setClipGain(slotId, gainDb);
        }

        emit activeClipsChanged();
        emit clipUpdated(boardId, clipId);
        return;
    }
}

void SoundboardService::setClipRepeat(int boardId, int clipId, bool repeat)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;

            c.isRepeat = repeat;

            // Apply to audio engine if clip is loaded
            if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], repeat);
            }

            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive(); // Persist the change
            return;
        }
    }
}

void SoundboardService::setClipReproductionMode(int boardId, int clipId, int mode)
{
    // Clamp mode to valid range (0-4)
    mode = std::max(0, std::min(4, mode));

    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;

            c.reproductionMode = mode;

            // Mode 4 (Loop) should turn on repeat, all other modes should turn it off
            if (mode == 4) {
                c.isRepeat = true;
                // Apply immediately to audio engine if currently assigned to a slot
                if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                    m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], true);
                }
            } else {
                // For all other modes (including mode 3 restart), turn off loop
                c.isRepeat = false;
                if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                    m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], false);
                }
            }

            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive(); // Persist the change
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.reproductionMode = mode;
            // Only mode 4 (Loop) forces repeat on
            if (mode == 4)
                c.isRepeat = true;
            else
                c.isRepeat = false;
            m_repo.saveBoard(b);
            m_state = m_repo.loadIndex();
            return;
        }
    }
}

void SoundboardService::setClipStopOtherSounds(int boardId, int clipId, bool stop)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            c.stopOtherSounds = stop;
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.stopOtherSounds = stop;
            m_repo.saveBoard(b);
            m_state = m_repo.loadIndex();
            return;
        }
    }
}

void SoundboardService::setClipMuteOtherSounds(int boardId, int clipId, bool mute)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            c.muteOtherSounds = mute;
            // If muteOtherSounds is enabled, also enable muteMicDuringPlayback
            if (mute) {
                c.muteMicDuringPlayback = true;
            }
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.muteOtherSounds = mute;
            if (mute)
                c.muteMicDuringPlayback = true;
            m_repo.saveBoard(b);
            m_state = m_repo.loadIndex();
            return;
        }
    }
}

void SoundboardService::setClipMuteMicDuringPlayback(int boardId, int clipId, bool mute)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            c.muteMicDuringPlayback = mute;
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.muteMicDuringPlayback = mute;
            m_repo.saveBoard(b);
            m_state = m_repo.loadIndex();
            return;
        }
    }
}

void SoundboardService::setClipTrim(int boardId, int clipId, double startMs, double endMs)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (auto& c : board.clips) {
            if (c.id != clipId)
                continue;
            if (c.trimStartMs == startMs && c.trimEndMs == endMs)
                return;
            c.trimStartMs = startMs;
            c.trimEndMs = endMs;
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();

            // Update engine if this clip is in a slot
            if (m_clipIdToSlot.contains(clipId)) {
                m_audioEngine->setClipTrim(m_clipIdToSlot[clipId], startMs, endMs);
            }
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.trimStartMs = startMs;
            c.trimEndMs = endMs;
            m_repo.saveBoard(b);
            m_state = m_repo.loadIndex();
            return;
        }
    }
}

void SoundboardService::seekClip(int boardId, int clipId, double positionMs)
{
    // Active board update
    if (m_activeBoards.contains(boardId)) {
        // Update engine if this clip is in a slot
        if (m_clipIdToSlot.contains(clipId)) {
            m_audioEngine->seekClip(m_clipIdToSlot[clipId], positionMs);
        }
    }
}

bool SoundboardService::moveClip(int boardId, int fromIndex, int toIndex)
{
    // Validate indices
    if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex)
        return false;

    // Active board update
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        if (fromIndex >= board.clips.size() || toIndex >= board.clips.size())
            return false;

        // Move clip within the vector
        Clip clip = board.clips.takeAt(fromIndex);
        board.clips.insert(toIndex, clip);

        emit activeClipsChanged();
        return saveActive();
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    if (fromIndex >= b.clips.size() || toIndex >= b.clips.size())
        return false;

    // Move clip within the vector
    Clip clip = b.clips.takeAt(fromIndex);
    b.clips.insert(toIndex, clip);

    // Save the updated board to repository
    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

void SoundboardService::copyClip(int clipId)
{
    Clip* clip = findActiveClipById(clipId);
    if (clip) {
        m_clipboardClip = *clip;
        emit clipboardChanged();
    }
}

bool SoundboardService::pasteClip(int boardId)
{
    if (!m_clipboardClip)
        return false;

    Clip draft = *m_clipboardClip;
    // Clear hotkey and ID for the new copy
    draft.hotkey = "";
    draft.id = -1;

    return addClipToBoard(boardId, draft);
}

bool SoundboardService::canPaste() const
{
    return m_clipboardClip.has_value();
}

QVariantList SoundboardService::getBoardsWithClipStatus(int clipId) const
{
    QVariantList result;

    // First, find the clip to get its file path
    QString clipFilePath;
    int sourceBoardId = -1;

    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        for (const auto& c : it.value().clips) {
            if (c.id == clipId) {
                clipFilePath = c.filePath;
                sourceBoardId = it.key();
                break;
            }
        }
        if (!clipFilePath.isEmpty())
            break;
    }

    // If not found in active boards, search inactive boards
    if (clipFilePath.isEmpty()) {
        for (const auto& boardInfo : m_state.soundboards) {
            if (!m_activeBoards.contains(boardInfo.id)) {
                auto loaded = m_repo.loadBoard(boardInfo.id);
                if (loaded) {
                    for (const auto& c : loaded->clips) {
                        if (c.id == clipId) {
                            clipFilePath = c.filePath;
                            sourceBoardId = boardInfo.id;
                            break;
                        }
                    }
                }
            }
            if (!clipFilePath.isEmpty())
                break;
        }
    }

    if (clipFilePath.isEmpty())
        return result;

    // Check each board to see if a clip with this file path actually exists
    for (const auto& boardInfo : m_state.soundboards) {
        bool hasClip = false;

        // Check active boards
        if (m_activeBoards.contains(boardInfo.id)) {
            const Soundboard& board = m_activeBoards.value(boardInfo.id);
            for (const auto& c : board.clips) {
                if (c.filePath == clipFilePath) {
                    hasClip = true;
                    break;
                }
            }
        } else {
            // Check inactive boards
            auto loaded = m_repo.loadBoard(boardInfo.id);
            if (loaded) {
                for (const auto& c : loaded->clips) {
                    if (c.filePath == clipFilePath) {
                        hasClip = true;
                        break;
                    }
                }
            }
        }

        QVariantMap boardEntry;
        boardEntry["id"] = boardInfo.id;
        boardEntry["name"] = boardInfo.name;
        boardEntry["hasClip"] = hasClip;
        boardEntry["isCurrent"] = (boardInfo.id == sourceBoardId);
        result.append(boardEntry);
    }

    return result;
}

bool SoundboardService::copyClipToBoard(int sourceClipId, int targetBoardId)
{
    // Find the source clip from any board (active or inactive)
    int sourceBoardId = -1;
    auto sourceClipOpt = findClipByIdAnyBoard(sourceClipId, &sourceBoardId);
    if (!sourceClipOpt.has_value()) {
        return false;
    }

    Clip sourceClip = sourceClipOpt.value();
    QString clipFilePath = sourceClip.filePath;

    // Check if clip already exists in target board (by file path)
    if (m_activeBoards.contains(targetBoardId)) {
        const Soundboard& board = m_activeBoards.value(targetBoardId);
        for (const auto& c : board.clips) {
            if (c.filePath == clipFilePath) {
                return false; // Already exists
            }
        }
    } else {
        auto loaded = m_repo.loadBoard(targetBoardId);
        if (loaded) {
            for (const auto& c : loaded->clips) {
                if (c.filePath == clipFilePath) {
                    return false; // Already exists
                }
            }
        }
    }

    // Create a copy of the clip
    Clip draft = sourceClip;
    draft.hotkey = ""; // Clear hotkey for the new copy
    draft.id = -1;     // Will be assigned a new ID
    draft.isPlaying = false;
    draft.locked = false;

    // Update shared board IDs - add both source and target boards
    if (!draft.sharedBoardIds.contains(sourceBoardId) && sourceBoardId != -1) {
        draft.sharedBoardIds.append(sourceBoardId);
    }
    if (!draft.sharedBoardIds.contains(targetBoardId)) {
        draft.sharedBoardIds.append(targetBoardId);
    }

    bool ok = addClipToBoard(targetBoardId, draft);
    if (ok) {
        // Now sync the sharedBoardIds back to all clips with the same file path
        syncSharedBoardIds(clipFilePath, draft.sharedBoardIds);
        emit boardsChanged();
        emit activeClipsChanged();
    }
    return ok;
}

void SoundboardService::syncSharedBoardIds(const QString& filePath, const QList<int>& sharedBoardIds)
{
    // Update all clips with the same file path in all active boards
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        Soundboard& board = it.value();
        bool boardModified = false;

        for (auto& clip : board.clips) {
            if (clip.filePath == filePath) {
                clip.sharedBoardIds = sharedBoardIds;
                boardModified = true;
            }
        }

        if (boardModified) {
            m_repo.saveBoard(board);
        }
    }

    // Also update clips in inactive boards
    for (const auto& boardInfo : m_state.soundboards) {
        if (!m_activeBoards.contains(boardInfo.id)) {
            auto loaded = m_repo.loadBoard(boardInfo.id);
            if (loaded) {
                bool boardModified = false;

                for (auto& clip : loaded->clips) {
                    if (clip.filePath == filePath) {
                        clip.sharedBoardIds = sharedBoardIds;
                        boardModified = true;
                    }
                }

                if (boardModified) {
                    m_repo.saveBoard(*loaded);
                }
            }
        }
    }
}

bool SoundboardService::removeClipByFilePath(int boardId, const QString& filePath)
{
    if (filePath.isEmpty())
        return false;

    // Active board case
    if (m_activeBoards.contains(boardId)) {
        Soundboard& board = m_activeBoards[boardId];
        for (int i = 0; i < board.clips.size(); ++i) {
            if (board.clips[i].filePath == filePath) {
                if (board.clips[i].locked)
                    return false;

                int clipId = board.clips[i].id;

                // Stop the clip if playing
                if (m_audioEngine && m_clipIdToSlot.contains(clipId)) {
                    int slotId = m_clipIdToSlot[clipId];
                    m_audioEngine->stopClip(slotId);
                    m_audioEngine->unloadClip(slotId);
                    m_clipIdToSlot.remove(clipId);
                }

                board.clips.removeAt(i);
                rebuildHotkeyIndex();

                // Update sharedBoardIds in all other clips with the same file path
                removeFromSharedBoardIds(filePath, boardId);

                emit activeClipsChanged();
                emit clipPlaybackStopped(clipId);
                return saveActive();
            }
        }
        return false;
    }

    // Inactive board case
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    for (int i = 0; i < b.clips.size(); ++i) {
        if (b.clips[i].filePath == filePath) {
            b.clips.removeAt(i);
            const bool ok = m_repo.saveBoard(b);
            if (ok) {
                // Update sharedBoardIds in all other clips with the same file path
                removeFromSharedBoardIds(filePath, boardId);

                m_state = m_repo.loadIndex();
                emit boardsChanged();
            }
            return ok;
        }
    }
    return false;
}

void SoundboardService::removeFromSharedBoardIds(const QString& filePath, int boardIdToRemove)
{
    // Remove boardIdToRemove from sharedBoardIds for all clips with this file path

    // Update active boards
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        Soundboard& board = it.value();
        bool boardModified = false;

        for (auto& clip : board.clips) {
            if (clip.filePath == filePath) {
                clip.sharedBoardIds.removeAll(boardIdToRemove);
                boardModified = true;
            }
        }

        if (boardModified) {
            m_repo.saveBoard(board);
        }
    }

    // Update inactive boards
    for (const auto& boardInfo : m_state.soundboards) {
        if (!m_activeBoards.contains(boardInfo.id)) {
            auto loaded = m_repo.loadBoard(boardInfo.id);
            if (loaded) {
                bool boardModified = false;

                for (auto& clip : loaded->clips) {
                    if (clip.filePath == filePath) {
                        clip.sharedBoardIds.removeAll(boardIdToRemove);
                        boardModified = true;
                    }
                }

                if (boardModified) {
                    m_repo.saveBoard(*loaded);
                }
            }
        }
    }
}

int SoundboardService::createBoard(const QString& name)
{
    QString finalName = name.trimmed();
    if (finalName.isEmpty())
        finalName = "New Soundboard";

    // Create board on disk + update index
    int id = m_repo.createBoard(finalName);

    // Reload index in memory and notify UI
    m_state = m_repo.loadIndex();
    emit boardsChanged();

    return id;
}

bool SoundboardService::renameBoard(int boardId, const QString& newName)
{
    const QString name = newName.trimmed();
    if (name.isEmpty())
        return false;

    // If renaming an active board (in memory)
    if (m_activeBoards.contains(boardId)) {
        m_activeBoards[boardId].name = name;
        // saveActive() will call emit activeBoardChanged, emit boardsChanged, and reload index
        return saveActive();
    }

    // Otherwise load -> rename -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    b.name = name;

    // Save the renamed board to repository
    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::deleteBoard(int boardId)
{
    // Don't allow deleting the last board
    if (m_state.soundboards.size() <= 1)
        return false;

    // If deleting an active board, deactivate it first
    if (m_activeBoards.contains(boardId)) {
        m_activeBoards.remove(boardId);
        m_state.activeBoardIds.remove(boardId);
        rebuildHotkeyIndex();
    }

    // Delete from repository
    const bool ok = m_repo.deleteBoard(boardId);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
        emit activeBoardChanged();
    }
    return ok;
}

// ============================================================================
// AUDIO PLAYBACK
// ============================================================================

void SoundboardService::clipClicked(int clipId)
{
    // This method handles a clip tile click:
    // 1. Emit signal to select the clip (shows in right sidebar)
    // 2. Play the clip with reproduction mode logic

    // Emit selection changed signal so UI updates
    setCurrentlySelectedClip(clipId);

    // Now handle playback based on the clip's reproduction mode
    playClip(clipId);
}

void SoundboardService::setCurrentlySelectedClip(int clipId)
{
    emit clipSelectionRequested(clipId);
}

void SoundboardService::reproductionPlayingClip(const QVariantList& playingClipIds, int mode)
{
    if (playingClipIds.isEmpty())
        return;

    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return;
    }

    for (const QVariant& v : playingClipIds) {
        bool ok = false;
        const int cid = v.toInt(&ok);
        if (!ok)
            continue;

        if (!m_clipIdToSlot.contains(cid))
            continue;
        const int slotId = m_clipIdToSlot.value(cid);

        switch (mode) {
        case 0: // Overlay -> do nothing to previous clips
            break;

        case 1: // Play/Pause -> pause previous clips
        {
            double pos = m_audioEngine->getClipPlaybackPositionMs(slotId);
            Clip* clip = findActiveClipById(cid);
            if (!clip)
                continue;
            clip->lastPlayedPosMs = pos;
            clip->isPlaying = false; // Mark as not playing so UI shows correct state
            saveActive();
            m_audioEngine->pauseClip(slotId);
            emit clipPlaybackPaused(cid); // Notify UI that clip is paused
            break;
        }

        case 2: // Play/Stop -> stop previous clips
        case 3: // Loop -> also stop previous clips
        {
            m_audioEngine->stopClip(slotId);

            // update your UI state if you track it
            if (Clip* other = findActiveClipById(cid)) {
                other->isPlaying = false;
            }

            emit clipPlaybackStopped(cid); // emit clipId (NOT slotId)
            break;
        }

        default:
            break;
        }
    }

    emit activeClipsChanged();
}

void SoundboardService::playClip(int clipId)
{
    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return;
    }

    Clip* clip = findActiveClipById(clipId);
    if (!clip) {
        qWarning() << "Clip not found:" << clipId;
        return;
    }

    if (clip->filePath.isEmpty()) {
        qWarning() << "Clip has no file path:" << clipId;
        return;
    }

    const int slotId = getOrAssignSlot(clipId);
    m_slotToClipId[slotId] = clipId;

    // IMPORTANT: reproductionMode of *Clip_B* affects *previous playing clips*.
    // 0=Overlay, 1=Play/Pause, 2=Play/Stop, 3=Restart, 4=Loop
    const int mode = clip->reproductionMode;

    const bool isCurrentlyPlaying = m_audioEngine->isClipPlaying(slotId);
    const bool isPaused = m_audioEngine->isClipPaused(slotId);

    // Per-clip behavior (when user taps the same clip again)
    if (mode == 1 && isCurrentlyPlaying) {
        if (!isPaused) {
            // Currently playing -> pause self
            clip->lastPlayedPosMs = m_audioEngine->getClipPlaybackPositionMs(slotId);
            m_audioEngine->pauseClip(slotId);
            clip->isPlaying = false;

            emit activeClipsChanged();
            emit clipPlaybackPaused(clipId);
            return;
        }

        // Currently paused -> we want to resume, BUT we must pause others first
        QVariantList others = playingClipIDs();

        // Remove self if present
        for (int i = others.size() - 1; i >= 0; --i) {
            bool ok = false;
            const int cid = others[i].toInt(&ok);
            if (ok && cid == clipId) {
                others.removeAt(i);
            }
        }

        // Pause other playing clips (Play/Pause rule)
        if (!others.isEmpty()) {
            QList<int> pausedClipIds;
            for (const QVariant& v : others) {
                bool ok = false;
                const int otherId = v.toInt(&ok);
                if (ok)
                    pausedClipIds.append(otherId);
            }

            reproductionPlayingClip(others, 1);

            if (!pausedClipIds.isEmpty()) {
                m_pausedByClip[clipId] = pausedClipIds;
            }
        }

        // Now resume self
        m_audioEngine->seekClip(slotId, clip->lastPlayedPosMs);
        m_audioEngine->resumeClip(slotId);
        clip->isPlaying = true;

        emit activeClipsChanged();
        emit clipPlaybackStarted(clipId);
        return;
    }

    // Handle case where clip has a saved position but is not currently in audio engine
    // (e.g., it was paused when another clip started playing)
    const bool hasSavedPosition = (mode == 1 && clip->lastPlayedPosMs > 0.0);

    if (mode == 2 && isCurrentlyPlaying && !isPaused) {
        m_audioEngine->stopClip(slotId);
        clip->isPlaying = false;
        emit activeClipsChanged();
        emit clipPlaybackStopped(clipId);
        return;
    }

    // Mode 3 (Restart): Always restart from beginning when clicking same clip
    // If the clip is playing or paused, stop it and let it fall through to restart
    if (mode == 3 && isCurrentlyPlaying) {
        m_audioEngine->stopClip(slotId);
        clip->isPlaying = false;
        qDebug() << "Mode 3 (Restart): Restarting clip" << clipId << "from beginning";
        // Fall through to reload and play from beginning
    }

    // If user taps a paused clip in Play/Stop mode: restart from beginning
    // (fall through)

    // 1) Apply Clip_B reproduction to OTHER currently playing clips
    QVariantList others = playingClipIDs();
    qDebug() << "playClip: clipId=" << clipId << "mode=" << mode << "others playing=" << others
             << "others count=" << others.size();

    // Remove this clip if it appears in the "playing" list
    for (int i = others.size() - 1; i >= 0; --i) {
        bool ok = false;
        const int cid = others[i].toInt(&ok);
        if (ok && cid == clipId) {
            others.removeAt(i);
        }
    }

    qDebug() << "playClip: after removing self, others=" << others << "others count=" << others.size();

    // Track which clips we're pausing for this clip (for resuming later)
    QList<int> pausedClipIds;

    if (mode == 1 && !others.isEmpty()) {
        // Pause Clip_A, play Clip_B - track paused clips for resuming later
        qDebug() << "playClip: mode=1 (Play/Pause), pausing" << others.size() << "other clips";
        for (const QVariant& v : others) {
            bool ok = false;
            int otherId = v.toInt(&ok);
            if (ok) {
                pausedClipIds.append(otherId);
                qDebug() << "playClip: will pause clip" << otherId;
            }
        }
        reproductionPlayingClip(others, 1);

        // Store which clips were paused by this clip
        if (!pausedClipIds.isEmpty()) {
            m_pausedByClip[clipId] = pausedClipIds;
            qDebug() << "playClip: stored paused clips for" << clipId << ":" << pausedClipIds;
        }
    } else if (mode == 2) {
        // Stop Clip_A, play Clip_B
        reproductionPlayingClip(others, 2);
    } else if (mode == 3) {
        // Restart mode - stop other sounds, play from beginning (no loop)
        reproductionPlayingClip(others, 2); // Stop others like mode 2
    } else if (mode == 4) {
        // Loop mode - stop other sounds, set Clip_B to loop, play Clip_B
        reproductionPlayingClip(others, 2); // Stop others
    }
    // mode == 0 overlay -> do nothing to others

    // Per-clip behavior options (independent of reproduction mode)
    if (clip->stopOtherSounds && !others.isEmpty()) {
        // Stop all other playing clips
        for (const QVariant& v : others) {
            bool ok = false;
            int otherId = v.toInt(&ok);
            if (ok) {
                stopClip(otherId);
            }
        }
    } else if (clip->muteOtherSounds && !others.isEmpty()) {
        // Pause (mute) all other playing clips and track them for resuming later
        QList<int> mutedClipIds;
        for (const QVariant& v : others) {
            bool ok = false;
            int otherId = v.toInt(&ok);
            if (ok && m_clipIdToSlot.contains(otherId)) {
                int otherSlotId = m_clipIdToSlot[otherId];
                if (m_audioEngine->isClipPlaying(otherSlotId) && !m_audioEngine->isClipPaused(otherSlotId)) {
                    // Save position before pausing
                    Clip* otherClip = findActiveClipById(otherId);
                    if (otherClip) {
                        otherClip->lastPlayedPosMs = m_audioEngine->getClipPlaybackPositionMs(otherSlotId);
                        otherClip->isPlaying = false;
                    }
                    m_audioEngine->pauseClip(otherSlotId);
                    mutedClipIds.append(otherId);
                    emit clipPlaybackPaused(otherId);
                }
            }
        }
        // Track which clips were muted by this clip for resuming later
        if (!mutedClipIds.isEmpty()) {
            m_pausedByClip[clipId] = mutedClipIds;
        }
        emit activeClipsChanged();
    }

    // Mute mic if muteMicDuringPlayback is enabled for this clip
    bool wasMicEnabled = isMicEnabled();
    if (clip->muteMicDuringPlayback && wasMicEnabled) {
        if (m_audioEngine) {
            m_audioEngine->setMicEnabled(false);
            m_clipsThatMutedMic.insert(clipId); // Track this clip muted the mic
            emit settingsChanged();
            qDebug() << "Mic muted during playback of clip" << clipId;
        }
    }

    // 2) Prepare Clip_B to start from beginning
    // Ensure it's stopped so loadClip() can succeed reliably
    m_audioEngine->stopClip(slotId);

    const std::string filePath = clip->filePath.toStdString();
    auto [startSec, endSec] = m_audioEngine->loadClip(slotId, filePath);
    if (startSec == endSec) {
        qWarning() << "Failed to load clip:" << clip->filePath;
        // Restore mic if we muted it
        if (clip->muteMicDuringPlayback && wasMicEnabled) {
            m_audioEngine->setMicEnabled(true);
            m_clipsThatMutedMic.remove(clipId);
            emit settingsChanged();
        }
        return;
    }
    clip->durationSec = endSec;

    // Apply gain
    const float gainDb = (clip->volume <= 0) ? -60.0f : 20.0f * std::log10(clip->volume / 100.0f);
    m_audioEngine->setClipGain(slotId, gainDb);

    // Apply loop behavior (Mode 4 forces repeat ON, Mode 3 is restart without loop)
    const bool loop = (mode == 4) ? true : clip->isRepeat;
    if (mode == 4)
        clip->isRepeat = true;

    m_audioEngine->setClipLoop(slotId, loop);
    m_audioEngine->setClipTrim(slotId, clip->trimStartMs, clip->trimEndMs);

    // Resume from saved position if applicable (mainly for Play/Pause mode)
    if (hasSavedPosition) {
        m_audioEngine->seekClip(slotId, clip->lastPlayedPosMs);
        qDebug() << "Starting clip" << clipId << "from saved position" << clip->lastPlayedPosMs << "ms";
    } else {
        qDebug() << "Starting clip" << clipId << "from beginning";
    }

    // Play the clip
    m_audioEngine->playClip(slotId);

    clip->isPlaying = true;
    emit activeClipsChanged();
    emit clipPlaybackStarted(clipId);

    static const char* modeNames[] = {"Overlay", "Play/Pause", "Play/Stop", "Restart", "Loop"};
    if (mode >= 0 && mode <= 4) {
        qDebug() << "mode" << modeNames[mode];
    } else {
        qDebug() << "mode" << mode;
    }
}

void SoundboardService::stopClip(int clipId)
{
    if (!m_audioEngine)
        return;
    if (!m_clipIdToSlot.contains(clipId))
        return;

    int slotId = m_clipIdToSlot[clipId];
    m_audioEngine->stopClip(slotId);

    // remove ownership mapping
    m_slotToClipId.remove(slotId);

    finalizeClipPlayback(clipId);
    qDebug() << "Stopped clip" << clipId << "in slot" << slotId;
}

bool SoundboardService::startRecording()
{
    if (!m_audioEngine)
        return false;

    // Stop preview if playing (avoid device conflicts)
    if (m_recordingPreviewPlaying) {
        stopLastRecordingPreview();
    }

    // Clear any previous pending recording to prevent re-save duplicates
    m_hasUnsavedRecording = false;
    m_lastRecordingPath.clear();

    emit recordingStateChanged(); // updates QML immediately

    m_lastRecordingPath = getRecordingOutputPath();
    QDir().mkpath(QFileInfo(m_lastRecordingPath).absolutePath());

    const bool success = m_audioEngine->startRecording(m_lastRecordingPath.toStdString());
    if (success) {
        // Start periodic UI updates
        if (m_recordingTickTimer)
            m_recordingTickTimer->start();

        emit recordingStateChanged();
    } else {
        // If failed, don't keep stale path
        m_lastRecordingPath.clear();
        emit recordingStateChanged();
    }
    return success;
}

bool SoundboardService::stopRecording()
{
    if (!m_audioEngine)
        return false;

    const bool success = m_audioEngine->stopRecording();

    if (m_recordingTickTimer)
        m_recordingTickTimer->stop();

    // Only mark as pending if a real file exists
    if (success && !m_lastRecordingPath.isEmpty() && QFileInfo::exists(m_lastRecordingPath)) {
        m_hasUnsavedRecording = true;
    } else {
        m_hasUnsavedRecording = false;
        m_lastRecordingPath.clear();
    }

    emit recordingStateChanged();
    return success;
}

bool SoundboardService::hasPendingRecording() const
{
    return m_hasUnsavedRecording && !m_lastRecordingPath.isEmpty() && QFileInfo::exists(m_lastRecordingPath);
}

QString SoundboardService::consumePendingRecordingPath()
{
    if (!hasPendingRecording())
        return QString();

    // Stop preview if playing
    if (m_recordingPreviewPlaying) {
        // Use the existing stop function so state updates consistently
        const_cast<SoundboardService*>(this)->stopLastRecordingPreview();
    }

    m_hasUnsavedRecording = false;

    const QString path = m_lastRecordingPath;
    m_lastRecordingPath.clear();

    emit recordingStateChanged();
    return path;
}

void SoundboardService::cancelPendingRecording()
{
    if (!m_audioEngine) {
        // Still clear state
        if (!m_lastRecordingPath.isEmpty())
            QFile::remove(m_lastRecordingPath);
        m_lastRecordingPath.clear();
        m_hasUnsavedRecording = false;
        m_recordingPreviewPlaying = false;
        emit recordingStateChanged();
        return;
    }

    // If currently recording, stop recording first
    if (isRecording()) {
        m_audioEngine->stopRecording();
    }

    if (m_recordingTickTimer)
        m_recordingTickTimer->stop();

    // Stop preview if playing
    if (m_recordingPreviewPlaying) {
        stopLastRecordingPreview();
    }

    // Delete file if exists
    if (!m_lastRecordingPath.isEmpty()) {
        QFile::remove(m_lastRecordingPath);
    }

    m_lastRecordingPath.clear();
    m_hasUnsavedRecording = false;
    m_recordingPreviewPlaying = false;

    emit recordingStateChanged();
}

bool SoundboardService::isRecording() const
{
    if (!m_audioEngine)
        return false;
    return m_audioEngine->isRecording();
}

float SoundboardService::recordingDuration() const
{
    if (!m_audioEngine)
        return 0.0f;
    return m_audioEngine->getRecordingDuration();
}

QString SoundboardService::getRecordingOutputPath() const
{
    // Recordings folder in AppData
    QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (root.isEmpty()) {
        root = QDir::homePath() + "/.TalkLess";
    }
    QDir base(root);
    QString recordingsPath = base.filePath("recordings");

    // Generate filename with timestamp
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString filename = QString("recording_%1.wav").arg(timestamp);

    return QDir(recordingsPath).filePath(filename);
}

bool SoundboardService::setRecordingInputDevice(const QString& deviceId)
{
    if (!m_audioEngine)
        return false;

    // This should control the dedicated recording-input device
    const bool success = m_audioEngine->setRecordingDevice(deviceId.toStdString());
    if (success) {
        // Optional: persist separately (recommended you add a field in settings)
        // m_state.settings.selectedRecordingCaptureDeviceId = deviceId;
        // m_indexDirty = true;

        emit settingsChanged();
    }
    return success;
}

bool SoundboardService::playLastRecordingPreview()
{
    if (!m_audioEngine || m_lastRecordingPath.isEmpty())
        return false;

    if (!QFileInfo::exists(m_lastRecordingPath))
        return false;

    // If already previewing, restart cleanly
    m_audioEngine->stopClip(kPreviewSlot);
    m_audioEngine->unloadClip(kPreviewSlot);

    auto result = m_audioEngine->loadClip(kPreviewSlot, m_lastRecordingPath.toStdString());
    const double endSec = result.second;

    const bool success = (endSec > 0.0);
    if (success) {
        m_audioEngine->playClip(kPreviewSlot);
        m_recordingPreviewPlaying = true;
        emit recordingStateChanged();
    } else {
        m_recordingPreviewPlaying = false;
        emit recordingStateChanged();
    }

    return success;
}

void SoundboardService::stopLastRecordingPreview()
{
    if (!m_audioEngine)
        return;

    m_audioEngine->stopClip(kPreviewSlot);
    m_audioEngine->unloadClip(kPreviewSlot);
    m_recordingPreviewPlaying = false;
    emit recordingStateChanged();
}

bool SoundboardService::isRecordingPreviewPlaying() const
{
    return m_recordingPreviewPlaying;
}

QVariantList SoundboardService::listBoardsForDropdown() const
{
    QVariantList out;
    for (const auto& b : m_state.soundboards) {
        QVariantMap m;
        m["id"] = b.id;
        m["name"] = b.name;
        out.append(m);
    }
    return out;
}

void SoundboardService::finalizeClipPlayback(int clipId)
{
    // Update state
    Clip* clip = findActiveClipById(clipId);
    if (clip) {
        clip->isPlaying = false;
        clip->lastPlayedPosMs = 0.0;
        emit activeClipsChanged();
        saveActive();
    }

    // If something else is currently playing (not paused), DO NOT auto-resume paused clips.
    {
        QVariantList others = playingClipIDs(); // excludes paused by your logic
        for (int i = others.size() - 1; i >= 0; --i) {
            bool ok = false;
            const int cid = others[i].toInt(&ok);
            if (ok && cid == clipId) {
                others.removeAt(i);
            }
        }

        if (!others.isEmpty()) {
            qDebug() << "finalizeClipPlayback: skip resuming paused clips because other clips are playing:" << others;
            emit clipPlaybackStopped(clipId);
            return;
        }
    }

    // Resume clips that were paused by this clip (Play/Pause mode)
    if (m_pausedByClip.contains(clipId)) {
        QList<int> pausedClips = m_pausedByClip.take(clipId);
        for (int pausedClipId : pausedClips) {
            Clip* pausedClip = findActiveClipById(pausedClipId);
            if (pausedClip && m_clipIdToSlot.contains(pausedClipId)) {
                int slotId = m_clipIdToSlot[pausedClipId];
                if (m_audioEngine->isClipPaused(slotId)) {
                    m_audioEngine->resumeClip(slotId);
                    pausedClip->isPlaying = true;
                    emit clipPlaybackStarted(pausedClipId);
                    qDebug() << "Resumed paused clip" << pausedClipId << "after clip" << clipId << "stopped";
                }
            }
        }
        emit activeClipsChanged();
    }

    // Restore mic if needed (keep your current code)
    if (m_clipsThatMutedMic.contains(clipId)) {
        m_clipsThatMutedMic.remove(clipId);
        if (m_clipsThatMutedMic.isEmpty()) {
            if (m_audioEngine) {
                m_audioEngine->setMicEnabled(true);
                emit settingsChanged();
                qDebug() << "Mic restored after clip" << clipId << "playback finalized";
            }
        }
    }

    emit clipPlaybackStopped(clipId);
}

void SoundboardService::stopAllClips()
{
    if (!m_audioEngine) {
        return;
    }

    for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end(); ++it) {
        m_audioEngine->stopClip(it.value());

        Clip* clip = findActiveClipById(it.key());
        if (clip) {
            clip->isPlaying = false;
        }
    }

    // Restore mic if any clips had muted it
    if (!m_clipsThatMutedMic.isEmpty()) {
        m_clipsThatMutedMic.clear();
        if (m_audioEngine) {
            m_audioEngine->setMicEnabled(true);
            emit settingsChanged();
            qDebug() << "Mic restored after stopping all clips";
        }
    }

    emit activeClipsChanged();
    qDebug() << "Stopped all clips";
}

bool SoundboardService::isClipPlaying(int clipId) const
{
    if (!m_audioEngine) {
        return false;
    }

    if (!m_clipIdToSlot.contains(clipId)) {
        return false;
    }

    int slotId = m_clipIdToSlot[clipId];
    return m_audioEngine->isClipPlaying(slotId);
}

double SoundboardService::getClipPlaybackPositionMs(int clipId) const
{
    if (!m_audioEngine)
        return 0.0;
    if (!m_clipIdToSlot.contains(clipId))
        return 0.0;

    return m_audioEngine->getClipPlaybackPositionMs(m_clipIdToSlot[clipId]);
}

double SoundboardService::getClipPlaybackProgress(int clipId) const
{
    if (!m_audioEngine)
        return 0.0;
    if (!m_clipIdToSlot.contains(clipId))
        return 0.0;

    // Find the clip to get its duration and trim points
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        for (const auto& clip : it.value().clips) {
            if (clip.id == clipId) {
                double totalDurationMs = clip.durationSec * 1000.0;
                if (totalDurationMs <= 0.0)
                    return 0.0;

                double trimStartMs = clip.trimStartMs;
                double trimEndMs = clip.trimEndMs > 0.0 ? clip.trimEndMs : totalDurationMs;

                // Calculate effective duration (the portion of the clip that actually plays)
                double effectiveDurationMs = trimEndMs - trimStartMs;
                if (effectiveDurationMs <= 0.0)
                    return 0.0;

                // Get current position (returns trimStartMs + played time)
                double positionMs = m_audioEngine->getClipPlaybackPositionMs(m_clipIdToSlot[clipId]);

                // Calculate progress within the trimmed region
                double playedMs = positionMs - trimStartMs;
                double progress = playedMs / effectiveDurationMs;

                return std::clamp(progress, 0.0, 1.0);
            }
        }
    }
    return 0.0;
}

double SoundboardService::getClipDurationMs(int clipId) const
{
    // Find the clip to get its duration
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        for (const auto& clip : it.value().clips) {
            if (clip.id == clipId) {
                return clip.durationSec * 1000.0;
            }
        }
    }
    return 0.0;
}

double SoundboardService::getFileDuration(const QString& filePath) const
{
    if (!m_audioEngine)
        return 0.0;

    QString path = filePath;
    if (path.startsWith("file:")) {
        path = QUrl(filePath).toLocalFile();
    }

    return m_audioEngine->getFileDuration(path.toStdString());
}

QVariantList SoundboardService::playingClipIDs() const
{
    QVariantList playingIds;

    // Check all active boards for playing clips (excluding paused clips)
    for (auto it = m_activeBoards.begin(); it != m_activeBoards.end(); ++it) {
        for (const auto& clip : it.value().clips) {
            // Check our internal state first (more reliable for short clips)
            // Also verify with audio engine if clip has a slot
            bool isPlayingInternal = clip.isPlaying;
            bool isPlayingEngine = false;
            bool isPausedEngine = false;

            if (m_clipIdToSlot.contains(clip.id)) {
                int slotId = m_clipIdToSlot[clip.id];
                isPlayingEngine = m_audioEngine && m_audioEngine->isClipPlaying(slotId);
                isPausedEngine = m_audioEngine && m_audioEngine->isClipPaused(slotId);
            }

            // Clip is playing if either our internal state says so OR the audio engine says so
            // Exclude paused clips
            if ((isPlayingInternal || isPlayingEngine) && !isPausedEngine) {
                playingIds.append(clip.id);
                qDebug() << "playingClipIDs: clip" << clip.id << "is playing (internal=" << isPlayingInternal
                         << ", engine=" << isPlayingEngine << ")";
            }
        }
    }
    qDebug() << "playingClipIDs: returning" << playingIds;
    return playingIds;
}

int SoundboardService::getOrAssignSlot(int clipId)
{
    if (m_clipIdToSlot.contains(clipId))
        return m_clipIdToSlot[clipId];

    QSet<int> usedSlots;
    for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end(); ++it)
        usedSlots.insert(it.value());

    // Only use 0..14 (reserve 15 for preview)
    for (int i = 0; i < kClipSlotsUsable; ++i) {
        int candidateSlot = (m_nextSlot + i) % kClipSlotsUsable;
        if (!usedSlots.contains(candidateSlot)) {
            m_clipIdToSlot[clipId] = candidateSlot;
            m_nextSlot = (candidateSlot + 1) % kClipSlotsUsable;
            return candidateSlot;
        }
    }

    // Evict using round-robin within usable slots only
    int slotId = m_nextSlot % kClipSlotsUsable;

    for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end();) {
        if (it.value() == slotId && it.key() != clipId) {
            if (m_audioEngine && m_audioEngine->isClipPlaying(slotId))
                m_audioEngine->stopClip(slotId);
            it = m_clipIdToSlot.erase(it);
        } else {
            ++it;
        }
    }

    m_clipIdToSlot[clipId] = slotId;
    m_nextSlot = (slotId + 1) % kClipSlotsUsable;
    return slotId;
}

// ============================================================================
// AUDIO DEVICE SELECTION
// ============================================================================

QVariantList SoundboardService::getInputDevices() const
{
    QVariantList result;
    if (!m_audioEngine) {
        return result;
    }

    auto devices = m_audioEngine->enumerateCaptureDevices();
    for (const auto& device : devices) {
        QVariantMap deviceMap;
        deviceMap["id"] = QString::fromStdString(device.id);
        deviceMap["name"] = QString::fromStdString(device.name);
        deviceMap["isDefault"] = device.isDefault;
        result.append(deviceMap);
    }
    return result;
}

QVariantList SoundboardService::getOutputDevices() const
{
    QVariantList result;
    if (!m_audioEngine) {
        return result;
    }

    auto devices = m_audioEngine->enumeratePlaybackDevices();
    for (const auto& device : devices) {
        QVariantMap deviceMap;
        deviceMap["id"] = QString::fromStdString(device.id);
        deviceMap["name"] = QString::fromStdString(device.name);
        deviceMap["isDefault"] = device.isDefault;
        result.append(deviceMap);
    }
    return result;
}

bool SoundboardService::setInputDevice(const QString& deviceId)
{
    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return false;
    }

    bool success = m_audioEngine->setCaptureDevice(deviceId.toStdString());
    if (success) {
        m_state.settings.selectedCaptureDeviceId = deviceId;
        m_indexDirty = true; // Mark as dirty instead of immediate save
        qDebug() << "Input device set to:" << deviceId;
        emit settingsChanged();
    } else {
        qWarning() << "Failed to set input device:" << deviceId;
    }
    return success;
}

bool SoundboardService::setOutputDevice(const QString& deviceId)
{
    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return false;
    }

    bool success = m_audioEngine->setPlaybackDevice(deviceId.toStdString());
    if (success) {
        m_state.settings.selectedPlaybackDeviceId = deviceId;
        m_indexDirty = true; // Mark as dirty instead of immediate save
        qDebug() << "Output device set to:" << deviceId;
        emit settingsChanged();
    } else {
        qWarning() << "Failed to set output device:" << deviceId;
    }
    return success;
}

bool SoundboardService::setMonitorOutputDevice(const QString& deviceId)
{
    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return false;
    }

    bool success = m_audioEngine->setMonitorPlaybackDevice(deviceId.toStdString());
    if (success) {
        m_state.settings.selectedMonitorDeviceId = deviceId;
        m_indexDirty = true; // Mark as dirty instead of immediate save
        qDebug() << "Secondary output device set to:" << deviceId;
        emit settingsChanged();
    } else {
        qWarning() << "Failed to set secondary output device:" << deviceId;
    }
    return success;
}

void SoundboardService::refreshAudioDevices()
{
    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return;
    }

    // Refresh the audio context and devices
    m_audioEngine->refreshPlaybackDevices();

    // Try to reconnect to previously selected devices if they're available again
    // Check and reconnect capture device
    if (!m_state.settings.selectedCaptureDeviceId.isEmpty()) {
        auto inputDevices = m_audioEngine->enumerateCaptureDevices();
        for (const auto& device : inputDevices) {
            if (QString::fromStdString(device.id) == m_state.settings.selectedCaptureDeviceId ||
                QString::fromStdString(device.name) == m_state.settings.selectedCaptureDeviceId) {
                qDebug() << "Reconnecting to capture device:" << m_state.settings.selectedCaptureDeviceId;
                m_audioEngine->setCaptureDevice(m_state.settings.selectedCaptureDeviceId.toStdString());
                break;
            }
        }
    }

    // Check and reconnect playback device
    if (!m_state.settings.selectedPlaybackDeviceId.isEmpty()) {
        auto outputDevices = m_audioEngine->enumeratePlaybackDevices();
        for (const auto& device : outputDevices) {
            if (QString::fromStdString(device.id) == m_state.settings.selectedPlaybackDeviceId ||
                QString::fromStdString(device.name) == m_state.settings.selectedPlaybackDeviceId) {
                qDebug() << "Reconnecting to playback device:" << m_state.settings.selectedPlaybackDeviceId;
                m_audioEngine->setPlaybackDevice(m_state.settings.selectedPlaybackDeviceId.toStdString());
                break;
            }
        }
    }

    // Check and reconnect monitor device
    if (!m_state.settings.selectedMonitorDeviceId.isEmpty()) {
        auto outputDevices = m_audioEngine->enumeratePlaybackDevices();
        for (const auto& device : outputDevices) {
            if (QString::fromStdString(device.id) == m_state.settings.selectedMonitorDeviceId ||
                QString::fromStdString(device.name) == m_state.settings.selectedMonitorDeviceId) {
                qDebug() << "Reconnecting to monitor device:" << m_state.settings.selectedMonitorDeviceId;
                m_audioEngine->setMonitorPlaybackDevice(m_state.settings.selectedMonitorDeviceId.toStdString());
                break;
            }
        }
    }

    qDebug() << "Audio devices refreshed and reconnected";
    emit audioDevicesChanged();
}

// ============================================================================
// AUDIO LEVEL MONITORING
// ============================================================================

float SoundboardService::getMicPeakLevel() const
{
    if (!m_audioEngine) {
        return 0.0f;
    }
    return m_audioEngine->getMicPeakLevel();
}

float SoundboardService::getMasterPeakLevel() const
{
    if (!m_audioEngine) {
        return 0.0f;
    }
    return m_audioEngine->getMasterPeakLevel();
}

float SoundboardService::getMonitorPeakLevel() const
{
    if (!m_audioEngine) {
        return 0.0f;
    }
    return m_audioEngine->getMonitorPeakLevel();
}

void SoundboardService::resetPeakLevels()
{
    if (m_audioEngine) {
        m_audioEngine->resetPeakLevels();
    }
}

// ============================================================================
// MIXER CONTROLS
// ============================================================================

void SoundboardService::setMicSoundboardBalance(float balance)
{
    if (!m_audioEngine) {
        return;
    }

    // Clamp balance to 0.0-1.0 range
    balance = std::max(0.0f, std::min(1.0f, balance));

    // Balance affects mic and clip gains inversely
    // At balance = 0.0: mic = 100%, clips = 0%
    // At balance = 0.5: mic = 100%, clips = 100% (both full)
    // At balance = 1.0: mic = 0%, clips = 100%

    // Use a crossfade curve: mic reduces as balance goes up, clips are always at balance level
    float micMultiplier = 1.0f - balance; // 1.0 at 0, 0.0 at 1.0

    // Apply the mic gain based on balance
    // We'll use a linear mix for now - mic fades out as balance increases
    m_audioEngine->setMicSoundboardBalance(balance);

    m_state.settings.micSoundboardBalance = balance;
    m_indexDirty = true; // Mark as dirty instead of immediate save

    qDebug() << "Mic/Soundboard balance set to:" << balance;
    emit settingsChanged();
}

float SoundboardService::getMicSoundboardBalance() const
{
    if (!m_audioEngine) {
        return 0.5f; // Default to center
    }
    return m_audioEngine->getMicSoundboardBalance();
}

void SoundboardService::setMicPassthroughEnabled(bool enabled)
{
    if (!m_audioEngine) {
        return;
    }
    m_audioEngine->setMicPassthroughEnabled(enabled);
    m_state.settings.micPassthroughEnabled = enabled;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    qDebug() << "Mic passthrough" << (enabled ? "enabled" : "disabled");
    emit settingsChanged();
}

bool SoundboardService::isMicPassthroughEnabled() const
{
    if (!m_audioEngine) {
        return true;
    }
    return m_audioEngine->isMicPassthroughEnabled();
}

void SoundboardService::setMicEnabled(bool enabled)
{
    if (!m_audioEngine) {
        return;
    }
    m_audioEngine->setMicEnabled(enabled);
    m_state.settings.micEnabled = enabled;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    qDebug() << "Mic capture" << (enabled ? "enabled" : "disabled");
    emit settingsChanged();
}

bool SoundboardService::isMicEnabled() const
{
    if (!m_audioEngine) {
        return true;
    }
    return m_audioEngine->isMicEnabled();
}

// ============================================================================
// SOUNDBOARD HOTKEY MANAGEMENT
// ============================================================================

QString SoundboardService::getBoardHotkey(int boardId) const
{
    for (const auto& b : m_state.soundboards) {
        if (b.id == boardId)
            return b.hotkey;
    }
    return QString("");
}

bool SoundboardService::setBoardHotkey(int boardId, const QString& hotkey)
{
    // Update in m_state (index)
    for (auto& info : m_state.soundboards) {
        if (info.id == boardId) {
            info.hotkey = hotkey;
            break;
        }
    }

    // If it's an active board, update in memory too
    if (m_activeBoards.contains(boardId)) {
        m_activeBoards[boardId].hotkey = hotkey;
        m_dirtyBoards.insert(boardId);
    } else {
        // Load, update, mark as dirty
        auto loaded = m_repo.loadBoard(boardId);
        if (loaded) {
            loaded->hotkey = hotkey;
            m_dirtyBoards.insert(boardId);
        }
    }

    // Mark index as dirty
    m_indexDirty = true;
    emit boardsChanged();

    return true;
}

// ============================================================================
// HOTKEY ACTION HANDLER
// ============================================================================

void SoundboardService::handleHotkeyAction(const QString& actionId)
{
    qDebug() << "Hotkey action received:" << actionId;

    if (actionId == "sys.toggleMute") {
        // Toggle mic enabled state
        bool currentState = isMicEnabled();
        setMicEnabled(!currentState);
        qDebug() << "Mic toggled to:" << !currentState;
    } else if (actionId == "sys.stopAll") {
        stopAllClips();
        qDebug() << "All clips stopped via hotkey";
    } else if (actionId == "sys.playSelected") {
        // Emit signal for QML to handle - it knows the selected clip
        emit playSelectedRequested();
        qDebug() << "Play selected signal emitted";
    } else if (actionId.startsWith("board.")) {
        // Handle soundboard activation hotkeys (e.g., "board.1" activates board 1)
        bool ok;
        int boardId = actionId.mid(6).toInt(&ok);
        if (ok) {
            activate(boardId);
            qDebug() << "Soundboard activated via hotkey:" << boardId;
        }
    } else if (actionId.startsWith("clip.")) {
        // Handle clip-specific hotkeys (e.g., "clip.123" plays clip 123)
        bool ok;
        int clipId = actionId.mid(5).toInt(&ok);
        if (ok) {
            // Clip hotkey uses the clip's reproduction mode
            playClip(clipId);
            qDebug() << "Clip hotkey triggered for clip:" << clipId;
        }
    } else {
        qDebug() << "Unknown hotkey action:" << actionId;
    }
}

void SoundboardService::setTheme(const QString& theme)
{
    if (m_state.settings.theme == theme)
        return;
    m_state.settings.theme = theme;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setAccentColor(const QString& color)
{
    if (m_state.settings.accentColor == color)
        return;
    m_state.settings.accentColor = color;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setSlotSize(const QString& size)
{
    if (m_state.settings.slotSize == size)
        return;
    m_state.settings.slotSize = size;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setSlotSizeScale(double scale)
{
    // Clamp scale to valid range
    scale = qBound(0.5, scale, 1.5);
    if (qFuzzyCompare(m_state.settings.slotSizeScale, scale))
        return;
    m_state.settings.slotSizeScale = scale;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setLanguage(const QString& lang)
{
    if (m_state.settings.language == lang)
        return;
    m_state.settings.language = lang;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setHotkeyMode(const QString& mode)
{
    if (m_state.settings.hotkeyMode == mode)
        return;
    m_state.settings.hotkeyMode = mode;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setBufferSizeFrames(int frames)
{
    // Validate: only allow common buffer sizes
    if (frames != 256 && frames != 512 && frames != 1024 && frames != 2048 && frames != 4096)
        return;
    if (m_state.settings.bufferSizeFrames == frames)
        return;
    m_state.settings.bufferSizeFrames = frames;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
    // Note: Audio engine needs restart to apply new buffer settings
}

void SoundboardService::setBufferPeriods(int periods)
{
    // Validate: only allow 2, 3, or 4 periods
    if (periods < 2 || periods > 4)
        return;
    if (m_state.settings.bufferPeriods == periods)
        return;
    m_state.settings.bufferPeriods = periods;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setSampleRate(int rate)
{
    // Validate: only allow common sample rates
    if (rate != 44100 && rate != 48000 && rate != 96000)
        return;
    if (m_state.settings.sampleRate == rate)
        return;
    m_state.settings.sampleRate = rate;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

void SoundboardService::setAudioChannels(int channels)
{
    // Validate: only allow mono (1) or stereo (2)
    if (channels != 1 && channels != 2)
        return;
    if (m_state.settings.channels == channels)
        return;
    m_state.settings.channels = channels;
    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

bool SoundboardService::exportSettings(const QString& filePath)
{
    QString path = filePath;
    if (path.startsWith("file:///")) {
        path = QUrl(filePath).toLocalFile();
    }

    QJsonObject root;
    QJsonObject settings;
    settings["masterGainDb"] = m_state.settings.masterGainDb;
    settings["micGainDb"] = m_state.settings.micGainDb;
    settings["selectedPlaybackDeviceId"] = m_state.settings.selectedPlaybackDeviceId;
    settings["selectedCaptureDeviceId"] = m_state.settings.selectedCaptureDeviceId;
    settings["selectedMonitorDeviceId"] = m_state.settings.selectedMonitorDeviceId;
    settings["theme"] = m_state.settings.theme;
    settings["accentColor"] = m_state.settings.accentColor;
    settings["slotSize"] = m_state.settings.slotSize;
    settings["language"] = m_state.settings.language;
    settings["hotkeyMode"] = m_state.settings.hotkeyMode;
    settings["micEnabled"] = m_state.settings.micEnabled;
    settings["micPassthroughEnabled"] = m_state.settings.micPassthroughEnabled;
    settings["micSoundboardBalance"] = m_state.settings.micSoundboardBalance;
    // Audio buffer settings
    settings["bufferSizeFrames"] = m_state.settings.bufferSizeFrames;
    settings["bufferPeriods"] = m_state.settings.bufferPeriods;
    settings["sampleRate"] = m_state.settings.sampleRate;
    settings["channels"] = m_state.settings.channels;

    root["settings"] = settings;
    root["version"] = m_state.version;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to open file for export:" << path;
        return false;
    }

    file.write(QJsonDocument(root).toJson());
    return true;
}

bool SoundboardService::importSettings(const QString& filePath)
{
    QString path = filePath;
    if (path.startsWith("file:///")) {
        path = QUrl(filePath).toLocalFile();
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open file for import:" << path;
        return false;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (doc.isNull())
        return false;

    QJsonObject root = doc.object();
    if (root.contains("settings")) {
        QJsonObject s = root.value("settings").toObject();
        m_state.settings.masterGainDb = s.value("masterGainDb").toDouble(m_state.settings.masterGainDb);
        m_state.settings.micGainDb = s.value("micGainDb").toDouble(m_state.settings.micGainDb);
        m_state.settings.selectedPlaybackDeviceId =
            s.value("selectedPlaybackDeviceId").toString(m_state.settings.selectedPlaybackDeviceId);
        m_state.settings.selectedCaptureDeviceId =
            s.value("selectedCaptureDeviceId").toString(m_state.settings.selectedCaptureDeviceId);
        m_state.settings.selectedMonitorDeviceId =
            s.value("selectedMonitorDeviceId").toString(m_state.settings.selectedMonitorDeviceId);
        m_state.settings.theme = s.value("theme").toString(m_state.settings.theme);
        m_state.settings.accentColor = s.value("accentColor").toString(m_state.settings.accentColor);
        m_state.settings.slotSize = s.value("slotSize").toString(m_state.settings.slotSize);
        m_state.settings.language = s.value("language").toString(m_state.settings.language);
        m_state.settings.hotkeyMode = s.value("hotkeyMode").toString(m_state.settings.hotkeyMode);
        m_state.settings.micEnabled = s.value("micEnabled").toBool(m_state.settings.micEnabled);
        m_state.settings.micPassthroughEnabled =
            s.value("micPassthroughEnabled").toBool(m_state.settings.micPassthroughEnabled);
        m_state.settings.micSoundboardBalance =
            (float)s.value("micSoundboardBalance").toDouble(m_state.settings.micSoundboardBalance);
        // Audio buffer settings
        m_state.settings.bufferSizeFrames = s.value("bufferSizeFrames").toInt(m_state.settings.bufferSizeFrames);
        m_state.settings.bufferPeriods = s.value("bufferPeriods").toInt(m_state.settings.bufferPeriods);
        m_state.settings.sampleRate = s.value("sampleRate").toInt(m_state.settings.sampleRate);
        m_state.settings.channels = s.value("channels").toInt(m_state.settings.channels);

        // Mark as dirty instead of immediate save
        m_indexDirty = true;

        // Apply settings
        if (m_audioEngine) {
            m_audioEngine->setMasterGainDB(static_cast<float>(m_state.settings.masterGainDb));
            m_audioEngine->setMicGainDB(static_cast<float>(m_state.settings.micGainDb));
            if (!m_state.settings.selectedCaptureDeviceId.isEmpty())
                m_audioEngine->setCaptureDevice(m_state.settings.selectedCaptureDeviceId.toStdString());
            if (!m_state.settings.selectedPlaybackDeviceId.isEmpty())
                m_audioEngine->setPlaybackDevice(m_state.settings.selectedPlaybackDeviceId.toStdString());
            if (!m_state.settings.selectedMonitorDeviceId.isEmpty())
                m_audioEngine->setMonitorPlaybackDevice(m_state.settings.selectedMonitorDeviceId.toStdString());

            m_audioEngine->setMicEnabled(m_state.settings.micEnabled);
            m_audioEngine->setMicPassthroughEnabled(m_state.settings.micPassthroughEnabled);
            m_audioEngine->setMicSoundboardBalance(m_state.settings.micSoundboardBalance);
        }

        emit settingsChanged();
        return true;
    }

    return false;
}

void SoundboardService::resetSettings()
{
    m_state.settings = AppSettings();

    // Apply audio settings to engine
    if (m_audioEngine) {
        m_audioEngine->setMasterGainDB(static_cast<float>(m_state.settings.masterGainDb));
        m_audioEngine->setMicGainDB(static_cast<float>(m_state.settings.micGainDb));

        // Note: Devices might need more complex handling if we want to reset to "System Default"
        // For now, setting them to empty so the engine uses defaults
        m_audioEngine->setPlaybackDevice("");
        m_audioEngine->setCaptureDevice("");
        m_audioEngine->setMonitorPlaybackDevice("");

        m_audioEngine->setMicEnabled(m_state.settings.micEnabled);
        m_audioEngine->setMicPassthroughEnabled(m_state.settings.micPassthroughEnabled);
        m_audioEngine->setMicSoundboardBalance(m_state.settings.micSoundboardBalance);
    }

    m_indexDirty = true; // Mark as dirty instead of immediate save
    emit settingsChanged();
}

QString SoundboardService::extractAudioArtwork(const QString& audioFilePath)
{
    if (audioFilePath.isEmpty())
        return QString();

    QFileInfo fileInfo(audioFilePath);
    if (!fileInfo.exists())
        return QString();

    // Create artwork cache directory
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/artwork_cache";
    QDir().mkpath(cacheDir);

    // Generate unique filename based on audio file path hash
    QByteArray hash = QCryptographicHash::hash(audioFilePath.toUtf8(), QCryptographicHash::Md5);
    QString artworkPath = cacheDir + "/" + hash.toHex() + ".jpg";

    // Check if already extracted
    if (QFileInfo::exists(artworkPath)) {
        return artworkPath;
    }

    // Try using ffmpeg to extract artwork
    QProcess process;
    process.setProgram("ffmpeg");
    process.setArguments({"-i", audioFilePath,
                          "-an",                                                       // No audio
                          "-vcodec", "mjpeg",                                          // Use MJPEG codec for cover art
                          "-vf", "scale=512:512:force_original_aspect_ratio=decrease", // Resize
                          "-y",                                                        // Overwrite
                          artworkPath});

    process.start();
    if (!process.waitForFinished(5000)) { // 5 second timeout
        process.kill();
        qDebug() << "FFmpeg timeout extracting artwork from:" << audioFilePath;
        return QString();
    }

    if (process.exitCode() != 0) {
        // FFmpeg failed - may not have embedded artwork
        qDebug() << "No embedded artwork found in:" << audioFilePath;
        QFile::remove(artworkPath); // Clean up any partial file
        return QString();
    }

    // Verify the file was created and has content
    QFileInfo artworkInfo(artworkPath);
    if (artworkInfo.exists() && artworkInfo.size() > 0) {
        qDebug() << "Extracted artwork to:" << artworkPath;
        return artworkPath;
    }

    return QString();
}
