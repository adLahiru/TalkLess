#include "hotkeymanager.h"
#include <QDebug>
#include <QKeySequence>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QWindow>

// Static member definitions
HotkeyManager* HotkeyManager::s_instance = nullptr;

#ifdef Q_OS_WIN
bool HotkeyManager::s_messageHookInstalled = false;
HHOOK HotkeyManager::s_messageHook = nullptr;
#endif

HotkeyManager::HotkeyManager(AudioEngine* audioEngine, QObject *parent)
    : QObject(parent)
    , m_audioEngine(audioEngine)
    , m_globalHotkeysEnabled(true)
    , m_hotkeyPollTimer(nullptr)
#ifdef Q_OS_MAC
    , m_nextHotkeyId(1)
#elif defined(Q_OS_WIN)
    , m_nextHotkeyId(1)
#endif
{
    s_instance = this;
    
    // Initialize default system hotkeys
    m_systemHotkeys["playPause"] = "Space";
    m_systemHotkeys["stopAll"] = "Ctrl+S";
    
    setupGlobalHotkeyListener();
    loadHotkeys();  // Load saved hotkeys on startup
    qDebug() << "HotkeyManager initialized with global hotkey support";
}

HotkeyManager::~HotkeyManager()
{
    teardownGlobalHotkeyListener();
    s_instance = nullptr;
}

bool HotkeyManager::registerHotkey(const QString &clipId, const QString &keySequence)
{
    if (keySequence.isEmpty()) {
        qWarning() << "Cannot register empty hotkey";
        return false;
    }
    
    // Check if hotkey is already in use
    if (m_hotkeyClips.contains(keySequence) && m_hotkeyClips[keySequence] != clipId) {
        qWarning() << "Hotkey already in use:" << keySequence;
        return false;
    }
    
    // Unregister previous hotkey for this clip if exists
    if (m_clipHotkeys.contains(clipId)) {
        QString oldHotkey = m_clipHotkeys[clipId];
        m_hotkeyClips.remove(oldHotkey);
    }
    
    // Register new hotkey
    m_clipHotkeys[clipId] = keySequence;
    m_hotkeyClips[keySequence] = clipId;
    
    // Save hotkeys to persistent storage
    saveHotkeys();
    
    // Register as system hotkey for global access
    registerAllSystemHotkeys();
    
    // Notify QML that hotkeys changed
    emit hotkeysChanged();
    
    qDebug() << "Registered hotkey:" << keySequence << "for clip:" << clipId;
    return true;
}

void HotkeyManager::unregisterHotkey(const QString &clipId)
{
    if (m_clipHotkeys.contains(clipId)) {
        QString hotkey = m_clipHotkeys[clipId];
        m_hotkeyClips.remove(hotkey);
        m_clipHotkeys.remove(clipId);
        
        // Save and update system hotkeys
        saveHotkeys();
        registerAllSystemHotkeys();
        
        // Notify QML that hotkeys changed
        emit hotkeysChanged();
        
        qDebug() << "Unregistered hotkey for clip:" << clipId;
    }
}

QString HotkeyManager::getHotkeyForClip(const QString &clipId) const
{
    return m_clipHotkeys.value(clipId, QString());
}

bool HotkeyManager::isHotkeyAvailable(const QString &keySequence) const
{
    return !m_hotkeyClips.contains(keySequence);
}

void HotkeyManager::handleKeyPress(int key, int modifiers)
{
    QString hotkeyString = createHotkeyString(key, modifiers);
    qDebug() << "handleKeyPress called with hotkeyString:" << hotkeyString;
    
    // Handle system hotkeys using configurable mappings
    if (m_systemHotkeys.contains("playPause") && hotkeyString == m_systemHotkeys["playPause"]) {
        qDebug() << "System hotkey: Play/Pause triggered";
        emit playPauseTriggered();
        return;
    } else if (m_systemHotkeys.contains("stopAll") && hotkeyString == m_systemHotkeys["stopAll"]) {
        qDebug() << "System hotkey: Stop All triggered";
        emit stopAllTriggered();
        return;
    }
    
    // Handle clip hotkeys
    if (m_hotkeyClips.contains(hotkeyString)) {
        QString clipId = m_hotkeyClips[hotkeyString];
        qDebug() << "Hotkey triggered:" << hotkeyString << "for clip:" << clipId;
        
        // Trigger the clip playback (don't bring app to front - play in background)
        emit hotkeyTriggered(clipId);
    }
}

QStringList HotkeyManager::getAllRegisteredHotkeys() const
{
    return m_hotkeyClips.keys();
}

