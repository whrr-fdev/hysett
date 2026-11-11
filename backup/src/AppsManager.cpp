#include "AppsManager.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>
#include <QSet>
#include <algorithm>

AppsManager::AppsManager(QObject *parent) : QObject(parent) {
    m_searchProc = new QProcess(this);
    connect(m_searchProc, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        QString out = QString::fromUtf8(m_searchProc->readAllStandardOutput());
        const QStringList lines = out.split('\n', Qt::SkipEmptyParts);
        QVariantList results;
        for (const QString &rawPath : lines) {
            QString p = rawPath.trimmed();
            if (p.isEmpty()) continue;
            QFileInfo fi(p);
            QVariantMap m;
            m["name"] = fi.fileName().isEmpty() ? p : fi.fileName();
            m["path"] = p;
            m["dir"] = fi.absolutePath();
            bool isDir = fi.isDir();
            m["isDir"] = isDir;

            QString ext = fi.suffix().toLower();
            QString icon = "󰈔";
            if (isDir) icon = "󰉋";
            else if (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "webp" || ext == "svg") icon = "󰋩";
            else if (ext == "mp4" || ext == "mkv" || ext == "webm" || ext == "mov") icon = "󰕧";
            else if (ext == "mp3" || ext == "flac" || ext == "wav" || ext == "ogg") icon = "󰎆";
            else if (ext == "cpp" || ext == "h" || ext == "py" || ext == "lua" || ext == "qml" || ext == "sh" || ext == "conf" || ext == "json") icon = "󰈙";
            else if (ext == "pdf" || ext == "doc" || ext == "docx" || ext == "txt" || ext == "md") icon = "󰈦";
            else if (ext == "zip" || ext == "tar" || ext == "gz" || ext == "xz" || ext == "7z") icon = "󰀼";
            m["icon"] = icon;

            if (isDir) {
                m["sizeStr"] = "Папка";
            } else {
                qint64 sz = fi.size();
                if (sz < 1024) m["sizeStr"] = QString::number(sz) + " B";
                else if (sz < 1024 * 1024) m["sizeStr"] = QString::number(sz / 1024.0, 'f', 1) + " KB";
                else m["sizeStr"] = QString::number(sz / (1024.0 * 1024.0), 'f', 1) + " MB";
            }
            results.append(m);
        }
        m_fileResults = results;
        m_isSearching = false;
        emit fileResultsChanged();
        emit isSearchingChanged();
    });

    m_pkgSearchProc = new QProcess(this);
    connect(m_pkgSearchProc, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        QString out = QString::fromUtf8(m_pkgSearchProc->readAllStandardOutput());
        const QStringList lines = out.split('\n');
        QVariantList parsed;

        for (int i = 0; i < lines.size(); ++i) {
            QString line = lines[i];
            if (line.isEmpty() || line.startsWith(' ') || line.startsWith('\t')) continue;
            int slashIdx = line.indexOf('/');
            if (slashIdx <= 0) continue;

            QString repo = line.left(slashIdx).trimmed();
            QString rest = line.mid(slashIdx + 1).trimmed();
            QStringList tokens = rest.split(' ', Qt::SkipEmptyParts);
            if (tokens.isEmpty()) continue;

            QString pkgName = tokens[0];
            QString version = tokens.size() > 1 ? tokens[1] : "";
            bool installed = line.contains("[installed") || line.contains("[установлен") || line.contains("[Installed");

            QString desc;
            if (i + 1 < lines.size() && (lines[i + 1].startsWith(' ') || lines[i + 1].startsWith('\t'))) {
                desc = lines[i + 1].trimmed();
                ++i;
            }

            QVariantMap item;
            item["repo"] = repo;
            item["name"] = pkgName;
            item["version"] = version;
            item["description"] = desc.isEmpty() ? pkgName : desc;
            item["installed"] = installed;
            parsed.append(item);
        }

        QString qLower = m_currentSearchQuery.toLower();
        std::sort(parsed.begin(), parsed.end(), [&qLower](const QVariant &a, const QVariant &b) {
            QVariantMap ma = a.toMap(), mb = b.toMap();
            QString na = ma["name"].toString().toLower();
            QString nb = mb["name"].toString().toLower();
            bool exactA = (na == qLower), exactB = (nb == qLower);
            if (exactA != exactB) return exactA;
            bool prefA = na.startsWith(qLower), prefB = nb.startsWith(qLower);
            if (prefA != prefB) return prefA;
            bool aurA = (ma["repo"].toString() == "aur"), aurB = (mb["repo"].toString() == "aur");
            if (aurA != aurB) return !aurA;
            return na < nb;
        });

        if (parsed.size() > 80) parsed = parsed.mid(0, 80);
        m_packageResults = parsed;
        m_isSearchingPackages = false;
        emit packageResultsChanged();
        emit isSearchingPackagesChanged();
    });

    refresh();
}

