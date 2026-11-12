#include <algorithm>
#include "WallpapersManager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QImageReader>
#include <QMap>

static const char *IRIS_SHADER_CODE = R"(//!HOOK MAIN
//!BIND HOOKED
//!DESC Expanding Circle Transition

vec4 hook() {
    vec4 c = HOOKED_tex(HOOKED_pos);
    float total_frames = 55.0;
    if (frame >= int(total_frames)) {
        return c;
    }
    float p = clamp(float(frame) / total_frames, 0.0, 1.0);
    float ease = 1.0 - pow(1.0 - p, 3.0);

    vec2 uv = HOOKED_pos - vec2(0.5);
    uv.x *= HOOKED_size.x / max(HOOKED_size.y, 1.0);

    float max_r = length(vec2(0.5 * (HOOKED_size.x / max(HOOKED_size.y, 1.0)), 0.5)) + 0.15;
    float r = ease * max_r;
    float d = length(uv);

    float mask = 1.0 - smoothstep(r - 0.10, r, d);
    return vec4(c.rgb * mask, c.a);
}
)";

WallThumbProvider::WallThumbProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage WallThumbProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    QString srcPath = "/" + id;
    if (srcPath.contains("рукиASCII")) return QImage();

    QString thumbDir = QDir::homePath() + "/.cache/wallpaper-thumbs-v3";
    QDir().mkpath(thumbDir);

    QByteArray hash = QCryptographicHash::hash(srcPath.toUtf8(), QCryptographicHash::Md5).toHex();
    QString fileName = QFileInfo(srcPath).fileName();

    QString thumbPath1 = thumbDir + "/thumb_" + QString(hash.left(6)) + "_" + fileName + ".png";
    QString thumbPath2 = thumbDir + "/" + QString(hash) + ".jpg";
    QString thumbPath = QFile::exists(thumbPath1) ? thumbPath1 : (QFile::exists(thumbPath2) ? thumbPath2 : thumbPath1);

    if (!QFile::exists(thumbPath)) {
        bool isVid = srcPath.endsWith(".mp4", Qt::CaseInsensitive) ||
                     srcPath.endsWith(".webm", Qt::CaseInsensitive) ||
                     srcPath.endsWith(".mkv", Qt::CaseInsensitive);
        if (isVid) {
            QProcess p;
            p.setStandardOutputFile(QProcess::nullDevice());
            p.setStandardErrorFile(QProcess::nullDevice());
            p.start("ffmpeg", {"-nostdin", "-loglevel", "quiet", "-y", "-ss", "00:00:01", "-i", srcPath, "-frames:v", "1", "-vf", "scale=240:135:force_original_aspect_ratio=increase,crop=240:135", "-q:v", "4", thumbPath});
            p.waitForFinished(600);
        } else {
            QImageReader reader(srcPath);
            reader.setAutoTransform(true);
            reader.setScaledSize(QSize(240, 135));
            QImage scaled = reader.read();
            if (!scaled.isNull()) {
                scaled.save(thumbPath, "PNG");
            }
        }
    }

    QImage img(thumbPath);
    if (size) *size = img.size();
    if (requestedSize.isValid()) {
        img = img.scaled(requestedSize, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    }
    return img;
}

WallpapersManager::WallpapersManager(QObject *parent) : QObject(parent) {
    // Обеспечиваем наличие шейдера круга для mpvpaper
    QString shaderPath = QDir::homePath() + "/.cache/mpv_iris.glsl";
    if (!QFile::exists(shaderPath)) {
        QFile sf(shaderPath);
        if (sf.open(QIODevice::WriteOnly | QIODevice::Text)) {
            sf.write(IRIS_SHADER_CODE);
            sf.close();
        }
    }

    loadDaemonSettings();
    loadPresets();
    scanWallpapers();
}

