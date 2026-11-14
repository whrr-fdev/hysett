#include <QFileSystemWatcher>
#include "WidgetsManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <algorithm>

static QTimer *s_kbRestartTimer = nullptr;
static QTimer *s_clockRestartTimer = nullptr;
static QTimer *s_sysRestartTimer = nullptr;

WidgetsManager::WidgetsManager(QObject *parent) : QObject(parent) {
    QDir().mkpath(QDir::homePath() + "/.config/hypr/scripts");
    loadKbConfig();
    {
        QFile ccf(QDir::homePath() + "/.config/hypr/scripts/control_center.conf");
        if (ccf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            for (const QByteArray &ln : ccf.readAll().split('\n')) {
                if (ln.trimmed().startsWith("widgets_m3_sync=")) {
                    QByteArray v = ln.trimmed().mid(16).trimmed();
                    m_widgetsM3Sync = (v == "1" || v == "true");
                } else if (ln.trimmed().startsWith("clock_m3_sync=")) {
                    QByteArray v = ln.trimmed().mid(14).trimmed();
                    m_clockM3Sync = (v == "1" || v == "true");
                }
            }
            ccf.close();
        }
    }
    loadClockConfig();
    loadSysConfig();

    s_kbRestartTimer = new QTimer(this);
    s_kbRestartTimer->setSingleShot(true);
    s_kbRestartTimer->setInterval(250);
    connect(s_kbRestartTimer, &QTimer::timeout, this, [this]() {
        if (m_kbRunning) restartKbProcess();
    });

    s_clockRestartTimer = new QTimer(this);
    s_clockRestartTimer->setSingleShot(true);
    s_clockRestartTimer->setInterval(250);
    connect(s_clockRestartTimer, &QTimer::timeout, this, [this]() {
        if (m_clockRunning) restartClockProcess();
    });

    s_sysRestartTimer = new QTimer(this);
    s_sysRestartTimer->setSingleShot(true);
    s_sysRestartTimer->setInterval(250);
    connect(s_sysRestartTimer, &QTimer::timeout, this, [this]() {
        if (m_sysRunning) restartSysProcess();
    });

    auto readEnabledConf = [](const QString &name) -> int {
        QFile f(QDir::homePath() + "/.config/hypr/scripts/" + name);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString val = QString::fromUtf8(f.readAll()).trimmed();
            if (val == "1" || val == "true") return 1;
            if (val == "0" || val == "false") return 0;
        }
        return -1;
    };

    QProcess p1;
    p1.start("pgrep", {"-f", "kb_overlay.py"});
    p1.waitForFinished();
    m_kbRunning = !p1.readAllStandardOutput().trimmed().isEmpty();
    if (!m_kbRunning && readEnabledConf("kb.conf") == 1) {
        QTimer::singleShot(600, this, [this]() { toggleKbProcess(true); });
    }

    QProcess p2;
    p2.start("pgrep", {"-x", "clock_overlay"});
    p2.waitForFinished();
    m_clockRunning = !p2.readAllStandardOutput().trimmed().isEmpty();
    if (!m_clockRunning && readEnabledConf("clock.conf") == 1) {
        QTimer::singleShot(650, this, [this]() { toggleClockProcess(true); });
    }

    QProcess p3;
    p3.start("pgrep", {"-f", "sysinfo_overlay"});
    p3.waitForFinished();
    m_sysRunning = !p3.readAllStandardOutput().trimmed().isEmpty();
    if (!m_sysRunning && readEnabledConf("sysinfo.conf") == 1) {
        QTimer::singleShot(700, this, [this]() { toggleSysProcess(true); });
    }

    auto * stateWatcher = new QFileSystemWatcher(this);
    stateWatcher->addPath(QDir::homePath() + "/.config/hypr/scripts");
    connect(stateWatcher, &QFileSystemWatcher::directoryChanged, this, [this, readEnabledConf]() {
        int kbSt = readEnabledConf("kb.conf");
        if (kbSt != -1 && m_kbRunning != (kbSt == 1)) {
            m_kbRunning = (kbSt == 1);
            emit kbChanged();
        }
        int sysSt = readEnabledConf("sysinfo.conf");
        if (sysSt != -1 && m_sysRunning != (sysSt == 1)) {
            m_sysRunning = (sysSt == 1);
            emit sysStateChanged();
        }
    });
}

