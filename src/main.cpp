#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQmlContext>
#include <QIcon>
#include <QtQml>

#include "services/soundboardService.h"
#include "qmlmodels/soundboardsListModel.h"
#include "qmlmodels/clipsListModel.h"
#include "controllers/hotkeymanager.h"

int main(int argc, char* argv[])
{
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);

    QGuiApplication::setOrganizationName("TalkLess");
    QGuiApplication::setOrganizationDomain("talkless.app");
    QGuiApplication::setApplicationName("TalkLess");

    app.setWindowIcon(QIcon(":/resources/icons/appIcon.png"));
    app.setQuitOnLastWindowClosed(true);

    QQmlApplicationEngine engine;

    // Backend
    SoundboardService soundboardService;

    // Model for QML
    SoundboardsListModel soundboardsModel;
    soundboardsModel.setService(&soundboardService);

    // Clips model for QML
    ClipsListModel clipsModel;
    clipsModel.setService(&soundboardService);

    // Hotkey Manager
    HotkeyManager hotkeyManager;
    hotkeyManager.setSoundboardService(&soundboardService);

    // Connect hotkey actions to soundboard service
    QObject::connect(&hotkeyManager, &HotkeyManager::actionTriggered,
                     &soundboardService, &SoundboardService::handleHotkeyAction);

    // Auto-save hotkeys when application closes
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&hotkeyManager]() {
        hotkeyManager.saveHotkeysOnClose();
    });

    // Save all soundboard changes and STOP ALL CLIPS when application closes
    QObject::connect(&app, &QGuiApplication::aboutToQuit, [&soundboardService]() {
        soundboardService.stopAllClips();
        soundboardService.saveAllChanges();
    });

    // Expose to QML
    engine.rootContext()->setContextProperty("soundboardService", &soundboardService);
    engine.rootContext()->setContextProperty("soundboardsModel", &soundboardsModel);
    engine.rootContext()->setContextProperty("clipsModel", &clipsModel);
    engine.rootContext()->setContextProperty("hotkeyManager", &hotkeyManager);

    // Register ClipsListModel as a QML type so detached windows can create their own instances
    qmlRegisterType<ClipsListModel>("TalkLess.Models", 1, 0, "ClipsListModel");

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("TalkLess", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
