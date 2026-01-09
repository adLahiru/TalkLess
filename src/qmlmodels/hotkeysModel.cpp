#include "hotkeysModel.h"

HotkeysModel::HotkeysModel(QObject* parent) : QAbstractListModel(parent) {}

int HotkeysModel::rowCount(const QModelIndex&) const {
    return m_items.size();
}

QVariant HotkeysModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const auto& it = m_items[index.row()];
    switch (role) {
        case IdRole: return it.id;
        case TitleRole: return it.title;
        case HotkeyRole: return it.hotkey;
        case ShortcutRole: return it.hotkey; // alias
        case DefaultHotkeyRole: return it.defaultHotkey;
        case ActionIdRole: return it.actionId;
        case IsSystemRole: return it.isSystem;
        case EnabledRole: return it.enabled;
        default: return {};
    }
}

QHash<int, QByteArray> HotkeysModel::roleNames() const {
    return {
        {IdRole, "id"},
        {TitleRole, "title"},
        {HotkeyRole, "hotkey"},
        {ShortcutRole, "shortcut"},
        {DefaultHotkeyRole, "defaultHotkey"},
        {ActionIdRole, "actionId"},
        {IsSystemRole, "isSystem"},
        {EnabledRole, "enabled"},
    };
}

void HotkeysModel::setItems(const QVector<HotkeyItem>& items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}

HotkeyItem* HotkeysModel::findById(int id) {
    for (auto& it : m_items)
        if (it.id == id) return &it;
    return nullptr;
}

const HotkeyItem* HotkeysModel::findById(int id) const {
    for (const auto& it : m_items)
        if (it.id == id) return &it;
    return nullptr;
}

bool HotkeysModel::setHotkeyById(int id, const QString& hotkeyText) {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == id) {
            m_items[i].hotkey = hotkeyText;
            emit dataChanged(index(i,0), index(i,0), {HotkeyRole, ShortcutRole});
            return true;
        }
    }
    return false;
}

bool HotkeysModel::setEnabledById(int id, bool enabled) {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == id) {
            m_items[i].enabled = enabled;
            emit dataChanged(index(i,0), index(i,0), {EnabledRole});
            return true;
        }
    }
    return false;
}

bool HotkeysModel::resetToDefaultById(int id) {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == id) {
            if (m_items[i].defaultHotkey.isEmpty()) return false;
            m_items[i].hotkey = m_items[i].defaultHotkey;
            emit dataChanged(index(i,0), index(i,0), {HotkeyRole, ShortcutRole});
            return true;
        }
    }
    return false;
}

bool HotkeysModel::removeById(int id) {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items[i].id == id) {
            beginRemoveRows(QModelIndex(), i, i);
            m_items.removeAt(i);
            endRemoveRows();
            return true;
        }
    }
    return false;
}
