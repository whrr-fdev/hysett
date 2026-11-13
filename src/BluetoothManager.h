#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>
#include <QSet>
#include <QTimer>

class BluetoothManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool powered READ powered WRITE setPowered NOTIFY stateChanged)
    Q_PROPERTY(bool autoConnect READ autoConnect WRITE setAutoConnect NOTIFY stateChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit BluetoothManager(QObject *parent = nullptr);

    bool powered() const { return m_powered; }
    void setPowered(bool v);

    bool autoConnect() const { return m_autoConnect; }
    void setAutoConnect(bool v);

    QVariantList devices() const { return m_devices; }
    bool scanning() const { return m_scanning; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void scanDevices();
    Q_INVOKABLE void toggleConnect(const QString &mac, bool isConnected);
    Q_INVOKABLE void removeDevice(const QString &mac);
    Q_INVOKABLE void openBlueman();

signals:
    void stateChanged();
    void devicesChanged();
    void scanningChanged();

private:
    void pollAutoConnect();

    bool m_powered = false;
    qint64 m_powerTransitionUntilMs = 0;
    bool m_autoConnect = true;
    bool m_autoConnectBusy = false;
    QVariantList m_devices;
    bool m_scanning = false;
    QSet<QString> m_manuallyDisconnectedMacs;
    QTimer *m_autoTimer = nullptr;
};
