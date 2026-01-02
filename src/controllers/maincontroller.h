#ifndef MAINCONTROLLER_H
#define MAINCONTROLLER_H

#include <QObject>

class AudioEngine;

class MainController : public QObject
{
    Q_OBJECT

public:
    explicit MainController(QObject* parent = nullptr);
    ~MainController();

    void initialize();
    AudioEngine* audioEngine(); // get audio engine

private:
    AudioEngine* m_audioEngine;
};

#endif // MAINCONTROLLER_H
