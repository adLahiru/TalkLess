#include "settingsmanager.h"

#include "../models/audioclip.h"
#include "audiomanager.h"
#include "hotkeymanager.h"
#include "soundboardview.h"

#include <QDebug>
#include <QDir>
#include <QJsonDocument>
#include <QStandardPaths>

const QString SettingsManager::APP_NAME = "TalkLess";
const QString SettingsManager::SETTINGS_VERSION = "1.0";
const QString SettingsManager::FILE_EXTENSION = ".json";

SettingsManager::SettingsManager(QObject* parent)
    : QObject(parent), m_audioManager(nullptr), m_hotkeyManager(nullptr), m_soundboardView(nullptr)
      // UI Display Settings defaults
      ,
      m_theme("dark"), m_interfaceScale(1.0), m_uiAnimationsEnabled(true), m_systemThemeEnabled(false),
      m_compactMode(false), m_showTooltips(true), m_hardwareAcceleration(true)
      // Feature Settings defaults
      ,
      m_equalizerEnabled(true), m_macrosEnabled(true), m_apiAccessEnabled(true), m_smartSuggestionsEnabled(true)
      // Update Settings defaults
      ,
      m_autoUpdateEnabled(true)
      // Audio Settings defaults
      ,
      m_audioDriver("WASAPI"), m_sampleRate("44.1 kHz")
{
    // Load settings on construction
    loadAllSettings();
}

bool SettingsManager::exportSettingsToJson(const QString& filePath)
{
    try {
        qDebug() << "SettingsManager: Exporting settings to:" << filePath;

        QJsonObject rootObject;

        // Add metadata
        QJsonObject metadata;
        metadata["appName"] = APP_NAME;
        metadata["version"] = SETTINGS_VERSION;
        metadata["exportDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        metadata["description"] = "TalkLess Application Settings Export";
        rootObject["metadata"] = metadata;

        // Serialize all settings
        rootObject["audioSettings"] = serializeAudioSettings();
        rootObject["hotkeySettings"] = serializeHotkeySettings();
        rootObject["soundboardSettings"] = serializeSoundboardSettings();
        rootObject["applicationSettings"] = serializeApplicationSettings();

        // Create JSON document
        QJsonDocument doc(rootObject);

        // Ensure directory exists
        QFileInfo fileInfo(filePath);
        QDir dir = fileInfo.absoluteDir();
        if (!dir.exists()) {
            dir.mkpath(dir.absolutePath());
        }

        // Write to file
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            emit exportError(QString("Failed to open file for writing: %1").arg(filePath));
            return false;
        }

        file.write(doc.toJson());
        file.close();

        qDebug() << "SettingsManager: Settings exported successfully to:" << filePath;
        emit settingsExported(filePath);
        return true;

    } catch (const std::exception& e) {
        QString error = QString("Exception during export: %1").arg(e.what());
        qCritical() << "SettingsManager:" << error;
        emit exportError(error);
        return false;
    } catch (...) {
        QString error = "Unknown exception during export";
        qCritical() << "SettingsManager:" << error;
        emit exportError(error);
        return false;
    }
}

