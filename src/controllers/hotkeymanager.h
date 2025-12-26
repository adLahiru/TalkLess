#ifndef HOTKEYMANAGER_H
#define HOTKEYMANAGER_H

#include <QObject>
#include <QKeySequence>
#include <QMap>
#include <QString>
#include <QTimer>
#include <QSettings>
#include <QVariantList>
#include <QWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

class AudioEngine;

#ifdef Q_OS_MAC
#include <Carbon/Carbon.h>
#elif defined(Q_OS_WIN)
#include <windows.h>
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
    Q_INVOKABLE void setSystemHotkey(const QString &action, const QString &keySequence);
    Q_INVOKABLE QString getSystemHotkey(const QString &action) const;
    Q_INVOKABLE QVariantList getSystemHotkeys() const;
    Q_INVOKABLE void resetSystemHotkeys();
    Q_INVOKABLE void clearAllSystemHotkeys();
    Q_INVOKABLE void bringToFront();
    
    bool globalHotkeysEnabled() const { return m_globalHotkeysEnabled; }
    void setGlobalHotkeysEnabled(bool enabled);

signals:
    void hotkeyTriggered(const QString &clipId);
    void globalHotkeysEnabledChanged();
    void hotkeysChanged();
    void systemHotkeysChanged();
    void playPauseTriggered();
    void stopAllTriggered();

public slots:
    void handleKeyPress(int key, int modifiers);
    void checkGlobalHotkeys();

private:
    AudioEngine* m_audioEngine;
    QMap<QString, QString> m_clipHotkeys;  // clipId -> hotkey
    QMap<QString, QString> m_hotkeyClips;  // hotkey -> clipId
    QMap<QString, QString> m_systemHotkeys; // action -> hotkey
    bool m_globalHotkeysEnabled;
    QTimer* m_hotkeyPollTimer;
    
    QString createHotkeyString(int key, int modifiers) const;
    void setupGlobalHotkeyListener();
    void teardownGlobalHotkeyListener();
    void registerAllSystemHotkeys();
    void saveSystemHotkeys();
    void loadSystemHotkeys();
    
#ifdef Q_OS_MAC
    static OSStatus hotkeyCallback(EventHandlerCallRef nextHandler, EventRef event, void *userData);
    QMap<quint32, EventHotKeyRef> m_registeredHotKeyRefs;
    QMap<quint32, QString> m_hotkeyIdToClipId;  // hotkeyId -> clipId mapping
    quint32 m_nextHotkeyId;
    bool registerSystemHotkey(const QString &clipId, const QString &keySequence, quint32 hotkeyId);
    void unregisterSystemHotkey(quint32 hotkeyId);
    quint32 keyStringToKeyCode(const QString &key) const;
    quint32 modifiersFromString(const QString &keySequence) const;
#elif defined(Q_OS_WIN)
    QMap<int, QString> m_registeredHotkeys; // hotkeyId -> clipId
    int m_nextHotkeyId;
    bool registerSystemHotkey(const QString &clipId, const QString &keySequence, int hotkeyId);
    void unregisterSystemHotkey(int hotkeyId);
    quint32 keyStringToVirtualKey(const QString &key) const;
    quint32 modifiersFromString(const QString &keySequence) const;
    static bool s_messageHookInstalled;
    static HHOOK s_messageHook;
    static HotkeyManager* s_instance;
    static LRESULT CALLBACK messageHookProc(int nCode, WPARAM wParam, LPARAM lParam);
#endif
};

#endif // HOTKEYMANAGER_H
