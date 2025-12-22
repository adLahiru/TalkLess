#include "audioplayerview.h"
#include <QDebug>

AudioPlayerView::AudioPlayerView(AudioManager* audioMgr, QObject *parent)
    : QObject(parent)
    , m_audioManager(audioMgr)
    , m_savedVolume(1.0)
{
    // Connect to audio manager signals
    connect(m_audioManager, &AudioManager::currentClipChanged,
            this, &AudioPlayerView::onCurrentClipChanged);
    connect(m_audioManager, &AudioManager::isPlayingChanged,
            this, &AudioPlayerView::onPlayingStateChanged);
    connect(m_audioManager, &AudioManager::currentPositionChanged,
            this, &AudioPlayerView::currentPositionChanged);
    connect(m_audioManager, &AudioManager::currentDurationChanged,
            this, &AudioPlayerView::currentDurationChanged);
    connect(m_audioManager, &AudioManager::volumeChanged,
            this, &AudioPlayerView::volumeChanged);
    
    qDebug() << "AudioPlayerView initialized";
}

QString AudioPlayerView::currentTitle() const
{
    if (m_audioManager && m_audioManager->currentClip()) {
        return m_audioManager->currentClip()->title();
    }
    return "No audio playing";
}

qreal AudioPlayerView::currentPosition() const
{
    return m_audioManager ? m_audioManager->currentPosition() : 0.0;
}

qreal AudioPlayerView::currentDuration() const
{
    return m_audioManager ? m_audioManager->currentDuration() : 0.0;
}

bool AudioPlayerView::isPlaying() const
{
    return m_audioManager ? m_audioManager->isPlaying() : false;
}

qreal AudioPlayerView::volume() const
{
    return m_audioManager ? m_audioManager->volume() : 1.0;
}

void AudioPlayerView::setVolume(qreal volume)
{
    if (m_audioManager) {
        m_audioManager->setVolume(volume);
    }
}

void AudioPlayerView::play()
{
    if (m_audioManager && m_audioManager->currentClip()) {
        m_audioManager->playClip(m_audioManager->currentClip()->id());
    }
}

void AudioPlayerView::pause()
{
    if (m_audioManager && m_audioManager->currentClip()) {
        m_audioManager->pauseClip(m_audioManager->currentClip()->id());
    }
}

void AudioPlayerView::stop()
{
    if (m_audioManager) {
        m_audioManager->stopAll();
    }
}

void AudioPlayerView::seekTo(qreal position)
{
    if (m_audioManager) {
        m_audioManager->seekTo(position);
    }
}

void AudioPlayerView::togglePlayPause()
{
    if (isPlaying()) {
        pause();
    } else {
        play();
    }
}

void AudioPlayerView::toggleMute()
{
    if (m_audioManager) {
        qreal currentVol = m_audioManager->volume();
        if (currentVol > 0) {
            m_savedVolume = currentVol;
            m_audioManager->setVolume(0);
        } else {
            m_audioManager->setVolume(m_savedVolume);
        }
    }
}

QString AudioPlayerView::formatTime(qreal seconds) const
{
    return m_audioManager ? m_audioManager->formatTime(seconds) : "0:00.00";
}

void AudioPlayerView::onCurrentClipChanged()
{
    emit currentTitleChanged();
    emit currentDurationChanged();
}

void AudioPlayerView::onPlayingStateChanged()
{
    emit isPlayingChanged();
}