bool SettingsManager::importSettingsFromJson(const QString& filePath)
{
    try {
        qDebug() << "SettingsManager: Importing settings from:" << filePath;

        // Validate file first
        if (!validateJsonFile(filePath)) {
            emit importError("Invalid JSON file or file does not exist");
            return false;
        }

        // Open and read file
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            emit importError(QString("Failed to open file for reading: %1").arg(filePath));
            return false;
        }

        QByteArray jsonData = file.readAll();
        file.close();

        // Parse JSON
        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);

        if (parseError.error != QJsonParseError::NoError) {
            emit importError(QString("JSON parse error: %1").arg(parseError.errorString()));
            return false;
        }

        if (!doc.isObject()) {
            emit importError("Invalid JSON format - root must be an object");
            return false;
        }

        QJsonObject rootObject = doc.object();

        // Check metadata
        if (!rootObject.contains("metadata")) {
            qWarning() << "SettingsManager: No metadata found in JSON file";
        } else {
            QJsonObject metadata = rootObject["metadata"].toObject();
            QString appName = metadata["appName"].toString();
            QString version = metadata["version"].toString();

            qDebug() << "SettingsManager: Importing settings for" << appName << "version" << version;

            if (appName != APP_NAME) {
                qWarning() << "SettingsManager: Settings are for a different app:" << appName;
            }
        }

        // Import all settings
        bool success = true;

        if (rootObject.contains("audioSettings")) {
            success &= deserializeAudioSettings(rootObject["audioSettings"].toObject());
        }

        if (rootObject.contains("hotkeySettings")) {
            success &= deserializeHotkeySettings(rootObject["hotkeySettings"].toObject());
        }

        if (rootObject.contains("soundboardSettings")) {
            success &= deserializeSoundboardSettings(rootObject["soundboardSettings"].toObject());
        }

        if (rootObject.contains("applicationSettings")) {
            success &= deserializeApplicationSettings(rootObject["applicationSettings"].toObject());
        }

        if (success) {
            qDebug() << "SettingsManager: Settings imported successfully from:" << filePath;
            emit settingsImported(filePath);
        } else {
            emit importError("Some settings failed to import - check console for details");
        }

        return success;

    } catch (const std::exception& e) {
        QString error = QString("Exception during import: %1").arg(e.what());
        qCritical() << "SettingsManager:" << error;
        emit importError(error);
        return false;
    } catch (...) {
        QString error = "Unknown exception during import";
        qCritical() << "SettingsManager:" << error;
        emit importError(error);
        return false;
    }
}

void SettingsManager::setAudioManager(AudioManager* audioManager)
{
    m_audioManager = audioManager;
}

void SettingsManager::setHotkeyManager(HotkeyManager* hotkeyManager)
{
    m_hotkeyManager = hotkeyManager;
}

void SettingsManager::setSoundboardView(SoundboardView* soundboardView)
{
    m_soundboardView = soundboardView;
}

QString SettingsManager::getDefaultExportPath() const
{
    QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString fileName = QString("%1_settings_%2%3")
                           .arg(APP_NAME)
                           .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss"))
                           .arg(FILE_EXTENSION);

    return QDir(documentsPath).filePath(fileName);
}

bool SettingsManager::validateJsonFile(const QString& filePath) const
{
    QFile file(filePath);
    if (!file.exists()) {
        qDebug() << "SettingsManager: File does not exist:" << filePath;
        return false;
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "SettingsManager: Cannot open file:" << filePath;
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    if (data.isEmpty()) {
        qDebug() << "SettingsManager: File is empty:" << filePath;
        return false;
    }

    QJsonParseError parseError;
    QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        qDebug() << "SettingsManager: JSON parse error:" << parseError.errorString();
        return false;
    }

    return true;
}

QJsonObject SettingsManager::serializeAudioSettings() const
{
    QJsonObject audioSettings;

    if (!m_audioManager) {
        qWarning() << "SettingsManager: AudioManager not set for serialization";
        return audioSettings;
    }

    // Device settings
    QJsonObject devices;
    devices["inputDevice"] = m_audioManager->currentInputDevice();
    devices["outputDevice"] = m_audioManager->currentOutputDevice();
    devices["secondaryOutputDevice"] = m_audioManager->secondaryOutputDevice();
    devices["secondaryOutputEnabled"] = m_audioManager->secondaryOutputEnabled();
    devices["inputDeviceEnabled"] = m_audioManager->inputDeviceEnabled();
    audioSettings["devices"] = devices;

    // Volume settings
    QJsonObject volumes;
    volumes["masterVolume"] = m_audioManager->masterVolume();
    volumes["micVolume"] = m_audioManager->micVolume();
    audioSettings["volumes"] = volumes;

    // Audio clips
    audioSettings["audioClips"] = serializeAudioClips();

    return audioSettings;
}

QJsonObject SettingsManager::serializeHotkeySettings() const
{
    QJsonObject hotkeySettings;

    if (!m_hotkeyManager) {
        qWarning() << "SettingsManager: HotkeyManager not set for serialization";
        return hotkeySettings;
    }

    // Serialize hotkeys
    hotkeySettings["hotkeys"] = serializeHotkeys();

    return hotkeySettings;
}

QJsonObject SettingsManager::serializeSoundboardSettings() const
{
    QJsonObject soundboardSettings;

    if (!m_soundboardView) {
        qWarning() << "SettingsManager: SoundboardView not set for serialization";
        return soundboardSettings;
    }

    // Serialize sections
    soundboardSettings["sections"] = serializeSections();

    // Current section
    if (m_soundboardView->currentSection()) {
        soundboardSettings["currentSectionId"] = m_soundboardView->currentSection()->id();
    }

    return soundboardSettings;
}

