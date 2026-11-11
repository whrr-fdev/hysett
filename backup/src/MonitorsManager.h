#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>

class MonitorsManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(int vrrMode READ vrrMode WRITE setVrrMode NOTIFY vrrModeChanged)
    Q_PROPERTY(bool mouseMoveDpms READ mouseMoveDpms WRITE setMouseMoveDpms NOTIFY mouseMoveDpmsChanged)
    Q_PROPERTY(bool keyPressDpms READ keyPressDpms WRITE setKeyPressDpms NOTIFY keyPressDpmsChanged)
    Q_PROPERTY(int revertCountdown READ revertCountdown NOTIFY revertCountdownChanged)
    Q_PROPERTY(bool revertDialogActive READ revertDialogActive NOTIFY revertDialogActiveChanged)

public:
    explicit MonitorsManager(QObject *parent = nullptr);

    QVariantList monitors() const { return m_monitors; }
    int vrrMode() const { return m_vrrMode; }
    void setVrrMode(int v);

    bool mouseMoveDpms() const { return m_mouseMoveDpms; }
    void setMouseMoveDpms(bool v);

    bool keyPressDpms() const { return m_keyPressDpms; }
    void setKeyPressDpms(bool v);

    int revertCountdown() const { return m_revertCountdown; }
    bool revertDialogActive() const { return m_revertDialogActive; }

    Q_INVOKABLE void refreshMonitors();
    Q_INVOKABLE void setMonitorDisabled(int index, bool disabled);
    Q_INVOKABLE void requestMonitorMode(int index, const QString &modeStr);
    Q_INVOKABLE void confirmMonitorMode();
    Q_INVOKABLE void cancelMonitorMode();
    Q_INVOKABLE void setMonitorScale(int index, qreal scale);
    Q_INVOKABLE void setMonitorTransform(int index, int transform);

signals:
    void monitorsChanged();
    void vrrModeChanged();
    void mouseMoveDpmsChanged();
    void keyPressDpmsChanged();
    void revertCountdownChanged();
    void revertDialogActiveChanged();

private:
    void applyMonitor(const QVariantMap &m);
    void saveMonitorsToLua();
    void loadDisplaySettings();

    QVariantList m_monitors;
    int m_vrrMode = 0;
    bool m_mouseMoveDpms = false;
    bool m_keyPressDpms = false;

    QTimer *m_revertTimer = nullptr;
    int m_revertCountdown = 10;
    bool m_revertDialogActive = false;
    int m_pendingMonitorIdx = -1;
    QVariantMap m_previousMonitorState;
};
