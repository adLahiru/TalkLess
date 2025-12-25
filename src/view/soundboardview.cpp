#include "soundboardview.h"
#include <QDebug>
#include <QUuid>
#include "../models/audioclip.h"

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
    
    // Connect to audioClipsChanged to update currentSectionClips
    connect(m_audioManager, &AudioManager::audioClipsChanged, this, &SoundboardView::currentSectionClipsChanged);
    
    // Initialize default sections
    initializeDefaultSections();
    
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

void SoundboardView::initializeDefaultSections()
{
    // Create a default section
    addSection("default");
}

QList<AudioClip*> SoundboardView::currentSectionClips() const
{
    QList<AudioClip*> filteredClips;
    
    if (!m_currentSection) {
        return filteredClips;
    }
    
    QString currentSectionId = m_currentSection->id();
    
    // Filter clips that belong to the current section
    for (AudioClip* clip : m_audioManager->audioClips()) {
        if (clip && clip->sectionId() == currentSectionId) {
            filteredClips.append(clip);
        }
    }
    
    return filteredClips;
}

SoundboardSection* SoundboardView::addSection(const QString &name)
{
    QString sectionId = QUuid::createUuid().toString();
    
    SoundboardSection* section = new SoundboardSection(this);
    section->setId(sectionId);
    section->setName(name);
    
    m_sections.append(section);
    
    // Select the new section if it's the first one or no section is selected
    if (m_sections.count() == 1 || !m_currentSection) {
        selectSection(sectionId);
    }
    
    emit sectionsChanged();
    emit sectionAdded(sectionId);
    
    qDebug() << "Added section:" << sectionId << name;
    return section;
}

void SoundboardView::deleteSection(const QString &sectionId)
{
    SoundboardSection* section = getSection(sectionId);
    if (!section) {
        qWarning() << "Section not found:" << sectionId;
        return;
    }
    
    // Don't allow deleting the last section
    if (m_sections.count() <= 1) {
        qWarning() << "Cannot delete the last section";
        return;
    }
    
    // If deleting the current section, select another one
    bool wasSelected = (m_currentSection == section);
    
    m_sections.removeOne(section);
    
    if (wasSelected && !m_sections.isEmpty()) {
        selectSection(m_sections.first()->id());
    }
    
    emit sectionsChanged();
    emit sectionDeleted(sectionId);
    
    qDebug() << "Deleted section:" << sectionId;
    section->deleteLater();
}

void SoundboardView::renameSection(const QString &sectionId, const QString &newName)
{
    SoundboardSection* section = getSection(sectionId);
    if (!section) {
        qWarning() << "Section not found:" << sectionId;
        return;
    }
    
    if (newName.isEmpty()) {
        qWarning() << "New name cannot be empty";
        return;
    }
    
    section->setName(newName);
    emit sectionsChanged();
    emit sectionRenamed(sectionId, newName);
    
    qDebug() << "Renamed section:" << sectionId << "to" << newName;
}

void SoundboardView::selectSection(const QString &sectionId)
{
    SoundboardSection* section = getSection(sectionId);
    if (!section) {
        qWarning() << "Section not found:" << sectionId;
        return;
    }
    
    // Deselect previous section
    if (m_currentSection) {
        m_currentSection->setIsSelected(false);
    }
    
    // Select new section
    m_currentSection = section;
    m_currentSection->setIsSelected(true);
    
    emit currentSectionChanged();
    emit currentSectionClipsChanged();
    
    qDebug() << "Selected section:" << sectionId;
}

SoundboardSection* SoundboardView::getSection(const QString &sectionId) const
{
    for (SoundboardSection* section : m_sections) {
        if (section->id() == sectionId) {
            return section;
        }
    }
    return nullptr;
}
