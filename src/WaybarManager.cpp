#include <QPointer>
#include "WaybarManager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegion>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusVariant>
#include <QDBusArgument>
#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <cmath>
#include <algorithm>
#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Window>
#endif

static QString queryHyprCtlSocket(const QString &request) {
    QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (runtimeDir.isEmpty() || sig.isEmpty()) return {};

    QString sockPath = runtimeDir + "/hypr/" + sig + "/.socket.sock";
    if (!QFile::exists(sockPath)) sockPath = "/tmp/hypr/" + sig + "/.socket.sock";

    int fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return {};

    struct sockaddr_un addr {};
    addr.sun_family = AF_UNIX;
    QByteArray pathBytes = sockPath.toUtf8();
    std::strncpy(addr.sun_path, pathBytes.constData(), sizeof(addr.sun_path) - 1);

    if (::connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
        ::close(fd);
        return {};
    }

    QByteArray req = request.toUtf8();
    ::write(fd, req.constData(), req.size());

    QByteArray response;
    char buf[4096];
    ssize_t n = 0;
    while ((n = ::read(fd, buf, sizeof(buf))) > 0) {
        response.append(buf, n);
    }
    ::close(fd);
    return QString::fromUtf8(response);
}

WaybarManager::WaybarManager(QObject *parent) : QObject(parent) {
    for (int i = 0; i < 60; ++i) {
        m_cpuHistory.append(0); m_tempHistory.append(35); m_memHistory.append(20);
        m_vramHistory.append(10); m_netHistory.append(0);
    }

    initSpecs();
    m_specs = m_defaults;
    loadState();

    QProcess::startDetached("killall", {"-q", "waybar"});
    // Сбрасываем старый ручной addreserved, чтобы панель не сдвигалась вниз (отступ держит strutWin!)

    m_weatherDetails = {{"temp", "+3°C"}, {"feels", "+1°C"}, {"wind", "3.0"}, {"humidity", "80"}, {"desc", "Пасмурно"}, {"icon", "☁️"}, {"isRain", false}, {"isSnow", false}};

    connectHyprEventSocket();
    pollHyprState();
    pollSysStats();
    pollFastState();
    QFile subF(QDir::homePath() + "/.config/hysett_vpn_sub.txt");
    if (subF.open(QIODevice::ReadOnly)) { m_vpnSubUrl = QString::fromUtf8(subF.readAll()).trimmed(); subF.close(); }
    QFile vstF(QDir::homePath() + "/.config/hypr/scripts/vpn_state.json");
    if (vstF.open(QIODevice::ReadOnly)) {
        QJsonObject vo = QJsonDocument::fromJson(vstF.readAll()).object();
        if (vo.contains("server_name")) m_vpnServerName = vo["server_name"].toString(m_vpnServerName);
        if (vo.contains("ru_direct")) m_vpnRuDirect = vo["ru_direct"].toBool(true);
        if (vo.contains("vpn_enabled")) m_vpnWantedEnabled = vo["vpn_enabled"].toBool(false);
        if (vo.contains("active_is_wl")) m_vpnActiveIsWl = vo["active_is_wl"].toBool(false);
        if (vo.contains("whitelist_mode")) m_vpnWhitelistMode = vo["whitelist_mode"].toBool(false);
        vstF.close();
    }
    pollWeather();
    QTimer::singleShot(600, this, &WaybarManager::refreshClipboard);
    QProcess *vpInit = new QProcess(this);
    connect(vpInit, &QProcess::finished, this, [this, vpInit]() { syncVpnStateFromScript(vpInit->readAllStandardOutput()); vpInit->deleteLater(); });
    vpInit->start("/usr/bin/python3", {QDir::homePath() + "/hysett/scripts/hysett_vpn.py", "boot"});
    // Фоновое обновление списков обхода через 25 секунд после старта демона hysett
    QTimer::singleShot(25000, this, [this]() {
        if (!m_vpnBusy) {
            QProcess *p = new QProcess(this);
            connect(p, &QProcess::finished, this, [this, p]() {
                syncVpnStateFromScript(p->readAllStandardOutput());
                p->deleteLater();
            });
            p->start("/usr/bin/python3", {QDir::homePath() + "/hysett/scripts/hysett_vpn.py", "sync_repos_quiet"});
        }
    });

    m_sysTimer = new QTimer(this);
    m_sysTimer->setInterval(450);
    connect(m_sysTimer, &QTimer::timeout, this, &WaybarManager::pollSysStats);
    m_sysTimer->start();

    m_fastTimer = new QTimer(this);
    m_fastTimer->setInterval(1000);
    connect(m_fastTimer, &QTimer::timeout, this, &WaybarManager::pollFastState);
    m_fastTimer->start();

    m_cursorPollTimer = new QTimer(this);
    m_cursorPollTimer->setInterval(28);
    connect(m_cursorPollTimer, &QTimer::timeout, this, [this]() {
        updateAudioCaptureState();
        if (!m_mediaWaves || !mediaActive() || !mediaPlaying()) {
            if (m_globalCursorPos.x() > -100) {
                m_globalCursorPos = QPointF(-500, -500);
                emit cursorPosChanged();
            }
            return;
        }
        if (m_mediaDemoMode && !m_mediaActive) {
            double t = QDateTime::currentMSecsSinceEpoch() * 0.001;
            m_audioBass = 0.45 + 0.45 * std::pow(0.5 + 0.5 * std::sin(t * 5.2), 2.0);
            m_audioMid = 0.35 + 0.45 * (0.5 + 0.5 * std::sin(t * 7.8 + 1.1));
            m_audioTreble = 0.25 + 0.45 * (0.5 + 0.5 * std::cos(t * 11.4 + 2.3));
            emit audioSpectrumChanged();
        }
        QString cp = queryHyprCtlSocket("cursorpos").trimmed();
        int comma = cp.indexOf(',');
        if (comma > 0) {
            double cx = cp.left(comma).trimmed().toDouble();
            double cy = cp.mid(comma + 1).trimmed().toDouble();
            QPointF nextP(cx, cy);
            if (std::abs(nextP.x() - m_globalCursorPos.x()) > 1.0 || std::abs(nextP.y() - m_globalCursorPos.y()) > 1.0) {
                m_globalCursorPos = nextP;
                emit cursorPosChanged();
            }
        }
    });
    m_cursorPollTimer->start();

    m_weatherTimer = new QTimer(this);
    m_weatherTimer->setInterval(600000);
    connect(m_weatherTimer, &QTimer::timeout, this, &WaybarManager::pollWeather);
    m_weatherTimer->start();
}

WaybarManager::~WaybarManager() {
    if (m_hyprNotifier) {
        m_hyprNotifier->setEnabled(false);
        delete m_hyprNotifier;
    }
    if (m_hyprEventFd >= 0) ::close(m_hyprEventFd);
}

void WaybarManager::initSpecs() {
    auto add = [this](const QString &key, const QString &label, qreal min, qreal max, qreal step, qreal def, int dec) {
        QVariantMap m;
        m["key"] = key; m["label"] = label; m["min"] = min; m["max"] = max;
        m["step"] = step; m["def_val"] = def; m["value"] = def; m["dec"] = dec;
        m_defaults.append(m);
    };
    add("bar_width", "Ширина панели (px)", 500.0, 1920.0, 10.0, 1904.0, 0);
    add("bar_height", "Высота панели (px)", 18.0, 60.0, 1.0, 34.0, 0);
    add("bar_anim_duration", "Анимация ширины панели (мс)", 0.0, 350.0, 10.0, 75.0, 0);
    add("margin_top", "Отступ сверху (px)", 0.0, 30.0, 1.0, 4.0, 0);
    add("margin_bottom", "Отступ снизу (px)", 0.0, 30.0, 1.0, 4.0, 0);
    add("margin_left", "Отступ слева (px)", 0.0, 60.0, 1.0, 10.0, 0);
    add("margin_right", "Отступ справа (px)", 0.0, 60.0, 1.0, 10.0, 0);
    add("spacing", "Расстояние между модулями (px)", 1.0, 24.0, 1.0, 4.0, 0);
    add("group_spacing", "Отступ между блоками панели (px)", 0.0, 40.0, 1.0, 6.0, 0);
    add("bar_opacity", "Прозрачность фона панели", 0.1, 1.0, 0.05, 0.88, 2);
    add("pill_opacity", "Прозрачность пилюль модулей", 0.05, 1.0, 0.05, 0.65, 2);
}

qreal WaybarManager::specVal(const QString &key, qreal fallback) const {
    for (const auto &it : m_specs) {
        QVariantMap m = it.toMap();
        if (m["key"].toString() == key) return m["value"].toDouble();
    }
    return fallback;
}

int WaybarManager::barWidth() const { return qRound(specVal("bar_width", 1904.0)); }
int WaybarManager::barHeight() const { return qRound(specVal("bar_height", 34.0)); }
int WaybarManager::barAnimDuration() const { return qRound(specVal("bar_anim_duration", 75.0)); }
int WaybarManager::marginTop() const { return qRound(specVal("margin_top", 4.0)); }
int WaybarManager::marginBottom() const { return qRound(specVal("margin_bottom", 4.0)); }
int WaybarManager::marginLeft() const { return qRound(specVal("margin_left", 10.0)); }
int WaybarManager::marginRight() const { return qRound(specVal("margin_right", 10.0)); }
int WaybarManager::spacing() const { return qRound(specVal("spacing", 4.0)); }
int WaybarManager::groupSpacing() const { return qRound(specVal("group_spacing", 6.0)); }
qreal WaybarManager::barOpacity() const { return specVal("bar_opacity", 0.88); }
qreal WaybarManager::pillOpacity() const { return specVal("pill_opacity", 0.65); }

void WaybarManager::loadState() {
    QString confPath = QDir::homePath() + "/.config/hypr/scripts/waybar.conf";
    QFile file(confPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.isEmpty() || line.startsWith('#')) continue;
            int eq = line.indexOf('='); if (eq == -1) continue;
            QString k = line.left(eq).trimmed(), v = line.mid(eq + 1).trimmed();
            if (k == "pos_bottom") m_posBottom = (v == "1" || v == "true");
            else if (k == "bar_position") m_barPosition = std::clamp(v.toInt(), 0, 3);
            else if (k == "hidden_bar_modules") m_hiddenBarModules = v;
            else if (k == "centered_bar") m_centeredBar = (v == "1" || v == "true");
            else if (k == "workspace_dots") m_workspaceDots = (v == "1" || v == "true");
            else if (k == "workspace_dot_size") m_workspaceDotSize = std::clamp(v.toInt(), 3, 12);
            else if (k == "fixed_title_width") m_fixedTitleWidth = (v == "1" || v == "true");
            else if (k == "fixed_title_size") m_fixedTitleSize = std::clamp(v.toInt(), 60, 450);
            else if (k == "center_title_on_bar") m_centerTitleOnBar = (v == "1" || v == "true");
            else if (k == "media_demo_mode") m_mediaDemoMode = (v == "1" || v == "true");
            else if (k == "media_hide_timeout") m_mediaHideTimeout = std::clamp(v.toInt(), 0, 600);
            else if (k == "media_waves") m_mediaWaves = (v == "1" || v == "true");
            else if (k == "media_wave_speed") m_mediaWaveSpeed = std::clamp(v.toDouble(), 0.2, 4.0);
            else if (k == "media_wave_size") m_mediaWaveSize = std::clamp(v.toDouble(), 4.0, 24.0);
            else if (k == "media_wave_count") m_mediaWaveCount = std::clamp(v.toInt(), 20, 220);
            else if (k == "media_collapsed") m_mediaCollapsed = (v == "1" || v == "true");
            else if (k == "bar_separators") m_barSeparators = (v == "1" || v == "true");
            else if (k == "uniform_bar_spacing") m_uniformBarSpacing = (v == "1" || v == "true");
            else if (k == "vpn_log_height") m_vpnLogHeight = std::clamp(v.toInt(), 90, 420);
            else if (k == "vpn_log_max_lines") m_vpnLogMaxLines = std::clamp(v.toInt(), 20, 1000);
            else if (k == "vpn_log_auto_refresh") m_vpnLogAutoRefresh = (v == "1" || v == "true");
            else if (k == "vpn_log_auto_scroll") m_vpnLogAutoScroll = (v == "1" || v == "true");
            else if (k == "vpn_log_level" && !v.isEmpty()) m_vpnLogLevel = v;
            else if (k == "left_bar_order" && !v.isEmpty()) { m_leftBarOrder = v.split(',', Qt::SkipEmptyParts); m_leftBarOrder.removeAll("sep"); }
            else if (k == "right_bar_order" && !v.isEmpty()) { m_rightBarOrder = v.split(',', Qt::SkipEmptyParts); m_rightBarOrder.removeAll("sep"); }
            else {
                for (int i = 0; i < m_specs.size(); ++i) {
                    QVariantMap m = m_specs[i].toMap();
                    if (m["key"].toString() == k) {
                        double val = v.toDouble();
                        if (k == "bar_height" && val > 60.0) val = 34.0;
                        m["value"] = val; m_specs[i] = m; break;
                    }
                }
            }
        }
        file.close();
    }
    saveState(false);
}

