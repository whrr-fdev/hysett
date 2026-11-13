#include "BluetoothManager.h"
#include <QProcess>
#include <QRegularExpression>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <algorithm>

static QString btAutoConfPath() {
    return QDir::homePath() + "/.config/hypr/scripts/bt_autoconnect.conf";
}

static QString stripAnsiCodes(QString s) {
    static const QRegularExpression ansiRe("\x1b\\[[0-9;]*[a-zA-Z]");
    return s.remove(ansiRe);
}

static bool isLikelyAudioName(const QString &name, const QString &info = QString()) {
    return info.contains("Audio", Qt::CaseInsensitive) ||
           info.contains("Headset", Qt::CaseInsensitive) ||
           info.contains("Headphones", Qt::CaseInsensitive) ||
           info.contains("0000110b", Qt::CaseInsensitive) ||
           info.contains("0000110e", Qt::CaseInsensitive) ||
           name.contains("JBL", Qt::CaseInsensitive) ||
           name.contains("TUNE", Qt::CaseInsensitive) ||
           name.contains("Buds", Qt::CaseInsensitive) ||
           name.contains("AirPods", Qt::CaseInsensitive) ||
           name.contains("Sony", Qt::CaseInsensitive) ||
           name.contains("WH-", Qt::CaseInsensitive) ||
           name.contains("WF-", Qt::CaseInsensitive) ||
           name.contains("Marshall", Qt::CaseInsensitive) ||
           name.contains("Soundcore", Qt::CaseInsensitive) ||
           name.contains("Headphone", Qt::CaseInsensitive) ||
           name.contains("Earbuds", Qt::CaseInsensitive);
}

BluetoothManager::BluetoothManager(QObject *parent) : QObject(parent) {
    QFile cf(btAutoConfPath());
    if (cf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString val = QString::fromUtf8(cf.readAll()).trimmed();
        m_autoConnect = (val != "0" && val.compare("false", Qt::CaseInsensitive) != 0);
        cf.close();
    }

    refresh();

    m_autoTimer = new QTimer(this);
    m_autoTimer->setInterval(12000);
    connect(m_autoTimer, &QTimer::timeout, this, &BluetoothManager::pollAutoConnect);
    m_autoTimer->start();
    QTimer::singleShot(1500, this, &BluetoothManager::pollAutoConnect);
}

void BluetoothManager::setAutoConnect(bool v) {
    if (m_autoConnect != v) {
        m_autoConnect = v;
        QFile cf(btAutoConfPath());
        if (cf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream(&cf) << (v ? "1\n" : "0\n");
            cf.close();
        }
        emit stateChanged();
        if (v) {
            m_manuallyDisconnectedMacs.clear();
            pollAutoConnect();
        }
    }
}

