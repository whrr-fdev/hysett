#include "NetworkManager.h"
#include <QProcess>
#include <QSet>

NetworkManager::NetworkManager(QObject *parent) : QObject(parent) {
    refresh();
}

void NetworkManager::refresh() {
    QProcess pRadio;
    pRadio.start("nmcli", {"radio", "wifi"});
    pRadio.waitForFinished(500);
    m_wifiEnabled = QString::fromUtf8(pRadio.readAllStandardOutput()).trimmed().contains("enabled");

    QProcess pIp;
    pIp.start("sh", {"-c", "ip -4 -br addr show scope global | awk '{print $3}' | head -n 1"});
    pIp.waitForFinished(500);
    m_ipAddress = QString::fromUtf8(pIp.readAllStandardOutput()).trimmed();
    if (m_ipAddress.isEmpty()) m_ipAddress = "Нет IP";

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
