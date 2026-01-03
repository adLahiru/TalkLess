#ifndef SOUNDBOARDVIEW_H
#define SOUNDBOARDVIEW_H

#include "../controllers/audiomanager.h"
#include "../controllers/hotkeymanager.h"
#include "../models/soundboardsection.h"

#include <QList>
#include <QObject>
#include <QQmlEngine>

class SoundboardView : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(AudioManager* audioManager READ audioManager CONSTANT)
    Q_PROPERTY(HotkeyManager* hotkeyManager READ hotkeyManager CONSTANT)
    Q_PROPERTY(QList<SoundboardSection*> sections READ sections NOTIFY sectionsChanged)
    Q_PROPERTY(SoundboardSection* currentSection READ currentSection NOTIFY currentSectionChanged)
    Q_PROPERTY(SoundboardSection* activeSection READ activeSection NOTIFY activeSectionChanged)
    Q_PROPERTY(QList<AudioClip*> currentSectionClips READ currentSectionClips NOTIFY currentSectionClipsChanged)
    Q_PROPERTY(QString clipboardClipId READ clipboardClipId NOTIFY clipboardChanged)
    Q_PROPERTY(bool hasClipboard READ hasClipboard NOTIFY clipboardChanged)

public:
    explicit SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject* parent = nullptr);

    AudioManager* audioManager() const { return m_audioManager; }
    HotkeyManager* hotkeyManager() const { return m_hotkeyManager; }
    QList<SoundboardSection*> sections() const { return m_sections; }
    SoundboardSection* currentSection() const { return m_currentSection; }
    SoundboardSection* activeSection() const { return m_activeSection; }
    QList<AudioClip*> currentSectionClips() const;
    QString clipboardClipId() const { return m_clipboardClipId; }
    bool hasClipboard() const { return !m_clipboardClipId.isEmpty(); }

    // UI-specific methods
    Q_INVOKABLE void playAudioInSlot(int slotIndex);
    Q_INVOKABLE void stopAllAudio();
    Q_INVOKABLE QString getAudioClipInfo(int slotIndex) const;

    // Section management methods
    Q_INVOKABLE SoundboardSection* addSection(const QString& name);
    Q_INVOKABLE void deleteSection(const QString& sectionId);
    Q_INVOKABLE void renameSection(const QString& sectionId, const QString& newName);
    Q_INVOKABLE void selectSection(const QString& sectionId);
    Q_INVOKABLE void setActiveSection(const QString& sectionId);
    Q_INVOKABLE SoundboardSection* getSection(const QString& sectionId) const;

    // Clip clipboard (copy/paste)
    Q_INVOKABLE void copyClip(const QString& clipId);
    Q_INVOKABLE bool pasteClip();
    Q_INVOKABLE void clearClipboard();

    // Settings persistence
    Q_INVOKABLE void saveSoundboardData();
    Q_INVOKABLE void loadSoundboardData();

signals:
    void audioClipAdded(int slotIndex);
    void audioClipRemoved(int slotIndex);
    void playbackStateChanged(int slotIndex, bool isPlaying);
    void sectionsChanged();
    void currentSectionChanged();
    void activeSectionChanged();
    void sectionAdded(const QString& sectionId);
    void sectionDeleted(const QString& sectionId);
    void sectionRenamed(const QString& sectionId, const QString& newName);
    void currentSectionClipsChanged();
    void clipboardChanged();
    void clipPasted(const QString& clipId, const QString& sectionId);

private slots:
    void onClipFinished(const QString& clipId);
    void onAudioError(const QString& message);

private:
    AudioManager* m_audioManager;
    HotkeyManager* m_hotkeyManager;
    QList<SoundboardSection*> m_sections;
    SoundboardSection* m_currentSection = nullptr;
    SoundboardSection* m_activeSection = nullptr;
    QString m_clipboardClipId;

    void initializeDefaultSections();
};

#endif // SOUNDBOARDVIEW_H
