#include "TranscriptionService.h"

#include <QAudioDevice>
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QSettings>
#include <QThread>

TranscriptionService::TranscriptionService(QObject* parent)
    : QObject(parent)
    , m_webSocket(std::make_unique<ix::WebSocket>())
{
    // Load API token from settings on startup
    QSettings settings;
    m_apiToken = settings.value("openai/apiKey").toString();

    // Setup inactivity timer
    m_inactivityTimer.setSingleShot(true);
    m_inactivityTimer.setInterval(INACTIVITY_TIMEOUT_MS);
    connect(&m_inactivityTimer, &QTimer::timeout, this, &TranscriptionService::onInactivityTimeout);

    // Audio send timer (100ms intervals for real-time streaming)
    m_audioSendTimer.setInterval(AUDIO_SEND_INTERVAL_MS);
    connect(&m_audioSendTimer, &QTimer::timeout, this, &TranscriptionService::sendAudioChunk);
}

TranscriptionService::~TranscriptionService()
{
    stopListening();
}

void TranscriptionService::setApiToken(const QString& token)
{
    m_apiToken = token;
    QSettings settings;
    settings.setValue("openai/apiKey", token);
    emit hasApiKeyChanged();
}

void TranscriptionService::setLanguage(const QString& language)
{
    if (m_language != language) {
        m_language = language;
        emit languageChanged();
        qDebug() << "[TranscriptionService] Language set to:" << language;
    }
}

QString TranscriptionService::getLanguageCode() const
{
    if (m_language.contains("Sinhala") || m_language.contains("සිංහල")) {
        return "si";
    }
    return "en";
}

QString TranscriptionService::getApiToken()
{
    if (!m_apiToken.isEmpty()) {
        return m_apiToken;
    }
    return QProcessEnvironment::systemEnvironment().value("OPENAI_API_KEY");
}

void TranscriptionService::startListening()
{
    if (m_isListening) {
        return;
    }

    QString token = getApiToken();
    if (token.isEmpty()) {
        m_errorMessage = "No API key configured";
        emit sttError(m_errorMessage);
        return;
    }

    qDebug() << "[TranscriptionService] Starting real-time transcription...";
    
    m_audioBuffer.clear();
    m_isListening = true;
    emit isListeningChanged();

    // Configure WebSocket with transcription intent
    std::string url = "wss://api.openai.com/v1/realtime?intent=transcription";
    
    ix::WebSocketHttpHeaders headers;
    headers["Authorization"] = "Bearer " + token.toStdString();
    headers["OpenAI-Beta"] = "realtime=v1";
    
    m_webSocket->setUrl(url);
    m_webSocket->setExtraHeaders(headers);
    
    // Set up message callback
    m_webSocket->setOnMessageCallback([this](const ix::WebSocketMessagePtr& msg) {
        onWebSocketMessage(msg);
    });

    m_webSocket->start();
}

void TranscriptionService::stopListening()
{
    if (!m_isListening) {
        return;
    }

    qDebug() << "[TranscriptionService] Stopping...";

    m_audioSendTimer.stop();
    m_inactivityTimer.stop();
    stopAudioCapture();
    
    m_webSocket->stop();
    m_isConnected = false;
    m_isListening = false;
    emit isListeningChanged();
}

void TranscriptionService::onWebSocketMessage(const ix::WebSocketMessagePtr& msg)
{
    switch (msg->type) {
    case ix::WebSocketMessageType::Open:
        qDebug() << "[TranscriptionService] WebSocket connected";
        m_isConnected = true;
        
        // Send transcription session configuration
        QMetaObject::invokeMethod(this, [this]() {
            sendTranscriptionSessionUpdate();
            startAudioCapture();
            m_audioSendTimer.start();
            m_inactivityTimer.start();
        }, Qt::QueuedConnection);
        break;

    case ix::WebSocketMessageType::Close:
        qDebug() << "[TranscriptionService] WebSocket closed";
        m_isConnected = false;
        QMetaObject::invokeMethod(this, [this]() {
            if (m_isListening) {
                stopListening();
            }
        }, Qt::QueuedConnection);
        break;

    case ix::WebSocketMessageType::Error:
        qDebug() << "[TranscriptionService] WebSocket error:" << QString::fromStdString(msg->errorInfo.reason);
        QMetaObject::invokeMethod(this, [this, error = QString::fromStdString(msg->errorInfo.reason)]() {
            m_errorMessage = error;
            emit sttError(m_errorMessage);
            stopListening();
        }, Qt::QueuedConnection);
        break;

    case ix::WebSocketMessageType::Message:
        QMetaObject::invokeMethod(this, [this, text = QString::fromStdString(msg->str)]() {
            processMessage(text);
        }, Qt::QueuedConnection);
        break;

    default:
        break;
    }
}