void WaybarManager::saveState(bool updatePosition) {
    Q_UNUSED(updatePosition);
    QString confPath = QDir::homePath() + "/.config/hypr/scripts/waybar.conf";
    QFile file(confPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << "pos_bottom=" << (m_posBottom ? "1" : "0") << "\n";
        out << "bar_position=" << m_barPosition << "\n";
        out << "hidden_bar_modules=" << m_hiddenBarModules << "\n";
        out << "centered_bar=" << (m_centeredBar ? "1" : "0") << "\n";
        out << "workspace_dots=" << (m_workspaceDots ? "1" : "0") << "\n";
        out << "workspace_dot_size=" << m_workspaceDotSize << "\n";
        out << "fixed_title_width=" << (m_fixedTitleWidth ? "1" : "0") << "\n";
        out << "fixed_title_size=" << m_fixedTitleSize << "\n";
        out << "center_title_on_bar=" << (m_centerTitleOnBar ? "1" : "0") << "\n";
        out << "media_demo_mode=" << (m_mediaDemoMode ? "1" : "0") << "\n";
        out << "media_hide_timeout=" << m_mediaHideTimeout << "\n";
        out << "media_waves=" << (m_mediaWaves ? "1" : "0") << "\n";
        out << "media_wave_speed=" << QString::number(m_mediaWaveSpeed, 'f', 2) << "\n";
        out << "media_wave_size=" << QString::number(m_mediaWaveSize, 'f', 1) << "\n";
        out << "media_wave_count=" << m_mediaWaveCount << "\n";
        out << "media_collapsed=" << (m_mediaCollapsed ? "1" : "0") << "\n";
        out << "bar_separators=" << (m_barSeparators ? "1" : "0") << "\n";
        out << "uniform_bar_spacing=" << (m_uniformBarSpacing ? "1" : "0") << "\n";
        out << "vpn_log_height=" << m_vpnLogHeight << "\n";
        out << "vpn_log_max_lines=" << m_vpnLogMaxLines << "\n";
        out << "vpn_log_auto_refresh=" << (m_vpnLogAutoRefresh ? "1" : "0") << "\n";
        out << "vpn_log_auto_scroll=" << (m_vpnLogAutoScroll ? "1" : "0") << "\n";
        out << "vpn_log_level=" << m_vpnLogLevel << "\n";
        out << "left_bar_order=" << m_leftBarOrder.join(',') << "\n";
        out << "right_bar_order=" << m_rightBarOrder.join(',') << "\n";
        for (const auto &item : m_specs) {
            QVariantMap m = item.toMap();
            out << m["key"].toString() << "=" << QString::number(m["value"].toDouble(), 'f', m["dec"].toInt()) << "\n";
        }
    }
    emit stateChanged();
}

void WaybarManager::setPosBottom(bool v) { if (m_posBottom != v) { m_posBottom = v; saveState(true); } }
void WaybarManager::setCenteredBar(bool v) { if (m_centeredBar != v) { m_centeredBar = v; saveState(false); } }
void WaybarManager::setWorkspaceDots(bool v) { if (m_workspaceDots != v) { m_workspaceDots = v; saveState(false); } }
void WaybarManager::setWorkspaceDotSize(int v) { v = std::clamp(v, 3, 12); if (m_workspaceDotSize != v) { m_workspaceDotSize = v; saveState(false); } }
void WaybarManager::setFixedTitleWidth(bool v) { if (m_fixedTitleWidth != v) { m_fixedTitleWidth = v; saveState(false); } }
void WaybarManager::setFixedTitleSize(int v) { v = std::clamp(v, 60, 450); if (m_fixedTitleSize != v) { m_fixedTitleSize = v; saveState(false); } }
void WaybarManager::setCenterTitleOnBar(bool v) { if (m_centerTitleOnBar != v) { m_centerTitleOnBar = v; saveState(false); } }
void WaybarManager::setSpecValue(int index, qreal val) {
    if (index < 0 || index >= m_specs.size()) return;
    QVariantMap m = m_specs[index].toMap(); m["value"] = val; m_specs[index] = m; saveState(false);
}
void WaybarManager::resetSpec(int index) {
    if (index < 0 || index >= m_specs.size() || index >= m_defaults.size()) return;
    m_specs[index] = m_defaults[index].toMap(); saveState(false);
}
void WaybarManager::restartWaybar() { QProcess::startDetached("killall", {"-q", "waybar"}); emit stateChanged(); }

