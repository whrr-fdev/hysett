#include "CursorManager.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QDataStream>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantMap>
#include <QHash>
#include <QMutex>
#include <QMutexLocker>
#include <algorithm>

static QHash<QString, QImage> s_cursorCache;
static QMutex s_cursorMutex;

CursorImageProvider::CursorImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

void CursorImageProvider::clearCache() {
    QMutexLocker lock(&s_cursorMutex);
    s_cursorCache.clear();
}

QImage CursorImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    QString cleanId = id;
    int qIdx = cleanId.indexOf('?');
    if (qIdx != -1) cleanId = cleanId.left(qIdx);

    QImage img;
    {
        QMutexLocker lock(&s_cursorMutex);
        if (s_cursorCache.contains(cleanId)) {
            img = s_cursorCache.value(cleanId);
        }
    }

    if (img.isNull()) {
        img = extractCursor(cleanId);
        if (!img.isNull()) {
            int minX = img.width(), minY = img.height(), maxX = 0, maxY = 0;
            bool hasVisible = false;
            for (int y = 0; y < img.height(); ++y) {
                for (int x = 0; x < img.width(); ++x) {
                    if (qAlpha(img.pixel(x, y)) > 25) {
                        minX = qMin(minX, x);
                        minY = qMin(minY, y);
                        maxX = qMax(maxX, x);
                        maxY = qMax(maxY, y);
                        hasVisible = true;
                    }
                }
            }
            if (hasVisible && maxX >= minX && maxY >= minY) {
                img = img.copy(minX, minY, maxX - minX + 1, maxY - minY + 1);
            }
            QMutexLocker lock(&s_cursorMutex);
            s_cursorCache.insert(cleanId, img);
        }
    }

    if (size) *size = img.size();
    if (requestedSize.isValid() && !img.isNull()) {
        img = img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    return img;
}

QImage CursorImageProvider::extractCursor(const QString &theme) {
    QString home = QDir::homePath();
    QStringList searchDirs = {
        home + "/.local/share/icons/" + theme,
        home + "/.icons/" + theme,
        "/usr/share/icons/" + theme
    };
    QStringList names = {"default", "left_ptr", "arrow", "top_left_arrow", "08e8e1c95fe2fc01f976f1e063a24ccd"};

    for (const auto &d : searchDirs) {
        for (const auto &n : names) {
            QString pngDir = d + "/hyprcursors/" + n;
            QDir dir(pngDir);
            if (dir.exists()) {
                QStringList entries = dir.entryList({"*.png", "*.svg"}, QDir::Files);
                if (!entries.isEmpty()) {
                    QImage img(dir.filePath(entries.first()));
                    if (!img.isNull()) return img;
                }
            }
        }
        for (const auto &n : names) {
            QString curPath = d + "/cursors/" + n;
            QFile file(curPath);
            if (file.open(QIODevice::ReadOnly)) {
                QByteArray data = file.readAll();
                if (data.size() >= 16 && data.startsWith("Xcur")) {
                    QDataStream ds(data);
                    ds.setByteOrder(QDataStream::LittleEndian);
                    ds.skipRawData(12);
                    quint32 ntoc = 0;
                    ds >> ntoc;

                    quint32 bestPos = 0;
                    qint32 minDiff = 9999;

                    for (quint32 i = 0; i < ntoc; ++i) {
                        quint32 ctype, csubtype, cpos;
                        ds >> ctype >> csubtype >> cpos;
                        if (ctype == 0xfffd0002) {
                            qint32 diff = std::abs(static_cast<qint32>(csubtype) - 28);
                            if (diff < minDiff) {
                                minDiff = diff;
                                bestPos = cpos;
                            }
                        }
                    }

                    if (bestPos > 0 && bestPos + 36 < static_cast<quint32>(data.size())) {
                        QDataStream dsImg(data.mid(bestPos));
                        dsImg.setByteOrder(QDataStream::LittleEndian);
                        dsImg.skipRawData(16);
                        quint32 w = 0, h = 0;
                        dsImg >> w >> h;
                        dsImg.skipRawData(12);

                        int pixelBytes = w * h * 4;
                        int offset = bestPos + 36;
                        if (offset + pixelBytes <= data.size()) {
                            const uchar *pixels = reinterpret_cast<const uchar*>(data.constData() + offset);
                            QImage img(pixels, w, h, QImage::Format_ARGB32_Premultiplied);
                            return img.copy();
                        }
                    }
                }
            }
        }
    }
    return QImage();
}

