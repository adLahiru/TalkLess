#ifdef Q_OS_WIN
    #include <fcntl.h>
    #include <io.h>
    #include <windows.h>
#endif

#include "controllers/audiomanager.h"
#include "controllers/hotkeymanager.h"
#include "controllers/maincontroller.h"
#include "controllers/settingsmanager.h"
#include "view/audioplayerview.h"
#include "view/soundboardview.h"

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSettings>
#include <QTimer>

int main(int argc, char* argv[])
{
    // Set Qt Quick Controls style to Basic to allow customization
    QQuickStyle::setStyle("Basic");

    QGuiApplication app(argc, argv);

    // Set application metadata for QSettings
    app.setOrganizationName("TalkLess");
    app.setOrganizationDomain("talkless.app");
    app.setApplicationName("TalkLess");

    qDebug() << "=== TalkLess Application Starting ===";
    qDebug() << "Qt version:" << QT_VERSION_STR;
    qDebug() << "Working directory:" << QDir::currentPath();

    try {
        QQmlApplicationEngine engine;

        qDebug() << "Creating MainController...";
        // Main controller owns the single AudioEngine instance
        MainController mainController(nullptr);

        qDebug() << "Getting AudioEngine instance...";
        AudioEngine* sharedAudioEngine = mainController.audioEngine();
        if (!sharedAudioEngine) {
            qCritical() << "Failed to get AudioEngine instance!";
            return -1;
        }

        qDebug() << "Starting audio device...";
        if (!sharedAudioEngine->startAudioDevice()) {
            qWarning() << "Failed to start audio device, continuing anyway...";
        }

        qDebug() << "Creating controllers...";
        // Create controllers sharing the same AudioEngine
        AudioManager audioManager(sharedAudioEngine);
        try {
            qDebug() << "AudioManager created successfully";
        } catch (...) {
            qCritical() << "Failed to create AudioManager!";
            return -1;
        }

        HotkeyManager hotkeyManager(sharedAudioEngine);
        try {
            qDebug() << "HotkeyManager created successfully";
        } catch (...) {
            qCritical() << "Failed to create HotkeyManager!";
            return -1;
        }

        qDebug() << "Creating views...";
        // Create views
        SoundboardView soundboardView(&audioManager, &hotkeyManager);
        try {
            qDebug() << "SoundboardView created successfully";
            // Add a small delay to ensure SoundboardView is fully initialized
            QTimer::singleShot(100, [&soundboardView]() { qDebug() << "SoundboardView initialization check passed"; });
        } catch (const std::exception& e) {
            qCritical() << "Failed to create SoundboardView! Exception:" << e.what();
            return -1;
        } catch (...) {
            qCritical() << "Failed to create SoundboardView! Unknown exception";
            return -1;
        }

        AudioPlayerView audioPlayerView(&audioManager);
        try {
            qDebug() << "AudioPlayerView created successfully";
        } catch (...) {
            qCritical() << "Failed to create AudioPlayerView!";
            return -1;
        }

        qDebug() << "Creating SettingsManager...";
        SettingsManager settingsManager;
        settingsManager.setAudioManager(&audioManager);
        settingsManager.setHotkeyManager(&hotkeyManager);
        settingsManager.setSoundboardView(&soundboardView);
        qDebug() << "SettingsManager created successfully";

        qDebug() << "Registering QML context properties...";
        // Register to QML context
        engine.rootContext()->setContextProperty("audioManager", &audioManager);
        engine.rootContext()->setContextProperty("hotkeyManager", &hotkeyManager);
        engine.rootContext()->setContextProperty("soundboardView", &soundboardView);
        engine.rootContext()->setContextProperty("audioPlayerView", &audioPlayerView);
        engine.rootContext()->setContextProperty("settingsManager", &settingsManager);
        // Also register as singletons to ensure availability inside module
        qmlRegisterSingletonInstance("TalkLess", 1, 0, "AudioManager", &audioManager);
        qmlRegisterSingletonInstance("TalkLess", 1, 0, "HotkeyManager", &hotkeyManager);
        qmlRegisterSingletonInstance("TalkLess", 1, 0, "SoundboardView", &soundboardView);
        qmlRegisterSingletonInstance("TalkLess", 1, 0, "AudioPlayerView", &audioPlayerView);
        qmlRegisterSingletonInstance("TalkLess", 1, 0, "SettingsManager", &settingsManager);

        qDebug() << "Connecting signals...";
        // Connect hotkey manager to audio manager - play from start when hotkey triggered
        QObject::connect(&hotkeyManager, &HotkeyManager::hotkeyTriggered, &audioManager,
                         &AudioManager::playClipFromStart);

        // Connect system hotkeys
        QObject::connect(&hotkeyManager, &HotkeyManager::playPauseTriggered, &audioManager, [&audioManager]() {
            if (audioManager.isPlaying()) {
                if (audioManager.currentClip()) {
                    audioManager.pauseClip(audioManager.currentClip()->id());
                }
            } else {
                if (audioManager.currentClip()) {
                    audioManager.playClip(audioManager.currentClip()->id());
                }
            }
        });

        QObject::connect(&hotkeyManager, &HotkeyManager::stopAllTriggered, &audioManager, &AudioManager::stopAll);

        qDebug() << "MVC Architecture initialized:";
        qDebug() << "- Controllers: AudioManager, HotkeyManager";
        qDebug() << "- Views: SoundboardView, AudioPlayerView";
        qDebug() << "- Models: AudioClip";

        QObject::connect(
            &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
            []() {
                qCritical() << "QML object creation failed!";
                QCoreApplication::exit(-1);
            },
            Qt::QueuedConnection);

        // Connect application close event to save all settings
        QObject::connect(&app, &QGuiApplication::aboutToQuit,
                         [&hotkeyManager, &audioManager, &soundboardView, &settingsManager]() {
                             qDebug() << "Application is closing - saving all settings...";

                             // Save all UI/feature/update settings to JSON
                             settingsManager.saveAllSettings();

                             // Save hotkeys (already implemented in HotkeyManager)
                             hotkeyManager.saveHotkeys();

                             // Save audio settings and device preferences
                             audioManager.saveSettings();

                             // Save soundboard data (clips and sections)
                             soundboardView.saveSoundboardData();

                             // Sync all settings to ensure they're written
                             QSettings settings("TalkLess", "Application");
                             settings.sync();

                             qDebug() << "All settings saved successfully";
                         });

        qDebug() << "Loading TalkLess module...";
        engine.loadFromModule("TalkLess", "Main");

        // Check if root object was created
        if (!engine.rootObjects().isEmpty()) {
            qDebug() << "Module loaded successfully, root objects count:" << engine.rootObjects().size();
            qDebug() << "Starting event loop...";
            int result = app.exec();

            // Clear QML engine before destroying C++ objects
            // This prevents QML from accessing destroyed C++ objects
            qDebug() << "Cleaning up QML engine...";
            engine.clearComponentCache();

            // Explicitly stop audio engine before destruction
            if (sharedAudioEngine && sharedAudioEngine->isDeviceRunning()) {
                qDebug() << "Stopping audio device...";
                sharedAudioEngine->stopAudioDevice();
            }

            qDebug() << "Application exiting cleanly";
            return result;
        } else {
            qCritical() << "Failed to load QML module - no root objects created";
            return -1;
        }

    } catch (const std::exception& e) {
        qCritical() << "Standard exception during startup:" << e.what();
        return -1;
    } catch (...) {
        qCritical() << "Unknown exception during startup!";
        return -1;
    }
}
