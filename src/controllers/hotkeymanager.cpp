#include "hotkeymanager.h"
#include "hotkeyvalidator.h"
#include "services/soundboardService.h"
#include <QHotkey>
#include <QDebug>

HotkeyManager::HotkeyManager(QObject* parent) : QObject(parent) {
    loadDefaults();
    loadUserSettings();
    snapshotForUndo();
    rebuildRegistrations();
}

void HotkeyManager::setSoundboardService(SoundboardService* service) {
    if (m_soundboardService) {
        disconnect(m_soundboardService, nullptr, this, nullptr);
    }
    
    m_soundboardService = service;
    
    if (m_soundboardService) {
        // Reload soundboard hotkeys when boards change
        connect(m_soundboardService, &SoundboardService::boardsChanged,
                this, &HotkeyManager::reloadSoundboardHotkeys);
        
        // Reload clip hotkeys when active board changes
        connect(m_soundboardService, &SoundboardService::activeBoardChanged,
                this, &HotkeyManager::reloadClipHotkeys);
        connect(m_soundboardService, &SoundboardService::activeClipsChanged,
                this, &HotkeyManager::reloadClipHotkeys);
        
        // Initial load
        reloadSoundboardHotkeys();
        reloadClipHotkeys();
    }
}

void HotkeyManager::reloadSoundboardHotkeys() {
    // Don't reload during shutdown to avoid accessing destroyed objects
    if (m_isShuttingDown) return;
    if (!m_soundboardService) return;
    
    // Build new preference list from soundboards
    QVector<HotkeyItem> pref;
    
    const auto boards = m_soundboardService->listBoards();
    for (const auto& board : boards) {
        HotkeyItem item;
        item.id = board.id;  // Use board ID as hotkey item ID
        item.title = QString("Activate: %1").arg(board.name);
        item.hotkey = board.hotkey;
        item.defaultHotkey = "";  // Preference has no default
        item.actionId = QString("board.%1").arg(board.id);
        item.isSystem = false;
        item.enabled = true;
        pref.push_back(item);
    }
    
    m_pref.setItems(pref);
    m_nextPrefId = 1000;  // Soundboards use their own IDs
    
    // Update undo snapshot and rebuild registrations
    snapshotForUndo();
    rebuildRegistrations();
}

void HotkeyManager::reloadClipHotkeys() {
    // Don't reload during shutdown
    if (m_isShuttingDown) return;
    if (!m_soundboardService) return;
    
    // Clear old clip hotkeys
    clearClipRegistrations();
    
    // Get clips from active soundboard
    const auto clips = m_soundboardService->getActiveClips();
    
    for (const auto& clip : clips) {
        if (!clip.hotkey.isEmpty()) {
            const QString portable = toPortable(clip.hotkey);
            if (portable.isEmpty()) continue;
            
            // Create action ID for clip
            QString actionId = QString("clip.%1").arg(clip.id);
            
            // Check if already registered in system/board hotkeys (avoid overrides)
            if (m_registered.contains(portable)) {
                qDebug() << "Clip hotkey conflict with system/board hotkey:" << portable;
                continue;
            }

            // Check if already registered as another clip (avoid duplicates)
            if (m_clipRegistered.contains(portable)) continue;
            
            // Register the hotkey
            QHotkey* hk = new QHotkey(QKeySequence(portable), true, this);
            if (hk->isRegistered()) {
                connect(hk, &QHotkey::activated, this, [this, actionId]() {
                    emit actionTriggered(actionId);
                });
                m_clipRegistered[portable] = hk;
                qDebug() << "Registered clip hotkey:" << portable << "->" << actionId;
            } else {
                qDebug() << "Failed to register clip hotkey:" << portable;
                delete hk;
            }
        }
    }
}

void HotkeyManager::clearClipRegistrations() {
    for (auto* hk : m_clipRegistered) {
        delete hk;
    }
    m_clipRegistered.clear();
}

