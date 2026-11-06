#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
#include <QSocketNotifier>
#include <QQuickWindow>

class WaybarManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool posBottom READ posBottom WRITE setPosBottom NOTIFY stateChanged)
    Q_PROPERTY(int barPosition READ barPosition WRITE setBarPosition NOTIFY stateChanged)
    Q_PROPERTY(bool centeredBar READ centeredBar WRITE setCenteredBar NOTIFY stateChanged)
    Q_PROPERTY(bool fixedTitleWidth READ fixedTitleWidth WRITE setFixedTitleWidth NOTIFY stateChanged)
    Q_PROPERTY(int fixedTitleSize READ fixedTitleSize WRITE setFixedTitleSize NOTIFY stateChanged)
    Q_PROPERTY(bool centerTitleOnBar READ centerTitleOnBar WRITE setCenterTitleOnBar NOTIFY stateChanged)
    Q_PROPERTY(QVariantList specs READ specs NOTIFY stateChanged)

    Q_PROPERTY(int barWidth READ barWidth NOTIFY stateChanged)
    Q_PROPERTY(int barHeight READ barHeight NOTIFY stateChanged)
    Q_PROPERTY(int barAnimDuration READ barAnimDuration NOTIFY stateChanged)
    Q_PROPERTY(QString hiddenBarModules READ hiddenBarModules WRITE setHiddenBarModules NOTIFY stateChanged)
    Q_PROPERTY(int marginTop READ marginTop NOTIFY stateChanged)
    Q_PROPERTY(int marginBottom READ marginBottom NOTIFY stateChanged)
    Q_PROPERTY(int marginLeft READ marginLeft NOTIFY stateChanged)
    Q_PROPERTY(int marginRight READ marginRight NOTIFY stateChanged)
    Q_PROPERTY(int spacing READ spacing NOTIFY stateChanged)
    Q_PROPERTY(int groupSpacing READ groupSpacing NOTIFY stateChanged)
    Q_PROPERTY(qreal barOpacity READ barOpacity NOTIFY stateChanged)
    Q_PROPERTY(qreal pillOpacity READ pillOpacity NOTIFY stateChanged)

    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY workspacesChanged)
    Q_PROPERTY(int activeWorkspace READ activeWorkspace NOTIFY workspacesChanged)
    Q_PROPERTY(QString activeWindowTitle READ activeWindowTitle NOTIFY activeWindowChanged)
    Q_PROPERTY(QVariantList trayApps READ trayApps NOTIFY activeWindowChanged)
    Q_PROPERTY(QVariantList clipboardItems READ clipboardItems NOTIFY clipboardChanged)

    // Музыкальный плеер (MPRIS2 + демо-режим + таймер автоскрытия)
    Q_PROPERTY(bool mediaActive READ mediaActive NOTIFY mediaChanged)
    Q_PROPERTY(bool hasRealMedia READ hasRealMedia NOTIFY mediaChanged)
    Q_PROPERTY(bool mediaPlaying READ mediaPlaying NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaPositionText READ mediaPositionText NOTIFY mediaChanged)
    Q_PROPERTY(QString mediaDurationText READ mediaDurationText NOTIFY mediaChanged)
    Q_PROPERTY(int mediaPosSec READ mediaPosSec NOTIFY mediaChanged)
    Q_PROPERTY(int mediaLengthSec READ mediaLengthSec NOTIFY mediaChanged)
    Q_PROPERTY(bool mediaDemoMode READ mediaDemoMode WRITE setMediaDemoMode NOTIFY mediaChanged)
    Q_PROPERTY(int mediaHideTimeout READ mediaHideTimeout WRITE setMediaHideTimeout NOTIFY stateChanged)

    // Разделители и режим редактирования панели задач (Drag & Drop)
    Q_PROPERTY(bool barSeparators READ barSeparators WRITE setBarSeparators NOTIFY stateChanged)
    Q_PROPERTY(bool uniformBarSpacing READ uniformBarSpacing WRITE setUniformBarSpacing NOTIFY stateChanged)
    Q_PROPERTY(bool barEditMode READ barEditMode WRITE setBarEditMode NOTIFY stateChanged)
    Q_PROPERTY(QStringList leftBarOrder READ leftBarOrder NOTIFY stateChanged)
    Q_PROPERTY(QStringList rightBarOrder READ rightBarOrder NOTIFY stateChanged)

    // Системные метрики и графики для встроенного монитора (btop)
    Q_PROPERTY(int cpuUsage READ cpuUsage NOTIFY sysStatsChanged)
    Q_PROPERTY(int cpuTemp READ cpuTemp NOTIFY sysStatsChanged)
    Q_PROPERTY(int memPercent READ memPercent NOTIFY sysStatsChanged)
    Q_PROPERTY(QString memUsageText READ memUsageText NOTIFY sysStatsChanged)
    Q_PROPERTY(QString memDetailText READ memDetailText NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList tempHistory READ tempHistory NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList memHistory READ memHistory NOTIFY sysStatsChanged)
    Q_PROPERTY(int vramPercent READ vramPercent NOTIFY sysStatsChanged)
    Q_PROPERTY(QString vramDetailText READ vramDetailText NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList vramHistory READ vramHistory NOTIFY sysStatsChanged)
    Q_PROPERTY(int netPercent READ netPercent NOTIFY sysStatsChanged)
    Q_PROPERTY(QString netSpeedText READ netSpeedText NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList netHistory READ netHistory NOTIFY sysStatsChanged)
    Q_PROPERTY(QVariantList processList READ processList NOTIFY processesChanged)
    Q_PROPERTY(int processSortMode READ processSortMode WRITE setProcessSortMode NOTIFY processesChanged)

    // Звук, раскладка, сеть
    Q_PROPERTY(int volume READ volume NOTIFY audioChanged)
    Q_PROPERTY(bool muted READ muted NOTIFY audioChanged)
    Q_PROPERTY(QString kbLayout READ kbLayout NOTIFY kbLayoutChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QString recordingTimeText READ recordingTimeText NOTIFY recordingChanged)
    Q_PROPERTY(bool btConnected READ btConnected NOTIFY sysStatsChanged)
    Q_PROPERTY(bool netConnected READ netConnected NOTIFY sysStatsChanged)
    Q_PROPERTY(bool vpnActive READ vpnActive NOTIFY sysStatsChanged)
    Q_PROPERTY(QString vpnServerName READ vpnServerName NOTIFY sysStatsChanged)
    Q_PROPERTY(QString vpnSubUrl READ vpnSubUrl WRITE setVpnSubUrl NOTIFY sysStatsChanged)
    Q_PROPERTY(QStringList vpnSubUrls READ vpnSubUrls NOTIFY sysStatsChanged)
    Q_PROPERTY(QStringList vpnServers READ vpnServers NOTIFY sysStatsChanged)
    Q_PROPERTY(int vpnSelectedServer READ vpnSelectedServer NOTIFY sysStatsChanged)
    Q_PROPERTY(bool vpnRuDirect READ vpnRuDirect WRITE setVpnRuDirect NOTIFY sysStatsChanged)

    // Погода Gismeteo (Сейчас, Завтра, Неделя, Месяц)
    Q_PROPERTY(QString weatherText READ weatherText NOTIFY weatherChanged)
    Q_PROPERTY(QVariantMap weatherDetails READ weatherDetails NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList weatherHourly READ weatherHourly NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList weatherTomorrow READ weatherTomorrow NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList weatherWeek READ weatherWeek NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList weatherMonth READ weatherMonth NOTIFY weatherChanged)

