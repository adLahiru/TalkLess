#include "maincontroller.h"

#include "../models/audioEngine.h"

MainController::MainController(QObject* parent) : QObject(parent), m_audioEngine(new AudioEngine(this)) {}

MainController::~MainController()
{
    delete m_audioEngine;
}

void MainController::initialize()
{
    if (m_audioEngine) {
        m_audioEngine->startAudioDevice();
    }
}

AudioEngine* MainController::audioEngine()
{
    return m_audioEngine;
}