#pragma once
#include <QHash>
#include <QKeySequence>
#include <QObject>
#include <QSettings>
#include <QPointer>

#include "qmlmodels/hotkeysModel.h"

class QHotkey;
class SoundboardService;

class HotkeyManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(HotkeysModel* systemHotkeysModel READ systemHotkeysModel CONSTANT)
    Q_PROPERTY(HotkeysModel* preferenceHotkeysModel READ preferenceHotkeysModel CONSTANT)

public:
    struct HotkeyDef
    {
        QString sequence; // e.g. "Ctrl+Alt+P"
        QString actionId; // e.g. "feature.print"
        bool enabled = true;
    };

    explicit HotkeyManager(QObject* parent = nullptr);

    HotkeysModel* systemHotkeysModel() { return &m_system; }
    HotkeysModel* preferenceHotkeysModel() { return &m_pref; }

    // --- Connect to SoundboardService to sync soundboard hotkeys ---
    void setSoundboardService(SoundboardService* service);

    // --- Called by your UI (same names you use in QML) ---
    Q_INVOKABLE void reassignSystem(int id);
    Q_INVOKABLE void resetSystem(int id);

    Q_INVOKABLE void reassignPreference(int id);
    Q_INVOKABLE void deletePreference(int id);

    Q_INVOKABLE void undoHotkeyChanges();
    Q_INVOKABLE void saveHotkeys();
    Q_INVOKABLE void resetAllHotkeys();

    // --- Add preference hotkey for a soundboard (you can call this from UI) ---
    Q_INVOKABLE int addPreferenceHotkey(const QString& title, const QString& actionId);

    // --- Called by the capture popup when the user pressed a combo ---
    Q_INVOKABLE void applyCapturedHotkey(const QString& hotkeyText);
    Q_INVOKABLE void cancelCapture();
    
    // --- Reload soundboard hotkeys from service ---
    Q_INVOKABLE void reloadSoundboardHotkeys();
    
    // --- Called when app is closing (saves without triggering reload) ---
    void saveHotkeysOnClose();

    Q_INVOKABLE void showMessage(const QString& text) { emit showMessageSignal(text); }

signals:
    void requestCapture(QString title);
    void showMessageSignal(QString text);

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
    
    // Clip hotkeys (separate from system/preference)
    QHash<QString, QHotkey*> m_clipRegistered;

    // Capture state
    enum class CaptureTarget { None, System, Preference };
    CaptureTarget m_target = CaptureTarget::None;
    int m_targetId = -1;

    // Id generator for preference hotkeys
    int m_nextPrefId = 1000;
    
    // Soundboard service reference
    QPointer<SoundboardService> m_soundboardService;
    
    // Shutdown flag to prevent reload during close
    bool m_isShuttingDown = false;

private:
    void loadDefaults();
    void loadUserSettings();
    void saveUserSettings();
    void snapshotForUndo();

    void clearRegistrations();
    void rebuildRegistrations();
    
    // Clip hotkey registration
    void reloadClipHotkeys();
    void clearClipRegistrations();

    bool isValidHotkey(const QString& text) const;
    bool hasConflictPortable(const QString& portableKey, int ignoreId, CaptureTarget ignoreTarget, QString* conflictTitle) const;

    static QString toPortable(const QString& text);
    static QString toNative(const QString& text);
};