QVariantList HotkeyManager::getClipsWithHotkeys() const
{
    QVariantList result;
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        QVariantMap item;
        item["clipId"] = it.key();
        item["hotkey"] = it.value();
        result.append(item);
    }
    return result;
}

void HotkeyManager::saveHotkeys()
{
    QSettings settings("TalkLess", "Hotkeys");
    
    // Save global hotkeys enabled state
    settings.setValue("globalHotkeysEnabled", m_globalHotkeysEnabled);
    
    settings.beginGroup("hotkeys");
    settings.remove("");  // Clear existing hotkeys
    
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    
    settings.endGroup();
    settings.sync();
    qDebug() << "Saved" << m_clipHotkeys.size() << "hotkeys to settings (globalHotkeysEnabled:" << m_globalHotkeysEnabled << ")";
}

void HotkeyManager::loadHotkeys()
{
    try {
        QSettings settings("TalkLess", "Hotkeys");
        
        // Load global hotkeys enabled state
        if (settings.contains("globalHotkeysEnabled")) {
            bool enabled = settings.value("globalHotkeysEnabled", true).toBool();
            if (m_globalHotkeysEnabled != enabled) {
                m_globalHotkeysEnabled = enabled;
                emit globalHotkeysEnabledChanged();
            }
            qDebug() << "Loaded globalHotkeysEnabled:" << m_globalHotkeysEnabled;
        }
        
        settings.beginGroup("hotkeys");
        
        QStringList clipIds = settings.childKeys();
        int successfulHotkeys = 0;
        int failedHotkeys = 0;
        
        for (const QString &clipId : clipIds) {
            try {
                QString keySequence = settings.value(clipId).toString();
                if (!keySequence.isEmpty()) {
                    m_clipHotkeys[clipId] = keySequence;
                    m_hotkeyClips[keySequence] = clipId;
                    successfulHotkeys++;
                }
            } catch (...) {
                failedHotkeys++;
                qWarning() << "HotkeyManager: Failed to load hotkey for clip:" << clipId;
                continue;
            }
        }
        
        settings.endGroup();
        qDebug() << "Loaded" << successfulHotkeys << "hotkeys from settings";
        if (failedHotkeys > 0) {
            qWarning() << "Failed to load" << failedHotkeys << "hotkeys";
        }
        
        // Load system hotkeys
        try {
            loadSystemHotkeys();
        } catch (...) {
            qWarning() << "HotkeyManager: Failed to load system hotkeys, using defaults";
        }
        
        // Register all loaded hotkeys as system hotkeys
        try {
            registerAllSystemHotkeys();
        } catch (...) {
            qWarning() << "HotkeyManager: Failed to register system hotkeys, hotkeys may not work";
        }
        
    } catch (...) {
        qWarning() << "HotkeyManager: Failed to load hotkeys, using defaults";
        // Continue with default hotkeys - don't crash the application
    }
}

void HotkeyManager::registerAllSystemHotkeys()
{
#ifdef Q_OS_MAC
    // First unregister all existing system hotkeys
    for (auto it = m_registeredHotKeyRefs.begin(); it != m_registeredHotKeyRefs.end(); ++it) {
        UnregisterEventHotKey(it.value());
    }
    m_registeredHotKeyRefs.clear();
    m_hotkeyIdToClipId.clear();
    m_nextHotkeyId = 1;
    
    // Register all current clip hotkeys as system hotkeys
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        QString clipId = it.key();
        QString keySequence = it.value();
        
        if (registerSystemHotkey(clipId, keySequence, m_nextHotkeyId)) {
            m_nextHotkeyId++;
        }
    }
    
    // Register system hotkeys as global hotkeys
    for (auto it = m_systemHotkeys.begin(); it != m_systemHotkeys.end(); ++it) {
        QString action = it.key();
        QString keySequence = it.value();
        
        // Only register non-empty system hotkeys
        if (!keySequence.isEmpty()) {
            // Use special IDs for system hotkeys (1000+ to distinguish from clip hotkeys)
            quint32 systemHotkeyId = 1000 + (action == "playPause" ? 1 : 2);
            if (registerSystemHotkey(action, keySequence, systemHotkeyId)) {
                qDebug() << "Registered system hotkey:" << action << "as" << keySequence;
            }
        }
    }
    
    qDebug() << "Registered" << m_registeredHotKeyRefs.size() << "system hotkeys (macOS)";
