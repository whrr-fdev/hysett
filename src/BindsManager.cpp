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

QString uncommentLine(const QString &line) {
    QString s = line;
    int idx = 0;
    while (idx < s.size() && s[idx].isSpace()) ++idx;
    if (s.mid(idx).startsWith("-- ")) return s.left(idx) + s.mid(idx + 3);
    if (s.mid(idx).startsWith("--")) return s.left(idx) + s.mid(idx + 2);
    return s;
}

QString formatKeyToLua(const QString &keys) {
    QString k = keys.trimmed();
    if (k.startsWith("SUPER")) {
        return "mainMod .. \"" + escapeLuaStr(k.mid(5)) + "\"";
    }
    if (k.contains("SUPER")) {
        QString replaced = "\"" + escapeLuaStr(k) + "\"";
        replaced.replace("SUPER", "\" .. mainMod .. \"");
        return replaced;
    }
    return "\"" + escapeLuaStr(k) + "\"";
}

// Находит запятую после первого аргумента hl.bind(key_expr, ...)
int findFirstArgComma(const QString &line, int afterBindParen) {
    bool inQuotes = false;
    QChar quoteChar;
    int depth = 0;
    for (int i = afterBindParen; i < line.size(); ++i) {
        QChar c = line[i];
        if (inQuotes) {
            if (c == '\\') { ++i; continue; }
            if (c == quoteChar) inQuotes = false;
        } else {
            if (c == '"' || c == '\'') { inQuotes = true; quoteChar = c; }
            else if (c == '(' || c == '{' || c == '[') ++depth;
            else if (c == ')' || c == '}' || c == ']') --depth;
            else if (c == ',' && depth == 0) return i;
        }
    }
    return -1;
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
        QString rawLine = lines[i];
        QString trimmed = rawLine.trimmed();

        // Пропускаем дублирующие строки авто-переключения Холста (-- [CANVAS_BIND])
        if (trimmed.contains("-- [CANVAS_BIND]")) continue;

        bool isBindStart = trimmed.startsWith("hl.bind(")
                        || trimmed.startsWith("--hl.bind(")
                        || trimmed.startsWith("-- hl.bind(");
        if (!isBindStart) continue;

        bool en = !trimmed.startsWith("--");
        QString cleanFirst = uncommentLine(rawLine).trimmed();
        if (cleanFirst.endsWith("-- [NORMAL_BIND]")) {
            cleanFirst = cleanFirst.left(cleanFirst.size() - 16).trimmed();
        }

        int bindIdx = cleanFirst.indexOf("hl.bind(");
        if (bindIdx < 0) continue;
        int openParen = bindIdx + 8;
        int commaIdx = findFirstArgComma(cleanFirst, openParen);
        if (commaIdx < 0) continue;

        QString keyExpr = cleanFirst.mid(openParen, commaIdx - openParen).trimmed();
        keyExpr.replace(QRegularExpression("mainMod\\s*\\.\\.\\s*\""), "SUPER");
        keyExpr.replace(QRegularExpression("\"\\s*\\.\\.\\s*mainMod\\s*\\.\\.\\s*\""), "SUPER");
        keyExpr.remove('"');
        keyExpr.replace("  ", " ");
        QString keys = keyExpr.trimmed();

        // Описание из комментария прямо над биндом
        QString desc;
        if (i > 0) {
            QString prev = lines[i - 1].trimmed();
            if (prev.startsWith("--") && !prev.startsWith("--hl.bind") && !prev.startsWith("-- hl.bind") && !prev.startsWith("---")) {
                desc = prev.mid(2).trimmed();
            }
        }

        QString afterComma = cleanFirst.mid(commaIdx + 1).trimmed();

        // Случай 1: Многострочная функция hl.bind(..., function() ... end)
        if (afterComma.startsWith("function(") && !afterComma.contains("end)")) {
            int endLine = i;
            QStringList bodyLines;
            bodyLines.append(afterComma);
            for (int j = i + 1; j < lines.size(); ++j) {
                QString cj = en ? lines[j] : uncommentLine(lines[j]);
                bodyLines.append(cj);
                QString tj = cj.trimmed();
                if (tj == "end)" || tj.startsWith("end,") || tj.startsWith("end )")) {
                    endLine = j;
                    break;
                }
            }

            QString fullBlock = bodyLines.join("\n").trimmed();
            QString trailingOpts = ")";
            if (fullBlock.endsWith(")")) {
                int lastEnd = fullBlock.lastIndexOf("end");
                if (lastEnd >= 0) {
                    trailingOpts = fullBlock.mid(lastEnd + 3);
                    fullBlock = fullBlock.left(lastEnd + 3);
                }
            }

            BindEntry be{ i, endLine, en, true, true, keys, fullBlock, trailingOpts, desc };
            m_entries.append(be);

            QVariantMap vm;
            vm["startLine"] = i;
            vm["endLine"] = endLine;
            vm["enabled"] = en;
            vm["isFunc"] = true;
            vm["isMultiline"] = true;
            vm["keys"] = keys;
            vm["cmd"] = fullBlock;
            vm["description"] = desc;
            m_items.append(vm);

            i = endLine;
            continue;
        }

        // Случай 2: Однострочный hl.dsp.exec_cmd(...)
        if (afterComma.contains("hl.dsp.exec_cmd(")) {
            int execIdx = cleanFirst.indexOf("hl.dsp.exec_cmd(", commaIdx);
            int openP = cleanFirst.indexOf('(', execIdx);
            QString cmd;
            QString trailingOpts = ")";
            if (openP >= 0) {
                int afterStr = -1;
                if (parseLuaQuotedBind(cleanFirst, openP + 1, cmd, &afterStr)) {
                    int closeExec = cleanFirst.indexOf(')', afterStr);
                    if (closeExec >= 0) trailingOpts = cleanFirst.mid(closeExec + 1);
                } else {
                    int closeExec = cleanFirst.indexOf(')', openP + 1);
                    if (closeExec > openP + 1) {
                        cmd = cleanFirst.mid(openP + 1, closeExec - openP - 1).trimmed();
                        trailingOpts = cleanFirst.mid(closeExec + 1);
                    }
                }
            }
            if (!keys.isEmpty() && !cmd.isEmpty()) {
                BindEntry be{ i, i, en, false, false, keys, cmd.trimmed(), trailingOpts, desc };
                m_entries.append(be);

                QVariantMap vm;
                vm["startLine"] = i;
                vm["endLine"] = i;
                vm["enabled"] = en;
                vm["isFunc"] = false;
                vm["isMultiline"] = false;
                vm["keys"] = keys;
                vm["cmd"] = cmd.trimmed();
                vm["description"] = desc;
                m_items.append(vm);
            }
            continue;
        }

        // Случай 3: Однострочные Lua-функции и диспетчеры (hl.dsp.window.*, function() ... end)
        if (cleanFirst.endsWith(")")) {
            QString expr = afterComma.left(afterComma.size() - 1).trimmed();
            BindEntry be{ i, i, en, true, false, keys, expr, ")", desc };
            m_entries.append(be);

            QVariantMap vm;
            vm["startLine"] = i;
            vm["endLine"] = i;
            vm["enabled"] = en;
            vm["isFunc"] = true;
            vm["isMultiline"] = false;
            vm["keys"] = keys;
            vm["cmd"] = expr;
            vm["description"] = desc;
            m_items.append(vm);
        }
    }
    emit itemsChanged();
}

