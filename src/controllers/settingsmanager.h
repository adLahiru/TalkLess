#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>

class AudioManager;
class HotkeyManager;
class SoundboardView;

class SettingsManager : public QObject
{
    Q_OBJECT
    
    // UI Display Settings
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(qreal interfaceScale READ interfaceScale WRITE setInterfaceScale NOTIFY interfaceScaleChanged)
    Q_PROPERTY(bool uiAnimationsEnabled READ uiAnimationsEnabled WRITE setUiAnimationsEnabled NOTIFY uiAnimationsEnabledChanged)
    Q_PROPERTY(bool systemThemeEnabled READ systemThemeEnabled WRITE setSystemThemeEnabled NOTIFY systemThemeEnabledChanged)
    Q_PROPERTY(bool compactMode READ compactMode WRITE setCompactMode NOTIFY compactModeChanged)
    Q_PROPERTY(bool showTooltips READ showTooltips WRITE setShowTooltips NOTIFY showTooltipsChanged)
    Q_PROPERTY(bool hardwareAcceleration READ hardwareAcceleration WRITE setHardwareAcceleration NOTIFY hardwareAccelerationChanged)
    
    // Feature Settings
    Q_PROPERTY(bool equalizerEnabled READ equalizerEnabled WRITE setEqualizerEnabled NOTIFY equalizerEnabledChanged)
    Q_PROPERTY(bool macrosEnabled READ macrosEnabled WRITE setMacrosEnabled NOTIFY macrosEnabledChanged)
    Q_PROPERTY(bool apiAccessEnabled READ apiAccessEnabled WRITE setApiAccessEnabled NOTIFY apiAccessEnabledChanged)
    Q_PROPERTY(bool smartSuggestionsEnabled READ smartSuggestionsEnabled WRITE setSmartSuggestionsEnabled NOTIFY smartSuggestionsEnabledChanged)
    
    // Update Settings
    Q_PROPERTY(bool autoUpdateEnabled READ autoUpdateEnabled WRITE setAutoUpdateEnabled NOTIFY autoUpdateEnabledChanged)
    
    // Audio Settings (additional)
    Q_PROPERTY(QString audioDriver READ audioDriver WRITE setAudioDriver NOTIFY audioDriverChanged)
    Q_PROPERTY(QString sampleRate READ sampleRate WRITE setSampleRate NOTIFY sampleRateChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);
    
    // Auto save/load for application lifecycle
    Q_INVOKABLE void saveAllSettings();
    Q_INVOKABLE void loadAllSettings();
    Q_INVOKABLE QString getSettingsFilePath() const;
    
    // Export/Import functions (for manual backup)
    Q_INVOKABLE bool exportSettingsToJson(const QString &filePath);
    Q_INVOKABLE bool importSettingsFromJson(const QString &filePath);
    
    // Set managers to export/import from
    void setAudioManager(AudioManager *audioManager);
    void setHotkeyManager(HotkeyManager *hotkeyManager);
    void setSoundboardView(SoundboardView *soundboardView);
    
    // Utility functions
    QString getDefaultExportPath() const;
    bool validateJsonFile(const QString &filePath) const;
    
    // UI Display Settings getters/setters
    QString theme() const { return m_theme; }
    void setTheme(const QString &theme);
    
    qreal interfaceScale() const { return m_interfaceScale; }
    void setInterfaceScale(qreal scale);
    
    bool uiAnimationsEnabled() const { return m_uiAnimationsEnabled; }
    void setUiAnimationsEnabled(bool enabled);
    
    bool systemThemeEnabled() const { return m_systemThemeEnabled; }
    void setSystemThemeEnabled(bool enabled);
    
    bool compactMode() const { return m_compactMode; }
    void setCompactMode(bool enabled);
    
    bool showTooltips() const { return m_showTooltips; }
    void setShowTooltips(bool enabled);
    
    bool hardwareAcceleration() const { return m_hardwareAcceleration; }
    void setHardwareAcceleration(bool enabled);
    