void WallpapersManager::setDaemonRunning(bool v) {
    m_daemonRunning = v;
    emit daemonChanged();

    QString stateFile = QDir::homePath() + "/.config/hypr/scripts/auto_wallpaper.conf";
    QFile f(stateFile);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&f);
        out << (v ? "1" : "0") << "\n";
    }

    if (v) {
        QProcess::startDetached("sh", {"-c", "pgrep -x wallpaperd >/dev/null || wallpaperd > /tmp/wallpaper_daemon.log 2>&1 &"});
    } else {
        QProcess::startDetached("pkill", {"-f", "wallpaperd"});
    }
}

void WallpapersManager::loadDaemonSettings() {
    QString home = QDir::homePath();

    bool confOn = true;
    QFile fState(home + "/.config/hypr/scripts/auto_wallpaper.conf");
    if (fState.open(QIODevice::ReadOnly | QIODevice::Text)) {
        confOn = (QTextStream(&fState).readLine().trimmed() != "0");
    }
    QProcess p;
    p.start("pgrep", {"-f", "wallpaperd"});
    p.waitForFinished();
    bool procRunning = !p.readAllStandardOutput().trimmed().isEmpty();
    m_daemonRunning = confOn && procRunning;

    QFile fMode(home + "/.config/hypr/scripts/auto_mode.conf");
    if (fMode.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_autoMode = QTextStream(&fMode).readLine().trimmed();
        if (m_autoMode.isEmpty()) m_autoMode = "all";
    }

    QFile fInt(home + "/.config/hypr/scripts/auto_interval.conf");
    if (fInt.open(QIODevice::ReadOnly | QIODevice::Text)) {
        int val = QTextStream(&fInt).readLine().trimmed().toInt();
        if (val > 0) m_autoInterval = val;
    }

    // Читаем состояние случайной анимации из random_anim.conf или auto_anim.conf
    QFile fAnim(home + "/.config/hypr/scripts/random_anim.conf");
    if (fAnim.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_randomAnim = (QTextStream(&fAnim).readLine().trimmed() == "1");
    } else {
        QFile fAnim2(home + "/.config/hypr/scripts/auto_anim.conf");
        if (fAnim2.open(QIODevice::ReadOnly | QIODevice::Text)) {
            m_randomAnim = (QTextStream(&fAnim2).readLine().trimmed() == "1");
        }
    }
}

void WallpapersManager::setAutoMode(const QString &v) {
    if (m_autoMode == v) return;
    m_autoMode = v;
    QFile f(QDir::homePath() + "/.config/hypr/scripts/auto_mode.conf");
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream(&f) << v << "\n";
    }
    emit daemonChanged();
}

void WallpapersManager::setAutoInterval(int v) {
    if (m_autoInterval == v) return;
    m_autoInterval = v;
    QFile f(QDir::homePath() + "/.config/hypr/scripts/auto_interval.conf");
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream(&f) << v << "\n";
    }
    emit daemonChanged();
}

void WallpapersManager::setRandomAnim(bool v) {
    if (m_randomAnim == v) return;
    m_randomAnim = v;
    QString home = QDir::homePath();
    for (const QString &fn : {"random_anim.conf", "auto_anim.conf"}) {
        QFile f(home + "/.config/hypr/scripts/" + fn);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream(&f) << (v ? "1" : "0") << "\n";
        }
    }
    emit animChanged();
}

