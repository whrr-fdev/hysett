#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class AutostartManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)

public:
    explicit AutostartManager(QObject *parent = nullptr);

    QVariantList items() const { return m_items; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void toggleItem(int index, bool enabled);
    Q_INVOKABLE void updateItem(int index, bool enabled, const QString &cmd, const QString &workspace);
    Q_INVOKABLE void deleteItem(int index);
    Q_INVOKABLE void addItem(const QString &cmd, const QString &workspace);

signals:
    void itemsChanged();

private:
    QString luaPath() const;
    void syncToFile();

    struct Entry {
        int lineIdx;
        bool enabled;
        QString cmd;
        QString workspace;
    };
    QVector<Entry> m_entries;
    QVariantList m_items;
};