static bool copyDirectoryRecursively(const QString &srcPath, const QString &dstPath) {
    QDir srcDir(srcPath);
    if (!srcDir.exists()) return false;
    QDir dstDir(dstPath);
    if (!dstDir.exists() && !QDir().mkpath(dstPath)) return false;

    const QFileInfoList entries = srcDir.entryInfoList(QDir::NoDotAndDotDot | QDir::AllEntries | QDir::Hidden | QDir::System);
    for (const QFileInfo &fi : entries) {
        QString srcItem = fi.filePath();
        QString dstItem = dstDir.filePath(fi.fileName());
        if (fi.isSymLink()) {
            QFile::remove(dstItem);
            QFile::link(fi.symLinkTarget(), dstItem);
        } else if (fi.isDir()) {
            if (!copyDirectoryRecursively(srcItem, dstItem)) return false;
        } else {
            QFile::remove(dstItem);
            if (!QFile::copy(srcItem, dstItem)) return false;
        }
    }
    return true;
}

CursorManager::CursorManager(QObject *parent) : QObject(parent) {
    scanThemes();
    loadSettings();
    refreshDownloadArchives();
}

void CursorManager::scanThemes() {
    m_installedThemes.clear();
    QString home = QDir::homePath();
    QStringList paths = { home + "/.icons", home + "/.local/share/icons", "/usr/share/icons" };

    for (const auto &p : paths) {
        QDir dir(p);
        if (!dir.exists()) continue;
        for (const auto &e : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QDir sub(dir.filePath(e));
            if (sub.exists("cursors") || sub.exists("hyprcursors")) {
                if (!m_installedThemes.contains(e)) m_installedThemes.append(e);
            }
        }
    }
    if (m_installedThemes.isEmpty()) {
        m_installedThemes << "Bibata-Modern-Classic" << "Adwaita";
    }
    m_installedThemes.sort(Qt::CaseInsensitive);
    emit installedThemesChanged();
}

void CursorManager::refreshDownloadArchives() {
    m_downloadArchives.clear();
    QString home = QDir::homePath();
    QStringList dlDirs = { home + "/Downloads", home + "/Загрузки" };
    QStringList filters = { "*.tar.gz", "*.tgz", "*.tar.xz", "*.txz", "*.tar.bz2", "*.tbz2", "*.tar.zst", "*.zip", "*.hlc", "*.tar" };
    QStringList seenPaths;

    for (const QString &dPath : dlDirs) {
        QDir d(dPath);
        if (!d.exists()) continue;
        QFileInfoList list = d.entryInfoList(filters, QDir::Files, QDir::Time);
        for (const QFileInfo &fi : list) {
            QString abs = fi.absoluteFilePath();
            if (seenPaths.contains(abs)) continue;
            seenPaths.append(abs);
            QVariantMap item;
            item["name"] = fi.fileName();
            item["path"] = abs;
            double mb = fi.size() / (1024.0 * 1024.0);
            item["size"] = mb >= 1.0 ? QString::number(mb, 'f', 1) + " МБ"
                                     : QString::number(qMax(1.0, fi.size() / 1024.0), 'f', 0) + " КБ";
            m_downloadArchives.append(item);
            if (m_downloadArchives.size() >= 15) break;
        }
    }
    emit downloadArchivesChanged();
}

QString CursorManager::browseCursorArchive() {
    QString startDir = QDir::homePath() + "/Downloads";
    if (!QDir(startDir).exists()) startDir = QDir::homePath();

    // Попытка через zenity / kdialog / python tkinter
    QString script = QString(
        "if command -v zenity >/dev/null 2>&1; then "
        "  zenity --file-selection --title='Выберите архив курсора' --filename='%1/' --file-filter='Архивы курсоров | *.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tbz2 *.tar.zst *.zip *.hlc *.tar' --file-filter='Все файлы | *' 2>/dev/null; "
        "elif command -v kdialog >/dev/null 2>&1; then "
        "  kdialog --getopenfilename '%1' '*.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tbz2 *.tar.zst *.zip *.hlc *.tar|Архивы курсоров' 2>/dev/null; "
        "else "
        "  python3 -c \"import tkinter as tk; from tkinter import filedialog; root = tk.Tk(); root.withdraw(); print(filedialog.askopenfilename(initialdir='%1', title='Выберите архив курсора'))\" 2>/dev/null; "
        "fi"
    ).arg(startDir);

    QProcess p;
    p.start("sh", {"-c", script});
    p.waitForFinished(-1);
    QString chosen = QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    return chosen;
}

