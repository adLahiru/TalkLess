#include "soundboardview.h"
#include <QDebug>

SoundboardView::SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject *parent)
    : QObject(parent)
    , m_audioManager(audioMgr)
    , m_hotkeyManager(hotkeyMgr)
{
    // Connect audio manager signals to view signals
    connect(m_audioManager, &AudioManager::clipFinished, 
            this, &SoundboardView::onClipFinished);
    connect(m_audioManager, &AudioManager::error, 
            this, &SoundboardView::onAudioError);
    
    qDebug() << "SoundboardView initialized";
}

void SoundboardView::playAudioInSlot(int slotIndex)
{
    if (m_audioManager && slotIndex >= 0 && slotIndex < m_audioManager->audioClips().count()) {
        AudioClip* clip = m_audioManager->audioClips().at(slotIndex);
        if (clip) {
            m_audioManager->playClip(clip->id());
        }
    }
}

void SoundboardView::stopAllAudio()
{
    if (m_audioManager) {
        m_audioManager->stopAll();
    }
}

QString SoundboardView::getAudioClipInfo(int slotIndex) const
{
    if (m_audioManager && slotIndex >= 0 && slotIndex < m_audioManager->audioClips().count()) {
        AudioClip* clip = m_audioManager->audioClips().at(slotIndex);
        if (clip) {
            return QString("Title: %1, Hotkey: %2, Duration: %3s")
                .arg(clip->title())
                .arg(clip->hotkey())
                .arg(clip->duration());
        }
    }
    return "No clip in slot";
}

void SoundboardView::onClipFinished(const QString& clipId)
{
    qDebug() << "Clip finished:" << clipId;
    
    // Find the slot index and emit signal
    for (int i = 0; i < m_audioManager->audioClips().count(); ++i) {
        if (m_audioManager->audioClips().at(i)->id() == clipId) {
            emit playbackStateChanged(i, false);
            break;
        }
    }
}

void SoundboardView::onAudioError(const QString& message)
{
    qWarning() << "Audio error:" << message;
}