void BluetoothManager::pollAutoConnect() {
    if (!m_powered || !m_autoConnect || m_scanning || m_autoConnectBusy) return;

    m_autoConnectBusy = true;
    QProcess *pConn = new QProcess(this);
    connect(pConn, &QProcess::finished, this, [this, pConn]() {
        QString outConn = stripAnsiCodes(QString::fromUtf8(pConn->readAllStandardOutput()));
        pConn->deleteLater();

        for (const QString &ln : outConn.split('\n', Qt::SkipEmptyParts)) {
            if (ln.trimmed().startsWith("Device ")) {
                // Уже есть подключенное устройство — ничего не делаем
                m_autoConnectBusy = false;
                return;
            }
        }

        // Если ничего не подключено — ищем сопряженные наушники и подключаемся к ним
        QProcess *pDevs = new QProcess(this);
        connect(pDevs, &QProcess::finished, this, [this, pDevs]() {
            QString outDevs = stripAnsiCodes(QString::fromUtf8(pDevs->readAllStandardOutput()));
            pDevs->deleteLater();

            QString targetMac;
            QString fallbackMac;
            for (const QString &line : outDevs.split('\n', Qt::SkipEmptyParts)) {
                QString trimmed = line.trimmed();
                if (!trimmed.startsWith("Device ")) continue;
                QStringList parts = trimmed.split(' ', Qt::SkipEmptyParts);
                if (parts.size() < 3) continue;
                QString mac = parts[1].trimmed();
                QString name = parts.mid(2).join(' ').trimmed();
                if (m_manuallyDisconnectedMacs.contains(mac)) continue;

                if (isLikelyAudioName(name)) {
                    targetMac = mac;
                    break;
                }
                if (fallbackMac.isEmpty()) fallbackMac = mac;
            }

            if (targetMac.isEmpty()) targetMac = fallbackMac;
            if (targetMac.isEmpty()) {
                m_autoConnectBusy = false;
                return;
            }

            QProcess::startDetached("bluetoothctl", {"trust", targetMac});
            QProcess *pTry = new QProcess(this);
            connect(pTry, &QProcess::finished, this, [this, pTry]() {
                QString res = stripAnsiCodes(QString::fromUtf8(pTry->readAllStandardOutput()));
                pTry->deleteLater();
                m_autoConnectBusy = false;
                if (res.contains("Connection successful", Qt::CaseInsensitive)) {
                    refresh();
                }
            });
            pTry->start("bluetoothctl", {"connect", targetMac});
        });
        pDevs->start("bluetoothctl", {"devices", "Paired"});
    });
    pConn->start("bluetoothctl", {"devices", "Connected"});
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

    bool hwPowered = outShow.contains("Powered: yes", Qt::CaseInsensitive) ||
                     outShow.contains("PowerState: on", Qt::CaseInsensitive) ||
                     outShow.contains("PowerState: off-enabling", Qt::CaseInsensitive) ||
                     !connectedMacs.isEmpty();
    if (QDateTime::currentMSecsSinceEpoch() >= m_powerTransitionUntilMs || hwPowered == m_powered) {
        m_powered = hwPowered;
    }
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
        bool trusted = info.contains("Trusted: yes", Qt::CaseInsensitive);
        bool isAudio = isLikelyAudioName(name, info);

        if (paired && isAudio && !trusted) {
            QProcess::startDetached("bluetoothctl", {"trust", mac});
        }

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
    m_powerTransitionUntilMs = QDateTime::currentMSecsSinceEpoch() + 1800;
    emit stateChanged();

    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc]() {
        proc->deleteLater();
        QTimer::singleShot(350, this, &BluetoothManager::refresh);
        QTimer::singleShot(1100, this, &BluetoothManager::refresh);
    });
    if (v) {
        proc->start("sh", {"-c",
            "rfkill unblock bluetooth 2>/dev/null; "
            "for d in /sys/bus/usb/devices/*; do "
            "  if [ -f '$d/bDeviceClass' ] && grep -qiE 'e0|ef' '$d/bDeviceClass' 2>/dev/null; then "
            "    echo on > '$d/power/control' 2>/dev/null || true; "
            "  fi; "
            "done; "
            "hciconfig hci0 up 2>/dev/null || true; "
            "bluetoothctl power on"
        });
    } else {
        proc->start("bluetoothctl", {"power", "off"});
    }
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
    if (isConnected) {
        m_manuallyDisconnectedMacs.insert(mac);
    } else {
        m_manuallyDisconnectedMacs.remove(mac);
        QProcess::startDetached("bluetoothctl", {"trust", mac});
    }
    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc]() {
        proc->deleteLater();
        refresh();
    });
    proc->start("bluetoothctl", {isConnected ? "disconnect" : "connect", mac});
}

void BluetoothManager::removeDevice(const QString &mac) {
    m_manuallyDisconnectedMacs.remove(mac);
    QProcess::execute("bluetoothctl", {"remove", mac});
    refresh();
}

void BluetoothManager::openBlueman() {
    QProcess::startDetached("blueman-manager", {});
}