#elif defined(Q_OS_WIN)
    // First unregister all existing system hotkeys
    for (auto it = m_registeredHotkeys.begin(); it != m_registeredHotkeys.end(); ++it) {
        UnregisterHotKey(nullptr, it.key());
    }
    m_registeredHotkeys.clear();
    m_nextHotkeyId = 1;
    
    // Register all current clip hotkeys as system hotkeys
    int successfulClipHotkeys = 0;
    int failedClipHotkeys = 0;
    
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        try {
            QString clipId = it.key();
            QString keySequence = it.value();
            
            if (registerSystemHotkey(clipId, keySequence, m_nextHotkeyId)) {
                m_nextHotkeyId++;
                successfulClipHotkeys++;
            } else {
                failedClipHotkeys++;
                qWarning() << "Failed to register hotkey for clip:" << clipId << "with key:" << keySequence;
            }
        } catch (...) {
            failedClipHotkeys++;
            qWarning() << "Exception while registering hotkey for clip:" << it.key();
            continue;
        }
    }
    
    // Register system hotkeys as global hotkeys
    int successfulSystemHotkeys = 0;
    int failedSystemHotkeys = 0;
    
    for (auto it = m_systemHotkeys.begin(); it != m_systemHotkeys.end(); ++it) {
        try {
            QString action = it.key();
            QString keySequence = it.value();
            
            // Only register non-empty system hotkeys
            if (!keySequence.isEmpty()) {
                // Use special IDs for system hotkeys (1000+ to distinguish from clip hotkeys)
                int systemHotkeyId = 1000 + (action == "playPause" ? 1 : 2);
                if (registerSystemHotkey(action, keySequence, systemHotkeyId)) {
                    successfulSystemHotkeys++;
                    qDebug() << "Registered system hotkey:" << action << "as" << keySequence;
                } else {
                    failedSystemHotkeys++;
                    qWarning() << "Failed to register system hotkey:" << action << "with key:" << keySequence;
                }
            }
        } catch (...) {
            failedSystemHotkeys++;
            qWarning() << "Exception while registering system hotkey:" << it.key();
            continue;
        }
    }
    
    qDebug() << "Registered" << m_registeredHotkeys.size() << "system hotkeys (Windows)";
#endif
}

void HotkeyManager::setGlobalHotkeysEnabled(bool enabled)
{
    if (m_globalHotkeysEnabled != enabled) {
        m_globalHotkeysEnabled = enabled;
        if (enabled) {
            setupGlobalHotkeyListener();
            registerAllSystemHotkeys();
            qDebug() << "Global hotkeys ENABLED - hotkeys will work when app is minimized";
        } else {
            teardownGlobalHotkeyListener();
            qDebug() << "Global hotkeys DISABLED - hotkeys will NOT work when app is minimized";
        }
        
        // Save state immediately
        QSettings settings("TalkLess", "Hotkeys");
        settings.setValue("globalHotkeysEnabled", m_globalHotkeysEnabled);
        settings.sync();
        
        emit globalHotkeysEnabledChanged();
        qDebug() << "Global hotkeys enabled:" << enabled;
    }
}

void HotkeyManager::checkGlobalHotkeys()
{
    // This method can be called periodically to check for global hotkeys
    // For now, the actual hotkey handling is done via system callbacks
}

void HotkeyManager::setupGlobalHotkeyListener()
{
#ifdef Q_OS_MAC
    // Install Carbon event handler for global hotkeys
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    
    InstallApplicationEventHandler(&HotkeyManager::hotkeyCallback, 1, &eventType, this, NULL);
    qDebug() << "Global hotkey listener installed (macOS)";
#elif defined(Q_OS_WIN)
    // Install low-level keyboard hook to capture WM_HOTKEY in Qt message loop
    if (!s_messageHookInstalled) {
        s_messageHook = SetWindowsHookEx(WH_GETMESSAGE, messageHookProc, nullptr, GetCurrentThreadId());
        if (s_messageHook) {
            s_messageHookInstalled = true;
            qDebug() << "Global hotkey listener installed (Windows)";
        } else {
            qWarning() << "Failed to install Windows message hook for hotkeys";
        }
    }
#else
    qDebug() << "Global hotkey listener not available on this platform";
#endif
}

void HotkeyManager::teardownGlobalHotkeyListener()
{
#ifdef Q_OS_MAC
    // Unregister all system hotkeys
    for (auto it = m_registeredHotKeyRefs.begin(); it != m_registeredHotKeyRefs.end(); ++it) {
        UnregisterEventHotKey(it.value());
    }
    m_registeredHotKeyRefs.clear();
    qDebug() << "Global hotkey listener removed (macOS)";
#elif defined(Q_OS_WIN)
    // Unregister message hook
    if (s_messageHookInstalled && s_messageHook) {
        UnhookWindowsHookEx(s_messageHook);
        s_messageHook = nullptr;
        s_messageHookInstalled = false;
        qDebug() << "Global hotkey listener removed (Windows)";
    }
    // Unregister all system hotkeys
    for (auto it = m_registeredHotkeys.begin(); it != m_registeredHotkeys.end(); ++it) {
        UnregisterHotKey(nullptr, it.key());
    }
    m_registeredHotkeys.clear();
    qDebug() << "Unregistered" << m_registeredHotkeys.size() << "system hotkeys (Windows)";
#endif
}

