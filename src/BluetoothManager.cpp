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
    m_autoTimer->setInterval(5000);
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
    if (m_scanning || m_autoConnectBusy) return;

    m_autoConnectBusy = true;
    QProcess *pShow = new QProcess(this);
    connect(pShow, &QProcess::finished, this, [this, pShow]() {
        QString outShow = stripAnsiCodes(QString::fromUtf8(pShow->readAllStandardOutput()));
        pShow->deleteLater();

        bool isOn = outShow.contains("PowerState: on", Qt::CaseInsensitive) ||
                    (outShow.contains("Powered: yes", Qt::CaseInsensitive) && !outShow.contains("PowerState: off", Qt::CaseInsensitive));
        if (m_powered != isOn && QDateTime::currentMSecsSinceEpoch() >= m_powerTransitionUntilMs) {
            m_powered = isOn;
            emit stateChanged();
        }
        m_autoConnectBusy = false;
    });
    pShow->start("bluetoothctl", {"show"});
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

    bool hwPowered = outShow.contains("PowerState: on", Qt::CaseInsensitive) ||
                     outShow.contains("PowerState: off-enabling", Qt::CaseInsensitive) ||
                     (outShow.contains("Powered: yes", Qt::CaseInsensitive) && !outShow.contains("PowerState: off", Qt::CaseInsensitive)) ||
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
    m_powerTransitionUntilMs = QDateTime::currentMSecsSinceEpoch() + 3200;
    emit stateChanged();

    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, v]() {
        proc->deleteLater();
        QTimer::singleShot(400, this, &BluetoothManager::refresh);
        if (v && m_autoConnect) {
            QTimer::singleShot(1400, this, [this]() {
                for (const QVariant &dv : m_devices) {
                    QVariantMap dm = dv.toMap();
                    QString mac = dm["mac"].toString();
                    if (dm["paired"].toBool() && !dm["connected"].toBool() && !m_manuallyDisconnectedMacs.contains(mac)) {
                        QProcess::startDetached("bluetoothctl", {"connect", mac});
                        break;
                    }
                }
                QTimer::singleShot(1800, this, &BluetoothManager::refresh);
            });
        }
    });
    if (v) {
        proc->start("sh", {"-c",
            "rfkill unblock bluetooth 2>/dev/null; "
            "if ! bluetoothctl show 2>/dev/null | grep -q 'PowerState: on'; then "
            "  sudo -n /usr/local/bin/hysett-bt-revive >/dev/null 2>&1; "
            "else "
            "  bluetoothctl power on >/dev/null 2>&1 || sudo -n /usr/local/bin/hysett-bt-revive >/dev/null 2>&1; "
            "fi"
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
