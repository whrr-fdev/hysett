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

static QVariantMap makeBadge(const QString &icon, const QString &label, const QString &kind) {
    QVariantMap b;
    b["icon"] = icon;
    b["label"] = label;
    b["kind"] = kind;
    return b;
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
    bool insideMatchBlock = false;
    RuleEntry current;
    QStringList rawLines;

    QRegularExpression reStr("=\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    QRegularExpression reClass("class\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    QRegularExpression reTitle("title\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    QRegularExpression reNs("namespace\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    QRegularExpression reWs("workspace\\s*=\\s*\"((?:\\\\.|[^\"\\\\])*)\"");
    QRegularExpression reSize("size\\s*=\\s*\\{\\s*(\\d+)\\s*,\\s*(\\d+)\\s*\\}");
    QRegularExpression reInt("=\\s*(-?\\d+(?:\\.\\d+)?)");

    for (int i = 0; i < lines.size(); ++i) {
        QString raw = lines[i];
        QString trimmed = raw.trimmed();

        bool isWinStart = (raw.startsWith("hl.window_rule({") || raw.startsWith("--hl.window_rule({") || raw.startsWith("-- hl.window_rule({"));
        bool isLayerStart = (raw.startsWith("hl.layer_rule({") || raw.startsWith("--hl.layer_rule({") || raw.startsWith("-- hl.layer_rule({"));

        if (!insideRule && (isWinStart || isLayerStart)) {
            insideRule = true;
            insideMatchBlock = false;
            current = RuleEntry();
            current.ruleType = isLayerStart ? "layer" : "window";
            current.startLine = i;
            current.enabled = !trimmed.startsWith("--");
            rawLines.clear();
            rawLines.append(raw);
            continue;
        }

        if (insideRule) {
            rawLines.append(raw);

            QString clean = trimmed;
            if (clean.startsWith("--")) clean = clean.mid(2).trimmed();

            if (clean == "})" || clean == "});") {
                current.endLine = i;
                current.rawCode = rawLines.join("\n");
                insideRule = false;
                insideMatchBlock = false;

                int idx = m_entries.size();
                m_entries.append(current);

                QVariantMap vm;
                vm["index"] = idx;
                vm["ruleType"] = current.ruleType;
                vm["name"] = current.name;
                vm["className"] = current.className;
                vm["titleMatch"] = current.titleMatch;
                vm["namespaceMatch"] = current.namespaceMatch;
                vm["float"] = current.isFloat;
                vm["center"] = current.isCenter;
                vm["pin"] = current.isPin;
                vm["sizeW"] = current.sizeW;
                vm["sizeH"] = current.sizeH;
                vm["movePos"] = current.movePos;
                vm["workspace"] = current.workspace;
                vm["opacity"] = current.opacity;
                vm["animation"] = current.animation;
                vm["rawCode"] = current.rawCode;
                vm["startLine"] = current.startLine + 1;
                vm["endLine"] = current.endLine + 1;
                vm["enabled"] = current.enabled;

                // Сформируем заголовок карточки
                QString displayTitle = !current.name.isEmpty() ? current.name
                                     : (!current.className.isEmpty() ? current.className
                                     : (!current.titleMatch.isEmpty() ? current.titleMatch : current.namespaceMatch));
                vm["displayTitle"] = displayTitle;

                // Сформируем список наглядных бейджей для UI
                QVariantList matchBadges;
                if (!current.className.isEmpty())
                    matchBadges.append(makeBadge("󰀻", "class: " + current.className, "match"));
                if (!current.titleMatch.isEmpty())
                    matchBadges.append(makeBadge("󰗧", "title: " + current.titleMatch, "match"));
                if (!current.namespaceMatch.isEmpty())
                    matchBadges.append(makeBadge("󰜬", "layer: " + current.namespaceMatch, "match"));
                if (!current.matchWorkspace.isEmpty())
                    matchBadges.append(makeBadge("󰍹", "match ws: " + current.matchWorkspace, "match"));
                if (current.matchXwayland)
                    matchBadges.append(makeBadge("󰖲", "xwayland: true", "match"));
                if (current.hasMatchFloat)
                    matchBadges.append(makeBadge("󰖲", QString("match float: ") + (current.matchFloatVal ? "true" : "false"), "match"));

                QVariantList propBadges;
                if (!current.sizeW.isEmpty() && !current.sizeH.isEmpty())
                    propBadges.append(makeBadge("󰩨", current.sizeW + " × " + current.sizeH + " px", "size"));
                if (!current.movePos.isEmpty())
                    propBadges.append(makeBadge("󰆾", "Позиция: " + current.movePos, "move"));
                if (current.isFloat)
                    propBadges.append(makeBadge("󰖲", "Плавающее", "prop"));
                if (current.isCenter)
                    propBadges.append(makeBadge("󰄬", "По центру", "prop"));
                if (current.hasPin && current.isPin)
                    propBadges.append(makeBadge("󰐃", "Закреплено (Pin)", "prop"));
                if (!current.workspace.isEmpty())
                    propBadges.append(makeBadge("󰍹", "Стол: " + current.workspace, "prop"));
                if (!current.opacity.isEmpty())
                    propBadges.append(makeBadge("󰔎", "Прозрачность: " + current.opacity, "fx"));
                if (!current.animation.isEmpty())
                    propBadges.append(makeBadge("󰑐", "Анимация: " + current.animation, "fx"));
                if (!current.borderSize.isEmpty())
                    propBadges.append(makeBadge("󰈈", "Рамка: " + current.borderSize + "px", "fx"));
                if (!current.rounding.isEmpty())
                    propBadges.append(makeBadge("󰈈", "Скругление: " + current.rounding + "px", "fx"));
                if (!current.suppressEvent.isEmpty())
                    propBadges.append(makeBadge("󰅙", "Подавлять: " + current.suppressEvent, "flag"));
                if (current.noBlur)
                    propBadges.append(makeBadge("󰅙", "Без блюра", "flag"));
                if (current.noShadow)
                    propBadges.append(makeBadge("󰅙", "Без тени", "flag"));
                if (current.noFocus)
                    propBadges.append(makeBadge("󰅙", "Без фокуса", "flag"));
                if (current.noAnim)
                    propBadges.append(makeBadge("󰅙", "Без анимации", "flag"));

                if (current.layerBlur)
                    propBadges.append(makeBadge("󰔎", "Размытие слоя (Blur)", "fx"));
                if (current.layerDimAround)
                    propBadges.append(makeBadge("󰔎", "Затемнение фона (Dim)", "fx"));
                if (!current.layerOrder.isEmpty())
                    propBadges.append(makeBadge("󰆾", "Порядок (Order): " + current.layerOrder, "prop"));
                if (!current.layerIgnoreAlpha.isEmpty())
                    propBadges.append(makeBadge("󰔎", "Ignore alpha: " + current.layerIgnoreAlpha, "fx"));

                vm["matchBadges"] = matchBadges;
                vm["propBadges"] = propBadges;
                m_rules.append(vm);
                continue;
            }

            if (clean.startsWith("match") && clean.contains("{")) {
                if (auto m = reClass.match(clean); m.hasMatch()) current.className = m.captured(1);
                if (auto m = reTitle.match(clean); m.hasMatch()) current.titleMatch = m.captured(1);
                if (auto m = reNs.match(clean); m.hasMatch()) current.namespaceMatch = m.captured(1);
                if (auto m = reWs.match(clean); m.hasMatch()) current.matchWorkspace = m.captured(1);
                if (clean.contains("float = false") || clean.contains("float=false")) {
                    current.hasMatchFloat = true;
                    current.matchFloatVal = false;
                } else if (clean.contains("float = true") || clean.contains("float=true")) {
                    current.hasMatchFloat = true;
                    current.matchFloatVal = true;
                }
                if (!clean.contains("}")) {
                    insideMatchBlock = true;
                }
                continue;
            }

            if (insideMatchBlock) {
                if (auto m = reClass.match(clean); m.hasMatch()) current.className = m.captured(1);
                if (auto m = reTitle.match(clean); m.hasMatch()) current.titleMatch = m.captured(1);
                if (auto m = reNs.match(clean); m.hasMatch()) current.namespaceMatch = m.captured(1);
                if (auto m = reWs.match(clean); m.hasMatch()) current.matchWorkspace = m.captured(1);
                if (clean.startsWith("xwayland") && clean.contains("true")) current.matchXwayland = true;
                if (clean.startsWith("float")) {
                    current.hasMatchFloat = true;
                    current.matchFloatVal = clean.contains("true");
                }
                if (clean.contains("}")) {
                    insideMatchBlock = false;
                }
                continue;
            }

            if (clean.startsWith("match") && !clean.contains("{")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.namespaceMatch = m.captured(1);
            } else if (clean.startsWith("name")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.name = m.captured(1);
            } else if (clean.startsWith("class")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.className = m.captured(1);
            } else if (clean.startsWith("title")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.titleMatch = m.captured(1);
            } else if (clean.startsWith("float")) {
                current.isFloat = clean.contains("true");
            } else if (clean.startsWith("center")) {
                current.isCenter = clean.contains("true");
            } else if (clean.startsWith("pin")) {
                current.hasPin = true;
                current.isPin = clean.contains("true");
            } else if (clean.startsWith("size")) {
                if (auto m = reSize.match(clean); m.hasMatch()) {
                    current.sizeW = m.captured(1);
                    current.sizeH = m.captured(2);
                }
            } else if (clean.startsWith("move")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.movePos = m.captured(1);
            } else if (clean.startsWith("workspace")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.workspace = m.captured(1);
                else if (auto mi = reInt.match(clean); mi.hasMatch()) current.workspace = mi.captured(1);
            } else if (clean.startsWith("opacity")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.opacity = m.captured(1);
            } else if (clean.startsWith("animation")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.animation = m.captured(1);
            } else if (clean.startsWith("suppress_event")) {
                if (auto m = reStr.match(clean); m.hasMatch()) current.suppressEvent = m.captured(1);
            } else if (clean.startsWith("border_size")) {
                if (auto m = reInt.match(clean); m.hasMatch()) current.borderSize = m.captured(1);
            } else if (clean.startsWith("rounding")) {
                if (auto m = reInt.match(clean); m.hasMatch()) current.rounding = m.captured(1);
            } else if (clean.startsWith("no_focus") && clean.contains("true")) {
                current.noFocus = true;
            } else if (clean.startsWith("no_blur") && clean.contains("true")) {
                current.noBlur = true;
            } else if (clean.startsWith("no_shadow") && clean.contains("true")) {
                current.noShadow = true;
            } else if (clean.startsWith("no_anim") && clean.contains("true")) {
                current.noAnim = true;
            } else if (clean.startsWith("blur") && clean.contains("true")) {
                current.layerBlur = true;
            } else if (clean.startsWith("dim_around") && clean.contains("true")) {
                current.layerDimAround = true;
            } else if (clean.startsWith("order")) {
                if (auto m = reInt.match(clean); m.hasMatch()) current.layerOrder = m.captured(1);
            } else if (clean.startsWith("ignore_alpha")) {
                if (auto m = reInt.match(clean); m.hasMatch()) current.layerIgnoreAlpha = m.captured(1);
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
            int dashPos = l.indexOf("--");
            if (dashPos >= 0 && l.left(dashPos).trimmed().isEmpty()) {
                int removeLen = (dashPos + 2 < l.size() && l[dashPos + 2] == ' ') ? 3 : 2;
                lines[i] = l.left(dashPos) + l.mid(dashPos + removeLen);
            }
        } else {
            if (!l.trimmed().startsWith("--")) {
                lines[i] = "-- " + l;
            }
        }
    }

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
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

    if (file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        QTextStream out(&file);
        for (const auto &l : lines) out << l << "\n";
        file.close();
    }

    QProcess::startDetached("hyprctl", {"reload"});
    reload();
}