#ifdef Q_OS_MAC
OSStatus HotkeyManager::hotkeyCallback(EventHandlerCallRef nextHandler, EventRef event, void *userData)
{
    Q_UNUSED(nextHandler)
    
    HotkeyManager* manager = static_cast<HotkeyManager*>(userData);
    if (!manager || !manager->m_globalHotkeysEnabled) {
        return noErr;
    }
    
    EventHotKeyID hotKeyID;
    GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hotKeyID), NULL, &hotKeyID);
    
    // Find the clip or action associated with this hotkey ID
    quint32 hotkeyId = hotKeyID.id;
    
    // Check if this is a system hotkey (ID >= 1000)
    if (hotkeyId >= 1000) {
        if (hotkeyId == 1001) {
            qDebug() << "Global system hotkey triggered: Play/Pause";
            QMetaObject::invokeMethod(manager, "playPauseTriggered", Qt::QueuedConnection);
        } else if (hotkeyId == 1002) {
            qDebug() << "Global system hotkey triggered: Stop All";
            QMetaObject::invokeMethod(manager, "stopAllTriggered", Qt::QueuedConnection);
        }
    } else if (manager->m_hotkeyIdToClipId.contains(hotkeyId)) {
        QString clipId = manager->m_hotkeyIdToClipId[hotkeyId];
        qDebug() << "Global hotkey triggered for clip:" << clipId;
        
        // Trigger the clip playback (don't bring app to front - play in background)
        QMetaObject::invokeMethod(manager, "hotkeyTriggered", Qt::QueuedConnection, Q_ARG(QString, clipId));
    }
    
    return noErr;
}

bool HotkeyManager::registerSystemHotkey(const QString &clipId, const QString &keySequence, quint32 hotkeyId)
{
    QStringList parts = keySequence.split("+");
    if (parts.isEmpty()) return false;
    
    QString keyPart = parts.last();
    quint32 keyCode = keyStringToKeyCode(keyPart);
    quint32 modifiers = modifiersFromString(keySequence);
    
    if (keyCode == 0) {
        qWarning() << "Invalid key in hotkey:" << keySequence;
        return false;
    }
    
    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'TkLs';  // TalkLess signature
    hotKeyID.id = hotkeyId;
    
    EventHotKeyRef hotKeyRef;
    OSStatus status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
    
    if (status == noErr) {
        m_registeredHotKeyRefs[hotkeyId] = hotKeyRef;
        
        // Only store clip mapping for actual clip hotkeys, not system hotkeys
        if (hotkeyId < 1000) {
            m_hotkeyIdToClipId[hotkeyId] = clipId;
        }
        
        qDebug() << "Registered system hotkey:" << keySequence << "for" << (hotkeyId >= 1000 ? "system action" : "clip") << ":" << clipId << "with ID:" << hotkeyId;
        return true;
    }
    
    qWarning() << "Failed to register system hotkey:" << keySequence;
    return false;
}

void HotkeyManager::unregisterSystemHotkey(quint32 hotkeyId)
{
    if (m_registeredHotKeyRefs.contains(hotkeyId)) {
        UnregisterEventHotKey(m_registeredHotKeyRefs[hotkeyId]);
        m_registeredHotKeyRefs.remove(hotkeyId);
        qDebug() << "Unregistered system hotkey ID:" << hotkeyId;
    }
}

