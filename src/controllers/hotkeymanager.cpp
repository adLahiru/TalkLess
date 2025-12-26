#include "hotkeymanager.h"
#include <QDebug>
#include <QKeySequence>
#include <QCoreApplication>

// Static instance for callback
static HotkeyManager* s_instance = nullptr;

HotkeyManager::HotkeyManager(AudioEngine* audioEngine, QObject *parent)
    : QObject(parent)
    , m_audioEngine(audioEngine)
    , m_globalHotkeysEnabled(true)
    , m_hotkeyPollTimer(nullptr)
#ifdef Q_OS_MAC
    , m_nextHotkeyId(1)
#endif
{
    s_instance = this;
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
    
    // Handle system hotkeys
    if (hotkeyString == "Space") {
        qDebug() << "System hotkey: Play/Pause";
        emit playPauseTriggered();
        return;
    } else if (hotkeyString == "Ctrl+S") {
        qDebug() << "System hotkey: Stop All";
        emit stopAllTriggered();
        return;
    }
    
    // Handle clip hotkeys
    if (m_hotkeyClips.contains(hotkeyString)) {
        QString clipId = m_hotkeyClips[hotkeyString];
        qDebug() << "Hotkey triggered:" << hotkeyString << "for clip:" << clipId;
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
    settings.beginGroup("hotkeys");
    settings.remove("");  // Clear existing hotkeys
    
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    
    settings.endGroup();
    settings.sync();
    qDebug() << "Saved" << m_clipHotkeys.size() << "hotkeys to settings";
}

void HotkeyManager::loadHotkeys()
{
    QSettings settings("TalkLess", "Hotkeys");
    settings.beginGroup("hotkeys");
    
    QStringList clipIds = settings.childKeys();
    for (const QString &clipId : clipIds) {
        QString keySequence = settings.value(clipId).toString();
        if (!keySequence.isEmpty()) {
            m_clipHotkeys[clipId] = keySequence;
            m_hotkeyClips[keySequence] = clipId;
        }
    }
    
    settings.endGroup();
    qDebug() << "Loaded" << m_clipHotkeys.size() << "hotkeys from settings";
    
    // Register all loaded hotkeys as system hotkeys
    registerAllSystemHotkeys();
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
    
    // Register all current hotkeys as system hotkeys
    for (auto it = m_clipHotkeys.begin(); it != m_clipHotkeys.end(); ++it) {
        QString clipId = it.key();
        QString keySequence = it.value();
        
        if (registerSystemHotkey(clipId, keySequence, m_nextHotkeyId)) {
            m_nextHotkeyId++;
        }
    }
    
    qDebug() << "Registered" << m_registeredHotKeyRefs.size() << "system hotkeys";
#endif
}

void HotkeyManager::setGlobalHotkeysEnabled(bool enabled)
{
    if (m_globalHotkeysEnabled != enabled) {
        m_globalHotkeysEnabled = enabled;
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
    
    // Find the clip associated with this hotkey ID using the mapping
    quint32 hotkeyId = hotKeyID.id;
    if (manager->m_hotkeyIdToClipId.contains(hotkeyId)) {
        QString clipId = manager->m_hotkeyIdToClipId[hotkeyId];
        qDebug() << "Global hotkey triggered for clip:" << clipId;
        // Emit the signal on the main thread
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
        m_hotkeyIdToClipId[hotkeyId] = clipId;  // Store the mapping
        qDebug() << "Registered system hotkey:" << keySequence << "for clip:" << clipId << "with ID:" << hotkeyId;
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
    // macOS virtual key codes
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
        {"Space", kVK_Space}, {"Enter", kVK_Return}, {"Tab", kVK_Tab},
        {"Backspace", kVK_Delete}, {"Delete", kVK_ForwardDelete},
        {"Home", kVK_Home}, {"End", kVK_End}, {"PageUp", kVK_PageUp}, {"PageDown", kVK_PageDown},
        {"Up", kVK_UpArrow}, {"Down", kVK_DownArrow}, {"Left", kVK_LeftArrow}, {"Right", kVK_RightArrow}
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