QJsonObject SettingsManager::serializeApplicationSettings() const
{
    QJsonObject appSettings;
    appSettings["language"] = "en";
    return appSettings;
}

QJsonObject SettingsManager::serializeUISettings() const
{
    QJsonObject uiSettings;
    uiSettings["theme"] = m_theme;
    uiSettings["interfaceScale"] = m_interfaceScale;
    uiSettings["uiAnimationsEnabled"] = m_uiAnimationsEnabled;
    uiSettings["systemThemeEnabled"] = m_systemThemeEnabled;
    uiSettings["compactMode"] = m_compactMode;
    uiSettings["showTooltips"] = m_showTooltips;
    uiSettings["hardwareAcceleration"] = m_hardwareAcceleration;
    return uiSettings;
}

QJsonObject SettingsManager::serializeFeatureSettings() const
{
    QJsonObject featureSettings;
    featureSettings["equalizerEnabled"] = m_equalizerEnabled;
    featureSettings["macrosEnabled"] = m_macrosEnabled;
    featureSettings["apiAccessEnabled"] = m_apiAccessEnabled;
    featureSettings["smartSuggestionsEnabled"] = m_smartSuggestionsEnabled;

    // Include global hotkeys enabled from HotkeyManager
    if (m_hotkeyManager) {
        featureSettings["globalHotkeysEnabled"] = m_hotkeyManager->globalHotkeysEnabled();
    }

    return featureSettings;
}

QJsonObject SettingsManager::serializeUpdateSettings() const
{
    QJsonObject updateSettings;
    updateSettings["autoUpdateEnabled"] = m_autoUpdateEnabled;
    return updateSettings;
}

QJsonArray SettingsManager::serializeAudioClips() const
{
    QJsonArray clipsArray;

    if (!m_audioManager) {
        return clipsArray;
    }

    for (AudioClip* clip : m_audioManager->audioClips()) {
        if (!clip)
            continue;

        QJsonObject clipObj;
        clipObj["id"] = clip->id();
        clipObj["title"] = clip->title();
        clipObj["filePath"] = clip->filePath().toString();
        clipObj["hotkey"] = clip->hotkey();
        clipObj["volume"] = clip->volume();
        clipObj["trimStart"] = clip->trimStart();
        clipObj["trimEnd"] = clip->trimEnd();
        clipObj["sectionId"] = clip->sectionId();
        clipObj["duration"] = clip->duration();

        clipsArray.append(clipObj);
    }

    return clipsArray;
}

QJsonArray SettingsManager::serializeSections() const
{
    QJsonArray sectionsArray;

    if (!m_soundboardView) {
        return sectionsArray;
    }

    // This would need to be implemented in SoundboardView
    // For now, return empty array
    return sectionsArray;
}

QJsonArray SettingsManager::serializeHotkeys() const
{
    QJsonArray hotkeysArray;

    // This would need to be implemented in HotkeyManager
    // For now, return empty array
    return hotkeysArray;
}

bool SettingsManager::deserializeAudioSettings(const QJsonObject& json)
{
    if (!m_audioManager) {
        qWarning() << "SettingsManager: AudioManager not set for deserialization";
        return false;
    }

    try {
        // Device settings
        if (json.contains("devices")) {
            QJsonObject devices = json["devices"].toObject();

            QString inputDevice = devices["inputDevice"].toString();
            QString outputDevice = devices["outputDevice"].toString();
            QString secondaryOutputDevice = devices["secondaryOutputDevice"].toString();
            bool secondaryOutputEnabled = devices["secondaryOutputEnabled"].toBool();
            bool inputDeviceEnabled = devices["inputDeviceEnabled"].toBool();

            // Apply device settings (with validation)
            if (!inputDevice.isEmpty()) {
                m_audioManager->setCurrentInputDevice(inputDevice);
            }
            if (!outputDevice.isEmpty()) {
                m_audioManager->setCurrentOutputDevice(outputDevice);
            }
            if (!secondaryOutputDevice.isEmpty()) {
                m_audioManager->setSecondaryOutputDevice(secondaryOutputDevice);
            }
            m_audioManager->setSecondaryOutputEnabled(secondaryOutputEnabled);
            m_audioManager->setInputDeviceEnabled(inputDeviceEnabled);
        }

        // Volume settings
        if (json.contains("volumes")) {
            QJsonObject volumes = json["volumes"].toObject();

            qreal masterVolume = volumes["masterVolume"].toDouble(1.0);
            qreal micVolume = volumes["micVolume"].toDouble(1.0);

            m_audioManager->setVolume(masterVolume);
            // Note: mic volume would need to be set through AudioEngine
        }

        // Audio clips
        if (json.contains("audioClips")) {
            deserializeAudioClips(json["audioClips"].toArray());
        }

        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeAudioSettings";
        return false;
    }
}