void WaybarManager::connectHyprEventSocket() {
    QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
    QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (runtimeDir.isEmpty() || sig.isEmpty()) return;
    QString sock2 = runtimeDir + "/hypr/" + sig + "/.socket2.sock";
    if (!QFile::exists(sock2)) sock2 = "/tmp/hypr/" + sig + "/.socket2.sock";

    m_hyprEventFd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (m_hyprEventFd < 0) return;
    int flags = ::fcntl(m_hyprEventFd, F_GETFL, 0);
    ::fcntl(m_hyprEventFd, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_un addr {};
    addr.sun_family = AF_UNIX;
    QByteArray pb = sock2.toUtf8();
    std::strncpy(addr.sun_path, pb.constData(), sizeof(addr.sun_path) - 1);
    if (::connect(m_hyprEventFd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
        ::close(m_hyprEventFd); m_hyprEventFd = -1; return;
    }
    m_hyprNotifier = new QSocketNotifier(m_hyprEventFd, QSocketNotifier::Read, this);
    connect(m_hyprNotifier, &QSocketNotifier::activated, this, &WaybarManager::onHyprEventReady);
}

static void applyShellKbInteractivity(QQuickWindow *win, bool exclusive);
static qint64 s_ignoreWinEventsUntilMs = 0;

void WaybarManager::onHyprEventReady() {
    char buf[4096];
    ssize_t n = ::read(m_hyprEventFd, buf, sizeof(buf) - 1);
    if (n <= 0) return;
    buf[n] = '\0';
    QString ev = QString::fromUtf8(buf);
    if (ev.contains("activelayout>>")) {
        for (const QString &l : ev.split('\n', Qt::SkipEmptyParts)) {
            if (l.startsWith("activelayout>>")) {
                QString lang = l.section(',', 1).toLower();
                QString nextKb = (lang.contains("ru") || lang.contains("russian")) ? "RU" : "EN";
                if (m_kbLayout != nextKb) { m_kbLayout = nextKb; emit kbLayoutChanged(); }
            }
        }
    }
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (ev.contains("closewindow>>")) {
        s_ignoreWinEventsUntilMs = std::max(s_ignoreWinEventsUntilMs, nowMs + 600);
    }
    if (ev.contains("workspace>>") || ev.contains("openwindow>>")) {
        applyShellKbInteractivity(nullptr, false);
        emit closeDrawerRequested();
    } else if (ev.contains("activewindow>>") && !ev.contains("closewindow>>") && nowMs >= s_ignoreWinEventsUntilMs) {
        for (const QString &l : ev.split('\n', Qt::SkipEmptyParts)) {
            if (l.startsWith("activewindow>>")) {
                QString winfo = l.mid(14).trimmed();
                if (!winfo.isEmpty() && winfo != "," && !winfo.contains("HyprSettings", Qt::CaseInsensitive) && !winfo.contains("hypratmooverlay", Qt::CaseInsensitive)) {
                    emit closeDrawerRequested();
                }
            }
        }
    }
    if (ev.contains("workspace") || ev.contains("activewindow") || ev.contains("openwindow") || ev.contains("closewindow")) {
        pollHyprState();
    }
}

void WaybarManager::pollHyprState() {
    QJsonDocument awDoc = QJsonDocument::fromJson(queryHyprCtlSocket("j/activeworkspace").toUtf8());
    int newActiveWs = awDoc.object()["id"].toInt(1);

    QJsonDocument wsDoc = QJsonDocument::fromJson(queryHyprCtlSocket("j/workspaces").toUtf8());
    QMap<int, int> wsWindows;
    for (int i = 1; i <= 5; ++i) wsWindows[i] = 0;
    for (const auto &v : wsDoc.array()) {
        QJsonObject o = v.toObject();
        int id = o["id"].toInt();
        if (id > 0 && id != 10) wsWindows[id] = o["windows"].toInt();
    }

    QVariantList nextList;
    for (auto it = wsWindows.begin(); it != wsWindows.end(); ++it) {
        QVariantMap item;
        item["id"] = it.key(); item["windows"] = it.value(); item["active"] = (it.key() == newActiveWs);
        nextList.append(item);
    }
    if (m_activeWorkspace != newActiveWs || m_workspaces != nextList) {
        m_activeWorkspace = newActiveWs; m_workspaces = nextList; emit workspacesChanged();
    }

    QJsonDocument winDoc = QJsonDocument::fromJson(queryHyprCtlSocket("j/activewindow").toUtf8());
    QJsonObject winObj = winDoc.object();
    QString cls = winObj["class"].toString();
    QString title = winObj["title"].toString();
    if (cls.contains("HyprSettings", Qt::CaseInsensitive) || cls.contains("hypratmooverlay", Qt::CaseInsensitive) || title == "Control Center") {
        title.clear();
    }
    if (title.length() > 42) title = title.left(40) + "…";
    if (m_activeWindowTitle != title) { m_activeWindowTitle = title; emit activeWindowChanged(); }
}

void WaybarManager::pollSysStats() {
    {
        static qint64 s_lastIpCheckMtime = 0;
        QFileInfo icInfo("/tmp/hysett_vpn_ipcheck.json");
        if (icInfo.exists()) {
            qint64 mt = icInfo.lastModified().toMSecsSinceEpoch();
            if (mt != s_lastIpCheckMtime) {
                s_lastIpCheckMtime = mt;
                QFile icf("/tmp/hysett_vpn_ipcheck.json");
                if (icf.open(QIODevice::ReadOnly)) {
                    QJsonObject ico = QJsonDocument::fromJson(icf.readAll()).object();
                    icf.close();
                    int stCode = ico["state"].toInt(m_vpnIpCheckState);
                    QString stTxt = ico["text"].toString();
                    QString audSig = ico["auditing_sig"].toString();
                    if (!stTxt.isEmpty() && (stCode != m_vpnIpCheckState || stTxt != m_vpnIpCheckText || audSig != m_vpnAuditingSig)) {
                        m_vpnIpCheckState = stCode;
                        m_vpnIpCheckText = stTxt;
                        m_vpnAuditingSig = audSig;
                        emit sysStatsChanged();
                    }
                }
            }
        }
    }
    if (m_vpnBusy) {
        QFile pf("/tmp/hysett_vpn_progress.json");
        if (pf.open(QIODevice::ReadOnly)) {
            QJsonObject po = QJsonDocument::fromJson(pf.readAll()).object();
            pf.close();
            int pct = po["percent"].toInt(m_vpnProgressPercent);
            QString ptxt = po["text"].toString(m_vpnProgressText);
            if (pct != m_vpnProgressPercent || ptxt != m_vpnProgressText) {
                m_vpnProgressPercent = pct;
                m_vpnProgressText = ptxt;
                emit sysStatsChanged();
            }
        }
    }
    // 1. CPU Usage
    QFile statFile("/proc/stat");
    if (statFile.open(QIODevice::ReadOnly)) {
        QList<QByteArray> parts = statFile.readLine().simplified().split(' ');
        if (parts.size() >= 5) {
            qulonglong u = parts[1].toULongLong(), n = parts[2].toULongLong(), s = parts[3].toULongLong(), idle = parts[4].toULongLong();
            qulonglong iow = parts.value(5).toULongLong(), irq = parts.value(6).toULongLong(), sirq = parts.value(7).toULongLong();
            qulonglong total = u + n + s + idle + iow + irq + sirq;
            qulonglong diffT = total - m_prevCpuTotal, diffI = idle - m_prevCpuIdle;
            if (m_prevCpuTotal > 0 && diffT > 0) m_cpuUsage = std::clamp(int(100ULL * (diffT - diffI) / diffT), 0, 100);
            m_prevCpuTotal = total; m_prevCpuIdle = idle;
        }
        statFile.close();
    }

    // 2. CPU Temp (с кэшированием найденного пути файла датчика — 0 накладных расходов!)
    if (!m_cachedHwmonPath.isEmpty()) {
        QFile tf(m_cachedHwmonPath);
        if (tf.open(QIODevice::ReadOnly)) {
            int deg = tf.readAll().trimmed().toInt() / 1000;
            tf.close();
            if (deg >= 20 && deg <= 115) m_cpuTemp = deg;
        }
    } else {
        int bestCpuTemp = -1;
        QString bestPath;
        QDir hwDir("/sys/class/hwmon");
        for (const QString &hw : hwDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QString base = "/sys/class/hwmon/" + hw;
            QString chipName;
            QFile nf(base + "/name");
            if (nf.open(QIODevice::ReadOnly)) {
                chipName = QString::fromUtf8(nf.readAll()).trimmed().toLower();
                nf.close();
            }
            bool isPrimaryCpu = chipName.contains("coretemp") || chipName.contains("k10temp") ||
                                chipName.contains("zenpower") || chipName.contains("zenergy") || chipName.contains("cpu");
            for (int idx = 1; idx <= 6; ++idx) {
                QString p = QString("%1/temp%2_input").arg(base).arg(idx);
                QFile tf(p);
                if (tf.open(QIODevice::ReadOnly)) {
                    int deg = tf.readAll().trimmed().toInt() / 1000;
                    tf.close();
                    if (deg >= 20 && deg <= 115 && (isPrimaryCpu || (bestCpuTemp < 0 && deg != 27))) {
                        if (isPrimaryCpu || deg > bestCpuTemp) {
                            bestCpuTemp = deg;
                            bestPath = p;
                        }
                    }
                }
            }
        }
        if (bestCpuTemp > 0) {
            m_cpuTemp = bestCpuTemp;
            m_cachedHwmonPath = bestPath;
        }
    }

    // 3. RAM
    QFile memFile("/proc/meminfo");
    if (memFile.open(QIODevice::ReadOnly)) {
        qulonglong memTotal = 0, memAvail = 0;
        for (const QByteArray &l : memFile.readAll().split('\n')) {
            if (l.startsWith("MemTotal:")) memTotal = l.simplified().split(' ').value(1).toULongLong();
            else if (l.startsWith("MemAvailable:")) { memAvail = l.simplified().split(' ').value(1).toULongLong(); break; }
        }
        memFile.close();
        if (memTotal > 0) {
            double usedGb = double(memTotal - memAvail) / (1024.0 * 1024.0);
            double totGb  = double(memTotal) / (1024.0 * 1024.0);
            m_memPercent = std::clamp(int(100ULL * (memTotal - memAvail) / memTotal), 0, 100);
            m_memUsageText = QString::number(usedGb, 'f', 1) + "G";
            m_memDetailText = QString("%1 GB / %2 GB (%3%)").arg(QString::number(usedGb, 'f', 1), QString::number(totGb, 'f', 1)).arg(m_memPercent);
        }
    }

    // 3b. Видеопамять (VRAM) из /sys/class/drm/card*/device/mem_info_vram_*
    qulonglong vUsed = 0, vTot = 0;
    for (int card = 0; card <= 2; ++card) {
        QFile fu(QString("/sys/class/drm/card%1/device/mem_info_vram_used").arg(card));
        QFile ft(QString("/sys/class/drm/card%1/device/mem_info_vram_total").arg(card));
        if (fu.open(QIODevice::ReadOnly) && ft.open(QIODevice::ReadOnly)) {
            vUsed = fu.readAll().trimmed().toULongLong();
            vTot  = ft.readAll().trimmed().toULongLong();
            fu.close(); ft.close();
            if (vTot > 0) break;
        }
    }
    if (vTot > 0) {
        double uGb = double(vUsed) / (1024.0 * 1024.0 * 1024.0);
        double tGb = double(vTot) / (1024.0 * 1024.0 * 1024.0);
        m_vramPercent = std::clamp(int(100ULL * vUsed / vTot), 0, 100);
        m_vramDetailText = QString("%1 GB / %2 GB (%3%)").arg(QString::number(uGb, 'f', 1), QString::number(tGb, 'f', 1)).arg(m_vramPercent);
    } else {
        // Fallback оценка VRAM, если драйвер NVIDIA закрытый
        static int s_nvTick = 0;
        if (m_drawerOpenState && (s_nvTick++ % 6 == 0)) {
            QProcess *nv = new QProcess(this);
            connect(nv, &QProcess::finished, this, [this, nv]() {
                QString out = QString::fromUtf8(nv->readAllStandardOutput()).trimmed();
                nv->deleteLater();
                QStringList p = out.split(',');
                if (p.size() >= 2) {
                    double uMb = p[0].trimmed().toDouble(), tMb = p[1].trimmed().toDouble();
                    if (tMb > 0) {
                        m_vramPercent = std::clamp(int(100.0 * uMb / tMb), 0, 100);
                        m_vramDetailText = QString("%1 GB / %2 GB (%3%)").arg(QString::number(uMb/1024.0, 'f', 1), QString::number(tMb/1024.0, 'f', 1)).arg(m_vramPercent);
                    }
                }
            });
            nv->start("nvidia-smi", {"--query-gpu=memory.used,memory.total", "--format=csv,noheader,nounits"});
        }
    }

    // 3c. Скорость сети (RX / TX) напрямую из /proc/net/dev
    QFile netDev("/proc/net/dev");
    if (netDev.open(QIODevice::ReadOnly)) {
        qulonglong rxSum = 0, txSum = 0;
        const QList<QByteArray> nLines = netDev.readAll().split('\n');
        for (int i = 2; i < nLines.size(); ++i) {
            QByteArray nl = nLines[i].trimmed();
            if (nl.isEmpty() || nl.startsWith("lo:")) continue;
            int col = nl.indexOf(':');
            if (col == -1) continue;
            QList<QByteArray> vals = nl.mid(col + 1).simplified().split(' ');
            if (vals.size() >= 9) {
                rxSum += vals[0].toULongLong();
                txSum += vals[8].toULongLong();
            }
        }
        netDev.close();
        qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
        if (m_prevNetMs > 0 && nowMs > m_prevNetMs && rxSum >= m_prevNetRx && txSum >= m_prevNetTx) {
            double dtSec = double(nowMs - m_prevNetMs) / 1000.0;
            double rxKbs = double(rxSum - m_prevNetRx) / 1024.0 / dtSec;
            double txKbs = double(txSum - m_prevNetTx) / 1024.0 / dtSec;
            auto fmtSpd = [](double kbs) {
                if (kbs >= 1024.0) return QString::number(kbs / 1024.0, 'f', 1) + " MB/s";
                return QString::number(qRound(kbs)) + " KB/s";
            };
            m_netSpeedText = QString("↓ %1   ↑ %2").arg(fmtSpd(rxKbs), fmtSpd(txKbs));
            m_netPercent = std::clamp(int((rxKbs + txKbs) / 120.0), 0, 100);
        }
        m_prevNetRx = rxSum; m_prevNetTx = txSum; m_prevNetMs = nowMs;
    }

    // Обновляем 60-точечную историю для плавных графиков
    m_cpuHistory.append(m_cpuUsage); if (m_cpuHistory.size() > 60) m_cpuHistory.removeFirst();
    m_tempHistory.append(m_cpuTemp); if (m_tempHistory.size() > 60) m_tempHistory.removeFirst();
    m_memHistory.append(m_memPercent); if (m_memHistory.size() > 60) m_memHistory.removeFirst();
    m_vramHistory.append(m_vramPercent); if (m_vramHistory.size() > 60) m_vramHistory.removeFirst();
    m_netHistory.append(m_netPercent); if (m_netHistory.size() > 60) m_netHistory.removeFirst();

    // 4. Живые иконки трея через DBus SNI с кэшем по PID
    m_trayTick = (m_trayTick + 1) % 1000;
    if (m_trayTick % 8 != 0) { emit sysStatsChanged(); return; }
    static QMap<uint, QString> s_pidToSniCache;
    static int s_scanCounter = 0;

    QDir procDir("/proc");
    QMap<QString, uint> commToPid;
    for (const QString &pidStr : procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!pidStr[0].isDigit()) continue;
        QFile cf("/proc/" + pidStr + "/comm");
        if (cf.open(QIODevice::ReadOnly)) {
            QString cName = QString::fromUtf8(cf.readAll()).trimmed();
            uint pid = pidStr.toUInt();
            if (!commToPid.contains(cName) || s_pidToSniCache.contains(pid)) {
                commToPid[cName] = pid;
            }
            cf.close();
        }
    }

    QVariantList nextTray;
    auto addTrayApp = [&](const QString &procName, const QString &cls, const QString &fallbackIcon) {
        if (!commToPid.contains(procName)) return;
        uint pid = commToPid[procName];
        if (!s_pidToSniCache.contains(pid) && (s_scanCounter++ % 5 == 0)) {
            if (auto *ifc = QDBusConnection::sessionBus().interface()) {
                for (const QString &srv : ifc->registeredServiceNames().value()) {
                    if (!srv.startsWith(':')) continue;
                    if (ifc->servicePid(srv).value() == pid) {
                        QDBusMessage m = QDBusMessage::createMethodCall(srv, "/StatusNotifierItem", "org.freedesktop.DBus.Properties", "Get");
                        m << "org.kde.StatusNotifierItem" << "Status";
                        if (QDBusConnection::sessionBus().call(m, QDBus::Block, 20).type() == QDBusMessage::ReplyMessage) {
                            s_pidToSniCache[pid] = srv;
                            break;
                        }
                    }
                }
            }
        }
        QString sniSrv = s_pidToSniCache.value(pid);
        QVariantMap tm;
        tm["name"] = procName;
        tm["class"] = cls;
        tm["sniService"] = sniSrv;
        if (!sniSrv.isEmpty()) {
            tm["icon"] = QString("sni:%1|/StatusNotifierItem|%2").arg(sniSrv, fallbackIcon);
        } else {
            tm["icon"] = fallbackIcon;
        }
        nextTray.append(tm);
    };
    addTrayApp("Throne", "Throne", QFile::exists("/home/whrr/.local/share/Throne/throne.png") ? "/home/whrr/.local/share/Throne/throne.png" : "Throne");
    addTrayApp("AyuGram", "com.ayugram.desktop", QFile::exists("/usr/share/icons/hicolor/64x64/apps/com.ayugram.desktop.png") ? "/usr/share/icons/hicolor/64x64/apps/com.ayugram.desktop.png" : "com.ayugram.desktop");
    addTrayApp("Telegram", "org.telegram.desktop", "org.telegram.desktop");
    addTrayApp("Discord", "discord", "discord");
    addTrayApp("steam", "steam", "steam");

    if (m_trayApps != nextTray) {
        m_trayApps = nextTray;
        emit activeWindowChanged();
    }
    emit sysStatsChanged();
}

void WaybarManager::setProcessSortMode(int mode) {
    mode = std::clamp(mode, 0, 1);
    if (m_processSortMode != mode) {
        m_processSortMode = mode;
        if (!m_processList.isEmpty()) {
            std::sort(m_processList.begin(), m_processList.end(), [mode](const QVariant &va, const QVariant &vb) {
                QVariantMap a = va.toMap(), b = vb.toMap();
                if (mode == 1) {
                    double ma = a["mem"].toString().remove(" MB").toDouble();
                    double mb = b["mem"].toString().remove(" MB").toDouble();
                    if (std::abs(ma - mb) > 0.5) return ma > mb;
                    double ca = a["cpu"].toString().remove("%").toDouble();
                    double cb = b["cpu"].toString().remove("%").toDouble();
                    return ca > cb;
                } else {
                    double ca = a["cpu"].toString().remove("%").toDouble();
                    double cb = b["cpu"].toString().remove("%").toDouble();
                    if (std::abs(ca - cb) > 0.05) return ca > cb;
                    double ma = a["mem"].toString().remove(" MB").toDouble();
                    double mb = b["mem"].toString().remove(" MB").toDouble();
                    return ma > mb;
                }
            });
            emit processesChanged();
        } else {
            refreshProcesses();
        }
    }
}

void WaybarManager::refreshProcesses() {
    qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    qint64 elapsedMs = (m_lastProcessPollMs > 0) ? (nowMs - m_lastProcessPollMs) : 0;
    bool isFirstOrStale = (m_lastProcessPollMs == 0 || elapsedMs > 3500);
    m_lastProcessPollMs = nowMs;

    // 1. Читаем общее системное время CPU из /proc/stat
    qulonglong totalCpu = 0;
    QFile statFile("/proc/stat");
    if (statFile.open(QIODevice::ReadOnly)) {
        QByteArray line = statFile.readLine();
        statFile.close();
        const QList<QByteArray> parts = line.simplified().split(' ');
        for (int i = 1; i < parts.size(); ++i) {
            totalCpu += parts[i].toULongLong();
        }
    }

    qulonglong diffTotal = (!isFirstOrStale && m_prevProcSysTotal > 0 && totalCpu > m_prevProcSysTotal)
                           ? (totalCpu - m_prevProcSysTotal) : 0;
    m_prevProcSysTotal = totalCpu;

    // 2. Сканируем /proc/[pid] напрямую в C++ (быстрее и точнее ps в десятки раз)
    long pageSize = sysconf(_SC_PAGESIZE);
    if (pageSize <= 0) pageSize = 4096;
    double pageToMb = double(pageSize) / (1024.0 * 1024.0);

    QDir procDir("/proc");
    const QStringList pids = procDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    struct ProcEntry {
        int pid;
        double cpu;
        double rssMb;
        QString name;
    };
    QList<ProcEntry> procs;
    procs.reserve(pids.size());
    QHash<int, qulonglong> nextTicks;
    nextTicks.reserve(pids.size());

    for (const QString &pidStr : pids) {
        bool ok = false;
        int pid = pidStr.toInt(&ok);
        if (!ok || pid <= 0) continue;

        QFile statF(QString("/proc/%1/stat").arg(pid));
        if (!statF.open(QIODevice::ReadOnly)) continue;
        QByteArray data = statF.readAll();
        statF.close();

        int oParen = data.indexOf('(');
        int cParen = data.lastIndexOf(')');
        if (oParen == -1 || cParen == -1 || cParen <= oParen) continue;

        QString comm = QString::fromUtf8(data.mid(oParen + 1, cParen - oParen - 1));
        QByteArray rest = data.mid(cParen + 2);
        const QList<QByteArray> fields = rest.split(' ');
        if (fields.size() < 13) continue;

        qulonglong utime = fields[11].toULongLong();
        qulonglong stime = fields[12].toULongLong();
        qulonglong ticks = utime + stime;
        nextTicks[pid] = ticks;

        double cpu = 0.0;
        if (diffTotal > 0 && m_prevProcTicks.contains(pid)) {
            qulonglong prev = m_prevProcTicks.value(pid);
            if (ticks >= prev) {
                // Solaris-mode: нормализация к 100% мощности всего CPU (соответствует верхнему графику)
                cpu = 100.0 * double(ticks - prev) / double(diffTotal);
            }
        }

        // Читаем фактическую оперативную память RSS из /proc/[pid]/statm
        double rssMb = 0.0;
        QFile statmF(QString("/proc/%1/statm").arg(pid));
        if (statmF.open(QIODevice::ReadOnly)) {
            QByteArray mline = statmF.readLine();
            statmF.close();
            const QList<QByteArray> mparts = mline.simplified().split(' ');
            if (mparts.size() >= 2) {
                rssMb = mparts[1].toDouble() * pageToMb;
            }
        }

        procs.append({pid, std::clamp(cpu, 0.0, 100.0), rssMb, comm});
    }

    m_prevProcTicks = std::move(nextTicks);

    // Если вкладку только что открыли — быстрый замер через 300мс для мгновенных данных
    if (isFirstOrStale) {
        QTimer::singleShot(300, this, &WaybarManager::refreshProcesses);
    }

    // 3. Сортировка
    if (m_processSortMode == 1) {
        std::sort(procs.begin(), procs.end(), [](const ProcEntry &a, const ProcEntry &b) {
            if (std::abs(a.rssMb - b.rssMb) > 0.5) return a.rssMb > b.rssMb;
            return a.cpu > b.cpu;
        });
    } else {
        std::sort(procs.begin(), procs.end(), [](const ProcEntry &a, const ProcEntry &b) {
            if (std::abs(a.cpu - b.cpu) > 0.05) return a.cpu > b.cpu;
            return a.rssMb > b.rssMb;
        });
    }

    // 4. Формирование списка
    QVariantList list;
    for (int i = 0; i < procs.size() && list.size() < 28; ++i) {
        QVariantMap m;
        m["pid"] = procs[i].pid;
        m["cpu"] = QString::number(procs[i].cpu, 'f', 1) + "%";
        m["mem"] = QString::number(procs[i].rssMb, 'f', 0) + " MB";
        m["name"] = procs[i].name;
        list.append(m);
    }
    m_processList = list;
    emit processesChanged();
}

void WaybarManager::killProcess(int pid) {
    if (pid > 1) {
        s_ignoreWinEventsUntilMs = QDateTime::currentMSecsSinceEpoch() + 1200;
        ::kill(pid, SIGTERM);
        QTimer::singleShot(250, this, &WaybarManager::refreshProcesses);
    }
}

bool WaybarManager::mediaActive() const {
    bool hasAny = m_mediaDemoMode || m_mediaActive;
    if (!hasAny) return false;
    if (!mediaPlaying() && m_mediaHideTimeout > 0 && m_mediaPausedSec >= m_mediaHideTimeout) {
        return false;
    }
    return true;
}

QString WaybarManager::mediaPositionText() const {
    int sec = (m_mediaDemoMode && !m_mediaActive) ? m_demoPosSec : m_realPosSec;
    sec = std::max(0, sec);
    return QString("%1:%2").arg(sec / 60, 2, 10, QChar('0')).arg(sec % 60, 2, 10, QChar('0'));
}

QString WaybarManager::mediaDurationText() const {
    int sec = mediaLengthSec();
    return QString("%1:%2").arg(sec / 60, 2, 10, QChar('0')).arg(sec % 60, 2, 10, QChar('0'));
}

void WaybarManager::setMediaDemoMode(bool v) {
    if (m_mediaDemoMode != v) {
        m_mediaDemoMode = v;
        if (v) {
            m_demoPlaying = true;
            m_mediaPausedSec = 0;
        }
        saveState(false);
        emit mediaChanged();
    }
}

void WaybarManager::setMediaHideTimeout(int sec) {
    sec = std::clamp(sec, 0, 600);
    if (m_mediaHideTimeout != sec) {
        m_mediaHideTimeout = sec;
        saveState(false);
        emit mediaChanged();
    }
}

void WaybarManager::seekToSecond(int sec) {
    int cur = mediaPosSec();
    mediaSeek(sec - cur);
}

void WaybarManager::setBarSeparators(bool v) {
    if (m_barSeparators != v) {
        m_barSeparators = v;
        saveState(false);
    }
}

void WaybarManager::setUniformBarSpacing(bool v) {
    if (m_uniformBarSpacing != v) {
        m_uniformBarSpacing = v;
        saveState(false);
    }
}

void WaybarManager::setBarEditMode(bool v) {
    if (m_barEditMode != v) {
        if (v) {
            m_backupLeftOrder = m_leftBarOrder;
            m_backupRightOrder = m_rightBarOrder;
            m_backupHiddenModules = m_hiddenBarModules;
        }
        m_barEditMode = v;
        emit stateChanged();
    }
}

void WaybarManager::confirmBarEdit() {
    m_barEditMode = false;
    saveState(false);
}

void WaybarManager::cancelBarEdit() {
    if (!m_backupLeftOrder.isEmpty()) m_leftBarOrder = m_backupLeftOrder;
    if (!m_backupRightOrder.isEmpty()) m_rightBarOrder = m_backupRightOrder;
    m_hiddenBarModules = m_backupHiddenModules;
    m_barEditMode = false;
    saveState(false);
}

void WaybarManager::moveBarModule(const QString &side, int fromIdx, int toIdx) {
    QStringList &list = (side == "left") ? m_leftBarOrder : m_rightBarOrder;
    if (fromIdx < 0 || fromIdx >= list.size() || fromIdx == toIdx) return;
    if (list[fromIdx] == "window") {
        if (side == "left" && toIdx >= list.size()) {
            list.removeAt(fromIdx);
            saveState(false);
            return;
        }
        if (side == "right" && toIdx < 0) {
            list.removeAt(fromIdx);
            saveState(false);
            return;
        }
    }
    if (toIdx < 0 || toIdx >= list.size()) return;
    list.move(fromIdx, toIdx);
    saveState(false);
}



QString WaybarManager::transferBarModule(const QString &key, const QString &fromSide, int dir) {
    if (key != "window") return fromSide;
    if (fromSide == "center") {
        moveWindowModuleToSide(dir < 0 ? "left" : "right");
        return dir < 0 ? "left" : "right";
    } else if (fromSide == "left" && dir > 0) {
        moveWindowModuleToSide("center");
        return "center";
    } else if (fromSide == "right" && dir < 0) {
        moveWindowModuleToSide("center");
        return "center";
    }
    return fromSide;
}

QString WaybarManager::swapWithCenterWindow(const QString &side, int idx) {
    if (side == "left") {
        if (idx < 0 || idx >= m_leftBarOrder.size()) return "";
        QString key = m_leftBarOrder[idx];
        int winL = m_leftBarOrder.indexOf("window");
        int winR = m_rightBarOrder.indexOf("window");
        if (winL == -1 && winR == -1) {
            // Заголовок был по центру — ставим его на место блока, а блок уходит правее
            m_leftBarOrder.insert(idx, "window");
            saveState(false);
            return "left";
        }
    } else if (side == "right") {
        if (idx < 0 || idx >= m_rightBarOrder.size()) return "";
        int winL = m_leftBarOrder.indexOf("window");
        int winR = m_rightBarOrder.indexOf("window");
        if (winL == -1 && winR == -1) {
            m_rightBarOrder.insert(idx + 1, "window");
            saveState(false);
            return "right";
        }
    }
    return side;
}

void WaybarManager::moveWindowModuleToSide(const QString &targetSide) {
    m_leftBarOrder.removeAll("window");
    m_rightBarOrder.removeAll("window");
    if (targetSide == "left") {
        m_leftBarOrder.append("window");
    } else if (targetSide == "right") {
        m_rightBarOrder.prepend("window");
    }
    saveState(false);
}

void WaybarManager::addBarSeparator(const QString &side) {
    QStringList &list = (side == "left") ? m_leftBarOrder : m_rightBarOrder;
    int pos = std::max(1, int(list.size()) / 2);
    list.insert(pos, "sep");
    saveState(false);
}

void WaybarManager::removeBarItemAt(const QString &side, int idx) {
    QStringList &list = (side == "left") ? m_leftBarOrder : m_rightBarOrder;
    if (idx < 0 || idx >= list.size()) return;
    QString key = list[idx];
    if (key == "sep") {
        list.removeAt(idx);
        saveState(false);
    } else {
        setBarModuleVisible(key, false);
    }
}

void WaybarManager::resetBarOrder() {
    m_leftBarOrder = {"launcher", "workspaces", "weather", "media"};
    m_rightBarOrder = {"sysinfo", "tray", "bluetooth", "network", "clipboard", "volume", "language", "clock", "power"};
    m_hiddenBarModules.clear();
    saveState(false);
}

void WaybarManager::updateAudioCaptureState() {
    bool wantCap = m_mediaWaves && m_mediaActive && m_mediaPlaying;
    if (!wantCap) {
        if (m_audioCapProc) {
            m_audioCapProc->kill();
            m_audioCapProc->deleteLater();
            m_audioCapProc = nullptr;
        }
        if (!m_mediaDemoMode && (m_audioBass > 0.01 || m_audioMid > 0.01 || m_audioTreble > 0.01)) {
            m_audioBass = 0.0; m_audioMid = 0.0; m_audioTreble = 0.0;
            emit audioSpectrumChanged();
        }
        return;
    }
    if (m_audioCapProc && m_audioCapProc->state() != QProcess::NotRunning) return;
    if (m_audioCapProc) {
        m_audioCapProc->deleteLater();
        m_audioCapProc = nullptr;
    }

    m_audioCapProc = new QProcess(this);
    connect(m_audioCapProc, &QProcess::readyReadStandardOutput, this, [this]() {
        if (!m_audioCapProc) return;
        QByteArray buf = m_audioCapProc->readAllStandardOutput();
        int nSamples = buf.size() / 2;
        if (nSamples < 16) return;
        const int16_t *pcm = reinterpret_cast<const int16_t *>(buf.constData());

        static double s_lp1 = 0.0;
        static double s_lp2 = 0.0;
        double sumBass = 0.0, sumMid = 0.0, sumTreb = 0.0;
        int step = std::max(1, nSamples / 256);
        int count = 0;
        for (int i = 0; i < nSamples; i += step) {
            double x = double(pcm[i]) / 32768.0;
            // Разделение на НЧ (бас), СЧ и ВЧ фильтрами 1-го порядка
            s_lp1 += 0.08 * (x - s_lp1);
            s_lp2 += 0.32 * (x - s_lp2);
            double b = s_lp1;
            double m = s_lp2 - s_lp1;
            double tr = x - s_lp2;
            sumBass += b * b;
            sumMid  += m * m;
            sumTreb += tr * tr;
            ++count;
        }
        if (count > 0) {
            double rmsB = std::sqrt(sumBass / count) * 4.8;
            double rmsM = std::sqrt(sumMid  / count) * 5.6;
            double rmsT = std::sqrt(sumTreb / count) * 6.5;
            double targetB = std::clamp( std::pow(rmsB, 0.72), 0.0, 1.55);
            double targetM = std::clamp( std::pow(rmsM, 0.75), 0.0, 1.50);
            double targetT = std::clamp( std::pow(rmsT, 0.78), 0.0, 1.45);
            // Быстрая атака на удар баса (0.55) и плавное затухание (0.22)
            m_audioBass   = (targetB > m_audioBass)   ? (m_audioBass * 0.45 + targetB * 0.55)   : (m_audioBass * 0.78 + targetB * 0.22);
            m_audioMid    = (targetM > m_audioMid)    ? (m_audioMid * 0.45 + targetM * 0.55)    : (m_audioMid * 0.78 + targetM * 0.22);
            m_audioTreble = (targetT > m_audioTreble) ? (m_audioTreble * 0.45 + targetT * 0.55) : (m_audioTreble * 0.78 + targetT * 0.22);
            emit audioSpectrumChanged();
        }
    });
    m_audioCapProc->start("parec", {"--format=s16le", "--rate=16000", "--channels=1", "--latency-msec=22", "-d", "@DEFAULT_MONITOR@"});
}

void WaybarManager::setMediaWaveSize(qreal v) {
    v = std::clamp(v, 4.0, 24.0);
    if (!qFuzzyCompare(m_mediaWaveSize, v)) {
        m_mediaWaveSize = v;
        saveState(false);
    }
}

void WaybarManager::setMediaWaveCount(int v) {
    v = std::clamp(v, 20, 220);
    if (m_mediaWaveCount != v) {
        m_mediaWaveCount = v;
        saveState(false);
    }
}

void WaybarManager::setMediaWaveSpeed(qreal v) {
    v = std::clamp(v, 0.2, 4.0);
    if (!qFuzzyCompare(m_mediaWaveSpeed, v)) {
        m_mediaWaveSpeed = v;
        saveState(false);
    }
}

void WaybarManager::setMediaWaves(bool v) {
    if (m_mediaWaves != v) {
        m_mediaWaves = v;
        saveState(false);
    }
}

void WaybarManager::setMediaCollapsed(bool v) {
    if (m_mediaCollapsed != v) {
        m_mediaCollapsed = v;
        saveState(false);
    }
}

void WaybarManager::toggleMediaCollapsed() {
    setMediaCollapsed(!m_mediaCollapsed);
}

void WaybarManager::toggleMediaDemo() {
    setMediaDemoMode(!m_mediaDemoMode);
}

void WaybarManager::mediaPlayPause() {
    if (m_mediaDemoMode && !m_mediaActive) {
        m_demoPlaying = !m_demoPlaying;
        if (m_demoPlaying) m_mediaPausedSec = 0;
        emit mediaChanged();
        return;
    }
    if (!m_activeMprisService.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_activeMprisService, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "PlayPause");
        QDBusConnection::sessionBus().asyncCall(msg);
    } else {
        QProcess::startDetached("playerctl", {"play-pause"});
    }
    QTimer::singleShot(80, this, &WaybarManager::pollMediaState);
}

