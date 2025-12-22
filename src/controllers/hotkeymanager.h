#ifndef HOTKEYMANAGER_H
#define HOTKEYMANAGER_H

#include <QObject>
#include <QKeySequence>
#include <QMap>
#include <QString>

class HotkeyManager : public QObject
{
    Q_OBJECT

public:
    explicit HotkeyManager(QObject *parent = nullptr);
    
    Q_INVOKABLE bool registerHotkey(const QString &clipId, const QString &keySequence);
    Q_INVOKABLE void unregisterHotkey(const QString &clipId);
    Q_INVOKABLE QString getHotkeyForClip(const QString &clipId) const;
    Q_INVOKABLE bool isHotkeyAvailable(const QString &keySequence) const;

signals:
    void hotkeyTriggered(const QString &clipId);

public slots:
    void handleKeyPress(int key, int modifiers);

private:
    QMap<QString, QString> m_clipHotkeys;  // clipId -> hotkey
    QMap<QString, QString> m_hotkeyClips;  // hotkey -> clipId
    
    QString createHotkeyString(int key, int modifiers) const;
};

#endif // HOTKEYMANAGER_H
