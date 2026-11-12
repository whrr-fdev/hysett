#include "AutostartManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QProcess>

namespace {

bool parseLuaQuoted(const QString &s, int startFrom, QString &outStr, int *afterIdx = nullptr) {
    int n = s.size();
    int i = startFrom;
    while (i < n && s[i].isSpace()) ++i;
    if (i >= n || (s[i] != '"' && s[i] != '\'')) return false;
    QChar q = s[i++];
    QString res;
    while (i < n) {
        QChar c = s[i++];
        if (c == '\\' && i < n) {
            QChar next = s[i++];
            if (next == '"' || next == '\'' || next == '\\') res.append(next);
            else { res.append('\\'); res.append(next); }
        } else if (c == q) {
            outStr = res;
            if (afterIdx) *afterIdx = i;
            return true;
        } else {
            res.append(c);
        }
    }
    return false;
}

QString escapeLuaDoubleQuoted(QString raw) {
    // Если строка уже содержит \" от старого ввода, нормализуем перед экранированием
    raw.replace("\\\"", "\"");
    raw.replace("\\", "\\\\");
    raw.replace("\"", "\\\"");
    return raw;
}

} // namespace

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

        if (inAutostart && line.contains("hl.exec_cmd")) {
            bool en = !line.startsWith("--");
            int callIdx = line.indexOf("hl.exec_cmd");
            int openParen = line.indexOf('(', callIdx);
            if (openParen < 0) continue;

            QString cmd;
            int afterCmdIdx = -1;
            if (!parseLuaQuoted(line, openParen + 1, cmd, &afterCmdIdx)) {
                continue;
            }

            // Ищем workspace ТОЛЬКО в хвосте строки после закрывающей кавычки первого аргумента!
            QString ws;
            if (afterCmdIdx > 0 && afterCmdIdx < line.size()) {
                QString tail = line.mid(afterCmdIdx);
                QRegularExpression reWs("workspace\\s*=\\s*");
                auto mWs = reWs.match(tail);
                if (mWs.hasMatch()) {
                    parseLuaQuoted(tail, mWs.capturedEnd(), ws, nullptr);
                }
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
        if (e.lineIdx >= 0 && e.lineIdx < lines.size()) {
            QString wsPart = e.workspace.isEmpty() ? "" : QString(", { workspace = \"%1\" }").arg(escapeLuaDoubleQuoted(e.workspace));
            QString code = QString("hl.exec_cmd(\"%1\"%2)").arg(escapeLuaDoubleQuoted(e.cmd), wsPart);
            lines[e.lineIdx] = (e.enabled ? "     " : "     --") + code;
        }
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
}

void AutostartManager::toggleItem(int index, bool enabled) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    m_items[index] = vm;

    // Меняем только префикс комментария у целевой строки, не трогая остальные строки
    int lineIdx = m_entries[index].lineIdx;
    QFile file(luaPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QStringList lines;
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();

        if (lineIdx >= 0 && lineIdx < lines.size()) {
            QString tr = lines[lineIdx].trimmed();
            while (tr.startsWith('-')) tr = tr.mid(1).trimmed();
            lines[lineIdx] = (enabled ? "     " : "     --") + tr;
            if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                QTextStream out(&file);
                for (const auto &l : lines) out << l << "\n";
                file.close();
            }
        }
    }
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

    int lineIdx = m_entries[index].lineIdx;
    QFile file(luaPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QStringList lines;
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();

        if (lineIdx >= 0 && lineIdx < lines.size()) {
            QString wsPart = workspace.isEmpty() ? "" : QString(", { workspace = \"%1\" }").arg(escapeLuaDoubleQuoted(workspace));
            QString code = QString("hl.exec_cmd(\"%1\"%2)").arg(escapeLuaDoubleQuoted(cmd), wsPart);
            lines[lineIdx] = (enabled ? "     " : "     --") + code;
            if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                QTextStream out(&file);
                for (const auto &l : lines) out << l << "\n";
                file.close();
            }
        }
    }
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

    if (lineIdx >= 0 && lineIdx < lines.size()) {
        lines.removeAt(lineIdx);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream out(&file);
            for (const auto &l : lines) out << l << "\n";
            file.close();
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

    QString wsPart = workspace.isEmpty() ? "" : QString(", { workspace = \"%1\" }").arg(escapeLuaDoubleQuoted(workspace));
    QString newLine = QString("     hl.exec_cmd(\"%1\"%2)").arg(escapeLuaDoubleQuoted(cmd), wsPart);

    bool inserted = false;
    bool inAutostart = false;
    for (int i = 0; i < lines.size(); ++i) {
        QString tr = lines[i].trimmed();
        if (tr.contains("hl.on(\"hyprland.start\"") || tr.contains("hl.on('hyprland.start'")) {
            inAutostart = true;
            continue;
        }
        if (inAutostart && (tr.startsWith("end)") || tr == "end")) {
            lines.insert(i, newLine);
            inserted = true;
            break;
        }
    }
    if (!inserted) {
        lines.append(newLine);
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
    reload();
}
