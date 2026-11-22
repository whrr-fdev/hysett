#include "LookManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QRegularExpression>
#include <QDateTime>
#include <cstring>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static void sendHyprLuaEval(const QString &luaCode) {
    QString sig = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (sig.isEmpty()) return;
    QString sockPath = qEnvironmentVariable("XDG_RUNTIME_DIR") + "/hypr/" + sig + "/.socket.sock";
    if (!QFile::exists(sockPath)) sockPath = "/tmp/hypr/" + sig + "/.socket.sock";
    int fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return;
    struct sockaddr_un addr {};
    addr.sun_family = AF_UNIX;
    QByteArray pb = sockPath.toUtf8();
    std::strncpy(addr.sun_path, pb.constData(), sizeof(addr.sun_path) - 1);
    if (::connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) == 0) {
        QByteArray b = ("eval " + luaCode).toUtf8();
        ::write(fd, b.constData(), b.size());
        char buf[256];
        ::read(fd, buf, sizeof(buf));
    }
    ::close(fd);
}

LookManager::LookManager(QObject *parent) : QObject(parent) {
    m_saveTimer = new QTimer(this);
    m_saveTimer->setSingleShot(true);
    m_saveTimer->setInterval(40);

    connect(m_saveTimer, &QTimer::timeout, this, [this]() {
        writeLookLua();
    });

    m_opacitySyncTimer = new QTimer(this);
    m_opacitySyncTimer->setSingleShot(true);
    m_opacitySyncTimer->setInterval(75);
    connect(m_opacitySyncTimer, &QTimer::timeout, this, []() {
        QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py", "--opacity"});
    });

    loadFromDisk();

    m_lookWatcher = new QFileSystemWatcher(this);
    QString lookPath = QDir::homePath() + "/.config/hypr/look.lua";
    if (QFile::exists(lookPath)) m_lookWatcher->addPath(lookPath);
    QString hyprDir = QDir::homePath() + "/.config/hypr";
    if (QDir(hyprDir).exists()) m_lookWatcher->addPath(hyprDir);
    auto reloadBorders = [this, lookPath]() {
        if (QDateTime::currentMSecsSinceEpoch() < m_ignoreWatchUntilMs) return;
        if (QFile::exists(lookPath) && !m_lookWatcher->files().contains(lookPath))
            m_lookWatcher->addPath(lookPath);
        QFile rf(lookPath);
        if (!rf.open(QIODevice::ReadOnly | QIODevice::Text)) return;
        QString cur = QString::fromUtf8(rf.readAll());
        rf.close();
        bool changed = false;
        auto ma = QRegularExpression("active_border\\s*=\\s*\"([^\"]+)\"").match(cur);
        auto mi = QRegularExpression("inactive_border\\s*=\\s*\"([^\"]+)\"").match(cur);
        if (ma.hasMatch() && ma.captured(1) != m_activeBorder) { m_activeBorder = ma.captured(1); changed = true; }
        if (mi.hasMatch() && mi.captured(1) != m_inactiveBorder) { m_inactiveBorder = mi.captured(1); changed = true; }
        if (changed) emit lookChanged();
    };
    connect(m_lookWatcher, &QFileSystemWatcher::fileChanged, this, reloadBorders);
    connect(m_lookWatcher, &QFileSystemWatcher::directoryChanged, this, reloadBorders);
}

