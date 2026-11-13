#include "BluetoothManager.h"
#include <QProcess>
#include <QTimer>
#include <QRegularExpression>
#include <QSet>
#include <algorithm>

BluetoothManager::BluetoothManager(QObject *parent) : QObject(parent) {
    refresh();
}

static QString stripAnsiCodes(QString s) {
    static const QRegularExpression ansiRe("\x1b\\[[0-9;]*[a-zA-Z]");
    return s.remove(ansiRe);
}

void BluetoothManager::refresh() {
    QProcess pShow;
    pShow.start("bluetoothctl", {"show"});
    pShow.waitForFinished(600);
    QString outShow = stripAnsiCodes(QString::fromUtf8(pShow.readAllStandardOutput()));

    QProcess pConn;
    pConn.start("bluetoothctl", {"devices", "Connected"});
    pConn.waitForFinished(500);
    QString outConn = stripAnsiCodes(QString::fromUtf8(pConn.readAllStandardOutput()));

    QSet<QString> connectedMacs;
    QMap<QString, QString> devNames;
    for (const QString &line : outConn.split('\n', Qt::SkipEmptyParts)) {
        QString trimmed = line.trimmed();
        if (!trimmed.startsWith("Device ")) continue;
        QStringList parts = trimmed.split(' ', Qt::SkipEmptyParts);
        if (parts.size() >= 3) {
            QString mac = parts[1].trimmed();
            QString name = parts.mid(2).join(' ').trimmed();
            connectedMacs.insert(mac);
            devNames[mac] = name;
        }
    }

    m_powered = outShow.contains("Powered: yes", Qt::CaseInsensitive) ||
                outShow.contains("PowerState: on", Qt::CaseInsensitive) ||
                !connectedMacs.isEmpty();
    emit stateChanged();

    if (!m_powered) {
        m_devices.clear();
        emit devicesChanged();
        return;
    }

    QProcess pDevs;
    pDevs.start("bluetoothctl", {"devices"});
    pDevs.waitForFinished(600);
    QString outDevs = stripAnsiCodes(QString::fromUtf8(pDevs.readAllStandardOutput()));

    for (const QString &line : outDevs.split('\n', Qt::SkipEmptyParts)) {
        QString trimmed = line.trimmed();
        if (!trimmed.startsWith("Device ")) continue;
        QStringList parts = trimmed.split(' ', Qt::SkipEmptyParts);
        if (parts.size() >= 3) {
            QString mac = parts[1].trimmed();
            QString name = parts.mid(2).join(' ').trimmed();
            if (!devNames.contains(mac) || devNames[mac].isEmpty()) {
                devNames[mac] = name;
            }
        }
    }

    static const QRegularExpression batRe("Battery Percentage:\\s*0x[0-9a-fA-F]+\\s*\\((\\d+)\\)");
    QVariantList nextList;

    for (auto it = devNames.constBegin(); it != devNames.constEnd(); ++it) {
        const QString &mac = it.key();
        const QString &name = it.value();

        QProcess pInfo;
        pInfo.start("bluetoothctl", {"info", mac});
        pInfo.waitForFinished(350);
        QString info = stripAnsiCodes(QString::fromUtf8(pInfo.readAllStandardOutput()));

        bool connected = connectedMacs.contains(mac) || info.contains("Connected: yes", Qt::CaseInsensitive);
        bool paired = info.contains("Paired: yes", Qt::CaseInsensitive) || connected;
        bool isAudio = info.contains("Audio", Qt::CaseInsensitive) ||
                       info.contains("Headset", Qt::CaseInsensitive) ||
                       info.contains("headphones", Qt::CaseInsensitive) ||
                       name.contains("JBL", Qt::CaseInsensitive) ||
                       name.contains("Buds", Qt::CaseInsensitive) ||
                       name.contains("AirPods", Qt::CaseInsensitive);

        int battery = -1;
        QRegularExpressionMatch bm = batRe.match(info);
        if (bm.hasMatch()) {
            battery = bm.captured(1).toInt();
        }

        QVariantMap d;
        d["mac"] = mac;
        d["name"] = name;
        d["connected"] = connected;
        d["paired"] = paired;
        d["isAudio"] = isAudio;
        d["battery"] = battery;
        nextList.append(d);
    }

    std::sort(nextList.begin(), nextList.end(), [](const QVariant &a, const QVariant &b) {
        QVariantMap ma = a.toMap(), mb = b.toMap();
        if (ma["connected"].toBool() != mb["connected"].toBool())
            return ma["connected"].toBool() > mb["connected"].toBool();
        if (ma["paired"].toBool() != mb["paired"].toBool())
            return ma["paired"].toBool() > mb["paired"].toBool();
        return ma["name"].toString().toLower() < mb["name"].toString().toLower();
    });

    m_devices = nextList;
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