void WallpapersManager::scanWallpapers() {
    m_categories.clear();
    m_wallpapers.clear();

    QString wallRoot = QDir::homePath() + "/Pictures/Wallpapers";
    QDir dir(wallRoot);
    if (!dir.exists()) return;

    QStringList subDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    QStringList imgExts = {"*.jpg", "*.jpeg", "*.png", "*.webp", "*.mp4", "*.webm", "*.mkv"};

    for (const auto &sub : subDirs) {
        if (sub.toLower().contains("windows")) continue;
        QDir sDir(wallRoot + "/" + sub);
        QString catName = sub;

        QStringList files = sDir.entryList(imgExts, QDir::Files);
        if (files.isEmpty()) continue;

        QVariantMap cat;
        cat["name"] = catName;
        cat["count"] = files.size();
        m_categories.append(cat);

        for (const auto &file : files) {
            if (file.contains("рукиASCII")) continue;
            QString fullPath = sDir.filePath(file);
            bool isVid = fullPath.endsWith(".mp4", Qt::CaseInsensitive) ||
                         fullPath.endsWith(".webm", Qt::CaseInsensitive) ||
                         fullPath.endsWith(".mkv", Qt::CaseInsensitive);

            QVariantMap w;
            w["path"] = fullPath;
            w["name"] = file;
            w["category"] = catName;
            w["isVideo"] = isVid;
            m_wallpapers.append(w);
        }
    }

    
    std::stable_sort(m_categories.begin(), m_categories.end(), [](const QVariant &a, const QVariant &b) {
        bool aLive = a.toMap()["name"].toString().compare("Live", Qt::CaseInsensitive) == 0;
        bool bLive = b.toMap()["name"].toString().compare("Live", Qt::CaseInsensitive) == 0;
        return aLive > bLive;
    });
    std::stable_sort(m_wallpapers.begin(), m_wallpapers.end(), [](const QVariant &a, const QVariant &b) {
        bool aLive = a.toMap()["category"].toString().compare("Live", Qt::CaseInsensitive) == 0;
        bool bLive = b.toMap()["category"].toString().compare("Live", Qt::CaseInsensitive) == 0;
        return aLive > bLive;
    });
    emit categoriesChanged();
    emit wallpapersChanged();
}

void WallpapersManager::applyWallpaperInternal(const QString &path, bool fromPreset) {
    if (path.isEmpty()) return;

    if (!fromPreset && m_activePresetIndex != -1) {
        m_activePresetIndex = -1;
        emit activePresetChanged();
    }

    QString home = QDir::homePath();
    bool isVid = path.endsWith(".mp4", Qt::CaseInsensitive) ||
                 path.endsWith(".webm", Qt::CaseInsensitive) ||
                 path.endsWith(".mkv", Qt::CaseInsensitive);

    for (const QString &fn : {home + "/.config/hypr/scripts/last_wallpaper.conf", home + "/.cache/last_wallpaper.txt"}) {
        QFile f(fn);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream(&f) << path << "\n";
        }
    }

    QString linkPath = home + "/.cache/wallpaper-current";
    QFile::remove(linkPath);
    QFile::link(path, linkPath);
    QProcess::startDetached("sh", {"-c", "/home/whrr/.config/hypr/scripts/update_lock_bg.sh"}); // sync_m3_after_wall

    // Выбираем случайную или стандартную анимацию перехода
    static const QStringList transitions = {
        "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "outer"
    };
    static const QStringList positions = {
        "center", "top-right", "top-left", "bottom-right", "bottom-left"
    };

    QString trans = m_randomAnim
        ? transitions[QRandomGenerator::global()->bounded(transitions.size())]
        : "grow";
    QString pos = m_randomAnim
        ? positions[QRandomGenerator::global()->bounded(positions.size())]
        : "top-right";

    QString blackImg = home + "/.cache/wallpaper-black.png";
    QString irisShader = home + "/.cache/mpv_iris.glsl";

    if (isVid) {
        if (QFile::exists(blackImg)) {
            QProcess::execute("awww", {
                "img", blackImg,
                "--transition-type", "outer",
                "--transition-pos", "center",
                "--transition-duration", "0.42",
                "--transition-fps", "160"
            });
        }
        QString cmd = QString(
            "pkill -9 -x mpvpaper; sleep 0.05; "
            "mpvpaper -o \"no-audio --loop-file=inf --hwdec=auto --panscan=1.0 --cache=no "
            "--demuxer-max-bytes=32M --vd-lavc-fast --sws-fast --brightness=-12 "
            "--glsl-shader=%1 --input-ipc-server=/tmp/mpvpaper-socket\" '*' '%2' &"
        ).arg(irisShader, path);
        QProcess::startDetached("sh", {"-c", cmd});
    } else {
        QProcess::execute("pkill", {"-9", "-x", "mpvpaper"});
        QString cmd = QString(
            "awww img '%1' --transition-type %2 --transition-pos %3 "
            "--transition-duration 1.2 --transition-fps 160 || swww img '%1'"
        ).arg(path, trans, pos);
        QProcess::startDetached("sh", {"-c", cmd});
    }

    QProcess::startDetached("sh", {"-c", "pkill -f 'qs -c overview'; sleep 0.35; qs -c overview &"});
}