void WidgetsManager::loadKbConfig() {
    QString p = QDir::homePath() + "/.config/hypr/scripts/kb_overlay_config.json";
    QFile f(p);
    if (f.open(QIODevice::ReadOnly)) {
        auto doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isObject()) {
            auto obj = doc.object();
            if (obj.contains("show_keyboard")) m_kbShowKeyboard = obj["show_keyboard"].toBool();
            if (obj.contains("show_mouse")) m_kbShowMouse = obj["show_mouse"].toBool();
            if (obj.contains("show_mouse_side")) m_kbShowSide = obj["show_mouse_side"].toBool();
            if (obj.contains("show_mouse_wheel")) m_kbShowWheel = obj["show_mouse_wheel"].toBool();
            if (obj.contains("only_combos")) m_kbOnlyCombos = obj["only_combos"].toBool();
            if (obj.contains("position") && !obj["position"].toString().isEmpty()) m_kbPosition = obj["position"].toString();
        }
    }
}

void WidgetsManager::saveKbConfig() {
    QDir().mkpath(QDir::homePath() + "/.config/hypr/scripts");
    QString p = QDir::homePath() + "/.config/hypr/scripts/kb_overlay_config.json";
    QJsonObject obj;
    QFile f(p);
    if (f.open(QIODevice::ReadOnly)) {
        obj = QJsonDocument::fromJson(f.readAll()).object();
        f.close();
    }
    obj["show_keyboard"] = m_kbShowKeyboard;
    obj["show_mouse"] = m_kbShowMouse;
    obj["show_mouse_side"] = m_kbShowSide;
    obj["show_mouse_wheel"] = m_kbShowWheel;
    obj["only_combos"] = m_kbOnlyCombos;
    obj["position"] = m_kbPosition;

    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(QJsonDocument(obj).toJson());
        f.close();
    }
    emit kbChanged();
    if (m_kbRunning && s_kbRestartTimer) s_kbRestartTimer->start();
}

void WidgetsManager::setKbShowKeyboard(bool v) { if (m_kbShowKeyboard != v) { m_kbShowKeyboard = v; saveKbConfig(); } }
void WidgetsManager::setKbShowMouse(bool v) { if (m_kbShowMouse != v) { m_kbShowMouse = v; saveKbConfig(); } }
void WidgetsManager::setKbShowSide(bool v) { if (m_kbShowSide != v) { m_kbShowSide = v; saveKbConfig(); } }
void WidgetsManager::setKbShowWheel(bool v) { if (m_kbShowWheel != v) { m_kbShowWheel = v; saveKbConfig(); } }
void WidgetsManager::setKbOnlyCombos(bool v) { if (m_kbOnlyCombos != v) { m_kbOnlyCombos = v; saveKbConfig(); } }
void WidgetsManager::setKbPosition(const QString &v) { if (m_kbPosition != v && !v.isEmpty()) { m_kbPosition = v; saveKbConfig(); } }

void WidgetsManager::toggleKbProcess(bool start) {
    m_kbRunning = start;
    QString home = QDir::homePath();
    QFile cf(home + "/.config/hypr/scripts/kb.conf");
    if (cf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream(&cf) << (start ? "1" : "0") << "\n";
        cf.close();
    }
    if (start) {
        saveKbConfig();
        if (s_kbRestartTimer) s_kbRestartTimer->stop();
        QProcess::execute("pkill", {"-f", "kb_overlay.py"});
        QString kbPy = QFile::exists(home + "/hysett/scripts/kb_overlay.py") ? (home + "/hysett/scripts/kb_overlay.py") : (home + "/.config/hypr/scripts/kb_overlay.py");
        QProcess::startDetached("python3", {kbPy, m_kbPosition});
    } else {
        QProcess::startDetached("pkill", {"-f", "kb_overlay.py"});
    }
    emit kbChanged();
}

