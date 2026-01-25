#include "clipsListModel.h"

#include <QUrl>

ClipsListModel::ClipsListModel(QObject* parent) : QAbstractListModel(parent) {}

void ClipsListModel::setService(SoundboardService* service)
{
    if (m_service == service)
        return;

    if (m_service) {
        disconnect(m_service, nullptr, this, nullptr);
    }

    m_service = service;
    emit serviceChanged();

    if (m_service) {
        connect(m_service, &SoundboardService::activeClipsChanged, this, &ClipsListModel::onActiveClipsChanged);
        connect(m_service, &SoundboardService::activeBoardChanged, this, &ClipsListModel::onActiveClipsChanged);

        // If no board ID is set, load the active board
        if (m_boardId < 0 && m_autoLoadActive) {
            loadActiveBoard();
        } else {
            // Even if we don't load active board, we might need to clear or reload specific board
            reload();
        }
    } else {
        beginResetModel();
        m_cache.clear();
        endResetModel();
    }
}

void ClipsListModel::setAutoLoadActive(bool active)
{
    if (m_autoLoadActive == active)
        return;

    m_autoLoadActive = active;
    emit autoLoadActiveChanged();

    // Reload to apply the new auto-load state (loads active if true, clears if false)
    if (m_boardId < 0 && m_service) {
        reload();
    }
}

void ClipsListModel::setBoardId(int id)
{
    if (m_boardId == id)
        return;

    m_boardId = id;
    emit boardIdChanged();
    emit boardNameChanged();
    reload();
}

QString ClipsListModel::boardName() const
{
    if (!m_service || m_boardId < 0)
        return QString();
    return m_service->getBoardName(m_boardId);
}

int ClipsListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_cache.size();
}

QVariant ClipsListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid())
        return {};

    const int row = index.row();
    if (row < 0 || row >= m_cache.size())
        return {};

    const Clip& c = m_cache[row];

    switch (role) {
    case IdRole:
        return c.id;
    case FilePathRole:
        return c.filePath;
    case ImgPathRole:
        return c.imgPath;
    case HotkeyRole:
        return c.hotkey;
    case TitleRole:
        return c.title;
    case TrimStartMsRole:
        return c.trimStartMs;
    case TrimEndMsRole:
        return c.trimEndMs;
    case VolumeRole:
        return c.volume;
    case SpeedRole:
        return c.speed;
    case IsPlayingRole:
        return c.isPlaying;
    case IsRepeatRole:
        return c.isRepeat;
    case LockedRole:
        return c.locked;
    case TagsRole:
        return c.tags;
    case ReproductionModeRole:
        return c.reproductionMode;
    case StopOtherSoundsRole:
        return c.stopOtherSounds;
    case MuteOtherSoundsRole:
        return c.muteOtherSounds;
    case MuteMicDuringPlaybackRole:
        return c.muteMicDuringPlayback;
    case DurationSecRole:
        return c.durationSec;
    case TeleprompterTextRole:
        return c.teleprompterText;
    default:
        return {};
    }
}

QHash<int, QByteArray> ClipsListModel::roleNames() const
{
    return {
        {                   IdRole,                "clipId"},
        {             FilePathRole,              "filePath"},
        {              ImgPathRole,               "imgPath"},
        {               HotkeyRole,                "hotkey"},
        {                TitleRole,             "clipTitle"},
        {          TrimStartMsRole,           "trimStartMs"},
        {            TrimEndMsRole,             "trimEndMs"},
        {               VolumeRole,            "clipVolume"},
        {                SpeedRole,             "clipSpeed"},
        {            IsPlayingRole,         "clipIsPlaying"},
        {             IsRepeatRole,              "isRepeat"},
        {               LockedRole,                "locked"},
        {                 TagsRole,                  "tags"},
        {     ReproductionModeRole,      "reproductionMode"},
        {      StopOtherSoundsRole,       "stopOtherSounds"},
        {      MuteOtherSoundsRole,       "muteOtherSounds"},
        {MuteMicDuringPlaybackRole, "muteMicDuringPlayback"},
        {          DurationSecRole,           "durationSec"},
        {     TeleprompterTextRole,      "teleprompterText"}
    };
}

