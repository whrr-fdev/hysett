#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class AnimsManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList anims READ anims NOTIFY animsChanged)
    Q_PROPERTY(int backupCount READ backupCount NOTIFY backupCountChanged)

public:
    explicit AnimsManager(QObject *parent = nullptr);

    QVariantList anims() const { return m_anims; }
    int backupCount() const { return m_history.size(); }

    Q_INVOKABLE void setAnimEnabled(int index, bool enabled);
    Q_INVOKABLE void setAnimSpeed(int index, qreal speed);
    Q_INVOKABLE void setAnimCurve(int index, const QString &kind, const QString &name);
    Q_INVOKABLE void resetItem(int index);
    Q_INVOKABLE void undo();

signals:
    void animsChanged();
    void backupCountChanged();

private:
    void initDefaults();
    void loadFromLua();
    void pushBackup();
    void applyAndSave();
    void applyKeyword(int index);

    QVariantList m_anims;
    QVariantList m_defaults;
    QVector<QVariantList> m_history;
};
