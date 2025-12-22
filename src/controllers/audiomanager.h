#ifndef AUDIOMANAGER_H
#define AUDIOMANAGER_H

#include <QObject>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QList>
#include <QMap>
#include <QUrl>
#include "../models/audioclip.h"

class AudioManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QList<AudioClip*> audioClips READ audioClips NOTIFY audioClipsChanged)
    Q_PROPERTY(AudioClip* currentClip READ currentClip NOTIFY currentClipChanged)
    Q_PROPERTY(qreal currentPosition READ currentPosition NOTIFY currentPositionChanged)
    Q_PROPERTY(qreal currentDuration READ currentDuration NOTIFY currentDurationChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    explicit AudioManager(QObject *parent = nullptr);
    ~AudioManager();

    QList<AudioClip*> audioClips() const { return m_audioClips; }
    AudioClip* currentClip() const { return m_currentClip; }
    qreal currentPosition() const;
    qreal currentDuration() const;
    bool isPlaying() const;
    qreal volume() const { return m_volume; }
    void setVolume(qreal volume);

    // Invokable methods for QML
    Q_INVOKABLE void loadAudioFile(const QString &clipId, const QUrl &filePath);
    Q_INVOKABLE void playClip(const QString &clipId);
    Q_INVOKABLE void pauseClip(const QString &clipId);
    Q_INVOKABLE void stopClip(const QString &clipId);
    Q_INVOKABLE void stopAll();
    Q_INVOKABLE void seekTo(qreal position);
    Q_INVOKABLE AudioClip* addClip(const QString &title, const QUrl &filePath, const QString &hotkey = "");
    Q_INVOKABLE void removeClip(const QString &clipId);
    Q_INVOKABLE AudioClip* getClip(const QString &clipId);
    Q_INVOKABLE void playClipByHotkey(const QString &hotkey);
    Q_INVOKABLE QString formatTime(qreal seconds) const;

signals:
    void audioClipsChanged();
    void currentClipChanged();
    void currentPositionChanged();
    void currentDurationChanged();
    void isPlayingChanged();
    void volumeChanged();
    void clipFinished(const QString &clipId);
    void error(const QString &message);

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
    AudioClip* m_currentClip;
    qreal m_volume;
    QString m_currentPlayingId;

    void initializePlayer(const QString &clipId);
    void cleanupPlayer(const QString &clipId);
};

#endif // AUDIOMANAGER_H
