#include "RulesManager.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QProcess>

RulesManager::RulesManager(QObject *parent) : QObject(parent) {
    reload();
}

QString RulesManager::luaPath() const {
    return QDir::homePath() + "/.config/hypr/hyprland.lua";
}

void RulesManager::reload() {
    m_entries.clear();
    m_rules.clear();

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    bool insideRule = false;
    RuleEntry current;

    for (int i = 0; i < lines.size(); ++i) {
        QString raw = lines[i];
        QString trimmed = raw.trimmed();

        if (trimmed.contains("hl.window_rule({")) {
            insideRule = true;
            current = RuleEntry();
            current.startLine = i;
            current.enabled = !trimmed.startsWith("--");
            continue;
        }

        if (insideRule) {
            if (trimmed.contains("name =")) {
                QRegularExpression re("name\\s*=\\s*\"([^\"]+)\"");
                auto match = re.match(trimmed);
                if (match.hasMatch()) current.name = match.captured(1);
            }
            if (trimmed.contains("class =")) {
                QRegularExpression re("class\\s*=\\s*\"([^\"]+)\"");
                auto match = re.match(trimmed);
                if (match.hasMatch()) current.className = match.captured(1);
            }
            if (trimmed.contains("float = true")) current.isFloat = true;
            if (trimmed.contains("center = true")) current.isCenter = true;
            if (trimmed.contains("size =")) {
                QRegularExpression re("size\\s*=\\s*\\{\\s*(\\d+)\\s*,\\s*(\\d+)\\s*\\}");
                auto match = re.match(trimmed);
                if (match.hasMatch()) {
                    current.sizeW = match.captured(1);
                    current.sizeH = match.captured(2);
                }
            }
            if (trimmed.contains("workspace =")) {
                QRegularExpression re("workspace\\s*=\\s*\"([^\"]+)\"");
                auto match = re.match(trimmed);
                if (match.hasMatch()) current.workspace = match.captured(1);
            }

            if (trimmed.startsWith("})") || trimmed.startsWith("--})")) {
                current.endLine = i;
                insideRule = false;

                if (!current.className.isEmpty() || !current.name.isEmpty()) {
                    m_entries.append(current);

                    QVariantMap vm;
                    vm["name"] = current.name;
                    vm["className"] = current.className;
                    vm["float"] = current.isFloat;
                    vm["center"] = current.isCenter;
                    vm["sizeW"] = current.sizeW;
                    vm["sizeH"] = current.sizeH;
                    vm["workspace"] = current.workspace;
                    vm["enabled"] = current.enabled;
                    m_rules.append(vm);
                }
            }
        }
    }

    emit rulesChanged();
}

void RulesManager::toggleRule(int index, bool enable) {
    if (index < 0 || index >= m_entries.size()) return;
    auto &entry = m_entries[index];

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    for (int i = entry.startLine; i <= entry.endLine && i < lines.size(); ++i) {
        QString l = lines[i];
        if (enable) {
            QString tr = l.trimmed();
            while (tr.startsWith("-")) tr.remove(0, 1);
            lines[i] = "    " + tr.trimmed();
        } else {
            QString tr = l.trimmed();
            if (!tr.startsWith("--")) lines[i] = "    --" + tr;
        }
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }

    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}

void RulesManager::deleteRule(int index) {
    if (index < 0 || index >= m_entries.size()) return;
    auto &entry = m_entries[index];

    QFile file(luaPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) lines.append(in.readLine());
    file.close();

    for (int i = entry.endLine; i >= entry.startLine && i < lines.size(); --i) {
        lines.removeAt(i);
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
    }

    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}