void LookManager::loadFromDisk() {
    QString path = QDir::homePath() + "/.config/hypr/look.lua";
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QString content = QString::fromUtf8(file.readAll());
    auto parseVal = [&](const QString &pattern, auto &target) {
        QRegularExpression re(pattern);
        auto match = re.match(content);
        if (match.hasMatch()) {
            if constexpr (std::is_same_v<std::decay_t<decltype(target)>, int>) {
                target = match.captured(1).toInt();
            } else if constexpr (std::is_same_v<std::decay_t<decltype(target)>, qreal>) {
                target = match.captured(1).toDouble();
            } else if constexpr (std::is_same_v<std::decay_t<decltype(target)>, bool>) {
                target = (match.captured(1) == "true");
            } else if constexpr (std::is_same_v<std::decay_t<decltype(target)>, QString>) {
                target = match.captured(1);
            }
        }
    };

    parseVal("active_opacity\\s*=\\s*([0-9.]+)", m_activeOpacity);
    parseVal("inactive_opacity\\s*=\\s*([0-9.]+)", m_inactiveOpacity);
    parseVal("bg_only_opacity\\s*=\\s*(true|false)", m_bgOnlyOpacity);
    parseVal("raw_active_opacity\\s*=\\s*([0-9.]+)", m_activeOpacity);
    parseVal("raw_inactive_opacity\\s*=\\s*([0-9.]+)", m_inactiveOpacity);
    parseVal("dim_inactive\\s*=\\s*(true|false)", m_dimInactive);
    parseVal("dim_strength\\s*=\\s*([0-9.]+)", m_dimStrength);
    parseVal("dim_around\\s*=\\s*([0-9.]+)", m_dimAround);
    parseVal("blur\\s*=\\s*\\{[^}]*enabled\\s*=\\s*(true|false)", m_blurEnabled);
    parseVal("blur\\s*=\\s*\\{[^}]*size\\s*=\\s*(\\d+)", m_blurSize);
    parseVal("blur\\s*=\\s*\\{[^}]*passes\\s*=\\s*(\\d+)", m_blurPasses);
    parseVal("blur\\s*=\\s*\\{[^}]*vibrancy\\s*=\\s*([0-9.]+)", m_blurVibrancy);
    parseVal("shadow\\s*=\\s*\\{[^}]*enabled\\s*=\\s*(true|false)", m_shadowEnabled);
    parseVal("shadow\\s*=\\s*\\{[^}]*range\\s*=\\s*(\\d+)", m_shadowRange);
    parseVal("gaps_in\\s*=\\s*(\\d+)", m_gapsIn);
    parseVal("gaps_out\\s*=\\s*(\\d+)", m_gapsOut);
    parseVal("border_size\\s*=\\s*(\\d+)", m_borderSize);
    parseVal("animations\\s*=\\s*\\{[^}]*enabled\\s*=\\s*(true|false)", m_animsEnabled);
    parseVal("single_window_no_border\\s*=\\s*(true|false)", m_noBorderSingleWindow);
    parseVal("active_border_only\\s*=\\s*(true|false)", m_activeBorderOnly);
    parseVal("border_wallpaper_sync\\s*=\\s*(true|false)", m_borderSyncWithWallpaper);
    parseVal("active_border\\s*=\\s*\"([^\"]+)\"", m_activeBorder);
    parseVal("inactive_border\\s*=\\s*\"([^\"]+)\"", m_inactiveBorder);
}

void LookManager::applyKeyword(const QString &key, const QString &val) {
    if (key == "general:col.active_border") {
        sendHyprLuaEval(QString("hl.config({ general = { col = { active_border = \"%1\" } } })").arg(val));
    } else if (key == "general:col.inactive_border") {
        sendHyprLuaEval(QString("hl.config({ general = { col = { inactive_border = \"%1\" } } })").arg(val));
    } else if (key == "general:border_size") {
        sendHyprLuaEval(QString("hl.config({ general = { border_size = %1 } })").arg(val));
    } else if (key == "general:gaps_in") {
        sendHyprLuaEval(QString("hl.config({ general = { gaps_in = %1 } })").arg(val));
    } else if (key == "general:gaps_out") {
        sendHyprLuaEval(QString("hl.config({ general = { gaps_out = %1 } })").arg(val));
    } else if (key == "decoration:active_opacity") {
        sendHyprLuaEval(QString("hl.config({ decoration = { active_opacity = %1 } })").arg(val));
    } else if (key == "decoration:inactive_opacity") {
        sendHyprLuaEval(QString("hl.config({ decoration = { inactive_opacity = %1 } })").arg(val));
    } else if (key == "decoration:dim_inactive") {
        sendHyprLuaEval(QString("hl.config({ decoration = { dim_inactive = %1 } })").arg(val));
    } else if (key == "decoration:dim_strength") {
        sendHyprLuaEval(QString("hl.config({ decoration = { dim_strength = %1 } })").arg(val));
    } else if (key == "decoration:blur:enabled") {
        sendHyprLuaEval(QString("hl.config({ decoration = { blur = { enabled = %1 } } })").arg(val));
    } else if (key == "decoration:blur:size") {
        sendHyprLuaEval(QString("hl.config({ decoration = { blur = { size = %1 } } })").arg(val));
    } else if (key == "decoration:blur:passes") {
        sendHyprLuaEval(QString("hl.config({ decoration = { blur = { passes = %1 } } })").arg(val));
    } else if (key == "decoration:blur:vibrancy") {
        sendHyprLuaEval(QString("hl.config({ decoration = { blur = { vibrancy = %1 } } })").arg(val));
    } else if (key == "decoration:shadow:enabled") {
        sendHyprLuaEval(QString("hl.config({ decoration = { shadow = { enabled = %1 } } })").arg(val));
    } else if (key == "decoration:shadow:range") {
        sendHyprLuaEval(QString("hl.config({ decoration = { shadow = { range = %1 } } })").arg(val));
    } else if (key == "animations:enabled") {
        sendHyprLuaEval(QString("hl.config({ animations = { enabled = %1 } })").arg(val));
    }
}

