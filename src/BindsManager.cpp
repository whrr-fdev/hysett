#include "BindsManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>

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
        if (line.contains("hl.bind(") && line.contains("hl.dsp.exec_cmd(")) {
            bool en = !line.startsWith("--");

            // Извлечение клавиши
            QRegularExpression reKey("hl\\.bind\\(\\s*(mainMod\\s*\\.\\.\\s*\"[^\"]+\"|\"[^\"]+\")");
            auto mKey = reKey.match(line);
            QString keys;
            if (mKey.hasMatch()) {
                keys = mKey.captured(1);
                keys.replace("mainMod .. \"", "SUPER");
                keys.remove('\"');
                keys.replace("+  +", "+");
            }

            // Извлечение команды
            QRegularExpression reCmd("hl\\.dsp\\.exec_cmd\\(\\s*\"([^\"]+)\"|'([^']+)'|([^\\)]+)");
            auto mCmd = reCmd.match(line);
            QString cmd;
            if (mCmd.hasMatch()) {
                cmd = mCmd.captured(1).isEmpty() ? (mCmd.captured(2).isEmpty() ? mCmd.captured(3) : mCmd.captured(2)) : mCmd.captured(1);
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
    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    for (const auto &e : m_entries) {
        if (e.lineIdx < lines.size()) {
            QString keyLua = e.keys;
            if (keyLua.startsWith("SUPER")) {
                keyLua = "mainMod .. \"" + keyLua.mid(5) + "\"";
            } else {
                keyLua = "\"" + keyLua + "\"";
            }
            QString code = QString("hl.bind(%1, hl.dsp.exec_cmd(\"%2\"))").arg(keyLua, e.cmd);
            lines[e.lineIdx] = (e.enabled ? "" : "--") + code;
        }
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }
}

void BindsManager::toggleItem(int index, bool enabled) {
    if (index < 0 || index >= m_entries.size()) return;
    m_entries[index].enabled = enabled;
    QVariantMap vm = m_items[index].toMap();
    vm["enabled"] = enabled;
    m_items[index] = vm;
    syncToFile();
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

    syncToFile();
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

    if (lineIdx < lines.size()) {
        lines.removeAt(lineIdx);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            for (const auto &l : lines) out << l << "\n";
        }
    }
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

    QString keyLua = keys;
    if (keyLua.startsWith("SUPER")) {
        keyLua = "mainMod .. \"" + keyLua.mid(5) + "\"";
    } else {
        keyLua = "\"" + keyLua + "\"";
    }
    QString newLine = QString("hl.bind(%1, hl.dsp.exec_cmd(\"%2\"))").arg(keyLua, cmd);

    lines.append(newLine);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }
    reload();
}