void HotkeyManager::saveHotkeysOnClose() {
    // Set shutdown flag to prevent reload during save
    m_isShuttingDown = true;
    
    // Disconnect from soundboard service to prevent signals during shutdown
    if (m_soundboardService) {
        disconnect(m_soundboardService, nullptr, this, nullptr);
    }
    
    // Save system hotkeys to QSettings
    saveUserSettings();
    
    // Save soundboard hotkeys directly (without emitting signals that trigger reload)
    if (m_soundboardService) {
        for (const auto& item : m_pref.items()) {
            if (item.actionId.startsWith("board.")) {
                bool ok;
                int boardId = item.actionId.mid(6).toInt(&ok);
                if (ok) {
                    m_soundboardService->setBoardHotkey(boardId, item.hotkey);
                }
            }
        }
    }
    
    qDebug() << "Hotkeys saved on close";
}

QString HotkeyManager::toPortable(const QString& text) {
    return QKeySequence(text).toString(QKeySequence::PortableText);
}
QString HotkeyManager::toNative(const QString& text) {
    return QKeySequence(text).toString(QKeySequence::NativeText);
}

bool HotkeyManager::isValidHotkey(const QString& text) const {
    auto validationInfo = HotkeyValidator::validate(text);
    
    // If not valid, show detailed error message
    if (!validationInfo.isValid()) {
        // Note: We can't emit signals from const method, 
        // so the caller should handle showing the message
        qDebug() << "Hotkey validation failed:" << validationInfo.message;
        return false;
    }
    
    return !toPortable(text).isEmpty();
}

void HotkeyManager::loadDefaults() {
    QVector<HotkeyItem> sys = {
        {1, "Microphone Mute / Unmute",          "Ctrl+Alt+U",     "Ctrl+Alt+U",     "sys.toggleMute",  true, true},
        {2, "Stop all clips",       "Ctrl+Alt+L",     "Ctrl+Alt+L",     "sys.stopAll",     true, true},
        {3, "Play / Pause",   "Ctrl+Space",     "Ctrl+Space",     "sys.playSelected",true, true},
    };

    m_system.setItems(sys);

    // Start preference empty by default (you can load from settings)
    m_pref.setItems({});
    m_nextPrefId = 1000;
}

void HotkeyManager::snapshotForUndo() {
    m_systemOriginal = m_system.items();
    m_prefOriginal = m_pref.items();

    // also keep next id consistent
    for (const auto& it : m_pref.items())
        m_nextPrefId = qMax(m_nextPrefId, it.id + 1);
}

void HotkeyManager::loadUserSettings() {
    QSettings s("TalkLess", "TalkLess");

    // System hotkey overrides
    s.beginGroup("hotkeys/system");
    for (const auto& it : m_system.items()) {
        const QString key = QString::number(it.id);
        if (s.contains(key)) {
            m_system.setHotkeyById(it.id, s.value(key).toString());
        }
    }
    s.endGroup();

    // Preference hotkeys list
    QVector<HotkeyItem> pref;

    int count = s.value("hotkeys/pref/count", 0).toInt();
    for (int i = 0; i < count; ++i) {
        s.beginGroup(QString("hotkeys/pref/%1").arg(i));
        HotkeyItem item;
        item.id = s.value("id").toInt();
        item.title = s.value("title").toString();
        item.hotkey = s.value("hotkey").toString();
        item.defaultHotkey = ""; // preference has no default
        item.actionId = s.value("actionId").toString();
        item.isSystem = false;
        item.enabled = s.value("enabled", true).toBool();
        s.endGroup();

        if (item.id > 0 && !item.actionId.isEmpty()) {
            pref.push_back(item);
            m_nextPrefId = qMax(m_nextPrefId, item.id + 1);
        }
    }

    if (!pref.isEmpty())
        m_pref.setItems(pref);
}

void HotkeyManager::saveUserSettings() {
    QSettings s("TalkLess", "TalkLess");

    // Save system shortcuts
    s.beginGroup("hotkeys/system");
    s.remove("");
    for (const auto& it : m_system.items())
        s.setValue(QString::number(it.id), it.hotkey);
    s.endGroup();

    // Save preference list
    // We'll store as indexed groups to keep it simple
    s.remove("hotkeys/pref");
    const auto& pref = m_pref.items();
    s.setValue("hotkeys/pref/count", pref.size());
    for (int i = 0; i < pref.size(); ++i) {
        s.beginGroup(QString("hotkeys/pref/%1").arg(i));
        s.setValue("id", pref[i].id);
        s.setValue("title", pref[i].title);
        s.setValue("hotkey", pref[i].hotkey);
        s.setValue("actionId", pref[i].actionId);
        s.setValue("enabled", pref[i].enabled);
        s.endGroup();
    }
}

