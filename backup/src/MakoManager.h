#pragma once
#include <QObject>
#include <QString>
#include <QColor>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>

class MakoManager : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

    Q_PROPERTY(QString anchor READ anchor WRITE setAnchor NOTIFY changed)
    Q_PROPERTY(int width READ width WRITE setWidth NOTIFY changed)
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY changed)
    Q_PROPERTY(int margin READ margin WRITE setMargin NOTIFY changed)
    Q_PROPERTY(int padding READ padding WRITE setPadding NOTIFY changed)
    Q_PROPERTY(int borderSize READ borderSize WRITE setBorderSize NOTIFY changed)
    Q_PROPERTY(int borderRadius READ borderRadius WRITE setBorderRadius NOTIFY changed)
    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY changed)
    Q_PROPERTY(int defaultTimeout READ defaultTimeout WRITE setDefaultTimeout NOTIFY changed)
    Q_PROPERTY(int maxVisible READ maxVisible WRITE setMaxVisible NOTIFY changed)
    Q_PROPERTY(bool icons READ icons WRITE setIcons NOTIFY changed)
    Q_PROPERTY(qreal bgOpacity READ bgOpacity WRITE setBgOpacity NOTIFY changed)
    Q_PROPERTY(QColor bgColor READ bgColor WRITE setBgColor NOTIFY changed)
    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY changed)
    Q_PROPERTY(QColor borderColor READ borderColor WRITE setBorderColor NOTIFY changed)
    Q_PROPERTY(QColor criticalBorderColor READ criticalBorderColor WRITE setCriticalBorderColor NOTIFY changed)

    Q_PROPERTY(bool popupVisible READ popupVisible NOTIFY popupChanged)
    Q_PROPERTY(bool popupCritical READ popupCritical NOTIFY popupChanged)
    Q_PROPERTY(QVariantList activePopups READ activePopups NOTIFY popupChanged)
    Q_PROPERTY(int hiddenPopupCount READ hiddenPopupCount NOTIFY popupChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY popupChanged)

public:
    explicit MakoManager(QObject *parent = nullptr);

    QString anchor() const { return m_anchor; }
    void setAnchor(const QString &v);
    int width() const { return m_width; }
    void setWidth(int v);
    int height() const { return m_height; }
    void setHeight(int v);
    int margin() const { return m_margin; }
    void setMargin(int v);
    int padding() const { return m_padding; }
    void setPadding(int v);
    int borderSize() const { return m_borderSize; }
    void setBorderSize(int v);
    int borderRadius() const { return m_borderRadius; }
    void setBorderRadius(int v);
    int fontSize() const { return m_fontSize; }
    void setFontSize(int v);
    int defaultTimeout() const { return m_defaultTimeout; }
    void setDefaultTimeout(int v);
    int maxVisible() const { return m_maxVisible; }
    void setMaxVisible(int v);
    bool icons() const { return m_icons; }
    void setIcons(bool v);
    qreal bgOpacity() const { return m_bgOpacity; }
    void setBgOpacity(qreal v);
    QColor bgColor() const { return m_bgColor; }
    void setBgColor(const QColor &v);
    QColor textColor() const { return m_textColor; }
    void setTextColor(const QColor &v);
    QColor borderColor() const { return m_borderColor; }
    void setBorderColor(const QColor &v);
    QColor criticalBorderColor() const { return m_criticalBorderColor; }
    void setCriticalBorderColor(const QColor &v);

    bool popupVisible() const { return !m_activePopups.isEmpty(); }
    bool popupCritical() const;
    QVariantList activePopups() const;
    int hiddenPopupCount() const;
    QVariantList history() const { return m_history; }

    Q_INVOKABLE void load();
    Q_INVOKABLE void save();
    Q_INVOKABLE void sendTestNotification();
    Q_INVOKABLE void sendCriticalNotification();
    Q_INVOKABLE void dismissPopup(int id);
    Q_INVOKABLE void dismissAll();
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void resetDefaults();
    Q_INVOKABLE void showInternalNotification(const QString &appName, const QString &summary, const QString &body, const QString &icon, bool critical, int timeoutMs = -1);

public slots:
    Q_SCRIPTABLE QStringList GetCapabilities();
    Q_SCRIPTABLE QString GetServerInformation(QString &vendor, QString &version, QString &specVersion);
    Q_SCRIPTABLE uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                             const QString &summary, const QString &body, const QStringList &actions,
                             const QVariantMap &hints, int expire_timeout);
    Q_SCRIPTABLE void CloseNotification(uint id);

signals:
    void changed();
    void popupChanged();

private:
    QString configPath() const;
    QString formatHexRgba(const QColor &c, qreal alpha) const;
    void parseHexRgba(const QString &str, QColor &outCol, qreal &outAlpha);
    void registerDbusService();
    void onTickPopups();

    QString m_anchor = "top-right";
    int m_width = 320;
    int m_height = 64;
    int m_margin = 10;
    int m_padding = 10;
    int m_borderSize = 1;
    int m_borderRadius = 12;
    int m_fontSize = 11;
    int m_defaultTimeout = 4500;
    int m_maxVisible = 4;
    bool m_icons = true;
    qreal m_bgOpacity = 0.85;
    QColor m_bgColor = QColor("#111318");
    QColor m_textColor = QColor("#ffffff");
    QColor m_borderColor = QColor("#444854");
    QColor m_criticalBorderColor = QColor("#ff6b6b");

    uint m_nextId = 1;
    QVariantList m_activePopups;
    QVariantList m_history;
    QTimer *m_tickTimer = nullptr;
};