void WidgetsManager::toggleKbVisibility() {
    QProcess::startDetached("pkill", {"-SIGUSR1", "-f", "kb_overlay.py"});
}

void WidgetsManager::restartKbProcess() {
    QProcess::execute("pkill", {"-f", "kb_overlay.py"});
    toggleKbProcess(true);
}

void WidgetsManager::loadClockConfig() {
    QString p = QDir::homePath() + "/.config/hypr/scripts/clock_style.conf";
    QFile f(p);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            int eq = line.indexOf('=');
            if (eq == -1) continue;
            QString k = line.left(eq).trimmed();
            QString v = line.mid(eq + 1).trimmed();
            if (k == "size") m_clockSize = std::clamp(v.toInt(), 24, 140);
            else if (k == "opacity") m_clockOpacity = std::clamp(v.toDouble(), 0.1, 1.0);
            else if (k == "is_24h") m_clock24h = (v == "1" || v == "true");
            else if (k == "show_seconds") m_clockShowSeconds = (v == "1" || v == "true");
            else if (k == "show_date") m_clockShowDate = (v == "1" || v == "true");
            else if (k == "show_weekday") m_clockShowWeekday = (v == "1" || v == "true");
        }
    }
}

void WidgetsManager::saveClockConfig() {
    QDir().mkpath(QDir::homePath() + "/.config/hypr/scripts");
    QString p = QDir::homePath() + "/.config/hypr/scripts/clock_style.conf";
    QMap<QString, QString> kv;
    QFile rf(p);
    if (rf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&rf);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            int eq = line.indexOf('=');
            if (eq != -1) kv[line.left(eq).trimmed()] = line.mid(eq + 1).trimmed();
        }
        rf.close();
    }
    kv["size"] = QString::number(m_clockSize);
    kv["opacity"] = QString::number(m_clockOpacity, 'f', 2);
    kv["is_24h"] = m_clock24h ? "1" : "0";
    kv["show_seconds"] = m_clockShowSeconds ? "1" : "0";
    kv["show_date"] = m_clockShowDate ? "1" : "0";
    kv["show_weekday"] = m_clockShowWeekday ? "1" : "0";

    QFile f(p);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&f);
        for (auto it = kv.begin(); it != kv.end(); ++it) {
            out << it.key() << "=" << it.value() << "\n";
        }
        f.close();
    }
}

void WidgetsManager::setClock24h(bool v) { if (m_clock24h != v) { m_clock24h = v; saveClockConfig(); emit clockChanged(); } }
void WidgetsManager::setClockShowSeconds(bool v) { if (m_clockShowSeconds != v) { m_clockShowSeconds = v; saveClockConfig(); emit clockChanged(); } }
void WidgetsManager::setClockShowDate(bool v) { if (m_clockShowDate != v) { m_clockShowDate = v; saveClockConfig(); emit clockChanged(); } }
void WidgetsManager::setClockShowWeekday(bool v) { if (m_clockShowWeekday != v) { m_clockShowWeekday = v; saveClockConfig(); emit clockChanged(); } }
void WidgetsManager::setClockSize(int v) { v = std::clamp(v, 24, 140); if (m_clockSize != v) { m_clockSize = v; saveClockConfig(); emit clockChanged(); } }
void WidgetsManager::setClockOpacity(qreal v) { v = std::clamp(v, 0.1, 1.0); if (!qFuzzyCompare(m_clockOpacity, v)) { m_clockOpacity = v; saveClockConfig(); emit clockChanged(); } }

void WidgetsManager::saveClock() {
    saveClockConfig();
    if (m_clockRunning) restartClockProcess();
}