bool SettingsManager::deserializeHotkeySettings(const QJsonObject& json)
{
    if (!m_hotkeyManager) {
        qWarning() << "SettingsManager: HotkeyManager not set for deserialization";
        return false;
    }

    try {
        if (json.contains("hotkeys")) {
            deserializeHotkeys(json["hotkeys"].toArray());
        }
        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeHotkeySettings";
        return false;
    }
}

bool SettingsManager::deserializeSoundboardSettings(const QJsonObject& json)
{
    if (!m_soundboardView) {
        qWarning() << "SettingsManager: SoundboardView not set for deserialization";
        return false;
    }

    try {
        if (json.contains("sections")) {
            deserializeSections(json["sections"].toArray());
        }

        if (json.contains("currentSectionId")) {
            QString currentSectionId = json["currentSectionId"].toString();
            // Select the current section
            // This would need to be implemented in SoundboardView
        }

        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeSoundboardSettings";
        return false;
    }
}

bool SettingsManager::deserializeApplicationSettings(const QJsonObject& json)
{
    try {
        // Handle application-wide settings here
        Q_UNUSED(json)
        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeApplicationSettings";
        return false;
    }
}

bool SettingsManager::deserializeAudioClips(const QJsonArray& array)
{
    if (!m_audioManager) {
        return false;
    }

    try {
        for (const QJsonValue& value : array) {
            QJsonObject clipObj = value.toObject();

            QString id = clipObj["id"].toString();
            QString title = clipObj["title"].toString();
            QString filePath = clipObj["filePath"].toString();
            QString hotkey = clipObj["hotkey"].toString();
            qreal volume = clipObj["volume"].toDouble(1.0);
            qreal trimStart = clipObj["trimStart"].toDouble(0.0);
            qreal trimEnd = clipObj["trimEnd"].toDouble(-1.0);
            QString sectionId = clipObj["sectionId"].toString();
            qreal duration = clipObj["duration"].toDouble(0.0);

            // Create and add the clip
            // This would need to be implemented in AudioManager
            Q_UNUSED(id)
            Q_UNUSED(title)
            Q_UNUSED(filePath)
            Q_UNUSED(hotkey)
            Q_UNUSED(volume)
            Q_UNUSED(trimStart)
            Q_UNUSED(trimEnd)
            Q_UNUSED(sectionId)
            Q_UNUSED(duration)
        }

        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeAudioClips";
        return false;
    }
}

bool SettingsManager::deserializeSections(const QJsonArray& array)
{
    if (!m_soundboardView) {
        return false;
    }

    try {
        // This would need to be implemented in SoundboardView
        Q_UNUSED(array)
        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeSections";
        return false;
    }
}

bool SettingsManager::deserializeHotkeys(const QJsonArray& array)
{
    if (!m_hotkeyManager) {
        return false;
    }

    try {
        // This would need to be implemented in HotkeyManager
        Q_UNUSED(array)
        return true;

    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeHotkeys";
        return false;
    }
}

// ============================================================================
// Auto Save/Load Functions
// ============================================================================

QString SettingsManager::getSettingsFilePath() const
{
    QString appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(appDataPath);
    if (!dir.exists()) {
        dir.mkpath(appDataPath);
    }
    return dir.filePath("settings.json");
}

