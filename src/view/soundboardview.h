#ifndef SOUNDBOARDVIEW_H
#define SOUNDBOARDVIEW_H

#include <QObject>
#include <QQmlEngine>
#include <QList>
#include "../controllers/audiomanager.h"
#include "../controllers/hotkeymanager.h"
#include "../models/soundboardsection.h"

class SoundboardView : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(AudioManager* audioManager READ audioManager CONSTANT)
    Q_PROPERTY(HotkeyManager* hotkeyManager READ hotkeyManager CONSTANT)
    Q_PROPERTY(QList<SoundboardSection*> sections READ sections NOTIFY sectionsChanged)
    Q_PROPERTY(SoundboardSection* currentSection READ currentSection NOTIFY currentSectionChanged)

public:
    explicit SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject *parent = nullptr);

    AudioManager* audioManager() const { return m_audioManager; }
    HotkeyManager* hotkeyManager() const { return m_hotkeyManager; }
    QList<SoundboardSection*> sections() const { return m_sections; }
    SoundboardSection* currentSection() const { return m_currentSection; }

    // UI-specific methods
    Q_INVOKABLE void playAudioInSlot(int slotIndex);
    Q_INVOKABLE void stopAllAudio();
    Q_INVOKABLE QString getAudioClipInfo(int slotIndex) const;

    // Section management methods
    Q_INVOKABLE SoundboardSection* addSection(const QString &name);
    Q_INVOKABLE void deleteSection(const QString &sectionId);
    Q_INVOKABLE void renameSection(const QString &sectionId, const QString &newName);
    Q_INVOKABLE void selectSection(const QString &sectionId);
    Q_INVOKABLE SoundboardSection* getSection(const QString &sectionId) const;

signals:
    void audioClipAdded(int slotIndex);
    void audioClipRemoved(int slotIndex);
    void playbackStateChanged(int slotIndex, bool isPlaying);
    void sectionsChanged();
    void currentSectionChanged();
    void sectionAdded(const QString &sectionId);
    void sectionDeleted(const QString &sectionId);
    void sectionRenamed(const QString &sectionId, const QString &newName);

private slots:
    void onClipFinished(const QString& clipId);
    void onAudioError(const QString& message);

private:
    AudioManager* m_audioManager;
    HotkeyManager* m_hotkeyManager;
    QList<SoundboardSection*> m_sections;
    SoundboardSection* m_currentSection = nullptr;

    void initializeDefaultSections();
};

#endif // SOUNDBOARDVIEW_H
