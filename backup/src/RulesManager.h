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
        QString name;
        QString className;
        bool isFloat;
        bool isCenter;
        QString sizeW;
        QString sizeH;
        QString workspace;
        int startLine;
        int endLine;
        bool enabled;
    };
    QVector<RuleEntry> m_entries;
    QVariantList m_rules;
};