void SettingsManager::saveAllSettings()
{
    try {
        QString filePath = getSettingsFilePath();
        qDebug() << "SettingsManager: Saving all settings to:" << filePath;

        QJsonObject rootObject;

        // Add metadata
        QJsonObject metadata;
        metadata["appName"] = APP_NAME;
        metadata["version"] = SETTINGS_VERSION;
        metadata["saveDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        rootObject["metadata"] = metadata;

        // Serialize all settings categories
        rootObject["uiSettings"] = serializeUISettings();
        rootObject["featureSettings"] = serializeFeatureSettings();
        rootObject["updateSettings"] = serializeUpdateSettings();
        rootObject["audioSettings"] = serializeAudioSettings();
        rootObject["applicationSettings"] = serializeApplicationSettings();

        // Create JSON document with pretty formatting
        QJsonDocument doc(rootObject);

        // Ensure directory exists
        QFileInfo fileInfo(filePath);
        QDir dir = fileInfo.absoluteDir();
        if (!dir.exists()) {
            dir.mkpath(dir.absolutePath());
        }

        // Write to file
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            qCritical() << "SettingsManager: Failed to open settings file for writing:" << filePath;
            return;
        }

        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();

        qDebug() << "SettingsManager: All settings saved successfully";
        emit settingsSaved();

    } catch (const std::exception& e) {
        qCritical() << "SettingsManager: Exception saving settings:" << e.what();
    } catch (...) {
        qCritical() << "SettingsManager: Unknown exception saving settings";
    }
}

void SettingsManager::loadAllSettings()
{
    try {
        QString filePath = getSettingsFilePath();
        qDebug() << "SettingsManager: Loading settings from:" << filePath;

        QFile file(filePath);
        if (!file.exists()) {
            qDebug() << "SettingsManager: No settings file found, using defaults";
            return;
        }

        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "SettingsManager: Failed to open settings file:" << filePath;
            return;
        }

        QByteArray jsonData = file.readAll();
        file.close();

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);

        if (parseError.error != QJsonParseError::NoError) {
            qWarning() << "SettingsManager: JSON parse error:" << parseError.errorString();
            return;
        }

        if (!doc.isObject()) {
            qWarning() << "SettingsManager: Invalid settings file format";
            return;
        }

        QJsonObject rootObject = doc.object();

        // Load all settings categories
        if (rootObject.contains("uiSettings")) {
            deserializeUISettings(rootObject["uiSettings"].toObject());
        }
        if (rootObject.contains("featureSettings")) {
            deserializeFeatureSettings(rootObject["featureSettings"].toObject());
        }
        if (rootObject.contains("updateSettings")) {
            deserializeUpdateSettings(rootObject["updateSettings"].toObject());
        }

        qDebug() << "SettingsManager: All settings loaded successfully";
        emit settingsLoaded();

    } catch (const std::exception& e) {
        qCritical() << "SettingsManager: Exception loading settings:" << e.what();
    } catch (...) {
        qCritical() << "SettingsManager: Unknown exception loading settings";
    }
}

// ============================================================================
// Deserialize Functions for New Settings
// ============================================================================

bool SettingsManager::deserializeUISettings(const QJsonObject& json)
{
    try {
        if (json.contains("theme")) {
            m_theme = json["theme"].toString("dark");
        }
        if (json.contains("interfaceScale")) {
            m_interfaceScale = json["interfaceScale"].toDouble(1.0);
        }
        if (json.contains("uiAnimationsEnabled")) {
            m_uiAnimationsEnabled = json["uiAnimationsEnabled"].toBool(true);
        }
        if (json.contains("systemThemeEnabled")) {
            m_systemThemeEnabled = json["systemThemeEnabled"].toBool(false);
        }
        if (json.contains("compactMode")) {
            m_compactMode = json["compactMode"].toBool(false);
        }
        if (json.contains("showTooltips")) {
            m_showTooltips = json["showTooltips"].toBool(true);
        }
        if (json.contains("hardwareAcceleration")) {
            m_hardwareAcceleration = json["hardwareAcceleration"].toBool(true);
        }

        // Emit all signals to update UI
        emit themeChanged();
        emit interfaceScaleChanged();
        emit uiAnimationsEnabledChanged();
        emit systemThemeEnabledChanged();
        emit compactModeChanged();
        emit showTooltipsChanged();
        emit hardwareAccelerationChanged();

        return true;
    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeUISettings";
        return false;
    }
}

