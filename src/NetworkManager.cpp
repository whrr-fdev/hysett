#include "NetworkManager.h"
#include <QProcess>
#include <QSet>
#include <QDir>
#include <QFile>
#include <QFileInfo>

NetworkManager::NetworkManager(QObject *parent) : QObject(parent) {
    refresh();
}

void NetworkManager::detectActiveConnection() {
    QSet<QString> routedIfaces;
    QFile routeFile("/proc/net/route");
    if (routeFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QList<QByteArray> lines = routeFile.readAll().split('\n');
        for (int i = 1; i < lines.size(); ++i) {
            QByteArray line = lines[i].trimmed();
            if (line.isEmpty()) continue;
            QList<QByteArray> cols = line.split('\t');
            if (cols.size() >= 2) {
                QString iface = QString::fromUtf8(cols[0]).trimmed();
                if (!iface.isEmpty()) routedIfaces.insert(iface);
            }
        }
        routeFile.close();
    }

    QString chosenIface;
    QString chosenType = "none";

    QDir netDir("/sys/class/net");
    const QStringList ifaces = netDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &iface : ifaces) {
        if (iface == "lo" || iface.startsWith("virbr") || iface.startsWith("docker") ||
            iface.startsWith("veth") || iface.startsWith("tun") || iface.startsWith("tap") ||
            iface.startsWith("singbox") || iface.startsWith("throne") || iface.startsWith("wg")) {
            continue;
        }
        QFile carrierFile("/sys/class/net/" + iface + "/carrier");
        bool carrierUp = false;
        if (carrierFile.open(QIODevice::ReadOnly)) {
            carrierUp = (carrierFile.readAll().trimmed() == "1");
            carrierFile.close();
        }
        if (!carrierUp && !routedIfaces.contains(iface)) continue;

        QString sysPath = QFileInfo("/sys/class/net/" + iface).canonicalFilePath();
        bool isUsb = sysPath.contains("/usb") || iface.startsWith("usb") || iface.startsWith("rndis");
        bool isWifi = QFileInfo("/sys/class/net/" + iface + "/wireless").exists() || iface.startsWith("wl");

        if (isUsb) {
            chosenIface = iface;
            chosenType = "usb";
            break; // Приоритет индикации активного USB-модема
        } else if (isWifi && chosenType == "none") {
            chosenIface = iface;
            chosenType = "wifi";
        } else if (!isWifi && chosenType != "usb") {
            chosenIface = iface;
            chosenType = "ethernet";
        }
    }

    m_activeInterface = chosenIface;
    m_connectionType = chosenType;

    if (chosenType == "usb") {
        m_connectionIcon = "󰄜";
        m_connectionTitle = "Раздача с телефона (USB-модем • " + chosenIface + ")";
    } else if (chosenType == "ethernet") {
        m_connectionIcon = "󰈀";
        m_connectionTitle = "Проводной интернет (Кабель • " + chosenIface + ")";
    } else if (chosenType == "wifi") {
        m_connectionIcon = "󰤨";
        m_connectionTitle = m_currentSsid.isEmpty() ? ("Wi-Fi (" + chosenIface + ")") : ("Wi-Fi • " + m_currentSsid);
    } else {
        m_connectionIcon = "󰖪";
        m_connectionTitle = "Нет подключения к сети";
    }

    m_ipAddress = "Нет IP";
    if (!chosenIface.isEmpty()) {
        QProcess pIp;
        pIp.start("ip", {"-4", "-br", "addr", "show", "dev", chosenIface});
        pIp.waitForFinished(400);
        QString out = QString::fromUtf8(pIp.readAllStandardOutput()).trimmed();
        QStringList parts = out.split(' ', Qt::SkipEmptyParts);
        if (parts.size() >= 3) {
            m_ipAddress = parts[2];
        }
    }
}

void NetworkManager::refresh() {
    QProcess pRadio;
    pRadio.start("nmcli", {"radio", "wifi"});
    pRadio.waitForFinished(400);
    m_wifiEnabled = QString::fromUtf8(pRadio.readAllStandardOutput()).trimmed().contains("enabled");

    detectActiveConnection();
    scanWifi();
    emit stateChanged();
}

void NetworkManager::setWifiEnabled(bool v) {
    m_wifiEnabled = v;
    emit stateChanged();
    QProcess::startDetached("nmcli", {"radio", "wifi", v ? "on" : "off"});
    if (v) scanWifi();
    else {
        m_networks.clear();
        m_currentSsid.clear();
        detectActiveConnection();
        emit networksChanged();
        emit stateChanged();
    }
}

void NetworkManager::scanWifi() {
    if (!m_wifiEnabled || m_scanning) return;
    m_scanning = true;
    emit scanningChanged();

    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc]() {
        QString out = QString::fromUtf8(proc->readAllStandardOutput());
        proc->deleteLater();

        m_networks.clear();
        m_currentSsid.clear();
        QSet<QString> seen;

        for (const QString &line : out.split('\n', Qt::SkipEmptyParts)) {
            QStringList parts = line.split(':');
            if (parts.size() < 4) continue;
            bool inUse = (parts[0].trimmed() == "*");
            QString ssid = parts[1].trimmed();
            int signal = parts[2].trimmed().toInt();
            QString sec = parts[3].trimmed();

            if (ssid.isEmpty() || seen.contains(ssid)) continue;
            seen.insert(ssid);

            if (inUse) m_currentSsid = ssid;

            QVariantMap net;
            net["ssid"] = ssid;
            net["signal"] = signal;
            net["security"] = sec.isEmpty() ? "Открытая" : sec;
            net["secured"] = !sec.isEmpty() && sec != "--";
            net["connected"] = inUse;
            m_networks.append(net);
        }

        m_scanning = false;
        detectActiveConnection();
        emit scanningChanged();
        emit networksChanged();
        emit stateChanged();
    });

    proc->start("nmcli", {"-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"});
}

void NetworkManager::connectToWifi(const QString &ssid, const QString &password) {
    m_statusMessage = "Подключение к " + ssid + "...";
    emit statusChanged();

    QProcess *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, ssid]() {
        int code = proc->exitCode();
        proc->deleteLater();
        if (code == 0) {
            m_statusMessage = "Подключено к " + ssid;
        } else {
            m_statusMessage = "Ошибка подключения к " + ssid;
        }
        emit statusChanged();
        refresh();
    });

    QStringList args = {"dev", "wifi", "connect", ssid};
    if (!password.isEmpty()) {
        args << "password" << password;
    }
    proc->start("nmcli", args);
}

void NetworkManager::disconnectCurrent() {
    if (m_currentSsid.isEmpty()) return;
    QProcess::execute("nmcli", {"con", "down", m_currentSsid});
    refresh();
}

void NetworkManager::openConnectionEditor() {
    QProcess::startDetached("nm-connection-editor", {});
}