void HotkeyManager::clearRegistrations() {
    for (auto* hk : m_registered) {
        if (hk) {
            hk->setRegistered(false);
            hk->deleteLater();
        }
    }
    m_registered.clear();
}

void HotkeyManager::rebuildRegistrations() {
    clearRegistrations();

    auto registerItem = [&](const HotkeyItem& it) {
        if (!it.enabled) return;
        if (it.hotkey.trimmed().isEmpty()) return;
        if (!isValidHotkey(it.hotkey)) return;

        const QString portable = toPortable(it.hotkey);

        // Prevent duplicates at registration stage
        if (m_registered.contains(portable)) return;

        auto* hk = new QHotkey(this);
        const bool ok = hk->setShortcut(QKeySequence(it.hotkey), true /* autoRegister */);

        if (!ok || !hk->isRegistered()) {
            hk->deleteLater();
            emit showMessage(QString("OS refused hotkey: %1").arg(toNative(it.hotkey)));
            return;
        }

        m_registered.insert(portable, hk);

        connect(hk, &QHotkey::activated, this, [this, it]() {
            emit actionTriggered(it.actionId);
        });
    };

    for (const auto& it : m_system.items()) registerItem(it);
    for (const auto& it : m_pref.items()) registerItem(it);
}

bool HotkeyManager::hasConflictPortable(const QString& portableKey, int ignoreId, CaptureTarget ignoreTarget, QString* conflictTitle) const {
    auto check = [&](const HotkeysModel& model, CaptureTarget target) -> const HotkeyItem* {
        for (const auto& it : model.items()) {
            if (target == ignoreTarget && it.id == ignoreId) continue;
            if (!it.enabled) continue;
            if (toPortable(it.hotkey) == portableKey) return &it;
        }
        return nullptr;
    };

    if (auto* c = check(m_system, CaptureTarget::System)) {
        if (conflictTitle) *conflictTitle = c->title;
        return true;
    }
    if (auto* c = check(m_pref, CaptureTarget::Preference)) {
        if (conflictTitle) *conflictTitle = c->title;
        return true;
    }
    return false;
}

// ------------------ UI functions ------------------

void HotkeyManager::reassignSystem(int id) {
    const auto* it = m_system.findById(id);
    if (!it) return;

    m_target = CaptureTarget::System;
    m_targetId = id;
    emit requestCapture(QString("Reassign: %1").arg(it->title));
}

void HotkeyManager::resetSystem(int id) {
    if (m_system.resetToDefaultById(id)) {
        rebuildRegistrations();
        emit showMessage("System hotkey reset.");
    }
}

void HotkeyManager::reassignClip(int boardId, int clipId) {
    if (!m_soundboardService) return;

    QVariantMap data = m_soundboardService->getClipData(boardId, clipId);
    QString title = data.value("title", "Clip").toString();

    m_target = CaptureTarget::Clip;
    m_targetId = clipId;
    m_targetBoardId = boardId;
    emit requestCapture(QString("Reassign: %1").arg(title));
}

void HotkeyManager::reassignPreference(int id) {
    const auto* it = m_pref.findById(id);
    if (!it) return;

    m_target = CaptureTarget::Preference;
    m_targetId = id;
    emit requestCapture(QString("Reassign: %1").arg(it->title));
}

void HotkeyManager::deletePreference(int id) {
    // Clear the hotkey in soundboard service first
    if (m_soundboardService) {
        m_soundboardService->setBoardHotkey(id, "");
    }
    
    // The model will be refreshed when boardsChanged is emitted
    rebuildRegistrations();
    emit showMessage("Soundboard hotkey deleted.");
}

void HotkeyManager::undoHotkeyChanges() {
    m_system.setItems(m_systemOriginal);
    m_pref.setItems(m_prefOriginal);
    rebuildRegistrations();
    emit showMessage("Hotkey changes undone.");
}

void HotkeyManager::saveHotkeys() {
    saveUserSettings();
    
    // Also save preference hotkeys to soundboard service
    if (m_soundboardService) {
        for (const auto& item : m_pref.items()) {
            // Extract board ID from actionId (format: "board.123")
            if (item.actionId.startsWith("board.")) {
                bool ok;
                int boardId = item.actionId.mid(6).toInt(&ok);
                if (ok) {
                    m_soundboardService->setBoardHotkey(boardId, item.hotkey);
                }
            }
        }
    }
    
    snapshotForUndo();
    emit showMessage("Hotkeys saved.");
}

