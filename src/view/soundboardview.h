#ifndef SOUNDBOARDVIEW_H
#define SOUNDBOARDVIEW_H

#include <QObject>
#include <QQmlEngine>
#include "../controllers/audiomanager.h"
#include "../controllers/hotkeymanager.h"

class SoundboardView : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(AudioManager* audioManager READ audioManager CONSTANT)
    Q_PROPERTY(HotkeyManager* hotkeyManager READ hotkeyManager CONSTANT)

public:
    explicit SoundboardView(AudioManager* audioMgr, HotkeyManager* hotkeyMgr, QObject *parent = nullptr);

    AudioManager* audioManager() const { return m_audioManager; }
    HotkeyManager* hotkeyManager() const { return m_hotkeyManager; }

    // UI-specific methods
    Q_INVOKABLE void playAudioInSlot(int slotIndex);
    Q_INVOKABLE void stopAllAudio();
    Q_INVOKABLE QString getAudioClipInfo(int slotIndex) const;

signals:
    void audioClipAdded(int slotIndex);
    void audioClipRemoved(int slotIndex);
    void playbackStateChanged(int slotIndex, bool isPlaying);

private slots:
    void onClipFinished(const QString& clipId);
    void onAudioError(const QString& message);

private:
    AudioManager* m_audioManager;
    HotkeyManager* m_hotkeyManager;
};

#endif // SOUNDBOARDVIEW_H
