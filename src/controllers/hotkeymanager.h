#pragma once

#include <QHash>
#include <QKeySequence>
#include <QObject>
#include <QVector>

class QHotkey;

class HotkeyManager : public QObject
{
    Q_OBJECT

public:
    struct HotkeyDef
    {
        QString sequence; // e.g. "Ctrl+Alt+P"
        QString actionId; // e.g. "feature.print"
        bool enabled = true;
    };

    explicit HotkeyManager(QObject* parent = nullptr);
    ~HotkeyManager();

    // Set ALL hotkeys at once (replaces existing)
    bool setHotkeys(const QVector<HotkeyDef>& defs);

    // Optional: enable/disable a specific hotkey later
    bool setHotkeyEnabled(const QString& sequence, bool enabled);

signals:
    void hotkeyTriggered(QString sequenceText, QString actionId);
    void hotkeyRegistrationFailed(QString sequenceText, QString actionId);

private:
    struct Entry
    {
        QString actionId;
        QHotkey* hotkey = nullptr;
        bool enabled = true;
    };

    QHash<QString, Entry> m_entries; // key: normalized sequence (PortableText)

    static QString normalize(const QString& sequenceText);
    static void logLine(const QString& s);

    bool registerOne(const HotkeyDef& def);
    void clearAll();
};