void WidgetsManager::toggleClockProcess(bool start) {
    m_clockRunning = start;
    QString home = QDir::homePath();
    QFile f(home + "/.config/hypr/scripts/clock.conf");
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream(&f) << (start ? "1" : "0") << "\n";
        f.close();
    }

    if (start) {
        saveClockConfig();
        if (s_clockRestartTimer) s_clockRestartTimer->stop();
        QProcess::execute("pkill", {"-x", "clock_overlay"});
        QStringList clockCands = {
            home + "/hysett/bin/clock_overlay",
            home + "/hysett/widgets/clock_overlay/target/release/clock_overlay",
            home + "/clock_overlay/target/release/clock_overlay"
        };
        QString bin = clockCands.first();
        for (const QString &c : clockCands) { if (QFile::exists(c)) { bin = c; break; } }
        QProcess::startDetached(bin, {});
    } else {
        QProcess::startDetached("pkill", {"-x", "clock_overlay"});
    }
    emit clockChanged();
}

void WidgetsManager::restartClockProcess() {
    QProcess::execute("pkill", {"-x", "clock_overlay"});
    toggleClockProcess(true);
}

void WidgetsManager::launchPeaclock() {
    QProcess::startDetached("foot", {"-a", "peaclok-clock", "-e", "peaclock"});
}

void WidgetsManager::launchFastfetch() {
    QProcess::startDetached("foot", {"-a", "fastfetch-widget", "-W", "50x8", "-e", "sh", "-c", "fastfetch; sleep infinity"});
}

void WidgetsManager::launchBtop() {
    QProcess::startDetached("kitty", {"--class", "waybar-btop", "-e", "btop"});
}

QString WidgetsManager::findSysBinary() const {
    QStringList candidates = {
        QDir::homePath() + "/hysett/bin/sysinfo_overlay",
        QDir::homePath() + "/hysett/widgets/sysinfo/target/release/sysinfo_overlay",
        QDir::homePath() + "/sysinfo/target/release/sysinfo_overlay",
        QDir::homePath() + "/.config/hypr/scripts/sysinfo_overlay",
        QDir::homePath() + "/.local/bin/sysinfo_overlay"
    };
    for (const QString &c : candidates) {
        if (QFile::exists(c)) return c;
    }
    return "sysinfo_overlay";
}

void WidgetsManager::loadSysConfig() {
    QFile f(QDir::homePath() + "/.config/hypr/scripts/sysinfo_style.conf");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        int eq = line.indexOf('=');
        if (line.isEmpty() || line.startsWith('#') || eq == -1) continue;
        QString k = line.left(eq).trimmed(), v = line.mid(eq + 1).trimmed();
        auto pb = [](const QString &s) { return s == "1" || s.compare("true", Qt::CaseInsensitive) == 0 || s == "yes"; };
        if (k == "show_cpu") m_sysShowCpu = pb(v);
        else if (k == "show_ram") m_sysShowRam = pb(v);
        else if (k == "show_net") m_sysShowNet = pb(v);
        else if (k == "show_temp") m_sysShowTemp = pb(v);
        else if (k == "show_extra") m_sysShowExtra = pb(v);
        else if (k == "show_procs") m_sysShowProcs = pb(v);
        else if (k == "proc_sort" && !v.isEmpty()) m_sysProcSort = v;
        else if (k == "proc_count") m_sysProcCount = std::clamp(v.toInt(), 1, 20);
        else if (k == "top_layer") m_sysTopLayer = pb(v);
        else if (k == "text_color" && !v.isEmpty()) m_sysTextColor = v;
        else if (k == "graph_color" && !v.isEmpty()) m_sysGraphColor = v;
        else if (k == "opacity") m_sysOpacity = std::clamp(v.toDouble(), 0.1, 1.0);
        else if (k == "scale") m_sysScale = std::clamp(v.toDouble(), 0.4, 2.5);
        else if (k == "title_size") m_sysTitleSize = std::clamp(qRound(v.toDouble()), 6, 36);
        else if (k == "extra_size") m_sysExtraSize = std::clamp(qRound(v.toDouble()), 6, 36);
        else if (k == "margin_x") m_sysMarginX = qRound(v.toDouble());
        else if (k == "margin_y") m_sysMarginY = qRound(v.toDouble());
        else if (k == "position" && !v.isEmpty()) m_sysPosition = v;
    }
}

