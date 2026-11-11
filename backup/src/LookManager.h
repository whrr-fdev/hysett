#pragma once
#include <QObject>
#include <QString>
#include <QVector>
#include <QTimer>

class LookManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(qreal activeOpacity READ activeOpacity WRITE setActiveOpacity NOTIFY lookChanged)
    Q_PROPERTY(qreal inactiveOpacity READ inactiveOpacity WRITE setInactiveOpacity NOTIFY lookChanged)
    Q_PROPERTY(bool dimInactive READ dimInactive WRITE setDimInactive NOTIFY lookChanged)
    Q_PROPERTY(qreal dimStrength READ dimStrength WRITE setDimStrength NOTIFY lookChanged)
    Q_PROPERTY(qreal dimAround READ dimAround WRITE setDimAround NOTIFY lookChanged)
    Q_PROPERTY(bool blurEnabled READ blurEnabled WRITE setBlurEnabled NOTIFY lookChanged)
    Q_PROPERTY(int blurSize READ blurSize WRITE setBlurSize NOTIFY lookChanged)
    Q_PROPERTY(int blurPasses READ blurPasses WRITE setBlurPasses NOTIFY lookChanged)
    Q_PROPERTY(qreal blurVibrancy READ blurVibrancy WRITE setBlurVibrancy NOTIFY lookChanged)
    Q_PROPERTY(bool shadowEnabled READ shadowEnabled WRITE setShadowEnabled NOTIFY lookChanged)
    Q_PROPERTY(int shadowRange READ shadowRange WRITE setShadowRange NOTIFY lookChanged)
    Q_PROPERTY(int gapsIn READ gapsIn WRITE setGapsIn NOTIFY lookChanged)
    Q_PROPERTY(int gapsOut READ gapsOut WRITE setGapsOut NOTIFY lookChanged)
    Q_PROPERTY(int borderSize READ borderSize WRITE setBorderSize NOTIFY lookChanged)
    Q_PROPERTY(bool animsEnabled READ animsEnabled WRITE setAnimsEnabled NOTIFY lookChanged)
    Q_PROPERTY(QString activeBorder READ activeBorder WRITE setActiveBorder NOTIFY lookChanged)
    Q_PROPERTY(QString inactiveBorder READ inactiveBorder WRITE setInactiveBorder NOTIFY lookChanged)
    Q_PROPERTY(int backupCount READ backupCount NOTIFY backupCountChanged)

public:
    explicit LookManager(QObject *parent = nullptr);

    qreal activeOpacity() const { return m_activeOpacity; }
    void setActiveOpacity(qreal v);

    qreal inactiveOpacity() const { return m_inactiveOpacity; }
    void setInactiveOpacity(qreal v);

    bool dimInactive() const { return m_dimInactive; }
    void setDimInactive(bool v);

    qreal dimStrength() const { return m_dimStrength; }
    void setDimStrength(qreal v);

    qreal dimAround() const { return m_dimAround; }
    void setDimAround(qreal v);

    bool blurEnabled() const { return m_blurEnabled; }
    void setBlurEnabled(bool v);

    int blurSize() const { return m_blurSize; }
    void setBlurSize(int v);

    int blurPasses() const { return m_blurPasses; }
    void setBlurPasses(int v);

    qreal blurVibrancy() const { return m_blurVibrancy; }
    void setBlurVibrancy(qreal v);

    bool shadowEnabled() const { return m_shadowEnabled; }
    void setShadowEnabled(bool v);

    int shadowRange() const { return m_shadowRange; }
    void setShadowRange(int v);

    int gapsIn() const { return m_gapsIn; }
    void setGapsIn(int v);

    int gapsOut() const { return m_gapsOut; }
    void setGapsOut(int v);

    int borderSize() const { return m_borderSize; }
    void setBorderSize(int v);

    bool animsEnabled() const { return m_animsEnabled; }
    void setAnimsEnabled(bool v);

    QString activeBorder() const { return m_activeBorder; }
    void setActiveBorder(const QString &v);

    QString inactiveBorder() const { return m_inactiveBorder; }
    void setInactiveBorder(const QString &v);

    int backupCount() const { return m_history.size(); }

    Q_INVOKABLE void undo();
    Q_INVOKABLE void resetToDefaults();

signals:
    void lookChanged();
    void backupCountChanged();

private:
    void loadFromDisk();
    void scheduleSaveAndApply();
    void pushBackup();
    void applyKeyword(const QString &key, const QString &val);
    void writeLookLua();

    qreal m_activeOpacity = 0.85;
    qreal m_inactiveOpacity = 0.75;
    bool m_dimInactive = false;
    qreal m_dimStrength = 0.75;
    qreal m_dimAround = 0.40;
    bool m_blurEnabled = true;
    int m_blurSize = 1;
    int m_blurPasses = 2;
    qreal m_blurVibrancy = 0.50;
    bool m_shadowEnabled = true;
    int m_shadowRange = 4;
    int m_gapsIn = 3;
    int m_gapsOut = 10;
    int m_borderSize = 1;
    bool m_animsEnabled = true;
    QString m_activeBorder = "rgba(ccccccff)";
    QString m_inactiveBorder = "rgba(333333ff)";

    struct Snapshot {
        qreal activeOpacity, inactiveOpacity;
        bool dimInactive;
        qreal dimStrength, dimAround;
        bool blurEnabled;
        int blurSize, blurPasses;
        qreal blurVibrancy;
        bool shadowEnabled;
        int shadowRange;
        int gapsIn, gapsOut, borderSize;
        bool animsEnabled;
        QString activeBorder, inactiveBorder;
    };
    QVector<Snapshot> m_history;
    QTimer *m_saveTimer = nullptr;
};
