#include "audiomanager.h"
#include <QDebug>
#include <QUuid>
#include <QMediaDevices>
#include <QAudioDevice>

AudioManager::AudioManager(AudioEngine* audioEngine, QObject *parent)
    : QObject(parent)
    , m_currentClip(nullptr)
    , m_volume(1.0)
    , m_secondaryOutputEnabled(false)
    , m_inputDeviceEnabled(true)
    , m_audioEngine(audioEngine)
{
    if (!m_audioEngine) {
        qWarning() << "AudioManager initialized without AudioEngine instance!";
    } else {
        qDebug() << "AudioManager initialized with shared AudioEngine";
    }

    // Initial device discovery
    refreshAudioDevices();
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
    
    // Clean up secondary audio outputs
    for (auto it = m_secondaryAudioOutputs.begin(); it != m_secondaryAudioOutputs.end(); ++it) {
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
        
        // Update all audio outputs (fallback for clips without per-clip volume)
        for (auto it = m_audioOutputs.begin(); it != m_audioOutputs.end(); ++it) {
            QAudioOutput* output = it.value();
            if (output) {
                AudioClip* clip = getClip(it.key());
                qreal clipVolume = clip ? clip->volume() : m_volume;
                output->setVolume(clipVolume);
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

    // Mirror to secondary player if exists
    if (m_secondaryPlayers.contains(clipId)) {
        QMediaPlayer* secondaryPlayer = m_secondaryPlayers[clipId];
        if (secondaryPlayer) {
            secondaryPlayer->setSource(filePath);
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
        // Start secondary player if available
        if (m_secondaryPlayers.contains(clipId)) {
            QMediaPlayer* secondaryPlayer = m_secondaryPlayers[clipId];
            if (secondaryPlayer) {
                secondaryPlayer->setPosition(player->position());
                secondaryPlayer->play();
            }
        }
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
    if (m_secondaryPlayers.contains(clipId)) {
        QMediaPlayer* secondaryPlayer = m_secondaryPlayers[clipId];
        if (secondaryPlayer) {
            secondaryPlayer->pause();
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
    if (m_secondaryPlayers.contains(clipId)) {
        QMediaPlayer* secondaryPlayer = m_secondaryPlayers[clipId];
        if (secondaryPlayer) {
            secondaryPlayer->stop();
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

    for (auto it = m_secondaryPlayers.begin(); it != m_secondaryPlayers.end(); ++it) {
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

AudioClip* AudioManager::addClip(const QString &title, const QUrl &filePath, const QString &hotkey, const QString &sectionId)
{
    // Check if the same file already exists in this section
    for (AudioClip* existingClip : m_audioClips) {
        if (existingClip->filePath() == filePath && existingClip->sectionId() == sectionId) {
            qWarning() << "Duplicate audio file detected in section:" << sectionId << "File:" << filePath;
            emit error("This audio file is already added to this soundboard.");
            return nullptr;
        }
    }
    
    QString clipId = QUuid::createUuid().toString();
    
    AudioClip* clip = new AudioClip(this);
    clip->setId(clipId);
    clip->setTitle(title);
    clip->setFilePath(filePath);
    clip->setHotkey(hotkey);
    clip->setSectionId(sectionId);
    
    m_audioClips.append(clip);
    
    // Initialize player for this clip
    initializePlayer(clipId);
    loadAudioFile(clipId, filePath);
    
    emit audioClipsChanged();
    
    qDebug() << "Added clip:" << clipId << title << "to section:" << sectionId;
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
    
    // If a preferred output device is set, try to apply it for this player
    if (!m_currentOutputDevice.isEmpty()) {
        QMediaDevices devices;
        const QList<QAudioDevice> outputs = devices.audioOutputs();
        for (const QAudioDevice &dev : outputs) {
            if (dev.description() == m_currentOutputDevice) {
                audioOutput->setDevice(dev);
                break;
            }
        }
    }
    
    // Apply per-clip volume if available
    AudioClip* clip = getClip(clipId);
    qreal clipVolume = clip ? clip->volume() : m_volume;
    audioOutput->setVolume(clipVolume);
    player->setAudioOutput(audioOutput);
    
    // Connect signals
    connect(player, &QMediaPlayer::positionChanged, this, &AudioManager::onPositionChanged);
    connect(player, &QMediaPlayer::durationChanged, this, &AudioManager::onDurationChanged);
    connect(player, &QMediaPlayer::playbackStateChanged, this, &AudioManager::onPlaybackStateChanged);
    connect(player, &QMediaPlayer::mediaStatusChanged, this, &AudioManager::onMediaStatusChanged);
    connect(player, &QMediaPlayer::errorOccurred, this, &AudioManager::onErrorOccurred);
    
    m_players[clipId] = player;
    m_audioOutputs[clipId] = audioOutput;

    // Secondary output (clips only)
    if (m_secondaryOutputEnabled && !m_secondaryOutputDevice.isEmpty()) {
        QMediaPlayer* secondaryPlayer = new QMediaPlayer(this);
        QAudioOutput* secondaryOutput = new QAudioOutput(this);
        secondaryOutput->setVolume(m_volume);

        QMediaDevices devices;
        const QList<QAudioDevice> outputs = devices.audioOutputs();
        for (const QAudioDevice &dev : outputs) {
            if (dev.description() == m_secondaryOutputDevice) {
                secondaryOutput->setDevice(dev);
                break;
            }
        }

        secondaryPlayer->setAudioOutput(secondaryOutput);

        // Mirror errors for visibility
        connect(secondaryPlayer, &QMediaPlayer::errorOccurred, this, &AudioManager::onErrorOccurred);

        m_secondaryPlayers[clipId] = secondaryPlayer;
        m_secondaryAudioOutputs[clipId] = secondaryOutput;
        qDebug() << "Initialized secondary player for clip:" << clipId << "on device:" << m_secondaryOutputDevice;
    }
    
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
    
    // Clean up secondary audio output/player
    if (m_secondaryPlayers.contains(clipId)) {
        QMediaPlayer* secondaryPlayer = m_secondaryPlayers[clipId];
        if (secondaryPlayer) {
            secondaryPlayer->stop();
            secondaryPlayer->deleteLater();
        }
        m_secondaryPlayers.remove(clipId);
    }
    if (m_secondaryAudioOutputs.contains(clipId)) {
        QAudioOutput* secondaryOutput = m_secondaryAudioOutputs[clipId];
        if (secondaryOutput) {
            secondaryOutput->deleteLater();
        }
        m_secondaryAudioOutputs.remove(clipId);
    }
}

void AudioManager::updateOutputDeviceForAllPlayers(const QString &deviceName)
{
    // Find the QAudioDevice for the selected device
    QMediaDevices devices;
    const QList<QAudioDevice> outputs = devices.audioOutputs();
    QAudioDevice selectedDevice;
    for (const QAudioDevice &audioDevice : outputs) {
        if (audioDevice.description() == deviceName) {
            selectedDevice = audioDevice;
            break;
        }
    }

    if (selectedDevice.isNull()) {
        qWarning() << "Output device not found:" << deviceName;
        return;
    }

    // Update all existing audio outputs to use the new device
    for (auto it = m_audioOutputs.begin(); it != m_audioOutputs.end(); ++it) {
        if (it.value()) {
            it.value()->setDevice(selectedDevice);
            qDebug() << "Updated audio output for clip:" << it.key() << "to device:" << deviceName;
        }
    }
}

void AudioManager::updateSecondaryOutputsForAllPlayers(const QString &deviceName)
{
    if (m_secondaryPlayers.isEmpty()) return;

    QMediaDevices devices;
    const QList<QAudioDevice> outputs = devices.audioOutputs();
    QAudioDevice selectedDevice;
    for (const QAudioDevice &audioDevice : outputs) {
        if (audioDevice.description() == deviceName) {
            selectedDevice = audioDevice;
            break;
        }
    }

    if (selectedDevice.isNull()) {
        qWarning() << "Secondary output device not found:" << deviceName;
        return;
    }

    for (auto it = m_secondaryAudioOutputs.begin(); it != m_secondaryAudioOutputs.end(); ++it) {
        if (it.value()) {
            it.value()->setDevice(selectedDevice);
            qDebug() << "Updated secondary output for clip:" << it.key() << "to device:" << deviceName;
        }
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

qreal AudioManager::masterVolume() const
{
    if (m_audioEngine) return m_audioEngine->getMasterGainLinear();
    return 1.0;
}

void AudioManager::setMasterVolume(qreal linear)
{
    if (!m_audioEngine) return;
    m_audioEngine->setMasterGainLinear(static_cast<float>(linear));
    // Apply master gain to all QMediaPlayer audio outputs (both primary and secondary)
    for (auto it = m_audioOutputs.begin(); it != m_audioOutputs.end(); ++it) {
        QAudioOutput* output = it.value();
        if (output) {
            // Combine per-clip volume with master gain
            AudioClip* clip = getClip(it.key());
            qreal clipVol = clip ? clip->volume() : 1.0;
            output->setVolume(clipVol * linear);
        }
    }
    for (auto it = m_secondaryAudioOutputs.begin(); it != m_secondaryAudioOutputs.end(); ++it) {
        QAudioOutput* output = it.value();
        if (output) {
            AudioClip* clip = getClip(it.key());
            qreal clipVol = clip ? clip->volume() : 1.0;
            output->setVolume(clipVol * linear);
        }
    }
    emit volumeChanged();
}

qreal AudioManager::micVolume() const
{
    if (m_audioEngine) return m_audioEngine->getMicGainLinear();
    return 1.0;
}

void AudioManager::setMicVolume(qreal linear)
{
    if (!m_audioEngine) return;
    m_audioEngine->setMicGainLinear(static_cast<float>(linear));
}

void AudioManager::setClipVolume(const QString &clipId, qreal volume)
{
    AudioClip* clip = getClip(clipId);
    if (!clip) return;
    clip->setVolume(volume);
    // Apply to the player's audio output if it exists, combined with master gain
    qreal masterGain = masterVolume();
    if (m_audioOutputs.contains(clipId)) {
        QAudioOutput* output = m_audioOutputs[clipId];
        if (output) {
            output->setVolume(volume * masterGain);
        }
    }
    if (m_secondaryAudioOutputs.contains(clipId)) {
        QAudioOutput* output = m_secondaryAudioOutputs[clipId];
        if (output) {
            output->setVolume(volume * masterGain);
        }
    }
}

QList<QObject*> AudioManager::audioClipsAsObjects() const
{
    QList<QObject*> objects;
    objects.reserve(m_audioClips.size());
    for (AudioClip* clip : m_audioClips) {
        objects.append(clip);
    }
    return objects;
}

QStringList AudioManager::inputDevices() const
{
    return m_inputDevices;
}

QStringList AudioManager::outputDevices() const
{
    return m_outputDevices;
}

QString AudioManager::currentInputDevice() const
{
    return m_currentInputDevice;
}

QString AudioManager::currentOutputDevice() const
{
    return m_currentOutputDevice;
}

void AudioManager::setCurrentInputDevice(const QString &device)
{
    if (m_currentInputDevice != device) {
        if (m_audioEngine) {
            // Find device ID by name (AudioEngine uses device IDs, not names)
            std::vector<AudioEngine::AudioDeviceInfo> inputDevices = m_audioEngine->enumerateCaptureDevices();
            for (const auto& deviceInfo : inputDevices) {
                if (QString::fromStdString(deviceInfo.name) == device) {
                    if (m_audioEngine->setCaptureDevice(deviceInfo.id)) {
                        m_currentInputDevice = device;
                        emit currentInputDeviceChanged();
                        qDebug() << "Input device changed to:" << device << "(ID:" << QString::fromStdString(deviceInfo.id) << ")";
                    } else {
                        qWarning() << "Failed to set input device:" << device;
                    }
                    return;
                }
            }
            qWarning() << "Input device not found:" << device;
        } else {
            // Fallback - just update the property
            m_currentInputDevice = device;
            emit currentInputDeviceChanged();
            qDebug() << "Input device changed to:" << device << "(fallback mode)";
        }
    }
}

void AudioManager::setCurrentOutputDevice(const QString &device)
{
    if (m_currentOutputDevice != device) {

        if (m_audioEngine) {
            bool qtDeviceApplied = false;
            // First, apply to Qt media players (names must match QMediaDevices)
            updateOutputDeviceForAllPlayers(device);
            qtDeviceApplied = true;

            // Then, find matching device in AudioEngine enumeration by name
            std::vector<AudioEngine::AudioDeviceInfo> outputDevices = m_audioEngine->enumeratePlaybackDevices();
            for (const auto& deviceInfo : outputDevices) {
                if (QString::fromStdString(deviceInfo.name) == device) {
                    if (m_audioEngine->setPlaybackDevice(deviceInfo.id)) {
                        m_currentOutputDevice = device;
                        emit currentOutputDeviceChanged();
                        qDebug() << "Output device changed to:" << device << "(ID:" << QString::fromStdString(deviceInfo.id) << ")";
                    } else {
                        qWarning() << "Failed to set output device (AudioEngine):" << device;
                    }
                    return;
                }
            }
            qWarning() << "Output device not found in AudioEngine list:" << device << " (Qt device applied:" << qtDeviceApplied << ")";
        } else {
            // Fallback - update property and QAudioOutputs
            m_currentOutputDevice = device;
            updateOutputDeviceForAllPlayers(device);
            emit currentOutputDeviceChanged();
            qDebug() << "Output device changed to:" << device << "(fallback mode)";
        }
    }
}

QString AudioManager::secondaryOutputDevice() const
{
    return m_secondaryOutputDevice;
}

bool AudioManager::secondaryOutputEnabled() const
{
    return m_secondaryOutputEnabled;
}

void AudioManager::setSecondaryOutputDevice(const QString &device)
{
    if (m_secondaryOutputDevice != device) {
        m_secondaryOutputDevice = device;
        emit secondaryOutputDeviceChanged();
        qDebug() << "Secondary output device changed to:" << device;
        
        // Retarget existing secondary outputs
        updateSecondaryOutputsForAllPlayers(device);
    }
}

void AudioManager::setSecondaryOutputEnabled(bool enabled)
{
    if (m_secondaryOutputEnabled != enabled) {
        m_secondaryOutputEnabled = enabled;
        emit secondaryOutputEnabledChanged();
        qDebug() << "Secondary output enabled:" << enabled;
        
        if (enabled && m_secondaryOutputDevice.isEmpty() && !m_outputDevices.isEmpty()) {
            // Set default secondary output device if not set
            setSecondaryOutputDevice(m_outputDevices.first());
        }

        if (enabled) {
            // Create secondary players for existing clips
            QMediaDevices devices;
            const QList<QAudioDevice> outputs = devices.audioOutputs();
            QAudioDevice selectedDevice;
            for (const QAudioDevice &dev : outputs) {
                if (dev.description() == m_secondaryOutputDevice) {
                    selectedDevice = dev;
                    break;
                }
            }

            for (auto it = m_players.begin(); it != m_players.end(); ++it) {
                const QString clipId = it.key();
                if (m_secondaryPlayers.contains(clipId)) continue;

                QMediaPlayer* secondaryPlayer = new QMediaPlayer(this);
                QAudioOutput* secondaryOutput = new QAudioOutput(this);
                secondaryOutput->setVolume(m_volume);
                if (!selectedDevice.isNull()) {
                    secondaryOutput->setDevice(selectedDevice);
                }
                secondaryPlayer->setAudioOutput(secondaryOutput);
                secondaryPlayer->setSource(it.value()->source());
                connect(secondaryPlayer, &QMediaPlayer::errorOccurred, this, &AudioManager::onErrorOccurred);
                m_secondaryPlayers[clipId] = secondaryPlayer;
                m_secondaryAudioOutputs[clipId] = secondaryOutput;
            }
        } else {
            // Tear down secondary players
            for (auto it = m_secondaryPlayers.begin(); it != m_secondaryPlayers.end(); ++it) {
                if (it.value()) {
                    it.value()->stop();
                    it.value()->deleteLater();
                }
            }
            m_secondaryPlayers.clear();

            for (auto it = m_secondaryAudioOutputs.begin(); it != m_secondaryAudioOutputs.end(); ++it) {
                if (it.value()) {
                    it.value()->deleteLater();
                }
            }
            m_secondaryAudioOutputs.clear();
        }
    }
}

bool AudioManager::inputDeviceEnabled() const
{
    return m_inputDeviceEnabled;
}

void AudioManager::setInputDeviceEnabled(bool enabled)
{
    if (m_inputDeviceEnabled != enabled) {
        m_inputDeviceEnabled = enabled;
        emit inputDeviceEnabledChanged();
        qDebug() << "Input device (microphone) enabled:" << enabled;
        
        if (m_audioEngine) {
            if (enabled) {
                m_audioEngine->startAudioDevice();
            } else {
                m_audioEngine->stopAudioDevice();
            }
        }

    }
}

void AudioManager::refreshAudioDevices()
{
    QStringList newInputDevices;
    QStringList newOutputDevices;
    if (m_audioEngine) {
        // Get input devices from AudioEngine
        std::vector<AudioEngine::AudioDeviceInfo> inputDevices = m_audioEngine->enumerateCaptureDevices();
        for (const auto& device : inputDevices) {
            newInputDevices << QString::fromStdString(device.name);
        }
        
        // Get output devices from AudioEngine
        std::vector<AudioEngine::AudioDeviceInfo> outputDevices = m_audioEngine->enumeratePlaybackDevices();
        for (const auto& device : outputDevices) {
            newOutputDevices << QString::fromStdString(device.name);
        }
        
        qDebug() << "AudioEngine enumerated - Inputs:" << inputDevices.size() 
                 << "Outputs:" << outputDevices.size();
    }

    
    // Update if changed
    if (m_inputDevices != newInputDevices) {
        m_inputDevices = newInputDevices;
        emit inputDevicesChanged();
    }
    
    if (m_outputDevices != newOutputDevices) {
        m_outputDevices = newOutputDevices;
        emit outputDevicesChanged();
    }
    
    // Set defaults if not set
    if (m_currentInputDevice.isEmpty() && !m_inputDevices.isEmpty()) {
        setCurrentInputDevice(m_inputDevices.first());
    }
    
    if (m_currentOutputDevice.isEmpty() && !m_outputDevices.isEmpty()) {
        setCurrentOutputDevice(m_outputDevices.first());
    }
    
    qDebug() << "Audio devices refreshed - Inputs:" << m_inputDevices.size() 
             << "Outputs:" << m_outputDevices.size();
}

void AudioManager::testPlayback()
{
    qDebug() << "Testing audio playback with current output device:" << m_currentOutputDevice;
    

    if (m_audioEngine) {
        // Start the AudioEngine device for testing
        if (m_audioEngine->startAudioDevice()) {
            qDebug() << "AudioEngine started successfully for testing";
            // You could load a test sound file here or generate a test tone
            emit error("AudioEngine test playback - device started successfully");
        } else {
            emit error("Failed to start AudioEngine device");
        }
    } else {
        // Fallback to QtMediaPlayer test
        if (!m_audioClips.isEmpty()) {
            playClip(m_audioClips.first()->id());
        } else {
            emit error("No audio clips available for testing");
        }
    }
}