bool CursorManager::installCursor(const QString &rawPath, bool applyImmediately) {
    QString path = rawPath.trimmed();
    if (path.startsWith("file://")) {
        path = QUrl(path).toLocalFile();
    }
    if (path.isEmpty()) {
        m_installSuccess = false;
        m_installStatus = "Укажите путь к архиву или папке с курсором";
        emit installStatusChanged();
        return false;
    }

    QFileInfo fi(path);
    if (!fi.exists()) {
        m_installSuccess = false;
        m_installStatus = "Файл или папка не найдены: " + path;
        emit installStatusChanged();
        return false;
    }

    QString targetBase = QDir::homePath() + "/.local/share/icons";
    QDir().mkpath(targetBase);

    QTemporaryDir tmpDir;
    QString searchRoot;

    if (fi.isDir()) {
        searchRoot = fi.absoluteFilePath();
    } else {
        if (!tmpDir.isValid()) {
            m_installSuccess = false;
            m_installStatus = "Не удалось создать временную папку для распаковки";
            emit installStatusChanged();
            return false;
        }
        searchRoot = tmpDir.path();

        QProcess proc;
        QString pyExtract = QString(
            "import sys, os, tarfile, zipfile, subprocess\n"
            "src, dst = sys.argv[1], sys.argv[2]\n"
            "ok = False\n"
            "if zipfile.is_zipfile(src):\n"
            "    with zipfile.ZipFile(src, 'r') as z:\n"
            "        z.extractall(dst)\n"
            "    ok = True\n"
            "else:\n"
            "    try:\n"
            "        with tarfile.open(src, 'r:*') as t:\n"
            "            t.extractall(dst)\n"
            "        ok = True\n"
            "    except Exception:\n"
            "        r = subprocess.run(['bsdtar', '-xf', src, '-C', dst])\n"
            "        if r.returncode != 0:\n"
            "            r = subprocess.run(['tar', '-xf', src, '-C', dst])\n"
            "        ok = (r.returncode == 0)\n"
            "sys.exit(0 if ok else 1)\n"
        );
        proc.start("python3", {"-c", pyExtract, fi.absoluteFilePath(), searchRoot});
        proc.waitForFinished(60000);
        if (proc.exitCode() != 0) {
            m_installSuccess = false;
            m_installStatus = "Ошибка распаковки архива (поддерживаются .tar.xz, .tar.gz, .tar.zst, .zip, .hlc)";
            emit installStatusChanged();
            return false;
        }
    }

    QStringList candidateDirs;
    QDir rootD(searchRoot);
    if (rootD.exists("cursors") || rootD.exists("hyprcursors")) {
        candidateDirs.append(searchRoot);
    } else {
        QDirIterator it(searchRoot, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            QString sub = it.next();
            QDir sd(sub);
            if (sd.dirName() == "cursors" || sd.dirName() == "hyprcursors") continue;
            if (sd.exists("cursors") || sd.exists("hyprcursors")) {
                if (!candidateDirs.contains(sub)) {
                    candidateDirs.append(sub);
                }
            }
        }
    }

    if (candidateDirs.isEmpty()) {
        m_installSuccess = false;
        m_installStatus = "Внутри не найдено папок курсора (cursors / hyprcursors)";
        emit installStatusChanged();
        return false;
    }

    QStringList installedNames;
    for (const QString &cand : candidateDirs) {
        QDir cd(cand);
        QString themeName = cd.dirName();
        if (cand == searchRoot) {
            themeName = fi.baseName();
            if (themeName.endsWith(".tar")) themeName.chop(4);
        }

        // Проверим index.theme при корневой распаковке
        if (cand == searchRoot && cd.exists("index.theme")) {
            QFile idxF(cd.filePath("index.theme"));
            if (idxF.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream ts(&idxF);
                while (!ts.atEnd()) {
                    QString l = ts.readLine().trimmed();
                    if (l.startsWith("Name=", Qt::CaseInsensitive)) {
                        QString n = l.mid(5).trimmed();
                        if (!n.isEmpty() && !n.contains('/')) {
                            themeName = n;
                            break;
                        }
                    }
                }
            }
        }

        QString dstThemePath = targetBase + "/" + themeName;
        if (QFileInfo(cand).canonicalFilePath() == QFileInfo(dstThemePath).canonicalFilePath()) {
            installedNames.append(themeName);
            continue;
        }

        if (copyDirectoryRecursively(cand, dstThemePath)) {
            installedNames.append(themeName);
        }
    }

    if (installedNames.isEmpty()) {
        m_installSuccess = false;
        m_installStatus = "Не удалось скопировать файлы курсора в ~/.local/share/icons";
        emit installStatusChanged();
        return false;
    }

    CursorImageProvider::clearCache();
    scanThemes();
    refreshDownloadArchives();

    if (applyImmediately && !installedNames.isEmpty()) {
        setTheme(installedNames.first());
    }

    m_installSuccess = true;
    m_installStatus = "Успешно установлено: " + installedNames.join(", ");
    emit installStatusChanged();
    return true;
}

