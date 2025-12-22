#include "audiomanager.h"
#include <QDebug>
#include <QUuid>

AudioManager::AudioManager(QObject *parent)
    : QObject(parent)
    , m_currentClip(nullptr)
    , m_volume(1.0)
{
    qDebug() << "AudioManager initialized";
}

AudioManager::~AudioManager()
{
    // Clean up all players
    for (auto it = m_players.begin(); it != m_players.end(); ++it) {
        if (it.value()) {
            it.value()->stop();
            it.value()->deleteLater();
        }
    }
    
    for (auto it = m_audioOutputs.begin(); it != m_audioOutputs.end(); ++it) {
        if (it.value()) {
            it.value()->deleteLater();
        }
    }
    
    qDeleteAll(m_audioClips);
}

void AudioManager::setVolume(qreal volume)
{
    if (m_volume != volume) {
        m_volume = qBound(0.0, volume, 1.0);
        
        // Update all audio outputs
        for (auto output : m_audioOutputs) {
            if (output) {
                output->setVolume(m_volume);
            }
        }
        
        emit volumeChanged();
    }
}

qreal AudioManager::currentPosition() const
{
    if (!m_currentPlayingId.isEmpty() && m_players.contains(m_currentPlayingId)) {
        QMediaPlayer* player = m_players[m_currentPlayingId];
        return player ? player->position() / 1000.0 : 0.0;
    }
    return 0.0;
}

qreal AudioManager::currentDuration() const
{
    if (!m_currentPlayingId.isEmpty() && m_players.contains(m_currentPlayingId)) {
        QMediaPlayer* player = m_players[m_currentPlayingId];
        return player ? player->duration() / 1000.0 : 0.0;
    }
    return 0.0;
}

bool AudioManager::isPlaying() const
{
    if (!m_currentPlayingId.isEmpty() && m_players.contains(m_currentPlayingId)) {
        QMediaPlayer* player = m_players[m_currentPlayingId];
        return player && player->playbackState() == QMediaPlayer::PlayingState;
    }
    return false;
}

void AudioManager::loadAudioFile(const QString &clipId, const QUrl &filePath)
{
    qDebug() << "Loading audio file for clip:" << clipId << filePath;
    
    if (!m_players.contains(clipId)) {
        initializePlayer(clipId);
    }
    
    QMediaPlayer* player = m_players[clipId];
    if (player) {
        player->setSource(filePath);
        
        // Update clip duration when loaded
        AudioClip* clip = getClip(clipId);
        if (clip) {
            clip->setFilePath(filePath);
        }
    }
}

void AudioManager::playClip(const QString &clipId)
{
    qDebug() << "Playing clip:" << clipId;
    
    AudioClip* clip = getClip(clipId);
    if (!clip) {
        qWarning() << "Clip not found:" << clipId;
        return;
    }
    
    // Stop currently playing clip if different
    if (!m_currentPlayingId.isEmpty() && m_currentPlayingId != clipId) {
        stopClip(m_currentPlayingId);
    }
    
    if (!m_players.contains(clipId)) {
        initializePlayer(clipId);
        loadAudioFile(clipId, clip->filePath());
    }
    
    QMediaPlayer* player = m_players[clipId];
    if (player) {
        // Apply trim start if set
        if (clip->trimStart() > 0) {
            player->setPosition(static_cast<qint64>(clip->trimStart() * 1000));
        }
        
        player->play();
        m_currentPlayingId = clipId;
        m_currentClip = clip;
        clip->setIsPlaying(true);
        
        emit currentClipChanged();
        emit isPlayingChanged();
    }
}

void AudioManager::pauseClip(const QString &clipId)
{
    qDebug() << "Pausing clip:" << clipId;
    
    if (m_players.contains(clipId)) {
        QMediaPlayer* player = m_players[clipId];
        if (player) {
            player->pause();
            
            AudioClip* clip = getClip(clipId);
            if (clip) {
                clip->setIsPlaying(false);
            }
            
            emit isPlayingChanged();
        }
    }
}

void AudioManager::stopClip(const QString &clipId)
{
    qDebug() << "Stopping clip:" << clipId;
    
    if (m_players.contains(clipId)) {
        QMediaPlayer* player = m_players[clipId];
        if (player) {
            player->stop();
            
            AudioClip* clip = getClip(clipId);
            if (clip) {
                clip->setIsPlaying(false);
            }
            
            if (m_currentPlayingId == clipId) {
                m_currentPlayingId.clear();
                m_currentClip = nullptr;
                emit currentClipChanged();
            }
            
            emit isPlayingChanged();
        }
    }
}

void AudioManager::stopAll()
{
    qDebug() << "Stopping all clips";
    
    for (auto it = m_players.begin(); it != m_players.end(); ++it) {
        if (it.value()) {
            it.value()->stop();
        }
    }
    
    for (AudioClip* clip : m_audioClips) {
        clip->setIsPlaying(false);
    }
    
    m_currentPlayingId.clear();
    m_currentClip = nullptr;
    emit currentClipChanged();
    emit isPlayingChanged();
}

void AudioManager::seekTo(qreal position)
{
    if (!m_currentPlayingId.isEmpty() && m_players.contains(m_currentPlayingId)) {
        QMediaPlayer* player = m_players[m_currentPlayingId];
        if (player) {
            player->setPosition(static_cast<qint64>(position * 1000));
        }
    }
}

