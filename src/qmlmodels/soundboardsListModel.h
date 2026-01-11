#pragma once

#include <QAbstractListModel>
#include <QPointer>

#include "services/soundboardService.h"   // adjust include path if needed
#include "models/soundboardInfo.h"        // adjust include path if needed

class SoundboardsListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ClipCountRole,
        HotkeyRole,
        ImagePathRole,
        IsActiveRole
    };
    Q_ENUM(Roles)

    explicit SoundboardsListModel(QObject* parent = nullptr);

    void setService(SoundboardService* service);
    SoundboardService* service() const { return m_service; }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool activateByRow(int row);
    Q_INVOKABLE bool activateById(int boardId);
    Q_INVOKABLE bool toggleActiveById(int boardId);  // Toggle active state (for checkbox behavior)
    Q_INVOKABLE int rowForId(int boardId) const;


private slots:
    void onBoardsChanged();
    void onActiveBoardChanged();

private:
    QPointer<SoundboardService> m_service;
    QVector<SoundboardInfo> m_cache;
};
