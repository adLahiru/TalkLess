#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

int main(int argc, char* argv[])
{
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);

    QGuiApplication::setOrganizationName("TalkLess");
    QGuiApplication::setOrganizationDomain("talkless.app");
    QGuiApplication::setApplicationName("TalkLess");

    QQmlApplicationEngine engine;

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("TalkLess", "Main");

    return app.exec();
}
