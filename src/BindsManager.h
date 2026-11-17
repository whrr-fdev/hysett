#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QFileSystemWatcher>
#include <QTimer>

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
    Q_INVOKABLE void addItem(const QString &keys, const QString &cmd, bool isLuaFunc = false);

signals:
    void itemsChanged();

private:
    QString luaPath() const;
    void ensureWatched();

    struct BindEntry {
        int startLine;
        int endLine;
        bool enabled;
        bool isFunc;
        bool isMultiline;
        QString keys;
        QString cmd;
        QString trailingOpts;
        QString description;
    };
    QVector<BindEntry> m_entries;
    QVariantList m_items;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_reloadTimer = nullptr;
    bool m_saving = false;
};