void CursorManager::loadSettings() {
    QProcess p1;
    p1.start("gsettings", {"get", "org.gnome.desktop.interface", "cursor-theme"});
    p1.waitForFinished();
    QString th = QString::fromUtf8(p1.readAllStandardOutput()).trimmed().remove('\'');
    if (!th.isEmpty()) m_theme = th;

    QProcess p2;
    p2.start("gsettings", {"get", "org.gnome.desktop.interface", "cursor-size"});
    p2.waitForFinished();
    int sz = QString::fromUtf8(p2.readAllStandardOutput()).trimmed().toInt();
    if (sz > 0) m_size = sz;

    QString confPath = QDir::homePath() + "/.config/hypr/scripts/cursor.conf";
    QFile file(confPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            int eq = line.indexOf('=');
            if (eq == -1) continue;
            QString k = line.left(eq).trimmed();
            QString v = line.mid(eq + 1).trimmed();
            if (k == "theme") m_theme = v;
            else if (k == "size") m_size = v.toInt();
            else if (k == "hw_cursors") m_hwCursors = v.toInt();
            else if (k == "enable_hyprcursor") m_enableHyprcursor = (v == "1" || v == "true");
            else if (k == "no_warps") m_noWarps = (v == "1" || v == "true");
            else if (k == "persistent_warps") m_persistentWarps = (v == "1" || v == "true");
            else if (k == "warp_on_change_ws") m_warpOnChangeWs = v.toInt();
            else if (k == "zoom_factor") m_zoomFactor = v.toDouble();
            else if (k == "inactive_timeout") m_inactiveTimeout = v.toDouble();
            else if (k == "hide_on_key_press") m_hideOnKeyPress = (v == "1" || v == "true");
            else if (k == "hide_on_touch") m_hideOnTouch = (v == "1" || v == "true");
            else if (k == "hide_on_tablet") m_hideOnTablet = (v == "1" || v == "true");
        }
    }
}

