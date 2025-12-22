#include "maincontroller.h"
#include "../views/mainwindow.h"
#include "../models/audioEngine.h"

MainController::MainController(MainWindow *view, QObject *parent)
    : QObject(parent)
    , m_view(view)
    , m_audioEngine(new AudioEngine(this))
{
}

MainController::~MainController()
{
    delete m_audioEngine;
}

void MainController::initialize()
{
    m_view->showWelcomeMessage(tr("Welcome to Call Assistant"));
    m_audioEngine->startAudioDevice();
}

AudioEngine* MainController::audioEngine()
{
    return m_audioEngine;
}