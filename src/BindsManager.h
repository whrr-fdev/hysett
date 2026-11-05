#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class BindsManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit BindsManager(QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void toggleItem(int index, bool enabled);
    Q_INVOKABLE void updateItem(int index, bool enabled, const QString &keys, const QString &cmd);
    Q_INVOKABLE void deleteItem(int index);
    Q_INVOKABLE void addItem(const QString &keys, const QString &cmd);

signals:
    void itemsChanged();

private:
    QString luaPath() const;
    void syncToFile();

    struct BindEntry {
        int lineIdx;
        bool enabled;
        QString keys;
        QString cmd;
    };
    QVector<BindEntry> m_entries;
    QVariantList m_items;
};