quint32 HotkeyManager::keyStringToKeyCode(const QString &key) const
{
    // macOS virtual key codes - all keys in UPPERCASE for consistent lookup
    static QMap<QString, quint32> keyMap = {
        {"A", kVK_ANSI_A}, {"B", kVK_ANSI_B}, {"C", kVK_ANSI_C}, {"D", kVK_ANSI_D},
        {"E", kVK_ANSI_E}, {"F", kVK_ANSI_F}, {"G", kVK_ANSI_G}, {"H", kVK_ANSI_H},
        {"I", kVK_ANSI_I}, {"J", kVK_ANSI_J}, {"K", kVK_ANSI_K}, {"L", kVK_ANSI_L},
        {"M", kVK_ANSI_M}, {"N", kVK_ANSI_N}, {"O", kVK_ANSI_O}, {"P", kVK_ANSI_P},
        {"Q", kVK_ANSI_Q}, {"R", kVK_ANSI_R}, {"S", kVK_ANSI_S}, {"T", kVK_ANSI_T},
        {"U", kVK_ANSI_U}, {"V", kVK_ANSI_V}, {"W", kVK_ANSI_W}, {"X", kVK_ANSI_X},
        {"Y", kVK_ANSI_Y}, {"Z", kVK_ANSI_Z},
        {"0", kVK_ANSI_0}, {"1", kVK_ANSI_1}, {"2", kVK_ANSI_2}, {"3", kVK_ANSI_3},
        {"4", kVK_ANSI_4}, {"5", kVK_ANSI_5}, {"6", kVK_ANSI_6}, {"7", kVK_ANSI_7},
        {"8", kVK_ANSI_8}, {"9", kVK_ANSI_9},
        {"F1", kVK_F1}, {"F2", kVK_F2}, {"F3", kVK_F3}, {"F4", kVK_F4},
        {"F5", kVK_F5}, {"F6", kVK_F6}, {"F7", kVK_F7}, {"F8", kVK_F8},
        {"F9", kVK_F9}, {"F10", kVK_F10}, {"F11", kVK_F11}, {"F12", kVK_F12},
        {"SPACE", kVK_Space}, {"ENTER", kVK_Return}, {"RETURN", kVK_Return}, {"TAB", kVK_Tab},
        {"BACKSPACE", kVK_Delete}, {"DELETE", kVK_ForwardDelete},
        {"HOME", kVK_Home}, {"END", kVK_End}, {"PAGEUP", kVK_PageUp}, {"PAGEDOWN", kVK_PageDown},
        {"UP", kVK_UpArrow}, {"DOWN", kVK_DownArrow}, {"LEFT", kVK_LeftArrow}, {"RIGHT", kVK_RightArrow},
        {"ESC", kVK_Escape}, {"ESCAPE", kVK_Escape}
    };
    
    return keyMap.value(key.toUpper(), 0);
}

quint32 HotkeyManager::modifiersFromString(const QString &keySequence) const
{
    quint32 modifiers = 0;
    
    if (keySequence.contains("Ctrl", Qt::CaseInsensitive) || keySequence.contains("Control", Qt::CaseInsensitive))
        modifiers |= controlKey;
    if (keySequence.contains("Alt", Qt::CaseInsensitive) || keySequence.contains("Option", Qt::CaseInsensitive))
        modifiers |= optionKey;
    if (keySequence.contains("Shift", Qt::CaseInsensitive))
        modifiers |= shiftKey;
    if (keySequence.contains("Meta", Qt::CaseInsensitive) || keySequence.contains("Cmd", Qt::CaseInsensitive))
        modifiers |= cmdKey;
    
    return modifiers;
}
#endif