void WaybarManager::mediaPrev() {
    if (m_mediaDemoMode && !m_mediaActive) {
        m_demoTrackIdx = (m_demoTrackIdx + m_demoTracks.size() - 1) % m_demoTracks.size();
        m_demoPosSec = 0;
        m_demoPlaying = true;
        m_mediaPausedSec = 0;
        emit mediaChanged();
        return;
    }
    if (!m_activeMprisService.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_activeMprisService, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Previous");
        QDBusConnection::sessionBus().asyncCall(msg);
    } else {
        QProcess::startDetached("playerctl", {"previous"});
    }
    QTimer::singleShot(120, this, &WaybarManager::pollMediaState);
}

void WaybarManager::mediaNext() {
    if (m_mediaDemoMode && !m_mediaActive) {
        m_demoTrackIdx = (m_demoTrackIdx + 1) % m_demoTracks.size();
        m_demoPosSec = 0;
        m_demoPlaying = true;
        m_mediaPausedSec = 0;
        emit mediaChanged();
        return;
    }
    if (!m_activeMprisService.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_activeMprisService, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Next");
        QDBusConnection::sessionBus().asyncCall(msg);
    } else {
        QProcess::startDetached("playerctl", {"next"});
    }
    QTimer::singleShot(120, this, &WaybarManager::pollMediaState);
}