public:
    explicit WaybarManager(QObject *parent = nullptr);
    ~WaybarManager() override;

    bool posBottom() const { return m_posBottom; }
    void setPosBottom(bool v);
    int barPosition() const { return m_barPosition; }
    void setBarPosition(int v);
    bool centeredBar() const { return m_centeredBar; }
    void setCenteredBar(bool v);
    bool fixedTitleWidth() const { return m_fixedTitleWidth; }
    void setFixedTitleWidth(bool v);
    int fixedTitleSize() const { return m_fixedTitleSize; }
    void setFixedTitleSize(int v);
    bool centerTitleOnBar() const { return m_centerTitleOnBar; }
    void setCenterTitleOnBar(bool v);
    QVariantList specs() const { return m_specs; }

    int barWidth() const;
    int barHeight() const;
    int barAnimDuration() const;
    QString hiddenBarModules() const { return m_hiddenBarModules; }
    void setHiddenBarModules(const QString &v);
    Q_INVOKABLE bool isBarModuleVisible(const QString &mod) const;
    Q_INVOKABLE void setBarModuleVisible(const QString &mod, bool visible);
    int marginTop() const;
    int marginBottom() const;
    int marginLeft() const;
    int marginRight() const;
    int spacing() const;
    int groupSpacing() const;
    qreal barOpacity() const;
    qreal pillOpacity() const;

    QVariantList workspaces() const { return m_workspaces; }
    int activeWorkspace() const { return m_activeWorkspace; }
    QString activeWindowTitle() const { return m_activeWindowTitle; }
    QVariantList trayApps() const { return m_trayApps; }
    QVariantList clipboardItems() const { return m_clipboardItems; }

    bool mediaActive() const;
    bool hasRealMedia() const { return m_mediaActive; }
    bool mediaPlaying() const { return (m_mediaDemoMode && !m_mediaActive) ? m_demoPlaying : m_mediaPlaying; }
    QString mediaTitle() const { return (m_mediaDemoMode && !m_mediaActive) ? m_demoTracks.value(m_demoTrackIdx) : m_mediaTitle; }
    QString mediaPositionText() const;
    QString mediaDurationText() const;
    int mediaPosSec() const { return (m_mediaDemoMode && !m_mediaActive) ? m_demoPosSec : m_realPosSec; }
    int mediaLengthSec() const { return (m_mediaDemoMode && !m_mediaActive) ? 215 : std::max(1, m_realLenSec); }
    bool mediaDemoMode() const { return m_mediaDemoMode; }
    void setMediaDemoMode(bool v);
    int mediaHideTimeout() const { return m_mediaHideTimeout; }
    void setMediaHideTimeout(int sec);
    Q_INVOKABLE void toggleMediaDemo();
    Q_INVOKABLE void mediaPlayPause();
    Q_INVOKABLE void mediaPrev();
    Q_INVOKABLE void mediaNext();
    Q_INVOKABLE void mediaSeek(int deltaSec);
    Q_INVOKABLE void seekToSecond(int sec);

    bool barSeparators() const { return m_barSeparators; }
    void setBarSeparators(bool v);
    bool uniformBarSpacing() const { return m_uniformBarSpacing; }
    void setUniformBarSpacing(bool v);
    bool barEditMode() const { return m_barEditMode; }
    void setBarEditMode(bool v);
    QStringList leftBarOrder() const { return m_leftBarOrder; }
    QStringList rightBarOrder() const { return m_rightBarOrder; }
    Q_INVOKABLE void moveBarModule(const QString &side, int fromIdx, int toIdx);
    Q_INVOKABLE void moveWindowModuleToSide(const QString &targetSide);
    Q_INVOKABLE QString swapWithCenterWindow(const QString &side, int idx);
    Q_INVOKABLE QString transferBarModule(const QString &key, const QString &fromSide, int dir);
    Q_INVOKABLE void addBarSeparator(const QString &side);
    Q_INVOKABLE void removeBarItemAt(const QString &side, int idx);
    Q_INVOKABLE void resetBarOrder();
    Q_INVOKABLE void confirmBarEdit();
    Q_INVOKABLE void cancelBarEdit();

    int cpuUsage() const { return m_cpuUsage; }
    int cpuTemp() const { return m_cpuTemp; }
    int memPercent() const { return m_memPercent; }
    QString memUsageText() const { return m_memUsageText; }
    QString memDetailText() const { return m_memDetailText; }
    QVariantList cpuHistory() const { return m_cpuHistory; }
    QVariantList tempHistory() const { return m_tempHistory; }
    QVariantList memHistory() const { return m_memHistory; }
    int vramPercent() const { return m_vramPercent; }
    QString vramDetailText() const { return m_vramDetailText; }
    QVariantList vramHistory() const { return m_vramHistory; }
    int netPercent() const { return m_netPercent; }
    QString netSpeedText() const { return m_netSpeedText; }
    QVariantList netHistory() const { return m_netHistory; }
    Q_INVOKABLE void switchKbLayout();
    QVariantList processList() const { return m_processList; }
    int processSortMode() const { return m_processSortMode; }
    void setProcessSortMode(int mode);

    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString kbLayout() const { return m_kbLayout; }
    bool recording() const { return m_recording; }
    QString recordingTimeText() const { return m_recordingTimeText; }
    bool btConnected() const { return m_btConnected; }
    bool netConnected() const { return m_netConnected; }
    bool vpnActive() const { return m_vpnActive; }
    QString vpnServerName() const { return m_vpnServerName; }
    QString vpnSubUrl() const { return m_vpnSubUrl; }
    void setVpnSubUrl(const QString &u);
    bool vpnRuDirect() const { return m_vpnRuDirect; }
    void setVpnRuDirect(bool v);
    Q_INVOKABLE void toggleVpn();
    Q_INVOKABLE void updateVpnSubscription();
    QStringList vpnSubUrls() const { return m_vpnSubUrls; }
    QStringList vpnServers() const { return m_vpnServers; }
    int vpnSelectedServer() const { return m_vpnSelectedServer; }
    Q_INVOKABLE void addVpnSubUrl(const QString &u);
    Q_INVOKABLE void removeVpnSubUrl(int idx);
    Q_INVOKABLE void selectVpnServer(int idx);

    QString weatherText() const { return m_weatherText; }
    QVariantMap weatherDetails() const { return m_weatherDetails; }
    QVariantList weatherHourly() const { return m_weatherHourly; }
    QVariantList weatherTomorrow() const { return m_weatherTomorrow; }
    QVariantList weatherWeek() const { return m_weatherWeek; }
    QVariantList weatherMonth() const { return m_weatherMonth; }

    Q_INVOKABLE void setSpecValue(int index, qreal val);
    Q_INVOKABLE void resetSpec(int index);
    Q_INVOKABLE void restartWaybar();

    Q_INVOKABLE void switchWorkspace(int wsId);
    Q_INVOKABLE void stepWorkspace(int dir);
    Q_INVOKABLE void changeVolume(int deltaPercent);
    Q_INVOKABLE void setVolumeExact(int percent);
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void runCommand(const QString &cmd);
    Q_INVOKABLE void activateTrayApp(const QString &cls, const QString &sniService = "");
    Q_INVOKABLE void trayContextAction(const QString &cls, const QString &sniService, int actionIdx);
    Q_INVOKABLE void refreshClipboard();
    Q_INVOKABLE void selectClipboardItem(int index);
    Q_INVOKABLE void clearClipboard();
    Q_INVOKABLE void refreshProcesses();
    Q_INVOKABLE void killProcess(int pid);
    Q_INVOKABLE void refreshWeather();
    Q_INVOKABLE void syncShellRegion(QQuickWindow *win, bool drawerOpen, bool notifOpen, int notifX, int notifY, int notifW, int notifH);