void LookManager::applyCurrentBlur() {
    sendHyprLuaEval(QString("hl.config({ decoration = { blur = { enabled = %1, size = %2, passes = %3, vibrancy = %4 } } })")
                        .arg(m_blurEnabled ? "true" : "false")
                        .arg(m_blurSize)
                        .arg(m_blurPasses)
                        .arg(QString::number(m_blurVibrancy, 'f', 2)));
}

void LookManager::scheduleSaveAndApply() {
    m_saveTimer->start();
    emit lookChanged();
}

void LookManager::pushBackup() {
    Snapshot s{
        m_activeOpacity, m_inactiveOpacity, m_dimInactive, m_dimStrength, m_dimAround,
        m_blurEnabled, m_blurSize, m_blurPasses, m_blurVibrancy,
        m_shadowEnabled, m_shadowRange,
        m_gapsIn, m_gapsOut, m_borderSize, m_animsEnabled,
        m_activeBorder, m_inactiveBorder
    };
    m_history.push_back(s);
    if (m_history.size() > 25) m_history.removeFirst();
    emit backupCountChanged();
}

void LookManager::undo() {
    if (m_history.isEmpty()) return;
    Snapshot s = m_history.takeLast();
    m_activeOpacity = s.activeOpacity;
    m_inactiveOpacity = s.inactiveOpacity;
    m_dimInactive = s.dimInactive;
    m_dimStrength = s.dimStrength;
    m_dimAround = s.dimAround;
    m_blurEnabled = s.blurEnabled;
    m_blurSize = s.blurSize;
    m_blurPasses = s.blurPasses;
    m_blurVibrancy = s.blurVibrancy;
    m_shadowEnabled = s.shadowEnabled;
    m_shadowRange = s.shadowRange;
    m_gapsIn = s.gapsIn;
    m_gapsOut = s.gapsOut;
    m_borderSize = s.borderSize;
    m_animsEnabled = s.animsEnabled;
    m_activeBorder = s.activeBorder;
    m_inactiveBorder = s.inactiveBorder;

    applyKeyword("decoration:active_opacity", QString::number(m_activeOpacity, 'f', 2));
    applyKeyword("decoration:inactive_opacity", QString::number(m_inactiveOpacity, 'f', 2));
    applyKeyword("decoration:dim_inactive", m_dimInactive ? "true" : "false");
    applyKeyword("decoration:dim_strength", QString::number(m_dimStrength, 'f', 2));
    applyKeyword("decoration:blur:enabled", m_blurEnabled ? "true" : "false");
    applyKeyword("decoration:blur:size", QString::number(m_blurSize));
    applyKeyword("decoration:blur:passes", QString::number(m_blurPasses));
    applyKeyword("decoration:blur:vibrancy", QString::number(m_blurVibrancy, 'f', 2));
    applyKeyword("decoration:shadow:enabled", m_shadowEnabled ? "true" : "false");
    applyKeyword("decoration:shadow:range", QString::number(m_shadowRange));
    applyKeyword("general:gaps_in", QString::number(m_gapsIn));
    applyKeyword("general:gaps_out", QString::number(m_gapsOut));
    applyKeyword("general:border_size", QString::number(m_borderSize));
    applyKeyword("animations:enabled", m_animsEnabled ? "true" : "false");
    applyKeyword("general:col.active_border", m_activeBorder);
    applyKeyword("general:col.inactive_border", m_inactiveBorder);

    writeLookLua();
    emit lookChanged();
    emit backupCountChanged();
}

