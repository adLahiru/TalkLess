#pragma once
#include <QObject>
#include <QHash>
#include <QKeySequence>
#include <QSettings>

#include "qmlmodels/hotkeysModel.h"

class QHotkey;

class HotkeyManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(HotkeysModel* systemHotkeysModel READ systemHotkeysModel CONSTANT)
    Q_PROPERTY(HotkeysModel* preferenceHotkeysModel READ preferenceHotkeysModel CONSTANT)

public:
    explicit HotkeyManager(QObject* parent = nullptr);

    HotkeysModel* systemHotkeysModel() { return &m_system; }
    HotkeysModel* preferenceHotkeysModel() { return &m_pref; }

    // --- Called by your UI (same names you use in QML) ---
    Q_INVOKABLE void reassignSystem(int id);
    Q_INVOKABLE void resetSystem(int id);

    Q_INVOKABLE void reassignPreference(int id);
    Q_INVOKABLE void deletePreference(int id);

    Q_INVOKABLE void undoHotkeyChanges();
    Q_INVOKABLE void saveHotkeys();

    // --- Add preference hotkey for a soundboard (you can call this from UI) ---
    Q_INVOKABLE int addPreferenceHotkey(const QString& title, const QString& actionId);

    // --- Called by the capture popup when the user pressed a combo ---
    Q_INVOKABLE void applyCapturedHotkey(const QString& hotkeyText);
    Q_INVOKABLE void cancelCapture();

signals:
    void requestCapture(QString title);
    void showMessage(QString text);

    // Fired when a global hotkey is pressed (minimized ok)
    void actionTriggered(QString actionId);

private:
    // Models
    HotkeysModel m_system;
    HotkeysModel m_pref;

    // Undo snapshots
    QVector<HotkeyItem> m_systemOriginal;
    QVector<HotkeyItem> m_prefOriginal;

    // Global registered hotkeys: portableShortcut -> QHotkey*
    QHash<QString, QHotkey*> m_registered;

    // Capture state
    enum class CaptureTarget { None, System, Preference };
    CaptureTarget m_target = CaptureTarget::None;
    int m_targetId = -1;

    // Id generator for preference hotkeys
    int m_nextPrefId = 1000;

private:
    void loadDefaults();
    void loadUserSettings();
    void saveUserSettings();
    void snapshotForUndo();

    void clearRegistrations();
    void rebuildRegistrations();

    bool isValidHotkey(const QString& text) const;
    bool hasConflictPortable(const QString& portableKey, int ignoreId, CaptureTarget ignoreTarget, QString* conflictTitle) const;

    static QString toPortable(const QString& text);
    static QString toNative(const QString& text);
};
