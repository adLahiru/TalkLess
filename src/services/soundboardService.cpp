#include "soundboardService.h"

#include "audioEngine.h"

#include <QDebug>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QUrl>

#include <cmath>

SoundboardService::SoundboardService(QObject* parent) : QObject(parent), m_audioEngine(std::make_unique<AudioEngine>())
{
    // Initialize audio engine
    if (!m_audioEngine->startAudioDevice()) {
        qWarning() << "Failed to start audio device";
    }

    // 1) Load index (might not exist)
    m_state = m_repo.loadIndex();

    // 2) First launch: no boards -> create one
    if (m_state.soundboards.isEmpty()) {
        int id = m_repo.createBoard("Default"); // creates board_1.json and updates index
        m_state = m_repo.loadIndex();
        m_state.activeBoardId = id;
        m_repo.saveIndex(m_state);
    }

    // 3) Activate the last active board
    int idToActivate = m_state.activeBoardId;
    if (idToActivate < 0 && !m_state.soundboards.isEmpty())
        idToActivate = m_state.soundboards.first().id;

    if (idToActivate >= 0)
        activate(idToActivate);

    // 4) Apply saved audio settings
    if (m_audioEngine) {
        m_audioEngine->setMasterGainDB(static_cast<float>(m_state.settings.masterGainDb));
        m_audioEngine->setMicGainDB(static_cast<float>(m_state.settings.micGainDb));

        if (!m_state.settings.selectedCaptureDeviceId.isEmpty()) {
            m_audioEngine->setCaptureDevice(m_state.settings.selectedCaptureDeviceId.toStdString());
        }
        if (!m_state.settings.selectedPlaybackDeviceId.isEmpty()) {
            m_audioEngine->setPlaybackDevice(m_state.settings.selectedPlaybackDeviceId.toStdString());
        }
        if (!m_state.settings.selectedMonitorDeviceId.isEmpty()) {
            m_audioEngine->setMonitorPlaybackDevice(m_state.settings.selectedMonitorDeviceId.toStdString());
        }

        m_audioEngine->setMicEnabled(m_state.settings.micEnabled);
        m_audioEngine->setMicPassthroughEnabled(m_state.settings.micPassthroughEnabled);
        m_audioEngine->setMicSoundboardBalance(m_state.settings.micSoundboardBalance);

        qDebug() << "Applied saved audio settings - Master:" << m_state.settings.masterGainDb
                 << "dB, Mic:" << m_state.settings.micGainDb << "dB";
    }

    // 5) Setup AudioEngine callbacks
    if (m_audioEngine) {
        m_audioEngine->setClipFinishedCallback([this](int slotId) {
            // Find which clipId was in this slot
            int finishedClipId = -1;
            for (auto it = m_clipIdToSlot.begin(); it != m_clipIdToSlot.end(); ++it) {
                if (it.value() == slotId) {
                    finishedClipId = it.key();
                    break;
                }
            }

            if (finishedClipId != -1) {
                // Update state on the main thread
                QMetaObject::invokeMethod(this, [this, finishedClipId]() {
                    finalizeClipPlayback(finishedClipId);
                }, Qt::QueuedConnection);
            }
        });
    }

    // 6) Notify UI
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

void SoundboardService::reloadIndex()
{
    m_state = m_repo.loadIndex();
    emit boardsChanged();
    emit settingsChanged();
}

int SoundboardService::activeBoardId() const
{
    return m_active ? m_active->id : -1;
}

QString SoundboardService::activeBoardName() const
{
    return m_active ? m_active->name : QString();
}

void SoundboardService::setMasterGainDb(double db)
{
    m_state.settings.masterGainDb = db;
    m_repo.saveIndex(m_state);

    // Apply to audio engine
    if (m_audioEngine) {
        m_audioEngine->setMasterGainDB(static_cast<float>(db));
    }

    emit settingsChanged();
}

void SoundboardService::setMicGainDb(double db)
{
    m_state.settings.micGainDb = db;
    m_repo.saveIndex(m_state);

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
    // Save current active board before switching
    if (m_active) {
        m_repo.saveBoard(*m_active);
    }

    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    m_active = *loaded;
    rebuildHotkeyIndex();

    // Update index activeBoardId
    m_state.activeBoardId = boardId;
    m_repo.saveIndex(m_state);

    emit activeBoardChanged();
    emit activeClipsChanged();
    emit boardsChanged();
    return true;
}

bool SoundboardService::saveActive()
{
    if (!m_active)
        return false;

    const bool ok = m_repo.saveBoard(*m_active);
    if (ok) {
        // reload index because clipCount/name might update
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

QString SoundboardService::normalizeHotkey(const QString& hotkey)
{
    return hotkey.trimmed();
}

void SoundboardService::rebuildHotkeyIndex()
{
    m_hotkeyToClipId.clear();
    if (!m_active)
        return;

    for (const auto& c : m_active->clips) {
        const QString hk = normalizeHotkey(c.hotkey);
        if (!hk.isEmpty()) {
            m_hotkeyToClipId[hk] = c.id;
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
    if (!m_active)
        return nullptr;
    for (auto& c : m_active->clips) {
        if (c.id == clipId)
            return &c;
    }
    return nullptr;
}

QVector<Clip> SoundboardService::getActiveClips() const
{
    if (!m_active)
        return {};
    return m_active->clips;
}

QVector<Clip> SoundboardService::getClipsForBoard(int boardId) const
{
    // If it's the active board, return from memory
    if (m_active && m_active->id == boardId) {
        return m_active->clips;
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
    if (m_active && m_active->id == boardId) {
        for (const auto& c : m_active->clips) {
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
                    map["isPlaying"] = isClipPlaying(c.id);
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
        map["isPlaying"] = isClipPlaying(clip->id);
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

    // If adding to active board, we can batch and save once
    if (m_active && m_active->id == boardId) {
        int maxId = 0;
        for (const auto& x : m_active->clips)
            maxId = std::max(maxId, x.id);

        for (const QString& filePath : filePaths) {
            QString localPath = filePath;
            if (localPath.startsWith("file:")) {
                localPath = QUrl(localPath).toLocalFile();
            }
            if (localPath.isEmpty()) continue;

            Clip c;
            c.filePath = localPath;
            c.title = QFileInfo(localPath).baseName();
            c.id = ++maxId;
            c.isPlaying = false;
            c.locked = false;
            
            if (m_audioEngine) {
                c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
            }

            m_active->clips.push_back(c);
        }
        rebuildHotkeyIndex();
        emit activeClipsChanged();
        return saveActive();
    }

    // Inactive board: load -> modify -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return false;

    Soundboard b = *loaded;
    int maxId = 0;
    for (const auto& x : b.clips)
        maxId = std::max(maxId, x.id);

    for (const QString& filePath : filePaths) {
        QString localPath = filePath;
        if (localPath.startsWith("file:")) {
            localPath = QUrl(localPath).toLocalFile();
        }
        if (localPath.isEmpty()) continue;

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

bool SoundboardService::deleteClip(int boardId, int clipId)
{
    // if deleting from active board (in memory)
    if (m_active && m_active->id == boardId) {
        bool found = false;
        for (int i = 0; i < m_active->clips.size(); ++i) {
            if (m_active->clips[i].id == clipId) {
                if (m_active->clips[i].locked)
                    return false; // can't delete playing
                m_active->clips.removeAt(i);
                found = true;
                break;
            }
        }
        if (!found)
            return false;

        rebuildHotkeyIndex();
        emit activeClipsChanged();
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

    // if adding to active board (in memory)
    if (m_active && m_active->id == boardId) {
        Clip c = draft;

        // default title if empty
        if (c.title.trimmed().isEmpty()) {
            c.title = QFileInfo(c.filePath).baseName();
        } else {
            c.title = c.title.trimmed();
        }

        // runtime defaults
        c.isPlaying = false;
        c.locked = false;

        // generate clip id (simple)
        int maxId = 0;
        for (const auto& x : m_active->clips)
            maxId = std::max(maxId, x.id);
        c.id = maxId + 1;

        // Get duration
        if (m_audioEngine) {
            c.durationSec = m_audioEngine->getFileDuration(c.filePath.toStdString());
        }

        m_active->clips.push_back(c);
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
    if (c.title.trimmed().isEmpty())
        c.title = QFileInfo(c.filePath).baseName();
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

    b.clips.push_back(c);

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
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
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

            if (n.reproductionMode == 3) n.isRepeat = true;
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

        if (n.reproductionMode == 3) n.isRepeat = true;
        c = n;

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
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
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
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
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
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
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
    if (!m_active || m_active->id != boardId)
        return;

    for (auto& c : m_active->clips) {
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
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId)
                continue;

            c.isRepeat = repeat;

            // Apply to audio engine if clip is loaded
            if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], repeat);
            }

            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();  // Persist the change
            return;
        }
    }
}

void SoundboardService::setClipReproductionMode(int boardId, int clipId, int mode)
{
    // Clamp mode to valid range (0-4)
    mode = std::max(0, std::min(3, mode));

    // Active board update
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;

            c.reproductionMode = mode;
            
            // "When we selected loop mode it should be turn on the repeat"
            if (mode == 3) {
                c.isRepeat = true;
                // Apply immediately to audio engine if currently assigned to a slot
                if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                    m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], true);
                }
            } else {
                c.isRepeat = false;
                if (m_clipIdToSlot.contains(clipId) && m_audioEngine) {
                    m_audioEngine->setClipLoop(m_clipIdToSlot[clipId], false);
                }
            }

            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();  // Persist the change
            qDebug() << "Reproduction mode set to" << mode << "for clip" << clipId;
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.reproductionMode = mode;
            if (mode == 3) c.isRepeat = true;
            else c.isRepeat = false;
            m_repo.saveBoard(b);
            return;
        }
    }
}

void SoundboardService::setClipStopOtherSounds(int boardId, int clipId, bool stop)
{
    // Active board update
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;
            c.stopOtherSounds = stop;
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.stopOtherSounds = stop;
            m_repo.saveBoard(b);
            return;
        }
    }
}