void CursorManager::saveAndApply() {
    QString sizeStr = QString::number(m_size);
    QProcess::startDetached("hyprctl", {"setcursor", m_theme, sizeStr});
    QProcess::startDetached("gsettings", {"set", "org.gnome.desktop.interface", "cursor-theme", m_theme});
    QProcess::startDetached("gsettings", {"set", "org.gnome.desktop.interface", "cursor-size", sizeStr});

    QString confPath = QDir::homePath() + "/.config/hypr/scripts/cursor.conf";
    QFile file(confPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << "theme=" << m_theme << "\n"
            << "size=" << m_size << "\n"
            << "hw_cursors=" << m_hwCursors << "\n"
            << "enable_hyprcursor=" << (m_enableHyprcursor ? 1 : 0) << "\n"
            << "no_warps=" << (m_noWarps ? 1 : 0) << "\n"
            << "persistent_warps=" << (m_persistentWarps ? 1 : 0) << "\n"
            << "warp_on_change_ws=" << m_warpOnChangeWs << "\n"
            << "zoom_factor=" << QString::number(m_zoomFactor, 'f', 2) << "\n"
            << "inactive_timeout=" << QString::number(m_inactiveTimeout, 'f', 1) << "\n"
            << "hide_on_key_press=" << (m_hideOnKeyPress ? 1 : 0) << "\n"
            << "hide_on_touch=" << (m_hideOnTouch ? 1 : 0) << "\n"
            << "hide_on_tablet=" << (m_hideOnTablet ? 1 : 0) << "\n";
    }

    QString luaPath = QDir::homePath() + "/.config/hypr/cursor.lua";
    QFile luaFile(luaPath);
    if (luaFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&luaFile);
        out << "-- Auto-generated by Control Center\n"
            << "hl.config({\n"
            << "    cursor = {\n"
            << "        no_hardware_cursors = " << m_hwCursors << ",\n"
            << "        enable_hyprcursor = " << (m_enableHyprcursor ? "true" : "false") << ",\n"
            << "        no_warps = " << (m_noWarps ? "true" : "false") << ",\n"
            << "        persistent_warps = " << (m_persistentWarps ? "true" : "false") << ",\n"
            << "        warp_on_change_workspace = " << m_warpOnChangeWs << ",\n"
            << "        zoom_factor = " << QString::number(m_zoomFactor, 'f', 2) << ",\n"
            << "        inactive_timeout = " << QString::number(m_inactiveTimeout, 'f', 1) << ",\n"
            << "        hide_on_key_press = " << (m_hideOnKeyPress ? "true" : "false") << ",\n"
            << "        hide_on_touch = " << (m_hideOnTouch ? "true" : "false") << ",\n"
            << "        hide_on_tablet = " << (m_hideOnTablet ? "true" : "false") << ",\n"
            << "    },\n"
            << "})\n"
            << "hl.env(\"XCURSOR_THEME\", \"" << m_theme << "\")\n"
            << "hl.env(\"XCURSOR_SIZE\", \"" << m_size << "\")\n"
            << "hl.env(\"HYPRCURSOR_THEME\", \"" << m_theme << "\")\n"
            << "hl.env(\"HYPRCURSOR_SIZE\", \"" << m_size << "\")\n";
    }

    QProcess::startDetached("hyprctl", {"eval", QString("dofile(\"%1\")").arg(luaPath)});
}

void CursorManager::setTheme(const QString &v) { if (m_theme != v) { m_theme = v; emit themeChanged(); saveAndApply(); } }
void CursorManager::setSize(int v) { v = std::clamp(v, 16, 64); if (m_size != v) { m_size = v; emit sizeChanged(); saveAndApply(); } }
void CursorManager::setHwCursors(int v) { if (m_hwCursors != v) { m_hwCursors = v; emit hwCursorsChanged(); saveAndApply(); } }
void CursorManager::setEnableHyprcursor(bool v) { if (m_enableHyprcursor != v) { m_enableHyprcursor = v; emit enableHyprcursorChanged(); saveAndApply(); } }
void CursorManager::setNoWarps(bool v) { if (m_noWarps != v) { m_noWarps = v; emit noWarpsChanged(); saveAndApply(); } }
void CursorManager::setPersistentWarps(bool v) { if (m_persistentWarps != v) { m_persistentWarps = v; emit persistentWarpsChanged(); saveAndApply(); } }
void CursorManager::setWarpOnChangeWs(int v) { if (m_warpOnChangeWs != v) { m_warpOnChangeWs = v; emit warpOnChangeWsChanged(); saveAndApply(); } }
void CursorManager::setZoomFactor(qreal v) { v = std::clamp(v, 1.0, 4.0); if (!qFuzzyCompare(m_zoomFactor, v)) { m_zoomFactor = v; emit zoomFactorChanged(); saveAndApply(); } }
void CursorManager::setInactiveTimeout(qreal v) { v = std::clamp(v, 0.0, 120.0); if (!qFuzzyCompare(m_inactiveTimeout, v)) { m_inactiveTimeout = v; emit inactiveTimeoutChanged(); saveAndApply(); } }
void CursorManager::setHideOnKeyPress(bool v) { if (m_hideOnKeyPress != v) { m_hideOnKeyPress = v; emit hideOnKeyPressChanged(); saveAndApply(); } }
void CursorManager::setHideOnTouch(bool v) { if (m_hideOnTouch != v) { m_hideOnTouch = v; emit hideOnTouchChanged(); saveAndApply(); } }
void CursorManager::setHideOnTablet(bool v) { if (m_hideOnTablet != v) { m_hideOnTablet = v; emit hideOnTabletChanged(); saveAndApply(); } }
void CursorManager::stepSize(int delta) { setSize(m_size + delta); }
void CursorManager::stepZoom(qreal delta) { setZoomFactor(m_zoomFactor + delta); }
void CursorManager::stepTimeout(qreal delta) { setInactiveTimeout(m_inactiveTimeout + delta); }
