#include "MonitorsManager.h"
#include <QProcess>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <cmath>

MonitorsManager::MonitorsManager(QObject *parent) : QObject(parent) {
    m_revertTimer = new QTimer(this);
    m_revertTimer->setInterval(1000);
    connect(m_revertTimer, &QTimer::timeout, this, [this]() {
        if (m_revertCountdown > 1) {
            m_revertCountdown--;
            emit revertCountdownChanged();
        } else {
            cancelMonitorMode();
        }
    });

    refreshMonitors();
    loadDisplaySettings();
}

void MonitorsManager::refreshMonitors() {
    QProcess proc;
    proc.start("hyprctl", {"monitors", "all"});
    proc.waitForFinished();
    QString output = QString::fromUtf8(proc.readAllStandardOutput());

    m_monitors.clear();
    QVariantMap current;
    QStringList modes;

    auto finalizeMonitor = [&]() {
        if (current.isEmpty()) return;
        int w = current.value("width", 1920).toInt();
        int h = current.value("height", 1080).toInt();
        double hz = current.value("refreshRate", 60.0).toDouble();

        QString curModeStr = QString("%1x%2@%3Hz").arg(w).arg(h).arg(hz, 0, 'f', 2);
        int modeIdx = -1;

        // Ищем точное или ближайшее совпадение по разрешению и Гц
        for (int i = 0; i < modes.size(); ++i) {
            if (modes[i] == curModeStr) {
                modeIdx = i;
                break;
            }
        }
        if (modeIdx == -1) {
            QString prefix = QString("%1x%2@").arg(w).arg(h);
            for (int i = 0; i < modes.size(); ++i) {
                if (modes[i].startsWith(prefix)) {
                    QString hzPart = modes[i].mid(prefix.length());
                    hzPart.remove("Hz");
                    if (std::abs(hzPart.toDouble() - hz) < 1.5) {
                        modeIdx = i;
                        break;
                    }
                }
            }
        }
        if (modeIdx == -1) {
            modes.prepend(curModeStr);
            modeIdx = 0;
        }

        current["availableModes"] = modes;
        current["currentModeIndex"] = modeIdx;
        m_monitors.append(current);
    };

    for (const auto &line : output.split('\n')) {
        QString t = line.trimmed();
        if (t.startsWith("Monitor ") && t.contains("ID")) {
            finalizeMonitor();
            current.clear();
            modes.clear();

            QString rest = t.mid(8).trimmed();
            int spIdx = rest.indexOf(' ');
            if (spIdx != -1) {
                current["name"] = rest.left(spIdx);
            }
            int idStart = rest.indexOf("(ID ");
            if (idStart != -1) {
                int idEnd = rest.indexOf(')', idStart);
                if (idEnd != -1) {
                    current["id"] = rest.mid(idStart + 4, idEnd - idStart - 4).toInt();
                }
            }
            continue;
        }

        if (!current.isEmpty()) {
            // Точный парсер из monitors.rs: split(" at ") и split('@')
            if (t.contains(" at ") && t.contains('@') && t.contains('x')) {
                QStringList parts = t.split(" at ");
                QStringList mp = parts[0].split('@');
                if (mp.size() == 2) {
                    QStringList wh = mp[0].split('x');
                    if (wh.size() == 2) {
                        current["width"] = wh[0].toInt();
                        current["height"] = wh[1].toInt();
                    }
                    QString hzClean = mp[1];
                    hzClean.remove("Hz");
                    current["refreshRate"] = hzClean.toDouble();
                }
                if (parts.size() > 1) {
                    QStringList xy = parts[1].split('x');
                    if (xy.size() == 2) {
                        current["x"] = xy[0].toInt();
                        current["y"] = xy[1].toInt();
                    }
                }
            } else if (t.startsWith("description:")) {
                current["description"] = t.mid(12).trimmed();
            } else if (t.startsWith("scale:")) {
                current["scale"] = t.mid(6).trimmed().toDouble();
            } else if (t.startsWith("transform:")) {
                current["transform"] = t.mid(10).trimmed().toInt();
            } else if (t.startsWith("disabled:")) {
                current["disabled"] = (t.mid(9).trimmed() == "true" || t.mid(9).trimmed() == "1");
            } else if (t.startsWith("availableModes:")) {
                QString rest = t.mid(15).trimmed();
                for (const auto &mStr : rest.split(' ', Qt::SkipEmptyParts)) {
                    modes.append(mStr.trimmed());
                }
            }
        }
    }

    finalizeMonitor();

    if (m_monitors.isEmpty()) {
        QVariantMap def;
        def["id"] = 0;
        def["name"] = "HDMI-A-1";
        def["description"] = "Xiaomi Corporation Mi Monitor";
        def["width"] = 1920;
        def["height"] = 1080;
        def["refreshRate"] = 160.0;
        def["scale"] = 1.0;
        def["transform"] = 0;
        def["disabled"] = false;
        def["availableModes"] = QStringList{"1920x1080@160.00Hz", "1920x1080@144.00Hz", "1920x1080@60.00Hz"};
        def["currentModeIndex"] = 0;
        m_monitors.append(def);
    }

    emit monitorsChanged();
}

void MonitorsManager::loadDisplaySettings() {
    QProcess p;
    p.start("hyprctl", {"-j", "getoption", "misc:vrr"});
    p.waitForFinished();
    QString vrrOut = QString::fromUtf8(p.readAllStandardOutput());
    if (vrrOut.contains("\"int\": 1")) m_vrrMode = 1;
    else if (vrrOut.contains("\"int\": 2")) m_vrrMode = 2;
    else m_vrrMode = 0;

    QProcess p2;
    p2.start("hyprctl", {"-j", "getoption", "misc:mouse_move_enables_dpms"});
    p2.waitForFinished();
    m_mouseMoveDpms = p2.readAllStandardOutput().contains("\"int\": 1");

    QProcess p3;
    p3.start("hyprctl", {"-j", "getoption", "misc:key_press_enables_dpms"});
    p3.waitForFinished();
    m_keyPressDpms = p3.readAllStandardOutput().contains("\"int\": 1");
}