void SoundboardService::setClipMuteOtherSounds(int boardId, int clipId, bool mute)
{
    // Active board update
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;
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
    if (!loaded) return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.muteOtherSounds = mute;
            if (mute) c.muteMicDuringPlayback = true;
            m_repo.saveBoard(b);
            return;
        }
    }
}

void SoundboardService::setClipMuteMicDuringPlayback(int boardId, int clipId, bool mute)
{
    // Active board update
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;
            c.muteMicDuringPlayback = mute;
            emit activeClipsChanged();
            emit clipUpdated(boardId, clipId);
            saveActive();
            return;
        }
    }

    // Inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.muteMicDuringPlayback = mute;
            m_repo.saveBoard(b);
            return;
        }
    }
}

void SoundboardService::setClipTrim(int boardId, int clipId, double startMs, double endMs)
{
    // Active board update
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;
            if (c.trimStartMs == startMs && c.trimEndMs == endMs) return;
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
    if (!loaded) return;
    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id == clipId) {
            c.trimStartMs = startMs;
            c.trimEndMs = endMs;
            m_repo.saveBoard(b);
            return;
        }
    }
}

bool SoundboardService::moveClip(int boardId, int fromIndex, int toIndex)
{
    // Validate indices
    if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex)
        return false;

    // Active board update
    if (m_active && m_active->id == boardId) {
        if (fromIndex >= m_active->clips.size() || toIndex >= m_active->clips.size())
            return false;

        // Move clip within the vector
        Clip clip = m_active->clips.takeAt(fromIndex);
        m_active->clips.insert(toIndex, clip);

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
        qDebug() << "Copied clip:" << clip->title;
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

    qDebug() << "Pasting clip:" << draft.title << "to board:" << boardId;
    return addClipToBoard(boardId, draft);
}