signals:
    void stateChanged();
    void closeDrawerRequested();
    void workspacesChanged();
    void activeWindowChanged();
    void clipboardChanged();
    void mediaChanged();
    void sysStatsChanged();
    void processesChanged();
    void audioChanged();
    void kbLayoutChanged();
    void weatherChanged();
    void recordingChanged();

private:
    void initSpecs();
    void loadState();
    void saveState(bool updatePosition);
    qreal specVal(const QString &key, qreal fallback) const;

    void connectHyprEventSocket();
    void onHyprEventReady();
    void pollHyprState();
    void pollSysStats();
    void pollFastState();
    void pollMediaState();
    void pollWeather();

    bool m_posBottom = false;
    int m_barPosition = 0;
    QString m_hiddenBarModules;
    bool m_centeredBar = false;
    bool m_fixedTitleWidth = false;
    int m_fixedTitleSize = 100;
    bool m_centerTitleOnBar = true;
    QVariantList m_specs;
    QVariantList m_defaults;

    int m_hyprEventFd = -1;
    QSocketNotifier *m_hyprNotifier = nullptr;
    QTimer *m_sysTimer = nullptr;
    QTimer *m_fastTimer = nullptr;
    QTimer *m_weatherTimer = nullptr;

    QVariantList m_workspaces;
    int m_activeWorkspace = 1;
    QString m_activeWindowTitle;
    QVariantList m_trayApps;
    int m_trayTick = 0;
    bool m_drawerOpenState = false;
    QString m_cachedHwmonPath;
    QVariantList m_clipboardItems;
    QStringList m_rawClipboardLines;

    bool m_mediaActive = false;
    bool m_mediaPlaying = false;
    QString m_mediaTitle;
    QString m_activeMprisService;
    bool m_mediaDemoMode = false;
    bool m_demoPlaying = true;
    int m_demoTrackIdx = 0;
    int m_demoPosSec = 42;
    int m_realPosSec = 0;
    int m_realLenSec = 215;
    int m_mediaHideTimeout = 15;
    int m_mediaPausedSec = 0;

    bool m_barSeparators = false;
    bool m_uniformBarSpacing = true;
    bool m_barEditMode = false;
    QStringList m_backupLeftOrder;
    QStringList m_backupRightOrder;
    QString m_backupHiddenModules;
    QStringList m_leftBarOrder = {"launcher", "workspaces", "weather", "media"};
    QStringList m_rightBarOrder = {"sysinfo", "tray", "bluetooth", "network", "clipboard", "volume", "language", "clock", "power"};
    QStringList m_demoTracks = {
        "The Weeknd — Blinding Lights",
        "Daft Punk — Instant Crush",
        "Kavinsky — Nightcall"
    };

    int m_cpuUsage = 0;
    int m_cpuTemp = 40;
    int m_memPercent = 20;
    QString m_memUsageText = "0.0G";
    QString m_memDetailText = "0.0 / 16.0 GB";
    QVariantList m_cpuHistory;
    QVariantList m_tempHistory;
    QVariantList m_memHistory;
    int m_vramPercent = 12;
    QString m_vramDetailText = "0.8 / 8.0 GB";
    QVariantList m_vramHistory;
    int m_netPercent = 5;
    QString m_netSpeedText = "↓ 0 KB/s  ↑ 0 KB/s";
    QVariantList m_netHistory;
    qulonglong m_prevNetRx = 0;
    qulonglong m_prevNetTx = 0;
    qint64 m_prevNetMs = 0;
    QVariantList m_processList;
    int m_processSortMode = 1;
    qint64 m_lastProcessPollMs = 0;
    qulonglong m_prevProcSysTotal = 0;
    QHash<int, qulonglong> m_prevProcTicks;
    qulonglong m_prevCpuIdle = 0;
    qulonglong m_prevCpuTotal = 0;

    int m_volume = 50;
    bool m_muted = false;
    QString m_kbLayout = "RU";
    bool m_recording = false;
    qint64 m_recordingStartSec = 0;
    QString m_recordingTimeText = "00:00";
    bool m_btConnected = false;
    bool m_netConnected = true;
    bool m_vpnActive = false;
    bool m_vpnRuDirect = true;
    QString m_vpnServerName = "StealthSurf VPN";
    QString m_vpnSubUrl = "";
    QStringList m_vpnSubUrls;
    QStringList m_vpnServers;
    int m_vpnSelectedServer = 0;
    void syncVpnStateFromScript(const QByteArray &raw);

    QString m_weatherText = "☁️ +3°C";
    QVariantMap m_weatherDetails;
    QVariantList m_weatherHourly;
    QVariantList m_weatherTomorrow;
    QVariantList m_weatherWeek;
    QVariantList m_weatherMonth;
};
