#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include "controllers/audiomanager.h"
#include "controllers/hotkeymanager.h"
#include "view/soundboardview.h"
#include "view/audioplayerview.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    
    // Create controllers
    AudioManager audioManager;
    HotkeyManager hotkeyManager;
    
    // Create views
    SoundboardView soundboardView(&audioManager, &hotkeyManager);
    AudioPlayerView audioPlayerView(&audioManager);
    
    // Register to QML context
    engine.rootContext()->setContextProperty("audioManager", &audioManager);
    engine.rootContext()->setContextProperty("hotkeyManager", &hotkeyManager);
    engine.rootContext()->setContextProperty("soundboardView", &soundboardView);
    engine.rootContext()->setContextProperty("audioPlayerView", &audioPlayerView);
    
    // Connect hotkey manager to audio manager
    QObject::connect(&hotkeyManager, &HotkeyManager::hotkeyTriggered,
                     &audioManager, &AudioManager::playClip);
    
    // Connect system hotkeys
    QObject::connect(&hotkeyManager, &HotkeyManager::playPauseTriggered,
                     &audioManager, [&audioManager]() {
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
    
    QObject::connect(&hotkeyManager, &HotkeyManager::stopAllTriggered,
                     &audioManager, &AudioManager::stopAll);
    
    qDebug() << "MVC Architecture initialized:";
    qDebug() << "- Controllers: AudioManager, HotkeyManager";
    qDebug() << "- Views: SoundboardView, AudioPlayerView";
    qDebug() << "- Models: AudioClip";
    
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { 
            qCritical() << "QML object creation failed!";
            QCoreApplication::exit(-1); 
        },
        Qt::QueuedConnection);
    
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [](QObject *obj, const QUrl &url) {
            if (!obj) {
                qCritical() << "Failed to create object from:" << url;
            } else {
                qDebug() << "Successfully created:" << url;
            }
        },
        Qt::QueuedConnection);
        
    qDebug() << "Loading TalkLess module...";
    engine.loadFromModule("TalkLess", "Main");
    qDebug() << "Module loaded, starting event loop...";

    return app.exec();
}