void WidgetsManager::saveSysConfig() {
    QDir().mkpath(QDir::homePath() + "/.config/hypr/scripts");
    QFile f(QDir::homePath() + "/.config/hypr/scripts/sysinfo_style.conf");
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&f);
        out << "show_cpu=" << (m_sysShowCpu ? "true" : "false") << "\n"
            << "show_ram=" << (m_sysShowRam ? "true" : "false") << "\n"
            << "show_net=" << (m_sysShowNet ? "true" : "false") << "\n"
            << "show_temp=" << (m_sysShowTemp ? "true" : "false") << "\n"
            << "show_extra=" << (m_sysShowExtra ? "true" : "false") << "\n"
            << "show_procs=" << (m_sysShowProcs ? "true" : "false") << "\n"
            << "proc_sort=" << m_sysProcSort << "\n"
            << "proc_count=" << m_sysProcCount << "\n"
            << "top_layer=" << (m_sysTopLayer ? "true" : "false") << "\n"
            << "text_color=" << m_sysTextColor << "\n"
            << "graph_color=" << m_sysGraphColor << "\n"
            << "opacity=" << QString::number(m_sysOpacity, 'f', 2) << "\n"
            << "scale=" << QString::number(m_sysScale, 'f', 2) << "\n"
            << "title_size=" << m_sysTitleSize << "\n"
            << "extra_size=" << m_sysExtraSize << "\n"
            << "margin_x=" << m_sysMarginX << "\n"
            << "margin_y=" << m_sysMarginY << "\n"
            << "position=" << m_sysPosition << "\n";
        f.close();
    }
    emit sysStateChanged();
    // sysinfo_overlay подхватывает конфиг на лету каждые 80 мс без перезапуска процесса
}

void WidgetsManager::toggleSysProcess(bool run) {
    m_sysRunning = run;
    QFile cf(QDir::homePath() + "/.config/hypr/scripts/sysinfo.conf");
    if (cf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream(&cf) << (run ? "1" : "0") << "\n";
        cf.close();
    }
    if (run) {
        saveSysConfig();
        if (s_sysRestartTimer) s_sysRestartTimer->stop();
        QProcess::execute("pkill", {"-f", "sysinfo_overlay"});
        QProcess::startDetached(findSysBinary(), {});
    } else {
        QProcess::execute("pkill", {"-f", "sysinfo_overlay"});
    }
    emit sysStateChanged();
}

void WidgetsManager::restartSysProcess() {
    toggleSysProcess(true);
}

void WidgetsManager::resetSysDefaults() {
    m_sysShowCpu = m_sysShowRam = m_sysShowNet = m_sysShowTemp = m_sysShowExtra = m_sysShowProcs = m_sysTopLayer = true;
    m_sysProcSort = "cpu";
    m_sysProcCount = 10;
    m_sysTextColor = "#ffffff"; m_sysGraphColor = "#ffffff";
    m_sysOpacity = 0.85; m_sysScale = 1.0;
    m_sysTitleSize = 13; m_sysExtraSize = 14;
    m_sysMarginX = 24; m_sysMarginY = 44;
    m_sysPosition = "top-right";
    saveSysConfig();
}