void AppsManager::refresh() {
    scanDesktopFiles();
}

void AppsManager::scanDesktopFiles() {
    m_apps.clear();
    m_hiddenApps.clear();

    QString home = QDir::homePath();
    QString localAppsDir = home + "/.local/share/applications";
    QStringList dirs = {
        localAppsDir,
        home + "/.local/share/flatpak/exports/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications"
    };

    QSet<QString> seenEntries;
    QSet<QString> seenNames;

    for (const auto &d : dirs) {
        QDir dir(d);
        if (!dir.exists()) continue;
        bool isLocalDir = (d == localAppsDir);

        for (const auto &entry : dir.entryList({"*.desktop"}, QDir::Files)) {
            if (seenEntries.contains(entry)) continue;

            QString fullPath = dir.filePath(entry);
            QFile file(fullPath);
            if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;

            QString name, exec, icon, comment;
            QStringList categories;
            bool noDisplay = false;
            bool hiddenByHySett = false;

            QTextStream in(&file);
            while (!in.atEnd()) {
                QString line = in.readLine().trimmed();
                int eq = line.indexOf('=');
                if (eq == -1) continue;
                QString k = line.left(eq).trimmed();
                QString v = line.mid(eq + 1).trimmed();

                if (k == "Name" && name.isEmpty()) name = v;
                else if (k == "Exec" && exec.isEmpty()) {
                    QStringList parts = v.split(' ');
                    QStringList clean;
                    for (const auto &p : parts) {
                        if (!p.startsWith('%')) clean.append(p);
                    }
                    exec = clean.join(' ');
                }
                else if (k == "Icon" && icon.isEmpty()) icon = v;
                else if (k == "Comment" && comment.isEmpty()) comment = v;
                else if ((k == "NoDisplay" || k == "Hidden") && v.compare("true", Qt::CaseInsensitive) == 0) noDisplay = true;
                else if (k == "X-HySett-Hidden" && v.compare("true", Qt::CaseInsensitive) == 0) hiddenByHySett = true;
                else if (k == "Categories") categories = v.split(';', Qt::SkipEmptyParts);
            }

            seenEntries.insert(entry);

            if (isLocalDir && hiddenByHySett && noDisplay) {
                QVariantMap hm;
                hm["name"] = name.isEmpty() ? entry : name;
                hm["exec"] = exec;
                hm["icon"] = icon.isEmpty() ? "application-x-executable" : icon;
                hm["comment"] = comment.isEmpty() ? exec : comment;
                hm["desktopPath"] = fullPath;
                hm["desktopId"] = entry;
                hm["isLocal"] = true;
                m_hiddenApps.append(hm);
                continue;
            }

            if (!noDisplay && !name.isEmpty() && !exec.isEmpty() && !seenNames.contains(name)) {
                seenNames.insert(name);
                QVariantMap m;
                m["name"] = name;
                m["exec"] = exec;
                m["icon"] = icon.isEmpty() ? "application-x-executable" : icon;
                m["comment"] = comment.isEmpty() ? exec : comment;
                m["categories"] = categories;
                m["desktopPath"] = fullPath;
                m["desktopId"] = entry;
                m["isLocal"] = isLocalDir;
                m_apps.append(m);
            }
        }
    }

    auto sortByName = [](const QVariant &a, const QVariant &b) {
        return a.toMap()["name"].toString().toLower() < b.toMap()["name"].toString().toLower();
    };
    std::sort(m_apps.begin(), m_apps.end(), sortByName);
    std::sort(m_hiddenApps.begin(), m_hiddenApps.end(), sortByName);

    emit appsChanged();
}

