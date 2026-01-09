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

    if (m_service) {
        connect(m_service, &SoundboardService::activeClipsChanged, this, &ClipsListModel::onActiveClipsChanged);
        connect(m_service, &SoundboardService::activeBoardChanged, this, &ClipsListModel::onActiveClipsChanged);

        // If no board ID is set, load the active board
        if (m_boardId < 0) {
            loadActiveBoard();
        } else {
            reload();
        }
    } else {
        beginResetModel();
        m_cache.clear();
        endResetModel();
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
    case IsPlayingRole:
        return c.isPlaying;
    case IsRepeatRole:
        return c.isRepeat;
    case LockedRole:
        return c.locked;
    case TagsRole:
        return c.tags;
    default:
        return {};
    }
}

QHash<int, QByteArray> ClipsListModel::roleNames() const
{
    return {
        {         IdRole,        "clipId"},
        {   FilePathRole,      "filePath"},
        {    ImgPathRole,       "imgPath"},
        {     HotkeyRole,        "hotkey"},
        {      TitleRole,     "clipTitle"},
        {TrimStartMsRole,   "trimStartMs"},
        {  TrimEndMsRole,     "trimEndMs"},
        {  IsPlayingRole, "clipIsPlaying"},
        {   IsRepeatRole,      "isRepeat"},
        {     LockedRole,        "locked"},
        {       TagsRole,          "tags"}
    };
}

void ClipsListModel::reload()
{
    if (!m_service)
        return;

    beginResetModel();

    if (m_boardId >= 0) {
        m_cache = m_service->getClipsForBoard(m_boardId);
    } else {
        // If no board ID specified, use active board
        m_cache = m_service->getActiveClips();
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
    // If we're showing the active board, reload
    if (m_service && m_boardId == m_service->activeBoardId()) {
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