AudioClip* AudioManager::addClip(const QString &title, const QUrl &filePath, const QString &hotkey)
{
    QString clipId = QUuid::createUuid().toString();
    
    AudioClip* clip = new AudioClip(this);
    clip->setId(clipId);
    clip->setTitle(title);
    clip->setFilePath(filePath);
    clip->setHotkey(hotkey);
    
    m_audioClips.append(clip);
    
    // Initialize player for this clip
    initializePlayer(clipId);
    loadAudioFile(clipId, filePath);
    
    emit audioClipsChanged();
    
    qDebug() << "Added clip:" << clipId << title;
    return clip;
}

void AudioManager::removeClip(const QString &clipId)
{
    AudioClip* clip = getClip(clipId);
    if (clip) {
        // Stop if currently playing
        if (m_currentPlayingId == clipId) {
            stopClip(clipId);
        }
        
        // Clean up player
        cleanupPlayer(clipId);
        
        // Remove from list
        m_audioClips.removeOne(clip);
        clip->deleteLater();
        
        emit audioClipsChanged();
        
        qDebug() << "Removed clip:" << clipId;
    }
}

AudioClip* AudioManager::getClip(const QString &clipId)
{
    for (AudioClip* clip : m_audioClips) {
        if (clip->id() == clipId) {
            return clip;
        }
    }
    return nullptr;
}

void AudioManager::playClipByHotkey(const QString &hotkey)
{
    for (AudioClip* clip : m_audioClips) {
        if (clip->hotkey() == hotkey) {
            playClip(clip->id());
            return;
        }
    }
    qWarning() << "No clip found with hotkey:" << hotkey;
}

QString AudioManager::formatTime(qreal seconds) const
{
    int totalSeconds = static_cast<int>(seconds);
    int minutes = totalSeconds / 60;
    int secs = totalSeconds % 60;
    int millis = static_cast<int>((seconds - totalSeconds) * 100);
    
    return QString("%1:%2.%3")
        .arg(minutes, 1, 10, QChar('0'))
        .arg(secs, 2, 10, QChar('0'))
        .arg(millis, 2, 10, QChar('0'));
}

void AudioManager::initializePlayer(const QString &clipId)
{
    if (m_players.contains(clipId)) {
        return; // Already initialized
    }
    
    QMediaPlayer* player = new QMediaPlayer(this);
    QAudioOutput* audioOutput = new QAudioOutput(this);
    
    audioOutput->setVolume(m_volume);
    player->setAudioOutput(audioOutput);
    
    // Connect signals
    connect(player, &QMediaPlayer::positionChanged, this, &AudioManager::onPositionChanged);
    connect(player, &QMediaPlayer::durationChanged, this, &AudioManager::onDurationChanged);
    connect(player, &QMediaPlayer::playbackStateChanged, this, &AudioManager::onPlaybackStateChanged);
    connect(player, &QMediaPlayer::mediaStatusChanged, this, &AudioManager::onMediaStatusChanged);
    connect(player, &QMediaPlayer::errorOccurred, this, &AudioManager::onErrorOccurred);
    
    m_players[clipId] = player;
    m_audioOutputs[clipId] = audioOutput;
    
    qDebug() << "Initialized player for clip:" << clipId;
}

void AudioManager::cleanupPlayer(const QString &clipId)
{
    if (m_players.contains(clipId)) {
        QMediaPlayer* player = m_players[clipId];
        if (player) {
            player->stop();
            player->deleteLater();
        }
        m_players.remove(clipId);
    }
    
    if (m_audioOutputs.contains(clipId)) {
        QAudioOutput* output = m_audioOutputs[clipId];
        if (output) {
            output->deleteLater();
        }
        m_audioOutputs.remove(clipId);
    }
}

void AudioManager::onPositionChanged(qint64 position)
{
    Q_UNUSED(position)
    emit currentPositionChanged();
    
    // Check for trim end
    if (!m_currentPlayingId.isEmpty()) {
        AudioClip* clip = getClip(m_currentPlayingId);
        if (clip && clip->trimEnd() > 0) {
            qreal currentPos = position / 1000.0;
            if (currentPos >= clip->trimEnd()) {
                stopClip(m_currentPlayingId);
            }
        }
    }
}

void AudioManager::onDurationChanged(qint64 duration)
{
    if (!m_currentPlayingId.isEmpty()) {
        AudioClip* clip = getClip(m_currentPlayingId);
        if (clip) {
            clip->setDuration(duration / 1000.0);
            
            // Set default trim end to duration if not set
            if (clip->trimEnd() == 0.0) {
                clip->setTrimEnd(duration / 1000.0);
            }
        }
    }
    emit currentDurationChanged();
}

void AudioManager::onPlaybackStateChanged(QMediaPlayer::PlaybackState state)
{
    qDebug() << "Playback state changed:" << state;
    emit isPlayingChanged();
}

void AudioManager::onMediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    qDebug() << "Media status changed:" << status;
    
    if (status == QMediaPlayer::EndOfMedia && !m_currentPlayingId.isEmpty()) {
        AudioClip* clip = getClip(m_currentPlayingId);
        if (clip) {
            clip->setIsPlaying(false);
        }
        
        QString finishedId = m_currentPlayingId;
        m_currentPlayingId.clear();
        m_currentClip = nullptr;
        
        emit clipFinished(finishedId);
        emit currentClipChanged();
        emit isPlayingChanged();
    }
}

void AudioManager::onErrorOccurred(QMediaPlayer::Error error, const QString &errorString)
{
    qWarning() << "Media player error:" << error << errorString;
    emit this->error(errorString);
}