void AppsManager::launchApp(const QString &exec) {
    if (exec.isEmpty()) return;
    QProcess::startDetached("sh", {"-c", exec + " &"});
}

QVariantMap AppsManager::getAppUninstallInfo(const QString &desktopPath, const QString &exec) {
    QVariantMap info;
    QString home = QDir::homePath();
    QFileInfo fi(desktopPath);
    QString fileName = fi.fileName();

    bool isLocal = desktopPath.startsWith(home + "/.local/share/applications");
    bool hasSys = QFileInfo::exists("/usr/share/applications/" + fileName) ||
                  QFileInfo::exists("/usr/local/share/applications/" + fileName);

    info["desktopPath"] = desktopPath;
    info["isLocal"] = isLocal;
    info["hasSystemCounterpart"] = hasSys;
    info["packageName"] = "";
    info["packageVersion"] = "";
    info["flatpakId"] = "";

    if (desktopPath.contains("flatpak") || exec.contains("flatpak ")) {
        QString fpId = fileName;
        if (fpId.endsWith(".desktop")) fpId.chop(8);
        info["flatpakId"] = fpId;
        return info;
    }

    auto queryPacmanOwner = [](const QString &targetPath, QString &outName, QString &outVer) -> bool {
        if (targetPath.isEmpty() || !QFileInfo::exists(targetPath)) return false;
        QProcess proc;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("LC_ALL", "C");
        proc.setProcessEnvironment(env);
        proc.start("pacman", {"-Qo", targetPath});
        if (!proc.waitForFinished(1500) || proc.exitCode() != 0) return false;
        QString out = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        int idx = out.indexOf(" is owned by ");
        if (idx == -1) return false;
        QString pkgPart = out.mid(idx + 13).trimmed();
        QStringList parts = pkgPart.split(' ', Qt::SkipEmptyParts);
        if (!parts.isEmpty()) {
            outName = parts[0];
            if (parts.size() > 1) outVer = parts[1];
            return true;
        }
        return false;
    };

    QString pkgName, pkgVer;
    QString checkPath = desktopPath;
    if (isLocal && hasSys) {
        if (QFileInfo::exists("/usr/share/applications/" + fileName))
            checkPath = "/usr/share/applications/" + fileName;
        else
            checkPath = "/usr/local/share/applications/" + fileName;
    }

    if (!queryPacmanOwner(checkPath, pkgName, pkgVer)) {
        QString firstToken = exec.trimmed().split(' ', Qt::SkipEmptyParts).value(0);
        firstToken.remove('"');
        firstToken.remove('\'');
        QString binPath = firstToken.startsWith('/') ? firstToken : QStandardPaths::findExecutable(firstToken);
        if (!binPath.isEmpty()) {
            queryPacmanOwner(binPath, pkgName, pkgVer);
        }
    }

    info["packageName"] = pkgName;
    info["packageVersion"] = pkgVer;
    return info;
}

bool AppsManager::removeOrHideShortcut(const QString &desktopPath) {
    if (desktopPath.isEmpty()) return false;
    QString home = QDir::homePath();
    QString localDir = home + "/.local/share/applications";
    QDir().mkpath(localDir);

    QFileInfo fi(desktopPath);
    QString fileName = fi.fileName();
    QString localPath = localDir + "/" + fileName;
    bool isLocal = (fi.absolutePath() == QDir(localDir).absolutePath());
    bool hasSys = QFileInfo::exists("/usr/share/applications/" + fileName) ||
                  QFileInfo::exists("/usr/local/share/applications/" + fileName);

    if (isLocal && !hasSys) {
        bool ok = QFile::remove(desktopPath);
        refresh();
        return ok;
    }

    QFile srcFile(desktopPath);
    QString content;
    if (srcFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        content = QString::fromUtf8(srcFile.readAll());
        srcFile.close();
    } else {
        content = "[Desktop Entry]\nType=Application\nName=" + fileName + "\n";
    }

    QStringList lines = content.split('\n');
    QStringList outLines;
    bool hasNoDisplay = false;
    bool hasHySettMark = false;

    for (const QString &l : lines) {
        QString tr = l.trimmed();
        if (tr.startsWith("NoDisplay=")) {
            outLines.append("NoDisplay=true");
            hasNoDisplay = true;
        } else if (tr.startsWith("X-HySett-Hidden=")) {
            outLines.append("X-HySett-Hidden=true");
            hasHySettMark = true;
        } else {
            outLines.append(l);
        }
    }
    if (!hasNoDisplay) outLines.append("NoDisplay=true");
    if (!hasHySettMark) outLines.append("X-HySett-Hidden=true");

    QFile dstFile(localPath);
    if (dstFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&dstFile);
        out << outLines.join('\n');
        dstFile.close();
        refresh();
        return true;
    }
    return false;
}

