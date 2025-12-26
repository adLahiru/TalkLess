#ifndef AUDIOMANAGER_H
#define AUDIOMANAGER_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QList>
#include <QMap>
#include <QUrl>
#include "../models/audioclip.h"
#include "../models/audioEngine.h"
#include <miniaudio.h>

class AudioManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QList<AudioClip*> audioClips READ audioClips NOTIFY audioClipsChanged)
    Q_PROPERTY(AudioClip* currentClip READ currentClip NOTIFY currentClipChanged)
    Q_PROPERTY(qreal currentPosition READ currentPosition NOTIFY currentPositionChanged)
    Q_PROPERTY(qreal currentDuration READ currentDuration NOTIFY currentDurationChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QStringList inputDevices READ inputDevices NOTIFY inputDevicesChanged)
    Q_PROPERTY(QStringList outputDevices READ outputDevices NOTIFY outputDevicesChanged)
    Q_PROPERTY(QString currentInputDevice READ currentInputDevice WRITE setCurrentInputDevice NOTIFY currentInputDeviceChanged)
    Q_PROPERTY(QString currentOutputDevice READ currentOutputDevice WRITE setCurrentOutputDevice NOTIFY currentOutputDeviceChanged)
    Q_PROPERTY(QString secondaryOutputDevice READ secondaryOutputDevice WRITE setSecondaryOutputDevice NOTIFY secondaryOutputDeviceChanged)
    Q_PROPERTY(bool secondaryOutputEnabled READ secondaryOutputEnabled WRITE setSecondaryOutputEnabled NOTIFY secondaryOutputEnabledChanged)
    Q_PROPERTY(bool inputDeviceEnabled READ inputDeviceEnabled WRITE setInputDeviceEnabled NOTIFY inputDeviceEnabledChanged)
    Q_PROPERTY(QList<QObject*> audioClips READ audioClipsAsObjects NOTIFY audioClipsChanged)

public:
    explicit AudioManager(AudioEngine* audioEngine, QObject *parent = nullptr);
    ~AudioManager();

    QList<AudioClip*> audioClips() const { return m_audioClips; }
    QList<QObject*> audioClipsAsObjects() const;
    AudioClip* currentClip() const { return m_currentClip; }
    qreal currentPosition() const;
    qreal currentDuration() const;
    bool isPlaying() const;
    qreal volume() const { return m_volume; }
    void setVolume(qreal volume);
    
    // Device management methods
    QStringList inputDevices() const;
    QStringList outputDevices() const;
    QString currentInputDevice() const;
    QString currentOutputDevice() const;
    QString secondaryOutputDevice() const;
    bool secondaryOutputEnabled() const;
    bool inputDeviceEnabled() const;
    Q_INVOKABLE void setCurrentInputDevice(const QString &device);
    Q_INVOKABLE void setCurrentOutputDevice(const QString &device);
    Q_INVOKABLE void setSecondaryOutputDevice(const QString &device);
    Q_INVOKABLE void setSecondaryOutputEnabled(bool enabled);
    Q_INVOKABLE void setInputDeviceEnabled(bool enabled);

    // Invokable methods for QML
    Q_INVOKABLE void loadAudioFile(const QString &clipId, const QUrl &filePath);
    Q_INVOKABLE void playClip(const QString &clipId);
    Q_INVOKABLE void pauseClip(const QString &clipId);
    Q_INVOKABLE void stopClip(const QString &clipId);
    Q_INVOKABLE void stopAll();
    Q_INVOKABLE void seekTo(qreal position);
    Q_INVOKABLE AudioClip* addClip(const QString &title, const QUrl &filePath, const QString &hotkey = "", const QString &sectionId = "");
    Q_INVOKABLE void removeClip(const QString &clipId);
    Q_INVOKABLE AudioClip* getClip(const QString &clipId);
    Q_INVOKABLE void playClipByHotkey(const QString &hotkey);
    Q_INVOKABLE QString formatTime(qreal seconds) const;
    Q_INVOKABLE void refreshAudioDevices();
    Q_INVOKABLE void testPlayback();
    // Volume mixer controls
    Q_INVOKABLE qreal masterVolume() const;
    Q_INVOKABLE void setMasterVolume(qreal linear);
    Q_INVOKABLE qreal micVolume() const;
    Q_INVOKABLE void setMicVolume(qreal linear);
    Q_INVOKABLE void setClipVolume(const QString &clipId, qreal volume);

signals:
    void audioClipsChanged();
    void currentClipChanged();
    void currentPositionChanged();
    void currentDurationChanged();
    void isPlayingChanged();
    void volumeChanged();
    void clipFinished(const QString &clipId);
    void error(const QString &message);
    void inputDevicesChanged();
    void outputDevicesChanged();
    void currentInputDeviceChanged();
    void currentOutputDeviceChanged();
    void secondaryOutputDeviceChanged();
    void secondaryOutputEnabledChanged();
    void inputDeviceEnabledChanged();

private slots:
    void onPositionChanged(qint64 position);
    void onDurationChanged(qint64 duration);
    void onPlaybackStateChanged(QMediaPlayer::PlaybackState state);
    void onMediaStatusChanged(QMediaPlayer::MediaStatus status);
    void onErrorOccurred(QMediaPlayer::Error error, const QString &errorString);

private:
    QList<AudioClip*> m_audioClips;
    QMap<QString, QMediaPlayer*> m_players;
    QMap<QString, QAudioOutput*> m_audioOutputs;
    QMap<QString, QMediaPlayer*> m_secondaryPlayers;
    QMap<QString, QAudioOutput*> m_secondaryAudioOutputs;
    AudioClip* m_currentClip;
    qreal m_volume;
    QString m_currentPlayingId;
    
    // Audio device management
    QStringList m_inputDevices;
    QStringList m_outputDevices;
    QString m_currentInputDevice;
    QString m_currentOutputDevice;
    QString m_secondaryOutputDevice;
    bool m_secondaryOutputEnabled;
    bool m_inputDeviceEnabled;

    // AudioEngine integration
    AudioEngine* m_audioEngine;


    void initializePlayer(const QString &clipId);
    void cleanupPlayer(const QString &clipId);
    void updateOutputDeviceForAllPlayers(const QString &deviceName);
    void updateSecondaryOutputsForAllPlayers(const QString &deviceName);
};

#endif // AUDIOMANAGER_H
