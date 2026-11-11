#include "NetworkManager.h"
#include <QProcess>
#include <QSet>
#include <QMap>
#include <QDir>
#include <QFile>
#include <QFileInfo>

NetworkManager::NetworkManager(QObject *parent) : QObject(parent) {
    refresh();
}

void NetworkManager::detectActiveConnection() {
    QSet<QString> routedIfaces;
    QString primaryDefaultIface;
    int bestMetric = 999999;

    QFile routeFile("/proc/net/route");
    if (routeFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QList<QByteArray> lines = routeFile.readAll().split('\n');
        for (int i = 1; i < lines.size(); ++i) {
            QByteArray line = lines[i].trimmed();
            if (line.isEmpty()) continue;
            QList<QByteArray> cols = line.split('\t');
            if (cols.size() >= 7) {
                QString iface = QString::fromUtf8(cols[0]).trimmed();
                QString dest = QString::fromUtf8(cols[1]).trimmed();
                int metric = cols[6].trimmed().toInt();
                if (!iface.isEmpty()) {
                    routedIfaces.insert(iface);
                    if (dest == "00000000" && !iface.startsWith("tun") && !iface.startsWith("singbox") && !iface.startsWith("throne")) {
                        if (metric < bestMetric) {
                            bestMetric = metric;
                            primaryDefaultIface = iface;
                        }
                    }
                }
            }
        }
        routeFile.close();
    }

    QString prefFile = QDir::homePath() + "/.config/hypr/scripts/preferred_net_iface.txt";
    QString preferredIface;
    QFile pf(prefFile);
    if (pf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        preferredIface = QString::fromUtf8(pf.readAll()).trimmed();
        pf.close();
    }

    m_activeConnections.clear();
    QDir netDir("/sys/class/net");
    const QStringList ifaces = netDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    struct ConnEntry {
        QString iface;
        QString type;
        QString icon;
        QString title;
        QString ip;
    };
    QList<ConnEntry> found;

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

        QProcess pIp;
        pIp.start("ip", {"-4", "-br", "addr", "show", "dev", iface});
        pIp.waitForFinished(250);
        QString out = QString::fromUtf8(pIp.readAllStandardOutput()).trimmed();
        QStringList parts = out.split(' ', Qt::SkipEmptyParts);
        QString ip = (parts.size() >= 3) ? parts[2] : "";
        if (ip.isEmpty() && !carrierUp) continue;

        QString sysPath = QFileInfo("/sys/class/net/" + iface).canonicalFilePath();
        bool isUsb = sysPath.contains("/usb") || iface.startsWith("usb") || iface.startsWith("rndis");
        bool isWifi = QFileInfo("/sys/class/net/" + iface + "/wireless").exists() || iface.startsWith("wl");

        ConnEntry ce;
        ce.iface = iface;
        ce.ip = ip.isEmpty() ? "Получение IP..." : ip;
        if (isUsb) {
            ce.type = "usb";
            ce.icon = "󰄜";
            ce.title = "Телефон (USB-модем • " + iface + ")";
        } else if (isWifi) {
            ce.type = "wifi";
            ce.icon = "󰤨";
            ce.title = m_currentSsid.isEmpty() ? ("Wi-Fi (" + iface + ")") : ("Wi-Fi • " + m_currentSsid);
        } else {
            ce.type = "ethernet";
            ce.icon = "󰈀";
            ce.title = "Проводная сеть (Кабель • " + iface + ")";
        }
        found.append(ce);
    }

    int chosenIdx = -1;
    if (!preferredIface.isEmpty()) {
        for (int i = 0; i < found.size(); ++i) {
            if (found[i].iface == preferredIface) { chosenIdx = i; break; }
        }
    }
    if (chosenIdx < 0 && !primaryDefaultIface.isEmpty()) {
        for (int i = 0; i < found.size(); ++i) {
            if (found[i].iface == primaryDefaultIface) { chosenIdx = i; break; }
        }
    }
    if (chosenIdx < 0 && !found.isEmpty()) chosenIdx = 0;

    for (int i = 0; i < found.size(); ++i) {
        QVariantMap m;
        m["iface"] = found[i].iface;
        m["type"] = found[i].type;
        m["icon"] = found[i].icon;
        m["title"] = found[i].title;
        m["ip"] = found[i].ip;
        m["selected"] = (i == chosenIdx);
        m_activeConnections.append(m);
    }

    if (chosenIdx >= 0) {
        m_activeInterface = found[chosenIdx].iface;
        m_connectionType = found[chosenIdx].type;
        m_connectionIcon = found[chosenIdx].icon;
        m_connectionTitle = found[chosenIdx].title;
        m_ipAddress = found[chosenIdx].ip;
    } else {
        m_activeInterface.clear();
        m_connectionType = "none";
        m_connectionIcon = "󰖪";
        m_connectionTitle = "Нет подключения к сети";
        m_ipAddress = "Нет IP";
    }
}

void NetworkManager::selectInterface(const QString &iface) {
    if (iface.trimmed().isEmpty()) return;
    QDir().mkpath(QDir::homePath() + "/.config/hypr/scripts");
    QFile pf(QDir::homePath() + "/.config/hypr/scripts/preferred_net_iface.txt");
    if (pf.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        pf.write(iface.trimmed().toUtf8() + "\n");
        pf.close();
    }

    // Повышаем приоритет выбранного интерфейса в NetworkManager (metric 20 против 250 у остальных)
    QProcess pCon;
    pCon.start("nmcli", {"-t", "-f", "UUID,DEVICE", "con", "show", "--active"});
    pCon.waitForFinished(500);
    const QStringList lines = QString::fromUtf8(pCon.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
    for (const QString &l : lines) {
        QStringList p = l.split(':');
        if (p.size() >= 2) {
            QString uuid = p[0].trimmed();
            QString dev = p[1].trimmed();
            if (dev == "lo" || dev.startsWith("tun") || dev.startsWith("singbox") || dev.startsWith("throne")) continue;
            int metric = (dev == iface.trimmed()) ? 20 : 250;
            QProcess::execute("nmcli", {"con", "modify", uuid, "ipv4.route-metric", QString::number(metric)});
            QProcess::startDetached("nmcli", {"con", "up", uuid});
        }
    }

    detectActiveConnection();
    emit stateChanged();
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
