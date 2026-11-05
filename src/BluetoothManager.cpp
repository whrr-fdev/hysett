#include "BluetoothManager.h"
#include <QProcess>
#include <QTimer>

BluetoothManager::BluetoothManager(QObject *parent) : QObject(parent) {
    refresh();
}

void BluetoothManager::refresh() {
    QProcess pShow;
    pShow.start("bluetoothctl", {"show"});
    pShow.waitForFinished(600);
    QString outShow = QString::fromUtf8(pShow.readAllStandardOutput());
    m_powered = outShow.contains("Powered: yes");
    emit stateChanged();

    if (!m_powered) {
        m_devices.clear();
        emit devicesChanged();
        return;
    }

    QProcess pDevs;
    pDevs.start("bluetoothctl", {"devices"});
    pDevs.waitForFinished(600);
    QString outDevs = QString::fromUtf8(pDevs.readAllStandardOutput());

    m_devices.clear();
    for (const QString &line : outDevs.split('\n', Qt::SkipEmptyParts)) {
        if (!line.startsWith("Device ")) continue;
        QStringList parts = line.split(' ');
        if (parts.size() < 3) continue;
        QString mac = parts[1];
        QString name = parts.mid(2).join(' ');

        QProcess pInfo;
        pInfo.start("bluetoothctl", {"info", mac});
        pInfo.waitForFinished(300);
        QString info = QString::fromUtf8(pInfo.readAllStandardOutput());
        bool connected = info.contains("Connected: yes");
        bool paired = info.contains("Paired: yes");

        QVariantMap d;
        d["mac"] = mac;
        d["name"] = name;
        d["connected"] = connected;
        d["paired"] = paired;
        m_devices.append(d);
    }
    emit devicesChanged();
}

void BluetoothManager::setPowered(bool v) {
    m_powered = v;
    emit stateChanged();
    QProcess::execute("bluetoothctl", {"power", v ? "on" : "off"});
    refresh();
}

void BluetoothManager::scanDevices() {
    if (!m_powered || m_scanning) return;
    m_scanning = true;
    emit scanningChanged();

    QProcess::startDetached("sh", {"-c", "bluetoothctl --timeout 4 scan on >/dev/null 2>&1"});
    QTimer::singleShot(4200, this, [this]() {
        m_scanning = false;
        emit scanningChanged();
        refresh();
    });
}

void BluetoothManager::toggleConnect(const QString &mac, bool isConnected) {
    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc]() {
        proc->deleteLater();
        refresh();
    });
    proc->start("bluetoothctl", {isConnected ? "disconnect" : "connect", mac});
}

void BluetoothManager::removeDevice(const QString &mac) {
    QProcess::execute("bluetoothctl", {"remove", mac});
    refresh();
}

void BluetoothManager::openBlueman() {
    QProcess::startDetached("blueman-manager", {});
}
