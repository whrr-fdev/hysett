#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>

class NetworkManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY stateChanged)
    Q_PROPERTY(QString currentSsid READ currentSsid NOTIFY stateChanged)
    Q_PROPERTY(QString ipAddress READ ipAddress NOTIFY stateChanged)
    Q_PROPERTY(QString connectionType READ connectionType NOTIFY stateChanged)
    Q_PROPERTY(QString connectionTitle READ connectionTitle NOTIFY stateChanged)
    Q_PROPERTY(QString connectionIcon READ connectionIcon NOTIFY stateChanged)
    Q_PROPERTY(QString activeInterface READ activeInterface NOTIFY stateChanged)
    Q_PROPERTY(QVariantList activeConnections READ activeConnections NOTIFY stateChanged)
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)

public:
    explicit NetworkManager(QObject *parent = nullptr);

    bool wifiEnabled() const { return m_wifiEnabled; }
    void setWifiEnabled(bool v);

    QString currentSsid() const { return m_currentSsid; }
    QString ipAddress() const { return m_ipAddress; }
    QString connectionType() const { return m_connectionType; }
    QString connectionTitle() const { return m_connectionTitle; }
    QString connectionIcon() const { return m_connectionIcon; }
    QString activeInterface() const { return m_activeInterface; }
    QVariantList activeConnections() const { return m_activeConnections; }
    QVariantList networks() const { return m_networks; }
    bool scanning() const { return m_scanning; }
    QString statusMessage() const { return m_statusMessage; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void selectInterface(const QString &iface);
    Q_INVOKABLE void scanWifi();
    Q_INVOKABLE void connectToWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnectCurrent();
    Q_INVOKABLE void openConnectionEditor();

signals:
    void stateChanged();
    void networksChanged();
    void scanningChanged();
    void statusChanged();

private:
    void detectActiveConnection();
    bool m_wifiEnabled = true;
    QString m_currentSsid;
    QString m_ipAddress = "Нет IP";
    QString m_connectionType = "none";
    QString m_connectionTitle = "Нет подключения";
    QString m_connectionIcon = "󰖪";
    QString m_activeInterface = "";
    QVariantList m_activeConnections;
    QVariantList m_networks;
    bool m_scanning = false;
    QString m_statusMessage;
};
