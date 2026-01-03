#include "soundboardview.h"

#include "../models/audioclip.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUuid>

SoundboardView::SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject* parent)
    : QObject(parent), m_audioManager(audioMgr), m_hotkeyManager(hotkeyMgr)
{
    try {
        qDebug() << "SoundboardView: Starting initialization...";

        // Connect audio manager signals to view signals
        connect(m_audioManager, &AudioManager::clipFinished, this, &SoundboardView::onClipFinished);
        connect(m_audioManager, &AudioManager::error, this, &SoundboardView::onAudioError);

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
    if (m_audioManager != nullptr && slotIndex >= 0 && slotIndex < m_audioManager->audioClips().count()) {
        AudioClip* clip = m_audioManager->audioClips().at(slotIndex);
        if (clip != nullptr) {
            m_audioManager->playClip(clip->id());
        }
    }
}

void SoundboardView::stopAllAudio()
{
    if (m_audioManager != nullptr) {
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

    if (m_currentSection == nullptr) {
        qDebug() << "currentSectionClips: m_currentSection is null";
        return filteredClips;
    }

    QString currentSectionId = m_currentSection->id();
    qDebug() << "currentSectionClips: Looking for clips in section:" << currentSectionId << "("
             << m_currentSection->name() << ")";
    qDebug() << "  Total clips in audioManager:" << m_audioManager->audioClips().count();

    // Filter clips that belong to the current section
    for (AudioClip* clip : m_audioManager->audioClips()) {
        if (clip != nullptr) {
            qDebug() << "  Clip:" << clip->title() << "sectionId:" << clip->sectionId()
                     << "matches:" << (clip->sectionId() == currentSectionId);
            if (clip->sectionId() == currentSectionId) {
                filteredClips.append(clip);
            }
        }
    }

    qDebug() << "  Filtered clips count:" << filteredClips.count();
    return filteredClips;
}

SoundboardSection* SoundboardView::addSection(const QString& name)
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

void SoundboardView::deleteSection(const QString& sectionId)
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

void SoundboardView::renameSection(const QString& sectionId, const QString& newName)
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

void SoundboardView::selectSection(const QString& sectionId)
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

void SoundboardView::setActiveSection(const QString& sectionId)
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

SoundboardSection* SoundboardView::getSection(const QString& sectionId) const
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
    try {
        // Get app data path
        QString appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir dir(appDataPath);
        if (!dir.exists()) {
            dir.mkpath(appDataPath);
        }
        QString filePath = dir.filePath("soundboard_data.json");

        qDebug() << "SoundboardView: Saving soundboard data to:" << filePath;

        QJsonObject rootObject;

        // Add metadata
        QJsonObject metadata;
        metadata["version"] = "1.0";
        metadata["appName"] = "TalkLess";
        metadata["saveDate"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        rootObject["metadata"] = metadata;

        // Save sections
        QJsonArray sectionsArray;
        for (SoundboardSection* section : m_sections) {
            if (section != nullptr) {
                QJsonObject sectionObj;
                sectionObj["id"] = section->id();
                sectionObj["name"] = section->name();
                sectionObj["isSelected"] = section->isSelected();
                sectionsArray.append(sectionObj);
            }
        }
        rootObject["sections"] = sectionsArray;

        // Save audio clips (from AudioManager)
        QJsonArray clipsArray;
        for (AudioClip* clip : m_audioManager->audioClips()) {
            if (clip != nullptr) {
                QJsonObject clipObj;
                clipObj["id"] = clip->id();
                clipObj["title"] = clip->title();
                clipObj["filePath"] = clip->filePath().toString();
                clipObj["hotkey"] = clip->hotkey();
                clipObj["volume"] = clip->volume();
                clipObj["trimStart"] = clip->trimStart();
                clipObj["trimEnd"] = clip->trimEnd();
                clipObj["sectionId"] = clip->sectionId();
                clipObj["imagePath"] = clip->imagePath();
                clipsArray.append(clipObj);
            }
        }
        rootObject["audioClips"] = clipsArray;

        // Save current/active section IDs
        rootObject["currentSectionId"] = m_currentSection != nullptr ? m_currentSection->id() : "";
        rootObject["activeSectionId"] = m_activeSection != nullptr ? m_activeSection->id() : "";

        // Write to file
        QJsonDocument doc(rootObject);
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            qCritical() << "SoundboardView: Failed to open file for writing:" << filePath;
            return;
        }

        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();

        qDebug() << "SoundboardView: Saved" << m_sections.size() << "sections and"
                 << m_audioManager->audioClips().size() << "clips";

    } catch (const std::exception& e) {
        qCritical() << "SoundboardView: Exception saving data:" << e.what();
    } catch (...) {
        qCritical() << "SoundboardView: Unknown exception saving data";
    }
}

void SoundboardView::loadSoundboardData()
{
    try {
        QString appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QString filePath = QDir(appDataPath).filePath("soundboard_data.json");

        qDebug() << "SoundboardView: Loading soundboard data from:" << filePath;

        QFile file(filePath);
        if (!file.exists()) {
            qDebug() << "SoundboardView: No saved data file found, using defaults";
            return;
        }

        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "SoundboardView: Failed to open data file:" << filePath;
            return;
        }

        QByteArray jsonData = file.readAll();
        file.close();

        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(jsonData, &parseError);

        if (parseError.error != QJsonParseError::NoError) {
            qWarning() << "SoundboardView: JSON parse error:" << parseError.errorString();
            return;
        }

        if (!doc.isObject()) {
            qWarning() << "SoundboardView: Invalid JSON format";
            return;
        }

        QJsonObject rootObject = doc.object();

        // Load sections
        if (rootObject.contains("sections")) {
            QJsonArray sectionsArray = rootObject["sections"].toArray();

            if (!sectionsArray.isEmpty()) {
                // Clear default sections
                qDeleteAll(m_sections);
                m_sections.clear();

                for (const QJsonValue& sectionVal : sectionsArray) {
                    QJsonObject sectionObj = sectionVal.toObject();
                    QString sectionId = sectionObj["id"].toString();
                    QString sectionName = sectionObj["name"].toString();
                    bool isSelected = sectionObj["isSelected"].toBool(false);

                    if (!sectionId.isEmpty() && !sectionName.isEmpty()) {
                        SoundboardSection* section = new SoundboardSection(this);
                        section->setId(sectionId);
                        section->setName(sectionName);
                        section->setIsSelected(isSelected);
                        m_sections.append(section);
                        qDebug() << "SoundboardView: Loaded section:" << sectionName;
                    }
                }
            }
        }

        // Load audio clips
        if (rootObject.contains("audioClips")) {
            QJsonArray clipsArray = rootObject["audioClips"].toArray();

            for (const QJsonValue& clipVal : clipsArray) {
                QJsonObject clipObj = clipVal.toObject();
                QString clipId = clipObj["id"].toString();
                QString title = clipObj["title"].toString();
                QString filePath = clipObj["filePath"].toString();
                QString hotkey = clipObj["hotkey"].toString();
                qreal volume = clipObj["volume"].toDouble(1.0);
                qreal trimStart = clipObj["trimStart"].toDouble(0.0);
                qreal trimEnd = clipObj["trimEnd"].toDouble(-1.0);
                QString sectionId = clipObj["sectionId"].toString();
                QString imagePath = clipObj["imagePath"].toString();

                if (!clipId.isEmpty() && !title.isEmpty() && !filePath.isEmpty()) {
                    // Check if clip already exists
                    bool exists = false;
                    for (AudioClip* c : m_audioManager->audioClips()) {
                        if (c != nullptr && c->id() == clipId) {
                            exists = true;
                            break;
                        }
                    }

                    if (!exists) {
                        AudioClip* clip = m_audioManager->addClip(title, QUrl(filePath), hotkey, sectionId);
                        if (clip != nullptr) {
                            clip->setVolume(volume);
                            clip->setTrimStart(trimStart);
                            clip->setTrimEnd(trimEnd);
                            if (!imagePath.isEmpty()) {
                                clip->setImagePath(imagePath);
                            }
                            qDebug() << "SoundboardView: Loaded clip:" << title << "in section:" << sectionId;
                        }
                    }
                }
            }
        }

        // Restore active section
        QString activeSectionId = rootObject["activeSectionId"].toString();
        if (!activeSectionId.isEmpty()) {
            m_activeSection = getSection(activeSectionId);
        }
        if (m_activeSection == nullptr && !m_sections.isEmpty()) {
            m_activeSection = m_sections.first();
        }

        // Set current section to active section
        if (m_activeSection != nullptr) {
            selectSection(m_activeSection->id());
        } else if (!m_sections.isEmpty()) {
            selectSection(m_sections.first()->id());
        }

        emit sectionsChanged();
        emit currentSectionChanged();
        emit activeSectionChanged();
        emit currentSectionClipsChanged();

        qDebug() << "SoundboardView: Loaded" << m_sections.size() << "sections and"
                 << m_audioManager->audioClips().size() << "clips successfully";

    } catch (const std::exception& e) {
        qCritical() << "SoundboardView: Exception loading data:" << e.what();
    } catch (...) {
        qCritical() << "SoundboardView: Unknown exception loading data";
    }
}