void LookManager::resetToDefaults() {
    pushBackup();
    setActiveOpacity(0.85);
    setInactiveOpacity(0.75);
    setDimInactive(false);
    setDimStrength(0.75);
    setDimAround(0.40);
    setBlurEnabled(true);
    setBlurSize(6);
    setBlurPasses(3);
    setBlurVibrancy(0.50);
    setShadowEnabled(true);
    setShadowRange(4);
    setGapsIn(3);
    setGapsOut(10);
    setBorderSize(1);
    setAnimsEnabled(true);
    setActiveBorder("rgba(ccccccff)");
    setInactiveBorder("rgba(767676cc)");
}

void LookManager::writeLookLua() {
    QString path = QDir::homePath() + "/.config/hypr/look.lua";
    if (m_borderSyncWithWallpaper) {
        QFile rf(path);
        if (rf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString cur = QString::fromUtf8(rf.readAll());
            rf.close();
            auto ma = QRegularExpression("active_border\\s*=\\s*\"([^\"]+)\"").match(cur);
            auto mi = QRegularExpression("inactive_border\\s*=\\s*\"([^\"]+)\"").match(cur);
            if (ma.hasMatch()) m_activeBorder = ma.captured(1);
            if (mi.hasMatch()) m_inactiveBorder = mi.captured(1);
        }
    }
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return;

    QTextStream out(&file);
    auto effOp = [&](qreal raw) {
        if (!m_bgOnlyOpacity) return std::clamp(raw, 0.10, 1.00);
        return (raw >= 0.99) ? 1.00 : std::clamp(0.45 + raw * 0.55, 0.45, 1.00);
    };
    qreal effAct = effOp(m_activeOpacity);
    qreal effInact = effOp(m_inactiveOpacity);

    out << "-- Auto-generated by HySett Control Center\n";
    out << "-- single_window_no_border = " << (m_noBorderSingleWindow ? "true" : "false") << "\n";
    out << "-- active_border_only = " << (m_activeBorderOnly ? "true" : "false") << "\n";
    out << "-- border_wallpaper_sync = " << (m_borderSyncWithWallpaper ? "true" : "false") << "\n";
    out << "-- bg_only_opacity = " << (m_bgOnlyOpacity ? "true" : "false") << "\n";
    out << "-- raw_active_opacity = " << QString::number(m_activeOpacity, 'f', 2) << "\n";
    out << "-- raw_inactive_opacity = " << QString::number(m_inactiveOpacity, 'f', 2) << "\n";
    out << "hl.config({\n";
    out << "    general = {\n";
    out << "        gaps_in  = " << m_gapsIn << ",\n";
    out << "        gaps_out = " << m_gapsOut << ",\n";
    out << "        border_size = " << m_borderSize << ",\n";
    out << "        col = {\n";
    out << "            active_border = \"" << m_activeBorder << "\",\n";
    out << "            inactive_border = \"" << (m_activeBorderOnly ? QString("rgba(00000000)") : m_inactiveBorder) << "\",\n";
    out << "        },\n";
    out << "    },\n";
    int curRounding = 12;
    QFile tf(QDir::homePath() + "/.config/hypr/scripts/theme_state.conf");
    if (tf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (QString::fromUtf8(tf.readAll()).trimmed() == "square") curRounding = 0;
        tf.close();
    }
    out << "    decoration = {\n";
    out << "        rounding         = " << curRounding << ",\n";
    out << "        rounding_power   = 2,\n";
    out << "        active_opacity   = " << QString::number(effAct, 'f', 2) << ",\n";
    out << "        inactive_opacity = " << QString::number(effInact, 'f', 2) << ",\n";
    out << "        dim_inactive     = " << (m_dimInactive ? "true" : "false") << ",\n";
    out << "        dim_strength     = " << QString::number(m_dimStrength, 'f', 2) << ",\n";
    out << "        shadow = {\n";
    out << "            enabled = " << (m_shadowEnabled ? "true" : "false") << ",\n";
    out << "            range   = " << m_shadowRange << ",\n";
    out << "        },\n";
    out << "        blur = {\n";
    out << "            enabled        = " << (m_blurEnabled ? "true" : "false") << ",\n";
    out << "            size           = " << m_blurSize << ",\n";
    out << "            passes         = " << m_blurPasses << ",\n";
    out << "            vibrancy       = " << QString::number(m_blurVibrancy, 'f', 2) << ",\n";
    out << "            ignore_opacity = true,\n";
    out << "        },\n";
    out << "    },\n";
    out << "    animations = {\n";
    out << "        enabled = " << (m_animsEnabled ? "true" : "false") << ",\n";
    out << "    },\n";
    out << "})\n";
    out << "hl.window_rule({\n";
    out << "    name        = \"no-gaps-wtv1\",\n";
    out << "    match       = { float = false, workspace = \"w[tv1]\" },\n";
    out << "    border_size = " << (m_noBorderSingleWindow ? 0 : m_borderSize) << ",\n";
    out << "})\n";
    QString bgOpRule = m_bgOnlyOpacity
        ? QString("0.999 override 0.999 override")
        : QString("%1 override %2 override").arg(effAct, 0, 'f', 2).arg(effInact, 0, 'f', 2);
    out << "hl.window_rule({\n";
    out << "    name    = \"hysett-bg-only-opacity\",\n";
    out << "    match   = { class = \"^(kitty|waybar-btop|neovide|dev\\\\.zed\\\\.Zed|.*zed.*|org\\\\.gnome\\\\..*|.*nautilus.*|org\\\\.pulseaudio\\\\.pavucontrol|blueman-manager|nm-connection-editor|xdg-desktop-portal-gtk)$\" },\n";
    out << "    opacity = \"" << bgOpRule << "\",\n";
    out << "})\n";
    m_ignoreWatchUntilMs = QDateTime::currentMSecsSinceEpoch() + 250;
    file.flush();
    file.close();
    sendHyprLuaEval("dofile(os.getenv(\"HOME\") .. \"/.config/hypr/look.lua\")");
}

