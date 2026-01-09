#include "hotkeyManager.h"
#include <QHotkey>
#include <QDebug>

HotkeyManager::HotkeyManager(QObject* parent) : QObject(parent) {
    loadDefaults();
    loadUserSettings();
    snapshotForUndo();
    rebuildRegistrations();
}

QString HotkeyManager::toPortable(const QString& text) {
    return QKeySequence(text).toString(QKeySequence::PortableText);
}
QString HotkeyManager::toNative(const QString& text) {
    return QKeySequence(text).toString(QKeySequence::NativeText);
}

bool HotkeyManager::isValidHotkey(const QString& text) const {
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

void HotkeyManager::reassignPreference(int id) {
    const auto* it = m_pref.findById(id);
    if (!it) return;

    m_target = CaptureTarget::Preference;
    m_targetId = id;
    emit requestCapture(QString("Reassign: %1").arg(it->title));
}

void HotkeyManager::deletePreference(int id) {
    if (m_pref.removeById(id)) {
        rebuildRegistrations();
        emit showMessage("Preference hotkey deleted.");
    }
}

void HotkeyManager::undoHotkeyChanges() {
    m_system.setItems(m_systemOriginal);
    m_pref.setItems(m_prefOriginal);
    rebuildRegistrations();
    emit showMessage("Hotkey changes undone.");
}

void HotkeyManager::saveHotkeys() {
    saveUserSettings();
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

    if (!isValidHotkey(hotkeyText)) {
        emit showMessage("Invalid hotkey.");
        return;
    }

    const QString portableKey = toPortable(hotkeyText);

    QString conflict;
    if (hasConflictPortable(portableKey, m_targetId, m_target, &conflict)) {
        emit showMessage(QString("Conflict: already used by '%1'").arg(conflict));
        return;
    }

    if (m_target == CaptureTarget::System) {
        m_system.setHotkeyById(m_targetId, hotkeyText);
    } else {
        m_pref.setHotkeyById(m_targetId, hotkeyText);
    }

    rebuildRegistrations();
    emit showMessage(QString("Assigned: %1").arg(toNative(hotkeyText)));

    m_target = CaptureTarget::None;
    m_targetId = -1;
}

void HotkeyManager::cancelCapture() {
    m_target = CaptureTarget::None;
    m_targetId = -1;
}
