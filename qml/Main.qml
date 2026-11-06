import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "components"
import "views"

ApplicationWindow {
    id: root
    visible: false
    width: 1920
    height: 1080
    title: "Control Center"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool drawerOpen: Config ? !Config.isDaemonStart() : false
    property string drawerMode: "settings"
    property bool isWallpaperExpanded: false
    property int powerSelectedIndex: 0
    property string clipSearchQuery: ""
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    property string trayMenuClass: ""
    property string trayMenuName: ""
    property string trayMenuSni: ""
    property real trayMenuTargetX: 1400

    property real barExpandProgress: 0.0
    property real drawerProgress: 0.0
    readonly property bool drawerActive: drawerProgress > 0.005 || barExpandProgress > 0.005

    SequentialAnimation {
        id: openSeqAnim
        NumberAnimation {
            target: root; property: "barExpandProgress"
            to: 1.0
            duration: (root.baseBarW < root.targetDrawerW && root.drawerMode !== "traymenu") ? (Waybar ? Waybar.barAnimDuration : 75) : 10
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "drawerProgress"
            to: 1.0; duration: 300; easing.type: Easing.OutQuint
        }
    }

    SequentialAnimation {
        id: closeSeqAnim
        NumberAnimation {
            target: root; property: "drawerProgress"
            to: 0.0; duration: 240; easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root; property: "barExpandProgress"
            to: 0.0
            duration: (root.baseBarW < root.targetDrawerW && root.drawerMode !== "traymenu") ? (Waybar ? Waybar.barAnimDuration : 75) : 10
            easing.type: Easing.OutQuint
        }
    }

    property string pendingDrawerMode: "settings"
    property int pendingTabIdx: 0
    property string pendingTrayClass: ""
    property string pendingTrayName: ""
    property string pendingTraySni: ""
    property real pendingTrayX: 1400

    SequentialAnimation {
        id: switchDrawerAnim
        NumberAnimation {
            target: root; property: "drawerProgress"
            to: 0.0; duration: 170; easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.isWallpaperExpanded = false
                root.drawerMode = root.pendingDrawerMode
                if (root.pendingDrawerMode === "traymenu") {
                    root.trayMenuClass = root.pendingTrayClass
                    root.trayMenuName = root.pendingTrayName
                    root.trayMenuSni = root.pendingTraySni
                    root.trayMenuTargetX = root.pendingTrayX
                } else if (root.pendingDrawerMode === "clipboard" && Waybar) {
                    root.clipSearchQuery = ""
                    Qt.callLater(() => Waybar.refreshClipboard())
                } else if (root.pendingDrawerMode === "calendar") {
                    var now = new Date()
                    root.calYear = now.getFullYear()
                    root.calMonth = now.getMonth()
                } else if (root.pendingDrawerMode === "power") {
                    root.powerSelectedIndex = 0
                } else if (root.pendingDrawerMode === "settings") {
                    if (root.pendingTabIdx === 21 && Waybar) Waybar.refreshProcesses()
                    if (root.pendingTabIdx === 23 && Waybar && Waybar.clipboardItems.length === 0) Qt.callLater(() => Waybar.refreshClipboard())
                    pageController.jumpToPageInstant(root.pendingTabIdx)
                }
                root.syncTabBlur()
            }
        }
        NumberAnimation {
            target: root; property: "barExpandProgress"
            to: 1.0
            duration: (root.baseBarW < root.targetDrawerW && root.drawerMode !== "traymenu" && root.barExpandProgress < 0.99) ? (Waybar ? Waybar.barAnimDuration : 75) : 10
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "drawerProgress"
            to: 1.0; duration: 260; easing.type: Easing.OutQuint
        }
    }

    readonly property int notifCount: (Mako && Mako.activePopups) ? Mako.activePopups.length : 0
    readonly property bool notifOpen: notifCount > 0
    property real notifProgress: notifOpen ? 1.0 : 0.0
    readonly property bool notifActive: notifProgress > 0.005

    Behavior on notifProgress {
        NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
    }

    readonly property int barPos: Waybar ? Waybar.barPosition : 0
    readonly property bool isCenteredBar: Waybar ? Waybar.centeredBar : false
    readonly property int barH: Waybar ? Waybar.barHeight : 22
    readonly property int barTop: Waybar ? Waybar.marginTop : 4
    readonly property int fullBarLeft: Math.max(0, (Waybar ? Waybar.marginLeft : 10) - 2)
    readonly property int fullBarRight: Math.max(0, (Waybar ? Waybar.marginRight : 10) - 2)
    readonly property int maxAvailBarW: Math.max(400, root.width - fullBarLeft - fullBarRight)
    readonly property int customBarW: Waybar ? Math.min(maxAvailBarW, Waybar.barWidth) : maxAvailBarW

    readonly property bool winModVis: Waybar ? (Waybar.hiddenBarModules, Waybar.isBarModuleVisible("window")) : true
    readonly property bool isFixedTitle: Waybar ? Waybar.fixedTitleWidth : false
    readonly property bool hasWinTitle: winModVis && Waybar && Waybar.activeWindowTitle.length > 0
    readonly property real winPillTargetW: !winModVis ? 0 : (isFixedTitle ? 200 : (hasWinTitle ? Math.min(220, winLbl.implicitWidth + 16) : 0))
    readonly property real islandW: Math.min(maxAvailBarW, leftBarRow.implicitWidth + (winPillTargetW > 0 ? (winPillTargetW + 6) : 0) + rightBarRow.implicitWidth + 14)
    property real smoothBaseBarW: (barPos >= 2) ? islandW : (isCenteredBar ? islandW : customBarW)
    Behavior on smoothBaseBarW { NumberAnimation { duration: Waybar ? Waybar.barAnimDuration : 75; easing.type: Easing.OutQuint } }
    readonly property real baseBarW: smoothBaseBarW
    readonly property real expandedBarW: (drawerMode === "traymenu") ? baseBarW : Math.max(baseBarW, animDrawerW)
    readonly property real barW: baseBarW + (expandedBarW - baseBarW) * barExpandProgress
    readonly property real barLeft: {
        if (barPos === 2) return barTop
        if (barPos === 3) return root.width - barW - barTop
        return (isCenteredBar || customBarW < maxAvailBarW) ? ((root.width - barW) * 0.5) : fullBarLeft
    }
    readonly property int barRectY: (barPos === 1) ? (root.height - barH - barTop) : barTop

    readonly property int targetDrawerW: {
        if (drawerMode === "traymenu") return 230
        if (drawerMode === "power") return 280
        if (drawerMode === "calendar") return 300
        if (drawerMode === "clipboard") return 460
        return isWallpaperExpanded ? maxAvailBarW : Math.min(860, maxAvailBarW - 120)
    }
    readonly property int targetDrawerH: {
        if (drawerMode === "traymenu") return 196
        if (drawerMode === "power") return 295
        if (drawerMode === "calendar") return 285
        if (drawerMode === "clipboard") return 370
        return isWallpaperExpanded
               ? (root.height - (barTop + barH) - 14)
               : Math.min(540, Config ? Config.windowHeight : 520)
    }

    property real animDrawerW: targetDrawerW
    property real smoothTargetH: targetDrawerH
    // Плавная анимация боковых торчащих кусков при открытии/закрытии из узкой панели!
    readonly property real wingMix: Math.min(1.0, Math.pow(drawerProgress, 0.42) * 1.15)
    readonly property real effDrawerW: animDrawerW
    readonly property real animDrawerH: smoothTargetH * drawerProgress

    property real centerAnchorX: {
        if (drawerMode === "traymenu") return trayMenuTargetX
        if (barPos === 2) return barLeft + effDrawerW * 0.5
        if (barPos === 3) return barLeft + barW - effDrawerW * 0.5
        return root.width * 0.5
    }
    Behavior on centerAnchorX { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
    Behavior on animDrawerW { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
    Behavior on smoothTargetH { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

    readonly property real drawerX: Math.max(fullBarLeft, Math.min(fullBarLeft + maxAvailBarW - effDrawerW, centerAnchorX - effDrawerW * 0.5))
    readonly property real drawerY: (barPos === 1) ? (barRectY - animDrawerH) : (barRectY + barH)

    // Уведомления приходят у правого края экрана (когда панель узкая) и без пустого отступа сверху!
    readonly property int notifW: Mako ? Mako.width : 320
    readonly property int notifTargetH: Math.max(44, notifStackCol.implicitHeight + 2)
    property real smoothNotifTargetH: notifTargetH
    Behavior on smoothNotifTargetH { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
    readonly property real animNotifH: smoothNotifTargetH * notifProgress
    readonly property real notifX: {
        var anc = Mako ? Mako.anchor : "top-right"
        if (anc.indexOf("left") !== -1) return 10
        if (anc.indexOf("center") !== -1) return Math.round((root.width - notifW) * 0.5)
        return root.width - notifW - 10
    }
    readonly property real notifY: (barPos === 1)
                                   ? ((isCenteredBar || customBarW < maxAvailBarW) ? (root.height - animNotifH - barTop) : (barRectY - animNotifH))
                                   : ((isCenteredBar || customBarW < maxAvailBarW) ? barTop : (barRectY + barH))

    property bool modalOpen: false
    property bool barSavePromptOpen: false
    readonly property bool anyModalActive: modalOpen || barSavePromptOpen || (Monitors && Monitors.revertDialogActive)
    readonly property bool isWindowExpanded: isWallpaperExpanded

    property real wallpapersLiveOpacity: Config ? Config.wallpapersOpacity : 0.30
    property real wallpapersLiveBlur: Config ? Config.wallpapersBlur : 0.02

    Behavior on wallpapersLiveOpacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on wallpapersLiveBlur { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    function requestCloseDrawer() {
        if (Waybar && Waybar.barEditMode) {
            root.barSavePromptOpen = true
            return
        }
        root.drawerOpen = false
    }

    function syncInputMask() {
        if (Waybar) {
            Waybar.syncShellRegion(root, root.drawerActive, root.notifOpen || root.notifActive,
                                   Math.round(root.notifX), Math.round(root.notifY),
                                   Math.round(root.notifW), Math.round(root.notifTargetH + 12))
        }
    }

    function openDrawerWithMode(mode, tabIdx) {
        var targetTab = (mode === "settings") ? ((tabIdx !== undefined) ? tabIdx : 0) : -1

        if (root.drawerOpen) {
            var isSame = false
            if (mode === "settings" && root.drawerMode === "settings") {
                if (tabIdx === undefined) {
                    var barTabs = [5, 6, 7, 16, 20, 21, 23, 25, 26, 27]
                    isSame = (barTabs.indexOf(pageController.currentIndex) === -1)
                } else {
                    isSame = (pageController.currentIndex === tabIdx)
                }
            } else {
                isSame = (root.drawerMode === mode)
            }

            if (isSame) {
                switchDrawerAnim.stop()
                root.drawerOpen = false
                return
            }

            openSeqAnim.stop()
            closeSeqAnim.stop()
            switchDrawerAnim.stop()
            root.pendingDrawerMode = mode
            root.pendingTabIdx = (targetTab >= 0) ? targetTab : 0
            switchDrawerAnim.start()
            return
        }

        switchDrawerAnim.stop()
        root.isWallpaperExpanded = false
        root.drawerMode = mode
        if (mode === "clipboard" && Waybar) {
            root.clipSearchQuery = ""
            Qt.callLater(() => Waybar.refreshClipboard())
        } else if (mode === "calendar") {
            var now = new Date()
            root.calYear = now.getFullYear()
            root.calMonth = now.getMonth()
        } else if (mode === "power") {
            root.powerSelectedIndex = 0
        } else if (mode === "settings") {
            var initTab = (tabIdx !== undefined) ? tabIdx : ((Config && Config.rememberLastTab) ? pageController.currentIndex : 0)
            if (initTab === 21 && Waybar) Waybar.refreshProcesses()
            if (initTab === 23 && Waybar && Waybar.clipboardItems.length === 0) Qt.callLater(() => Waybar.refreshClipboard())
            pageController.jumpToPageInstant(initTab)
        }
        root.drawerOpen = true
    }

    function openTrayContextMenu(appData, globalX) {
        if (root.drawerOpen) {
            if (root.drawerMode === "traymenu" && root.trayMenuClass === appData.class) {
                switchDrawerAnim.stop()
                root.drawerOpen = false
                return
            }
            openSeqAnim.stop()
            closeSeqAnim.stop()
            switchDrawerAnim.stop()
            root.pendingDrawerMode = "traymenu"
            root.pendingTrayClass = appData.class
            root.pendingTrayName = appData.name || appData.class
            root.pendingTraySni = appData.sniService || ""
            root.pendingTrayX = globalX
            switchDrawerAnim.start()
            return
        }
        switchDrawerAnim.stop()
        root.trayMenuClass = appData.class
        root.trayMenuName = appData.name || appData.class
        root.trayMenuSni = appData.sniService || ""
        root.trayMenuTargetX = globalX
        root.drawerMode = "traymenu"
        root.drawerOpen = true
    }

    onDrawerOpenChanged: {
        openSeqAnim.stop()
        closeSeqAnim.stop()
        switchDrawerAnim.stop()
        if (drawerOpen) openSeqAnim.start()
        else closeSeqAnim.start()
        syncInputMask()
        if (!drawerOpen) {
            modalOpen = false
            trailActive = false
            isWallpaperExpanded = false
            root.mousePos = Qt.point(-500, -500)
            if (Theme) Theme.applyEffectiveBlur(Theme.windowBlur)
        } else {
            syncTabBlur()
        }
    }
    onDrawerActiveChanged: {
        syncInputMask()
        if (!drawerActive) {
            if (Config && !Config.rememberLastTab) pageController.resetToWelcomeInstant()
            if (Apps) { Apps.clearFileSearch(); Apps.clearPackageSearch() }
            if (Atmosphere) Atmosphere.releaseInAppCaches()
            if (Hypr) Hypr.deepCleanMemory()
        }
    }
    onNotifActiveChanged: syncInputMask()
    onNotifCountChanged: Qt.callLater(syncInputMask)
    onNotifTargetHChanged: Qt.callLater(syncInputMask)

    Component.onCompleted: {
        Qt.callLater(syncInputMask)
        if (drawerOpen) applyPendingLaunchCmd()
    }
    Connections {
        target: Waybar
        function onStateChanged() { root.syncInputMask() }
        function onCloseDrawerRequested() { if (root.drawerOpen) root.requestCloseDrawer() }
    }

    function syncWallpapersModeState() {
        root.wallpapersLiveOpacity = Config ? Config.wallpapersOpacity : 0.30
        root.wallpapersLiveBlur = Config ? Config.wallpapersBlur : 0.02
        root.syncTabBlur()
    }
    onIsWindowExpandedChanged: syncWallpapersModeState()

    property point mousePos: Qt.point(-500, -500)
    property point trail1: Qt.point(-500, -500)
    property point trail2: Qt.point(-500, -500)
    property point trail3: Qt.point(-500, -500)
    property bool trailActive: false
    property point clickPos: Qt.point(-500, -500)
    property real liquidTime: 0.0

    function handleExternalTrigger() {
        if (!Config) return
        var cmd = Config.consumeLaunchCmd()
        if (cmd === "wallpaper") {
            root.drawerMode = "settings"; pageController.jumpToPageInstant(14); root.isWallpaperExpanded = true; root.drawerOpen = true; root.syncWallpapersModeState()
        } else if (cmd === "apps") {
            root.openDrawerWithMode("settings", 12)
        } else if (cmd === "search") {
            root.openDrawerWithMode("settings", 16)
        } else if (cmd === "power") {
            root.openDrawerWithMode("power")
        } else if (cmd === "clipboard") {
            root.openDrawerWithMode("clipboard")
        } else {
            root.openDrawerWithMode("settings")
        }
    }

    function applyPendingLaunchCmd() {
        if (!Config) return
        var cmd = Config.consumeLaunchCmd()
        if (cmd === "wallpaper") {
            root.drawerMode = "settings"; pageController.jumpToPageInstant(14); root.isWallpaperExpanded = true; root.syncWallpapersModeState()
        } else if (cmd === "apps") {
            root.drawerMode = "settings"; pageController.jumpToPageInstant(12)
        } else if (cmd === "search") {
            root.drawerMode = "settings"; pageController.jumpToPageInstant(16)
        } else if (cmd === "power") {
            root.drawerMode = "power"
        } else if (cmd === "clipboard") {
            root.drawerMode = "clipboard"; if (Waybar) Qt.callLater(() => Waybar.refreshClipboard())
        }
    }

    function syncTabBlur() {
        if (!Theme || !Config) return
        if (root.drawerOpen && root.drawerMode === "settings" && pageController.currentIndex === 14 && Config.autoGlass) {
            var targetBlur = root.wallpapersLiveBlur
            Theme.applyEffectiveBlur(targetBlur)
        } else {
            Theme.applyEffectiveBlur(Theme.windowBlur)
        }
    }

    function triggerClickRipple(cx, cy) {
        if (Config && Config.clickFlashIntensity <= 0.01) return
        clickPos = Qt.point(cx, cy)
        clickAnim.restart()
    }

    function triggerPowerAction(idx) {
        root.drawerOpen = false
        if (!Waybar) return
        if (idx === 0) Waybar.runCommand("hyprlock")
        else if (idx === 1) Waybar.runCommand("hyprlock & systemctl suspend")
        else if (idx === 2) Waybar.runCommand("hyprlock & systemctl hibernate")
        else if (idx === 3) Waybar.runCommand("hyprshutdown --post-cmd \"bash -c 'pkill -KILL -u $(whoami)'\"")
        else if (idx === 4) Waybar.runCommand("systemctl reboot")
        else if (idx === 5) Waybar.runCommand("systemctl poweroff")
    }

    NumberAnimation on liquidTime {
        from: 0.0; to: 628.3185; duration: 120000
        loops: Animation.Infinite
        running: root.drawerActive
    }

    Timer {
        id: trailTimer
        interval: 16
        running: root.drawerActive && root.trailActive
        repeat: true
        onTriggered: {
            root.trail1 = Qt.point(root.trail1.x + (root.mousePos.x - root.trail1.x) * 0.38,
                                   root.trail1.y + (root.mousePos.y - root.trail1.y) * 0.38)
            root.trail2 = Qt.point(root.trail2.x + (root.trail1.x - root.trail2.x) * 0.30,
                                   root.trail2.y + (root.trail1.y - root.trail2.y) * 0.30)
            root.trail3 = Qt.point(root.trail3.x + (root.trail2.x - root.trail3.x) * 0.24,
                                   root.trail3.y + (root.trail2.y - root.trail3.y) * 0.24)
            var d = Math.abs(root.mousePos.x - root.trail3.x) + Math.abs(root.mousePos.y - root.trail3.y)
            if (d < 0.8) root.trailActive = false
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.isWallpaperExpanded) root.isWallpaperExpanded = false
            else if (root.barSavePromptOpen) root.barSavePromptOpen = false
            else if (!root.anyModalActive && root.drawerOpen) root.requestCloseDrawer()
        }
    }
    Shortcut {
        sequence: "Up"
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.powerSelectedIndex = (root.powerSelectedIndex + 5) % 6
    }
    Shortcut {
        sequence: "Down"
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.powerSelectedIndex = (root.powerSelectedIndex + 1) % 6
    }
    Shortcut {
        sequence: "Return"
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.triggerPowerAction(root.powerSelectedIndex)
    }

    Item {
        id: sceneRoot
        anchors.fill: parent


        // Отслеживание мыши в глобальных координатах сцены (свет курсора плавно переходит на панель задач!)
        HoverHandler {
            enabled: root.drawerActive
            onPointChanged: {
                if (root.mousePos.x < -100) {
                    root.trail1 = point.position; root.trail2 = point.position; root.trail3 = point.position
                }
                root.mousePos = point.position; root.trailActive = true
            }
        }

        MouseArea {
            x: 0
            y: root.barTop + root.barH
            width: parent.width
            height: parent.height - y
            enabled: root.drawerOpen
            z: 1
            onPressed: (mouse) => {
                var gy = mouse.y + y
                var inDrawer = (mouse.x >= root.drawerX && mouse.x <= root.drawerX + root.animDrawerW &&
                                gy >= root.drawerY && gy <= root.drawerY + root.animDrawerH)
                var inNotif = root.notifOpen && (mouse.x >= root.notifX && mouse.x <= root.notifX + root.notifW &&
                               gy >= root.notifY && gy <= root.notifY + root.animNotifH)
                if (!inDrawer && !inNotif && !root.anyModalActive) {
                    root.requestCloseDrawer()
                } else {
                    mouse.accepted = false
                }
            }
        }

        // ЕДИНЫЙ GLSL-ШЕЙДЕР (ПАНЕЛЬ + ОКНО + УВЕДОМЛЕНИЯ + СВЕТ КУРСОРА НА ПАНЕЛИ И ОКНЕ)
        ShaderEffect {
            id: mergedShellBg
            anchors.fill: parent
            z: 2
            property real currentOpacity: (root.drawerOpen && root.drawerMode === "settings" && pageController.currentIndex === 14 && Config.autoGlass)
                                          ? Math.max(0.0, root.wallpapersLiveOpacity)
                                          : (Config ? Config.opacity : 0.85)
            Behavior on currentOpacity { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
            property color surfCol: Config ? Config.m3Surface : "#111318"
            property color notifBgCol: Mako ? Mako.bgColor : surfCol
            property real notifAlpha: Mako ? Mako.bgOpacity : 0.85
            property color outCol: (root.notifActive && Mako && Mako.popupCritical) ? Mako.criticalBorderColor : (Config ? Config.m3Outline : "#444854")

            property vector2d u_resolution: Qt.vector2d(width, height)
            property vector4d u_bar_rect: Qt.vector4d(root.barLeft, root.barRectY, root.barW, root.barH)
            property vector4d u_drawer_rect: Qt.vector4d(root.drawerX, root.drawerY, root.effDrawerW, root.animDrawerH)
            property vector4d u_notif_rect: Qt.vector4d(root.notifX, root.notifY, root.notifW, root.animNotifH)
            property vector4d u_bg_color: Qt.vector4d(surfCol.r, surfCol.g, surfCol.b, currentOpacity)
            property vector4d u_notif_color: Qt.vector4d(notifBgCol.r, notifBgCol.g, notifBgCol.b, notifAlpha)
            property vector4d u_outline_color: Qt.vector4d(outCol.r, outCol.g, outCol.b, (root.drawerActive || root.notifActive) ? 0.36 : 0.16)
            property vector3d u_glow_color: Config ? Qt.vector3d(Config.borderGlowCustomColor.r, Config.borderGlowCustomColor.g, Config.borderGlowCustomColor.b) : Qt.vector3d(0.66, 0.78, 0.98)
            property vector3d u_cursor_color: Config ? Qt.vector3d(Config.cursorCustomColor.r, Config.cursorCustomColor.g, Config.cursorCustomColor.b) : Qt.vector3d(1, 1, 1)
            property real u_bar_alpha: Waybar ? Waybar.barOpacity : 0.88
            property real u_radius: (Theme && Theme.isRounded) ? 11.0 : 0.0
            property real u_fillet: (Theme && Theme.isRounded) ? 20.0 : 0.0
            property real u_refraction: (root.drawerActive && Theme) ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.55 : 0.0) : 0.0
            property real u_time: root.liquidTime * (Config ? Config.borderGlowSpeed : 1.0)
            property real u_glow_intensity: (root.drawerActive && Config && Config.borderGlowEnabled) ? Config.borderGlowIntensity : 0.0
            property real u_glow_spread: Config ? Config.borderGlowSpread : 0.45
            property real u_glow_mode: Config ? Config.borderGlowColorMode : 4
            property real u_glow_dir: Config ? Config.borderGlowDirection : 0
            property real u_cursor_strength: Config ? Config.cursorGlowIntensity : 0.65
            property vector2d u_mouse: Qt.vector2d(root.mousePos.x, root.mousePos.y)
            property vector2d u_trail1: Qt.vector2d(root.trail1.x, root.trail1.y)
            property vector2d u_trail2: Qt.vector2d(root.trail2.x, root.trail2.y)
            fragmentShader: "qrc:/shaders/qml/shaders/merged_shell.frag.qsb"
        }

        // =====================================================================
        // ВСТРОЕННАЯ ПАНЕЛЬ ЗАДАЧ (НА ВСЮ ШИРИНУ ИЛИ ОСТРОВОК ПО ЦЕНТРУ)
        // =====================================================================
        Item {
            id: topBarContainer
            x: root.barLeft; y: root.barRectY; width: root.barW; height: root.barH; z: 10
            property int pillRadius: (Theme && Theme.isRounded) ? Math.round((height - 4) / 2) : 0
            property int pillHeight: height - 4
            property color pillColor: "transparent"

            MouseArea { anchors.fill: parent; z: 0; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }

            readonly property bool editMode: Waybar ? Waybar.barEditMode : false
            readonly property real launcherVis: editMode ? 1.0 : Math.max(0.0, Math.min(1.0, 1.0 - root.drawerProgress))
            readonly property bool showSeps: Waybar ? Waybar.barSeparators : false
            readonly property bool uniformMode: Waybar ? Waybar.uniformBarSpacing : true
            readonly property real extraExpandW: uniformMode ? Math.max(0, root.barW - root.baseBarW) : 0
            readonly property bool trayBlockVis: (Waybar ? (Waybar.hiddenBarModules, Waybar.isBarModuleVisible("tray")) : true) && ((Waybar && (Waybar.trayApps.length > 0 || Waybar.vpnActive)) || editMode)
            readonly property int macroGapsCount: 5 + (centerTitlePill.visible ? 1 : 0) + (trayBlockVis ? 1 : 0)
            readonly property real baseGroupGap: Waybar ? Waybar.groupSpacing : 6
            readonly property real macroStepGap: baseGroupGap + (macroGapsCount > 0 ? (extraExpandW / macroGapsCount) : 0)

            Row {
                id: leftBarRow; z: 5
                anchors.left: parent.left; anchors.leftMargin: 5; anchors.verticalCenter: parent.verticalCenter
                spacing: Waybar ? Waybar.spacing : 4

                Repeater {
                    model: Waybar ? Waybar.leftBarOrder : ["launcher", "workspaces", "weather", "media"]
                    delegate: Row {
                        id: leftModWrap
                        spacing: modKey === "launcher" ? ((Waybar ? Waybar.spacing : 4) * topBarContainer.launcherVis) : (Waybar ? Waybar.spacing : 4)
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property string modKey: modelData
                        readonly property bool modVis: {
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            var _m = Waybar ? Waybar.mediaActive : false
                            if (modKey === "sep") return true
                            if (Waybar && !Waybar.isBarModuleVisible(modKey)) return false
                            if (modKey === "media") return (Waybar ? Waybar.mediaActive : false) || topBarContainer.editMode
                            return true
                        }
                        visible: modVis

                        Item {
                            readonly property bool isLeftMacro: (modKey === "workspaces" || modKey === "weather" || modKey === "media") && index > 0
                            visible: isLeftMacro && topBarContainer.macroStepGap > 0.5
                            width: modKey === "workspaces"
                                   ? (topBarContainer.macroStepGap * topBarContainer.launcherVis)
                                   : topBarContainer.macroStepGap
                            height: 1
                        }

                        // Вертикальный разделитель между блоками
                        Rectangle {
                            visible: topBarContainer.showSeps && index > 0 && modKey !== "sep"
                            opacity: modKey === "workspaces" ? topBarContainer.launcherVis : 1.0
                            width: 1; height: topBarContainer.pillHeight - 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }

                        Item {
                            id: leftModBody
                            height: topBarContainer.pillHeight
                            anchors.verticalCenter: parent.verticalCenter
                            clip: modKey === "media"
                            opacity: modKey === "launcher" ? (topBarContainer.launcherVis * topBarContainer.launcherVis) : 1.0
                            width: {
                                if (modKey === "sep") return topBarContainer.editMode ? 12 : 5
                                if (modKey === "launcher") return (topBarContainer.pillHeight + 8) * topBarContainer.launcherVis
                                if (modKey === "workspaces") return wsRow.implicitWidth + 2
                                if (modKey === "weather") return wLbl.implicitWidth + 10
                                if (modKey === "media") return mediaInnerRow.implicitWidth + 10
                                return 0
                            }

                            // Контент: sep
                            Rectangle {
                                visible: modKey === "sep"
                                anchors.centerIn: parent
                                width: 1; height: topBarContainer.pillHeight - 4
                                color: Qt.rgba(1, 1, 1, 0.32)
                            }

                            // Контент: launcher (плавное скольжение без субпиксельного дрожания centerIn)
                            Item {
                                visible: modKey === "launcher"
                                anchors.fill: parent
                                Image {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 1
                                    scale: 0.72 + 0.28 * topBarContainer.launcherVis
                                    width: 15; height: 15
                                    sourceSize: Qt.size(30, 30)
                                    smooth: true
                                    source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                                }
                                MouseArea { enabled: !topBarContainer.editMode && topBarContainer.launcherVis > 0.5; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 16) }
                            }

                            // Контент: workspaces
                            Item {
                                visible: modKey === "workspaces"
                                anchors.fill: parent
                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.stepWorkspace(e.angleDelta.y > 0 ? -1 : 1) } }
                                Row {
                                    id: wsRow; anchors.centerIn: parent; spacing: 0
                                    Repeater {
                                        model: (modKey === "workspaces" && Waybar) ? Waybar.workspaces : []
                                        delegate: Rectangle {
                                            property bool act: modelData.active === true
                                            property bool occ: (modelData.windows || 0) > 0
                                            width: 20; height: topBarContainer.pillHeight - 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: (Theme && Theme.isRounded) ? height / 2 : 0
                                            color: act ? (Config ? Config.m3Primary : "#ffffff") : (occ ? Qt.rgba(1,1,1,0.10) : "transparent")
                                            Text { anchors.centerIn: parent; text: modelData.id; font.pixelSize: 10; font.bold: parent.act; color: parent.act ? (Config ? Config.accentTextColor : "#000000") : (parent.occ ? "#ffffff" : "#767b8a") }
                                            MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.switchWorkspace(modelData.id) }
                                        }
                                    }
                                }
                            }

                            // Контент: weather
                            Item {
                                visible: modKey === "weather"
                                anchors.fill: parent
                                Text { id: wLbl; anchors.centerIn: parent; text: Waybar ? Waybar.weatherText : "☁️ +3°C"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 20) }
                            }

                            // Контент: media (без двойных стрелочек, клик по треку открывает вкладку Музыки 27)
                            Item {
                                visible: modKey === "media"
                                anchors.fill: parent
                                clip: true
                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.mediaSeek(e.angleDelta.y > 0 ? 5 : -5) } }
                                Row {
                                    id: mediaInnerRow
                                    height: topBarContainer.pillHeight
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Item {
                                        width: 12; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: "󰒮"; color: prevMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 11 }
                                        MouseArea { id: prevMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPrev() }
                                    }

                                    Item {
                                        width: 12; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: (Waybar && Waybar.mediaPlaying) ? "󰏤" : "󰐊"; color: playMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 11 }
                                        MouseArea { id: playMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPlayPause() }
                                    }

                                    Item {
                                        width: 12; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: "󰒭"; color: nextMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 11 }
                                        MouseArea { id: nextMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaNext() }
                                    }

                                    Item {
                                        width: Math.min(155, mediaTrackLbl.implicitWidth)
                                        height: topBarContainer.pillHeight
                                        Text {
                                            id: mediaTrackLbl
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            text: Waybar ? (Waybar.mediaTitle.length > 0 ? Waybar.mediaTitle : "Плеер") : "Плеер"
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        MouseArea {
                                            enabled: !topBarContainer.editMode
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openDrawerWithMode("settings", 27)
                                        }
                                    }
                                }
                            }

                            // Оверлей режима редактирования: перетаскивание мышкой (ЛКМ) и скрытие (ПКМ или клик по ✕)
                            Rectangle {
                                visible: topBarContainer.editMode
                                anchors.fill: parent
                                radius: 4
                                color: leftDragMa.pressed ? Qt.rgba(0.4, 0.7, 1.0, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Config ? Config.m3Primary : "#a8c7fa"
                                border.width: 1

                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -2
                                    color: "#ff5555"
                                    Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: leftDragMa
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.SizeHorCursor
                                    property real pressX: 0
                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.RightButton || (mouse.x > width - 11 && mouse.y < 11)) {
                                            if (Waybar) Waybar.removeBarItemAt("left", index)
                                            mouse.accepted = true
                                            return
                                        }
                                        pressX = mouse.x
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (!(pressedButtons & Qt.LeftButton) || !Waybar) return
                                        var dx = mouse.x - pressX
                                        if (dx > 22 && index + 1 < Waybar.leftBarOrder.length) {
                                            Waybar.moveBarModule("left", index, index + 1)
                                        } else if (dx < -22 && index > 0) {
                                            Waybar.moveBarModule("left", index, index - 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: centerTitlePill; z: 5
                readonly property real availGap: Math.max(0, parent.width - leftBarRow.width - rightBarRow.width - 14)
                readonly property real minLeftX: leftBarRow.x + leftBarRow.width + 6
                readonly property real maxRightX: Math.max(minLeftX, parent.width - rightBarRow.width - 6 - width)
                readonly property real trueCenterX: Math.round((parent.width - width) * 0.5)
                visible: width > 0.5 && availGap > 24
                opacity: (root.isFixedTitle || root.hasWinTitle) ? 1.0 : 0.0
                clip: true
                width: (root.isFixedTitle || root.hasWinTitle) ? Math.min(availGap, root.winPillTargetW) : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                x: Math.max(minLeftX, Math.min(maxRightX, trueCenterX))
                anchors.verticalCenter: parent.verticalCenter
                height: topBarContainer.pillHeight
                radius: topBarContainer.pillRadius
                color: root.hasWinTitle ? topBarContainer.pillColor : "transparent"
                Text { id: winLbl; anchors.centerIn: parent; width: Math.min(Math.max(0, parent.width - 12), implicitWidth); text: Waybar ? Waybar.activeWindowTitle : ""; color: "#ececec"; font.pixelSize: 10; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }
            }

            Row {
                id: rightBarRow; z: 5
                anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // Индикатор записи экрана
                Rectangle {
                    property bool isRec: Waybar ? Waybar.recording : false
                    visible: width > 0.5
                    opacity: isRec ? 1.0 : 0.0
                    clip: true
                    height: topBarContainer.pillHeight
                    width: isRec ? (recRow.implicitWidth + 12) : 0
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    anchors.verticalCenter: parent.verticalCenter
                    radius: topBarContainer.pillRadius
                    color: topBarContainer.pillColor

                    Row {
                        id: recRow
                        height: topBarContainer.pillHeight
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle { width: 8; height: 8; radius: 4; color: "#ff4d4d"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Waybar ? Waybar.recordingTimeText : "00:00"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.runCommand("~/.config/hypr/scripts/record.sh") }
                }



                Repeater {
                    model: Waybar ? Waybar.rightBarOrder : ["sysinfo", "tray", "bluetooth", "network", "clipboard", "volume", "language", "clock", "power"]
                    delegate: Row {
                        id: rightModWrap
                        spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property string modKey: modelData
                        readonly property bool modVis: {
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            var _t = Waybar ? Waybar.trayApps : []
                            if (modKey === "sep") return true
                            if (Waybar && !Waybar.isBarModuleVisible(modKey)) return false
                            if (modKey === "tray") return (Waybar && (Waybar.trayApps.length > 0 || Waybar.vpnActive)) || topBarContainer.editMode
                            return true
                        }
                        visible: modVis

                        readonly property bool isMacroBoundary: (modKey === "tray" || modKey === "bluetooth" || modKey === "power") && index > 0
                        readonly property bool isTightStatusIcon: (modKey === "network" || modKey === "clipboard" || modKey === "volume" || modKey === "language") && index > 0

                        Item {
                            visible: index > 0
                            width: parent.isMacroBoundary
                                   ? topBarContainer.macroStepGap
                                   : (parent.isTightStatusIcon ? 2 : (Waybar ? Waybar.spacing : 4))
                            height: 1
                        }

                        Rectangle {
                            visible: topBarContainer.showSeps && parent.isMacroBoundary
                            width: 1; height: topBarContainer.pillHeight - 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }

                        Item {
                            id: rightModBody
                            height: topBarContainer.pillHeight
                            anchors.verticalCenter: parent.verticalCenter
                            width: {
                                if (modKey === "sep") return topBarContainer.editMode ? 12 : 5
                                if (modKey === "sysinfo") return sysRow.implicitWidth + 6
                                if (modKey === "tray") return Math.max(16, trayRow.implicitWidth + 6)
                                if (modKey === "bluetooth" || modKey === "network" || modKey === "clipboard") return 11
                                if (modKey === "volume") return volInnerRow.implicitWidth + 1
                                if (modKey === "language") return 15
                                if (modKey === "clock") return barClockText.implicitWidth + 4
                                if (modKey === "power") return 13
                                return 0
                            }

                            Rectangle {
                                visible: modKey === "sep"
                                anchors.centerIn: parent
                                width: 1; height: topBarContainer.pillHeight - 4
                                color: Qt.rgba(1, 1, 1, 0.32)
                            }

                            Item {
                                visible: modKey === "sysinfo"
                                anchors.fill: parent
                                Row {
                                    id: sysRow; height: topBarContainer.pillHeight; anchors.centerIn: parent; spacing: 2
                                    Item { width: 39; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 2; Text { text: ""; color: "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: (Waybar ? Waybar.cpuUsage : 0) + "%"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                    Item { width: 35; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 2; Text { text: ""; color: "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: (Waybar ? Waybar.cpuTemp : 40) + "°C"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                    Item { width: 39; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 2; Text { text: "󰍛"; color: "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: Waybar ? Waybar.memUsageText : "0.0G"; color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 21) }
                            }

                            Item {
                                visible: modKey === "tray"
                                anchors.fill: parent
                                Row {
                                    id: trayRow; anchors.centerIn: parent; spacing: 7
                                    Rectangle {
                                        visible: Waybar ? Waybar.vpnActive : false
                                        width: 32; height: topBarContainer.pillHeight - 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: (Theme && Theme.isRounded) ? 5 : 0
                                        color: "transparent"
                                        border.color: "#ffffff"
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "VPN"; color: "#ffffff"; font.pixelSize: 9; font.bold: true }
                                        MouseArea {
                                            enabled: !topBarContainer.editMode
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton && Waybar) Waybar.toggleVpn()
                                                else root.openDrawerWithMode("settings", 26)
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: (modKey === "tray" && Waybar) ? Waybar.trayApps : []
                                        delegate: Item {
                                            id: trayItemDel; width: 15; height: 15; anchors.verticalCenter: parent.verticalCenter
                                            Image { anchors.fill: parent; source: "image://appicon/" + modelData.icon; cache: false; sourceSize: Qt.size(18, 18); smooth: true }
                                            MouseArea {
                                                enabled: !topBarContainer.editMode
                                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                                onClicked: (mouse) => {
                                                    if (mouse.button === Qt.RightButton) {
                                                        var gp = trayItemDel.mapToItem(sceneRoot, trayItemDel.width * 0.5, 0)
                                                        root.openTrayContextMenu(modelData, gp.x)
                                                    } else {
                                                        root.drawerOpen = false
                                                        if (Waybar) Waybar.activateTrayApp(modelData.class, modelData.sniService || "")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                visible: modKey === "bluetooth"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; text: "󰂯"; color: "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 7) }
                            }

                            Item {
                                visible: modKey === "network"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; text: (Waybar && Waybar.netConnected) ? "󰈀" : "󰖪"; color: "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 6) }
                            }

                            Item {
                                visible: modKey === "clipboard"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; text: "󰅌"; color: (root.drawerOpen && root.drawerMode === "clipboard") ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 23) }
                            }

                            Item {
                                visible: modKey === "volume"
                                anchors.fill: parent
                                Row {
                                    id: volInnerRow; anchors.centerIn: parent; spacing: 2
                                    Text { text: (Waybar && Waybar.muted) ? "󰝟" : "󰕾"; color: (Waybar && Waybar.muted) ? "#ff6b6b" : "#ffffff"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: (Waybar && Waybar.muted) ? "Mute" : ((Waybar ? Waybar.volume : 50) + "%"); color: "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                }
                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.changeVolume(e.angleDelta.y > 0 ? 5 : -5) } }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 5) }
                            }

                            Item {
                                visible: modKey === "language"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; text: Waybar ? Waybar.kbLayout : "RU"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 25) }
                            }

                            Item {
                                visible: modKey === "clock"
                                anchors.fill: parent
                                Text {
                                    id: barClockText; anchors.centerIn: parent
                                    text: Qt.formatDateTime(new Date(), "hh:mm")
                                    color: (root.drawerOpen && root.drawerMode === "calendar") ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"
                                    font.pixelSize: 10; font.bold: true
                                    Timer { interval: 1000; running: modKey === "clock"; repeat: true; onTriggered: barClockText.text = Qt.formatDateTime(new Date(), "hh:mm") }
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("calendar") }
                            }

                            Item {
                                visible: modKey === "power"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; text: "⏻"; color: "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("power") }
                            }

                            // Оверлей режима редактирования для правого блока
                            Rectangle {
                                visible: topBarContainer.editMode
                                anchors.fill: parent
                                radius: 4
                                color: rightDragMa.pressed ? Qt.rgba(0.4, 0.7, 1.0, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Config ? Config.m3Primary : "#a8c7fa"
                                border.width: 1

                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -2
                                    color: "#ff5555"
                                    Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: rightDragMa
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.SizeHorCursor
                                    property real pressX: 0
                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.RightButton || (mouse.x > width - 11 && mouse.y < 11)) {
                                            if (Waybar) Waybar.removeBarItemAt("right", index)
                                            mouse.accepted = true
                                            return
                                        }
                                        pressX = mouse.x
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (!(pressedButtons & Qt.LeftButton) || !Waybar) return
                                        var dx = mouse.x - pressX
                                        if (dx > 18 && index + 1 < Waybar.rightBarOrder.length) {
                                            Waybar.moveBarModule("right", index, index + 1)
                                        } else if (dx < -18 && index > 0) {
                                            Waybar.moveBarModule("right", index, index - 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ПРАВЫЙ СТЕК УВЕДОМЛЕНИЙ (РАЗДЕЛИТЕЛЬНЫЕ ЛИНИИ + СЧЕТЧИК "+N СКРЫТЫХ")
        Item {
            id: notifClipBox
            x: root.notifX; y: root.notifY; width: root.notifW; height: root.animNotifH
            clip: true; visible: root.notifActive; z: 8

            Column {
                id: notifStackCol
                width: root.notifW
                y: -(1.0 - root.notifProgress) * 18
                opacity: Math.min(1.0, root.notifProgress * 1.35)
                spacing: 0; topPadding: 0; bottomPadding: 2

                Repeater {
                    model: Mako ? Mako.activePopups : []
                    delegate: Item {
                        width: root.notifW
                        height: Math.max(42, notifTextCol.implicitHeight + (Mako ? Mako.padding : 10))

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.topMargin: 5; anchors.bottomMargin: 5; spacing: 8
                            Image { visible: Mako && Mako.icons && modelData.icon && modelData.icon.length > 0; source: visible ? ("image://appicon/" + modelData.icon) : ""; Layout.preferredWidth: 22; Layout.preferredHeight: 22; sourceSize: Qt.size(22, 22); Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout {
                                id: notifTextCol; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: modelData.summary; color: modelData.critical ? (Mako ? Mako.criticalBorderColor : "#ff6b6b") : (Mako ? Mako.textColor : "#ffffff"); font.pixelSize: Mako ? Mako.fontSize : 11; font.bold: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                                    Text { text: "✕"; color: "#888888"; font.pixelSize: 9; Layout.alignment: Qt.AlignTop }
                                }
                                Text { text: modelData.body; color: Mako ? Qt.lighter(Mako.textColor, 0.85) : "#cccccc"; font.pixelSize: Mako ? Math.max(8, Mako.fontSize - 1) : 10; wrapMode: Text.Wrap; Layout.fillWidth: true }
                            }
                        }

                        // Разделительная линия между уведомлениями
                        Rectangle {
                            visible: index < root.notifCount - 1 || (Mako && Mako.hiddenPopupCount > 0)
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.14)
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Mako) Mako.dismissPopup(modelData.id) }
                    }
                }

                // Плашка "+N скрытых", если уведомлений больше лимита maxVisible
                Item {
                    visible: Mako && Mako.hiddenPopupCount > 0
                    width: root.notifW
                    height: visible ? 24 : 0

                    Text {
                        anchors.centerIn: parent
                        text: "+" + (Mako ? Mako.hiddenPopupCount : 0) + " скрытых"
                        color: "#aaaaaa"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (Mako) Mako.dismissAll()
                    }
                }
            }
        }

        // =====================================================================
        // ВЫЕЗЖАЮЩИЙ КОНТЕЙНЕР (СИММЕТРИЧНЫЙ ПО ЦЕНТРУ!)
        // =====================================================================
        Item {
            id: drawerClipBox
            x: root.drawerX
            y: root.drawerY
            width: root.effDrawerW
            height: root.animDrawerH
            clip: true
            visible: root.drawerActive
            z: 5

            Item {
                id: drawerInner
                width: root.effDrawerW
                height: root.targetDrawerH
                y: -(1.0 - root.drawerProgress) * (root.targetDrawerH * 0.32)
                opacity: Math.min(1.0, root.drawerProgress * 1.35)

                MouseArea {
                    anchors.fill: parent; z: 1000
                    acceptedButtons: Qt.LeftButton | Qt.RightButton; hoverEnabled: false
                    onPressed: (mouse) => { root.triggerClickRipple(mouse.x, mouse.y); mouse.accepted = false }
                }

                // 0. ПКМ-МЕНЮ ТРЕЯ
                Item {
                    anchors.fill: parent
                    visible: root.drawerMode === "traymenu"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 5
                        Text {
                            text: root.trayMenuName
                            color: "#ffffff"; font.pixelSize: 12; font.bold: true
                            Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 2
                        }
                        Repeater {
                            model: [
                                { label: "󰖲  Открыть / Развернуть", act: 0 },
                                { label: "󰁁  На текущий стол", act: 1 },
                                { label: "󰘕  Свернуть в трей", act: 2 },
                                { label: "󰍜  Меню приложения", act: 3 },
                                { label: "✕  Выйти из программы", act: 4 }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: tmMouse.containsMouse ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                                border.color: tmMouse.containsMouse ? "transparent" : Qt.rgba(1,1,1,0.14)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11
                                    color: tmMouse.containsMouse ? (Config ? Config.accentTextColor : "#000000") : (modelData.act === 4 ? "#ff6b6b" : "#ffffff")
                                }
                                MouseArea {
                                    id: tmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.drawerOpen = false
                                        if (Waybar) Waybar.trayContextAction(root.trayMenuClass, root.trayMenuSni, modelData.act)
                                    }
                                }
                            }
                        }
                    }
                }

                // 1. POWER MENU
                Item {
                    anchors.fill: parent
                    visible: root.drawerMode === "power"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 6
                        Text { text: "Power Menu"; color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 2 }
                        Repeater {
                            model: [
                                { label: "󰌾   Lock", idx: 0 },
                                { label: "󰒲   Sleep", idx: 1 },
                                { label: "󰤄   Hibernate", idx: 2 },
                                { label: "󰍃   Logout", idx: 3 },
                                { label: "󰜉   Reboot", idx: 4 },
                                { label: "⏻   Shutdown", idx: 5 }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                property bool isSel: root.powerSelectedIndex === modelData.idx || pmMouse.containsMouse
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: isSel ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                                border.color: isSel ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.18)
                                border.width: 1
                                Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 12; font.bold: parent.isSel; color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff" }
                                MouseArea { id: pmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.powerSelectedIndex = modelData.idx; onClicked: root.triggerPowerAction(modelData.idx) }
                            }
                        }
                    }
                }

                // 2. БУФЕР ОБМЕНА (БЕЗ ПРОЛАГОВ: АСИНХРОННЫЕ ПРЕВЬЮ И КЭШ)
                Item {
                    anchors.fill: parent
                    visible: root.drawerMode === "clipboard"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰅌  История буфера обмена"; color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                            StyledButton { text: "Очистить"; implicitHeight: 22; onClicked: if (Waybar) Waybar.clearClipboard() }
                        }
                        TextField {
                            Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                            color: "#ffffff"; font.pixelSize: 11; placeholderText: "Поиск в буфере..."; placeholderTextColor: "#777777"
                            text: root.clipSearchQuery
                            onTextChanged: root.clipSearchQuery = text.toLowerCase()
                            background: GlassPanel { radius: (Theme && Theme.isRounded) ? 10 : 0 }
                        }
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                            cacheBuffer: 120
                            model: (root.drawerActive && root.drawerMode === "clipboard" && Waybar) ? Waybar.clipboardItems : []
                            delegate: Rectangle {
                                property bool matches: root.clipSearchQuery.length === 0 || modelData.label.toLowerCase().indexOf(root.clipSearchQuery) !== -1
                                width: ListView.view.width
                                height: matches ? (modelData.isImage ? 54 : 32) : 0
                                visible: matches
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: clipItemMouse.containsMouse ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                                border.color: clipItemMouse.containsMouse ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                                    Text {
                                        text: modelData.label
                                        color: clipItemMouse.containsMouse ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Image {
                                        visible: modelData.isImage && modelData.thumb.length > 0
                                        source: visible ? ("file://" + modelData.thumb) : ""
                                        asynchronous: true
                                        Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                                MouseArea {
                                    id: clipItemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (Waybar) Waybar.selectClipboardItem(modelData.index)
                                        root.drawerOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. КАЛЕНДАРЬ
                Item {
                    anchors.fill: parent
                    visible: root.drawerMode === "calendar"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            StyledButton {
                                text: "‹"; isIconOnly: true; implicitHeight: 24; implicitWidth: 24
                                onClicked: {
                                    if (root.calMonth === 0) { root.calMonth = 11; root.calYear-- }
                                    else root.calMonth--
                                }
                            }
                            Text {
                                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                text: ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"][root.calMonth] + " " + root.calYear
                                color: "#ffffff"; font.pixelSize: 13; font.bold: true
                            }
                            StyledButton {
                                text: "›"; isIconOnly: true; implicitHeight: 24; implicitWidth: 24
                                onClicked: {
                                    if (root.calMonth === 11) { root.calMonth = 0; root.calYear++ }
                                    else root.calMonth++
                                }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true; columns: 7; columnSpacing: 4; rowSpacing: 4
                            Repeater {
                                model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                                delegate: Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: "#888888"; font.pixelSize: 10; font.bold: true }
                            }
                            Repeater {
                                model: (root.drawerActive && root.drawerMode === "calendar") ? 42 : 0
                                delegate: Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 26
                                    property var cellInfo: {
                                        var firstDay = (new Date(root.calYear, root.calMonth, 1).getDay() + 6) % 7
                                        var daysInM = new Date(root.calYear, root.calMonth + 1, 0).getDate()
                                        var dNum = index - firstDay + 1
                                        var valid = (dNum >= 1 && dNum <= daysInM)
                                        var now = new Date()
                                        var isToday = valid && (dNum === now.getDate() && root.calMonth === now.getMonth() && root.calYear === now.getFullYear())
                                        return { day: valid ? dNum : "", valid: valid, today: isToday }
                                    }
                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                    color: cellInfo.today ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                                    border.color: cellInfo.today ? "transparent" : (cellInfo.valid ? Qt.rgba(1,1,1,0.08) : "transparent")
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent; text: parent.cellInfo.day
                                        color: parent.cellInfo.today ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        font.pixelSize: 11; font.bold: parent.cellInfo.today
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. ОСНОВНЫЕ ВКЛАДКИ НАСТРОЕК
                Item {
                    id: scaledRoot
                    visible: root.drawerMode === "settings"
                    width: parent.width / (Config ? Config.uiScale : 1.0)
                    height: parent.height / (Config ? Config.uiScale : 1.0)
                    scale: Config ? Config.uiScale : 1.0
                    transformOrigin: Item.TopLeft
                    clip: true
                    layer.enabled: root.anyModalActive && Config && Config.dialogBlur > 0.01
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property vector2d u_resolution: Qt.vector2d(scaledRoot.width, scaledRoot.height)
                        property real u_blur: Config ? Config.dialogBlur : 0.65
                        fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                    }
                    Item {
                    id: pageController
                    anchors.fill: parent
                    clip: true

                    property int currentIndex: 0
                    property int previousIndex: 0
                    property bool inTransition: false
                    property int sidebarW: 136

                    onCurrentIndexChanged: {
                        root.syncWallpapersModeState()
                    }

                    function basePageX(idx) { return idx === 0 ? 0 : sidebarW }
                    function basePageW(idx) { return idx === 0 ? pageController.width : (pageController.width - sidebarW) }

                    function stopAllTransitions() {
                        pageSlideAnim.stop()
                        pageFadeAnim.stop()
                        depthTransition.stop()
                        bounceTransition.stop()
                        vortexTransition.stop()
                        blackholeTransition.stop()
                        portalTransition.stop()
                        shatterTransition.stop()
                    }

                    function jumpToPageInstant(targetIdx) {
                        stopAllTransitions()
                        inTransition = false
                        for (var i = 0; i < pageRepeater.count; ++i) {
                            var p = pageRepeater.itemAt(i)
                            if (p) {
                                p.visible = (i === targetIdx)
                                p.opacity = (i === targetIdx) ? 1.0 : 0.0
                                p.x = basePageX(i)
                                p.y = 0
                                p.scale = 1.0
                                p.rotation = 0
                                p.vortexProgress = 0.0
                            }
                        }
                        previousIndex = targetIdx
                        currentIndex = targetIdx
                        var tp = pageRepeater.itemAt(targetIdx)
                        if (tp && tp.item && tp.item.focusSearchInput) Qt.callLater(tp.item.focusSearchInput)
                    }

                    function resetToWelcomeInstant() {
                        jumpToPageInstant(0)
                    }

                    function runTransition(mode, oldPage, newPage, oldIdx, newIdx, toForward) {
                        stopAllTransitions()
                        var dur = Math.max(40, Config.animDuration)
                        var oldBaseX = basePageX(oldIdx)
                        var newBaseX = basePageX(newIdx)
                        var w = basePageW(newIdx)

                        oldPage.x = oldBaseX; oldPage.y = 0; oldPage.scale = 1.0; oldPage.rotation = 0; oldPage.opacity = 1.0; oldPage.vortexProgress = 0.0; oldPage.vortexDir = 1.0; oldPage.vortexMode = 0.0
                        newPage.x = newBaseX; newPage.y = 0; newPage.scale = 1.0; newPage.rotation = 0; newPage.opacity = 0.0; newPage.vortexProgress = 0.0; newPage.vortexDir = -1.0; newPage.vortexMode = 0.0

                        if (mode === "none" || dur <= 15) {
                            oldPage.visible = false; oldPage.opacity = 0.0
                            newPage.visible = true; newPage.opacity = 1.0
                            inTransition = false
                            return
                        }

                        inTransition = true

                        if (mode === "slide") {
                            var offset = toForward ? w * 0.45 : -w * 0.45
                            newPage.x = newBaseX + offset; newPage.opacity = 0.0; newPage.visible = true
                            slideOutAnim.target = oldPage; slideOutAnim.from = oldBaseX; slideOutAnim.to = oldBaseX - offset * 0.6; slideOutAnim.duration = dur
                            slideOutOp.target = oldPage; slideOutOp.duration = dur * 0.85
                            slideInAnim.target = newPage; slideInAnim.from = newPage.x; slideInAnim.to = newBaseX; slideInAnim.duration = dur
                            slideInOp.target = newPage; slideInOp.duration = dur
                            pageSlideAnim.start()
                        } else if (mode === "depth") {
                            newPage.scale = toForward ? 1.12 : 0.88; newPage.visible = true
                            depthOutOp.target = oldPage; depthOutOp.duration = dur
                            depthOutSc.target = oldPage; depthOutSc.to = toForward ? 0.86 : 1.12; depthOutSc.duration = dur
                            depthInOp.target = newPage; depthInOp.duration = dur
                            depthInSc.target = newPage; depthInSc.from = newPage.scale; depthInSc.duration = dur
                            depthTransition.start()
                        } else if (mode === "bounce") {
                            newPage.y = toForward ? 70 : -70; newPage.scale = 0.94; newPage.visible = true
                            bounceOutOp.target = oldPage; bounceOutOp.duration = dur * 0.75
                            bounceOutY.target = oldPage; bounceOutY.to = toForward ? -40 : 40; bounceOutY.duration = dur
                            bounceInOp.target = newPage; bounceInOp.duration = dur
                            bounceInY.target = newPage; bounceInY.from = newPage.y; bounceInY.duration = dur * 1.15
                            bounceInSc.target = newPage; bounceInSc.duration = dur * 1.15
                            bounceTransition.start()
                        } else if (mode === "blackhole") {
                            var dir = toForward ? 1.0 : -1.0
                            oldPage.vortexMode = 0.0
                            oldPage.vortexDir = dir
                            oldPage.vortexProgress = 0.0
                            oldPage.scale = 1.0
                            oldPage.rotation = 0
                            oldPage.opacity = 1.0
                            oldPage.visible = true

                            newPage.vortexMode = 0.0
                            newPage.vortexDir = -dir
                            newPage.vortexProgress = 0.65
                            newPage.scale = 0.04
                            newPage.rotation = -140 * dir
                            newPage.opacity = 0.0
                            newPage.visible = true

                            bhOutVortex.target = oldPage; bhOutVortex.duration = 380
                            bhOutSc.target = oldPage; bhOutSc.duration = 380
                            bhOutRot.target = oldPage; bhOutRot.to = 200 * dir; bhOutRot.duration = 380
                            bhOutOp.target = oldPage; bhOutOp.duration = 380

                            bhInDelay.duration = 270
                            bhInVortex.target = newPage; bhInVortex.duration = 370
                            bhInSc.target = newPage; bhInSc.duration = 370
                            bhInRot.target = newPage; bhInRot.from = -140 * dir; bhInRot.duration = 370
                            bhInOp.target = newPage; bhInOp.duration = 240

                            blackholeTransition.start()
                        } else if (mode === "portal") {
                            var pdir = toForward ? 1.0 : -1.0
                            oldPage.vortexMode = 1.0
                            oldPage.vortexProgress = 0.0
                            oldPage.scale = 1.0
                            oldPage.rotation = 0
                            oldPage.opacity = 1.0
                            oldPage.visible = true

                            newPage.vortexMode = 1.0
                            newPage.vortexProgress = 0.75
                            newPage.scale = 0.16
                            newPage.rotation = 35 * pdir
                            newPage.opacity = 0.0
                            newPage.visible = true

                            portalOutWave.target = oldPage; portalOutWave.duration = 340
                            portalOutSc.target = oldPage; portalOutSc.duration = 340
                            portalOutRot.target = oldPage; portalOutRot.to = -35 * pdir; portalOutRot.duration = 340
                            portalOutOp.target = oldPage; portalOutOp.duration = 320

                            portalInDelay.duration = 200
                            portalInWave.target = newPage; portalInWave.duration = 380
                            portalInSc.target = newPage; portalInSc.duration = 380
                            portalInRot.target = newPage; portalInRot.from = 35 * pdir; portalInRot.duration = 380
                            portalInOp.target = newPage; portalInOp.duration = 240

                            portalTransition.start()
                        } else if (mode === "shatter") {
                            var sdir = toForward ? 1.0 : -1.0
                            oldPage.vortexMode = 2.0
                            oldPage.vortexDir = sdir
                            oldPage.vortexProgress = 0.0
                            oldPage.scale = 1.0
                            oldPage.opacity = 1.0
                            oldPage.visible = true

                            newPage.vortexMode = 2.0
                            newPage.vortexDir = -sdir
                            newPage.vortexProgress = 0.85
                            newPage.scale = 1.16
                            newPage.x = newBaseX + 90 * sdir
                            newPage.opacity = 0.0
                            newPage.visible = true

                            shatterOutProg.target = oldPage; shatterOutProg.duration = 300
                            shatterOutSc.target = oldPage; shatterOutSc.duration = 300
                            shatterOutX.target = oldPage; shatterOutX.from = oldBaseX; shatterOutX.to = oldBaseX - 90 * sdir; shatterOutX.duration = 300
                            shatterOutOp.target = oldPage; shatterOutOp.duration = 280

                            shatterInDelay.duration = 140
                            shatterInProg.target = newPage; shatterInProg.duration = 320
                            shatterInSc.target = newPage; shatterInSc.duration = 320
                            shatterInX.target = newPage; shatterInX.from = newPage.x; shatterInX.to = newBaseX; shatterInX.duration = 320
                            shatterInOp.target = newPage; shatterInOp.duration = 220

                            shatterTransition.start()
                        } else if (mode === "vortex") {
                            newPage.x = newBaseX + (toForward ? 110 : -110); newPage.y = toForward ? 28 : -28; newPage.scale = 0.90; newPage.visible = true
                            vortexOutOp.target = oldPage; vortexOutOp.duration = dur * 0.8
                            vortexOutX.target = oldPage; vortexOutX.from = oldBaseX; vortexOutX.to = oldBaseX + (toForward ? -80 : 80); vortexOutX.duration = dur
                            vortexOutSc.target = oldPage; vortexOutSc.duration = dur
                            vortexInOp.target = newPage; vortexInOp.duration = dur
                            vortexInX.target = newPage; vortexInX.from = newPage.x; vortexInX.to = newBaseX; vortexInX.duration = dur
                            vortexInY.target = newPage; vortexInY.from = newPage.y; vortexInY.duration = dur
                            vortexInSc.target = newPage; vortexInSc.duration = dur
                            vortexTransition.start()
                        } else {
                            newPage.visible = true
                            fadeOldAnim.target = oldPage; fadeOldAnim.from = 1.0; fadeOldAnim.to = 0.0; fadeOldAnim.duration = dur
                            fadeNewAnim.target = newPage; fadeNewAnim.from = 0.0; fadeNewAnim.to = 1.0; fadeNewAnim.duration = dur
                            pageFadeAnim.start()
                        }
                    }

                    function switchPage(targetIdx) {
                        if (targetIdx === currentIndex) return
                        inTransition = true
                        previousIndex = currentIndex
                        currentIndex = targetIdx
                        var oldPage = pageRepeater.itemAt(previousIndex)
                        var newPage = pageRepeater.itemAt(targetIdx)
                        if (!oldPage || !newPage) {
                            jumpToPageInstant(targetIdx)
                            return
                        }
                        var isWelcomeTransition = (previousIndex === 0 || targetIdx === 0)
                        var mode = isWelcomeTransition ? Config.welcomeAnimType : Config.animType
                        runTransition(mode, oldPage, newPage, previousIndex, targetIdx, targetIdx > previousIndex)
                    }

                    function cleanupTransition() {
                        var p = pageRepeater.itemAt(pageController.previousIndex)
                        if (p && pageController.previousIndex !== pageController.currentIndex) {
                            p.visible = false
                            p.x = basePageX(pageController.previousIndex)
                            p.y = 0
                            p.scale = 1.0
                            p.rotation = 0
                            p.opacity = 0.0
                            p.vortexProgress = 0.0
                        }
                        var cur = pageRepeater.itemAt(pageController.currentIndex)
                        if (cur) {
                            cur.visible = true
                            cur.x = basePageX(pageController.currentIndex)
                            cur.y = 0
                            cur.scale = 1.0
                            cur.rotation = 0
                            cur.opacity = 1.0
                            cur.vortexProgress = 0.0
                        }
                        slideOutAnim.target = null; slideOutOp.target = null; slideInAnim.target = null; slideInOp.target = null
                        fadeOldAnim.target = null; fadeNewAnim.target = null
                        depthOutOp.target = null; depthOutSc.target = null; depthInOp.target = null; depthInSc.target = null
                        bounceOutOp.target = null; bounceOutY.target = null; bounceInOp.target = null; bounceInY.target = null; bounceInSc.target = null
                        vortexOutOp.target = null; vortexOutX.target = null; vortexOutSc.target = null; vortexInOp.target = null; vortexInX.target = null; vortexInY.target = null; vortexInSc.target = null
                        bhOutVortex.target = null; bhOutSc.target = null; bhOutRot.target = null; bhOutOp.target = null; bhInVortex.target = null; bhInSc.target = null; bhInRot.target = null; bhInOp.target = null
                        portalOutWave.target = null; portalOutSc.target = null; portalOutRot.target = null; portalOutOp.target = null; portalInWave.target = null; portalInSc.target = null; portalInRot.target = null; portalInOp.target = null
                        shatterOutProg.target = null; shatterOutSc.target = null; shatterOutX.target = null; shatterOutOp.target = null; shatterInProg.target = null; shatterInSc.target = null; shatterInX.target = null; shatterInOp.target = null
                        inTransition = false
                        if (cur && cur.item && cur.item.focusSearchInput) Qt.callLater(cur.item.focusSearchInput)
                        if (Hypr) Hypr.trimMemory()
                    }

                    ParallelAnimation {
                        id: pageSlideAnim
                        NumberAnimation { id: slideOutAnim; property: "x"; easing.type: Easing.OutCubic }
                        NumberAnimation { id: slideOutOp; property: "opacity"; from: 1.0; to: 0.0 }
                        NumberAnimation { id: slideInAnim; property: "x"; easing.type: Easing.OutCubic }
                        NumberAnimation { id: slideInOp; property: "opacity"; from: 0.0; to: 1.0 }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: pageFadeAnim
                        NumberAnimation { id: fadeOldAnim; property: "opacity" }
                        NumberAnimation { id: fadeNewAnim; property: "opacity" }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: depthTransition
                        NumberAnimation { id: depthOutOp; property: "opacity"; from: 1.0; to: 0.0 }
                        NumberAnimation { id: depthOutSc; property: "scale"; from: 1.0; easing.type: Easing.OutCubic }
                        NumberAnimation { id: depthInOp; property: "opacity"; from: 0.0; to: 1.0 }
                        NumberAnimation { id: depthInSc; property: "scale"; to: 1.0; easing.type: Easing.OutCubic }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: bounceTransition
                        NumberAnimation { id: bounceOutOp; property: "opacity"; from: 1.0; to: 0.0 }
                        NumberAnimation { id: bounceOutY; property: "y"; from: 0; easing.type: Easing.OutQuad }
                        NumberAnimation { id: bounceInOp; property: "opacity"; from: 0.0; to: 1.0 }
                        NumberAnimation { id: bounceInY; property: "y"; to: 0; easing.type: Easing.OutBack }
                        NumberAnimation { id: bounceInSc; property: "scale"; from: 0.94; to: 1.0; easing.type: Easing.OutBack }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: vortexTransition
                        NumberAnimation { id: vortexOutOp; property: "opacity"; from: 1.0; to: 0.0 }
                        NumberAnimation { id: vortexOutX; property: "x"; easing.type: Easing.OutCubic }
                        NumberAnimation { id: vortexOutSc; property: "scale"; from: 1.0; to: 0.90; easing.type: Easing.OutCubic }
                        NumberAnimation { id: vortexInOp; property: "opacity"; from: 0.0; to: 1.0 }
                        NumberAnimation { id: vortexInX; property: "x"; easing.type: Easing.OutCubic }
                        NumberAnimation { id: vortexInY; property: "y"; to: 0; easing.type: Easing.OutCubic }
                        NumberAnimation { id: vortexInSc; property: "scale"; from: 0.90; to: 1.0; easing.type: Easing.OutCubic }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: blackholeTransition
                        NumberAnimation { id: bhOutVortex; property: "vortexProgress"; from: 0.0; to: 1.0; easing.type: Easing.InCubic }
                        NumberAnimation { id: bhOutSc; property: "scale"; from: 1.0; to: 0.02; easing.type: Easing.InBack; easing.overshoot: 0.6 }
                        NumberAnimation { id: bhOutRot; property: "rotation"; from: 0; easing.type: Easing.InCubic }
                        NumberAnimation { id: bhOutOp; property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.InExpo }
                        SequentialAnimation {
                            PauseAnimation { id: bhInDelay }
                            ParallelAnimation {
                                NumberAnimation { id: bhInVortex; property: "vortexProgress"; from: 0.65; to: 0.0; easing.type: Easing.OutCubic }
                                NumberAnimation { id: bhInSc; property: "scale"; from: 0.04; to: 1.0; easing.type: Easing.OutBack; easing.overshoot: 0.85 }
                                NumberAnimation { id: bhInRot; property: "rotation"; to: 0; easing.type: Easing.OutCubic }
                                NumberAnimation { id: bhInOp; property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.OutCubic }
                            }
                        }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: portalTransition
                        NumberAnimation { id: portalOutWave; property: "vortexProgress"; from: 0.0; to: 1.0; easing.type: Easing.InCubic }
                        NumberAnimation { id: portalOutSc; property: "scale"; from: 1.0; to: 1.85; easing.type: Easing.InCubic }
                        NumberAnimation { id: portalOutRot; property: "rotation"; from: 0; easing.type: Easing.InCubic }
                        NumberAnimation { id: portalOutOp; property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.InQuad }
                        SequentialAnimation {
                            PauseAnimation { id: portalInDelay }
                            ParallelAnimation {
                                NumberAnimation { id: portalInWave; property: "vortexProgress"; from: 0.75; to: 0.0; easing.type: Easing.OutCubic }
                                NumberAnimation { id: portalInSc; property: "scale"; from: 0.16; to: 1.0; easing.type: Easing.OutBack; easing.overshoot: 0.75 }
                                NumberAnimation { id: portalInRot; property: "rotation"; to: 0; easing.type: Easing.OutCubic }
                                NumberAnimation { id: portalInOp; property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.OutCubic }
                            }
                        }
                        onFinished: pageController.cleanupTransition()
                    }
                    ParallelAnimation {
                        id: shatterTransition
                        NumberAnimation { id: shatterOutProg; property: "vortexProgress"; from: 0.0; to: 1.0; easing.type: Easing.InCubic }
                        NumberAnimation { id: shatterOutSc; property: "scale"; from: 1.0; to: 0.82; easing.type: Easing.InCubic }
                        NumberAnimation { id: shatterOutX; property: "x"; easing.type: Easing.InBack }
                        NumberAnimation { id: shatterOutOp; property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.InQuad }
                        SequentialAnimation {
                            PauseAnimation { id: shatterInDelay }
                            ParallelAnimation {
                                NumberAnimation { id: shatterInProg; property: "vortexProgress"; from: 0.85; to: 0.0; easing.type: Easing.OutCubic }
                                NumberAnimation { id: shatterInSc; property: "scale"; from: 1.16; to: 1.0; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                                NumberAnimation { id: shatterInX; property: "x"; easing.type: Easing.OutBack; easing.overshoot: 0.7 }
                                NumberAnimation { id: shatterInOp; property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.OutCubic }
                            }
                        }
                        onFinished: pageController.cleanupTransition()
                    }

                    Repeater {
                        id: pageRepeater
                        model: [
                            "views/WelcomeView.qml",
                            "views/LookSettingsView.qml",
                            "views/AnimsSettingsView.qml",
                            "views/CursorSettingsView.qml",
                            "views/MonitorsSettingsView.qml",
                            "views/DevicesSettingsView.qml",
                            "views/NetworkSettingsView.qml",
                            "views/BluetoothSettingsView.qml",
                            "views/WaybarSettingsView.qml",
                            "views/AutostartSettingsView.qml",
                            "views/BindsSettingsView.qml",
                            "views/RulesSettingsView.qml",
                            "views/AppsSettingsView.qml",
                            "views/ShadersView.qml",
                            "views/WallpapersView.qml",
                            "views/WidgetsSettingsView.qml",
                            "views/SearchView.qml",
                            "views/AppSettingsView.qml",
                            "views/MakoSettingsView.qml",
                            "views/AtmosphereView.qml",
                            "views/WeatherView.qml",
                            "views/SysMonView.qml",
                            "views/CalendarView.qml",
                            "views/ClipboardView.qml",
                            "views/PowerView.qml",
                            "views/LanguageView.qml",
                            "views/VpnView.qml",
                            "views/MusicView.qml"
                        ]

                        Loader {
                            id: pageLoader
                            z: (pageController.inTransition && index === pageController.previousIndex) ? 2 : 1
                            x: index === 0 ? 0 : pageController.sidebarW
                            width: index === 0 ? pageController.width : (pageController.width - pageController.sidebarW)
                            height: pageController.height
                            active: root.drawerActive && root.drawerMode === "settings" && (
                                    index === pageController.currentIndex ||
                                    (pageController.inTransition && index === pageController.previousIndex))
                            source: modelData
                            visible: index === 0
                            opacity: index === 0 ? 1.0 : 0.0
                            transformOrigin: Item.Center
                            property real vortexProgress: 0.0
                            property real vortexDir: 1.0
                            property real vortexMode: 0.0
                            layer.enabled: pageController.inTransition && vortexProgress > 0.001
                            layer.smooth: true
                            layer.effect: ShaderEffect {
                                property vector2d u_resolution: Qt.vector2d(pageLoader.width, pageLoader.height)
                                property real u_progress: pageLoader.vortexProgress
                                property real u_direction: pageLoader.vortexDir
                                property real u_mode: pageLoader.vortexMode
                                fragmentShader: "qrc:/shaders/qml/shaders/vortex_suck.frag.qsb"
                            }

                            onLoaded: {
                                if ((index === 12 || index === 16) && item && item.focusSearchInput && index === pageController.currentIndex) Qt.callLater(item.focusSearchInput)
                                if (index === 0 && item) {
                                    item.navigateTo.connect((target) => pageController.switchPage(target))
                                }
                            }
                        }
                    }
                }

                Sidebar {
                    id: sidebar
                    width: 136
                    height: parent.height
                    property bool showBar: pageController.currentIndex > 0 && !(blackholeTransition.running && pageController.previousIndex === 0 && bhInOp.target && bhInOp.target.opacity < 0.05)
                    x: showBar ? 0 : -136
                    opacity: showBar ? 1.0 : 0.0
                    visible: opacity > 0.01
                    currentIndex: pageController.currentIndex
                    onCategorySelected: (idx) => pageController.switchPage(idx)
                    onReturnToWelcome: () => pageController.switchPage(0)

                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }

                ShaderEffectSource {
                    id: pageSceneSource
                    readonly property bool activeCapture: root.drawerActive && root.drawerMode === "settings" && Atmosphere && Atmosphere.inAppEnabled && (Atmosphere.rainEnabled || Atmosphere.snowEnabled)
                    sourceItem: activeCapture ? pageController : null
                    anchors.fill: pageController
                    visible: false
                    live: activeCapture
                }

                AtmosphereCanvas {
                    id: inAppWaterMap
                    roundedTheme: (Theme && Theme.isRounded) ? true : false
                    anchors.fill: parent
                    visible: root.drawerActive && Atmosphere && Atmosphere.inAppEnabled
                    enabled: false
                    globalMode: false
                    renderPass: 0
                    activeRunning: root.drawerActive && Atmosphere && Atmosphere.inAppEnabled
                    cursorPos: Qt.point((root.mousePos.x - root.drawerX) / (Config ? Config.uiScale : 1.0),
                                        (root.mousePos.y - root.drawerY) / (Config ? Config.uiScale : 1.0))
                }

                ShaderEffectSource {
                    id: inAppWaterMapSource
                    readonly property bool activeCapture: root.drawerActive && root.drawerMode === "settings" && Atmosphere && Atmosphere.inAppEnabled
                    sourceItem: activeCapture ? inAppWaterMap : null
                    anchors.fill: parent
                    visible: false
                    hideSource: true
                    smooth: true
                    live: activeCapture
                }

                AtmosphereCanvas {
                    id: inAppOverlayMap
                    anchors.fill: parent
                    visible: root.drawerActive && Atmosphere && Atmosphere.inAppEnabled
                    enabled: false
                    globalMode: false
                    renderPass: 1
                    masterCanvas: inAppWaterMap
                    activeRunning: root.drawerActive && Atmosphere && Atmosphere.inAppEnabled
                }

                ShaderEffectSource {
                    id: inAppOverlayMapSource
                    readonly property bool activeCapture: root.drawerActive && root.drawerMode === "settings" && Atmosphere && Atmosphere.inAppEnabled
                    sourceItem: activeCapture ? inAppOverlayMap : null
                    anchors.fill: parent
                    visible: false
                    hideSource: true
                    smooth: true
                    live: activeCapture
                }

                ShaderEffect {
                    id: inAppAtmosphereShader
                    anchors.fill: parent
                    z: 95
                    enabled: false
                    visible: root.drawerActive && Atmosphere && Atmosphere.inAppEnabled
                    property vector2d u_resolution: Qt.vector2d(width, height)
                    property real u_has_scene: 1.0
                    property real u_refraction_strength: 1.15 * (Atmosphere ? Atmosphere.dropRefraction : 1.0)
                    property real u_time: root.liquidTime * (Config ? Config.borderGlowSpeed : 1.0)
                    property vector2d u_mouse: Qt.vector2d((root.mousePos.x - root.drawerX) / (Config ? Config.uiScale : 1.0), (root.mousePos.y - root.drawerY) / (Config ? Config.uiScale : 1.0))
                    property real u_cursor_strength: Config ? Config.cursorGlowIntensity : 0.65
                    property vector3d u_cursor_color: Config ? Qt.vector3d(Config.cursorCustomColor.r, Config.cursorCustomColor.g, Config.cursorCustomColor.b) : Qt.vector3d(1, 1, 1)
                    property real u_border_strength: 0.0
                    property real u_border_spread: Config ? Config.borderGlowSpread : 0.45
                    property real u_border_color_mode: Config ? Config.borderGlowColorMode : 0
                    property vector3d u_border_color: Config ? Qt.vector3d(Config.borderGlowCustomColor.r, Config.borderGlowCustomColor.g, Config.borderGlowCustomColor.b) : Qt.vector3d(1, 1, 1)
                    property real idleBoost: (Atmosphere && Atmosphere.idleFogEnabled) ? (inAppWaterMap.idleFogBoost * Atmosphere.idleFogStrength) : 0.0
                    property real baseSpread: Atmosphere ? ((Atmosphere.snowEnabled && !Atmosphere.rainEnabled) ? Atmosphere.snowScreenFrostSpread : Atmosphere.fogSpread) : 0.45
                    property real baseInt: Atmosphere ? ((Atmosphere.snowEnabled && !Atmosphere.rainEnabled) ? Atmosphere.snowScreenFrostIntensity : Atmosphere.fogIntensity) : 0.65
                    property bool inAppMistOn: Atmosphere ? ((Atmosphere.snowEnabled && !Atmosphere.rainEnabled) ? Atmosphere.snowScreenFrostEnabled : Atmosphere.condensationEnabled) : false
                    property real effSpread: Math.min(1.0, baseSpread + idleBoost * (1.0 - baseSpread) * 0.78)
                    property real effInt: Math.min(0.995, baseInt + idleBoost * (0.995 - baseInt))
                    property real u_fog_strength: (inAppMistOn && !(Atmosphere.globalOverlayEnabled && Atmosphere.syncWithOverlay)) ? (Math.round(effSpread * 100) + effInt) : 0.0
                    property real u_lightning: inAppWaterMap.lightningFlash
                    property real u_lightning_x: inAppWaterMap.lightningPosX
                    property real u_drop_tint_strength: Atmosphere ? Atmosphere.dropTintStrength : 0.20
                    property real u_drop_highlight: Atmosphere ? Atmosphere.dropHighlightStrength : 1.0
                    property vector3d u_drop_tint_color: Atmosphere ? Atmosphere.effectiveDropTintVec : Qt.vector3d(0.015, 0.015, 0.018)
                    property real u_wipe_strength: Atmosphere ? Atmosphere.wipeTrailStrength : 0.55
                    property real u_frost_strength: (Atmosphere && Atmosphere.snowEnabled) ? (((Atmosphere.snowFrostStyle === 0 && Atmosphere.snowVelvetFlakesEnabled) ? 3 : Atmosphere.snowFrostStyle) * 10.0 + Atmosphere.snowFrostPatternStrength) : 0.0
                    property real u_idle_fog_boost: (Atmosphere && Atmosphere.condensationEnabled && Atmosphere.idleFogEnabled && !(Atmosphere.globalOverlayEnabled && Atmosphere.syncWithOverlay)) ? (inAppWaterMap.idleFogBoost * Atmosphere.idleFogStrength) : 0.0
                    property variant u_waterMap: inAppWaterMapSource
                    property variant u_overlayMap: inAppOverlayMapSource
                    property variant u_scene: pageSceneSource
                    fragmentShader: "qrc:/shaders/qml/shaders/atmosphere_fx.frag.qsb"
                }
            }

                            ShaderEffect {
                    id: cursorFollowItem
                    width: 240; height: 240
                    x: (root.mousePos.x - root.drawerX) - 120; y: (root.mousePos.y - root.drawerY) - 120
                    z: 97; enabled: false
                    visible: root.drawerActive && Config && Config.cursorGlowIntensity > 0.01 && root.mousePos.x > -100
                    property vector2d u_size: Qt.vector2d(240, 240)
                    property vector2d u_origin: Qt.vector2d(x, y)
                    property vector2d u_mouse: Qt.vector2d(root.mousePos.x - root.drawerX, root.mousePos.y - root.drawerY)
                    property vector2d u_trail1: Qt.vector2d(root.trail1.x - root.drawerX, root.trail1.y - root.drawerY)
                    property vector2d u_trail2: Qt.vector2d(root.trail2.x - root.drawerX, root.trail2.y - root.drawerY)
                    property vector2d u_trail3: Qt.vector2d(root.trail3.x - root.drawerX, root.trail3.y - root.drawerY)
                    property real u_cursor_strength: Config ? Config.cursorGlowIntensity : 0.65
                    property real u_liquid_enabled: (Theme && (Theme.controlsLiquidGlass || Theme.glassRefraction > 0.01)) ? 1.0 : 0.0
                    property real u_refraction: Theme ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.55 : 0.0) : 0.55
                    property vector3d u_custom_color: Config ? Qt.vector3d(Config.cursorCustomColor.r, Config.cursorCustomColor.g, Config.cursorCustomColor.b) : Qt.vector3d(1, 1, 1)
                    fragmentShader: "qrc:/shaders/qml/shaders/cursor_fx.frag.qsb"
                }

                // Модальный диалог сохранения при выходе из режима перетаскивания панели задач
                Rectangle {
                    visible: root.barSavePromptOpen
                    anchors.fill: parent
                    z: 990
                    color: Qt.rgba(0, 0, 0, 0.55)

                    MouseArea { anchors.fill: parent; onClicked: {} }

                    GlassPanel {
                        anchors.centerIn: parent
                        width: 340
                        implicitHeight: savePromptCol.implicitHeight + 28
                        radius: (Theme && Theme.isRounded) ? 14 : 0

                        ColumnLayout {
                            id: savePromptCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: "Сохранить изменения панели?"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Вы находитесь в режиме редактирования панели задач. Сохранить новое расположение блоков перед закрытием?"
                                color: "#cccccc"
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                StyledButton {
                                    text: "✓ Сохранить"
                                    isActive: true
                                    onClicked: {
                                        root.barSavePromptOpen = false
                                        if (Waybar) Waybar.confirmBarEdit()
                                        root.drawerOpen = false
                                    }
                                }

                                StyledButton {
                                    text: "✕ Не сохранять"
                                    onClicked: {
                                        root.barSavePromptOpen = false
                                        if (Waybar) Waybar.cancelBarEdit()
                                        root.drawerOpen = false
                                    }
                                }

                                StyledButton {
                                    text: "Отмена"
                                    onClicked: root.barSavePromptOpen = false
                                }
                            }
                        }
                    }
                }

                ShaderEffect {
                    id: clickFxItem
                    width: 280; height: 280
                    x: root.clickPos.x - 140; y: root.clickPos.y - 140
                    z: 98; enabled: false
                    visible: clickAnim.running
                    property real u_progress: 0.0
                    property real u_intensity: Config ? Config.clickFlashIntensity : 0.70
                    property real u_shape: Config ? Config.clickFlashShape : 0
                    property vector3d u_custom_color: Config ? Qt.vector3d(Config.cursorCustomColor.r, Config.cursorCustomColor.g, Config.cursorCustomColor.b) : Qt.vector3d(1, 1, 1)
                    NumberAnimation on u_progress { id: clickAnim; from: 0.001; to: 1.0; duration: 460; running: false; easing.type: Easing.OutCubic }
                    fragmentShader: "qrc:/shaders/qml/shaders/click_fx.frag.qsb"
                }
            }
        }
    }
}