QString HotkeyManager::createHotkeyString(int key, int modifiers) const
{
    QStringList parts;
    
    if (modifiers & Qt::ControlModifier)
        parts << "Ctrl";
    if (modifiers & Qt::AltModifier)
        parts << "Alt";
    if (modifiers & Qt::ShiftModifier)
        parts << "Shift";
    if (modifiers & Qt::MetaModifier)
        parts << "Cmd";
    
    // Map Qt key codes to key names matching our registration format
    QString keyName;
    switch (key) {
        case Qt::Key_A: keyName = "A"; break;
        case Qt::Key_B: keyName = "B"; break;
        case Qt::Key_C: keyName = "C"; break;
        case Qt::Key_D: keyName = "D"; break;
        case Qt::Key_E: keyName = "E"; break;
        case Qt::Key_F: keyName = "F"; break;
        case Qt::Key_G: keyName = "G"; break;
        case Qt::Key_H: keyName = "H"; break;
        case Qt::Key_I: keyName = "I"; break;
        case Qt::Key_J: keyName = "J"; break;
        case Qt::Key_K: keyName = "K"; break;
        case Qt::Key_L: keyName = "L"; break;
        case Qt::Key_M: keyName = "M"; break;
        case Qt::Key_N: keyName = "N"; break;
        case Qt::Key_O: keyName = "O"; break;
        case Qt::Key_P: keyName = "P"; break;
        case Qt::Key_Q: keyName = "Q"; break;
        case Qt::Key_R: keyName = "R"; break;
        case Qt::Key_S: keyName = "S"; break;
        case Qt::Key_T: keyName = "T"; break;
        case Qt::Key_U: keyName = "U"; break;
        case Qt::Key_V: keyName = "V"; break;
        case Qt::Key_W: keyName = "W"; break;
        case Qt::Key_X: keyName = "X"; break;
        case Qt::Key_Y: keyName = "Y"; break;
        case Qt::Key_Z: keyName = "Z"; break;
        case Qt::Key_0: keyName = "0"; break;
        case Qt::Key_1: keyName = "1"; break;
        case Qt::Key_2: keyName = "2"; break;
        case Qt::Key_3: keyName = "3"; break;
        case Qt::Key_4: keyName = "4"; break;
        case Qt::Key_5: keyName = "5"; break;
        case Qt::Key_6: keyName = "6"; break;
        case Qt::Key_7: keyName = "7"; break;
        case Qt::Key_8: keyName = "8"; break;
        case Qt::Key_9: keyName = "9"; break;
        case Qt::Key_F1: keyName = "F1"; break;
        case Qt::Key_F2: keyName = "F2"; break;
        case Qt::Key_F3: keyName = "F3"; break;
        case Qt::Key_F4: keyName = "F4"; break;
        case Qt::Key_F5: keyName = "F5"; break;
        case Qt::Key_F6: keyName = "F6"; break;
        case Qt::Key_F7: keyName = "F7"; break;
        case Qt::Key_F8: keyName = "F8"; break;
        case Qt::Key_F9: keyName = "F9"; break;
        case Qt::Key_F10: keyName = "F10"; break;
        case Qt::Key_F11: keyName = "F11"; break;
        case Qt::Key_F12: keyName = "F12"; break;
        case Qt::Key_Space: keyName = "Space"; break;
        case Qt::Key_Return: keyName = "Enter"; break;
        case Qt::Key_Enter: keyName = "Enter"; break;
        case Qt::Key_Tab: keyName = "Tab"; break;
        case Qt::Key_Backspace: keyName = "Backspace"; break;
        case Qt::Key_Delete: keyName = "Delete"; break;
        case Qt::Key_Up: keyName = "Up"; break;
        case Qt::Key_Down: keyName = "Down"; break;
        case Qt::Key_Left: keyName = "Left"; break;
        case Qt::Key_Right: keyName = "Right"; break;
        default:
            keyName = QKeySequence(key).toString().toUpper();
    }
    
    if (!keyName.isEmpty())
        parts << keyName;
    
    return parts.join("+");
}

#ifdef Q_OS_WIN
LRESULT CALLBACK HotkeyManager::messageHookProc(int nCode, WPARAM wParam, LPARAM lParam)
{
    if (nCode >= 0 && wParam == PM_REMOVE) {
        MSG* msg = reinterpret_cast<MSG*>(lParam);
        if (msg->message == WM_HOTKEY && s_instance) {
            // Check if global hotkeys are enabled
            if (!s_instance->m_globalHotkeysEnabled) {
                qDebug() << "Global hotkey blocked - global hotkeys are DISABLED";
                return CallNextHookEx(s_messageHook, nCode, wParam, lParam);
            }
            
            int hotkeyId = static_cast<int>(msg->wParam);
            qDebug() << "Global hotkey received - global hotkeys are ENABLED";
            
            // Check if this is a system hotkey (ID >= 1000)
            if (hotkeyId >= 1000) {
                if (hotkeyId == 1001) {
                    qDebug() << "Global system hotkey triggered: Play/Pause";
                    QMetaObject::invokeMethod(s_instance, "playPauseTriggered", Qt::QueuedConnection);
                } else if (hotkeyId == 1002) {
                    qDebug() << "Global system hotkey triggered: Stop All";
                    QMetaObject::invokeMethod(s_instance, "stopAllTriggered", Qt::QueuedConnection);
                }
            } else if (s_instance->m_registeredHotkeys.contains(hotkeyId)) {
                QString clipId = s_instance->m_registeredHotkeys[hotkeyId];
                qDebug() << "Global hotkey triggered for clip:" << clipId;
                
                // Trigger the clip playback (don't bring app to front - play in background)
                QMetaObject::invokeMethod(s_instance, "hotkeyTriggered", Qt::QueuedConnection, Q_ARG(QString, clipId));
            }
        }
    }
    return CallNextHookEx(s_messageHook, nCode, wParam, lParam);
}

