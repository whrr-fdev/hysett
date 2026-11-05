#include <sys/prctl.h>
#include <signal.h>
#include <malloc.h>
#include <QPixmapCache>
#include <QTimer>
#include <QFile>
#include <QVector>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QLoggingCategory>
#include <QMetaObject>
#include <QRegion>
#include "ThemeEngine.h"
#include "HyprIpc.h"
#include "AppInstance.h"
#include "AppConfig.h"
#include "LookManager.h"
#include "CursorManager.h"
#include "MonitorsManager.h"
#include "DevicesManager.h"
#include "NetworkManager.h"
#include "BluetoothManager.h"
#include "AnimsManager.h"
#include "WaybarManager.h"
#include "MakoManager.h"
#include "AutostartManager.h"
#include "BindsManager.h"
#include "RulesManager.h"
#include "AppsManager.h"
#include "WidgetsManager.h"
#include "WallpapersManager.h"
#include "ShadersManager.h"
#include "AtmosphereManager.h"
#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Window>
#endif
#include "IconImageProvider.h"

int main(int argc, char *argv[]) {
    mallopt(M_ARENA_MAX, 2);
    mallopt(M_MMAP_THRESHOLD, 64 * 1024);
    mallopt(M_TRIM_THRESHOLD, 64 * 1024);

    bool isDaemonFlag = false;
    bool isAtmoOverlay = false;
    QString launchTarget = "default";
    QVector<char*> cleanArgv;
    cleanArgv.push_back(argv[0]);
    for (int i = 1; i < argc; ++i) {
        QString arg = QString::fromUtf8(argv[i]);
        if (arg == "--daemon") {
            isDaemonFlag = true;
            cleanArgv.push_back(argv[i]);
        } else if (arg == "--wallpaper" || arg == "--wallpapers") {
            launchTarget = "wallpaper";
        } else if (arg == "--apps") {
            launchTarget = "apps";
        } else if (arg == "--atmosphere-overlay") {
            isAtmoOverlay = true;
        } else if (arg == "--search") {
            launchTarget = "search";
        } else if (arg == "--power") {
            launchTarget = "power";
        } else if (arg == "--clipboard") {
            launchTarget = "clipboard";
        } else {
            cleanArgv.push_back(argv[i]);
        }
    }
    qputenv("HYSETT_DAEMON_START", isDaemonFlag ? "1" : "0");
    if (!isDaemonFlag) {
        QFile cmdFile("/tmp/hysett_launch_cmd");
        if (cmdFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
            cmdFile.write(launchTarget.toUtf8());
            cmdFile.close();
        }
    }
    argc = cleanArgv.size();
    argv = cleanArgv.data();

    qputenv("QSG_TRANSIENT_IMAGES", "1");
    qputenv("QML_DISK_CACHE", "aot");
    QPixmapCache::setCacheLimit(16384);
    QQuickStyle::setStyle("Basic");

    QLoggingCategory::setFilterRules(
        "qt.qpa.wayland.textinput.debug=false\n"
        "qt.qpa.wayland.textinput=false\n"
        "qt.qpa.services=false\n"
        "qt.svg=false\n"
        "qt.svg.warning=false\n"
    );

    QQuickWindow::setDefaultAlphaBuffer(true);
    QGuiApplication app(argc, argv);
    QPixmapCache::setCacheLimit(32768);
    app.setApplicationName("com.whrr.HyprSettings");
    app.setDesktopFileName("com.whrr.HyprSettings");
    app.setOrganizationName("whrr");
    app.setOrganizationDomain("com.whrr");

    if (isAtmoOverlay) {
        prctl(PR_SET_PDEATHSIG, SIGTERM);
        AppInstance ovSingle("com.whrr.HyprAtmosphere.socket");
        if (!ovSingle.checkSingleInstance()) return 0;
        app.setApplicationName("");
        app.setApplicationDisplayName("");
        app.setDesktopFileName("hypratmooverlay");
        QQmlApplicationEngine ovEngine;
        static AtmosphereManager atmoOverlayMgr(true);
        qmlRegisterSingletonInstance("HySett", 1, 0, "Atmosphere", &atmoOverlayMgr);
        qmlRegisterType<AtmosphereCanvas>("HySett", 1, 0, "AtmosphereCanvas");
        ovEngine.rootContext()->setContextProperty("Atmosphere", &atmoOverlayMgr);
        const QUrl ovUrl(QStringLiteral("qrc:/qt/qml/HySett/qml/AtmosphereOverlay.qml"));
        QObject::connect(&ovEngine, &QQmlApplicationEngine::objectCreated, &app, [](QObject *obj, const QUrl &) {
            if (auto *w = qobject_cast<QQuickWindow *>(obj)) {
                w->setTitle("");
                w->setFlag(Qt::WindowTransparentForInput, false);
                w->setFlag(Qt::WindowDoesNotAcceptFocus, true);
#ifdef HAVE_LAYERSHELLQT
                if (auto *ls = LayerShellQt::Window::get(w)) {
                    ls->setLayer(LayerShellQt::Window::LayerTop);
                    ls->setExclusiveZone(-1);
                    ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
                    ls->setAnchors(LayerShellQt::Window::Anchors(
                        LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom |
                        LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
                    ls->setScope(QStringLiteral("hypratmooverlay"));
                }
#endif
                w->show();
                w->setMask(QRegion(-10, -10, 1, 1));
            }
        }, Qt::DirectConnection);
        ovEngine.load(ovUrl);
        return app.exec();
    }

    AppInstance instance("com.whrr.HyprSettings.socket");
    if (!instance.checkSingleInstance()) return 0;

    QQmlApplicationEngine engine;
    engine.addImageProvider("cursor", new CursorImageProvider());
    engine.addImageProvider("appicon", new IconImageProvider());
    engine.addImageProvider("wallthumb", new WallThumbProvider());

    static ThemeEngine themeEngine;
    static HyprIpc hyprIpc;
    hyprIpc.setEngine(&engine);
    static AppConfig appConfig;
    static LookManager lookManager;
    static CursorManager cursorManager;
    static MonitorsManager monitorsManager;
    static DevicesManager devicesManager;
    static NetworkManager networkManager;
    static BluetoothManager bluetoothManager;
    static AnimsManager animsManager;
    static WaybarManager waybarManager;
    MakoManager *makoMgr = new MakoManager(&app);
    static AutostartManager autostartManager;
    static BindsManager bindsManager;
    static RulesManager rulesManager;
    static AppsManager appsManager;
    static WidgetsManager widgetsManager;
    static WallpapersManager wallpapersManager;
    static ShadersManager shadersManager;
    static AtmosphereManager atmosphereManager(false);

    qmlRegisterSingletonInstance("HySett", 1, 0, "Theme", &themeEngine);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Hypr", &hyprIpc);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Config", &appConfig);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Look", &lookManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Cursor", &cursorManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Monitors", &monitorsManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Devices", &devicesManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Network", &networkManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Bluetooth", &bluetoothManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Anims", &animsManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Waybar", &waybarManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Mako", makoMgr);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Autostart", &autostartManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Binds", &bindsManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Rules", &rulesManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Apps", &appsManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Widgets", &widgetsManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Wallpapers", &wallpapersManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Shaders", &shadersManager);
    qmlRegisterSingletonInstance("HySett", 1, 0, "Atmosphere", &atmosphereManager);
    qmlRegisterType<AtmosphereCanvas>("HySett", 1, 0, "AtmosphereCanvas");

    auto ctx = engine.rootContext();
    ctx->setContextProperty("Theme", &themeEngine);
    ctx->setContextProperty("Hypr", &hyprIpc);
    ctx->setContextProperty("Config", &appConfig);
    ctx->setContextProperty("Look", &lookManager);
    ctx->setContextProperty("Cursor", &cursorManager);
    ctx->setContextProperty("Monitors", &monitorsManager);
    ctx->setContextProperty("Devices", &devicesManager);
    ctx->setContextProperty("Network", &networkManager);
    ctx->setContextProperty("Bluetooth", &bluetoothManager);
    ctx->setContextProperty("Anims", &animsManager);
    ctx->setContextProperty("Waybar", &waybarManager);
    ctx->setContextProperty("Mako", makoMgr);
    ctx->setContextProperty("Autostart", &autostartManager);
    ctx->setContextProperty("Binds", &bindsManager);
    ctx->setContextProperty("Rules", &rulesManager);
    ctx->setContextProperty("Apps", &appsManager);
    ctx->setContextProperty("Widgets", &widgetsManager);
    ctx->setContextProperty("Wallpapers", &wallpapersManager);
    ctx->setContextProperty("Shaders", &shadersManager);
    ctx->setContextProperty("Atmosphere", &atmosphereManager);

    QObject::connect(&instance, &AppInstance::toggleRequested, [&engine]() {
        if (engine.rootObjects().isEmpty()) return;
        QObject *rootObj = engine.rootObjects().first();
        if (rootObj) {
            QMetaObject::invokeMethod(rootObj, "handleExternalTrigger");
        }
    });

    const QUrl url(QStringLiteral("qrc:/qt/qml/HySett/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) QCoreApplication::exit(-1);
        if (auto *w = qobject_cast<QQuickWindow *>(obj)) {
#ifdef HAVE_LAYERSHELLQT
            if (auto *ls = LayerShellQt::Window::get(w)) {
                ls->setLayer(LayerShellQt::Window::LayerTop);
                ls->setExclusiveZone(-1);
                ls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
                ls->setAnchors(LayerShellQt::Window::Anchors(
                    LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom |
                    LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
                ls->setScope(QStringLiteral("waybar"));
            }
            static QQuickWindow *strutWin = nullptr;
            if (!strutWin) {
                strutWin = new QQuickWindow();
                strutWin->setColor(Qt::transparent);
                strutWin->setMask(QRegion(0, 0, 1, 1));
                auto updateStrut = [&]() {
                    int pos = waybarManager.barPosition();
                    int thick = waybarManager.barHeight() + waybarManager.marginTop() + 4 + (pos >= 2 ? 12 : 0);
                    if (pos <= 1) { strutWin->setWidth(1920); strutWin->setHeight(thick); }
                    else { strutWin->setWidth(thick); strutWin->setHeight(1080); }
                    if (auto *sls = LayerShellQt::Window::get(strutWin)) {
                        sls->setLayer(LayerShellQt::Window::LayerBottom);
                        sls->setExclusiveZone(thick);
                        sls->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
                        if (pos == 0) sls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
                        else if (pos == 1) sls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorBottom | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight));
                        else if (pos == 2) sls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom));
                        else sls->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorRight | LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom));
                        sls->setScope(QStringLiteral("hysett-strut"));
                    }
                };
                updateStrut();
                strutWin->show();
                QObject::connect(&waybarManager, &WaybarManager::stateChanged, strutWin, updateStrut);
            }
#endif
            w->show();
        }
    }, Qt::DirectConnection);

    engine.load(url);
    malloc_trim(0);
    return app.exec();
}
