#include <QFile>
#include "AppInstance.h"

AppInstance::AppInstance(const QString &serverName, QObject *parent)
    : QObject(parent), m_serverName(serverName) {}

bool AppInstance::checkSingleInstance() {
    QLocalSocket socket;
    socket.connectToServer(m_serverName);
    if (socket.waitForConnected(200)) {
        socket.write("TOGGLE");
        socket.flush();
        socket.waitForBytesWritten(200);
        return false;
    }

    QLocalServer::removeServer(m_serverName);
    m_server = new QLocalServer(this);
    if (m_server->listen(m_serverName)) {
        connect(m_server, &QLocalServer::newConnection, this, [this]() {
            QLocalSocket *client = m_server->nextPendingConnection();
            if (client) {
                connect(client, &QLocalSocket::readyRead, this, [this, client]() {
                    QByteArray msg = client->readAll();
                    if (msg.contains("DRAW_DOWN")) emit drawCommandRequested(QStringLiteral("down"));
                    if (msg.contains("DRAW_UP")) emit drawCommandRequested(QStringLiteral("up"));
                    if (msg.contains("DRAW_TOGGLE")) emit drawCommandRequested(QStringLiteral("toggle"));
                    if (msg.contains("DRAW_CLEAR")) emit drawCommandRequested(QStringLiteral("clear"));
                    if (msg.contains("TOGGLE") && !msg.contains("DRAW_TOGGLE")) {
                        emit toggleRequested();
                    }
                });
                connect(client, &QLocalSocket::disconnected, client, &QObject::deleteLater);
            }
        });
    }
    return true;
}
