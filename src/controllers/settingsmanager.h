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

public:
    explicit SettingsManager(QObject *parent = nullptr);
    
    // Export/Import functions
    bool exportSettingsToJson(const QString &filePath);
    bool importSettingsFromJson(const QString &filePath);
    
    // Set managers to export/import from
    void setAudioManager(AudioManager *audioManager);
    void setHotkeyManager(HotkeyManager *hotkeyManager);
    void setSoundboardView(SoundboardView *soundboardView);
    
    // Utility functions
    QString getDefaultExportPath() const;
    bool validateJsonFile(const QString &filePath) const;
    
signals:
    void settingsExported(const QString &filePath);
    void settingsImported(const QString &filePath);
    void exportError(const QString &error);
    void importError(const QString &error);

private:
    // JSON serialization functions
    QJsonObject serializeAudioSettings() const;
    QJsonObject serializeHotkeySettings() const;
    QJsonObject serializeSoundboardSettings() const;
    QJsonObject serializeApplicationSettings() const;
    
    // JSON deserialization functions
    bool deserializeAudioSettings(const QJsonObject &json);
    bool deserializeHotkeySettings(const QJsonObject &json);
    bool deserializeSoundboardSettings(const QJsonObject &json);
    bool deserializeApplicationSettings(const QJsonObject &json);
    
    // Utility functions
    QJsonArray serializeAudioClips() const;
    QJsonArray serializeSections() const;
    QJsonArray serializeHotkeys() const;
    
    bool deserializeAudioClips(const QJsonArray &array);
    bool deserializeSections(const QJsonArray &array);
    bool deserializeHotkeys(const QJsonArray &array);
    
    // Member variables
    AudioManager *m_audioManager;
    HotkeyManager *m_hotkeyManager;
    SoundboardView *m_soundboardView;
    
    static const QString APP_NAME;
    static const QString SETTINGS_VERSION;
    static const QString FILE_EXTENSION;
};

#endif // SETTINGSMANAGER_H