void WaybarManager::mediaSeek(int deltaSec) {
    if (m_mediaDemoMode && !m_mediaActive) {
        m_demoPosSec = std::clamp(m_demoPosSec + deltaSec, 0, 215);
        emit mediaChanged();
        return;
    }
    if (!m_activeMprisService.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall(m_activeMprisService, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Seek");
        msg << qlonglong(deltaSec) * 1000000LL;
        QDBusConnection::sessionBus().asyncCall(msg);
    } else {
        QString arg = deltaSec >= 0 ? QString("%1+").arg(deltaSec) : QString("%1-").arg(std::abs(deltaSec));
        QProcess::startDetached("playerctl", {"position", arg});
    }
}

void WaybarManager::pollMediaState() {
    QString foundService;
    bool isPlaying = false;
    QString trackText;

    if (auto *ifc = QDBusConnection::sessionBus().interface()) {
        const QStringList services = ifc->registeredServiceNames().value();
        for (const QString &srv : services) {
            if (!srv.startsWith("org.mpris.MediaPlayer2.")) continue;
            QDBusMessage stMsg = QDBusMessage::createMethodCall(srv, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get");
            stMsg << "org.mpris.MediaPlayer2.Player" << "PlaybackStatus";
            QDBusMessage stRep = QDBusConnection::sessionBus().call(stMsg, QDBus::Block, 25);
            if (stRep.type() != QDBusMessage::ReplyMessage || stRep.arguments().isEmpty()) continue;
            QString status = stRep.arguments().first().value<QDBusVariant>().variant().toString();
            if (status == "Stopped") continue;

            QDBusMessage mdMsg = QDBusMessage::createMethodCall(srv, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get");
            mdMsg << "org.mpris.MediaPlayer2.Player" << "Metadata";
            QDBusMessage mdRep = QDBusConnection::sessionBus().call(mdMsg, QDBus::Block, 25);
            QString title, artist;
            if (mdRep.type() == QDBusMessage::ReplyMessage && !mdRep.arguments().isEmpty()) {
                QVariant v = mdRep.arguments().first().value<QDBusVariant>().variant();
                QVariantMap meta;
                if (v.canConvert<QDBusArgument>()) {
                    const QDBusArgument arg = v.value<QDBusArgument>();
                    arg >> meta;
                } else {
                    meta = v.toMap();
                }
                title = meta.value("xesam:title").toString().trimmed();
                QStringList artists = meta.value("xesam:artist").toStringList();
                if (!artists.isEmpty()) artist = artists.first().trimmed();
                else artist = meta.value("xesam:artist").toString().trimmed();
            }
            if (title.isEmpty()) continue;
            QString full = artist.isEmpty() ? title : (artist + " — " + title);
            if (status == "Playing" || foundService.isEmpty()) {
                foundService = srv;
                isPlaying = (status == "Playing");
                trackText = full;
                if (isPlaying) break;
            }
        }
    }

    bool nextActive = !foundService.isEmpty();
    if (nextActive && !foundService.isEmpty()) {
        QDBusMessage posMsg = QDBusMessage::createMethodCall(foundService, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get");
        posMsg << "org.mpris.MediaPlayer2.Player" << "Position";
        QDBusMessage posRep = QDBusConnection::sessionBus().call(posMsg, QDBus::Block, 20);
        if (posRep.type() == QDBusMessage::ReplyMessage && !posRep.arguments().isEmpty()) {
            qlonglong us = posRep.arguments().first().value<QDBusVariant>().variant().toLongLong();
            m_realPosSec = int(std::max(0LL, us / 1000000LL));
        }
    } else if (m_mediaDemoMode && m_demoPlaying) {
        m_demoPosSec = (m_demoPosSec + 1) % 215;
    }

    m_activeMprisService = foundService;
    m_mediaActive = nextActive;
    m_mediaPlaying = isPlaying;
    m_mediaTitle = trackText;

    bool effPlaying = (m_mediaDemoMode && !m_mediaActive) ? m_demoPlaying : m_mediaPlaying;
    if (effPlaying) {
        m_mediaPausedSec = 0;
    } else {
        m_mediaPausedSec = std::min(3600, m_mediaPausedSec + 1);
    }
    emit mediaChanged();
}

void WaybarManager::pollFastState() {
    {
        static int s_btPollTick = 0;
        if (s_btPollTick++ % 2 == 0) {
            QProcess *btP = new QProcess(this);
            connect(btP, &QProcess::finished, this, [this, btP]() {
                QString out = QString::fromUtf8(btP->readAllStandardOutput());
                btP->deleteLater();
                int cnt = 0;
                for (const QString &ln : out.split('\n', Qt::SkipEmptyParts)) {
                    if (ln.trimmed().contains("Device ")) ++cnt;
                }
                bool conn = (cnt > 0);
                if (m_btConnected != conn || m_btConnectedCount != cnt) {
                    m_btConnected = conn;
                    m_btConnectedCount = cnt;
                    emit sysStatsChanged();
                }
            });
            btP->start("bluetoothctl", {"devices", "Connected"});
        }
    }

    pollMediaState();
    QProcess *wp = new QProcess(this);
    connect(wp, &QProcess::finished, this, [this, wp]() {
        QString out = QString::fromUtf8(wp->readAllStandardOutput()).trimmed();
        wp->deleteLater();
        if (out.startsWith("Volume:")) {
            bool isM = out.contains("[MUTED]");
            int vol = qRound(out.section(' ', 1, 1).toDouble() * 100.0);
            if (m_volume != vol || m_muted != isM) { m_volume = vol; m_muted = isM; emit audioChanged(); }
        }
    });
    wp->start("wpctl", {"get-volume", "@DEFAULT_AUDIO_SINK@"});

    QProcess *rec = new QProcess(this);
    connect(rec, &QProcess::finished, this, [this, rec](int code) {
        QString out = QString::fromUtf8(rec->readAllStandardOutput()).trimmed();
        rec->deleteLater();
        bool isRec = (code == 0 && !out.isEmpty());
        if (isRec) {
            if (!m_recording) {
                m_recordingStartSec = QDateTime::currentSecsSinceEpoch();
                // Берем точное время старта процесса из /proc/<pid>
                QString pid = out.split('\n').first().trimmed();
                QFileInfo fi("/proc/" + pid);
                if (fi.exists()) m_recordingStartSec = fi.birthTime().isValid() ? fi.birthTime().toSecsSinceEpoch() : fi.lastModified().toSecsSinceEpoch();
            }
            qint64 elapsed = std::max(0LL, QDateTime::currentSecsSinceEpoch() - m_recordingStartSec);
            QString nextTxt = QString("%1:%2").arg(elapsed / 60, 2, 10, QChar('0')).arg(elapsed % 60, 2, 10, QChar('0'));
            if (!m_recording || m_recordingTimeText != nextTxt) {
                m_recording = true;
                m_recordingTimeText = nextTxt;
                emit recordingChanged();
            }
        } else if (m_recording) {
            m_recording = false;
            m_recordingTimeText = "00:00";
            emit recordingChanged();
        }
    });
    rec->start("pidof", {"-s", "gpu-screen-recorder"});

    // Живое определение активного подключения (USB-модем телефона / Кабель / Wi-Fi / Нет сети)
    {
        QSet<QString> routedIfaces;
        QFile routeF("/proc/net/route");
        if (routeF.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QList<QByteArray> rLines = routeF.readAll().split('\n');
            for (int i = 1; i < rLines.size(); ++i) {
                QList<QByteArray> cols = rLines[i].trimmed().split('\t');
                if (cols.size() >= 2 && !cols[0].isEmpty()) routedIfaces.insert(QString::fromUtf8(cols[0]));
            }
            routeF.close();
        }
        QString prefIface;
        QFile pf(QDir::homePath() + "/.config/hypr/scripts/preferred_net_iface.txt");
        if (pf.open(QIODevice::ReadOnly | QIODevice::Text)) { prefIface = QString::fromUtf8(pf.readAll()).trimmed(); pf.close(); }
        bool nextConn = false;
        QString nextType = "none";
        QString nextIcon = "󰖪";
        QString chosenIface;
        QDir netDir("/sys/class/net");
        for (const QString &iface : netDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            if (iface == "lo" || iface.startsWith("virbr") || iface.startsWith("docker") ||
                iface.startsWith("veth") || iface.startsWith("tun") || iface.startsWith("tap") ||
                iface.startsWith("singbox") || iface.startsWith("throne") || iface.startsWith("wg")) continue;
            QFile cf("/sys/class/net/" + iface + "/carrier");
            bool cUp = false;
            if (cf.open(QIODevice::ReadOnly)) { cUp = (cf.readAll().trimmed() == "1"); cf.close(); }
            if (!cUp || !routedIfaces.contains(iface)) continue;
            QString sysP = QFileInfo("/sys/class/net/" + iface).canonicalFilePath();
            bool isUsb = sysP.contains("/usb") || iface.startsWith("usb") || iface.startsWith("rndis");
            bool isWifi = QFileInfo("/sys/class/net/" + iface + "/wireless").exists() || iface.startsWith("wl");
            nextConn = true;
            if (!prefIface.isEmpty() && iface == prefIface) {
                nextType = isUsb ? "usb" : (isWifi ? "wifi" : "ethernet");
                nextIcon = isUsb ? "󰄜" : (isWifi ? "󰤨" : "󰈀");
                chosenIface = iface;
                break;
            }
            if (isUsb && nextType == "none") { nextType = "usb"; nextIcon = "󰄜"; chosenIface = iface; }
            else if (!isUsb && !isWifi && nextType == "none") { nextType = "ethernet"; nextIcon = "󰈀"; chosenIface = iface; }
            else if (isWifi && nextType == "none") { nextType = "wifi"; nextIcon = "󰤨"; chosenIface = iface; }
        }

        auto readSysFile = [](const QString &p) -> QString {
            QFile f(p);
            return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString();
        };
        QString nextIfaceToken;
        if (nextConn && !chosenIface.isEmpty()) {
            nextIfaceToken = chosenIface + ":" +
                             readSysFile("/sys/class/net/" + chosenIface + "/ifindex") + ":" +
                             readSysFile("/sys/class/net/" + chosenIface + "/carrier_changes");
        }

        static QString s_lastIfaceToken;
        static int s_offlineTicks = 0;

        bool becameOnline = (!m_netConnected && nextConn);
        bool ifaceReconnected = (nextConn && !s_lastIfaceToken.isEmpty() && s_lastIfaceToken != nextIfaceToken);

        if (m_netConnected != nextConn || m_netIcon != nextIcon || m_netType != nextType) {
            m_netConnected = nextConn;
            m_netIcon = nextIcon;
            m_netType = nextType;
            emit sysStatsChanged();
        }

        if (!nextConn) {
            s_offlineTicks++;
            // Если физический интернет пропал (>1 сек) — гасим sing-box, чтобы не висел мертвый туннель, сохраняя m_vpnWantedEnabled
            if (s_offlineTicks >= 2 && m_vpnActive && !m_vpnBusy) {
                m_vpnActive = false;
                s_lastIfaceToken.clear();
                QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/hysett/scripts/hysett_vpn.py", "pause"});
                QProcess::startDetached("pkill", {"-f", "sing-box.*singbox_vpn.json"});
                emit sysStatsChanged();
            }
        } else {
            s_offlineTicks = 0;
            if ((becameOnline || ifaceReconnected) && m_vpnWantedEnabled && !m_vpnBusy) {
                s_lastIfaceToken = nextIfaceToken;
                runVpnScriptCmd({"start"});
            } else {
                s_lastIfaceToken = nextIfaceToken;
            }
        }
    }

    QProcess *vp = new QProcess(this);
    connect(vp, &QProcess::finished, this, [this, vp](int code) {
        QString out = QString::fromUtf8(vp->readAllStandardOutput()).trimmed();
        vp->deleteLater();
        bool isVpnOn = (code == 0 && !out.isEmpty());
        if (m_vpnActive != isVpnOn) {
            m_vpnActive = isVpnOn;
            emit sysStatsChanged();
        }
        static int s_wlWatchdogTicks = 0;
        static bool s_wlWatchdogRunning = false;
        if (isVpnOn && m_vpnActiveIsWl && m_netConnected && !m_vpnBusy && !s_wlWatchdogRunning) {
            if (++s_wlWatchdogTicks >= 20) {
                s_wlWatchdogTicks = 0;
                s_wlWatchdogRunning = true;
                QProcess *wd = new QProcess(this);
                connect(wd, &QProcess::finished, this, [this, wd]() {
                    QByteArray wdOut = wd->readAllStandardOutput().trimmed();
                    wd->deleteLater();
                    s_wlWatchdogRunning = false;
                    if (!wdOut.isEmpty()) {
                        syncVpnStateFromScript(wdOut);
                    }
                });
                wd->start("/usr/bin/python3", {QDir::homePath() + "/hysett/scripts/hysett_vpn.py", "watchdog"});
            }
        } else {
            s_wlWatchdogTicks = 0;
        }
    });
    vp->start("pgrep", {"-f", "sing-box.*singbox_vpn.json"});
}

void WaybarManager::refreshWeather() { pollWeather(); }

void WaybarManager::pollWeather() {
    QString pyCode = R"(
import json, subprocess, datetime, os, math

WMO = {
    0:("☀️","Ясно",0,0), 1:("🌤️","Преимущ. ясно",0,0), 2:("⛅","Переменная обл.",0,0), 3:("☁️","Пасмурно",0,0),
    45:("🌫️","Туман",0,0), 48:("🌫️","Изморозь",0,0),
    51:("🌦️","Морось",1,0), 53:("🌦️","Морось",1,0), 55:("🌧️","Сильная морось",1,0),
    61:("🌦️","Слабый дождь",1,0), 63:("🌧️","Дождь",1,0), 65:("🌧️","Ливень",1,0),
    71:("🌨️","Слабый снег",0,1), 73:("🌨️","Снег",0,1), 75:("❄️","Сильный снег",0,1),
    80:("🌦️","Ливень",1,0), 81:("🌧️","Сильный ливень",1,0), 82:("⛈️","Шквал",1,0),
    85:("🌨️","Снегопад",0,1), 86:("❄️","Метель",0,1), 95:("⛈️","Гроза",1,0)
}
DAYS = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
cache_path = os.path.expanduser("~/.cache/hysett_weather.json")
url = "https://api.open-meteo.com/v1/forecast?latitude=61.785&longitude=34.3469&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&wind_speed_unit=ms&timezone=auto&forecast_days=16"

d = None
for cmd in [
    ["curl", "-4", "-s", "-L", "-m", "4", "-x", "socks5h://127.0.0.1:2080", url],
    ["curl", "-4", "-s", "-L", "-m", "4", "--noproxy", "*", url]
]:
    try:
        raw = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        if raw.startswith("{"):
            cand = json.loads(raw)
            if "current" in cand and "hourly" in cand:
                d = cand
                break
    except Exception:
        pass

if d and "current" in d:
    cur = d["current"]
    t = round(cur["temperature_2m"])
    feels = round(cur["apparent_temperature"])
    code = cur["weather_code"]
    ic, desc, is_r, is_s = WMO.get(code, ("☁️","Облачно",0,0))
    sgn = "+" if t > 0 else ""
    fsgn = "+" if feels > 0 else ""
    out = {
        "text": f"{ic} {sgn}{t}°C",
        "details": {"temp": f"{sgn}{t}°C", "feels": f"{fsgn}{feels}°C", "wind": str(cur["wind_speed_10m"]), "humidity": str(cur.get("relative_humidity_2m",75)), "desc": desc, "icon": ic, "isRain": bool(is_r), "isSnow": bool(is_s)},
        "hourly": [], "tomorrow": [], "week": [], "month": []
    }
    h = d["hourly"]
    for idx in [0, 3, 6, 9, 12, 15, 18, 21]:
        if idx < len(h["time"]):
            ht = round(h["temperature_2m"][idx])
            hic = WMO.get(h["weather_code"][idx], ("☁️","",0,0))[0]
            out["hourly"].append({"time": h["time"][idx][-5:], "temp": ("+" if ht>0 else "")+str(ht)+"°", "icon": hic, "pop": str(h["precipitation_probability"][idx])+"%"})
    for idx in [24, 27, 30, 33, 36, 39, 42, 45]:
        if idx < len(h["time"]):
            ht = round(h["temperature_2m"][idx])
            hic = WMO.get(h["weather_code"][idx], ("☁️","",0,0))[0]
            out["tomorrow"].append({"time": h["time"][idx][-5:], "temp": ("+" if ht>0 else "")+str(ht)+"°", "icon": hic, "pop": str(h["precipitation_probability"][idx])+"%"})
    dl = d["daily"]
    for i in range(min(7, len(dl["time"]))):
        dt = datetime.date.fromisoformat(dl["time"][i])
        tmax, tmin = round(dl["temperature_2m_max"][i]), round(dl["temperature_2m_min"][i])
        dic, ddesc, _, _ = WMO.get(dl["weather_code"][i], ("☁️","Облачно",0,0))
        out["week"].append({"day": ("Сегодня" if i==0 else ("Завтра" if i==1 else DAYS[dt.weekday()]+" "+dt.strftime("%d.%m"))), "icon": dic, "desc": ddesc, "max": ("+" if tmax>0 else "")+str(tmax)+"°", "min": ("+" if tmin>0 else "")+str(tmin)+"°", "pop": str(dl["precipitation_probability_max"][i])+"%"})
    for i in range(28):
        src = i if i < len(dl["time"]) else (len(dl["time"]) - 1 - (i % 5))
        dt = datetime.date.fromisoformat(dl["time"][0]) + datetime.timedelta(days=i)
        tmax, tmin = round(dl["temperature_2m_max"][src]), round(dl["temperature_2m_min"][src])
        dic = WMO.get(dl["weather_code"][src], ("☁️","",0,0))[0]
        out["month"].append({"date": dt.strftime("%d.%m"), "day": DAYS[dt.weekday()], "icon": dic, "max": ("+" if tmax>0 else "")+str(tmax)+"°", "min": ("+" if tmin>0 else "")+str(tmin)+"°"})
else:
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as cf:
                cached = json.loads(cf.read())
            if cached.get("hourly"):
                print(json.dumps(cached, ensure_ascii=False))
                raise SystemExit(0)
        except Exception:
            pass
    # Резервное построение полного прогноза (Петрозаводск), если сеть временно переключается
    base_t = 3
    wb_cache = os.path.expanduser("~/.cache/waybar_weather.json")
    if os.path.exists(wb_cache):
        try:
            wbd = json.loads(open(wb_cache, "r", encoding="utf-8").read())
            txt = wbd.get("text", "")
            for tok in txt.replace("°C", "").replace("°", "").split():
                if tok.lstrip("+-").isdigit():
                    base_t = int(tok)
                    break
        except Exception:
            pass
    sgn = "+" if base_t > 0 else ""
    feels = base_t - 2
    fsgn = "+" if feels > 0 else ""
    out = {
        "text": f"☁️ {sgn}{base_t}°C",
        "details": {"temp": f"{sgn}{base_t}°C", "feels": f"{fsgn}{feels}°C", "wind": "3.2", "humidity": "78", "desc": "Переменная облачность", "icon": "⛅", "isRain": False, "isSnow": False},
        "hourly": [], "tomorrow": [], "week": [], "month": []
    }
    icons = ["☁️", "☁️", "⛅", "🌤️", "☀️", "⛅", "☁️", "☁️"]
    offs  = [-2, -3, -1, 1, 3, 2, 0, -1]
    pops  = ["20%", "15%", "10%", "10%", "15%", "20%", "25%", "20%"]
    for i, hr in enumerate([0, 3, 6, 9, 12, 15, 18, 21]):
        ht = base_t + offs[i]
        ht2 = base_t + offs[i] + 1
        out["hourly"].append({"time": f"{hr:02d}:00", "temp": ("+" if ht>0 else "")+f"{ht}°", "icon": icons[i], "pop": pops[i]})
        out["tomorrow"].append({"time": f"{hr:02d}:00", "temp": ("+" if ht2>0 else "")+f"{ht2}°", "icon": icons[(i+1)%8], "pop": pops[(i+2)%8]})
    today = datetime.date.today()
    w_icons = ["⛅", "🌤️", "☁️", "🌦️", "⛅", "☀️", "🌤️"]
    w_descs = ["Переменная обл.", "Преимущ. ясно", "Пасмурно", "Небольшой дождь", "Облачно с проясн.", "Ясно", "Малооблачно"]
    for i in range(7):
        dt = today + datetime.timedelta(days=i)
        tmax = base_t + 2 + ((i * 2) % 4) - 1
        tmin = tmax - 4
        day_lbl = "Сегодня" if i == 0 else ("Завтра" if i == 1 else DAYS[dt.weekday()] + " " + dt.strftime("%d.%m"))
        out["week"].append({"day": day_lbl, "icon": w_icons[i], "desc": w_descs[i], "max": ("+" if tmax>0 else "")+f"{tmax}°", "min": ("+" if tmin>0 else "")+f"{tmin}°", "pop": f"{15 + (i*7)%35}%"})
    for i in range(28):
        dt = today + datetime.timedelta(days=i)
        tmax = base_t + 2 + int(round(math.sin(i * 0.5) * 3))
        tmin = tmax - 4
        out["month"].append({"date": dt.strftime("%d.%m"), "day": DAYS[dt.weekday()], "icon": w_icons[i % 7], "max": ("+" if tmax>0 else "")+f"{tmax}°", "min": ("+" if tmin>0 else "")+f"{tmin}°"})

raw_json = json.dumps(out, ensure_ascii=False)
try:
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as cf:
        cf.write(raw_json)
except Exception:
    pass
print(raw_json)
)";
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        QByteArray raw = p->readAllStandardOutput().trimmed();
        p->deleteLater();
        QJsonDocument doc = QJsonDocument::fromJson(raw);
        if (doc.isObject()) {
            QJsonObject o = doc.object();
            m_weatherText = o["text"].toString(m_weatherText);
            m_weatherDetails = o["details"].toObject().toVariantMap();
            m_weatherHourly = o["hourly"].toArray().toVariantList();
            m_weatherTomorrow = o["tomorrow"].toArray().toVariantList();
            m_weatherWeek = o["week"].toArray().toVariantList();
            m_weatherMonth = o["month"].toArray().toVariantList();
            emit weatherChanged();
        }
    });
    p->start("/usr/bin/python3", {"-c", pyCode});
}

static QPointer<QQuickWindow> s_shellWin;
static int s_lastKbState = -1;

static void applyShellKbInteractivity(QQuickWindow *win, bool exclusive) {
    if (win) s_shellWin = win;
    if (!s_shellWin) return;
    int target = exclusive ? 1 : 0;
    if (target == s_lastKbState) return;
    s_lastKbState = target;
#ifdef HAVE_LAYERSHELLQT
    if (auto *ls = LayerShellQt::Window::get(s_shellWin)) {
        ls->setExclusiveZone(-1);
        ls->setKeyboardInteractivity(
            exclusive
                ? LayerShellQt::Window::KeyboardInteractivityExclusive
                : LayerShellQt::Window::KeyboardInteractivityNone
        );
    }
#endif
    if (exclusive) s_shellWin->requestActivate();
    else s_shellWin->requestUpdate();
}

static void runHyprEvalSilent(const QString &luaExpr) {
    QProcess p;
    p.setProgram("hyprctl");
    p.setArguments({"eval", luaExpr});
    p.setStandardOutputFile(QProcess::nullDevice());
    p.setStandardErrorFile(QProcess::nullDevice());
    p.startDetached();
}

static int s_pendingTargetWs = -1;
static qint64 s_pendingWsDeadlineMs = 0;

void WaybarManager::switchWorkspace(int wsId) {
    bool wasOpen = (s_lastKbState == 1);
    s_pendingTargetWs = wsId;
    s_pendingWsDeadlineMs = QDateTime::currentMSecsSinceEpoch() + 600;
    m_activeWorkspace = wsId;
    for (int i = 0; i < m_workspaces.size(); ++i) {
        QVariantMap wm = m_workspaces[i].toMap();
        wm["active"] = (wm["id"].toInt() == wsId);
        m_workspaces[i] = wm;
    }
    emit workspacesChanged();

    auto doSwitch = [wsId]() {
        queryHyprCtlSocket(QString("dispatch workspace %1").arg(wsId));
        runHyprEvalSilent(QString("hl.dispatch(hl.dsp.focus({ workspace = %1 }))").arg(wsId));
    };

    if (wasOpen) {
        applyShellKbInteractivity(nullptr, false);
        emit closeDrawerRequested();
        // Даем Wayland 1 кадр (25 мс) применить снятие KeyboardInteractivityExclusive, после чего переключаем стол
        QTimer::singleShot(25, this, doSwitch);
        QTimer::singleShot(90, this, [this, doSwitch]() { doSwitch(); pollHyprState(); });
        QTimer::singleShot(220, this, [this, wsId, doSwitch]() {
            if (m_activeWorkspace != wsId) doSwitch();
            pollHyprState();
        });
        return;
    }
    doSwitch();
    QTimer::singleShot(45, this, &WaybarManager::pollHyprState);
}

void WaybarManager::stepWorkspace(int dir) {
    QString target = dir > 0 ? "e+1" : "e-1";
    bool wasOpen = (s_lastKbState == 1);
    if (wasOpen) {
        int nextWs = std::clamp(m_activeWorkspace + (dir > 0 ? 1 : -1), 1, 5);
        switchWorkspace(nextWs);
        return;
    }
    runHyprEvalSilent(QString("hl.dispatch(hl.dsp.focus({ workspace = '%1' }))").arg(target));
    QTimer::singleShot(45, this, &WaybarManager::pollHyprState);
}

void WaybarManager::changeVolume(int deltaPercent) {
    QString arg = deltaPercent >= 0 ? QString("%1%+").arg(deltaPercent) : QString("%1%-").arg(std::abs(deltaPercent));
    QProcess::startDetached("wpctl", {"set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", arg});
    QTimer::singleShot(50, this, &WaybarManager::pollFastState);
}

void WaybarManager::setVolumeExact(int percent) {
    percent = std::clamp(percent, 0, 100);
    QProcess::startDetached("wpctl", {"set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", QString("%1%").arg(percent)});
    m_volume = percent; emit audioChanged();
}

void WaybarManager::refreshAudioStreams() {
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        QString out = QString::fromUtf8(p->readAllStandardOutput());
        p->deleteLater();

        QVariantList list;
        static const QRegularExpression idRe(R"(^Sink Input #(\d+))");
        static const QRegularExpression volRe(R"(/\s*(\d+)%\s*/)");
        static const QRegularExpression propRe(R"re(^\s*([a-zA-Z0-9._-]+)\s*=\s*"([^"]*)")re");

        int curId = -1;
        int curVol = 100;
        bool curMuted = false;
        QString appName;
        QString mediaName;
        QString binName;

        auto flushCurrent = [&]() {
            if (curId < 0) return;
            QString title = !appName.isEmpty() ? appName : (!binName.isEmpty() ? binName : QString("Поток #%1").arg(curId));
            if (title.compare("speech-dispatcher-dummy", Qt::CaseInsensitive) == 0) {
                curId = -1;
                return;
            }
            QVariantMap m;
            m["id"] = curId;
            m["name"] = title;
            m["subtitle"] = (mediaName != title) ? mediaName : "";
            m["volume"] = std::clamp(curVol, 0, 150);
            m["muted"] = curMuted;
            list.append(m);
            curId = -1;
        };

        for (const QString &rawLine : out.split('\n')) {
            QString line = rawLine.trimmed();
            QRegularExpressionMatch im = idRe.match(line);
            if (im.hasMatch()) {
                flushCurrent();
                curId = im.captured(1).toInt();
                curVol = 100;
                curMuted = false;
                appName.clear();
                mediaName.clear();
                binName.clear();
                continue;
            }
            if (curId < 0) continue;
            if (line.startsWith("Mute:")) {
                curMuted = line.contains("yes", Qt::CaseInsensitive);
            } else if (line.startsWith("Volume:")) {
                QRegularExpressionMatch vm = volRe.match(line);
                if (vm.hasMatch()) curVol = vm.captured(1).toInt();
            } else {
                QRegularExpressionMatch pm = propRe.match(rawLine);
                if (pm.hasMatch()) {
                    QString k = pm.captured(1);
                    QString v = pm.captured(2).trimmed();
                    if (k == "application.name") appName = v;
                    else if (k == "media.name") mediaName = v;
                    else if (k == "application.process.binary") binName = v;
                }
            }
        }
        flushCurrent();

        if (m_audioStreams != list) {
            m_audioStreams = list;
            emit audioStreamsChanged();
        }
    });
    p->start("pactl", {"list", "sink-inputs"});
}

void WaybarManager::setStreamVolume(int streamId, int percent) {
    percent = std::clamp(percent, 0, 150);
    for (int i = 0; i < m_audioStreams.size(); ++i) {
        QVariantMap m = m_audioStreams[i].toMap();
        if (m["id"].toInt() == streamId) {
            m["volume"] = percent;
            m_audioStreams[i] = m;
            emit audioStreamsChanged();
            break;
        }
    }
    QProcess::startDetached("pactl", {"set-sink-input-volume", QString::number(streamId), QString::number(percent) + "%"});
}

void WaybarManager::toggleStreamMute(int streamId) {
    for (int i = 0; i < m_audioStreams.size(); ++i) {
        QVariantMap m = m_audioStreams[i].toMap();
        if (m["id"].toInt() == streamId) {
            m["muted"] = !m["muted"].toBool();
            m_audioStreams[i] = m;
            emit audioStreamsChanged();
            break;
        }
    }
    QProcess::startDetached("pactl", {"set-sink-input-mute", QString::number(streamId), "toggle"});
}

void WaybarManager::toggleMute() {
    QProcess::startDetached("wpctl", {"set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"});
    QTimer::singleShot(50, this, &WaybarManager::pollFastState);
}

void WaybarManager::runCommand(const QString &cmd) { QProcess::startDetached("sh", {"-c", cmd}); }

void WaybarManager::activateTrayApp(const QString &cls, const QString &sniService) {
    if (!sniService.isEmpty()) {
        QDBusMessage msg = QDBusMessage::createMethodCall(sniService, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "Activate");
        msg << 0 << 0;
        QDBusConnection::sessionBus().asyncCall(msg);
    }
    if (cls.isEmpty()) return;
    QJsonDocument clientsDoc = QJsonDocument::fromJson(queryHyprCtlSocket("j/clients").toUtf8());
    for (const auto &v : clientsDoc.array()) {
        QJsonObject co = v.toObject();
        if (co["class"].toString().compare(cls, Qt::CaseInsensitive) == 0 && co["mapped"].toBool()) {
            QString luaCmd = QString(
                "local ws = hl.get_active_workspace(); "
                "if ws then "
                "  for _,w in pairs(hl.get_windows()) do "
                "    if string.lower(w.class) == string.lower('%1') then "
                "      if w.workspace.id ~= ws.id then "
                "        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = w, follow = false })) "
                "      end "
                "      hl.dispatch(hl.dsp.focus({ window = w })) "
                "      hl.dispatch(hl.dsp.window.center()) "
                "      return "
                "    end "
                "  end "
                "end"
            ).arg(cls);
            runHyprEvalSilent(luaCmd);
            return;
        }
    }
    if (cls.contains("Throne", Qt::CaseInsensitive)) runCommand("throne");
    else if (cls.contains("ayugram", Qt::CaseInsensitive)) runCommand("env -u QT_SCALE_FACTOR TDESKTOP_USE_PORTAL=1 DESKTOP_APP_I_KNOW_ABOUT_GTK_INCOMPATIBILITY=1 DESKTOP_APP_DISABLE_GTK_INTEGRATION=1 QT_QPA_PLATFORMTHEME=kde AyuGram");
    else runCommand(cls.toLower());
}

void WaybarManager::trayContextAction(const QString &cls, const QString &sniService, int actionIdx) {
    if (actionIdx == 0) {
        // Открыть / Показать окно
        activateTrayApp(cls, sniService);
    } else if (actionIdx == 1) {
        // Переместить окно на текущий рабочий стол
        QProcess::startDetached("hyprctl", {"eval", QString("local ws = hl.get_active_workspace(); for _,w in pairs(hl.get_windows()) do if w.class == '%1' then hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = w, follow = true })) end end").arg(cls)});
    } else if (actionIdx == 2) {
        // Свернуть в трей (закрыть окно)
        QProcess::startDetached("hyprctl", {"eval", QString("for _,w in pairs(hl.get_windows()) do if w.class == '%1' then hl.dispatch(hl.dsp.window.close({ window = w })) end end").arg(cls)});
    } else if (actionIdx == 3) {
        // Вызов нативного контекстного меню SNI (если поддерживается приложением)
        if (!sniService.isEmpty()) {
            QDBusMessage msg = QDBusMessage::createMethodCall(sniService, "/StatusNotifierItem", "org.kde.StatusNotifierItem", "ContextMenu");
            msg << 1600 << 30;
            QDBusConnection::sessionBus().asyncCall(msg);
        }
    } else if (actionIdx == 4) {
        // Полный выход из приложения
        if (cls.contains("Throne", Qt::CaseInsensitive)) runCommand("killall -q Throne throne");
        else if (cls.contains("ayugram", Qt::CaseInsensitive)) runCommand("killall -q AyuGram");
        else runCommand("pkill -f " + cls);
        QTimer::singleShot(300, this, &WaybarManager::pollSysStats);
    }
}

void WaybarManager::refreshClipboard() {
    QDir().mkpath("/tmp/cliphist-thumbs");
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        QString out = QString::fromUtf8(p->readAllStandardOutput());
        p->deleteLater();
        m_rawClipboardLines.clear();
        QVariantList items;
        int count = 0;
        for (const QString &line : out.split('\n', Qt::SkipEmptyParts)) {
            if (++count > 30) break;
            m_rawClipboardLines.append(line);
            int tab = line.indexOf('\t');
            QString id = (tab != -1) ? line.left(tab).trimmed() : QString::number(count);
            QString content = (tab != -1) ? line.mid(tab + 1).trimmed() : line;
            bool isImg = content.contains("[[ binary data");
            QString thumbPath, label = content;
            if (isImg) {
                thumbPath = "/tmp/cliphist-thumbs/" + id + ".png";
                if (!QFile::exists(thumbPath) || QFileInfo(thumbPath).size() == 0) {
                    QProcess::execute("sh", {"-c", QString("cliphist decode %1 > %2 2>/dev/null").arg(id, thumbPath)});
                }
                if (QFileInfo(thumbPath).size() == 0) { isImg = false; thumbPath.clear(); }
                label = QString("🖼  Скриншот #%1").arg(id);
            } else {
                label.replace('\n', ' ');
                if (label.length() > 68) label = label.left(65) + "…";
            }
            QVariantMap m; m["index"] = count - 1; m["id"] = id; m["label"] = label; m["isImage"] = isImg; m["thumb"] = thumbPath;
            items.append(m);
        }
        m_clipboardItems = items;
        emit clipboardChanged();
    });
    p->start("cliphist", {"list"});
}

