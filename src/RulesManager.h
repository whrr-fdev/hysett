#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class RulesManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList rules READ rules NOTIFY rulesChanged)

public:
    explicit RulesManager(QObject *parent = nullptr);

    QVariantList rules() const { return m_rules; }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void toggleRule(int index, bool enable);
    Q_INVOKABLE void deleteRule(int index);

signals:
    void rulesChanged();

private:
    QString luaPath() const;

    struct RuleEntry {
        QString ruleType; // "window" | "layer"
        QString name;
        QString className;
        QString titleMatch;
        QString namespaceMatch;
        QString matchWorkspace;
        bool matchXwayland = false;
        bool hasMatchFloat = false;
        bool matchFloatVal = false;

        bool isFloat = false;
        bool isCenter = false;
        bool isPin = false;
        bool hasPin = false;
        QString sizeW;
        QString sizeH;
        QString movePos;
        QString workspace;
        QString opacity;
        QString animation;
        QString suppressEvent;
        QString borderSize;
        QString rounding;
        bool noFocus = false;
        bool noBlur = false;
        bool noShadow = false;
        bool noAnim = false;

        // layer_rule properties
        bool layerBlur = false;
        bool layerDimAround = false;
        QString layerOrder;
        QString layerIgnoreAlpha;

        QString rawCode;
        int startLine = 0;
        int endLine = 0;
        bool enabled = true;
    };
    QVector<RuleEntry> m_entries;
    QVariantList m_rules;
};
