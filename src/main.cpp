#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQmlContext>
#include <QDebug>

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
    // Keep process alive even if window closes/minimizes
    app.setQuitOnLastWindowClosed(true);

           // Create QML engine FIRST
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

           // Connect hotkey actions to soundboard service (modular signal-slot connection)
    QObject::connect(&hotkeyManager, &HotkeyManager::actionTriggered,
                     &soundboardService, &SoundboardService::handleHotkeyAction);

           // Expose to QML
    engine.rootContext()->setContextProperty("soundboardService", &soundboardService);
    engine.rootContext()->setContextProperty("soundboardsModel", &soundboardsModel);
    engine.rootContext()->setContextProperty("clipsModel", &clipsModel);
    engine.rootContext()->setContextProperty("hotkeyManager", &hotkeyManager);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("TalkLess", "Main");

    return app.exec();
}
