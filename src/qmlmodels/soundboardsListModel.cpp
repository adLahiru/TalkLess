#include "soundboardsListModel.h"

#include <QtGlobal>

SoundboardsListModel::SoundboardsListModel(QObject* parent) : QAbstractListModel(parent) {}

void SoundboardsListModel::setService(SoundboardService* service)
{
    if (m_service == service)
        return;

    if (m_service) {
        disconnect(m_service, nullptr, this, nullptr);
    }

    m_service = service;

    if (m_service) {
        connect(m_service, &SoundboardService::boardsChanged, this, &SoundboardsListModel::onBoardsChanged);

        connect(m_service, &SoundboardService::activeBoardChanged, this, &SoundboardsListModel::onActiveBoardChanged);

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
    case IdRole:
        return b.id;
    case NameRole:
        return b.name;
    case ClipCountRole:
        return b.clipCount;

    case HotkeyRole:
        return b.hotkey;

    case ImagePathRole:
        return b.artwork;

    case IsActiveRole:
        if (!m_service)
            return false;
        return m_service->isBoardActive(b.id);

    default:
        return {};
    }
}

QHash<int, QByteArray> SoundboardsListModel::roleNames() const
{
    return {
        {       IdRole,        "id"},
        {     NameRole,      "name"},
        {ClipCountRole, "clipCount"},
        {   HotkeyRole,    "hotkey"},
        {ImagePathRole, "imagePath"},
        { IsActiveRole,  "isActive"}
    };
}

void SoundboardsListModel::reload()
{
    if (!m_service)
        return;

    beginResetModel();
    m_cache = m_service->listBoards(); // expects QVector<SoundboardInfo>
    endResetModel();
}

void SoundboardsListModel::updateFromService()
{
    if (!m_service)
        return;

    const QVector<SoundboardInfo> newData = m_service->listBoards();
    
    // Build lookup maps for efficient comparison
    QHash<int, int> oldIdToRow;
    for (int i = 0; i < m_cache.size(); ++i) {
        oldIdToRow[m_cache[i].id] = i;
    }
    
    QHash<int, int> newIdToRow;
    for (int i = 0; i < newData.size(); ++i) {
        newIdToRow[newData[i].id] = i;
    }
    
    // Find removed items (in old but not in new) - process from end to avoid index shifting
    QVector<int> removedRows;
    for (int i = 0; i < m_cache.size(); ++i) {
        if (!newIdToRow.contains(m_cache[i].id)) {
            removedRows.append(i);
        }
    }
    // Remove from end to beginning
    for (int i = removedRows.size() - 1; i >= 0; --i) {
        int row = removedRows[i];
        beginRemoveRows(QModelIndex(), row, row);
        m_cache.removeAt(row);
        endRemoveRows();
    }
    
    // Rebuild oldIdToRow after removals
    oldIdToRow.clear();
    for (int i = 0; i < m_cache.size(); ++i) {
        oldIdToRow[m_cache[i].id] = i;
    }
    
    // Find added items (in new but not in old) and insert at correct position
    for (int newRow = 0; newRow < newData.size(); ++newRow) {
        const SoundboardInfo& info = newData[newRow];
        if (!oldIdToRow.contains(info.id)) {
            // Insert at the target row
            int insertAt = qMin(newRow, m_cache.size());
            beginInsertRows(QModelIndex(), insertAt, insertAt);
            m_cache.insert(insertAt, info);
            endInsertRows();
            
            // Update oldIdToRow for subsequent insertions
            oldIdToRow.clear();
            for (int i = 0; i < m_cache.size(); ++i) {
                oldIdToRow[m_cache[i].id] = i;
            }
        }
    }
    
    // Update existing items that may have changed (name, artwork, etc.)
    for (int newRow = 0; newRow < newData.size(); ++newRow) {
        const SoundboardInfo& newInfo = newData[newRow];
        if (oldIdToRow.contains(newInfo.id)) {
            int oldRow = oldIdToRow[newInfo.id];
            const SoundboardInfo& oldInfo = m_cache[oldRow];
            
            // Check if any data changed
            if (oldInfo.name != newInfo.name || 
                oldInfo.artwork != newInfo.artwork ||
                oldInfo.clipCount != newInfo.clipCount ||
                oldInfo.hotkey != newInfo.hotkey) {
                m_cache[oldRow] = newInfo;
                const QModelIndex idx = index(oldRow, 0);
                emit dataChanged(idx, idx, {NameRole, ImagePathRole, ClipCountRole, HotkeyRole});
            }
        }
    }
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

bool SoundboardsListModel::toggleActiveById(int boardId)
{
    if (!m_service)
        return false;
    return m_service->toggleBoardActive(boardId);
}

void SoundboardsListModel::onBoardsChanged()
{
    // Use incremental update instead of full reload for better performance
    updateFromService();
}

void SoundboardsListModel::onActiveBoardChanged()
{
    if (m_cache.isEmpty())
        return;

    // Only the IsActiveRole changes for all rows
    const QModelIndex top = index(0, 0);
    const QModelIndex bottom = index(m_cache.size() - 1, 0);
    emit dataChanged(top, bottom, {IsActiveRole});
}

int SoundboardsListModel::rowForId(int boardId) const
{
    for (int i = 0; i < m_cache.size(); ++i) {
        if (m_cache[i].id == boardId)
            return i;
    }
    return -1;
}

int SoundboardsListModel::getIdAt(int row) const
{
    if (row < 0 || row >= m_cache.size())
        return -1;
    return m_cache[row].id;
}
