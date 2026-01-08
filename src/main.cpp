#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQmlContext>

#include "services/soundboardService.h"
#include "qmlmodels/soundboardsListModel.h"
#include "qmlmodels/clipsListModel.h"

int main(int argc, char* argv[])
{
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);

    QGuiApplication::setOrganizationName("TalkLess");
    QGuiApplication::setOrganizationDomain("talkless.app");
    QGuiApplication::setApplicationName("TalkLess");

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
