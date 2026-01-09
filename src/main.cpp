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
    app.setQuitOnLastWindowClosed(false);

    HotkeyManager manager;

    QVector<HotkeyManager::HotkeyDef> defs = {
        { "Ctrl++P",          "feature.print", true },
        { "Ctrl+Shift+S",        "feature.save",  true },
        { "Ctrl+Shift+Alt+F12",  "feature.test",  true }  // good test
    };

    manager.setHotkeys(defs);

    QObject::connect(&manager, &HotkeyManager::hotkeyTriggered,
                     [](const QString& seq, const QString& actionId) {
        qDebug() << "Triggered:" << seq << actionId;
        // Dispatch to your feature system here
    });

    QObject::connect(&manager, &HotkeyManager::hotkeyRegistrationFailed,
                     [](const QString& seq, const QString& actionId) {
        qDebug() << "FAILED to register:" << seq << actionId;
    });


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

           // Expose to QML
    engine.rootContext()->setContextProperty("soundboardService", &soundboardService);
    engine.rootContext()->setContextProperty("soundboardsModel", &soundboardsModel);
    engine.rootContext()->setContextProperty("clipsModel", &clipsModel);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("TalkLess", "Main");

    return app.exec();
}