void MonitorsManager::setVrrMode(int v) {
    if (m_vrrMode == v) return;
    m_vrrMode = v;
    QProcess::startDetached("hyprctl", {"keyword", "misc:vrr", QString::number(v)});
    emit vrrModeChanged();
}

void MonitorsManager::setMouseMoveDpms(bool v) {
    if (m_mouseMoveDpms == v) return;
    m_mouseMoveDpms = v;
    QProcess::startDetached("hyprctl", {"keyword", "misc:mouse_move_enables_dpms", v ? "true" : "false"});
    emit mouseMoveDpmsChanged();
}

void MonitorsManager::setKeyPressDpms(bool v) {
    if (m_keyPressDpms == v) return;
    m_keyPressDpms = v;
    QProcess::startDetached("hyprctl", {"keyword", "misc:key_press_enables_dpms", v ? "true" : "false"});
    emit keyPressDpmsChanged();
}

void MonitorsManager::applyMonitor(const QVariantMap &m) {
    saveMonitorsToLua();
    QString luaPath = QDir::homePath() + "/.config/hypr/monitors.lua";
    QProcess::startDetached("hyprctl", {"eval", QString("dofile('%1')").arg(luaPath)});
}

void MonitorsManager::saveMonitorsToLua() {
    QString luaPath = QDir::homePath() + "/.config/hypr/monitors.lua";
    QFile file(luaPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return;

    QTextStream out(&file);
    out << "-- Auto-generated by Control Center\n";
    for (const auto &item : m_monitors) {
        QVariantMap m = item.toMap();
        if (m["disabled"].toBool()) {
            out << QString("hl.monitor({\n    output   = \"%1\",\n    disabled = true,\n})\n").arg(m["name"].toString());
        } else {
            out << QString("hl.monitor({\n    output   = \"%1\",\n    mode     = \"%2x%3@%4\",\n    position = \"%5x%6\",\n    scale    = \"%7\",\n    transform = %8,\n})\n")
                .arg(m["name"].toString())
                .arg(m["width"].toInt())
                .arg(m["height"].toInt())
                .arg(m["refreshRate"].toDouble(), 0, 'f', 2)
                .arg(m["x"].toInt())
                .arg(m["y"].toInt())
                .arg(m["scale"].toDouble(), 0, 'f', 2)
                .arg(m["transform"].toInt());
        }
    }
}

void MonitorsManager::setMonitorDisabled(int index, bool disabled) {
    if (index < 0 || index >= m_monitors.size()) return;
    QVariantMap m = m_monitors[index].toMap();
    m["disabled"] = disabled;
    m_monitors[index] = m;
    applyMonitor(m);
    emit monitorsChanged();
}

void MonitorsManager::requestMonitorMode(int index, const QString &modeStr) {
    if (index < 0 || index >= m_monitors.size()) return;
    m_previousMonitorState = m_monitors[index].toMap();
    m_pendingMonitorIdx = index;

    QVariantMap m = m_previousMonitorState;
    QStringList parts = modeStr.split('@');
    if (parts.size() == 2) {
        QStringList wh = parts[0].split('x');
        if (wh.size() == 2) {
            m["width"] = wh[0].toInt();
            m["height"] = wh[1].toInt();
            QString hz = parts[1];
            hz.remove("Hz");
            m["refreshRate"] = hz.toDouble();

            QStringList avail = m["availableModes"].toStringList();
            int newIdx = avail.indexOf(modeStr);
            if (newIdx != -1) m["currentModeIndex"] = newIdx;

            m_monitors[index] = m;
            applyMonitor(m);
            emit monitorsChanged();

            m_revertCountdown = 10;
            m_revertDialogActive = true;
            m_revertTimer->start();
            emit revertCountdownChanged();
            emit revertDialogActiveChanged();
        }
    }
}

void MonitorsManager::confirmMonitorMode() {
    m_revertTimer->stop();
    m_revertDialogActive = false;
    m_pendingMonitorIdx = -1;
    m_previousMonitorState.clear();
    emit revertDialogActiveChanged();
}

void MonitorsManager::cancelMonitorMode() {
    m_revertTimer->stop();
    m_revertDialogActive = false;
    if (m_pendingMonitorIdx >= 0 && m_pendingMonitorIdx < m_monitors.size() && !m_previousMonitorState.isEmpty()) {
        m_monitors[m_pendingMonitorIdx] = m_previousMonitorState;
        applyMonitor(m_previousMonitorState);
        emit monitorsChanged();
    }
    m_pendingMonitorIdx = -1;
    m_previousMonitorState.clear();
    emit revertDialogActiveChanged();
}

void MonitorsManager::setMonitorScale(int index, qreal scale) {
    if (index < 0 || index >= m_monitors.size()) return;
    QVariantMap m = m_monitors[index].toMap();
    m["scale"] = scale;
    m_monitors[index] = m;
    applyMonitor(m);
    emit monitorsChanged();
}

void MonitorsManager::setMonitorTransform(int index, int transform) {
    if (index < 0 || index >= m_monitors.size()) return;
    QVariantMap m = m_monitors[index].toMap();
    m["transform"] = transform;
    m_monitors[index] = m;
    applyMonitor(m);
    emit monitorsChanged();
}
