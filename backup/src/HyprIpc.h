#pragma once
#include <QObject>
#include <QString>
#include <QQmlApplicationEngine>

class HyprIpc : public QObject {
    Q_OBJECT
public:
    explicit HyprIpc(QObject *parent = nullptr);
    void setEngine(QQmlApplicationEngine *eng) { m_engine = eng; }

    Q_INVOKABLE static void dispatch(const QString &cmd);
    Q_INVOKABLE static QString getActiveWorkspace();
    Q_INVOKABLE void trimMemory();
    Q_INVOKABLE void deepCleanMemory();

private:
    QQmlApplicationEngine *m_engine = nullptr;
};
