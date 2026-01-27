#pragma once

#include "models/clip.h"
#include "services/soundboardService.h"

#include <QAbstractListModel>
#include <QVector>

class ClipsListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(SoundboardService* service READ service WRITE setService NOTIFY serviceChanged)
    Q_PROPERTY(int boardId READ boardId WRITE setBoardId NOTIFY boardIdChanged)
    Q_PROPERTY(QString boardName READ boardName NOTIFY boardNameChanged)
    Q_PROPERTY(int count READ count NOTIFY clipsChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        FilePathRole,
        ImgPathRole,
        HotkeyRole,
        TitleRole,
        TrimStartMsRole,
        TrimEndMsRole,
        VolumeRole,
        SpeedRole,
        IsPlayingRole,
        IsRepeatRole,
        LockedRole,
        TagsRole,
        ReproductionModeRole,
        StopOtherSoundsRole,
        MuteOtherSoundsRole,
        MuteMicDuringPlaybackRole,
        DurationSecRole
    };

    explicit ClipsListModel(QObject* parent = nullptr);

    // Service property
    SoundboardService* service() const { return m_service; }
    void setService(SoundboardService* service);

    // Board ID to display clips from
    int boardId() const { return m_boardId; }
    void setBoardId(int id);

    QString boardName() const;

    // Model interface
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_cache.size(); }

    // Invokable methods for QML
    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadActiveBoard(); // Load clips from the currently active board
    Q_INVOKABLE bool updateClip(int clipId, const QString& title, const QString& hotkey, const QStringList& tags);
    Q_INVOKABLE bool updateClipImage(int clipId, const QString& imagePath);
    Q_INVOKABLE bool updateClipAudioSettings(int clipId, int volume, double speed);
    Q_INVOKABLE void setClipVolume(int clipId, int volume);  // Real-time volume update
    Q_INVOKABLE void setClipRepeat(int clipId, bool repeat); // Toggle repeat mode

signals:
    void serviceChanged();
    void boardIdChanged();
    void boardNameChanged();
    void clipsChanged();

private slots:
    void onActiveClipsChanged();

private:
    SoundboardService* m_service = nullptr;
    int m_boardId = -1;
    QVector<Clip> m_cache;
};
