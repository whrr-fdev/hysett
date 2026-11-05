#include "AutostartManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>

AutostartManager::AutostartManager(QObject *parent) : QObject(parent) {
    reload();
}

QString AutostartManager::luaPath() const {
    return QDir::homePath() + "/.config/hypr/hyprland.lua";
}

void AutostartManager::reload() {
    m_entries.clear();
    m_items.clear();

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    bool inAutostart = false;
    for (int i = 0; i < lines.size(); ++i) {
        QString line = lines[i].trimmed();
        if (line.contains("hl.on(\"hyprland.start\"") || line.contains("hl.on('hyprland.start'")) {
            inAutostart = true;
            continue;
        }
        if (inAutostart && (line.startsWith("end)") || line == "end")) {
            break;
        }

        if (inAutostart && (line.contains("hl.exec_cmd"))) {
            bool en = !line.startsWith("--");
            // Извлекаем команду
            QRegularExpression reCmd("hl\\.exec_cmd\\(\\s*\"([^\"]+)\"|'([^']+)'");
            auto mCmd = reCmd.match(line);
            QString cmd;
            if (mCmd.hasMatch()) {
                cmd = mCmd.captured(1).isEmpty() ? mCmd.captured(2) : mCmd.captured(1);
            }

            // Извлекаем workspace если есть
            QString ws;
            QRegularExpression reWs("workspace\\s*=\\s*\"([^\"]+)\"|'([^']+)'");
            auto mWs = reWs.match(line);
            if (mWs.hasMatch()) {
                ws = mWs.captured(1).isEmpty() ? mWs.captured(2) : mWs.captured(1);
            }

            if (!cmd.isEmpty()) {
                Entry e{ i, en, cmd, ws };
                m_entries.append(e);

                QVariantMap vm;
                vm["lineIdx"] = i;
                vm["enabled"] = en;
                vm["cmd"] = cmd;
                vm["workspace"] = ws;
                m_items.append(vm);
            }
        }
    }
    emit itemsChanged();
}

void AutostartManager::syncToFile() {
    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    for (const auto &e : m_entries) {
        if (e.lineIdx < lines.size()) {
            QString wsPart = e.workspace.isEmpty() ? "" : QString(", { workspace = \"%1\" }").arg(e.workspace);
            QString code = QString("hl.exec_cmd(\"%1\"%2)").arg(e.cmd, wsPart);
            lines[e.lineIdx] = (e.enabled ? "     " : "     --") + code;
        }
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }
}

void AutostartManager::toggleItem(int index, bool enabled) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    m_items[index] = vm;
    syncToFile();
    emit itemsChanged();
}

void AutostartManager::updateItem(int index, bool enabled, const QString &cmd, const QString &workspace) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    m_entries[index].cmd = cmd;
    m_entries[index].workspace = workspace;

    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    vm["cmd"] = cmd;
    vm["workspace"] = workspace;
    m_items[index] = vm;

    syncToFile();
    emit itemsChanged();
}

void AutostartManager::deleteItem(int index) {
    if (index < 0 || index >= m_entries.size()) return;
    int lineIdx = m_entries[index].lineIdx;

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    if (lineIdx < lines.size()) {
        lines.removeAt(lineIdx);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            for (const auto &l : lines) out << l << "\n";
        }
    }
    reload();
}

void AutostartManager::addItem(const QString &cmd, const QString &workspace) {
    if (cmd.trimmed().isEmpty()) return;

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    QString wsPart = workspace.isEmpty() ? "" : QString(", { workspace = \"%1\" }").arg(workspace);
    QString newLine = QString("     hl.exec_cmd(\"%1\"%2)").arg(cmd, wsPart);

    bool inserted = false;
    for (int i = 0; i < lines.size(); ++i) {
        if (lines[i].trimmed().startsWith("end)") && i > 0 && lines[i-1].contains("hl.exec_cmd")) {
            lines.insert(i, newLine);
            inserted = true;
            break;
        }
    }
    if (!inserted) {
        lines.append(newLine);
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }
    reload();
}
