#pragma once
#include <QObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QString>

class AppInstance : public QObject {
    Q_OBJECT
public:
    explicit AppInstance(const QString &serverName, QObject *parent = nullptr);
    bool checkSingleInstance();

signals:
    void toggleRequested();
    void drawCommandRequested(const QString &cmd);

private:
    QString m_serverName;
    QLocalServer *m_server = nullptr;
};