void ClipsListModel::reload()
{
    if (!m_service)
        return;

    beginResetModel();

    if (m_boardId >= 0) {
        m_cache = m_service->getClipsForBoard(m_boardId);
    } else if (m_autoLoadActive) {
        // If no board ID specified and auto-load is on, use active board
        m_cache = m_service->getActiveClips();
    } else {
        // Otherwise clear
        m_cache.clear();
    }

    endResetModel();
    emit clipsChanged();
}

void ClipsListModel::loadActiveBoard()
{
    if (!m_service)
        return;

    int activeId = m_service->activeBoardId();
    if (activeId >= 0) {
        m_boardId = activeId;
        emit boardIdChanged();
    }

    reload();
}

void ClipsListModel::onActiveClipsChanged()
{
    // Reload if we're showing any active board (since playback state may have changed)
    if (m_service && m_boardId >= 0 && m_service->isBoardActive(m_boardId)) {
        reload();
    }
}

bool ClipsListModel::updateClip(int clipId, const QString& title, const QString& hotkey, const QStringList& tags)
{
    if (!m_service || m_boardId < 0)
        return false;

    bool success = m_service->updateClipInBoard(m_boardId, clipId, title, hotkey, tags);
    if (success) {
        // Update cache
        for (auto& c : m_cache) {
            if (c.id == clipId) {
                c.title = title;
                c.hotkey = hotkey;
                c.tags = tags;
                break;
            }
        }
        emit clipsChanged();
    }
    return success;
}

bool ClipsListModel::updateClipImage(int clipId, const QString& imagePath)
{
    if (!m_service || m_boardId < 0)
        return false;

    bool success = m_service->updateClipImage(m_boardId, clipId, imagePath);
    if (success) {
        // Update cache and emit dataChanged for the specific row
        for (int i = 0; i < m_cache.size(); ++i) {
            if (m_cache[i].id == clipId) {
                // Convert file:// URL to local path for storage consistency
                QString localPath = imagePath;
                if (localPath.startsWith("file:")) {
                    localPath = QUrl(localPath).toLocalFile();
                }
                m_cache[i].imgPath = localPath;

                // Emit dataChanged for the specific row and role
                QModelIndex idx = index(i, 0);
                emit dataChanged(idx, idx, {ImgPathRole});
                break;
            }
        }
        emit clipsChanged();
    }
    return success;
}

bool ClipsListModel::updateClipAudioSettings(int clipId, int volume, double speed)
{
    if (!m_service || m_boardId < 0)
        return false;

    bool success = m_service->updateClipAudioSettings(m_boardId, clipId, volume, speed);
    if (success) {
        // Update cache and emit dataChanged for the specific row
        for (int i = 0; i < m_cache.size(); ++i) {
            if (m_cache[i].id == clipId) {
                m_cache[i].volume = volume;
                m_cache[i].speed = speed;

                // Emit dataChanged for the specific row and roles
                QModelIndex idx = index(i, 0);
                emit dataChanged(idx, idx, {VolumeRole, SpeedRole});
                break;
            }
        }
    }
    return success;
}

void ClipsListModel::setClipVolume(int clipId, int volume)
{
    if (!m_service || m_boardId < 0)
        return;

    m_service->setClipVolume(m_boardId, clipId, volume);

    // Update cache
    for (int i = 0; i < m_cache.size(); ++i) {
        if (m_cache[i].id == clipId) {
            m_cache[i].volume = volume;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, {VolumeRole});
            break;
        }
    }
}

void ClipsListModel::setClipRepeat(int clipId, bool repeat)
{
    if (!m_service || m_boardId < 0)
        return;

    m_service->setClipRepeat(m_boardId, clipId, repeat);

    // Update cache
    for (int i = 0; i < m_cache.size(); ++i) {
        if (m_cache[i].id == clipId) {
            m_cache[i].isRepeat = repeat;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, {IsRepeatRole});
            break;
        }
    }
}
