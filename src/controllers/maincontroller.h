#ifndef MAINCONTROLLER_H
#define MAINCONTROLLER_H

#include <QObject>

class MainWindow;
class AudioEngine;

class MainController : public QObject
{
    Q_OBJECT

public:
    explicit MainController(MainWindow *view, QObject *parent = nullptr);
    ~MainController();

    void initialize();
    AudioEngine* audioEngine();                     // get audio engine

private:
    MainWindow *m_view;
    AudioEngine *m_audioEngine;
};

#endif // MAINCONTROLLER_H
