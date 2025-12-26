#include <QGuiApplication>
#include <QSettings>
#include <QDebug>
#include <QDir>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    qDebug() << "Clearing TalkLess application data...";
    
    // Clear main application settings
    QSettings settings("TalkLess", "Application");
    settings.clear();
    qDebug() << "Cleared Application settings";
    
    // Clear soundboard settings
    QSettings soundboardSettings("TalkLess", "Soundboard");
    soundboardSettings.clear();
    qDebug() << "Cleared Soundboard settings";
    
    // Clear audio manager settings
    QSettings audioSettings("TalkLess", "AudioManager");
    audioSettings.clear();
    qDebug() << "Cleared AudioManager settings";
    
    // Clear hotkey settings
    QSettings hotkeySettings("TalkLess", "HotkeyManager");
    hotkeySettings.clear();
    qDebug() << "Cleared HotkeyManager settings";
    
    // Try to remove settings files directly
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (QDir(configDir).exists()) {
        qDebug() << "Config directory:" << configDir;
        QDir(configDir).removeRecursively();
        qDebug() << "Removed config directory";
    }
    
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (QDir(dataDir).exists()) {
        qDebug() << "Data directory:" << dataDir;
        QDir(dataDir).removeRecursively();
        qDebug() << "Removed data directory";
    }
    
    qDebug() << "All TalkLess data cleared successfully!";
    return 0;
}
