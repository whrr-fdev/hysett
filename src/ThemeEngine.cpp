#include "ThemeEngine.h"
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QProcess>
#include <algorithm>
#include <cmath>

static QString ccConfPath() {
    return QDir::homePath() + "/.config/hypr/scripts/control_center.conf";
}

static void updateConfKey(const QString &key, const QString &val) {
    QFile file(ccConfPath());
    QStringList lines;
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();
    }
    bool found = false;
    for (int i = 0; i < lines.size(); ++i) {
        if (lines[i].trimmed().startsWith(key + "=")) {
            lines[i] = key + "=" + val;
            found = true;
            break;
        }
    }
    if (!found) lines.append(key + "=" + val);

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }
}

ThemeEngine::ThemeEngine(QObject *parent) : QObject(parent) {
        m_muteTimer = new QTimer(this);
    m_muteTimer->setSingleShot(true);
    m_muteTimer->setInterval(650);
    connect(m_muteTimer, &QTimer::timeout, this, [this]() {
        m_ignoreWatcher = false;
    });

    m_blurTimer = new QTimer(this);
    m_blurTimer->setSingleShot(true);
    m_blurTimer->setInterval(45);
    connect(m_blurTimer, &QTimer::timeout, this, [this]() {
        qreal val = m_pendingBlur;
        int rnd = (m_cornerRadius > 0) ? 12 : 0;
        if (val <= 0.01) {
            QProcess::startDetached("hyprctl", {"eval", QString("hl.config({ decoration = { rounding = %1, rounding_power = 2, blur = { enabled = false, size = 1, passes = 1 } } })").arg(rnd)});
            return;
        }
        int bPasses = 1;
        int bSize = 1;
        if (val <= 0.45) {
            bPasses = 1;
            bSize = qMax(1, qRound(1.0 + (val / 0.45) * 5.0));
        } else if (val <= 0.80) {
            bPasses = 2;
            bSize = qMax(2, qRound(2.0 + ((val - 0.45) / 0.35) * 5.0));
        } else {
            bPasses = 3;
            bSize = qMax(4, qRound(4.0 + ((val - 0.80) / 0.20) * 5.0));
        }
        QString cmd = QString("hl.config({ decoration = { rounding = %3, rounding_power = 2, blur = { enabled = true, size = %1, passes = %2 } } })").arg(bSize).arg(bPasses).arg(rnd);
        QProcess::startDetached("hyprctl", {"eval", cmd});
    });

    QFile f(ccConfPath());
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            int eq = line.indexOf('=');
            if (eq == -1) continue;
            QString k = line.left(eq).trimmed();
            QString v = line.mid(eq + 1).trimmed();
            if (k == "window_blur") m_windowBlur = std::clamp(v.toDouble(), 0.0, 1.0);
            else if (k == "glass_refraction") m_glassRefraction = std::clamp(v.toDouble(), 0.0, 1.0);
            else if (k == "controls_liquid_glass") m_controlsLiquidGlass = (v == "1" || v == "true");
        }
        f.close();
    }

    m_watcher = new QFileSystemWatcher(this);
    QString scriptsDir = QDir::homePath() + "/.config/hypr/scripts";
    if (QDir(scriptsDir).exists()) {
        m_watcher->addPath(scriptsDir);
    }
    QString themePath = scriptsDir + "/theme_state.conf";
    if (QFile::exists(themePath)) {
        m_watcher->addPath(themePath);
    }

    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        if (!m_ignoreWatcher) checkThemeFile();
    });
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        if (!m_ignoreWatcher) checkThemeFile();
    });

    checkThemeFile();
}

void ThemeEngine::checkThemeFile() {
    if (m_ignoreWatcher) return;
    QString themePath = QDir::homePath() + "/.config/hypr/scripts/theme_state.conf";
    QFile file(themePath);
    int newRadius = 8;
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        QString state = in.readLine().trimmed();
        newRadius = (state == "square") ? 0 : 8;
    }
    if (m_cornerRadius != newRadius) {
        m_cornerRadius = newRadius;
        emit cornerRadiusChanged();
        emit isRoundedChanged();
    }
}

void ThemeEngine::applyEffectiveBlur(qreal val) {
    m_pendingBlur = std::clamp(val, 0.0, 1.0);
    m_blurTimer->start();
}

void ThemeEngine::setWindowBlur(qreal val) {
    val = std::clamp(val, 0.0, 1.0);
    if (qFuzzyCompare(m_windowBlur, val)) return;
    m_windowBlur = val;
    updateConfKey("window_blur", QString::number(m_windowBlur, 'f', 2));
    emit windowBlurChanged();
    applyEffectiveBlur(val);
}

void ThemeEngine::setGlassRefraction(qreal val) {
    val = std::clamp(val, 0.0, 1.0);
    if (qFuzzyCompare(m_glassRefraction, val)) return;
    m_glassRefraction = val;
    updateConfKey("glass_refraction", QString::number(m_glassRefraction, 'f', 2));
    emit glassRefractionChanged();
}

void ThemeEngine::setControlsLiquidGlass(bool val) {
    if (m_controlsLiquidGlass == val) return;
    m_controlsLiquidGlass = val;
    updateConfKey("controls_liquid_glass", m_controlsLiquidGlass ? "1" : "0");
    emit controlsLiquidGlassChanged();
}

void ThemeEngine::setRoundedState(bool rounded) {
    int nextRadius = rounded ? 8 : 0;
    if (m_cornerRadius == nextRadius) return;

    m_ignoreWatcher = true;
    m_muteTimer->start();

    m_cornerRadius = nextRadius;
    emit cornerRadiusChanged();
    emit isRoundedChanged();

    QString target = rounded ? "rounded" : "square";
    int rnd = rounded ? 12 : 0;
    QFile sf(QDir::homePath() + "/.config/hypr/scripts/theme_state.conf");
    if (sf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        sf.write((target + "\n").toUtf8());
        sf.close();
    }
    QFile tf(QDir::homePath() + "/.config/hypr/theme.lua");
    if (tf.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        tf.write(QString("hl.config({ decoration = { rounding = %1, rounding_power = 2 } })\n").arg(rnd).toUtf8());
        tf.close();
    }
    QProcess::startDetached("hyprctl", {"keyword", "decoration:rounding", QString::number(rnd)});
    QProcess::startDetached("hyprctl", {"eval", QString("hl.config({ decoration = { rounding = %1, rounding_power = 2 } })").arg(rnd)});
    QString scriptPath = QDir::homePath() + "/.config/hypr/scripts/theme_toggle.sh";
    if (QFile::exists(scriptPath)) {
        QProcess::startDetached("/bin/bash", {scriptPath, target});
    }
}

void ThemeEngine::toggleThemeState() {
    setRoundedState(m_cornerRadius == 0);
}

void ThemeEngine::reloadTheme() {
    checkThemeFile();
}