void BindsManager::toggleItem(int index, bool enabled) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    m_items[index] = vm;

    int sLine = m_entries[index].startLine;
    int eLine = m_entries[index].endLine;

    QFile file(luaPath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QStringList lines;
        QTextStream in(&file);
        while (!in.atEnd()) lines.append(in.readLine());
        file.close();

        for (int l = sLine; l <= eLine && l >= 0 && l < lines.size(); ++l) {
            QString clean = uncommentLine(lines[l]);
            lines[l] = enabled ? clean : ("-- " + clean);
        }
        if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream out(&file);
            for (const auto &l : lines) out << l << "\n";
            file.close();
        }
    }
    QProcess::startDetached("hyprctl", {"reload"});
    emit itemsChanged();
}

void BindsManager::updateItem(int index, bool enabled, const QString &keys, const QString &cmd) {
    if (index < 0 || index >= m_entries.size()) return;
    BindEntry &be = m_entries[index];

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    if (be.startLine < 0 || be.endLine >= lines.size()) return;

    QString normalMarker;
    if (lines[be.startLine].contains("-- [NORMAL_BIND]")) {
        normalMarker = " -- [NORMAL_BIND]";
    }

    QString keyLua = formatKeyToLua(keys);
    QStringList replacementLines;

    if (!be.isFunc) {
        QString cmdLua = isKnownLuaIdentifier(cmd) ? cmd.trimmed() : ("\"" + escapeLuaStr(cmd.trimmed()) + "\"");
        QString lineCode = QString("hl.bind(%1, hl.dsp.exec_cmd(%2)%3%4")
                               .arg(keyLua, cmdLua, be.trailingOpts.isEmpty() ? ")" : be.trailingOpts, normalMarker);
        replacementLines.append(enabled ? lineCode : ("-- " + lineCode));
    } else {
        QString trimmedCmd = cmd.trimmed();
        QString opts = be.trailingOpts.isEmpty() ? ")" : be.trailingOpts;
        QString fullBind = QString("hl.bind(%1, %2%3%4").arg(keyLua, trimmedCmd, opts, normalMarker);
        for (const QString &ln : fullBind.split('\n')) {
            replacementLines.append(enabled ? ln : ("-- " + ln));
        }
    }

    for (int l = be.endLine; l >= be.startLine; --l) {
        lines.removeAt(l);
    }
    for (int k = 0; k < replacementLines.size(); ++k) {
        lines.insert(be.startLine + k, replacementLines[k]);
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }

    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}

void BindsManager::deleteItem(int index) {
    if (index < 0 || index >= m_entries.size()) return;
    int sLine = m_entries[index].startLine;
    int eLine = m_entries[index].endLine;

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    if (sLine >= 0 && eLine < lines.size()) {
        for (int l = eLine; l >= sLine; --l) {
            lines.removeAt(l);
        }
        if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            QTextStream out(&file);
            for (const auto &l : lines) out << l << "\n";
            file.close();
        }
    }
    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}

void BindsManager::addItem(const QString &keys, const QString &cmd, bool isLuaFunc) {
    if (keys.trimmed().isEmpty() || cmd.trimmed().isEmpty()) return;

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    QString keyLua = formatKeyToLua(keys);
    QString newBlock;
    if (isLuaFunc || cmd.trimmed().startsWith("function(") || cmd.trimmed().startsWith("hl.dsp.")) {
        newBlock = QString("hl.bind(%1, %2)").arg(keyLua, cmd.trimmed());
    } else {
        QString cmdLua = isKnownLuaIdentifier(cmd) ? cmd.trimmed() : ("\"" + escapeLuaStr(cmd.trimmed()) + "\"");
        newBlock = QString("hl.bind(%1, hl.dsp.exec_cmd(%2))").arg(keyLua, cmdLua);
    }

    for (const QString &ln : newBlock.split('\n')) {
        lines.append(ln);
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }
    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}
