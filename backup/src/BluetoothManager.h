#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>

class BluetoothManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool powered READ powered WRITE setPowered NOTIFY stateChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    explicit BluetoothManager(QObject *parent = nullptr);

    bool powered() const { return m_powered; }
    void setPowered(bool v);

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
    bool m_powered = false;
    QVariantList m_devices;
    bool m_scanning = false;
};
