#pragma once
#include <QObject>
#include <QString>
#include <QColor>
#include <QHash>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QSettings>
#include <QVariantList>

class AppConfig : public QObject {
    Q_OBJECT

    Q_PROPERTY(int fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
    Q_PROPERTY(qreal uiScale READ uiScale WRITE setUiScale NOTIFY uiScaleChanged)
    Q_PROPERTY(int windowHeight READ windowHeight WRITE setWindowHeight NOTIFY windowHeightChanged)
    Q_PROPERTY(bool alignCenter READ alignCenter WRITE setAlignCenter NOTIFY alignCenterChanged)
    Q_PROPERTY(int welcomeAlignMode READ welcomeAlignMode WRITE setWelcomeAlignMode NOTIFY welcomeAlignModeChanged)
    Q_PROPERTY(int sidebarWidth READ sidebarWidth WRITE setSidebarWidth NOTIFY sidebarWidthChanged)
    Q_PROPERTY(qreal opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)
    Q_PROPERTY(qreal sidebarOpacity READ sidebarOpacity WRITE setSidebarOpacity NOTIFY sidebarOpacityChanged)
    Q_PROPERTY(qreal cardOpacity READ cardOpacity WRITE setCardOpacity NOTIFY cardOpacityChanged)
    Q_PROPERTY(qreal wallpapersOpacity READ wallpapersOpacity WRITE setWallpapersOpacity NOTIFY wallpapersOpacityChanged)
    Q_PROPERTY(qreal wallpapersBlur READ wallpapersBlur WRITE setWallpapersBlur NOTIFY wallpapersBlurChanged)
    Q_PROPERTY(qreal dialogOpacity READ dialogOpacity WRITE setDialogOpacity NOTIFY dialogOpacityChanged)
    Q_PROPERTY(qreal dialogBlur READ dialogBlur WRITE setDialogBlur NOTIFY dialogBlurChanged)
    Q_PROPERTY(bool autoGlass READ autoGlass WRITE setAutoGlass NOTIFY autoGlassChanged)
    Q_PROPERTY(QString animType READ animType WRITE setAnimType NOTIFY animTypeChanged)
    Q_PROPERTY(QString welcomeAnimType READ welcomeAnimType WRITE setWelcomeAnimType NOTIFY welcomeAnimTypeChanged)
    Q_PROPERTY(QString windowOpenAnimType READ windowOpenAnimType WRITE setWindowOpenAnimType NOTIFY windowOpenAnimTypeChanged)
    Q_PROPERTY(int animDuration READ animDuration WRITE setAnimDuration NOTIFY animDurationChanged)
    Q_PROPERTY(bool rememberLastTab READ rememberLastTab WRITE setRememberLastTab NOTIFY rememberLastTabChanged)
        Q_PROPERTY(bool musicPrivacyMode READ musicPrivacyMode WRITE setMusicPrivacyMode NOTIFY musicPrivacyModeChanged)
    Q_PROPERTY(bool streamerMode READ streamerMode WRITE setStreamerMode NOTIFY streamerModeChanged)
    Q_PROPERTY(bool webShareRunning READ webShareRunning NOTIFY webShareChanged)
    Q_PROPERTY(QString webShareUrl READ webShareUrl NOTIFY webShareChanged)
    Q_PROPERTY(QString webShareQrPath READ webShareQrPath NOTIFY webShareChanged)
    Q_PROPERTY(QString webShareStatus READ webShareStatus NOTIFY webShareChanged)
    Q_PROPERTY(QString webShareMode READ webShareMode NOTIFY webShareChanged)
    Q_PROPERTY(QString webShareActiveTitle READ webShareActiveTitle NOTIFY webShareChanged)
    Q_PROPERTY(QVariantList webShareItems READ webShareItems NOTIFY webShareChanged)
    Q_PROPERTY(bool firstRunCompleted READ firstRunCompleted WRITE setFirstRunCompleted NOTIFY firstRunChanged)
    Q_PROPERTY(QString wallpapersDir READ wallpapersDir WRITE setWallpapersDir NOTIFY pathsChanged)
    Q_PROPERTY(QString musicDir READ musicDir WRITE setMusicDir NOTIFY pathsChanged)
    Q_PROPERTY(QString backupsDir READ backupsDir WRITE setBackupsDir NOTIFY pathsChanged)
    Q_PROPERTY(int pkgNativeCount READ pkgNativeCount NOTIFY backupStateChanged)
    Q_PROPERTY(int pkgAurCount READ pkgAurCount NOTIFY backupStateChanged)
    Q_PROPERTY(QVariantList backupArchives READ backupArchives NOTIFY backupStateChanged)
    Q_PROPERTY(bool sysBusy READ sysBusy NOTIFY sysProgressChanged)
    Q_PROPERTY(int sysProgress READ sysProgress NOTIFY sysProgressChanged)
    Q_PROPERTY(QString sysStatusText READ sysStatusText NOTIFY sysProgressChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateStateChanged)
    Q_PROPERTY(QString localVersionInfo READ localVersionInfo NOTIFY updateStateChanged)
    Q_PROPERTY(QString remoteVersionInfo READ remoteVersionInfo NOTIFY updateStateChanged)
    Q_PROPERTY(QString updateChangelog READ updateChangelog NOTIFY updateStateChanged)
    Q_PROPERTY(bool phoneBridgeRunning READ phoneBridgeRunning NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QString phoneBridgeUrl READ phoneBridgeUrl NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QString phoneBridgeQrPath READ phoneBridgeQrPath NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QString phoneBridgeStatus READ phoneBridgeStatus NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QVariantList phoneSharedItems READ phoneSharedItems NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QString phoneWirelessIp READ phoneWirelessIp WRITE setPhoneWirelessIp NOTIFY phoneBridgeChanged)
    Q_PROPERTY(int phoneMouseMode READ phoneMouseMode WRITE setPhoneMouseMode NOTIFY phoneBridgeChanged)
    Q_PROPERTY(bool phoneTurnScreenOff READ phoneTurnScreenOff WRITE setPhoneTurnScreenOff NOTIFY phoneBridgeChanged)
    Q_PROPERTY(bool phoneScreenRunning READ phoneScreenRunning NOTIFY phoneBridgeChanged)
    Q_PROPERTY(QString hiddenSidebarTabs READ hiddenSidebarTabs WRITE setHiddenSidebarTabs NOTIFY hiddenSidebarTabsChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)

    Q_PROPERTY(bool borderGlowEnabled READ borderGlowEnabled WRITE setBorderGlowEnabled NOTIFY borderGlowEnabledChanged)
    Q_PROPERTY(bool borderGlowAllPages READ borderGlowAllPages WRITE setBorderGlowAllPages NOTIFY borderGlowAllPagesChanged)
    Q_PROPERTY(qreal borderGlowIntensity READ borderGlowIntensity WRITE setBorderGlowIntensity NOTIFY borderGlowIntensityChanged)
    Q_PROPERTY(qreal borderGlowSpread READ borderGlowSpread WRITE setBorderGlowSpread NOTIFY borderGlowSpreadChanged)
    Q_PROPERTY(qreal borderGlowSpeed READ borderGlowSpeed WRITE setBorderGlowSpeed NOTIFY borderGlowSpeedChanged)
    Q_PROPERTY(int borderGlowColorMode READ borderGlowColorMode WRITE setBorderGlowColorMode NOTIFY borderGlowColorModeChanged)
    Q_PROPERTY(int borderGlowDirection READ borderGlowDirection WRITE setBorderGlowDirection NOTIFY borderGlowDirectionChanged)
    Q_PROPERTY(qreal cursorGlowIntensity READ cursorGlowIntensity WRITE setCursorGlowIntensity NOTIFY cursorGlowIntensityChanged)
    Q_PROPERTY(qreal clickFlashIntensity READ clickFlashIntensity WRITE setClickFlashIntensity NOTIFY clickFlashIntensityChanged)
    Q_PROPERTY(int clickFlashShape READ clickFlashShape WRITE setClickFlashShape NOTIFY clickFlashShapeChanged)

    // Цвета и раздельное редактирование палитры
    Q_PROPERTY(bool syncColorsWithAccent READ syncColorsWithAccent WRITE setSyncColorsWithAccent NOTIFY syncColorsWithAccentChanged)
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(QColor accentTextColor READ accentTextColor NOTIFY accentColorChanged)
    Q_PROPERTY(QColor borderGlowCustomColor READ borderGlowCustomColor WRITE setBorderGlowCustomColor NOTIFY borderGlowCustomColorChanged)
    Q_PROPERTY(QColor cursorCustomColor READ cursorCustomColor WRITE setCursorCustomColor NOTIFY cursorCustomColorChanged)
    Q_PROPERTY(QColor windowBgColor READ windowBgColor WRITE setWindowBgColor NOTIFY windowBgColorChanged)
    Q_PROPERTY(QColor cardBgColor READ cardBgColor WRITE setCardBgColor NOTIFY cardBgColorChanged)
    Q_PROPERTY(QColor m3Primary READ m3Primary NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3PrimaryContainer READ m3PrimaryContainer NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3OnPrimaryContainer READ m3OnPrimaryContainer NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3SecondaryContainer READ m3SecondaryContainer NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3Surface READ m3Surface NOTIFY windowBgColorChanged)
    Q_PROPERTY(QColor m3SurfaceContainer READ m3SurfaceContainer NOTIFY cardBgColorChanged)
    Q_PROPERTY(QColor m3SurfaceContainerHigh READ m3SurfaceContainerHigh NOTIFY cardBgColorChanged)
    Q_PROPERTY(QColor m3Outline READ m3Outline NOTIFY accentColorChanged)
    Q_PROPERTY(bool m3DynamicWallpaperColors READ m3DynamicWallpaperColors WRITE setM3DynamicWallpaperColors NOTIFY m3AttributesChanged)
    Q_PROPERTY(QColor m3SecondaryColor READ m3SecondaryColor WRITE setM3SecondaryColor NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3TertiaryColor READ m3TertiaryColor WRITE setM3TertiaryColor NOTIFY accentColorChanged)
    Q_PROPERTY(QColor m3TertiaryContainer READ m3TertiaryContainer NOTIFY accentColorChanged)
    Q_PROPERTY(int m3Preset READ m3Preset WRITE applyM3Preset NOTIFY m3AttributesChanged)
    Q_PROPERTY(int m3ElevationStyle READ m3ElevationStyle WRITE setM3ElevationStyle NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal m3SurfaceTintStrength READ m3SurfaceTintStrength WRITE setM3SurfaceTintStrength NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal m3ContrastLevel READ m3ContrastLevel WRITE setM3ContrastLevel NOTIFY m3AttributesChanged)
    Q_PROPERTY(int m3WindowRadius READ m3WindowRadius WRITE setM3WindowRadius NOTIFY m3AttributesChanged)
    Q_PROPERTY(int m3CardRadius READ m3CardRadius WRITE setM3CardRadius NOTIFY m3AttributesChanged)
    Q_PROPERTY(int m3ControlRadius READ m3ControlRadius WRITE setM3ControlRadius NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal m3OutlineWidth READ m3OutlineWidth WRITE setM3OutlineWidth NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal m3OutlineOpacity READ m3OutlineOpacity WRITE setM3OutlineOpacity NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal sliderWaveSpeed READ sliderWaveSpeed WRITE setSliderWaveSpeed NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal sliderWaveAmplitude READ sliderWaveAmplitude WRITE setSliderWaveAmplitude NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal sliderWaveLength READ sliderWaveLength WRITE setSliderWaveLength NOTIFY m3AttributesChanged)
    Q_PROPERTY(qreal sliderThickness READ sliderThickness WRITE setSliderThickness NOTIFY m3AttributesChanged)

public:
    explicit AppConfig(QObject *parent = nullptr);

    int fontSize() const { return m_fontSize; }
    void setFontSize(int v);
    qreal uiScale() const { return m_uiScale; }
    void setUiScale(qreal v);
    int windowHeight() const { return m_windowHeight; }
    void setWindowHeight(int v);
    bool alignCenter() const { return m_alignCenter; }
    void setAlignCenter(bool v);
    int welcomeAlignMode() const { return m_welcomeAlignMode; }
    void setWelcomeAlignMode(int v);
    int sidebarWidth() const { return m_sidebarWidth; }
    void setSidebarWidth(int v);
    qreal opacity() const { return m_opacity; }
    void setOpacity(qreal v);
    qreal sidebarOpacity() const { return m_sidebarOpacity; }
    void setSidebarOpacity(qreal v);
    qreal cardOpacity() const { return m_cardOpacity; }
    void setCardOpacity(qreal v);
    qreal wallpapersOpacity() const { return m_wallpapersOpacity; }
    void setWallpapersOpacity(qreal v);
    qreal wallpapersBlur() const { return m_wallpapersBlur; }
    void setWallpapersBlur(qreal v);
    qreal dialogOpacity() const { return m_dialogOpacity; }
    void setDialogOpacity(qreal v);
    qreal dialogBlur() const { return m_dialogBlur; }
    void setDialogBlur(qreal v);
    bool autoGlass() const { return m_autoGlass; }
    void setAutoGlass(bool v);
    QString animType() const { return m_animType; }
    void setAnimType(const QString &v);
    QString welcomeAnimType() const { return m_welcomeAnimType; }
    void setWelcomeAnimType(const QString &v);
    QString windowOpenAnimType() const {
        QSettings s("whrr", "HyprSettings");
        return s.value("windowOpenAnimType", m_windowOpenAnimType).toString();
    }
    void setWindowOpenAnimType(const QString &v) {
        if (windowOpenAnimType() != v) {
            m_windowOpenAnimType = v;
            QSettings s("whrr", "HyprSettings");
            s.setValue("windowOpenAnimType", v);
            emit windowOpenAnimTypeChanged();
        }
    }
    int animDuration() const { return m_animDuration; }
    void setAnimDuration(int v);
    bool rememberLastTab() const { return m_rememberLastTab; }
    void setRememberLastTab(bool v);
    bool musicPrivacyMode() const { return m_musicPrivacyMode; }
    void setMusicPrivacyMode(bool v);
    bool streamerMode() const { return m_streamerMode; }
    void setStreamerMode(bool v);

    bool firstRunCompleted() const { return m_firstRunCompleted; }
    void setFirstRunCompleted(bool v);
    QString wallpapersDir() const { return m_wallpapersDir; }
    void setWallpapersDir(const QString &v);
    QString musicDir() const { return m_musicDir; }
    void setMusicDir(const QString &v);
    QString backupsDir() const { return m_backupsDir; }
    void setBackupsDir(const QString &v);
    Q_INVOKABLE void completeFirstRunSetup(const QString &wallDir, const QString &musDir, const QString &bakDir, bool downloadWalls);

    int pkgNativeCount() const { return m_pkgNativeCount; }
    int pkgAurCount() const { return m_pkgAurCount; }
    QVariantList backupArchives() const { return m_backupArchives; }
    bool sysBusy() const { return m_sysBusy; }
    int sysProgress() const { return m_sysProgress; }
    QString sysStatusText() const { return m_sysStatusText; }
    bool updateAvailable() const { return m_updateAvailable; }
    QString localVersionInfo() const { return m_localVersionInfo; }
    QString remoteVersionInfo() const { return m_remoteVersionInfo; }
    QString updateChangelog() const { return m_updateChangelog; }

    Q_INVOKABLE void refreshBackupInfo();
    Q_INVOKABLE void generatePackageScript();
    Q_INVOKABLE void createFullBackup();
    Q_INVOKABLE void restoreFromBackup(const QString &archivePath, bool installPackages);
    Q_INVOKABLE void deleteBackupArchive(const QString &archivePath);
    Q_INVOKABLE void openBackupsFolder();
    Q_INVOKABLE void checkUpdates();
    Q_INVOKABLE void installUpdate();
    bool phoneBridgeRunning() const { return m_phoneBridgeRunning; }
    QString phoneBridgeUrl() const { return m_phoneBridgeUrl; }
    QString phoneBridgeQrPath() const { return m_phoneBridgeQrPath; }
    QString phoneBridgeStatus() const { return m_phoneBridgeStatus; }
    QVariantList phoneSharedItems() const { return m_phoneSharedItems; }
    Q_INVOKABLE void togglePhoneBridge();
    Q_INVOKABLE void refreshPhoneBridgeState();
    Q_INVOKABLE void sendTextToPhone(const QString &text);
    Q_INVOKABLE void sendClipboardToPhone();
    Q_INVOKABLE void shareFileToPhone(const QString &filePath);
    Q_INVOKABLE void quickCloudShare(const QString &target, bool isFile);
    Q_INVOKABLE void clearPhoneItems();
    Q_INVOKABLE void openPhoneDownloadsFolder();
    QString phoneWirelessIp() const { return m_phoneWirelessIp; }
    void setPhoneWirelessIp(const QString &v);
    int phoneMouseMode() const { return m_phoneMouseMode; }
    void setPhoneMouseMode(int v);
    bool phoneTurnScreenOff() const { return m_phoneTurnScreenOff; }
    void setPhoneTurnScreenOff(bool v);
    bool phoneScreenRunning() const { return m_phoneScreenRunning; }
    Q_INVOKABLE void startPhoneScreen(const QString &mode, const QString &ip, int fps, bool turnScreenOff);
    Q_INVOKABLE void stopPhoneScreen();
    Q_INVOKABLE void pressPhonePowerKey();
    bool webShareRunning() const { return m_webShareRunning; }
    QString webShareUrl() const { return m_webShareUrl; }
    QString webShareQrPath() const { return m_webShareQrPath; }
    QString webShareStatus() const { return m_webShareStatus; }
    QString webShareMode() const { return m_webShareMode; }
    QString webShareActiveTitle() const { return m_webShareActiveTitle; }
    QVariantList webShareItems() const { return m_webShareItems; }
    Q_INVOKABLE void refreshWebShareState();
    Q_INVOKABLE void toggleWebShare();
    Q_INVOKABLE void hostPathForFriend(const QString &path);
    Q_INVOKABLE void hostHtmlCodeForFriend(const QString &htmlCode, const QString &title);
    Q_INVOKABLE void pickFileForWebShare(bool pickFolder);
    Q_INVOKABLE void removeWebShareItem(const QString &itemId);
    Q_INVOKABLE void setPrimaryWebShareItem(const QString &itemId);
    Q_INVOKABLE void clearWebShareItems();

    QString hiddenSidebarTabs() const { return m_hiddenSidebarTabs; }
    void setHiddenSidebarTabs(const QString &v);
    Q_INVOKABLE bool isTabVisible(int idx) const;
    Q_INVOKABLE void setTabVisible(int idx, bool visible);

    QString language() const { return m_language; }
    void setLanguage(const QString &v);
    Q_INVOKABLE QString trAuto(const QString &ruText) const;

    bool borderGlowEnabled() const { return m_borderGlowEnabled; }
    void setBorderGlowEnabled(bool v);
    bool borderGlowAllPages() const { return m_borderGlowAllPages; }
    void setBorderGlowAllPages(bool v);
    qreal borderGlowIntensity() const { return m_borderGlowIntensity; }
    void setBorderGlowIntensity(qreal v);
    qreal borderGlowSpread() const { return m_borderGlowSpread; }
    void setBorderGlowSpread(qreal v);
    qreal borderGlowSpeed() const { return m_borderGlowSpeed; }
    void setBorderGlowSpeed(qreal v);
    int borderGlowColorMode() const { return m_borderGlowColorMode; }
    void setBorderGlowColorMode(int v);
    int borderGlowDirection() const { return m_borderGlowDirection; }
    void setBorderGlowDirection(int v);
    qreal cursorGlowIntensity() const { return m_cursorGlowIntensity; }
    void setCursorGlowIntensity(qreal v);
    qreal clickFlashIntensity() const { return m_clickFlashIntensity; }
    void setClickFlashIntensity(qreal v);
    int clickFlashShape() const { return m_clickFlashShape; }
    void setClickFlashShape(int v);

    bool syncColorsWithAccent() const { return m_syncColorsWithAccent; }
    void setSyncColorsWithAccent(bool v);
    QColor accentColor() const { return m_accentColor; }
    void setAccentColor(const QColor &c);
    QColor accentTextColor() const;
    QColor borderGlowCustomColor() const { return m_borderGlowCustomColor; }
    void setBorderGlowCustomColor(const QColor &c);
    QColor cursorCustomColor() const { return m_cursorCustomColor; }
    void setCursorCustomColor(const QColor &c);
    QColor windowBgColor() const { return m_windowBgColor; }
    void setWindowBgColor(const QColor &c);
    QColor cardBgColor() const { return m_cardBgColor; }
    void setCardBgColor(const QColor &c);
    QColor m3Primary() const;
    QColor m3PrimaryContainer() const;
    QColor m3OnPrimaryContainer() const;
    QColor m3SecondaryContainer() const;
    QColor m3Surface() const;
    QColor m3SurfaceContainer() const;
    QColor m3SurfaceContainerHigh() const;
    QColor m3Outline() const;
    bool m3DynamicWallpaperColors() const { return m_m3DynamicWallpaperColors; }
    void setM3DynamicWallpaperColors(bool v);
    Q_INVOKABLE void extractPaletteFromWallpaper();

    QColor m3SecondaryColor() const { return m_m3SecondaryColor; }
    void setM3SecondaryColor(const QColor &c);
    QColor m3TertiaryColor() const { return m_m3TertiaryColor; }
    void setM3TertiaryColor(const QColor &c);
    QColor m3TertiaryContainer() const;

    int m3Preset() const { return m_m3Preset; }
    Q_INVOKABLE void applyM3Preset(int idx);
    int m3ElevationStyle() const { return m_m3ElevationStyle; }
    void setM3ElevationStyle(int v);
    qreal m3SurfaceTintStrength() const { return m_m3SurfaceTintStrength; }
    void setM3SurfaceTintStrength(qreal v);
    qreal m3ContrastLevel() const { return m_m3ContrastLevel; }
    void setM3ContrastLevel(qreal v);
    int m3WindowRadius() const { return m_m3WindowRadius; }
    void setM3WindowRadius(int v);
    int m3CardRadius() const { return m_m3CardRadius; }
    void setM3CardRadius(int v);
    int m3ControlRadius() const { return m_m3ControlRadius; }
    void setM3ControlRadius(int v);
    qreal m3OutlineWidth() const { return m_m3OutlineWidth; }
    void setM3OutlineWidth(qreal v);
    qreal m3OutlineOpacity() const { return m_m3OutlineOpacity; }
    void setM3OutlineOpacity(qreal v);
    qreal sliderWaveSpeed() const { return m_sliderWaveSpeed; }
    void setSliderWaveSpeed(qreal v);
    qreal sliderWaveAmplitude() const { return m_sliderWaveAmplitude; }
    void setSliderWaveAmplitude(qreal v);
    qreal sliderWaveLength() const { return m_sliderWaveLength; }
    void setSliderWaveLength(qreal v);
    qreal sliderThickness() const { return m_sliderThickness; }
    void setSliderThickness(qreal v);
    Q_INVOKABLE void resetM3Attributes();
    Q_INVOKABLE void resetToDefaultMonochrome();

    Q_INVOKABLE QString consumeLaunchCmd();
    Q_INVOKABLE bool isDaemonStart() const;
    Q_INVOKABLE void resetColors();
    Q_INVOKABLE void resetDefaults();
    Q_INVOKABLE void save();
    void load();

signals:
    void fontSizeChanged();
    void uiScaleChanged();
    void windowHeightChanged();
    void alignCenterChanged();
    void welcomeAlignModeChanged();
    void sidebarWidthChanged();
    void opacityChanged();
    void sidebarOpacityChanged();
    void cardOpacityChanged();
    void wallpapersOpacityChanged();
    void wallpapersBlurChanged();
    void dialogOpacityChanged();
    void dialogBlurChanged();
    void autoGlassChanged();
    void animTypeChanged();
    void welcomeAnimTypeChanged();
    void windowOpenAnimTypeChanged();
    void animDurationChanged();
    void rememberLastTabChanged();
    void musicPrivacyModeChanged();
    void streamerModeChanged();
    void webShareChanged();
    void firstRunChanged();
    void pathsChanged();
    void backupStateChanged();
    void sysProgressChanged();
    void updateStateChanged();
    void phoneBridgeChanged();
    void hiddenSidebarTabsChanged();
    void languageChanged();
    void borderGlowEnabledChanged();
    void borderGlowAllPagesChanged();
    void borderGlowIntensityChanged();
    void borderGlowSpreadChanged();
    void borderGlowSpeedChanged();
    void borderGlowColorModeChanged();
    void borderGlowDirectionChanged();
    void cursorGlowIntensityChanged();
    void clickFlashIntensityChanged();
    void clickFlashShapeChanged();
    void syncColorsWithAccentChanged();
    void accentColorChanged();
    void borderGlowCustomColorChanged();
    void cursorCustomColorChanged();
    void windowBgColorChanged();
    void cardBgColorChanged();
    void m3AttributesChanged();

private:
    QString configFilePath() const;
    void syncHyprlandLuaHeight(int h) const;
    void initTranslations();

    int m_fontSize = 11;
    qreal m_uiScale = 1.0;
    int m_windowHeight = 720;
    bool m_alignCenter = false;
    int m_welcomeAlignMode = 1;
    int m_sidebarWidth = 136;
    qreal m_opacity = 0.70;
    qreal m_sidebarOpacity = 0.00;
    qreal m_cardOpacity = 0.10;
    qreal m_wallpapersOpacity = 0.30;
    qreal m_wallpapersBlur = 0.02;
    qreal m_dialogOpacity = 0.45;
    qreal m_dialogBlur = 0.65;
    bool m_autoGlass = true;
    QString m_animType = "bounce";
    QString m_welcomeAnimType = "blackhole";
    QString m_windowOpenAnimType = "spring";
    int m_animDuration = 150;
    bool m_rememberLastTab = false;
    bool m_musicPrivacyMode = false;
    bool m_streamerMode = false;
    QString m_lastPhoneScreenMode = "usb";
    bool m_webShareRunning = false;
    QString m_webShareUrl;
    QString m_webShareQrPath;
    QString m_webShareStatus = "Сервер раздачи выключен";
    QString m_webShareMode = "files";
    QString m_webShareActiveTitle;
    QVariantList m_webShareItems;
    bool m_firstRunCompleted = true;
    QString m_wallpapersDir;
    QString m_musicDir;
    QString m_backupsDir;
    int m_pkgNativeCount = 0;
    int m_pkgAurCount = 0;
    QVariantList m_backupArchives;
    bool m_sysBusy = false;
    int m_sysProgress = 0;
    QString m_sysStatusText = "Готово к работе";
    bool m_updateAvailable = false;
    QString m_localVersionInfo = "main";
    QString m_remoteVersionInfo = "main";
    QString m_updateChangelog = "Нажмите «Проверить обновления» для запроса к GitHub.";
    QTimer *m_sysProgTimer = nullptr;
    bool m_phoneBridgeRunning = false;
    QString m_phoneBridgeUrl;
    QString m_phoneBridgeQrPath;
    QString m_phoneBridgeStatus = "Готово к обмену с телефоном";
    QVariantList m_phoneSharedItems;
    QString m_phoneWirelessIp;
    QString m_hiddenSidebarTabs = "";
    QString m_language = "ru";

    bool m_borderGlowEnabled = true;
    bool m_borderGlowAllPages = true;
    qreal m_borderGlowIntensity = 0.75;
    qreal m_borderGlowSpread = 0.45;
    qreal m_borderGlowSpeed = 1.00;
    int m_borderGlowColorMode = 0;
    int m_borderGlowDirection = 0;
    qreal m_cursorGlowIntensity = 0.65;
    qreal m_clickFlashIntensity = 0.70;
    int m_clickFlashShape = 0;

    bool m_syncColorsWithAccent = true;
    QColor m_accentColor = QColor("#a8c7fa");
    QColor m_borderGlowCustomColor = QColor("#ffffff");
    QColor m_cursorCustomColor = QColor("#ffffff");
    QColor m_windowBgColor = QColor("#111318");
    QColor m_cardBgColor = QColor("#1e2028");
    bool m_m3DynamicWallpaperColors = true;
    QColor m_m3SecondaryColor = QColor("#bec6dc");
    QColor m_m3TertiaryColor = QColor("#debcdf");
    int m_m3Preset = 0;
    int m_m3ElevationStyle = 0;
    qreal m_m3SurfaceTintStrength = 0.22;
    qreal m_m3ContrastLevel = 0.50;
    int m_m3WindowRadius = 20;
    int m_m3CardRadius = 16;
    int m_m3ControlRadius = 10;
    qreal m_m3OutlineWidth = 1.0;
    qreal m_m3OutlineOpacity = 0.28;
    qreal m_sliderWaveSpeed = 1.25;
    qreal m_sliderWaveAmplitude = 2.4;
    qreal m_sliderWaveLength = 22.0;
    qreal m_sliderThickness = 2.4;
    QFileSystemWatcher *m_wallWatcher = nullptr;
    QTimer *m_wallExtractTimer = nullptr;

    int m_phoneMouseMode = 0;
    bool m_phoneTurnScreenOff = false;
    bool m_phoneScreenRunning = false;
    QHash<QString, QString> m_enDict;
};
