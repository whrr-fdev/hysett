#include "BindsManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QStringList>
#include <QProcess>

namespace {

bool parseLuaQuotedBind(const QString &s, int startFrom, QString &outStr, int *afterIdx = nullptr) {
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

QString escapeLuaStr(QString raw) {
    raw.replace("\\\"", "\"");
    raw.replace("\\", "\\\\");
    raw.replace("\"", "\\\"");
    return raw;
}

bool isKnownLuaIdentifier(const QString &s) {
    static const QStringList kVars = {
        "terminal", "fileManager", "menu", "browser", "VPN",
        "screenshot_cmd", "region_cmd", "record_cmd"
    };
    return kVars.contains(s.trimmed());
}

} // namespace

BindsManager::BindsManager(QObject *parent) : QObject(parent) {
    reload();
}

QString BindsManager::luaPath() const {
    return QDir::homePath() + "/.config/hypr/hyprland.lua";
}

void BindsManager::reload() {
    m_entries.clear();
    m_items.clear();

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    for (int i = 0; i < lines.size(); ++i) {
        QString line = lines[i].trimmed();
        if ((line.startsWith("hl.bind(") || line.startsWith("--hl.bind(") || line.startsWith("-- hl.bind(")) &&
            line.contains("hl.dsp.exec_cmd(")) {
            bool en = !line.startsWith("--");

            QRegularExpression reKey("hl\\.bind\\(\\s*(mainMod\\s*\\.\\.\\s*\"[^\"]+\"|\"[^\"]+\")");
            auto mKey = reKey.match(line);
            QString keys;
            if (mKey.hasMatch()) {
                keys = mKey.captured(1);
                keys.replace(QRegularExpression("mainMod\\s*\\.\\.\\s*\""), "SUPER");
                keys.remove('\"');
                keys.replace("+  +", "+");
            }

            int execIdx = line.indexOf("hl.dsp.exec_cmd(");
            int openParen = line.indexOf('(', execIdx);
            QString cmd;
            if (openParen >= 0) {
                if (!parseLuaQuotedBind(line, openParen + 1, cmd, nullptr)) {
                    int closeParen = line.indexOf(')', openParen + 1);
                    if (closeParen > openParen + 1) {
                        cmd = line.mid(openParen + 1, closeParen - openParen - 1).trimmed();
                    }
                }
            }

            if (!keys.isEmpty() && !cmd.isEmpty()) {
                BindEntry be{ i, en, keys.trimmed(), cmd.trimmed() };
                m_entries.append(be);

                QVariantMap vm;
                vm["lineIdx"] = i;
                vm["enabled"] = en;
                vm["keys"] = keys.trimmed();
                vm["cmd"] = cmd.trimmed();
                m_items.append(vm);
            }
        }
    }
    emit itemsChanged();
}

void BindsManager::syncToFile() {
    // Оставлено для совместимости, но изменения применяются точечно в toggleItem / updateItem
}

void BindsManager::toggleItem(int index, bool enabled) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    m_items[index] = vm;

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
            lines[lineIdx] = (enabled ? "" : "--") + tr;
            if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                QTextStream out(&file);
                for (const auto &l : lines) out << l << "\n";
                file.close();
            }
        }
    }
    QProcess::startDetached("hyprctl", {"reload"});
    emit itemsChanged();
}

void BindsManager::updateItem(int index, bool enabled, const QString &keys, const QString &cmd) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    m_entries[index].keys = keys;
    m_entries[index].cmd = cmd;

    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    vm["keys"] = keys;
    vm["cmd"] = cmd;
    m_items[index] = vm;

    int lineIdx = m_entries[index].lineIdx;
    QFile file(luaPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QStringList lines;
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();

        if (lineIdx >= 0 && lineIdx < lines.size()) {
            // Сохраняем возможный хвост опций ", { locked = true, ... })"
            QString oldLine = lines[lineIdx].trimmed();
            QString trailingOpts = ")";
            int execIdx = oldLine.indexOf("hl.dsp.exec_cmd(");
            if (execIdx >= 0) {
                int openP = oldLine.indexOf('(', execIdx);
                QString dummy;
                int afterStr = -1;
                if (parseLuaQuotedBind(oldLine, openP + 1, dummy, &afterStr)) {
                    int closeExec = oldLine.indexOf(')', afterStr);
                    if (closeExec >= 0) trailingOpts = oldLine.mid(closeExec + 1);
                } else {
                    int closeExec = oldLine.indexOf(')', openP + 1);
                    if (closeExec >= 0) trailingOpts = oldLine.mid(closeExec + 1);
                }
            }
            if (trailingOpts.isEmpty()) trailingOpts = ")";

            QString keyLua = keys.trimmed();
            if (keyLua.startsWith("SUPER")) {
                keyLua = "mainMod .. \"" + escapeLuaStr(keyLua.mid(5)) + "\"";
            } else {
                keyLua = "\"" + escapeLuaStr(keyLua) + "\"";
            }
            QString cmdLua = isKnownLuaIdentifier(cmd) ? cmd.trimmed() : ("\"" + escapeLuaStr(cmd.trimmed()) + "\"");
            QString code = QString("hl.bind(%1, hl.dsp.exec_cmd(%2)%3").arg(keyLua, cmdLua, trailingOpts);
            lines[lineIdx] = (enabled ? "" : "--") + code;

            if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                QTextStream out(&file);
                for (const auto &l : lines) out << l << "\n";
                file.close();
            }
        }
    }
    QProcess::startDetached("hyprctl", {"reload"});
    emit itemsChanged();
}

void BindsManager::deleteItem(int index) {
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
    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}

void BindsManager::addItem(const QString &keys, const QString &cmd) {
    if (keys.trimmed().isEmpty() || cmd.trimmed().isEmpty()) return;

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    QString keyLua = keys.trimmed();
    if (keyLua.startsWith("SUPER")) {
        keyLua = "mainMod .. \"" + escapeLuaStr(keyLua.mid(5)) + "\"";
    } else {
        keyLua = "\"" + escapeLuaStr(keyLua) + "\"";
    }
    QString cmdLua = isKnownLuaIdentifier(cmd) ? cmd.trimmed() : ("\"" + escapeLuaStr(cmd.trimmed()) + "\"");
    QString newLine = QString("hl.bind(%1, hl.dsp.exec_cmd(%2))").arg(keyLua, cmdLua);

    lines.append(newLine);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}
