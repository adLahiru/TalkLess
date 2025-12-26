#include "soundboardview.h"
#include <QDebug>
#include <QUuid>
#include <QSettings>
#include "../models/audioclip.h"

SoundboardView::SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject *parent)
    : QObject(parent)
    , m_audioManager(audioMgr)
    , m_hotkeyManager(hotkeyMgr)
{
    try {
        qDebug() << "SoundboardView: Starting initialization...";
        
        // Connect audio manager signals to view signals
        connect(m_audioManager, &AudioManager::clipFinished, 
                this, &SoundboardView::onClipFinished);
        connect(m_audioManager, &AudioManager::error, 
                this, &SoundboardView::onAudioError);
        
        // Connect to audioClipsChanged to update currentSectionClips
        connect(m_audioManager, &AudioManager::audioClipsChanged, this, &SoundboardView::currentSectionClipsChanged);
        
        qDebug() << "SoundboardView: Signals connected";
        
        // Initialize default sections first
        initializeDefaultSections();
        qDebug() << "SoundboardView: Default sections initialized";
        
        // Load saved soundboard data (will replace defaults if available)
        loadSoundboardData();
        qDebug() << "SoundboardView: Soundboard data loaded";
        
        qDebug() << "SoundboardView initialized successfully";
    } catch (const std::exception& e) {
        qCritical() << "SoundboardView: Initialization failed! Exception:" << e.what();
        throw; // Re-throw to be caught by main.cpp
    } catch (...) {
        qCritical() << "SoundboardView: Initialization failed! Unknown exception";
        throw; // Re-throw to be caught by main.cpp
    }
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
    
    // Set as active section if it's the first one or no active section exists
    if (m_sections.count() == 1 || !m_activeSection) {
        m_activeSection = section;
        emit activeSectionChanged();
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
    try {
        qDebug() << "SoundboardView: selectSection called with ID:" << sectionId;
        
        // Handle empty section ID
        if (sectionId.isEmpty()) {
            qWarning() << "SoundboardView: Empty section ID provided, selecting first available section";
            if (!m_sections.isEmpty()) {
                SoundboardSection* firstSection = m_sections.first();
                qDebug() << "SoundboardView: Using first section:" << firstSection->id();
                selectSection(firstSection->id());
            } else {
                qWarning() << "SoundboardView: No sections available to select";
                return;
            }
            return;
        }
        
        SoundboardSection* section = getSection(sectionId);
        if (!section) {
            qWarning() << "SoundboardView: Section not found:" << sectionId;
            // Try to select first available section instead
            if (!m_sections.isEmpty()) {
                section = m_sections.first();
                qWarning() << "SoundboardView: Using fallback section:" << section->id();
            } else {
                qWarning() << "SoundboardView: No sections available, cannot select";
                return;
            }
        }
        
        // Don't do anything if selecting the same section
        if (m_currentSection == section) {
            qDebug() << "SoundboardView: Section already selected:" << sectionId;
            return;
        }
        
        // Deselect previous section
        if (m_currentSection) {
            try {
                qDebug() << "SoundboardView: Deselecting previous section:" << m_currentSection->id();
                m_currentSection->setIsSelected(false);
            } catch (...) {
                qWarning() << "SoundboardView: Failed to deselect previous section";
            }
        }
        
        // Select new section
        m_currentSection = section;
        try {
            qDebug() << "SoundboardView: Selecting new section:" << m_currentSection->id();
            m_currentSection->setIsSelected(true);
        } catch (...) {
            qWarning() << "SoundboardView: Failed to select new section";
            m_currentSection = nullptr; // Reset to avoid inconsistent state
            return;
        }
        
        emit currentSectionChanged();
        emit currentSectionClipsChanged();
        qDebug() << "SoundboardView: Section selection completed for:" << sectionId;
        
    } catch (const std::exception& e) {
        qCritical() << "SoundboardView: Exception in selectSection:" << e.what();
        m_currentSection = nullptr; // Reset to safe state
    } catch (...) {
        qCritical() << "SoundboardView: Unknown exception in selectSection";
        m_currentSection = nullptr; // Reset to safe state
    }
}

void SoundboardView::setActiveSection(const QString &sectionId)
{
    SoundboardSection* section = getSection(sectionId);
    if (!section) {
        qWarning() << "SoundboardView: Cannot set active section, section not found:" << sectionId;
        return;
    }
    
    if (m_activeSection == section) {
        return;
    }
    
    m_activeSection = section;
    emit activeSectionChanged();
    
    // Save the active section
    saveSoundboardData();
    
    qDebug() << "SoundboardView: Active section set to:" << section->name();
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

void SoundboardView::saveSoundboardData()
{
    QSettings settings("TalkLess", "Soundboard");
    
    // Save sections
    settings.beginGroup("sections");
    settings.remove(""); // Clear existing sections
    for (int i = 0; i < m_sections.size(); ++i) {
        SoundboardSection* section = m_sections[i];
        if (section) {
            QString sectionKey = QString("section_%1").arg(i);
            settings.beginGroup(sectionKey);
            settings.setValue("id", section->id());
            settings.setValue("name", section->name());
            settings.setValue("isSelected", section->isSelected());
            settings.endGroup();
        }
    }
    settings.endGroup();
    
    // Save current section ID
    settings.setValue("currentSectionId", m_currentSection ? m_currentSection->id() : "");
    
    // Save active section ID
    settings.setValue("activeSectionId", m_activeSection ? m_activeSection->id() : "");
    
    settings.sync();
    qDebug() << "SoundboardView: Saved" << m_sections.size() << "sections";
}

void SoundboardView::loadSoundboardData()
{
    try {
        qDebug() << "SoundboardView: Starting to load soundboard data...";
        QSettings settings("TalkLess", "Soundboard");
        
        // Load sections
        settings.beginGroup("sections");
        QStringList sectionKeys = settings.childGroups();
        qDebug() << "SoundboardView: Found" << sectionKeys.size() << "section keys";
        
        // Only load sections if we have saved data (don't clear defaults on first run)
        if (!sectionKeys.isEmpty()) {
            qDebug() << "SoundboardView: Loading saved sections...";
            // Clear default sections only if we have saved data
            qDeleteAll(m_sections);
            m_sections.clear();
            
            for (const QString& sectionKey : sectionKeys) {
                try {
                    qDebug() << "SoundboardView: Loading section key:" << sectionKey;
                    settings.beginGroup(sectionKey);
                    QString sectionId = settings.value("id").toString();
                    QString sectionName = settings.value("name").toString();
                    bool isSelected = settings.value("isSelected", false).toBool();
                    settings.endGroup();
                    
                    qDebug() << "SoundboardView: Section data - ID:" << sectionId << "Name:" << sectionName;
                    
                    if (!sectionId.isEmpty() && !sectionName.isEmpty()) {
                        SoundboardSection* section = new SoundboardSection(this);
                        section->setId(sectionId);
                        section->setName(sectionName);
                        section->setIsSelected(isSelected);
                        m_sections.append(section);
                        
                        qDebug() << "SoundboardView: Loaded section:" << sectionName << "ID:" << sectionId;
                    }
                } catch (const std::exception& e) {
                    qWarning() << "SoundboardView: Failed to load section with key:" << sectionKey << "Exception:" << e.what();
                    continue; // Skip this section and continue with others
                } catch (...) {
                    qWarning() << "SoundboardView: Failed to load section with key:" << sectionKey;
                    continue; // Skip this section and continue with others
                }
            }
            
        }
        settings.endGroup();
        
        // Restore active section (read from root, not from sections group)
        try {
            qDebug() << "SoundboardView: Restoring active section...";
            QString activeSectionId = settings.value("activeSectionId").toString();
            qDebug() << "SoundboardView: Active section ID from settings:" << activeSectionId;
            if (!activeSectionId.isEmpty()) {
                m_activeSection = getSection(activeSectionId);
            }
            if (!m_activeSection && !m_sections.isEmpty()) {
                m_activeSection = m_sections.first();
            }
            
            // Set current section to active section (app opens with active soundboard displayed)
            if (m_activeSection) {
                selectSection(m_activeSection->id());
            } else if (!m_sections.isEmpty()) {
                selectSection(m_sections.first()->id());
            }
            
            emit sectionsChanged();
            emit currentSectionChanged();
            emit activeSectionChanged();
            qDebug() << "SoundboardView: Active section restored:" << (m_activeSection ? m_activeSection->name() : "none");
        } catch (const std::exception& e) {
            qWarning() << "SoundboardView: Failed to restore active section, using first available. Exception:" << e.what();
            if (!m_sections.isEmpty()) {
                m_activeSection = m_sections.first();
                selectSection(m_sections.first()->id());
            }
        } catch (...) {
            qWarning() << "SoundboardView: Failed to restore active section, using first available";
            if (!m_sections.isEmpty()) {
                m_activeSection = m_sections.first();
                selectSection(m_sections.first()->id());
            }
        }
        
        qDebug() << "SoundboardView: Loaded" << m_sections.size() << "sections successfully";
        
    } catch (const std::exception& e) {
        qCritical() << "SoundboardView: Failed to load soundboard data! Exception:" << e.what();
        // Continue with default sections - don't crash the application
    } catch (...) {
        qCritical() << "SoundboardView: Failed to load soundboard data! Unknown exception";
        // Continue with default sections - don't crash the application
    }
}