bool AppsManager::unhideShortcut(const QString &desktopPath) {
    if (desktopPath.isEmpty()) return false;
    QFileInfo fi(desktopPath);
    QString entry = fi.fileName();
    QString fullPath = fi.absoluteFilePath();

    bool hasSys = QFileInfo::exists("/usr/share/applications/" + entry) ||
                  QFileInfo::exists("/usr/local/share/applications/" + entry);
    if (hasSys) {
        QFile::remove(fullPath);
        refresh();
        return true;
    }

    QFile file(fullPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    QString content = QString::fromUtf8(file.readAll());
    file.close();

    content.replace("NoDisplay=true", "NoDisplay=false");
    content.remove("X-HySett-Hidden=true\n");
    content.remove("X-HySett-Hidden=true");
    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        file.write(content.toUtf8());
        file.close();
        refresh();
        return true;
    }
    return false;
}

void AppsManager::restoreHiddenShortcuts() {
    QString localDir = QDir::homePath() + "/.local/share/applications";
    QDir dir(localDir);
    if (!dir.exists()) return;

    for (const QString &entry : dir.entryList({"*.desktop"}, QDir::Files)) {
        QString fullPath = dir.filePath(entry);
        QFile file(fullPath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) continue;
        QString content = QString::fromUtf8(file.readAll());
        file.close();

        if (!content.contains("X-HySett-Hidden=true")) continue;

        bool hasSys = QFileInfo::exists("/usr/share/applications/" + entry) ||
                      QFileInfo::exists("/usr/local/share/applications/" + entry);
        if (hasSys) {
            QFile::remove(fullPath);
        } else {
            content.replace("NoDisplay=true", "NoDisplay=false");
            content.remove("X-HySett-Hidden=true\n");
            content.remove("X-HySett-Hidden=true");
            if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                file.write(content.toUtf8());
                file.close();
            }
        }
    }
    refresh();
}

void AppsManager::searchPackages(const QString &query) {
    QString q = query.trimmed();
    if (q.isEmpty()) {
        clearPackageSearch();
        return;
    }

    if (m_pkgSearchProc->state() != QProcess::NotRunning) {
        m_pkgSearchProc->kill();
        m_pkgSearchProc->waitForFinished(80);
    }

    m_currentSearchQuery = q;
    m_isSearchingPackages = true;
    emit isSearchingPackagesChanged();

    QString safeQ = q;
    safeQ.replace("'", "");
    safeQ.replace("\"", "");
    safeQ.replace(";", "");
    safeQ.replace("`", "");
    safeQ.replace("$", "");

    QString cmd = QString(
        "if command -v yay >/dev/null 2>&1; then "
        "  yay -Ss --color never -- '%1' 2>/dev/null | head -n 180; "
        "elif command -v paru >/dev/null 2>&1; then "
        "  paru -Ss --color never -- '%1' 2>/dev/null | head -n 180; "
        "else "
        "  pacman -Ss --color never -- '%1' 2>/dev/null | head -n 180; "
        "fi"
    ).arg(safeQ);

    m_pkgSearchProc->start("sh", {"-c", cmd});
}

void AppsManager::clearPackageSearch() {
    if (m_pkgSearchProc->state() != QProcess::NotRunning) {
        m_pkgSearchProc->kill();
        m_pkgSearchProc->waitForFinished(80);
    }
    m_packageResults.clear();
    m_isSearchingPackages = false;
    emit packageResultsChanged();
    emit isSearchingPackagesChanged();
}

