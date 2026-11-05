#pragma once
#include <QObject>
#include <QStringList>
#include <QQuickImageProvider>
#include <QImage>

class CursorImageProvider : public QQuickImageProvider {
public:
    CursorImageProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    static QImage extractCursor(const QString &theme);
};

class CursorManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(int size READ size WRITE setSize NOTIFY sizeChanged)
    Q_PROPERTY(int hwCursors READ hwCursors WRITE setHwCursors NOTIFY hwCursorsChanged)
    Q_PROPERTY(bool enableHyprcursor READ enableHyprcursor WRITE setEnableHyprcursor NOTIFY enableHyprcursorChanged)
    Q_PROPERTY(bool noWarps READ noWarps WRITE setNoWarps NOTIFY noWarpsChanged)
    Q_PROPERTY(bool persistentWarps READ persistentWarps WRITE setPersistentWarps NOTIFY persistentWarpsChanged)
    Q_PROPERTY(int warpOnChangeWs READ warpOnChangeWs WRITE setWarpOnChangeWs NOTIFY warpOnChangeWsChanged)
    Q_PROPERTY(qreal zoomFactor READ zoomFactor WRITE setZoomFactor NOTIFY zoomFactorChanged)
    Q_PROPERTY(qreal inactiveTimeout READ inactiveTimeout WRITE setInactiveTimeout NOTIFY inactiveTimeoutChanged)
    Q_PROPERTY(bool hideOnKeyPress READ hideOnKeyPress WRITE setHideOnKeyPress NOTIFY hideOnKeyPressChanged)
    Q_PROPERTY(bool hideOnTouch READ hideOnTouch WRITE setHideOnTouch NOTIFY hideOnTouchChanged)
    Q_PROPERTY(bool hideOnTablet READ hideOnTablet WRITE setHideOnTablet NOTIFY hideOnTabletChanged)
    Q_PROPERTY(QStringList installedThemes READ installedThemes NOTIFY installedThemesChanged)

public:
    explicit CursorManager(QObject *parent = nullptr);

    QString theme() const { return m_theme; }
    void setTheme(const QString &v);

    int size() const { return m_size; }
    void setSize(int v);

    int hwCursors() const { return m_hwCursors; }
    void setHwCursors(int v);

    bool enableHyprcursor() const { return m_enableHyprcursor; }
    void setEnableHyprcursor(bool v);

    bool noWarps() const { return m_noWarps; }
    void setNoWarps(bool v);

    bool persistentWarps() const { return m_persistentWarps; }
    void setPersistentWarps(bool v);

    int warpOnChangeWs() const { return m_warpOnChangeWs; }
    void setWarpOnChangeWs(int v);

    qreal zoomFactor() const { return m_zoomFactor; }
    void setZoomFactor(qreal v);

    qreal inactiveTimeout() const { return m_inactiveTimeout; }
    void setInactiveTimeout(qreal v);

    bool hideOnKeyPress() const { return m_hideOnKeyPress; }
    void setHideOnKeyPress(bool v);

    bool hideOnTouch() const { return m_hideOnTouch; }
    void setHideOnTouch(bool v);

    bool hideOnTablet() const { return m_hideOnTablet; }
    void setHideOnTablet(bool v);

    QStringList installedThemes() const { return m_installedThemes; }

    Q_INVOKABLE void stepSize(int delta);
    Q_INVOKABLE void stepZoom(qreal delta);
    Q_INVOKABLE void stepTimeout(qreal delta);

signals:
    void themeChanged();
    void sizeChanged();
    void hwCursorsChanged();
    void enableHyprcursorChanged();
    void noWarpsChanged();
    void persistentWarpsChanged();
    void warpOnChangeWsChanged();
    void zoomFactorChanged();
    void inactiveTimeoutChanged();
    void hideOnKeyPressChanged();
    void hideOnTouchChanged();
    void hideOnTabletChanged();
    void installedThemesChanged();

private:
    void scanThemes();
    void loadSettings();
    void saveAndApply();

    QString m_theme = "Bibata-Modern-Classic";
    int m_size = 24;
    int m_hwCursors = 2; // 0=on, 1=off, 2=auto
    bool m_enableHyprcursor = true;
    bool m_noWarps = false;
    bool m_persistentWarps = false;
    int m_warpOnChangeWs = 0;
    qreal m_zoomFactor = 1.0;
    qreal m_inactiveTimeout = 0.0;
    bool m_hideOnKeyPress = false;
    bool m_hideOnTouch = false;
    bool m_hideOnTablet = false;

    QStringList m_installedThemes;
};
