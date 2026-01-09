#pragma once
#include <QAbstractListModel>
#include <QVector>

struct HotkeyItem {
    int id = -1;                 // used by your QML table (onPrimaryClicked passes id)
    QString title;               // "Mute microphone", "Soundboard: Airhorn"
    QString hotkey;              // "Ctrl+Alt+P"
    QString defaultHotkey;       // system only; empty for preference
    QString actionId;            // "sys.mute", "sb.airhorn", etc.
    bool isSystem = false;
    bool enabled = true;
};

class HotkeysModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        HotkeyRole,          // name: "hotkey"
        ShortcutRole,        // name: "shortcut" (alias for hotkey, for safety)
        DefaultHotkeyRole,
        ActionIdRole,
        IsSystemRole,
        EnabledRole
    };

    explicit HotkeysModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    const QVector<HotkeyItem>& items() const { return m_items; }
    void setItems(const QVector<HotkeyItem>& items);

    // Updates by id
    bool setHotkeyById(int id, const QString& hotkeyText);
    bool setEnabledById(int id, bool enabled);
    bool resetToDefaultById(int id);
    bool removeById(int id);

    HotkeyItem* findById(int id);
    const HotkeyItem* findById(int id) const;

private:
    QVector<HotkeyItem> m_items;
};