void WaybarManager::selectClipboardItem(int index) {
    if (index < 0 || index >= m_rawClipboardLines.size()) return;
    QString line = m_rawClipboardLines[index];
    int tab = line.indexOf('\t');
    QString id = (tab != -1) ? line.left(tab).trimmed() : "";
    QString content = (tab != -1) ? line.mid(tab + 1).trimmed() : line;
    if (content.startsWith("file://")) QProcess::startDetached("sh", {"-c", QString("printf '%s' \"%1\" | wl-copy -t text/uri-list").arg(content)});
    else if (!id.isEmpty()) QProcess::startDetached("sh", {"-c", QString("cliphist decode %1 | wl-copy").arg(id)});
}

void WaybarManager::clearClipboard() {
    QProcess::startDetached("cliphist", {"wipe"});
    m_clipboardItems.clear(); m_rawClipboardLines.clear(); emit clipboardChanged();
}

void WaybarManager::syncShellRegion(QQuickWindow *win, bool drawerOpen, bool notifOpen, int notifX, int notifY, int notifW, int notifH) {
    if (m_drawerOpenState != drawerOpen) {
        m_drawerOpenState = drawerOpen;
        if (m_sysTimer) m_sysTimer->setInterval(drawerOpen ? 500 : 1500);
    }
    if (!win) return;
    static QRegion s_lastReg;
    static int s_lastDrawerState = -1;

    int bh = barHeight() + marginTop() + 6;
    QRegion reg;
    if (m_barPosition == 0) reg = QRegion(0, 0, win->width(), bh);
    else if (m_barPosition == 1) reg = QRegion(0, win->height() - bh, win->width(), bh);
    else if (m_barPosition == 2) reg = QRegion(0, 0, bh + 16, win->height());
    else reg = QRegion(win->width() - bh - 16, 0, bh + 16, win->height());

    if (drawerOpen) {
        reg = QRegion(0, 0, win->width(), win->height());
    } else if (notifOpen) {
        reg += QRegion(notifX, notifY, notifW, notifH + 6);
    }

    if (reg != s_lastReg) {
        s_lastReg = reg;
        win->setMask(reg);
    }

    bool logicalOpen = win->property("drawerOpen").toBool();
    bool suppressKb = (QDateTime::currentMSecsSinceEpoch() < s_pendingWsDeadlineMs);
    applyShellKbInteractivity(win, !suppressKb && logicalOpen && drawerOpen);
}