    // Feature Settings getters/setters
    bool equalizerEnabled() const { return m_equalizerEnabled; }
    void setEqualizerEnabled(bool enabled);
    
    bool macrosEnabled() const { return m_macrosEnabled; }
    void setMacrosEnabled(bool enabled);
    
    bool apiAccessEnabled() const { return m_apiAccessEnabled; }
    void setApiAccessEnabled(bool enabled);
    
    bool smartSuggestionsEnabled() const { return m_smartSuggestionsEnabled; }
    void setSmartSuggestionsEnabled(bool enabled);
    
    // Update Settings getters/setters
    bool autoUpdateEnabled() const { return m_autoUpdateEnabled; }
    void setAutoUpdateEnabled(bool enabled);
    
    // Audio Settings getters/setters
    QString audioDriver() const { return m_audioDriver; }
    void setAudioDriver(const QString &driver);
    
    QString sampleRate() const { return m_sampleRate; }
    void setSampleRate(const QString &rate);
    
signals:
    void settingsExported(const QString &filePath);
    void settingsImported(const QString &filePath);
    void exportError(const QString &error);
    void importError(const QString &error);
    void settingsSaved();
    void settingsLoaded();
    
    // UI Display signals
    void themeChanged();
    void interfaceScaleChanged();
    void uiAnimationsEnabledChanged();
    void systemThemeEnabledChanged();
    void compactModeChanged();
    void showTooltipsChanged();
    void hardwareAccelerationChanged();
    
    // Feature signals
    void equalizerEnabledChanged();
    void macrosEnabledChanged();
    void apiAccessEnabledChanged();
    void smartSuggestionsEnabledChanged();
    
    // Update signals
    void autoUpdateEnabledChanged();
    
    // Audio signals
    void audioDriverChanged();
    void sampleRateChanged();

private:
    // JSON serialization functions
    QJsonObject serializeAudioSettings() const;
    QJsonObject serializeHotkeySettings() const;
    QJsonObject serializeSoundboardSettings() const;
    QJsonObject serializeApplicationSettings() const;
    QJsonObject serializeUISettings() const;
    QJsonObject serializeFeatureSettings() const;
    QJsonObject serializeUpdateSettings() const;
    
    // JSON deserialization functions
    bool deserializeAudioSettings(const QJsonObject &json);
    bool deserializeHotkeySettings(const QJsonObject &json);
    bool deserializeSoundboardSettings(const QJsonObject &json);
    bool deserializeApplicationSettings(const QJsonObject &json);
    bool deserializeUISettings(const QJsonObject &json);
    bool deserializeFeatureSettings(const QJsonObject &json);
    bool deserializeUpdateSettings(const QJsonObject &json);
    
    // Utility functions
    QJsonArray serializeAudioClips() const;
    QJsonArray serializeSections() const;
    QJsonArray serializeHotkeys() const;
    
    bool deserializeAudioClips(const QJsonArray &array);
    bool deserializeSections(const QJsonArray &array);
    bool deserializeHotkeys(const QJsonArray &array);
    
    // Member variables - Managers
    AudioManager *m_audioManager;
    HotkeyManager *m_hotkeyManager;
    SoundboardView *m_soundboardView;
    
    // UI Display Settings
    QString m_theme;
    qreal m_interfaceScale;
    bool m_uiAnimationsEnabled;
    bool m_systemThemeEnabled;
    bool m_compactMode;
    bool m_showTooltips;
    bool m_hardwareAcceleration;
    
    // Feature Settings
    bool m_equalizerEnabled;
    bool m_macrosEnabled;
    bool m_apiAccessEnabled;
    bool m_smartSuggestionsEnabled;
    
    // Update Settings
    bool m_autoUpdateEnabled;
    
    // Audio Settings
    QString m_audioDriver;
    QString m_sampleRate;
    
    static const QString APP_NAME;
    static const QString SETTINGS_VERSION;
    static const QString FILE_EXTENSION;
};

#endif // SETTINGSMANAGER_H