bool SoundboardService::canPaste() const
{
    return m_clipboardClip.has_value();
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

    // If renaming active board (in memory)
    if (m_active && m_active->id == boardId) {
        m_active->name = name;
        // saveActive() will call emit activeBoardChanged, emit boardsChanged, and reload index
        return saveActive();
    }

    // Otherwise load -> rename -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded)
        return false;

    Soundboard b = *loaded;
    b.name = name;

    const bool ok = m_repo.saveBoard(b); // should update index name + clipCount
    if (ok) {
        m_state = m_repo.loadIndex(); // IMPORTANT: Reload index in memory!
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::deleteBoard(int boardId)
{
    // Don't allow deleting the last board
    if (m_state.soundboards.size() <= 1)
        return false;

    // If deleting the active board, switch to another first
    if (m_active && m_active->id == boardId) {
        // Find another board to activate
        int newActiveId = -1;
        for (const auto& info : m_state.soundboards) {
            if (info.id != boardId) {
                newActiveId = info.id;
                break;
            }
        }
        if (newActiveId >= 0) {
            activate(newActiveId);
        }
        m_active.reset();
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

    qDebug() << "Clip clicked:" << clipId;

    // Emit selection changed signal so UI updates
    setCurrentlySelectedClip(clipId);

    //Now handle playback based on the clip's reproduction mode
    playClip(clipId);
}

void SoundboardService::setCurrentlySelectedClip(int clipId)
{
    emit clipSelectionRequested(clipId);
}

void SoundboardService::reproductionPlayingClip(const QVariantList &playingClipIds, int mode)
{
    if (playingClipIds.isEmpty())
        return;

    if (!m_audioEngine) {
        qWarning() << "AudioEngine not initialized";
        return;
    }

    for (const QVariant &v : playingClipIds) {
        bool ok = false;
        const int cid = v.toInt(&ok);
        if (!ok) continue;

        if (!m_clipIdToSlot.contains(cid)) continue;
        const int slotId = m_clipIdToSlot.value(cid);

        switch (mode) {
        case 0: // Overlay -> do nothing to previous clips
            break;

        case 1: // Play/Pause -> pause previous clips
            m_audioEngine->pauseClip(slotId);
            // (optional) if you have a signal for pause, emit it here
            break;

        case 2: // Play/Stop -> stop previous clips
        case 3: // Loop -> also stop previous clips
            m_audioEngine->stopClip(slotId);

            // update your UI state if you track it
            if (Clip* other = findActiveClipById(cid)) {
                other->isPlaying = false;
            }

            emit clipPlaybackStopped(cid);   // emit clipId (NOT slotId)
            break;

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

    // IMPORTANT: reproductionMode of *Clip_B* affects *previous playing clips*.
    const int mode = clip->reproductionMode; // 0=Overlay, 1=Play/Pause, 2=Play/Stop, 3=Loop

    const bool isCurrentlyPlaying = m_audioEngine->isClipPlaying(slotId);
    const bool isPaused           = m_audioEngine->isClipPaused(slotId);

    // Per-clip behavior (when user taps the same clip again)
    if (mode == 1 && isCurrentlyPlaying) {
        if (isPaused) m_audioEngine->resumeClip(slotId);
        else          m_audioEngine->pauseClip(slotId);

        emit activeClipsChanged();
        return;
    }

    if (mode == 2 && isCurrentlyPlaying && !isPaused) {
        m_audioEngine->stopClip(slotId);
        clip->isPlaying = false;
        emit activeClipsChanged();
        emit clipPlaybackStopped(clipId);
        return;
    }

    // If user taps a paused clip in Play/Stop mode: restart from beginning
    // (fall through)

    // 1) Apply Clip_B reproduction to OTHER currently playing clips
    QVariantList others = playingClipIDs();
    // Remove this clip if it appears in the "playing" list
    for (int i = others.size() - 1; i >= 0; --i) {
        bool ok = false;
        const int cid = others[i].toInt(&ok);
        if (ok && cid == clipId) {
            others.removeAt(i);
        }
    }

    if (mode == 1) {
        // Pause Clip_A, play Clip_B
        reproductionPlayingClip(others, 1);
    } else if (mode == 2) {
        // Stop Clip_A, play Clip_B
        reproductionPlayingClip(others, 2);
    } else if (mode == 3) {
        // Stop other sound, set Clip_B to loop, play Clip_B
        reproductionPlayingClip(others, 3);
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
        // Pause (mute) all other playing clips
        for (const QVariant& v : others) {
            bool ok = false;
            int otherId = v.toInt(&ok);
            if (ok && m_clipIdToSlot.contains(otherId)) {
                m_audioEngine->pauseClip(m_clipIdToSlot[otherId]);
            }
        }
    }
    
    // Mute mic if muteMicDuringPlayback is enabled for this clip
    bool wasMicEnabled = isMicEnabled();
    if (clip->muteMicDuringPlayback && wasMicEnabled) {
        if (m_audioEngine) {
            m_audioEngine->setMicEnabled(false);
            m_clipsThatMutedMic.insert(clipId);  // Track this clip muted the mic
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
    const float gainDb = (clip->volume <= 0)
        ? -60.0f
        : 20.0f * std::log10(clip->volume / 100.0f);
    m_audioEngine->setClipGain(slotId, gainDb);

    // Apply loop behavior (Mode 3 forces repeat ON)
    const bool loop = (mode == 3) ? true : clip->isRepeat;
    if (mode == 3) clip->isRepeat = true;

    m_audioEngine->setClipLoop(slotId, loop);
    m_audioEngine->setClipTrim(slotId, clip->trimStartMs, clip->trimEndMs);

    // 3) Play Clip_B
    m_audioEngine->playClip(slotId);

    clip->isPlaying = true;
    emit activeClipsChanged();
    emit clipPlaybackStarted(clipId);

    const char* modeNames[] = {"Overlay", "Play/Pause", "Play/Stop", "Loop"};
    if (mode >= 0 && mode <= 3) {
        qDebug() << "Playing clip" << clipId << "in slot" << slotId
                 << "with mode" << modeNames[mode] << ":" << clip->filePath;
    } else {
        qDebug() << "Playing clip" << clipId << "in slot" << slotId
                 << "with mode" << mode << ":" << clip->filePath;
    }
}


void SoundboardService::stopClip(int clipId)
{
    if (!m_audioEngine) {
        return;
    }

    // Check if this clip has a slot assigned
    if (!m_clipIdToSlot.contains(clipId)) {
        return;
    }

    int slotId = m_clipIdToSlot[clipId];
    m_audioEngine->stopClip(slotId);

    finalizeClipPlayback(clipId);
    qDebug() << "Stopped clip" << clipId << "in slot" << slotId;
}

void SoundboardService::finalizeClipPlayback(int clipId)
{
    // Update state
    Clip* clip = findActiveClipById(clipId);
    if (clip) {
        clip->isPlaying = false;
        emit activeClipsChanged();
    }

    // Restore mic if this clip had muted it and no other mic-muting clips are playing
    if (m_clipsThatMutedMic.contains(clipId)) {
        m_clipsThatMutedMic.remove(clipId);
        // Only restore mic if no other clips that muted the mic are still playing
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
    if (!m_audioEngine) return 0.0;
    if (!m_clipIdToSlot.contains(clipId)) return 0.0;
    
    return m_audioEngine->getClipPlaybackPositionMs(m_clipIdToSlot[clipId]);
}

QVariantList SoundboardService::playingClipIDs() const
{
    QVariantList playingIds;
    if (!m_active)
        return playingIds;

    for (const auto& clip : m_active->clips) {
        if (isClipPlaying(clip.id)) {
            playingIds.append(clip.id);
        }
    }
    return playingIds;
}


int SoundboardService::getOrAssignSlot(int clipId)
{
    // Check if clip already has a slot
    if (m_clipIdToSlot.contains(clipId)) {
        return m_clipIdToSlot[clipId];
    }

    // Assign a new slot (wrap around if we exceed MAX_CLIPS)
    int slotId = m_nextSlot % 16; // MAX_CLIPS is 16
    m_clipIdToSlot[clipId] = slotId;
    m_nextSlot++;

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
        m_repo.saveIndex(m_state);
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
        m_repo.saveIndex(m_state);
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
        m_repo.saveIndex(m_state);
        qDebug() << "Secondary output device set to:" << deviceId;
        emit settingsChanged();
    } else {
        qWarning() << "Failed to set secondary output device:" << deviceId;
    }
    return success;
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
    m_repo.saveIndex(m_state);

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
    m_repo.saveIndex(m_state);
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
    m_repo.saveIndex(m_state);
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

    // If it's the active board, update in memory too
    if (m_active && m_active->id == boardId) {
        m_active->hotkey = hotkey;
        m_repo.saveBoard(*m_active);
    } else {
        // Load, update, save the board
        auto loaded = m_repo.loadBoard(boardId);
        if (loaded) {
            loaded->hotkey = hotkey;
            m_repo.saveBoard(*loaded);
        }
    }

    // Save index
    m_repo.saveIndex(m_state);
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
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

void SoundboardService::setAccentColor(const QString& color)
{
    if (m_state.settings.accentColor == color)
        return;
    m_state.settings.accentColor = color;
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

void SoundboardService::setSlotSize(const QString& size)
{
    if (m_state.settings.slotSize == size)
        return;
    m_state.settings.slotSize = size;
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

void SoundboardService::setLanguage(const QString& lang)
{
    if (m_state.settings.language == lang)
        return;
    m_state.settings.language = lang;
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

void SoundboardService::setHotkeyMode(const QString& mode)
{
    if (m_state.settings.hotkeyMode == mode)
        return;
    m_state.settings.hotkeyMode = mode;
    m_repo.saveIndex(m_state);
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

        // Save updated state
        m_repo.saveIndex(m_state);

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
    
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}