void WallpapersManager::applyWallpaper(const QString &path) {
    applyWallpaperInternal(path, false);
}


void WallpapersManager::clearWallpaper() {
    if (m_daemonRunning) setDaemonRunning(false);
    if (m_activePresetIndex != -1) {
        m_activePresetIndex = -1;
        emit activePresetChanged();
        savePresetsToFile();
    }

    QString home = QDir::homePath();
    QString blackImg = home + "/.cache/wallpaper-black.png";
    if (!QFile::exists(blackImg)) {
        QImage img(32, 32, QImage::Format_RGB32);
        img.fill(QColor(8, 8, 10));
        img.save(blackImg, "PNG");
    }

    for (const QString &fn : {home + "/.config/hypr/scripts/last_wallpaper.conf", home + "/.cache/last_wallpaper.txt"}) {
        QFile f(fn);
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream(&f) << "none\n";
        }
    }
    QFile::remove(home + "/.cache/wallpaper-current");

    QProcess::execute("pkill", {"-9", "-x", "mpvpaper"});
    QString cmd = QString(
        "awww clear 08080a 2>/dev/null || "
        "awww img '%1' --transition-type fade --transition-duration 0.6 --transition-fps 160 2>/dev/null || "
        "swww clear 08080a 2>/dev/null || "
        "swww img '%1' 2>/dev/null"
    ).arg(blackImg);
    QProcess::startDetached("sh", {"-c", cmd});
}

void WallpapersManager::applyRandomWallpaper() {
    if (m_wallpapers.isEmpty()) return;
    int idx = QRandomGenerator::global()->bounded(m_wallpapers.size());
    applyWallpaperInternal(m_wallpapers[idx].toMap()["path"].toString(), false);
}

void WallpapersManager::loadPresets() {
    m_presets.clear();

    auto makeDef = [](int i) {
        QVariantMap m;
        m["name"] = (i == 1) ? "🌿 Трава (Live)" : "🌸 Сакура (Live)";
        m["wall"] = (i == 1) ? QDir::homePath() + "/Pictures/Wallpapers/Live/grass.mp4" :
                               QDir::homePath() + "/Pictures/Wallpapers/Live/cherry-blossom-ghost-of-tsushima-moewalls-com.mp4";
        m["active_opacity"] = 0.85;
        m["inactive_opacity"] = (i == 1) ? 0.75 : 0.65;
        m["blur_enabled"] = true;
        m["blur_size"] = (i == 1) ? 8.0 : 5.0;
        m["canDelete"] = false;
        return m;
    };

    QMap<int, QVariantMap> loaded;
    loaded[1] = makeDef(1);
    loaded[2] = makeDef(2);

    QString path = QDir::homePath() + "/.config/hypr/scripts/presets.conf";
    QFile f(path);
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&f);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (!line.contains('=')) continue;
            int eq = line.indexOf('=');
            QString k = line.left(eq).trimmed();
            QString v = line.mid(eq + 1).trimmed();

            if (k == "active_preset") {
                m_activePresetIndex = v.toInt();
                continue;
            }

            if (k.startsWith('p')) {
                int us = k.indexOf('_');
                if (us > 1) {
                    int idx = k.mid(1, us - 1).toInt();
                    QString field = k.mid(us + 1);
                    if (idx >= 1) {
                        if (!loaded.contains(idx)) {
                            QVariantMap custom;
                            custom["name"] = QString("Пресет %1").arg(idx);
                            custom["wall"] = "";
                            custom["active_opacity"] = 0.85;
                            custom["inactive_opacity"] = 0.75;
                            custom["blur_enabled"] = true;
                            custom["blur_size"] = 8.0;
                            custom["canDelete"] = (idx > 2);
                            loaded[idx] = custom;
                        }
                        QVariantMap p = loaded[idx];
                        if (field == "name") p["name"] = v;
                        else if (field == "wall") p["wall"] = v;
                        else if (field == "active_opacity") p["active_opacity"] = v.toDouble();
                        else if (field == "inactive_opacity") p["inactive_opacity"] = v.toDouble();
                        else if (field == "blur_enabled") p["blur_enabled"] = (v.toDouble() >= 0.5);
                        else if (field == "blur_size") p["blur_size"] = v.toDouble();
                        p["canDelete"] = (idx > 2);
                        loaded[idx] = p;
                    }
                }
            }
        }
    }

    for (auto it = loaded.begin(); it != loaded.end(); ++it) {
        m_presets.append(it.value());
    }
    emit presetsChanged();
}