bool SettingsManager::deserializeFeatureSettings(const QJsonObject& json)
{
    try {
        if (json.contains("equalizerEnabled")) {
            m_equalizerEnabled = json["equalizerEnabled"].toBool(true);
        }
        if (json.contains("macrosEnabled")) {
            m_macrosEnabled = json["macrosEnabled"].toBool(true);
        }
        if (json.contains("apiAccessEnabled")) {
            m_apiAccessEnabled = json["apiAccessEnabled"].toBool(true);
        }
        if (json.contains("smartSuggestionsEnabled")) {
            m_smartSuggestionsEnabled = json["smartSuggestionsEnabled"].toBool(true);
        }
        if (json.contains("globalHotkeysEnabled") && m_hotkeyManager) {
            m_hotkeyManager->setGlobalHotkeysEnabled(json["globalHotkeysEnabled"].toBool(true));
        }

        // Emit all signals
        emit equalizerEnabledChanged();
        emit macrosEnabledChanged();
        emit apiAccessEnabledChanged();
        emit smartSuggestionsEnabledChanged();

        return true;
    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeFeatureSettings";
        return false;
    }
}

bool SettingsManager::deserializeUpdateSettings(const QJsonObject& json)
{
    try {
        if (json.contains("autoUpdateEnabled")) {
            m_autoUpdateEnabled = json["autoUpdateEnabled"].toBool(true);
        }

        emit autoUpdateEnabledChanged();

        return true;
    } catch (...) {
        qCritical() << "SettingsManager: Exception in deserializeUpdateSettings";
        return false;
    }
}

// ============================================================================
// Property Setters
// ============================================================================

void SettingsManager::setTheme(const QString& theme)
{
    if (m_theme != theme) {
        m_theme = theme;
        emit themeChanged();
    }
}

void SettingsManager::setInterfaceScale(qreal scale)
{
    if (!qFuzzyCompare(m_interfaceScale, scale)) {
        m_interfaceScale = scale;
        emit interfaceScaleChanged();
    }
}

void SettingsManager::setUiAnimationsEnabled(bool enabled)
{
    if (m_uiAnimationsEnabled != enabled) {
        m_uiAnimationsEnabled = enabled;
        emit uiAnimationsEnabledChanged();
    }
}

void SettingsManager::setSystemThemeEnabled(bool enabled)
{
    if (m_systemThemeEnabled != enabled) {
        m_systemThemeEnabled = enabled;
        emit systemThemeEnabledChanged();
    }
}

void SettingsManager::setCompactMode(bool enabled)
{
    if (m_compactMode != enabled) {
        m_compactMode = enabled;
        emit compactModeChanged();
    }
}

void SettingsManager::setShowTooltips(bool enabled)
{
    if (m_showTooltips != enabled) {
        m_showTooltips = enabled;
        emit showTooltipsChanged();
    }
}

void SettingsManager::setHardwareAcceleration(bool enabled)
{
    if (m_hardwareAcceleration != enabled) {
        m_hardwareAcceleration = enabled;
        emit hardwareAccelerationChanged();
    }
}

void SettingsManager::setEqualizerEnabled(bool enabled)
{
    if (m_equalizerEnabled != enabled) {
        m_equalizerEnabled = enabled;
        emit equalizerEnabledChanged();
    }
}

void SettingsManager::setMacrosEnabled(bool enabled)
{
    if (m_macrosEnabled != enabled) {
        m_macrosEnabled = enabled;
        emit macrosEnabledChanged();
    }
}

void SettingsManager::setApiAccessEnabled(bool enabled)
{
    if (m_apiAccessEnabled != enabled) {
        m_apiAccessEnabled = enabled;
        emit apiAccessEnabledChanged();
    }
}

void SettingsManager::setSmartSuggestionsEnabled(bool enabled)
{
    if (m_smartSuggestionsEnabled != enabled) {
        m_smartSuggestionsEnabled = enabled;
        emit smartSuggestionsEnabledChanged();
    }
}

void SettingsManager::setAutoUpdateEnabled(bool enabled)
{
    if (m_autoUpdateEnabled != enabled) {
        m_autoUpdateEnabled = enabled;
        emit autoUpdateEnabledChanged();
    }
}

void SettingsManager::setAudioDriver(const QString& driver)
{
    if (m_audioDriver != driver) {
        m_audioDriver = driver;
        emit audioDriverChanged();
    }
}

void SettingsManager::setSampleRate(const QString& rate)
{
    if (m_sampleRate != rate) {
        m_sampleRate = rate;
        emit sampleRateChanged();
    }
}
