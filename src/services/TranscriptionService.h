#pragma once

#include <QAudioFormat>
#include <QAudioSource>
#include <QByteArray>
#include <QIODevice>
#include <QMediaDevices>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <ixwebsocket/IXWebSocket.h>
#include <memory>
#include <mutex>

/**
 * @brief OpenAI Realtime Transcription service
 *
 * Uses the Realtime API with transcription intent for real-time speech-to-text.
 * Endpoint: wss://api.openai.com/v1/realtime?intent=transcription
 * API key is stored persistently via QSettings.
 */
class TranscriptionService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isListening READ isListening NOTIFY isListeningChanged)
    Q_PROPERTY(bool hasApiKey READ hasApiKey NOTIFY hasApiKeyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY sttError)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QStringList supportedLanguages READ supportedLanguages CONSTANT)

public:
    explicit TranscriptionService(QObject* parent = nullptr);
    ~TranscriptionService() override;

    [[nodiscard]] bool isListening() const { return m_isListening; }
    [[nodiscard]] bool hasApiKey() const { return !m_apiToken.isEmpty(); }
    [[nodiscard]] QString errorMessage() const { return m_errorMessage; }
    [[nodiscard]] QString language() const { return m_language; }
    
    /// Get list of supported languages (display names)
    [[nodiscard]] QStringList supportedLanguages() const {
        return {"English", "සිංහල (Sinhala)"};
    }
    
    /// Set the transcription language
    void setLanguage(const QString& language);

    /// Set API key programmatically (saves to persistent settings)
    Q_INVOKABLE void setApiToken(const QString& token);

public slots:
    /// Start listening - connects WebSocket and begins streaming audio
    void startListening();

    /// Stop listening - closes WebSocket connection
    void stopListening();

signals:
    /// Emitted with partial transcription delta
    void transcriptDelta(const QString& itemId, const QString& delta);

    /// Emitted when transcription for an item is complete
    void transcriptFinal(const QString& itemId, const QString& text);

    /// Emitted on any error
    void sttError(const QString& message);

    /// Listening state changed
    void isListeningChanged();

    /// API key status changed
    void hasApiKeyChanged();
    
    /// Language changed
    void languageChanged();

private slots:
    void onInactivityTimeout();
    void sendAudioChunk();

private:
    void onWebSocketMessage(const ix::WebSocketMessagePtr& msg);
    void sendTranscriptionSessionUpdate();
    void startAudioCapture();
    void stopAudioCapture();
    QString getApiToken();
    QString getLanguageCode() const;
    void processMessage(const QString& message);

    std::unique_ptr<ix::WebSocket> m_webSocket;
    std::unique_ptr<QAudioSource> m_audioSource;
    QIODevice* m_audioDevice = nullptr;
    QTimer m_inactivityTimer;
    QTimer m_audioSendTimer;

    QString m_apiToken;
    QString m_language = "English";
    bool m_isListening = false;
    bool m_isConnected = false;
    QString m_errorMessage;
    QByteArray m_audioBuffer;
    std::mutex m_audioMutex;

    static constexpr int INACTIVITY_TIMEOUT_MS = 10000;  // 10 seconds
    static constexpr int CAPTURE_SAMPLE_RATE = 48000;    // Native capture rate
    static constexpr int API_SAMPLE_RATE = 24000;        // API requires 24kHz
    static constexpr int AUDIO_SEND_INTERVAL_MS = 100;   // Send every 100ms for real-time
};
