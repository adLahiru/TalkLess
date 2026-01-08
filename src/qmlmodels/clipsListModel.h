#pragma once

#include <QAbstractListModel>
#include <QVector>

#include "services/soundboardService.h"
#include "models/clip.h"

class ClipsListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int boardId READ boardId WRITE setBoardId NOTIFY boardIdChanged)
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
        IsPlayingRole,
        IsRepeatRole,
        LockedRole
    };

    explicit ClipsListModel(QObject* parent = nullptr);

    void setService(SoundboardService* service);

    // Board ID to display clips from
    int boardId() const { return m_boardId; }
    void setBoardId(int id);

    // Model interface
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_cache.size(); }

    // Invokable methods for QML
    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadActiveBoard();  // Load clips from the currently active board

signals:
    void boardIdChanged();
    void clipsChanged();

private slots:
    void onActiveClipsChanged();

private:
    SoundboardService* m_service = nullptr;
    int m_boardId = -1;
    QVector<Clip> m_cache;
};
