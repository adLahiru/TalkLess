#ifndef SOUNDBOARDSECTION_H
#define SOUNDBOARDSECTION_H

#include <QObject>
#include <QString>
#include <QList>
#include "audioclip.h"

class SoundboardSection : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id WRITE setId NOTIFY idChanged)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString imagePath READ imagePath WRITE setImagePath NOTIFY imagePathChanged)
    Q_PROPERTY(bool isSelected READ isSelected WRITE setIsSelected NOTIFY isSelectedChanged)
    Q_PROPERTY(int clipCount READ clipCount NOTIFY clipCountChanged)

public:
    explicit SoundboardSection(QObject *parent = nullptr);

    QString id() const { return m_id; }
    void setId(const QString &id) {
        if (m_id != id) {
            m_id = id;
            emit idChanged();
        }
    }

    QString name() const { return m_name; }
    void setName(const QString &name) {
        if (m_name != name) {
            m_name = name;
            emit nameChanged();
        }
    }

    QString imagePath() const { return m_imagePath; }
    void setImagePath(const QString &imagePath) {
        if (m_imagePath != imagePath) {
            m_imagePath = imagePath;
            emit imagePathChanged();
        }
    }

    bool isSelected() const { return m_isSelected; }
    void setIsSelected(bool isSelected) {
        if (m_isSelected != isSelected) {
            m_isSelected = isSelected;
            emit isSelectedChanged();
        }
    }

    int clipCount() const { return m_clipIds.count(); }

    QStringList clipIds() const { return m_clipIds; }
    void addClipId(const QString &clipId) {
        if (!m_clipIds.contains(clipId)) {
            m_clipIds.append(clipId);
            emit clipCountChanged();
        }
    }
    void removeClipId(const QString &clipId) {
        if (m_clipIds.removeOne(clipId)) {
            emit clipCountChanged();
        }
    }

signals:
    void idChanged();
    void nameChanged();
    void imagePathChanged();
    void isSelectedChanged();
    void clipCountChanged();

private:
    QString m_id;
    QString m_name;
    QString m_imagePath;
    bool m_isSelected = false;
    QStringList m_clipIds;
};

#endif // SOUNDBOARDSECTION_H