void WallpapersManager::savePresetsToFile() {
    QString path = QDir::homePath() + "/.config/hypr/scripts/presets.conf";
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&f);
        out << "active_preset=" << m_activePresetIndex << "\n\n";
        for (int i = 0; i < m_presets.size(); ++i) {
            QVariantMap p = m_presets[i].toMap();
            int idx = i + 1;
            out << QString("p%1_name=%2\n").arg(idx).arg(p["name"].toString());
            out << QString("p%1_wall=%2\n").arg(idx).arg(p["wall"].toString());
            out << QString("p%1_active_opacity=%2\n").arg(idx).arg(p["active_opacity"].toDouble());
            out << QString("p%1_inactive_opacity=%2\n").arg(idx).arg(p["inactive_opacity"].toDouble());
            out << QString("p%1_blur_enabled=%2\n").arg(idx).arg(p["blur_enabled"].toBool() ? 1.0 : 0.0);
            out << QString("p%1_blur_size=%2\n\n").arg(idx).arg(p["blur_size"].toDouble());
        }
    }
}

void WallpapersManager::applyPreset(int idx) {
    if (idx < 0 || idx >= m_presets.size()) return;
    QVariantMap p = m_presets[idx].toMap();

    m_activePresetIndex = idx;
    emit activePresetChanged();
    savePresetsToFile();

    setDaemonRunning(false);

    QString evalCmd = QString("hl.config({ decoration = { active_opacity = %1, inactive_opacity = %2, blur = { enabled = %3, size = %4 } } })")
        .arg(p["active_opacity"].toDouble(), 0, 'f', 2)
        .arg(p["inactive_opacity"].toDouble(), 0, 'f', 2)
        .arg(p["blur_enabled"].toBool() ? "true" : "false")
        .arg(qRound(p["blur_size"].toDouble()));
    QProcess::startDetached("hyprctl", {"eval", evalCmd});

    applyWallpaperInternal(p["wall"].toString(), true);
}

void WallpapersManager::savePreset(int idx, const QString &name, const QString &wall, qreal actOp, qreal inactOp, bool blurEn, qreal blurSz) {
    QVariantMap p;
    p["name"] = name;
    p["wall"] = wall;
    p["active_opacity"] = actOp;
    p["inactive_opacity"] = inactOp;
    p["blur_enabled"] = blurEn;
    p["blur_size"] = blurSz;

    if (idx >= 0 && idx < m_presets.size()) {
        p["canDelete"] = (idx >= 2);
        m_presets[idx] = p;
    } else {
        p["canDelete"] = true;
        m_presets.append(p);
    }

    savePresetsToFile();
    emit presetsChanged();
}

void WallpapersManager::deletePreset(int idx) {
    if (idx < 2 || idx >= m_presets.size()) return;
    if (m_activePresetIndex == idx) {
        m_activePresetIndex = -1;
        emit activePresetChanged();
    } else if (m_activePresetIndex > idx) {
        m_activePresetIndex--;
        emit activePresetChanged();
    }
    m_presets.removeAt(idx);
    savePresetsToFile();
    emit presetsChanged();
}

QVariantMap WallpapersManager::snapshotCurrentSettings() {
    QVariantMap m;
    QFile f(QDir::homePath() + "/.config/hypr/scripts/last_wallpaper.conf");
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m["wall"] = QTextStream(&f).readLine().trimmed();
    } else {
        m["wall"] = "";
    }
    return m;
}