void TranscriptionService::processMessage(const QString& message)
{
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();
    
    qDebug() << "[TranscriptionService] Event:" << type;

    // Handle transcription events
    if (type == "conversation.item.input_audio_transcription.delta") {
        QString delta = obj["delta"].toString();
        if (!delta.isEmpty()) {
            qDebug() << "[TranscriptionService] Delta:" << delta;
            emit transcriptDelta("", delta);
        }
        
    } else if (type == "conversation.item.input_audio_transcription.completed") {
        QString transcript = obj["transcript"].toString();
        qDebug() << "[TranscriptionService] Completed:" << transcript;
        emit transcriptFinal("", transcript);
        
    } else if (type == "input_audio_buffer.speech_started") {
        qDebug() << "[TranscriptionService] Speech started";
        m_inactivityTimer.stop();
        
    } else if (type == "input_audio_buffer.speech_stopped") {
        qDebug() << "[TranscriptionService] Speech stopped";
        m_inactivityTimer.start();
        
    } else if (type == "error") {
        QJsonObject errorObj = obj["error"].toObject();
        QString errorMsg = errorObj["message"].toString();
        qDebug() << "[TranscriptionService] Error:" << errorMsg;
        m_errorMessage = errorMsg;
        emit sttError(m_errorMessage);
        
    } else if (type == "transcription_session.created" || type == "transcription_session.updated") {
        qDebug() << "[TranscriptionService] Session ready";
    }
}

void TranscriptionService::startAudioCapture()
{
    QAudioDevice audioDevice = QMediaDevices::defaultAudioInput();
    if (audioDevice.isNull()) {
        m_errorMessage = "No microphone available";
        emit sttError(m_errorMessage);
        stopListening();
        return;
    }
    
    qDebug() << "[TranscriptionService] Using audio device:" << audioDevice.description();

    // Setup audio format: PCM16 mono at 48kHz (native Mac rate)
    QAudioFormat format;
    format.setSampleRate(CAPTURE_SAMPLE_RATE);
    format.setChannelCount(1);
    format.setSampleFormat(QAudioFormat::Int16);

    if (!audioDevice.isFormatSupported(format)) {
        format = audioDevice.preferredFormat();
        format.setChannelCount(1);
        format.setSampleFormat(QAudioFormat::Int16);
    }
    
    qDebug() << "[TranscriptionService] Audio format:" << format.sampleRate() << "Hz";

    m_audioSource = std::make_unique<QAudioSource>(audioDevice, format);
    m_audioDevice = m_audioSource->start();

    if (!m_audioDevice) {
        m_errorMessage = "Failed to start microphone capture";
        emit sttError(m_errorMessage);
        stopListening();
        return;
    }
    
    qDebug() << "[TranscriptionService] Audio capture started";
}

void TranscriptionService::stopAudioCapture()
{
    m_audioSendTimer.stop();
    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource.reset();
    }
    m_audioDevice = nullptr;
    m_audioBuffer.clear();
}

void TranscriptionService::sendAudioChunk()
{
    if (!m_isConnected || !m_audioDevice) {
        return;
    }

    QByteArray audioData = m_audioDevice->readAll();
    
    if (audioData.isEmpty()) {
        return;
    }
    
    // Downsample from 48kHz to 24kHz (2:1 decimation)
    const int16_t* samples = reinterpret_cast<const int16_t*>(audioData.constData());
    int sampleCount = audioData.size() / 2;
    
    QByteArray downsampled;
    downsampled.reserve(audioData.size() / 2);
    
    for (int i = 0; i < sampleCount - 1; i += 2) {
        int32_t avg = (static_cast<int32_t>(samples[i]) + static_cast<int32_t>(samples[i + 1])) / 2;
        int16_t sample = static_cast<int16_t>(avg);
        downsampled.append(reinterpret_cast<const char*>(&sample), 2);
    }
    
    if (downsampled.isEmpty()) {
        return;
    }

    // Base64 encode and send
    QString base64Audio = downsampled.toBase64();

    QJsonObject message;
    message["type"] = "input_audio_buffer.append";
    message["audio"] = base64Audio;

    std::string jsonStr = QJsonDocument(message).toJson(QJsonDocument::Compact).toStdString();
    m_webSocket->send(jsonStr);
}

void TranscriptionService::onInactivityTimeout()
{
    qDebug() << "[TranscriptionService] Inactivity timeout - stopping";
    stopListening();
}

void TranscriptionService::sendTranscriptionSessionUpdate()
{
    /*
     * Transcription session configuration per OpenAI docs:
     * {
     *   "type": "transcription_session.update",
     *   "session": {
     *     "input_audio_format": "pcm16",
     *     "input_audio_transcription": {
     *       "model": "gpt-4o-mini-transcribe",
     *       "language": "en"
     *     },
     *     "turn_detection": {
     *       "type": "server_vad",
     *       "threshold": 0.5,
     *       "prefix_padding_ms": 300,
     *       "silence_duration_ms": 500
     *     }
     *   }
     * }
     */
    
    QJsonObject transcription;
    transcription["model"] = "gpt-4o-transcribe";
    transcription["language"] = getLanguageCode();
    
    QJsonObject turnDetection;
    turnDetection["type"] = "server_vad";
    turnDetection["threshold"] = 0.5;
    turnDetection["prefix_padding_ms"] = 300;
    turnDetection["silence_duration_ms"] = 500;
    
    // Session config object
    QJsonObject sessionConfig;
    sessionConfig["input_audio_format"] = "pcm16";
    sessionConfig["input_audio_transcription"] = transcription;
    sessionConfig["turn_detection"] = turnDetection;
    
    // Wrap in message with type
    QJsonObject message;
    message["type"] = "transcription_session.update";
    message["session"] = sessionConfig;

    std::string jsonStr = QJsonDocument(message).toJson(QJsonDocument::Compact).toStdString();
    qDebug() << "[TranscriptionService] Sending session config:" << QString::fromStdString(jsonStr);
    m_webSocket->send(jsonStr);
}