void WidgetsManager::setSysShowCpu(bool v) { if (m_sysShowCpu != v) { m_sysShowCpu = v; saveSysConfig(); } }
void WidgetsManager::setSysShowRam(bool v) { if (m_sysShowRam != v) { m_sysShowRam = v; saveSysConfig(); } }
void WidgetsManager::setSysShowNet(bool v) { if (m_sysShowNet != v) { m_sysShowNet = v; saveSysConfig(); } }
void WidgetsManager::setSysShowTemp(bool v) { if (m_sysShowTemp != v) { m_sysShowTemp = v; saveSysConfig(); } }
void WidgetsManager::setSysShowExtra(bool v) { if (m_sysShowExtra != v) { m_sysShowExtra = v; saveSysConfig(); } }
void WidgetsManager::setSysTopLayer(bool v) { if (m_sysTopLayer != v) { m_sysTopLayer = v; saveSysConfig(); } }
void WidgetsManager::setSysTextColor(const QString &v) { if (m_sysTextColor != v && !v.isEmpty()) { m_sysTextColor = v; saveSysConfig(); } }
void WidgetsManager::setSysGraphColor(const QString &v) { if (m_sysGraphColor != v && !v.isEmpty()) { m_sysGraphColor = v; saveSysConfig(); } }
void WidgetsManager::setSysOpacity(qreal v) { v = std::clamp(v, 0.1, 1.0); if (!qFuzzyCompare(m_sysOpacity, v)) { m_sysOpacity = v; saveSysConfig(); } }
void WidgetsManager::setSysScale(qreal v) { v = std::clamp(v, 0.4, 2.5); if (!qFuzzyCompare(m_sysScale, v)) { m_sysScale = v; saveSysConfig(); } }
void WidgetsManager::setSysTitleSize(int v) { v = std::clamp(v, 6, 36); if (m_sysTitleSize != v) { m_sysTitleSize = v; saveSysConfig(); } }
void WidgetsManager::setSysExtraSize(int v) { v = std::clamp(v, 6, 36); if (m_sysExtraSize != v) { m_sysExtraSize = v; saveSysConfig(); } }
void WidgetsManager::setSysMarginX(int v) { if (m_sysMarginX != v) { m_sysMarginX = v; saveSysConfig(); } }
void WidgetsManager::setSysMarginY(int v) { if (m_sysMarginY != v) { m_sysMarginY = v; saveSysConfig(); } }
void WidgetsManager::setSysPosition(const QString &v) { if (m_sysPosition != v && !v.isEmpty()) { m_sysPosition = v; saveSysConfig(); } }

void WidgetsManager::setSysShowProcs(bool v) { if (m_sysShowProcs != v) { m_sysShowProcs = v; saveSysConfig(); } }
void WidgetsManager::setSysProcSort(const QString &v) { if (m_sysProcSort != v && !v.isEmpty()) { m_sysProcSort = v; saveSysConfig(); } }

void WidgetsManager::setSysProcCount(int v) { v = std::clamp(v, 1, 20); if (m_sysProcCount != v) { m_sysProcCount = v; saveSysConfig(); } }

void WidgetsManager::setClockM3Sync(bool v) {
    if (m_clockM3Sync == v) return;
    m_clockM3Sync = v;
    QString ccPath = QDir::homePath() + "/.config/hypr/scripts/control_center.conf";
    QFile file(ccPath);
    QStringList lines;
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();
    }
    bool found = false;
    for (int i = 0; i < lines.size(); ++i) {
        if (lines[i].trimmed().startsWith("clock_m3_sync=")) {
            lines[i] = QString("clock_m3_sync=%1").arg(v ? "1" : "0");
            found = true;
            break;
        }
    }
    if (!found) lines.append(QString("clock_m3_sync=%1").arg(v ? "1" : "0"));
    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
    emit clockChanged();
    QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py"});
}

void WidgetsManager::setWidgetsM3Sync(bool v) {
    if (m_widgetsM3Sync == v && m_clockM3Sync == v) return;
    m_widgetsM3Sync = v;
    m_clockM3Sync = v;
    QString ccPath = QDir::homePath() + "/.config/hypr/scripts/control_center.conf";
    QFile file(ccPath);
    QStringList lines;
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();
    }
    bool foundW = false, foundC = false;
    for (int i = 0; i < lines.size(); ++i) {
        if (lines[i].trimmed().startsWith("widgets_m3_sync=")) {
            lines[i] = QString("widgets_m3_sync=%1").arg(v ? "1" : "0");
            foundW = true;
        } else if (lines[i].trimmed().startsWith("clock_m3_sync=")) {
            lines[i] = QString("clock_m3_sync=%1").arg(v ? "1" : "0");
            foundC = true;
        }
    }
    if (!foundW) lines.append(QString("widgets_m3_sync=%1").arg(v ? "1" : "0"));
    if (!foundC) lines.append(QString("clock_m3_sync=%1").arg(v ? "1" : "0"));
    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
    emit clockChanged();
    emit sysStateChanged();
    QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py"});
    QTimer::singleShot(350, this, [this]() {
        loadClockConfig();
        loadSysConfig();
        emit clockChanged();
        emit sysStateChanged();
    });
}