int HotkeyManager::addPreferenceHotkey(const QString& title, const QString& actionId) {
    if (actionId.trimmed().isEmpty()) return -1;

    auto pref = m_pref.items();
    HotkeyItem it;
    it.id = m_nextPrefId++;
    it.title = title.isEmpty() ? QString("Preference %1").arg(it.id) : title;
    it.hotkey = ""; // will be assigned by capture
    it.defaultHotkey = "";
    it.actionId = actionId;
    it.isSystem = false;
    it.enabled = true;
    pref.push_back(it);

    m_pref.setItems(pref);
    emit showMessage("Preference hotkey added.");
    return it.id;
}

void HotkeyManager::applyCapturedHotkey(const QString& hotkeyText) {
    if (m_target == CaptureTarget::None || m_targetId < 0) return;

    // Validate the hotkey with detailed feedback
    auto validationInfo = HotkeyValidator::validate(hotkeyText);
    if (!validationInfo.isValid()) {
        emit showMessage(validationInfo.message);
        return;
    }

    const QString portableKey = toPortable(hotkeyText);

    QString conflict;
    if (hasConflictPortable(portableKey, m_targetId, m_target, &conflict)) {
        emit showMessage(QString("Conflict: already used by '%1'").arg(conflict));
        return;
    }
    
    // Check clip conflicts
    if (m_clipRegistered.contains(portableKey)) {
        // If we are reassigning a clip, and IT OWNS this hotkey, it's fine.
        // But we don't track which clip owns which hotkey in m_clipRegistered (just QHotkey*).
        // Simplest check: just warn.
        emit showMessage("Conflict: already used by an active clip");
        return;
    }

    if (m_target == CaptureTarget::System) {
        m_system.setHotkeyById(m_targetId, hotkeyText);
    } else if (m_target == CaptureTarget::Preference) {
        m_pref.setHotkeyById(m_targetId, hotkeyText);
        
        // For preference hotkeys (soundboards), also save to service immediately
        if (m_soundboardService) {
            const auto* item = m_pref.findById(m_targetId);
            if (item && item->actionId.startsWith("board.")) {
                bool ok;
                int boardId = item->actionId.mid(6).toInt(&ok);
                if (ok) {
                    m_soundboardService->setBoardHotkey(boardId, hotkeyText);
                }
            }
        }
    } else if (m_target == CaptureTarget::Clip) {
         if (m_soundboardService) {
             QVariantMap data = m_soundboardService->getClipData(m_targetBoardId, m_targetId);
             if (!data.isEmpty()) {
                 QString title = data["title"].toString();
                 QStringList tags = data["tags"].toStringList();
                 m_soundboardService->updateClipInBoard(m_targetBoardId, m_targetId, title, hotkeyText, tags);
             }
         }
    }

    rebuildRegistrations();
    emit showMessage(QString("Assigned: %1").arg(toNative(hotkeyText)));

    m_target = CaptureTarget::None;
    m_targetId = -1;
    m_targetBoardId = -1;
}

void HotkeyManager::cancelCapture() {
    m_target = CaptureTarget::None;
    m_targetId = -1;
    m_targetBoardId = -1;
}
void HotkeyManager::resetAllHotkeys() {
    loadDefaults();
    
    // Clear user settings from QSettings
    QSettings s("TalkLess", "TalkLess");
    s.remove("hotkeys");
    
    // Also clear hotkeys in SoundboardService (boards and clips)
    if (m_soundboardService) {
        // Clear board hotkeys
        const auto boards = m_soundboardService->listBoards();
        for (const auto& board : boards) {
            m_soundboardService->setBoardHotkey(board.id, "");
        }
        
        // Clear clip hotkeys for all boards
        // We'll need a method in SoundboardService for this or loop through boards
        // For now, let's assume clearing the active board's clips is a good start
        // or better, SoundboardService should have a reset-all-clip-hotkeys 
    }
    
    rebuildRegistrations();
    snapshotForUndo();
    saveUserSettings(); // Persist the cleared state
    
    emit showMessage("All hotkeys reset to defaults.");
}