void AppsManager::resetPkgActionState() {
    m_isPkgActionRunning = false;
    m_pkgActionFinished = false;
    m_pkgActionSuccess = false;
    m_pkgActionStatus.clear();
    emit pkgActionStateChanged();
}

void AppsManager::executePackageAction(const QString &action, const QString &packageName,
                                       const QString &repo, const QString &flatpakId,
                                       const QString &desktopPath, const QString &password) {
    if (m_isPkgActionRunning) return;

    if (packageName.isEmpty() && flatpakId.isEmpty()) {
        removeOrHideShortcut(desktopPath);
        m_pkgActionFinished = true;
        m_pkgActionSuccess = true;
        m_pkgActionStatus = "Ярлык удалён";
        emit pkgActionStateChanged();
        return;
    }

    m_isPkgActionRunning = true;
    m_pkgActionFinished = false;
    m_pkgActionSuccess = false;
    m_pkgActionStatus = (action == "install")
        ? QString("Установка пакета %1...").arg(packageName)
        : QString("Удаление пакета %1...").arg(!packageName.isEmpty() ? packageName : flatpakId);
    emit pkgActionStateChanged();

    // Создаём временный askpass-скрипт в /tmp с правами 700
    QString askpassPath = QString("/tmp/hysett_askpass_%1.sh").arg(QCoreApplication::applicationPid());
    QFile askFile(askpassPath);
    if (askFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        askFile.write("#!/bin/sh\nprintf '%s\\n' \"$HYSETT_SUDO_PASS\"\n");
        askFile.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
        askFile.close();
    }

    QString safePkg = packageName;
    safePkg.replace("'", "");
    safePkg.replace(";", "");
    QString safeFp = flatpakId;
    safeFp.replace("'", "");
    safeFp.replace(";", "");

    QString cmd;
    if (action == "install") {
        if (repo == "aur") {
            cmd = QString(
                "export SUDO_ASKPASS='%1'; "
                "printf '%s\\n' \"$HYSETT_SUDO_PASS\" | sudo -S -p '' -v 2>/dev/null || exit 42; "
                "if command -v yay >/dev/null 2>&1; then "
                "  yay -S --noconfirm --needed --answerdiff None --answerclean None --sudo sudo --sudoflags '-A' -- '%2'; "
                "elif command -v paru >/dev/null 2>&1; then "
                "  paru -S --noconfirm --needed --skipreview --sudo sudo --sudoflags '-A' -- '%2'; "
                "else "
                "  sudo -A pacman -S --noconfirm --needed -- '%2'; "
                "fi"
            ).arg(askpassPath, safePkg);
        } else {
            cmd = QString(
                "export SUDO_ASKPASS='%1'; "
                "printf '%s\\n' \"$HYSETT_SUDO_PASS\" | sudo -S -p '' -v 2>/dev/null || exit 42; "
                "sudo -A pacman -S --noconfirm --needed -- '%2'"
            ).arg(askpassPath, safePkg);
        }
    } else {
        if (!safePkg.isEmpty()) {
            cmd = QString(
                "export SUDO_ASKPASS='%1'; "
                "printf '%s\\n' \"$HYSETT_SUDO_PASS\" | sudo -S -p '' -v 2>/dev/null || exit 42; "
                "sudo -A pacman -Rns --noconfirm -- '%2'"
            ).arg(askpassPath, safePkg);
        } else {
            cmd = QString(
                "export SUDO_ASKPASS='%1'; "
                "flatpak uninstall -y --noninteractive '%2' || "
                "(printf '%s\\n' \"$HYSETT_SUDO_PASS\" | sudo -S -p '' flatpak uninstall -y --noninteractive '%2')"
            ).arg(askpassPath, safeFp);
        }
    }

    if (m_pkgActionProc) {
        m_pkgActionProc->deleteLater();
    }
    m_pkgActionProc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("HYSETT_SUDO_PASS", password);
    env.insert("SUDO_ASKPASS", askpassPath);
    m_pkgActionProc->setProcessEnvironment(env);

    connect(m_pkgActionProc, &QProcess::finished, this, [this, askpassPath, desktopPath, action](int exitCode, QProcess::ExitStatus) {
        QFile::remove(askpassPath);
        QString errOut = QString::fromUtf8(m_pkgActionProc->readAllStandardError()).trimmed();
        m_isPkgActionRunning = false;
        m_pkgActionFinished = true;

        if (exitCode == 0) {
            m_pkgActionSuccess = true;
            m_pkgActionStatus = (action == "install")
                ? "✔ Пакет успешно установлен!"
                : "✔ Пакет успешно удалён!";

            if (!desktopPath.isEmpty()) {
                QFileInfo fi(desktopPath);
                QString fileName = fi.fileName();
                QString localPath = QDir::homePath() + "/.local/share/applications/" + fileName;
                bool sysExists = QFileInfo::exists("/usr/share/applications/" + fileName) ||
                                 QFileInfo::exists("/usr/local/share/applications/" + fileName);
                if (!sysExists && QFileInfo::exists(localPath)) {
                    QFile::remove(localPath);
                }
            }
            refresh();
            if (!m_currentSearchQuery.isEmpty()) {
                searchPackages(m_currentSearchQuery);
            }
        } else if (exitCode == 42) {
            m_pkgActionSuccess = false;
            m_pkgActionStatus = "❌ Неверный пароль sudo. Попробуйте ещё раз.";
        } else {
            m_pkgActionSuccess = false;
            QString lastLine = errOut.split('\n', Qt::SkipEmptyParts).value(0);
            m_pkgActionStatus = lastLine.isEmpty()
                ? "❌ Ошибка выполнения команды (возможно пакет зависит от других)."
                : ("❌ Ошибка: " + lastLine.left(110));
        }
        emit pkgActionStateChanged();
    });

    m_pkgActionProc->start("sh", {"-c", cmd});
}

