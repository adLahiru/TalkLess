#ifndef AUDIOPLAYERVIEW_H
#define AUDIOPLAYERVIEW_H

#include <QObject>
#include <QQmlEngine>
#include "../controllers/audiomanager.h"

class AudioPlayerView : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentTitleChanged)
    Q_PROPERTY(qreal currentPosition READ currentPosition NOTIFY currentPositionChanged)
    Q_PROPERTY(qreal currentDuration READ currentDuration NOTIFY currentDurationChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY isPlayingChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

public:
    explicit AudioPlayerView(AudioManager* audioMgr, QObject *parent = nullptr);

    QString currentTitle() const;
    qreal currentPosition() const;
    qreal currentDuration() const;
    bool isPlaying() const;
    qreal volume() const;
    void setVolume(qreal volume);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seekTo(qreal position);
    Q_INVOKABLE void togglePlayPause();
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE QString formatTime(qreal seconds) const;

signals:
    void currentTitleChanged();
    void currentPositionChanged();
    void currentDurationChanged();
    void isPlayingChanged();
    void volumeChanged();

private slots:
    void onCurrentClipChanged();
    void onPlayingStateChanged();

private:
    AudioManager* m_audioManager;
    qreal m_savedVolume;
};

#endif // AUDIOPLAYERVIEW_H
