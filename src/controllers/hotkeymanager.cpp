#include "hotkeyManager.h"
#include <QHotkey>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QDebug>

HotkeyManager::HotkeyManager(QObject* parent) : QObject(parent) {
    logLine("HotkeyManager created");
}

HotkeyManager::~HotkeyManager() {
    clearAll();
}

QString HotkeyManager::normalize(const QString& sequenceText) {
    QKeySequence ks(sequenceText);
    return ks.toString(QKeySequence::PortableText);
}

void HotkeyManager::logLine(const QString& s) {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);

    QFile f(dir + "/hotkey_manager.log");
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&f);
        ts << QDateTime::currentDateTime().toString(Qt::ISODate) << "  " << s << "\n";
    }
}

void HotkeyManager::clearAll() {
    // Delete all QHotkey objects (they are parented to this, but we also remove mapping)
    for (auto it = m_entries.begin(); it != m_entries.end(); ++it) {
        if (it.value().hotkey) {
            it.value().hotkey->setRegistered(false);
            it.value().hotkey->deleteLater();
            it.value().hotkey = nullptr;
        }
    }
    m_entries.clear();
    logLine("Cleared all hotkeys");
}

bool HotkeyManager::registerOne(const HotkeyManager::HotkeyDef& def) {
    const QString key = normalize(def.sequence);
    if (key.isEmpty()) {
        logLine(QString("Invalid hotkey: '%1'").arg(def.sequence));
        emit hotkeyRegistrationFailed(def.sequence, def.actionId);
        return false;
    }

    if (m_entries.contains(key)) {
        logLine(QString("Duplicate hotkey ignored: '%1' -> '%2'").arg(key, def.actionId));
        return false;
    }

    auto* hk = new QHotkey(this);
    const bool ok = hk->setShortcut(QKeySequence(def.sequence), true /*autoRegister*/);

    logLine(QString("Register '%1' (norm '%2') -> %3")
                .arg(def.sequence, key, ok ? "OK" : "FAILED"));

    if (!ok || !hk->isRegistered()) {
        hk->deleteLater();
        emit hotkeyRegistrationFailed(def.sequence, def.actionId);
        return false;
    }

    // If you want per-hotkey enable/disable:
    if (!def.enabled) {
        hk->setRegistered(false);
    }

    Entry e;
    e.actionId = def.actionId;
    e.enabled = def.enabled;
    e.hotkey = hk;
    m_entries.insert(key, e);

    connect(hk, &QHotkey::activated, this, [this, key]() {
        const auto it = m_entries.find(key);
        if (it == m_entries.end()) return;

        // It was registered, so this tells you exactly which hotkey fired:
        emit hotkeyTriggered(key, it.value().actionId);
        logLine(QString("ACTIVATED '%1' -> '%2'").arg(key, it.value().actionId));
    });

    return true;
}

bool HotkeyManager::setHotkeys(const QVector<HotkeyDef>& defs) {
    clearAll();

    bool allOk = true;
    for (const auto& d : defs) {
        allOk = registerOne(d) && allOk;
    }
    return allOk;
}

bool HotkeyManager::setHotkeyEnabled(const QString& sequence, bool enabled) {
    const QString key = normalize(sequence);
    auto it = m_entries.find(key);
    if (it == m_entries.end() || !it.value().hotkey) return false;

    it.value().enabled = enabled;
    it.value().hotkey->setRegistered(enabled);
    logLine(QString("SetEnabled '%1' -> %2").arg(key, enabled ? "true" : "false"));
    return true;
}