void AppsManager::clearFileSearch() {
    if (m_searchProc->state() != QProcess::NotRunning) {
        m_searchProc->kill();
        m_searchProc->waitForFinished(100);
    }
    m_fileResults.clear();
    m_isSearching = false;
    emit fileResultsChanged();
    emit isSearchingChanged();
}

void AppsManager::searchFiles(const QString &query, bool wholeSystem) {
    QString q = query.trimmed();
    if (q.isEmpty()) {
        clearFileSearch();
        return;
    }

    if (m_searchProc->state() != QProcess::NotRunning) {
        m_searchProc->kill();
        m_searchProc->waitForFinished(80);
    }

    m_isSearching = true;
    emit isSearchingChanged();

    QString safeQ = q;
    safeQ.replace("'", "");
    safeQ.replace("\"", "");
    safeQ.replace(";", "");

    QString rootDir = wholeSystem ? "/" : QDir::homePath();
    QString cmd;
    if (wholeSystem) {
        cmd = QString("if command -v fd >/dev/null 2>&1; then "
                      "fd -H -i --max-results 70 --exclude /proc --exclude /sys --exclude /dev --exclude /run -- '%1' / 2>/dev/null; "
                      "else "
                      "find / \\( -path /proc -o -path /sys -o -path /dev -o -path /run \\) -prune -o -iname '*%1*' -print 2>/dev/null | head -n 70; "
                      "fi").arg(safeQ);
    } else {
        cmd = QString("if command -v fd >/dev/null 2>&1; then "
                      "fd -H -i --max-results 70 --exclude .cache --exclude .local/share/Trash -- '%1' '%2' 2>/dev/null; "
                      "else "
                      "find '%2' \\( -path '*/.cache*' -o -path '*/.local/share/Trash*' \\) -prune -o -iname '*%1*' -print 2>/dev/null | head -n 70; "
                      "fi").arg(safeQ, rootDir);
    }

    m_searchProc->start("sh", {"-c", cmd});
}

void AppsManager::openFile(const QString &path) {
    if (path.isEmpty()) return;
    QProcess::startDetached("xdg-open", {path});
}

void AppsManager::openContainingFolder(const QString &path) {
    if (path.isEmpty()) return;
    QFileInfo fi(path);
    QString folder = fi.isDir() ? fi.absoluteFilePath() : fi.absolutePath();
    QProcess::startDetached("xdg-open", {folder});
}

void AppsManager::copyPath(const QString &path) {
    if (path.isEmpty()) return;
    QProcess::startDetached("wl-copy", {path});
}