void SoundboardView::copyClip(const QString& clipId)
{
    qDebug() << "SoundboardView::copyClip - Copying clip:" << clipId;

    // Verify clip exists
    AudioClip* clip = nullptr;
    for (AudioClip* c : m_audioManager->audioClips()) {
        if (c && c->id() == clipId) {
            clip = c;
            break;
        }
    }

    if (clip) {
        m_clipboardClipId = clipId;
        qDebug() << "SoundboardView::copyClip - Copied to clipboard:" << clip->title();
        emit clipboardChanged();
    } else {
        qWarning() << "SoundboardView::copyClip - Clip not found:" << clipId;
    }
}

bool SoundboardView::pasteClip()
{
    qDebug() << "SoundboardView::pasteClip - START";
    qDebug() << "  Clipboard clip ID:" << m_clipboardClipId;

    if (m_clipboardClipId.isEmpty()) {
        qWarning() << "SoundboardView::pasteClip - Clipboard is empty";
        return false;
    }

    if (!m_currentSection) {
        qWarning() << "SoundboardView::pasteClip - No current section";
        return false;
    }

    // Find source clip
    AudioClip* sourceClip = nullptr;
    for (AudioClip* clip : m_audioManager->audioClips()) {
        if (clip && clip->id() == m_clipboardClipId) {
            sourceClip = clip;
            break;
        }
    }

    if (!sourceClip) {
        qWarning() << "SoundboardView::pasteClip - Source clip not found:" << m_clipboardClipId;
        return false;
    }

    QString targetSectionId = m_currentSection->id();
    qDebug() << "  Source clip:" << sourceClip->title();
    qDebug() << "  Target section:" << m_currentSection->name() << "(" << targetSectionId << ")";

    // Check if already exists in this section
    for (AudioClip* clip : m_audioManager->audioClips()) {
        if (clip && clip->sectionId() == targetSectionId && clip->filePath() == sourceClip->filePath()) {
            qDebug() << "SoundboardView::pasteClip - Audio already exists in this section";
            return false;
        }
    }

    // Create new clip with same properties
    AudioClip* newClip = m_audioManager->addClip(sourceClip->title(), sourceClip->filePath(),
                                                 "", // No hotkey for pasted clip
                                                 targetSectionId);

    if (!newClip) {
        qWarning() << "SoundboardView::pasteClip - Failed to create new clip";
        return false;
    }

    qDebug() << "  New clip created with ID:" << newClip->id();

    // Copy additional properties
    newClip->setVolume(sourceClip->volume());
    newClip->setImagePath(sourceClip->imagePath());
    newClip->setTrimStart(sourceClip->trimStart());
    newClip->setTrimEnd(sourceClip->trimEnd());

    // Emit signals
    emit clipPasted(newClip->id(), targetSectionId);
    emit currentSectionClipsChanged();

    // Save
    saveSoundboardData();
    m_audioManager->saveSettings();

    qDebug() << "SoundboardView::pasteClip - SUCCESS";
    return true;
}

void SoundboardView::clearClipboard()
{
    m_clipboardClipId.clear();
    emit clipboardChanged();
}