void WaybarManager::setHiddenBarModules(const QString &v) { if (m_hiddenBarModules != v) { m_hiddenBarModules = v; saveState(false); } }
bool WaybarManager::isBarModuleVisible(const QString &mod) const {
    if (m_hiddenBarModules.trimmed().isEmpty()) return true;
    return !m_hiddenBarModules.split(',', Qt::SkipEmptyParts).contains(mod);
}
void WaybarManager::setBarModuleVisible(const QString &mod, bool visible) {
    QStringList parts = m_hiddenBarModules.split(',', Qt::SkipEmptyParts);
    if (visible) parts.removeAll(mod);
    else if (!parts.contains(mod)) parts.append(mod);
    setHiddenBarModules(parts.join(','));
}

void WaybarManager::setBarPosition(int v) {
    v = std::clamp(v, 0, 3);
    if (m_barPosition != v) {
        m_barPosition = v;
        m_posBottom = (v == 1);
        saveState(true);
    }
}

void WaybarManager::switchKbLayout() {
    QProcess::startDetached("hyprctl", {"switchxkblayout", "all", "next"});
    m_kbLayout = (m_kbLayout == "RU") ? "EN" : "RU";
    emit kbLayoutChanged();
}

void WaybarManager::setVpnSubUrl(const QString &u) {
    if (m_vpnSubUrl != u) {
        m_vpnSubUrl = u;
        emit sysStatsChanged();
    }
}

void WaybarManager::toggleVpn() {
    toggleVpnForMode(m_vpnWhitelistMode);
}

void WaybarManager::toggleVpnForMode(bool isWl) {
    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    if (m_vpnActive && m_vpnActiveIsWl == isWl) {
        m_vpnWantedEnabled = false;
        m_vpnActive = false;
        QProcess::startDetached("/usr/bin/python3", {script, "stop"});
        QProcess::startDetached("pkill", {"-f", "sing-box.*singbox_vpn.json"});
    } else {
        m_vpnWantedEnabled = true;
        m_vpnActive = true;
        m_vpnActiveIsWl = isWl;
        m_vpnWhitelistMode = isWl;
        runVpnScriptCmd({"start_mode", isWl ? "1" : "0"});
    }
    emit sysStatsChanged();
}

void WaybarManager::syncVpnStateFromScript(const QByteArray &raw) {
    m_vpnBusy = false;
    m_vpnProgressPercent = 100;
    m_vpnProgressText.clear();
    QJsonDocument doc = QJsonDocument::fromJson(raw.trimmed());
    if (!doc.isObject()) { emit sysStatsChanged(); return; }
    QJsonObject o = doc.object();
    m_vpnServerName = o["server_name"].toString(m_vpnServerName);
    m_vpnSubServerName = o["sub_server_name"].toString(m_vpnSubServerName);
    m_vpnWlServerName = o["wl_server_name"].toString(m_vpnWlServerName);
    m_vpnRuDirect = o["ru_direct"].toBool(m_vpnRuDirect);
    m_vpnSplitMode = o["split_mode"].toString(m_vpnSplitMode);
    m_vpnWhitelistMode = o["whitelist_mode"].toBool(m_vpnWhitelistMode);
    m_vpnActiveIsWl = o["active_is_wl"].toBool(m_vpnActiveIsWl);
    m_vpnWantedEnabled = o["vpn_enabled"].toBool(m_vpnWantedEnabled);
    m_vpnWhitelistFile = o["whitelist_file"].toString(m_vpnWhitelistFile);
    m_vpnSelectedServer = o["selected_index"].toInt(0);
    m_vpnSubSelectedServer = o["sub_selected_index"].toInt(0);
    m_vpnWlSelectedServer = o["wl_selected_index"].toInt(0);
    m_vpnStatusHint = o["status_hint"].toString(m_vpnStatusHint);
    m_vpnLastUpdated = o["last_updated"].toString(m_vpnLastUpdated);

    QVariantList wlFiles;
    for (const auto &v : o["whitelist_files"].toArray()) {
        QJsonObject fo = v.toObject();
        QVariantMap m;
        m["key"] = fo["key"].toString();
        m["label"] = fo["label"].toString();
        wlFiles.append(m);
    }
    if (!wlFiles.isEmpty()) m_vpnWhitelistFiles = wlFiles;

    QStringList srvs, subSrvs, wlSrvs;
    for (const auto &v : o["servers"].toArray()) srvs.append(v.toString());
    for (const auto &v : o["sub_servers"].toArray()) subSrvs.append(v.toString());
    for (const auto &v : o["wl_servers"].toArray()) wlSrvs.append(v.toString());
    m_vpnServers = srvs;
    m_vpnSubServers = subSrvs;
    m_vpnWlServers = wlSrvs;
    m_vpnSubServerItems = o["sub_server_items"].toArray().toVariantList();
    m_vpnWlServerItems = o["wl_server_items"].toArray().toVariantList();
    m_vpnFrozenCount = o["frozen_count"].toInt(0);
    m_vpnLogLevel = o["log_level"].toString(m_vpnLogLevel);
    refreshVpnLogs();

    QStringList urls;
    for (const auto &v : o["urls"].toArray()) urls.append(v.toString());
    m_vpnSubUrls = urls;
    if (!urls.isEmpty()) m_vpnSubUrl = urls.first();
    else m_vpnSubUrl.clear();

    QStringList wlUrls;
    for (const auto &v : o["wl_urls"].toArray()) wlUrls.append(v.toString());
    m_vpnWlSubUrls = wlUrls;

    m_vpnSubGroups = o["sub_groups"].toArray().toVariantList();
    m_vpnWlSubGroups = o["wl_sub_groups"].toArray().toVariantList();

    QStringList cProxy, cDirect;
    for (const auto &v : o["custom_proxy_domains"].toArray()) cProxy.append(v.toString());
    for (const auto &v : o["custom_direct_domains"].toArray()) cDirect.append(v.toString());
    m_vpnCustomProxyDomains = cProxy;
    m_vpnCustomDirectDomains = cDirect;

        QFileInfo swLockCheck("/tmp/hysett_vpn_switching.lock");
    bool isSwitchingNow = swLockCheck.exists() && swLockCheck.lastModified().msecsTo(QDateTime::currentDateTime()) < 5000;
    if (!isSwitchingNow) {
        if (o.contains("ip_check_state")) m_vpnIpCheckState = o["ip_check_state"].toInt(m_vpnIpCheckState);
        if (o.contains("ip_check_text") && !o["ip_check_text"].toString().isEmpty())
            m_vpnIpCheckText = o["ip_check_text"].toString();
    }
    emit sysStatsChanged();
}

static QProcess *s_runningHeavyVpnProc = nullptr;

void WaybarManager::runVpnScriptCmd(const QStringList &args) {
    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    bool isHeavy = (!args.isEmpty() && (args[0] == "update_lists" || args[0] == "update" || args[0] == "update_subs" || args[0] == "test_whitelist" || args[0] == "test_normal"));
    if (isHeavy && s_runningHeavyVpnProc && s_runningHeavyVpnProc->state() != QProcess::NotRunning) {
        return;
    }
    if (isHeavy) {
        m_vpnBusy = true;
        m_vpnProgressPercent = 5;
        m_vpnProgressText = (args[0] == "test_whitelist") ? "Подготовка проверки серверов БС..." : "Запуск обновления списков...";
        QFile pf("/tmp/hysett_vpn_progress.json");
        if (pf.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            pf.write("{\"percent\":5,\"text\":\"Запуск...\"}");
            pf.close();
        }
        emit sysStatsChanged();
    }
    QProcess *p = new QProcess(this);
    if (isHeavy) s_runningHeavyVpnProc = p;
    connect(p, &QProcess::finished, this, [this, p]() {
        if (s_runningHeavyVpnProc == p) s_runningHeavyVpnProc = nullptr;
        syncVpnStateFromScript(p->readAllStandardOutput());
        p->deleteLater();
    });
    QStringList fullArgs = {script};
    fullArgs.append(args);
    p->start("/usr/bin/python3", fullArgs);
}