bool HotkeyManager::registerSystemHotkey(const QString &clipId, const QString &keySequence, int hotkeyId)
{
    QStringList parts = keySequence.split("+");
    if (parts.isEmpty()) return false;
    
    QString keyPart = parts.last();
    quint32 vk = keyStringToVirtualKey(keyPart);
    quint32 mods = modifiersFromString(keySequence);
    
    if (vk == 0) {
        qWarning() << "Invalid key in hotkey:" << keySequence;
        return false;
    }
    
    BOOL ok = RegisterHotKey(nullptr, hotkeyId, mods, vk);
    if (ok) {
        // Only store clip mapping for actual clip hotkeys, not system hotkeys
        if (hotkeyId < 1000) {
            m_registeredHotkeys[hotkeyId] = clipId;
        }
        
        qDebug() << "Registered system hotkey:" << keySequence << "for" << (hotkeyId >= 1000 ? "system action" : "clip") << ":" << clipId << "with ID:" << hotkeyId;
        return true;
    } else {
        DWORD err = GetLastError();
        qWarning() << "Failed to register system hotkey:" << keySequence << "error:" << err;
        return false;
    }
}

void HotkeyManager::unregisterSystemHotkey(int hotkeyId)
{
    if (m_registeredHotkeys.contains(hotkeyId)) {
        UnregisterHotKey(nullptr, hotkeyId);
        m_registeredHotkeys.remove(hotkeyId);
        qDebug() << "Unregistered system hotkey ID:" << hotkeyId;
    }
}

quint32 HotkeyManager::keyStringToVirtualKey(const QString &key) const
{
    // Windows virtual key codes - all special keys in UPPERCASE for consistent lookup
    static QMap<QString, quint32> keyMap = {
        {"A", 0x41}, {"B", 0x42}, {"C", 0x43}, {"D", 0x44},
        {"E", 0x45}, {"F", 0x46}, {"G", 0x47}, {"H", 0x48},
        {"I", 0x49}, {"J", 0x4A}, {"K", 0x4B}, {"L", 0x4C},
        {"M", 0x4D}, {"N", 0x4E}, {"O", 0x4F}, {"P", 0x50},
        {"Q", 0x51}, {"R", 0x52}, {"S", 0x53}, {"T", 0x54},
        {"U", 0x55}, {"V", 0x56}, {"W", 0x57}, {"X", 0x58},
        {"Y", 0x59}, {"Z", 0x5A},
        {"0", 0x30}, {"1", 0x31}, {"2", 0x32}, {"3", 0x33},
        {"4", 0x34}, {"5", 0x35}, {"6", 0x36}, {"7", 0x37},
        {"8", 0x38}, {"9", 0x39},
        {"F1", VK_F1}, {"F2", VK_F2}, {"F3", VK_F3}, {"F4", VK_F4},
        {"F5", VK_F5}, {"F6", VK_F6}, {"F7", VK_F7}, {"F8", VK_F8},
        {"F9", VK_F9}, {"F10", VK_F10}, {"F11", VK_F11}, {"F12", VK_F12},
        {"SPACE", VK_SPACE}, {"ENTER", VK_RETURN}, {"RETURN", VK_RETURN}, {"TAB", VK_TAB},
        {"BACKSPACE", VK_BACK}, {"DELETE", VK_DELETE},
        {"HOME", VK_HOME}, {"END", VK_END}, {"PAGEUP", VK_PRIOR}, {"PAGEDOWN", VK_NEXT},
        {"UP", VK_UP}, {"DOWN", VK_DOWN}, {"LEFT", VK_LEFT}, {"RIGHT", VK_RIGHT},
        {"ESC", VK_ESCAPE}, {"ESCAPE", VK_ESCAPE}
    };
    return keyMap.value(key.toUpper(), 0);
}

quint32 HotkeyManager::modifiersFromString(const QString &keySequence) const
{
    quint32 mods = 0;
    if (keySequence.contains("Ctrl", Qt::CaseInsensitive) || keySequence.contains("Control", Qt::CaseInsensitive))
        mods |= MOD_CONTROL;
    if (keySequence.contains("Alt", Qt::CaseInsensitive) || keySequence.contains("Option", Qt::CaseInsensitive))
        mods |= MOD_ALT;
    if (keySequence.contains("Shift", Qt::CaseInsensitive))
        mods |= MOD_SHIFT;
    if (keySequence.contains("Meta", Qt::CaseInsensitive) || keySequence.contains("Win", Qt::CaseInsensitive))
        mods |= MOD_WIN;
    return mods;
}
#endif

