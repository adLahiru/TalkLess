#include "hotkeymanager.h"
#include <QDebug>
#include <QKeySequence>

HotkeyManager::HotkeyManager(QObject *parent)
    : QObject(parent)
{
    qDebug() << "HotkeyManager initialized";
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
    
    qDebug() << "Registered hotkey:" << keySequence << "for clip:" << clipId;
    return true;
}

void HotkeyManager::unregisterHotkey(const QString &clipId)
{
    if (m_clipHotkeys.contains(clipId)) {
        QString hotkey = m_clipHotkeys[clipId];
        m_hotkeyClips.remove(hotkey);
        m_clipHotkeys.remove(clipId);
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
    
    if (m_hotkeyClips.contains(hotkeyString)) {
        QString clipId = m_hotkeyClips[hotkeyString];
        qDebug() << "Hotkey triggered:" << hotkeyString << "for clip:" << clipId;
        emit hotkeyTriggered(clipId);
    }
}

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
        parts << "Meta";
    
    QString keyName = QKeySequence(key).toString();
    if (!keyName.isEmpty())
        parts << keyName;
    
    return parts.join("+");
}