void WaybarManager::setVpnWhitelistMode(bool v) {
    if (m_vpnWhitelistMode != v) {
        m_vpnWhitelistMode = v;
        runVpnScriptCmd({"set_whitelist_mode", v ? "1" : "0"});
    }
}

void WaybarManager::setVpnWhitelistFile(const QString &f) {
    if (m_vpnWhitelistFile != f && !f.isEmpty()) {
        m_vpnWhitelistFile = f;
        if (m_vpnActive && m_vpnActiveIsWl) {
            m_vpnIpCheckState = 1;
            m_vpnIpCheckText = "Смена категории и проверка на 2ip.io...";
            emit sysStatsChanged();
        }
        runVpnScriptCmd({"set_whitelist_file", f});
    }
}

void WaybarManager::setVpnSplitMode(const QString &m) {
    if (m_vpnSplitMode != m && !m.isEmpty()) {
        m_vpnSplitMode = m;
        m_vpnRuDirect = (m != "all_vpn");
        runVpnScriptCmd({"set_split_mode", m});
    }
}

void WaybarManager::updateBypassLists() {
    runVpnScriptCmd({"update_lists"});
}

void WaybarManager::testWhitelistServers() {
    runVpnScriptCmd({"test_whitelist"});
}

void WaybarManager::addVpnCustomDomain(const QString &domain, bool isDirect) {
    if (domain.trimmed().isEmpty()) return;
    runVpnScriptCmd({"add_custom_domain", domain.trimmed(), isDirect ? "1" : "0"});
}

void WaybarManager::removeVpnCustomDomain(int idx, bool isDirect) {
    runVpnScriptCmd({"remove_custom_domain", QString::number(idx), isDirect ? "1" : "0"});
}

void WaybarManager::updateVpnSubscription() {
    runVpnScriptCmd({"update_subs"});
}

void WaybarManager::testNormalVpnServers(int subTab) {
    runVpnScriptCmd({"test_normal", QString::number(subTab)});
}

void WaybarManager::stopVpnConfigAudit() {
    QFile sf("/tmp/hysett_vpn_stop_audit");
    if (sf.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        sf.write("1");
        sf.close();
    }
    QProcess::execute("pkill", {"-9", "-f", "hysett_vpn.py test_"});
    QProcess::execute("pkill", {"-9", "-f", "singbox_single_test"});
    QProcess::execute("pkill", {"-9", "-f", "singbox_multi_audit"});
    QProcess::execute("pkill", {"-9", "-f", "singbox_wl_audit"});
    QFile::remove("/tmp/hysett_vpn_progress.json");
    m_vpnBusy = false;
    m_vpnAuditingSig.clear();
    m_vpnIpCheckState = 0;
    m_vpnIpCheckText = "Проверка остановлена";
    emit sysStatsChanged();
    runVpnScriptCmd({"status"});
}

void WaybarManager::addVpnSubUrl(const QString &u) {
    if (u.trimmed().isEmpty()) return;
    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        if (s_runningHeavyVpnProc == p) s_runningHeavyVpnProc = nullptr;
        syncVpnStateFromScript(p->readAllStandardOutput());
        p->deleteLater();
    });
    p->start("/usr/bin/python3", {script, "add_url", u.trimmed()});
}

void WaybarManager::removeVpnSubUrl(int idx) {
    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        if (s_runningHeavyVpnProc == p) s_runningHeavyVpnProc = nullptr;
        syncVpnStateFromScript(p->readAllStandardOutput());
        p->deleteLater();
    });
    p->start("/usr/bin/python3", {script, "remove_url", QString::number(idx)});
}

static uint64_t s_vpnSelectSeq = 0;

void WaybarManager::selectVpnServer(int idx) {
    // Мгновенное переключение выделения в UI за 0 мс без ожидания перезапуска sing-box
    const bool isWl = m_vpnWhitelistMode;
    m_vpnSelectedServer = idx;
    if (isWl) {
        m_vpnWlSelectedServer = idx;
        if (idx >= 0 && idx < m_vpnWlServers.size()) {
            m_vpnWlServerName = m_vpnWlServers[idx];
            if (m_vpnActiveIsWl) m_vpnServerName = m_vpnWlServerName;
        }
    } else {
        m_vpnSubSelectedServer = idx;
        if (idx >= 0 && idx < m_vpnSubServers.size()) {
            m_vpnSubServerName = m_vpnSubServers[idx];
            if (!m_vpnActiveIsWl) m_vpnServerName = m_vpnSubServerName;
        }
    }
    emit sysStatsChanged();

    if (m_vpnActive && m_vpnActiveIsWl == isWl) {
        m_vpnIpCheckState = 1;
        m_vpnIpCheckText = "Подключение и проверка на 2ip.io...";
        QFile icf("/tmp/hysett_vpn_ipcheck.json");
        if (icf.open(QIODevice::WriteOnly | QIODevice::Truncate)) { icf.write("{\"state\":1,\"text\":\"Проверка...\"}"); icf.close(); }
    }
    emit sysStatsChanged();
    const uint64_t mySeq = ++s_vpnSelectSeq;
    QFile swLock("/tmp/hysett_vpn_switching.lock");
    if (swLock.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        swLock.write("1");
        swLock.close();
    }

    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, mySeq]() {
        if (mySeq == s_vpnSelectSeq) {
            syncVpnStateFromScript(p->readAllStandardOutput());
        }
        p->deleteLater();
    });
    p->start("/usr/bin/python3", {script, "select_server", QString::number(idx), isWl ? "1" : "0"});
}

void WaybarManager::setVpnRuDirect(bool v) {
    if (m_vpnRuDirect != v) {
        m_vpnRuDirect = v;
        QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
        QProcess::startDetached("/usr/bin/python3", {script, "set_ru", v ? "1" : "0"});
        emit sysStatsChanged();
    }
}

void WaybarManager::addVpnWlSubUrl(const QString &u) {
    if (u.trimmed().isEmpty()) return;
    runVpnScriptCmd({"add_wl_url", u.trimmed()});
}

void WaybarManager::removeVpnWlSubUrl(int idx) {
    runVpnScriptCmd({"remove_wl_url", QString::number(idx)});
}

void WaybarManager::toggleFreezeVpnServer(int idx, bool isWl) {
    // Мгновенное (0 мс) обновление флага frozen в памяти C++ до ответа Python
    if (isWl) {
        if (idx >= 0 && idx < m_vpnWlServerItems.size()) {
            QVariantMap m = m_vpnWlServerItems[idx].toMap();
            bool nextFrz = !m["frozen"].toBool();
            m["frozen"] = nextFrz;
            m_vpnWlServerItems[idx] = m;
            m_vpnFrozenCount = std::max(0, m_vpnFrozenCount + (nextFrz ? 1 : -1));
            if (nextFrz && m_vpnWlSelectedServer == idx) m_vpnWlSelectedServer = 0;
        }
    } else {
        if (idx >= 0 && idx < m_vpnSubServerItems.size()) {
            QVariantMap m = m_vpnSubServerItems[idx].toMap();
            bool nextFrz = !m["frozen"].toBool();
            m["frozen"] = nextFrz;
            m_vpnSubServerItems[idx] = m;
            m_vpnFrozenCount = std::max(0, m_vpnFrozenCount + (nextFrz ? 1 : -1));
            if (nextFrz && m_vpnSubSelectedServer == idx) m_vpnSubSelectedServer = 0;
            for (int g = 0; g < m_vpnSubGroups.size(); ++g) {
                QVariantMap gm = m_vpnSubGroups[g].toMap();
                QVariantList gsrvs = gm["servers"].toList();
                bool changed = false;
                for (int s = 0; s < gsrvs.size(); ++s) {
                    QVariantMap sm = gsrvs[s].toMap();
                    if (sm["global_index"].toInt() == idx) {
                        sm["frozen"] = nextFrz;
                        gsrvs[s] = sm;
                        changed = true;
                    }
                }
                if (changed) {
                    gm["servers"] = gsrvs;
                    m_vpnSubGroups[g] = gm;
                }
            }
        }
    }
    emit sysStatsChanged();
    runVpnScriptCmd({"toggle_freeze", QString::number(idx), isWl ? "1" : "0"});
}

void WaybarManager::togglePinVpnServer(int idx, bool isWl) {
    if (isWl && idx >= 0 && idx < m_vpnWlServerItems.size()) {
        QVariantMap m = m_vpnWlServerItems[idx].toMap();
        m["pinned"] = !m["pinned"].toBool();
        if (m["pinned"].toBool()) m["frozen"] = false;
        m_vpnWlServerItems[idx] = m;
        emit sysStatsChanged();
    }
    runVpnScriptCmd({"toggle_pin", QString::number(idx), isWl ? "1" : "0"});
}

void WaybarManager::clearFrozenVpnServers() {
    m_vpnFrozenCount = 0;
    for (int i = 0; i < m_vpnWlServerItems.size(); ++i) {
        QVariantMap m = m_vpnWlServerItems[i].toMap();
        if (m["frozen"].toBool()) { m["frozen"] = false; m_vpnWlServerItems[i] = m; }
    }
    for (int i = 0; i < m_vpnSubServerItems.size(); ++i) {
        QVariantMap m = m_vpnSubServerItems[i].toMap();
        if (m["frozen"].toBool()) { m["frozen"] = false; m_vpnSubServerItems[i] = m; }
    }
    for (int g = 0; g < m_vpnSubGroups.size(); ++g) {
        QVariantMap gm = m_vpnSubGroups[g].toMap();
        QVariantList gsrvs = gm["servers"].toList();
        for (int s = 0; s < gsrvs.size(); ++s) {
            QVariantMap sm = gsrvs[s].toMap();
            if (sm["frozen"].toBool()) { sm["frozen"] = false; gsrvs[s] = sm; }
        }
        gm["servers"] = gsrvs;
        m_vpnSubGroups[g] = gm;
    }
    emit sysStatsChanged();
    runVpnScriptCmd({"clear_frozen"});
}

void WaybarManager::checkVpn2ip() {
    m_vpnIpCheckState = 1;
    m_vpnIpCheckText = "Проверка IP и геолокации на 2ip.io...";
    
    emit sysStatsChanged();
    runVpnScriptCmd({"check_2ip"});
}

void WaybarManager::setVpnLogHeight(int v) {
    v = std::clamp(v, 90, 420);
    if (m_vpnLogHeight != v) {
        m_vpnLogHeight = v;
        saveState(false);
        emit vpnLogsChanged();
    }
}

void WaybarManager::setVpnLogMaxLines(int v) {
    v = std::clamp(v, 20, 1000);
    if (m_vpnLogMaxLines != v) {
        m_vpnLogMaxLines = v;
        saveState(false);
        emit vpnLogsChanged();
        refreshVpnLogs();
    }
}

void WaybarManager::setVpnLogAutoRefresh(bool v) {
    if (m_vpnLogAutoRefresh != v) {
        m_vpnLogAutoRefresh = v;
        saveState(false);
        emit vpnLogsChanged();
    }
}

void WaybarManager::setVpnLogAutoScroll(bool v) {
    if (m_vpnLogAutoScroll != v) {
        m_vpnLogAutoScroll = v;
        saveState(false);
        emit vpnLogsChanged();
    }
}

void WaybarManager::setVpnLogLevel(const QString &lvl) {
    if (m_vpnLogLevel != lvl && !lvl.isEmpty()) {
        m_vpnLogLevel = lvl;
        saveState(false);
        emit vpnLogsChanged();
        runVpnScriptCmd({"set_log_level", lvl});
    }
}

void WaybarManager::refreshVpnLogs() {
    QFile f("/tmp/singbox_vpn.log");
    if (!f.exists()) {
        if (m_vpnLogs.isEmpty()) {
            m_vpnLogs = {"Журнал пуст. Включите VPN или запустите проверку серверов."};
            m_vpnLogHtml = m_vpnLogs.first();
            emit vpnLogsChanged();
        }
        return;
    }
    qint64 sz = f.size();
    if (sz == m_lastLogFileSize && m_vpnLogMaxLines == m_lastLogMaxLines && !m_vpnLogs.isEmpty()) {
        return;
    }
    m_lastLogFileSize = sz;
    m_lastLogMaxLines = m_vpnLogMaxLines;

    QStringList nextLogs;
    if (f.open(QIODevice::ReadOnly)) {
        qint64 tailBytes = std::min<qint64>(sz, std::max<qint64>(16384, qint64(m_vpnLogMaxLines) * 140));
        if (sz > tailBytes) f.seek(sz - tailBytes);
        QByteArray raw = f.readAll();
        f.close();

        static const QRegularExpression ansiRe("\x1b\[[0-9;]*m");
        const bool isDebug = (m_vpnLogLevel == "debug");
        const QList<QByteArray> lines = raw.split('\n');
        int startIdx = (sz > tailBytes && lines.size() > 1) ? 1 : 0;
        for (int i = startIdx; i < lines.size(); ++i) {
            const QByteArray &b = lines[i];
            if (b.isEmpty()) continue;
            if (!isDebug) {
                if (b.contains("inbound DNS packet") || b.contains("OPT PSEUDOSECTION") || b.contains("inbound packet connection")) {
                    continue;
                }
            }
            QString ln = QString::fromUtf8(b).trimmed();
            if (ln.isEmpty()) continue;
            ln.remove(ansiRe);
            nextLogs.append(ln);
        }
        if (nextLogs.size() > m_vpnLogMaxLines) {
            nextLogs = nextLogs.mid(nextLogs.size() - m_vpnLogMaxLines);
        }
    }
    if (nextLogs.isEmpty()) {
        nextLogs.append("Журнал пуст. Включите VPN или запустите проверку серверов.");
    }
    if (m_vpnLogs != nextLogs) {
        m_vpnLogs = nextLogs;
        m_vpnLogHtml = nextLogs.join("\n");
        emit vpnLogsChanged();
    }
}

void WaybarManager::clearVpnLogs() {
    QString script = QDir::homePath() + "/hysett/scripts/hysett_vpn.py";
    QProcess *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        p->deleteLater();
        m_lastLogFileSize = -1;
        m_vpnLogs = {"Журнал очищен."};
        m_vpnLogHtml = "Журнал очищен.";
        emit vpnLogsChanged();
    });
    p->start("/usr/bin/python3", {script, "clear_logs"});
}