void HotkeyManager::setSystemHotkey(const QString &action, const QString &keySequence)
{
    qDebug() << "setSystemHotkey called with action:" << action << "keySequence:" << keySequence;
    
    // Allow empty keySequence to clear the hotkey
    if (keySequence.isEmpty()) {
        m_systemHotkeys[action] = "";
        saveSystemHotkeys();
        registerAllSystemHotkeys();
        emit systemHotkeysChanged();
        qDebug() << "Cleared system hotkey for action:" << action;
        return;
    }
    
    // Validate action
    if (action != "playPause" && action != "stopAll") {
        qWarning() << "Invalid system hotkey action:" << action;
        return;
    }
    
    // Check if hotkey conflicts with existing clip hotkeys and remove the conflicting clip hotkey
    if (m_hotkeyClips.contains(keySequence)) {
        QString conflictingClipId = m_hotkeyClips[keySequence];
        qDebug() << "System hotkey conflicts with clip hotkey:" << keySequence << "- removing clip hotkey";
        unregisterHotkey(conflictingClipId);
    }
    
    m_systemHotkeys[action] = keySequence;
    qDebug() << "Updated m_systemHotkeys[" << action << "] to:" << keySequence;
    
    saveSystemHotkeys();
    registerAllSystemHotkeys();
    
    // Emit signal to update UI
    emit systemHotkeysChanged();
    
    qDebug() << "Set system hotkey:" << action << "to" << keySequence;
}

QString HotkeyManager::getSystemHotkey(const QString &action) const
{
    return m_systemHotkeys.value(action, QString());
}

QVariantList HotkeyManager::getSystemHotkeys() const
{
    QVariantList result;
    for (auto it = m_systemHotkeys.begin(); it != m_systemHotkeys.end(); ++it) {
        QVariantMap item;
        item["action"] = it.key();
        item["displayName"] = (it.key() == "playPause") ? "Play/Pause" : "Stop All";
        item["hotkey"] = it.value();
        result.append(item);
    }
    return result;
}

void HotkeyManager::resetSystemHotkeys()
{
    m_systemHotkeys["playPause"] = "Space";
    m_systemHotkeys["stopAll"] = "Ctrl+S";
    saveSystemHotkeys();
    registerAllSystemHotkeys();
    
    // Emit signal to update UI
    emit systemHotkeysChanged();
    
    qDebug() << "Reset system hotkeys to defaults";
}

void HotkeyManager::clearAllSystemHotkeys()
{
    m_systemHotkeys["playPause"] = "";
    m_systemHotkeys["stopAll"] = "";
    saveSystemHotkeys();
    registerAllSystemHotkeys();
    
    // Emit signal to update UI
    emit systemHotkeysChanged();
    
    qDebug() << "Cleared all system hotkeys";
}

void HotkeyManager::saveSystemHotkeys()
{
    QSettings settings("TalkLess", "Hotkeys");
    settings.beginGroup("systemHotkeys");
    settings.remove("");  // Clear existing system hotkeys
    
    for (auto it = m_systemHotkeys.begin(); it != m_systemHotkeys.end(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    
    settings.endGroup();
    settings.sync();
    qDebug() << "Saved system hotkeys to settings";
}

void HotkeyManager::loadSystemHotkeys()
{
    QSettings settings("TalkLess", "Hotkeys");
    settings.beginGroup("systemHotkeys");
    
    QStringList actions = settings.childKeys();
    for (const QString &action : actions) {
        QString keySequence = settings.value(action).toString();
        if (!keySequence.isEmpty()) {
            m_systemHotkeys[action] = keySequence;
        }
    }
    
    settings.endGroup();
    qDebug() << "Loaded" << m_systemHotkeys.size() << "system hotkeys from settings";
    
    // Register system hotkeys after loading
    registerAllSystemHotkeys();
}

void HotkeyManager::bringToFront()
{
#ifdef Q_OS_WIN
    // Windows implementation
    HWND hwnd = (HWND)QGuiApplication::topLevelWindows().first()->winId();
    if (hwnd) {
        // Restore window if minimized
        if (IsIconic(hwnd)) {
            ShowWindow(hwnd, SW_RESTORE);
        }
        
        // Bring to front and set focus
        SetForegroundWindow(hwnd);
        SetActiveWindow(hwnd);
        SetFocus(hwnd);
        
        qDebug() << "Brought application to front (Windows)";
    }
#elif defined(Q_OS_MAC)
    // macOS implementation
    // This is more complex on macOS and would require AppleScript or other methods
    // For now, we'll use a simple approach
    QWindow* window = QGuiApplication::topLevelWindows().first();
    if (window) {
        window->raise();
        window->requestActivate();
        qDebug() << "Brought application to front (macOS)";
    }
#else
    // Linux/X11 implementation
    QWindow* window = QGuiApplication::topLevelWindows().first();
    if (window) {
        window->raise();
        window->requestActivate();
        window->showNormal();
        qDebug() << "Brought application to front (Linux)";
    }
#endif
}
