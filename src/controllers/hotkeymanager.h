#ifndef HOTKEYMANAGER_H
#define HOTKEYMANAGER_H

#include <QObject>
#include <QKeySequence>
#include <QMap>
#include <QString>
#include <QTimer>
#include <QSettings>
#include <QVariantList>

class AudioEngine;

#ifdef Q_OS_MAC
#include <Carbon/Carbon.h>
#endif

class HotkeyManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool globalHotkeysEnabled READ globalHotkeysEnabled WRITE setGlobalHotkeysEnabled NOTIFY globalHotkeysEnabledChanged)

public:
    explicit HotkeyManager(AudioEngine* audioEngine = nullptr, QObject *parent = nullptr);
    ~HotkeyManager();
    
    Q_INVOKABLE bool registerHotkey(const QString &clipId, const QString &keySequence);
    Q_INVOKABLE void unregisterHotkey(const QString &clipId);
    Q_INVOKABLE QString getHotkeyForClip(const QString &clipId) const;
    Q_INVOKABLE bool isHotkeyAvailable(const QString &keySequence) const;
    Q_INVOKABLE QStringList getAllRegisteredHotkeys() const;
    Q_INVOKABLE QVariantList getClipsWithHotkeys() const;
    Q_INVOKABLE void saveHotkeys();
    Q_INVOKABLE void loadHotkeys();
    
    bool globalHotkeysEnabled() const { return m_globalHotkeysEnabled; }
    void setGlobalHotkeysEnabled(bool enabled);

signals:
    void hotkeyTriggered(const QString &clipId);
    void globalHotkeysEnabledChanged();
    void hotkeysChanged();
    void playPauseTriggered();
    void stopAllTriggered();

public slots:
    void handleKeyPress(int key, int modifiers);
    void checkGlobalHotkeys();

private:
    AudioEngine* m_audioEngine;
    QMap<QString, QString> m_clipHotkeys;  // clipId -> hotkey
    QMap<QString, QString> m_hotkeyClips;  // hotkey -> clipId
    bool m_globalHotkeysEnabled;
    QTimer* m_hotkeyPollTimer;
    
    QString createHotkeyString(int key, int modifiers) const;
    void setupGlobalHotkeyListener();
    void teardownGlobalHotkeyListener();
    void registerAllSystemHotkeys();
    
#ifdef Q_OS_MAC
    static OSStatus hotkeyCallback(EventHandlerCallRef nextHandler, EventRef event, void *userData);
    QMap<quint32, EventHotKeyRef> m_registeredHotKeyRefs;
    QMap<quint32, QString> m_hotkeyIdToClipId;  // hotkeyId -> clipId mapping
    quint32 m_nextHotkeyId;
    bool registerSystemHotkey(const QString &clipId, const QString &keySequence, quint32 hotkeyId);
    void unregisterSystemHotkey(quint32 hotkeyId);
    quint32 keyStringToKeyCode(const QString &key) const;
    quint32 modifiersFromString(const QString &keySequence) const;
#endif
};

#endif // HOTKEYMANAGER_H
