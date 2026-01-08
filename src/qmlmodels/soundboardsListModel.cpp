#include "soundboardsListModel.h"

#include <QtGlobal>

SoundboardsListModel::SoundboardsListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

void SoundboardsListModel::setService(SoundboardService* service)
{
    if (m_service == service)
        return;

    if (m_service) {
        disconnect(m_service, nullptr, this, nullptr);
    }

    m_service = service;

    if (m_service) {
        connect(m_service, &SoundboardService::boardsChanged,
                this, &SoundboardsListModel::onBoardsChanged);

        connect(m_service, &SoundboardService::activeBoardChanged,
                this, &SoundboardsListModel::onActiveBoardChanged);

        reload();
    } else {
        beginResetModel();
        m_cache.clear();
        endResetModel();
    }
}

int SoundboardsListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_cache.size();
}

QVariant SoundboardsListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid())
        return {};

    const int row = index.row();
    if (row < 0 || row >= m_cache.size())
        return {};

    const SoundboardInfo& b = m_cache[row];

    switch (role) {
    case IdRole:        return b.id;
    case NameRole:      return b.name;
    case ClipCountRole: return b.clipCount;

    case HotkeyRole:
        // If you add b.hotkey later, compile with -DTALKLESS_BOARD_HAS_HOTKEY
        #ifdef TALKLESS_BOARD_HAS_HOTKEY
            return b.hotkey;
        #else
            return QString();
        #endif

    case ImagePathRole:
        // If you add b.imagePath later, compile with -DTALKLESS_BOARD_HAS_IMAGE
        #ifdef TALKLESS_BOARD_HAS_IMAGE
            return b.imagePath;
        #else
            return QString();
        #endif

    case IsActiveRole:
        if (!m_service) return false;
        return m_service->activeBoardId() == b.id;

    default:
        return {};
    }
}

QHash<int, QByteArray> SoundboardsListModel::roleNames() const
{
    return {
        { IdRole, "id" },
        { NameRole, "name" },
        { ClipCountRole, "clipCount" },
        { HotkeyRole, "hotkey" },
        { ImagePathRole, "imagePath" },
        { IsActiveRole, "isActive" }
    };
}

void SoundboardsListModel::reload()
{
    if (!m_service)
        return;

    beginResetModel();
    m_cache = m_service->listBoards();  // expects QVector<SoundboardInfo>
    endResetModel();
}

bool SoundboardsListModel::activateByRow(int row)
{
    if (!m_service)
        return false;
    if (row < 0 || row >= m_cache.size())
        return false;

    return m_service->activate(m_cache[row].id);
}

bool SoundboardsListModel::activateById(int boardId)
{
    if (!m_service)
        return false;
    return m_service->activate(boardId);
}

void SoundboardsListModel::onBoardsChanged()
{
    reload();
}

void SoundboardsListModel::onActiveBoardChanged()
{
    if (m_cache.isEmpty())
        return;

    // Only the IsActiveRole changes for all rows
    const QModelIndex top = index(0, 0);
    const QModelIndex bottom = index(m_cache.size() - 1, 0);
    emit dataChanged(top, bottom, { IsActiveRole });
}

int SoundboardsListModel::rowForId(int boardId) const
{
    for (int i = 0; i < m_cache.size(); ++i) {
        if (m_cache[i].id == boardId)
            return i;
    }
    return -1;
}
