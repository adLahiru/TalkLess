#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    
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