void LookManager::setActiveOpacity(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (!qFuzzyCompare(m_activeOpacity, v)) {
        pushBackup();
        m_activeOpacity = v;
        qreal eff = m_bgOnlyOpacity ? ((v >= 0.99) ? 1.00 : std::clamp(0.45 + v * 0.55, 0.45, 1.00)) : std::clamp(v, 0.10, 1.00);
        applyKeyword("decoration:active_opacity", QString::number(eff, 'f', 2));
        scheduleSaveAndApply();
        if (m_opacitySyncTimer) m_opacitySyncTimer->start();
    }
}
void LookManager::setInactiveOpacity(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (!qFuzzyCompare(m_inactiveOpacity, v)) {
        pushBackup();
        m_inactiveOpacity = v;
        qreal eff = m_bgOnlyOpacity ? ((v >= 0.99) ? 1.00 : std::clamp(0.45 + v * 0.55, 0.45, 1.00)) : std::clamp(v, 0.10, 1.00);
        applyKeyword("decoration:inactive_opacity", QString::number(eff, 'f', 2));
        scheduleSaveAndApply();
        if (m_opacitySyncTimer) m_opacitySyncTimer->start();
    }
}
void LookManager::setBgOnlyOpacity(bool v) {
    if (m_bgOnlyOpacity != v) {
        m_bgOnlyOpacity = v;
        qreal effA = m_bgOnlyOpacity ? ((m_activeOpacity >= 0.99) ? 1.00 : std::clamp(0.45 + m_activeOpacity * 0.55, 0.45, 1.00)) : std::clamp(m_activeOpacity, 0.10, 1.00);
        qreal effI = m_bgOnlyOpacity ? ((m_inactiveOpacity >= 0.99) ? 1.00 : std::clamp(0.45 + m_inactiveOpacity * 0.55, 0.45, 1.00)) : std::clamp(m_inactiveOpacity, 0.10, 1.00);
        applyKeyword("decoration:active_opacity", QString::number(effA, 'f', 2));
        applyKeyword("decoration:inactive_opacity", QString::number(effI, 'f', 2));
        scheduleSaveAndApply();
        if (m_opacitySyncTimer) m_opacitySyncTimer->start();
    }
}
void LookManager::setDimInactive(bool v) { if (m_dimInactive != v) { pushBackup(); m_dimInactive = v; applyKeyword("decoration:dim_inactive", v ? "true" : "false"); scheduleSaveAndApply(); } }
void LookManager::setDimStrength(qreal v) { if (!qFuzzyCompare(m_dimStrength, v)) { pushBackup(); m_dimStrength = v; applyKeyword("decoration:dim_strength", QString::number(v, 'f', 2)); scheduleSaveAndApply(); } }
void LookManager::setDimAround(qreal v) { if (!qFuzzyCompare(m_dimAround, v)) { pushBackup(); m_dimAround = v; scheduleSaveAndApply(); } }
void LookManager::setBlurEnabled(bool v) { if (m_blurEnabled != v) { pushBackup(); m_blurEnabled = v; applyKeyword("decoration:blur:enabled", v ? "true" : "false"); scheduleSaveAndApply(); } }
void LookManager::setBlurSize(int v) { if (m_blurSize != v) { pushBackup(); m_blurSize = v; applyKeyword("decoration:blur:size", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setBlurPasses(int v) { if (m_blurPasses != v) { pushBackup(); m_blurPasses = v; applyKeyword("decoration:blur:passes", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setBlurVibrancy(qreal v) { if (!qFuzzyCompare(m_blurVibrancy, v)) { pushBackup(); m_blurVibrancy = v; applyKeyword("decoration:blur:vibrancy", QString::number(v, 'f', 2)); scheduleSaveAndApply(); } }
void LookManager::setShadowEnabled(bool v) { if (m_shadowEnabled != v) { pushBackup(); m_shadowEnabled = v; applyKeyword("decoration:shadow:enabled", v ? "true" : "false"); scheduleSaveAndApply(); } }
void LookManager::setShadowRange(int v) { if (m_shadowRange != v) { pushBackup(); m_shadowRange = v; applyKeyword("decoration:shadow:range", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setGapsIn(int v) { if (m_gapsIn != v) { pushBackup(); m_gapsIn = v; applyKeyword("general:gaps_in", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setGapsOut(int v) { if (m_gapsOut != v) { pushBackup(); m_gapsOut = v; applyKeyword("general:gaps_out", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setBorderSize(int v) { if (m_borderSize != v) { pushBackup(); m_borderSize = v; applyKeyword("general:border_size", QString::number(v)); scheduleSaveAndApply(); } }
void LookManager::setAnimsEnabled(bool v) { if (m_animsEnabled != v) { pushBackup(); m_animsEnabled = v; applyKeyword("animations:enabled", v ? "true" : "false"); scheduleSaveAndApply(); } }
void LookManager::setActiveBorder(const QString &v) { if (m_activeBorder != v) { m_activeBorder = v; applyKeyword("general:col.active_border", v); scheduleSaveAndApply(); } }
void LookManager::setInactiveBorder(const QString &v) { if (m_inactiveBorder != v) { m_inactiveBorder = v; applyKeyword("general:col.inactive_border", v); scheduleSaveAndApply(); } }
void LookManager::setBorderSyncWithWallpaper(bool v) {
    if (m_borderSyncWithWallpaper != v) {
        m_borderSyncWithWallpaper = v;
        if (v) {
            QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py"});
            QTimer::singleShot(250, this, [this]() {
                loadFromDisk();
                emit lookChanged();
            });
        } else {
            applyKeyword("general:col.active_border", m_activeBorder);
            applyKeyword("general:col.inactive_border", m_inactiveBorder);
        }
        scheduleSaveAndApply();
    }
}
void LookManager::setNoBorderSingleWindow(bool v) {
    if (m_noBorderSingleWindow != v) {
        pushBackup();
        m_noBorderSingleWindow = v;
        sendHyprLuaEval(QString("hl.window_rule({ name = \"no-gaps-wtv1\", match = { float = false, workspace = \"w[tv1]\" }, border_size = %1 })").arg(v ? 0 : m_borderSize));
        scheduleSaveAndApply();
    }
}

void LookManager::setActiveBorderOnly(bool v) {
    if (m_activeBorderOnly != v) {
        m_activeBorderOnly = v;
        scheduleSaveAndApply();
        QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py"});
    }
}
