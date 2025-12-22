#ifndef AUDIOCLIP_H
#define AUDIOCLIP_H

#include <QObject>
#include <QString>
#include <QUrl>

class AudioClip : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id WRITE setId NOTIFY idChanged)
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    Q_PROPERTY(QString hotkey READ hotkey WRITE setHotkey NOTIFY hotkeyChanged)
    Q_PROPERTY(QUrl filePath READ filePath WRITE setFilePath NOTIFY filePathChanged)
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)
    Q_PROPERTY(QString tagLabel READ tagLabel WRITE setTagLabel NOTIFY tagLabelChanged)
    Q_PROPERTY(QString tagColor READ tagColor WRITE setTagColor NOTIFY tagColorChanged)
    Q_PROPERTY(qreal duration READ duration WRITE setDuration NOTIFY durationChanged)
    Q_PROPERTY(qreal trimStart READ trimStart WRITE setTrimStart NOTIFY trimStartChanged)
    Q_PROPERTY(qreal trimEnd READ trimEnd WRITE setTrimEnd NOTIFY trimEndChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying WRITE setIsPlaying NOTIFY isPlayingChanged)

public:
    explicit AudioClip(QObject *parent = nullptr);

    QString id() const { return m_id; }
    void setId(const QString &id) { 
        if (m_id != id) { 
            m_id = id; 
            emit idChanged(); 
        } 
    }

    QString title() const { return m_title; }
    void setTitle(const QString &title) { 
        if (m_title != title) { 
            m_title = title; 
            emit titleChanged(); 
        } 
    }

    QString hotkey() const { return m_hotkey; }
    void setHotkey(const QString &hotkey) { 
        if (m_hotkey != hotkey) { 
            m_hotkey = hotkey; 
            emit hotkeyChanged(); 
        } 
    }

    QUrl filePath() const { return m_filePath; }
    void setFilePath(const QUrl &filePath) { 
        if (m_filePath != filePath) { 
            m_filePath = filePath; 
            emit filePathChanged(); 
        } 
    }

    QString imagePath() const { return m_imagePath; }
    void setImagePath(const QString &imagePath) { 
        if (m_imagePath != imagePath) { 
            m_imagePath = imagePath; 
            emit imagePathChanged(); 
        } 
    }

    QString tagLabel() const { return m_tagLabel; }
    void setTagLabel(const QString &tagLabel) { 
        if (m_tagLabel != tagLabel) { 
            m_tagLabel = tagLabel; 
            emit tagLabelChanged(); 
        } 
    }

    QString tagColor() const { return m_tagColor; }
    void setTagColor(const QString &tagColor) { 
        if (m_tagColor != tagColor) { 
            m_tagColor = tagColor; 
            emit tagColorChanged(); 
        } 
    }

    qreal duration() const { return m_duration; }
    void setDuration(qreal duration) { 
        if (m_duration != duration) { 
            m_duration = duration; 
            emit durationChanged(); 
        } 
    }

    qreal trimStart() const { return m_trimStart; }
    void setTrimStart(qreal trimStart) { 
        if (m_trimStart != trimStart) { 
            m_trimStart = trimStart; 
            emit trimStartChanged(); 
        } 
    }

    qreal trimEnd() const { return m_trimEnd; }
    void setTrimEnd(qreal trimEnd) { 
        if (m_trimEnd != trimEnd) { 
            m_trimEnd = trimEnd; 
            emit trimEndChanged(); 
        } 
    }

    qreal volume() const { return m_volume; }
    void setVolume(qreal volume) { 
        if (m_volume != volume) { 
            m_volume = volume; 
            emit volumeChanged(); 
        } 
    }

    bool isPlaying() const { return m_isPlaying; }
    void setIsPlaying(bool isPlaying) { 
        if (m_isPlaying != isPlaying) { 
            m_isPlaying = isPlaying; 
            emit isPlayingChanged(); 
        } 
    }

signals:
    void idChanged();
    void titleChanged();
    void hotkeyChanged();
    void filePathChanged();
    void imagePathChanged();
    void tagLabelChanged();
    void tagColorChanged();
    void durationChanged();
    void trimStartChanged();
    void trimEndChanged();
    void volumeChanged();
    void isPlayingChanged();

private:
    QString m_id;
    QString m_title;
    QString m_hotkey;
    QUrl m_filePath;
    QString m_imagePath;
    QString m_tagLabel;
    QString m_tagColor;
    qreal m_duration = 0.0;
    qreal m_trimStart = 0.0;
    qreal m_trimEnd = 0.0;
    qreal m_volume = 1.0;
    bool m_isPlaying = false;
};

#endif // AUDIOCLIP_H
