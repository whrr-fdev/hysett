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
    property bool isSettingsMaximized: false
    property real contentMaxBounce: 1.0
    SequentialAnimation {
        id: pageMaxSpringAnim
        NumberAnimation { target: root; property: "contentMaxBounce"; from: 0.965; to: 1.022; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "contentMaxBounce"; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
    }
    onIsSettingsMaximizedChanged: if (drawerOpen) pageMaxSpringAnim.restart()
    property int powerSelectedIndex: 0
    property string clipSearchQuery: ""
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    property int timeSubTab: 0
    property int musicSubTab: 0

    // Таймер и Секундомер (живут в фоне и отображаются в таблетках на панели задач)
    property int timerTotalMs: 5 * 60 * 1000
    property int timerRemainingMs: 5 * 60 * 1000
    property bool timerRunning: false
    property bool timerActive: false
    property double timerLastTickMs: 0

    property int stopwatchElapsedMs: 0
    property bool stopwatchRunning: false
    property bool stopwatchActive: false
    property double stopwatchLastTickMs: 0
    property int stopwatchLastLapMs: 0
    property var stopwatchLaps: []

    function formatClockMs(ms, showTenths, showHundredths) {
        var totalSec = Math.floor(Math.max(0, ms) / 1000)
        var hrs = Math.floor(totalSec / 3600)
        var mins = Math.floor((totalSec % 3600) / 60)
        var secs = totalSec % 60
        var base = (hrs > 0 ? (String(hrs).padStart(2, '0') + ":") : "") +
                   String(mins).padStart(2, '0') + ":" +
                   String(secs).padStart(2, '0')
        if (showHundredths) {
            var cs = Math.floor((Math.max(0, ms) % 1000) / 10)
            return base + "." + String(cs).padStart(2, '0')
        }
        if (showTenths) {
            var ds = Math.floor((Math.max(0, ms) % 1000) / 100)
            return base + "." + String(ds)
        }
        return base
    }

    readonly property string timerBarText: formatClockMs(timerRemainingMs + 999, false, false)
    readonly property string stopwatchBarText: formatClockMs(stopwatchElapsedMs, true, false)
    readonly property string stopwatchFullText: formatClockMs(stopwatchElapsedMs, false, true)

    function setTimerPreset(ms) {
        timerRunning = false
        timerActive = false
        timerTotalMs = Math.max(1000, ms)
        timerRemainingMs = timerTotalMs
    }

    function addTimerMs(deltaMs) {
        var nextRem = Math.max(1000, timerRemainingMs + deltaMs)
        timerRemainingMs = nextRem
        if (!timerActive || nextRem > timerTotalMs) timerTotalMs = nextRem
    }

    function toggleTimerPause() {
        if (timerRunning) {
            timerRunning = false
        } else {
            if (timerRemainingMs <= 0) timerRemainingMs = timerTotalMs
            timerLastTickMs = Date.now()
            timerActive = true
            timerRunning = true
        }
    }

    function resetTimer() {
        timerRunning = false
        timerActive = false
        timerRemainingMs = timerTotalMs
    }

    function toggleStopwatch() {
        if (stopwatchRunning) {
            stopwatchRunning = false
        } else {
            stopwatchLastTickMs = Date.now()
            stopwatchActive = true
            stopwatchRunning = true
        }
    }

    function lapStopwatch() {
        if (!stopwatchActive) return
        var cur = stopwatchElapsedMs
        var diff = cur - stopwatchLastLapMs
        stopwatchLastLapMs = cur
        var nextLaps = [{
            num: stopwatchLaps.length + 1,
            lapTime: formatClockMs(diff, false, true),
            totalTime: formatClockMs(cur, false, true)
        }]
        for (var i = 0; i < stopwatchLaps.length && i < 49; ++i) nextLaps.push(stopwatchLaps[i])
        stopwatchLaps = nextLaps
    }

    function clearStopwatchLaps() {
        stopwatchLastLapMs = stopwatchElapsedMs
        stopwatchLaps = []
    }

    function resetStopwatch() {
        stopwatchRunning = false
        stopwatchActive = false
        stopwatchElapsedMs = 0
        stopwatchLastLapMs = 0
        stopwatchLaps = []
    }

    Timer {
        interval: 45
        repeat: true
        running: root.timerRunning || root.stopwatchRunning
        onTriggered: {
            var now = Date.now()
            if (root.timerRunning) {
                var dt = Math.max(0, now - root.timerLastTickMs)
                root.timerLastTickMs = now
                if (root.timerRemainingMs > dt) {
                    root.timerRemainingMs -= dt
                } else {
                    root.timerRemainingMs = 0
                    root.timerRunning = false
                    root.timerActive = false
                    if (Mako) {
                        Mako.showInternalNotification("Таймер HySett", "󰔛 Время таймера вышло!", "Обратный отсчёт успешно завершён.", "preferences-system-time", true, 8000)
                    }
                    if (Waybar) {
                        Waybar.runCommand("paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || canberra-gtk-play -i complete 2>/dev/null || true")
                    }
                }
            }
            if (root.stopwatchRunning) {
                var ds = Math.max(0, now - root.stopwatchLastTickMs)
                root.stopwatchLastTickMs = now
                root.stopwatchElapsedMs += ds
            }
        }
    }

    property string trayMenuClass: ""
    property string trayMenuName: ""
    property string trayMenuSni: ""
    property real trayMenuTargetX: 1400
    property real popupTargetX: 1550
    property bool barDragActive: false
    property bool chewWaveActive: false
    property real barChewExtraH: barDragActive ? 14.0 : 0.0
    Behavior on barChewExtraH { enabled: !barChewAnim.running; NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 1.35 } }
    property real barChewWidthScale: 1.0
    property real barDropX: 960
    property real swallowIconScale: 0.0
    property real swallowIconY: 0.0
    property string droppedFilePath: ""
    property string droppedFileName: ""
    property int fileDropSelectedIndex: 0

    onBarDragActiveChanged: syncInputMask()

    SequentialAnimation {
        id: barChewAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "swallowIconScale"; from: 1.15; to: 0.0; duration: 210; easing.type: Easing.InBack }
            NumberAnimation { target: root; property: "swallowIconY"; from: 14.0; to: 4.0; duration: 210; easing.type: Easing.InCubic }
            SequentialAnimation {
                NumberAnimation { target: root; property: "barChewExtraH"; to: 18.0; duration: 70; easing.type: Easing.OutQuad }
                NumberAnimation { target: root; property: "barChewExtraH"; to: 0.0; duration: 150; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction {
            script: {
                root.chewWaveActive = false
                root.barDragActive = false
                root.fileDropSelectedIndex = 0
                root.openDrawerWithMode("filedrop", undefined, root.barDropX)
            }
        }
    }

    function executeDroppedFileAction(actIdx) {
        var fp = root.droppedFilePath
        if (!fp || fp.length === 0) {
            root.drawerOpen = false
            return
        }
        var safeSq = fp.replace(/'/g, "'\\''")
        if (actIdx === 0) {
            if (Config) {
                Config.shareFileToPhone(fp)
            }
            root.openDrawerWithMode("settings", 30)
        } else if (actIdx === 1) {
            if (Config) Config.quickCloudShare(fp, true)
            root.openDrawerWithMode("settings", 30)
        } else if (actIdx === 2) {
            root.drawerOpen = false
            if (Wallpapers) Wallpapers.applyWallpaper(fp)
        } else if (actIdx === 3) {
            root.drawerOpen = false
            if (Waybar) Waybar.runCommand("printf '%s' '" + safeSq + "' | wl-copy")
        } else if (actIdx === 4) {
            root.drawerOpen = false
            if (Waybar) Waybar.runCommand("xdg-open '" + safeSq + "'")
        }
    }

    readonly property bool isCompactPopup: drawerMode === "traymenu" || drawerMode === "filedrop" || drawerMode === "volume" || drawerMode === "bluetooth" || drawerMode === "clipboard" || drawerMode === "calendar" || drawerMode === "power" 

    property real barExpandProgress: 0.0
    property real drawerProgress: 0.0
    readonly property bool drawerActive: drawerProgress > 0.005 || barExpandProgress > 0.005

    property real drawerWidthScale: 1.0
    readonly property string openFxMode: Config ? Config.windowOpenAnimType : "spring"
    readonly property int openFxEasing: {
        if (openFxMode === "elastic") return Easing.OutElastic
        if (openFxMode === "bounce") return Easing.OutBounce
        if (openFxMode === "smooth") return Easing.OutQuint
        return Easing.OutBack
    }
    readonly property int openFxDuration: {
        if (openFxMode === "elastic") return 520
        if (openFxMode === "bounce") return 450
        if (openFxMode === "smooth") return 280
        return 360
    }

    SequentialAnimation {
        id: openSeqAnim
        NumberAnimation {
            target: root; property: "barExpandProgress"
            to: 1.0
            duration: (!root.isCompactPopup && root.baseBarW < root.targetDrawerW - 2) ? (Waybar ? Waybar.barAnimDuration : 75) : 0
            easing.type: Easing.OutCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "drawerProgress"
                to: 1.0
                duration: root.openFxDuration
                easing.type: root.openFxEasing
                easing.overshoot: 1.24
                easing.amplitude: 1.0
                easing.period: 0.36
            }
            SequentialAnimation {
                NumberAnimation {
                    target: root; property: "drawerWidthScale"
                    from: 1.0
                    to: (root.openFxMode === "smooth" || (Waybar && !Waybar.windowSideStretch)) ? 1.0 : 1.05
                    duration: Math.round(root.openFxDuration * 0.55)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: root; property: "drawerWidthScale"
                    to: 1.0
                    duration: Math.round(root.openFxDuration * 0.45)
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    SequentialAnimation {
        id: closeSeqAnim
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "drawerProgress"
                to: 0.0; duration: 220; easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root; property: "drawerWidthScale"
                to: 1.0; duration: 220; easing.type: Easing.InOutCubic
            }
        }
        NumberAnimation {
            target: root; property: "barExpandProgress"
            to: 0.0
            duration: (!root.isCompactPopup && root.baseBarW < root.targetDrawerW - 2) ? (Waybar ? Waybar.barAnimDuration : 75) : 0
            easing.type: Easing.OutQuint
        }
    }

    property string pendingDrawerMode: "settings"
    property int pendingTabIdx: 0
    property string pendingTrayClass: ""
    property string pendingTrayName: ""
    property string pendingTraySni: ""
    property real pendingTrayX: 1400
    property real pendingPopupX: 1550

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
                root.popupTargetX = root.pendingPopupX
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
                } else if (root.pendingDrawerMode === "volume") {
                    if (Waybar) Qt.callLater(() => Waybar.refreshAudioStreams())
                } else if (root.pendingDrawerMode === "bluetooth") {
                    if (Bluetooth) Qt.callLater(() => Bluetooth.refresh())
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
            duration: (!root.isCompactPopup && root.baseBarW < root.targetDrawerW && root.barExpandProgress < 0.99) ? (Waybar ? Waybar.barAnimDuration : 75) : 0
            easing.type: Easing.OutCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "drawerProgress"
                to: 1.0
                duration: Math.round(root.openFxDuration * 0.9)
                easing.type: root.openFxEasing
                easing.overshoot: 1.20
                easing.amplitude: 1.0
                easing.period: 0.36
            }
            SequentialAnimation {
                NumberAnimation {
                    target: root; property: "drawerWidthScale"
                    from: 1.0
                    to: (root.openFxMode === "smooth" || (Waybar && !Waybar.windowSideStretch)) ? 1.0 : 1.045
                    duration: Math.round(root.openFxDuration * 0.55)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: root; property: "drawerWidthScale"
                    to: 1.0
                    duration: Math.round(root.openFxDuration * 0.45)
                    easing.type: Easing.InOutQuad
                }
            }
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
    readonly property bool isVertBar: barPos >= 2
    readonly property bool isCenteredBar: Waybar ? Waybar.centeredBar : false
    readonly property int barH: Waybar ? Waybar.barHeight : 34
    readonly property int barTop: Waybar ? Waybar.marginTop : 6
    readonly property int fullBarLeft: Math.max(0, (Waybar ? Waybar.marginLeft : 10) - 2)
    readonly property int fullBarRight: Math.max(0, (Waybar ? Waybar.marginRight : 10) - 2)
    readonly property int maxAvailBarW: Math.max(400, root.width - fullBarLeft - fullBarRight)
    readonly property int customBarW: Waybar ? Math.min(maxAvailBarW, Waybar.barWidth) : maxAvailBarW

    readonly property bool winModVis: Waybar ? (Waybar.hiddenBarModules, Waybar.isBarModuleVisible("window")) : true
    readonly property bool isFixedTitle: Waybar ? Waybar.fixedTitleWidth : false
    readonly property bool winInSideOrder: Waybar ? (Waybar.leftBarOrder.indexOf("window") !== -1 || Waybar.rightBarOrder.indexOf("window") !== -1) : false
    readonly property bool hasWinTitle: winModVis && Waybar && (Waybar.activeWindowTitle.length > 0 || Waybar.barEditMode)
    readonly property real winPillTargetW: !winModVis ? 0 : (isFixedTitle ? (Waybar ? Waybar.fixedTitleSize : 100) : (hasWinTitle ? Math.min(240, Math.ceil(winTitleMeasure.implicitWidth / 2) * 2 + 24) : 0))
    readonly property real islandW: Math.min(maxAvailBarW, leftBarRow.implicitWidth + (winPillTargetW > 0 ? (winPillTargetW + 12) : 0) + rightBarRow.implicitWidth + 24)
    property real smoothBaseBarW: isCenteredBar ? islandW : customBarW
    Behavior on smoothBaseBarW { NumberAnimation { duration: Waybar ? Waybar.barAnimDuration : 75; easing.type: Easing.OutQuint } }
    readonly property real baseBarW: smoothBaseBarW
    readonly property real expandedBarW: isCompactPopup ? baseBarW : Math.max(baseBarW, effDrawerW)
    readonly property real barW: isVertBar ? Math.max(38, barH + 6 + root.barChewExtraH) : ((baseBarW + (expandedBarW - baseBarW) * barExpandProgress) * root.barChewWidthScale)

    readonly property real maxAvailVertH: Math.max(400, root.height - 16)
    readonly property real vertIslandH: Math.min(maxAvailVertH, vertTopCol.implicitHeight + (winPillTargetW > 0 ? (winPillTargetW + 16) : 0) + vertBottomCol.implicitHeight + 28)
    property real smoothVertBarH: isCenteredBar ? vertIslandH : maxAvailVertH
    Behavior on smoothVertBarH { NumberAnimation { duration: Waybar ? Waybar.barAnimDuration : 75; easing.type: Easing.OutQuint } }
    readonly property real expandedVertH: isCompactPopup ? smoothVertBarH : Math.max(smoothVertBarH, effDrawerH)
    readonly property real actualBarH: isVertBar ? (smoothVertBarH + (expandedVertH - smoothVertBarH) * barExpandProgress) : (barH + root.barChewExtraH)

    readonly property real barLeft: {
        if (barPos === 2) return barTop
        if (barPos === 3) return root.width - barW - barTop
        return (isCenteredBar || customBarW < maxAvailBarW) ? ((root.width - barW) * 0.5) : fullBarLeft
    }
    readonly property int barRectY: {
        if (isVertBar) return Math.round((root.height - actualBarH) * 0.5)
        return (barPos === 1) ? (root.height - barH - barTop) : barTop
    }

    readonly property int targetDrawerW: {
        var isM3 = (Theme && Theme.isRounded)
        if (drawerMode === "traymenu") return 230
        if (drawerMode === "filedrop") return isM3 ? 336 : 316
        if (drawerMode === "power") return isM3 ? 280 : 260
        if (drawerMode === "calendar") return isM3 ? 310 : 295
        if (drawerMode === "volume" || drawerMode === "bluetooth") return isM3 ? 360 : 340
        if (drawerMode === "clipboard") return isM3 ? 440 : 410
        return (isWallpaperExpanded || isSettingsMaximized) ? maxAvailBarW : Math.min(isM3 ? 1040 : 860, maxAvailBarW - 80)
    }
    readonly property int targetDrawerH: {
        var isM3 = (Theme && Theme.isRounded)
        if (drawerMode === "traymenu") return 196
        if (drawerMode === "filedrop") return isM3 ? 272 : 254
        if (drawerMode === "power") return isM3 ? 305 : 285
        if (drawerMode === "calendar") return isM3 ? 298 : 280
        if (drawerMode === "volume") {
            var sCnt = (Waybar && Waybar.audioStreams) ? Waybar.audioStreams.length : 0
            if (sCnt <= 0) return 174
            return Math.min(380, 146 + sCnt * 58)
        }
        if (drawerMode === "bluetooth") {
            if (!Bluetooth || !Bluetooth.powered) return 126
            var dCnt = Bluetooth.devices ? Bluetooth.devices.length : 0
            if (dCnt <= 0) return 158
            return Math.min(375, 125 + dCnt * 47)
        }
        if (drawerMode === "clipboard") {
            var cCnt = (Waybar && Waybar.clipboardItems) ? Waybar.clipboardItems.length : 0
            if (cCnt <= 0) return 138
            return Math.min(isM3 ? 390 : 360, 108 + cCnt * 37)
        }
        if (isWallpaperExpanded || isSettingsMaximized) {
            return isVertBar ? (root.height - 12) : (root.height - (barRectY + barH) - Math.max(4, fullBarLeft))
        }
        return isM3 ? Math.min(680, Config ? Math.max(640, Config.windowHeight) : 640) : Math.min(540, Config ? Config.windowHeight : 520)
    }

    property real animDrawerW: targetDrawerW
    property real smoothTargetH: targetDrawerH
    readonly property real wingMix: Math.min(1.0, Math.pow(Math.max(0.0, drawerProgress), 0.42) * 1.15)
    readonly property real effDrawerW: isVertBar
                                       ? Math.max(0.0, animDrawerW * drawerProgress)
                                       : (drawerMode === "power" ? animDrawerW : (animDrawerW * root.drawerWidthScale))
    readonly property real effDrawerH: isVertBar
                                       ? (smoothTargetH * root.drawerWidthScale)
                                       : Math.min(root.height - ((barPos === 1) ? 8 : (barRectY + barH)) - 2, Math.max(0.0, smoothTargetH * drawerProgress))
    readonly property real animDrawerH: effDrawerH

    property real centerAnchorX: {
        if (drawerMode === "traymenu") return trayMenuTargetX
        if (isCompactPopup) return popupTargetX
        return root.width * 0.5
    }
    Behavior on centerAnchorX { enabled: root.drawerProgress > 0.08; NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on animDrawerW { enabled: root.drawerProgress > 0.95; NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
    Behavior on smoothTargetH { enabled: root.drawerProgress > 0.95; NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

    readonly property real drawerX: {
        if (barPos === 2) return barLeft + barW
        if (barPos === 3) return barLeft - effDrawerW
        if (drawerMode === "power") {
            return (centerAnchorX < root.width * 0.5) ? barLeft : (barLeft + barW - effDrawerW)
        }
        var minBound = isCompactPopup ? Math.max(fullBarLeft, barLeft) : fullBarLeft
        var maxBound = isCompactPopup ? Math.min(fullBarLeft + maxAvailBarW - effDrawerW, barLeft + barW - effDrawerW) : (fullBarLeft + maxAvailBarW - effDrawerW)
        return Math.max(minBound, Math.min(maxBound, centerAnchorX - effDrawerW * 0.5))
    }
    readonly property real drawerY: {
        if (isVertBar) return Math.round((root.height - effDrawerH) * 0.5)
        return (barPos === 1) ? (barRectY - animDrawerH) : (barRectY + barH)
    }

    readonly property int notifW: Mako ? Mako.width : 320
    readonly property int notifTargetH: Math.max(46, notifStackCol.implicitHeight + 4)
    property real smoothNotifTargetH: notifTargetH
    Behavior on smoothNotifTargetH { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
    readonly property real animNotifH: smoothNotifTargetH * notifProgress
    readonly property real notifX: {
        var anc = Mako ? Mako.anchor : "top-right"
        var edgeGap = Math.max(4, fullBarRight)
        if (anc.indexOf("left") !== -1) return (barPos === 2) ? (barLeft + barW + 6) : Math.max(4, fullBarLeft)
        if (anc.indexOf("center") !== -1) return Math.round((root.width - notifW) * 0.5)
        return (barPos === 3) ? (barLeft - notifW - 6) : (root.width - notifW - edgeGap)
    }
    readonly property real closedBarLeft: (isCenteredBar || customBarW < maxAvailBarW) ? ((root.width - baseBarW) * 0.5) : fullBarLeft
    readonly property bool barOverlapsNotifX: !isVertBar && (closedBarLeft + baseBarW > notifX - 2) && (closedBarLeft < notifX + notifW + 2)
    readonly property real notifY: {
        if (barPos === 1) return barOverlapsNotifX ? (barRectY - animNotifH) : (root.height - animNotifH - barTop)
        if (barPos === 0) return barOverlapsNotifX ? (barRectY + barH) : barRectY
        return barTop
    }

    property bool modalOpen: false
    property bool barSavePromptOpen: false
    property bool setupWizardOpen: Config ? !Config.firstRunCompleted : false
    readonly property bool anyModalActive: modalOpen || barSavePromptOpen || setupWizardOpen || (Monitors && Monitors.revertDialogActive)
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
            Waybar.syncShellRegion(root, root.drawerOpen, root.notifOpen || root.notifActive,
                                   Math.round(root.notifX), Math.round(root.notifY),
                                   Math.round(root.notifW), Math.round(root.notifTargetH + 12))
        }
    }

    function openDrawerWithMode(mode, tabIdx, anchorX) {
        if (anchorX !== undefined && anchorX > 0) {
            root.popupTargetX = anchorX
            root.pendingPopupX = anchorX
        } else if (mode === "power") {
            root.popupTargetX = root.barLeft + root.barW - 140
            root.pendingPopupX = root.popupTargetX
        }
        if (root.drawerOpen) {
            if (mode === "settings" && tabIdx !== undefined) {
                if (root.drawerMode === "settings" && pageController.currentIndex === tabIdx) {
                    root.drawerOpen = false
                    return
                }
                var wasSettings = (root.drawerMode === "settings")
                root.isWallpaperExpanded = false
                root.drawerMode = "settings"
                if (tabIdx === 21 && Waybar) Waybar.refreshProcesses()
                if (tabIdx === 23 && Waybar && Waybar.clipboardItems.length === 0) Qt.callLater(() => Waybar.refreshClipboard())
                if (wasSettings) pageController.switchPage(tabIdx)
                else pageController.jumpToPageInstant(tabIdx)
                root.syncTabBlur()
                return
            }
            if (root.drawerMode === mode && tabIdx === undefined) {
                root.drawerOpen = false
                return
            }
        }

        root.isWallpaperExpanded = false
        root.drawerMode = mode
        if (mode === "volume" && Waybar) Qt.callLater(() => Waybar.refreshAudioStreams())
        if (mode === "bluetooth" && Bluetooth) Qt.callLater(() => Bluetooth.refresh())
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
        root.syncTabBlur()
    }

    function openTrayContextMenu(appData, globalX) {
        if (root.drawerOpen && root.drawerMode === "traymenu" && root.trayMenuClass === appData.class) {
            root.drawerOpen = false
            return
        }
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
            isSettingsMaximized = false
            root.mousePos = Qt.point(-500, -500)
            if (Theme) Theme.applyEffectiveBlur(Theme.windowBlur)
        } else {
            root.requestActivate()
            sceneRoot.forceActiveFocus()
            Qt.callLater(syncTabBlur)
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
    property real musicWavePhase: 0.0
    property real mediaPillCenterX: 320.0
    property real mediaPillHalfW: 95.0
    readonly property int waveMode: Waybar ? Waybar.mediaWaveMode : 0
    readonly property bool anyMusicWaveOn: (!root.isVertBar && root.barPos === 0 && Waybar && Waybar.mediaActive && Waybar.mediaPlaying && Waybar.mediaWaves) || root.chewWaveActive
    readonly property bool barShaderWaveRun: (anyMusicWaveOn && (waveMode === 0 || waveMode === 2)) || root.chewWaveActive
    readonly property real targetBarWaveAmp: root.chewWaveActive ? 15.0 : (!barShaderWaveRun ? 0.0 : (waveMode === 2 ? (Waybar ? Waybar.arcWaveSize : 38.0) : (Waybar ? Waybar.mediaWaveSize : 11.0)))
    property real musicWaveAmp: targetBarWaveAmp
    Behavior on musicWaveAmp { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

    readonly property bool drawerAnimSettled: root.drawerOpen && !openSeqAnim.running && !switchDrawerAnim.running && !closeSeqAnim.running && root.drawerProgress > 0.98
    readonly property bool drawerWaveShouldRun: anyMusicWaveOn && (waveMode === 0 || waveMode === 2) && drawerAnimSettled
    property real drawerWaveAmp: !drawerWaveShouldRun ? 0.0 : (waveMode === 2 ? (Waybar ? Waybar.arcWaveSize : 38.0) : (Waybar ? Waybar.mediaWaveSize : 11.0))
    Behavior on drawerWaveAmp { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

    property real smoothBass: root.chewWaveActive ? 1.15 : (Waybar ? Waybar.audioBass : 0.0)
    property real smoothMid: root.chewWaveActive ? 1.05 : (Waybar ? Waybar.audioMid : 0.0)
    property real smoothTreb: root.chewWaveActive ? 0.95 : (Waybar ? Waybar.audioTreble : 0.0)
    Behavior on smoothBass { NumberAnimation { duration: 65; easing.type: Easing.Linear } }
    Behavior on smoothMid  { NumberAnimation { duration: 65; easing.type: Easing.Linear } }
    Behavior on smoothTreb { NumberAnimation { duration: 65; easing.type: Easing.Linear } }

    FrameAnimation {
        running: root.anyMusicWaveOn
        onTriggered: {
            var dt = Math.min(0.05, Math.max(0.002, frameTime))
            var spd = 1.5
            if (Waybar) {
                if (root.waveMode === 1) spd = Waybar.pillWaveSpeed
                else if (root.waveMode === 2) spd = Waybar.arcWaveSpeed
                else spd = Waybar.mediaWaveSpeed
            }
            var mult = (root.waveMode === 0) ? 7.5 : ((root.waveMode === 2) ? 2.8 : 2.6)
            root.musicWavePhase = (root.musicWavePhase + dt * mult * spd) % 6283.1853
        }
    }

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
        if (idx === 0) Waybar.runCommand("/home/whrr/.config/hypr/scripts/lock.sh")
        else if (idx === 1) Waybar.runCommand("/home/whrr/.config/hypr/scripts/lock.sh & sleep 0.3 && systemctl suspend && sleep 1.0 && /home/whrr/.config/hypr/scripts/resume_restore.sh")
        else if (idx === 2) Waybar.runCommand("/home/whrr/.config/hypr/scripts/lock.sh & sleep 0.3 && systemctl hibernate && sleep 1.0 && /home/whrr/.config/hypr/scripts/resume_restore.sh")
        else if (idx === 3) Waybar.runCommand("hyprshutdown --post-cmd \"bash -c 'pkill -KILL -u $(whoami)'\"")
        else if (idx === 4) Waybar.runCommand("systemctl reboot")
        else if (idx === 5) Waybar.runCommand("systemctl poweroff")
    }

    NumberAnimation on liquidTime {
        from: 0.0; to: 628.3185; duration: 120000
        loops: Animation.Infinite
        running: root.drawerActive && Config && Config.borderGlowEnabled && Config.borderGlowIntensity > 0.01
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
        sequences: ["Escape"]
        context: Qt.ApplicationShortcut
        enabled: root.drawerOpen || root.isWallpaperExpanded || root.isSettingsMaximized || root.barSavePromptOpen
        onActivated: {
            if (root.isWallpaperExpanded) root.isWallpaperExpanded = false
            else if (root.isSettingsMaximized) root.isSettingsMaximized = false
            else if (root.barSavePromptOpen) root.barSavePromptOpen = false
            else if (root.modalOpen) root.modalOpen = false
            else if (root.drawerOpen) root.requestCloseDrawer()
        }
    }
    Shortcut {
        sequences: ["Up", "K"]
        context: Qt.ApplicationShortcut
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.powerSelectedIndex = (root.powerSelectedIndex + 5) % 6
    }
    Shortcut {
        sequences: ["Down", "J"]
        context: Qt.ApplicationShortcut
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.powerSelectedIndex = (root.powerSelectedIndex + 1) % 6
    }
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        context: Qt.ApplicationShortcut
        enabled: root.drawerOpen && root.drawerMode === "power"
        onActivated: root.triggerPowerAction(root.powerSelectedIndex)
    }

    Item {
        id: sceneRoot
        anchors.fill: parent

        HoverHandler {
            enabled: root.drawerActive && (!Config || Config.cursorGlowIntensity > 0.01)
            onPointChanged: {
                if (root.mousePos.x < -100) {
                    root.trail1 = point.position; root.trail2 = point.position; root.trail3 = point.position
                }
                root.mousePos = point.position; root.trailActive = true
            }
        }

        MouseArea {
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            enabled: root.drawerOpen
            z: 1
            onPressed: (mouse) => {
                var gy = mouse.y
                var inBar = (mouse.x >= root.barLeft && mouse.x <= root.barLeft + root.barW && gy >= root.barRectY && gy <= root.barRectY + root.actualBarH)
                var inDrawer = inBar || (mouse.x >= root.drawerX && mouse.x <= root.drawerX + root.effDrawerW &&
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

        // ЕДИНЫЙ GLSL-ШЕЙДЕР (ПАНЕЛЬ + ОКНО + УВЕДОМЛЕНИЯ + СВЕТ КУРСОРА)
        ShaderEffect {
            id: mergedShellBg
            x: 0; y: 0
            width: parent.width
            height: (root.drawerActive || root.notifActive || root.isVertBar || root.barPos !== 0)
                    ? parent.height
                    : Math.min(parent.height, root.barRectY + root.actualBarH + 115)
            z: 2
            property real currentOpacity: (root.drawerOpen && root.drawerMode === "settings" && pageController.currentIndex === 14 && Config.autoGlass)
                                          ? Math.max(0.0, root.wallpapersLiveOpacity)
                                          : (Config ? Config.opacity : 0.85)
            Behavior on currentOpacity { enabled: pageController.currentIndex === 14; NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
            property color surfCol: Config ? Config.m3Surface : "#0e1015"
            property color notifBgCol: (Theme && Theme.isRounded && Config) ? surfCol : (Mako ? Mako.bgColor : surfCol)
            property real notifAlpha: root.drawerActive ? currentOpacity : (Waybar ? Waybar.barOpacity : 0.88)
            property color outCol: Config ? Config.m3Outline : "#444854"

            property vector2d u_resolution: Qt.vector2d(width, height)
            property vector4d u_bar_rect: Qt.vector4d(root.barLeft, root.barRectY, root.barW, root.actualBarH)
            property vector4d u_drawer_rect: Qt.vector4d(root.drawerX, root.drawerY, root.effDrawerW, root.animDrawerH)
            property vector4d u_notif_rect: notifClipBox.overlapsOpenDrawer ? Qt.vector4d(0, 0, 0, 0) : Qt.vector4d(root.notifX, root.notifY, root.notifW, root.animNotifH)
            property vector4d u_bg_color: Qt.vector4d(surfCol.r, surfCol.g, surfCol.b, currentOpacity)
            property vector4d u_notif_color: Qt.vector4d(notifBgCol.r, notifBgCol.g, notifBgCol.b, notifAlpha)
            property vector4d u_outline_color: Qt.vector4d(outCol.r, outCol.g, outCol.b, root.drawerActive ? 0.32 : 0.16)
            readonly property color activeWaveTint: (Theme && Theme.isRounded && Config) ? Config.m3Primary : (Config ? Config.accentColor : '#a8c7fa')
            property vector3d u_glow_color: Qt.vector3d(activeWaveTint.r, activeWaveTint.g, activeWaveTint.b)
            property vector3d u_cursor_color: Config ? Qt.vector3d(Config.cursorCustomColor.r, Config.cursorCustomColor.g, Config.cursorCustomColor.b) : Qt.vector3d(1, 1, 1)
            property real u_bar_alpha: Waybar ? Waybar.barOpacity : 0.88
            property real u_radius: (Theme && Theme.isRounded) ? (Config ? Math.round(Config.m3WindowRadius * 0.65) : 13.0) : 0.0
            property real u_fillet: (Theme && Theme.isRounded) ? (Config ? Config.m3WindowRadius : 20.0) : 0.0
            property real u_refraction: (root.drawerActive && Theme) ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.55 : 0.0) : 0.0
            property real u_time: root.liquidTime * (Config ? Config.borderGlowSpeed : 1.0)
            property real u_glow_intensity: (root.drawerActive && Config && Config.borderGlowEnabled) ? Config.borderGlowIntensity : 0.0
            property real u_glow_spread: Config ? Config.borderGlowSpread : 0.45
            property real u_glow_mode: Config ? Config.borderGlowColorMode : 4
            property real u_glow_dir: Config ? Config.borderGlowDirection : 0
            property real u_cursor_strength: Config ? Config.cursorGlowIntensity : 0.65
            property vector2d u_mouse: root.drawerActive ? Qt.vector2d(root.mousePos.x, root.mousePos.y) : Qt.vector2d(-500, -500)
            property vector2d u_trail1: Qt.vector2d(root.trail1.x, root.trail1.y)
            property vector2d u_trail2: Qt.vector2d(root.trail2.x, root.trail2.y)
            readonly property real modeParamY: (root.waveMode === 2)
                                               ? (Waybar ? Waybar.arcWaveCurve : 0.65)
                                               : (Waybar ? Waybar.mediaWaveSharpness : 0.70)
            readonly property real modeParamCountOrPack: (root.waveMode === 2)
                                                         ? ((Waybar ? Waybar.arcWaveWidth : 2) * 100.0 + (Waybar ? Waybar.arcWaveGap : 1))
                                                         : (Waybar ? Waybar.mediaWaveCount : 95)
            property vector4d u_music_wave: Qt.vector4d(root.chewWaveActive ? 0 : root.waveMode, root.chewWaveActive ? 0.88 : modeParamY, root.musicWaveAmp, root.musicWavePhase)
            property vector4d u_music_wave2: Qt.vector4d(root.chewWaveActive ? 115 : modeParamCountOrPack, root.smoothBass, root.smoothMid, root.smoothTreb)
            property real u_drawer_wave_amp: root.drawerWaveAmp
            fragmentShader: "qrc:/shaders/qml/shaders/merged_shell.frag.qsb"
        }

        // =====================================================================
        // ВСТРОЕННАЯ ПАНЕЛЬ ЗАДАЧ (УВЕЛИЧЕННАЯ ВЫСОТА И ПРОСТОРНЫЕ ОТСТУПЫ MD3)
        // =====================================================================
        Item {
            id: topBarContainer
            HoverHandler {
                id: barMagnetHover
                enabled: root.drawerActive
                onPointChanged: {
                    if (root.drawerActive && barMagnetHover.hovered) {
                        root.mousePos = Qt.point(topBarContainer.x + barMagnetHover.point.position.x, topBarContainer.y + barMagnetHover.point.position.y)
                    }
                }
                onHoveredChanged: {
                    if (!barMagnetHover.hovered && !root.drawerOpen) {
                        root.mousePos = Qt.point(-500, -500)
                    }
                }
            }
            x: root.barLeft; y: root.barRectY; width: root.barW; height: root.actualBarH; z: 10
            readonly property int vPad: (Theme && Theme.isRounded) ? 8 : 4
            property int pillHeight: Math.max(20, (root.isVertBar ? width : height) - vPad)
            property int pillRadius: (Theme && Theme.isRounded) ? Math.max(5, Math.round(pillHeight * 0.32)) : 0
                        readonly property real settingsOpenWeight: (root.drawerMode === "settings") ? root.drawerProgress : 0.0
            property color pillColor: {
                var pillOp = Waybar ? Waybar.pillOpacity : 0.85
                if (pillOp <= 0.005) return "transparent"
                if (!Theme || !Theme.isRounded || !Config) return Qt.rgba(0.10, 0.11, 0.14, pillOp)
                var wOpen = settingsOpenWeight
                var priMix = 0.14 - 0.04 * wOpen
                var darkScale = 0.72 + 0.28 * wOpen
                var effAlpha = pillOp * (1.0 - 0.18 * wOpen)
                return Qt.rgba(
                    Math.min(1.0, (Config.m3SurfaceContainerHigh.r * (1.0 - priMix) + Config.m3Primary.r * priMix) * darkScale),
                    Math.min(1.0, (Config.m3SurfaceContainerHigh.g * (1.0 - priMix) + Config.m3Primary.g * priMix) * darkScale),
                    Math.min(1.0, (Config.m3SurfaceContainerHigh.b * (1.0 - priMix) + Config.m3Primary.b * priMix) * darkScale),
                    Math.max(0.0, Math.min(1.0, effAlpha))
                )
            }
            readonly property string trayTintHex: (Theme && Theme.isRounded && Config)
                                                  ? (Math.round(Config.accentColor.r * 255).toString(16).padStart(2, '0') +
                                                     Math.round(Config.accentColor.g * 255).toString(16).padStart(2, '0') +
                                                     Math.round(Config.accentColor.b * 255).toString(16).padStart(2, '0'))
                                                  : "ffffff"

            MouseArea { anchors.fill: parent; z: 0; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }
            MouseArea { anchors.fill: leftBarRow; anchors.margins: -4; z: 1 }
            MouseArea { anchors.fill: rightBarRow; anchors.margins: -4; z: 1 }

            readonly property bool editMode: Waybar ? Waybar.barEditMode : false
            readonly property real launcherVis: 1.0
            readonly property bool showSeps: Waybar ? Waybar.barSeparators : false
            readonly property bool uniformMode: Waybar ? Waybar.uniformBarSpacing : true
            readonly property real extraExpandW: uniformMode ? Math.max(0, root.barW - root.baseBarW) : 0
            readonly property bool trayBlockVis: (Waybar ? (Waybar.hiddenBarModules, Waybar.isBarModuleVisible("tray")) : true) && ((Waybar && (Waybar.trayApps.length > 0 || Waybar.vpnActive)) || editMode)
            readonly property int macroGapsCount: 5 + (centerTitlePill.visible ? 1 : 0) + (trayBlockVis ? 1 : 0)
            readonly property real baseGroupGap: Waybar ? Waybar.groupSpacing : 6
            readonly property real macroStepGap: baseGroupGap + (macroGapsCount > 0 ? (extraExpandW / macroGapsCount) : 0)

            function isStatusClusterMod(k) {
                return k === "bluetooth" || k === "network" || k === "clipboard" || k === "volume" || k === "language" || k === "clock"
            }

            // Единая таблетка для системного лотка + часов (bluetooth, network, clipboard, volume, language, clock)
            Rectangle {
                id: statusClockPillBg
                z: 4
                opacity: (root.barDragActive || barChewAnim.running) ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                readonly property var bounds: {
                    var _ = Waybar ? Waybar.rightBarOrder : []
                    var _h = Waybar ? Waybar.hiddenBarModules : ""
                    var _rw = rightBarRow.width
                    var _rx = rightBarRow.x
                    var minX = 999999
                    var maxX = -1
                    for (var i = 0; i < rightModRepeater.count; ++i) {
                        var it = rightModRepeater.itemAt(i)
                        if (it && it.visible && topBarContainer.isStatusClusterMod(it.modKey)) {
                            var bodyX = rightBarRow.x + it.x + it.bodyOffsetX
                            var bodyR = bodyX + it.bodyWidth
                            if (bodyX < minX) minX = bodyX
                            if (bodyR > maxX) maxX = bodyR
                        }
                    }
                    return { valid: maxX > minX, x: minX, w: Math.max(0, maxX - minX) }
                }
                visible: !root.isVertBar && bounds.valid && (Theme && Theme.isRounded)
                x: bounds.x
                width: bounds.w
                height: topBarContainer.pillHeight
                anchors.verticalCenter: parent.verticalCenter
                radius: topBarContainer.pillRadius
                color: topBarContainer.pillColor
            }

            Row {
                id: leftBarRow; z: 5; visible: !root.isVertBar
                opacity: (root.barDragActive || barChewAnim.running) ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                move: Transition { NumberAnimation { properties: "x"; duration: 150; easing.type: Easing.OutQuint } }
                anchors.left: parent.left; anchors.leftMargin: (Theme && Theme.isRounded) ? 8 : 4; anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Repeater {
                    id: leftModRepeater
                    model: Waybar ? Waybar.leftBarOrder.length : 4
                    delegate: Row {
                        id: leftModWrap
                        spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property string modKey: (Waybar && index < Waybar.leftBarOrder.length) ? Waybar.leftBarOrder[index] : ""
                        readonly property real bodyOffsetX: leftGapItem.visible ? leftGapItem.width : 0
                        readonly property real bodyWidth: leftModBody.width
                        readonly property bool modVis: {
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            var _m = Waybar ? Waybar.mediaActive : false
                            if (modKey === "sep") return true
                            if (Waybar && !Waybar.isBarModuleVisible(modKey)) return false
                            if (modKey === "media") return (Waybar ? (Waybar.mediaActive || Waybar.ymBusy) : false) || topBarContainer.editMode || mediaPillBox.width > 0.5
                            return true
                        }
                        visible: modVis

                        Item {
                            id: leftGapItem
                            readonly property bool isLeftMacro: (modKey === "workspaces" || modKey === "weather" || modKey === "media") && index > 0
                            readonly property real fullGap: isLeftMacro
                                                            ? (topBarContainer.macroStepGap + (Waybar ? Waybar.spacing : 4))
                                                            : (Waybar ? Waybar.spacing : 4)
                            visible: index > 0 && fullGap > 0.1
                            width: (index === 1 && Waybar && Waybar.leftBarOrder.length > 0 && Waybar.leftBarOrder[0] === "launcher")
                                   ? (fullGap * topBarContainer.launcherVis)
                                   : fullGap
                            height: 1
                        }

                        Rectangle {
                            visible: topBarContainer.showSeps && index > 0 && modKey !== "sep"
                            opacity: modKey === "workspaces" ? topBarContainer.launcherVis : 1.0
                            width: 1; height: topBarContainer.pillHeight - 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }

                        Item {
                            id: leftModBody
                            height: topBarContainer.height
                            anchors.verticalCenter: parent.verticalCenter
                            clip: modKey === "launcher"
                            opacity: modKey === "launcher" ? (topBarContainer.launcherVis * topBarContainer.launcherVis) : 1.0
                            width: {
                                if (modKey === "sep") return topBarContainer.editMode ? 12 : 5
                                if (modKey === "launcher") return (topBarContainer.pillHeight + 8) * topBarContainer.launcherVis
                                if (modKey === "workspaces") return (wsModuleItem.isDots ? (wsDotsRow.implicitWidth + 12) : (wsRow.implicitWidth + 4))
                                if (modKey === "weather") return wLbl.implicitWidth + 24
                                if (modKey === "media") {
                                    var dlW = ymDownloadPillBox.width
                                    var plW = mediaPillBox.width
                                    var gapW = (dlW > 0.5 && plW > 0.5) ? (Waybar ? Waybar.spacing : 4) : 0
                                    return dlW + gapW + plW
                                }
                                if (modKey === "window") return Math.max(90, root.winPillTargetW)
                                return 0
                            }

                            Rectangle {
                                visible: modKey === "sep"
                                anchors.centerIn: parent
                                width: 1; height: topBarContainer.pillHeight - 4
                                color: Qt.rgba(1, 1, 1, 0.32)
                            }

                            // Контент: launcher (логотип CachyOS остается на месте при маленьких окнах, меняется на кнопку полного экрана только для settings)
                            Item {
                                visible: modKey === "launcher"
                                anchors.fill: parent
                                property real maxIconMix: (root.drawerMode === "settings") ? root.drawerProgress : 0.0
                                Behavior on maxIconMix { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    width: topBarContainer.pillHeight + 8
                                    height: topBarContainer.pillHeight
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: topBarContainer.pillRadius
                                    color: (root.drawerOpen && root.drawerMode === "settings" && root.isSettingsMaximized && Theme && Theme.isRounded && Config)
                                           ? Config.m3Primary
                                           : topBarContainer.pillColor
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Image {
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        sourceSize: Qt.size(32, 32)
                                        smooth: true
                                        opacity: Math.max(0.0, 1.0 - parent.parent.maxIconMix * 1.35)
                                        scale: 1.0 - 0.35 * Math.min(1.0, parent.parent.maxIconMix)
                                        visible: opacity > 0.02
                                        source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isSettingsMaximized ? "󰊔" : "󰊓"
                                        font.pixelSize: 13
                                        font.bold: true
                                        opacity: Math.max(0.0, (parent.parent.maxIconMix - 0.15) / 0.85)
                                        scale: 0.65 + 0.35 * Math.min(1.0, parent.parent.maxIconMix)
                                        visible: opacity > 0.02
                                        color: (root.drawerOpen && root.drawerMode === "settings" && root.isSettingsMaximized && Theme && Theme.isRounded && Config)
                                               ? Config.accentTextColor
                                               : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                                    }
                                }
                                MouseArea {
                                    enabled: !topBarContainer.editMode
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.drawerOpen && root.drawerMode === "settings") {
                                            root.isSettingsMaximized = !root.isSettingsMaximized
                                        } else {
                                            root.openDrawerWithMode("settings", 16)
                                        }
                                    }
                                }
                            }

                            // Контент: workspaces (таблетка как у других модулей + растягивающиеся точки без разбегания при наведении)
                            Item {
                                id: wsModuleItem
                                visible: modKey === "workspaces"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                readonly property bool isDots: Waybar ? Waybar.workspaceDots : false
                                readonly property int dotSz: Waybar ? Waybar.workspaceDotSize : 5
                                readonly property int actDotSz: Math.max(dotSz + 2, Math.round(dotSz * 1.8))
                                property int hoveredWsIdx: -1
                                property int lastHoverIdx: 0
                                readonly property int wsGap: (Theme && Theme.isRounded) ? 3 : 2
                                readonly property int wsBtnW: 25
                                readonly property int wsStep: wsBtnW + wsGap
                                readonly property real outerR: topBarContainer.pillRadius
                                readonly property real innerR: (Theme && Theme.isRounded) ? 5 : 0
                                readonly property int activeWsIdx: {
                                    var list = (modKey === "workspaces" && Waybar) ? Waybar.workspaces : []
                                    for (var i = 0; i < list.length; ++i) {
                                        if (list[i].active === true) return i
                                    }
                                    return 0
                                }

                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.stepWorkspace(e.angleDelta.y > 0 ? -1 : 1) } }

                                // Таблетка фона для режима точек (без обводки, точно как у остальных таблеток панели)
                                Rectangle {
                                    id: wsOuterPill
                                    z: 0
                                    visible: wsModuleItem.isDots
                                    anchors.fill: parent
                                    radius: wsModuleItem.outerR
                                    color: topBarContainer.pillColor
                                }

                                Row {
                                    id: wsRow; z: 1; visible: !wsModuleItem.isDots; anchors.centerIn: parent; spacing: wsModuleItem.wsGap
                                    Repeater {
                                        id: wsRep
                                        model: (modKey === "workspaces" && Waybar) ? Waybar.workspaces.length : 0
                                        delegate: Rectangle {
                                            readonly property bool isFirst: index === 0
                                            readonly property bool isLast: index === wsRep.count - 1
                                            width: wsModuleItem.wsBtnW
                                            height: topBarContainer.pillHeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            topLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                            bottomLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                            topRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                            bottomRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                            color: topBarContainer.pillColor
                                        }
                                    }
                                }

                                Rectangle {
                                    id: wsHoverPill
                                    z: 2
                                    visible: !wsModuleItem.isDots
                                    width: wsModuleItem.wsBtnW
                                    height: topBarContainer.pillHeight
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool isFirst: wsModuleItem.lastHoverIdx === 0
                                    readonly property bool isLast: wsModuleItem.lastHoverIdx === Math.max(0, wsRep.count - 1)
                                    topLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                    bottomLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                    topRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                    bottomRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.20)
                                    opacity: (wsModuleItem.hoveredWsIdx >= 0 && wsModuleItem.hoveredWsIdx !== wsModuleItem.activeWsIdx) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                    x: wsRow.x + wsModuleItem.lastHoverIdx * wsModuleItem.wsStep
                                    Behavior on x { enabled: wsHoverPill.opacity > 0.05; NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                }

                                Rectangle {
                                    id: wsActivePill
                                    z: 3
                                    visible: !wsModuleItem.isDots
                                    width: wsModuleItem.wsBtnW
                                    height: topBarContainer.pillHeight
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool isFirst: wsModuleItem.activeWsIdx === 0
                                    readonly property bool isLast: wsModuleItem.activeWsIdx === Math.max(0, wsRep.count - 1)
                                    topLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                    bottomLeftRadius: isFirst ? wsModuleItem.outerR : wsModuleItem.innerR
                                    topRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                    bottomRightRadius: isLast ? wsModuleItem.outerR : wsModuleItem.innerR
                                    Behavior on topLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    color: Config ? Config.m3Primary : "#ffffff"
                                    x: wsRow.x + wsModuleItem.activeWsIdx * wsModuleItem.wsStep
                                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                }

                                // Режим 1: Номера (1..5) — делегаты не пересоздаются при смене стола
                                Row {
                                    z: 4; visible: !wsModuleItem.isDots; anchors.centerIn: parent; spacing: wsModuleItem.wsGap
                                    Repeater {
                                        model: (modKey === "workspaces" && Waybar) ? Waybar.workspaces.length : 0
                                        delegate: Item {
                                            readonly property var wsItem: (Waybar && index < Waybar.workspaces.length)
                                                                          ? Waybar.workspaces[index]
                                                                          : ({ id: index + 1, active: false, windows: 0 })
                                            property bool act: wsItem.active === true
                                            property bool occ: (wsItem.windows || 0) > 0
                                            property bool hov: wsNumMa.containsMouse
                                            width: wsModuleItem.wsBtnW
                                            height: topBarContainer.pillHeight

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.wsItem.id
                                                font.pixelSize: 11
                                                font.bold: parent.act || parent.hov
                                                color: parent.act
                                                       ? (Config ? Config.accentTextColor : "#000000")
                                                       : (parent.hov ? "#ffffff" : (parent.occ ? (Theme && Theme.isRounded && Config ? Config.m3OnPrimaryContainer : "#ffffff") : "#7c8292"))
                                                Behavior on color { ColorAnimation { duration: 180 } }
                                            }

                                            MouseArea {
                                                id: wsNumMa
                                                enabled: !topBarContainer.editMode
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: { wsModuleItem.lastHoverIdx = index; wsModuleItem.hoveredWsIdx = index }
                                                onExited: { if (wsModuleItem.hoveredWsIdx === index) wsModuleItem.hoveredWsIdx = -1 }
                                                onClicked: if (Waybar) Waybar.switchWorkspace(parent.wsItem.id)
                                            }
                                        }
                                    }
                                }

                                // Режим 2: Компактные кнопочки (точки) — чуть меньше (5px -> 13px), делегаты живые
                                Row {
                                    id: wsDotsRow
                                    z: 4
                                    visible: wsModuleItem.isDots
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Repeater {
                                        id: wsDotsRep
                                        model: (modKey === "workspaces" && Waybar) ? Waybar.workspaces.length : 0
                                        delegate: Item {
                                            id: dotSlot
                                            readonly property var wsItem: (Waybar && index < Waybar.workspaces.length)
                                                                          ? Waybar.workspaces[index]
                                                                          : ({ id: index + 1, active: false, windows: 0 })
                                            property bool act: wsItem.active === true
                                            property bool occ: (wsItem.windows || 0) > 0
                                            property bool hov: wsDotMa.containsMouse
                                            width: dotRect.width
                                            height: topBarContainer.pillHeight

                                            Rectangle {
                                                id: dotRect
                                                anchors.centerIn: parent
                                                width: parent.act ? wsModuleItem.actDotSz : wsModuleItem.dotSz
                                                height: wsModuleItem.dotSz
                                                radius: (Theme && Theme.isRounded) ? height / 2 : 1
                                                color: parent.act
                                                       ? (Config ? Config.m3Primary : "#ffffff")
                                                       : (parent.hov
                                                          ? (Theme && Theme.isRounded && Config
                                                             ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.80)
                                                             : Qt.rgba(1, 1, 1, 0.85))
                                                          : (parent.occ
                                                             ? (Theme && Theme.isRounded && Config
                                                                ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.65)
                                                                : Qt.rgba(1, 1, 1, 0.65))
                                                             : Qt.rgba(1, 1, 1, 0.25)))
                                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                            }

                                            MouseArea {
                                                id: wsDotMa
                                                enabled: !topBarContainer.editMode
                                                anchors.fill: parent
                                                anchors.leftMargin: -2
                                                anchors.rightMargin: -2
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: { wsModuleItem.lastHoverIdx = index; wsModuleItem.hoveredWsIdx = index }
                                                onExited: { if (wsModuleItem.hoveredWsIdx === index) wsModuleItem.hoveredWsIdx = -1 }
                                                onClicked: if (Waybar) Waybar.switchWorkspace(parent.wsItem.id)
                                            }
                                        }
                                    }
                                }
                            }

                                                        // Контент: window (при перетаскивании в левый или правый блок)
                            Rectangle {
                                visible: modKey === "window"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    text: (Waybar && Waybar.activeWindowTitle.length > 0) ? Waybar.activeWindowTitle : "Заголовок окна"
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ececec"
                                    font.pixelSize: 10; font.bold: (Theme && Theme.isRounded)
                                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }
                            }

                            // Контент: weather
                            Rectangle {
                                visible: modKey === "weather"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Text { id: wLbl; anchors.centerIn: parent; text: Waybar ? Waybar.weatherText : "☁️ +3°C"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 20) }
                            }

                            // Индикатор загрузки треков Яндекс.Музыки слева от пилюли плеера (появляется даже когда музыка не играет)
                            Rectangle {
                                id: ymDownloadPillBox
                                visible: modKey === "media" && width > 0.5
                                readonly property bool dlActive: (modKey === "media") && Waybar && Waybar.ymBusy
                                opacity: dlActive ? 1.0 : 0.0
                                clip: true
                                width: dlActive ? (ymDlRow.implicitWidth + 16) : 0
                                height: topBarContainer.pillHeight
                                x: 0
                                anchors.verticalCenter: parent.verticalCenter
                                radius: topBarContainer.pillRadius
                                color: topBarContainer.pillColor
                                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 160 } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    height: 2
                                    width: parent.width * Math.max(0.06, Math.min(1.0, (Waybar ? Waybar.ymProgress : 0) / 100.0))
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                }

                                Row {
                                    id: ymDlRow
                                    height: topBarContainer.pillHeight
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "󰇚"
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: (Waybar ? Waybar.ymProgress : 0) + "%"
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "monospace"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    enabled: !topBarContainer.editMode
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (Waybar) Waybar.stopYmSync()
                                        } else {
                                            root.musicSubTab = 1
                                            root.openDrawerWithMode("settings", 27)
                                        }
                                    }
                                }
                            }

                            // Контент: media (с плавной анимацией сворачивания/разворачивания и передачей координат для волны)
                            Rectangle {
                                id: mediaPillBox
                                readonly property bool wantsVisible: modKey === "media" && ((Waybar && Waybar.mediaActive) || topBarContainer.editMode)
                                readonly property bool isCollapsed: Waybar ? Waybar.mediaCollapsed : false
                                readonly property real targetPillW: !wantsVisible ? 0.0 : (isCollapsed ? (topBarContainer.pillHeight + 8) : (mediaInnerRow.implicitWidth + 12))
                                property real animPillW: targetPillW
                                Behavior on animPillW { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                visible: modKey === "media" && animPillW > 0.5
                                width: animPillW
                                height: topBarContainer.pillHeight
                                opacity: wantsVisible ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                x: (ymDownloadPillBox.visible && ymDownloadPillBox.width > 0.5) ? (ymDownloadPillBox.width + (Waybar ? Waybar.spacing : 4)) : 0
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                anchors.verticalCenter: parent.verticalCenter
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                clip: true

                                function syncWaveCoords() {
                                    if (!visible || width <= 0) return
                                    var gp = mediaPillBox.mapToItem(sceneRoot, width * 0.5, 0)
                                    if (gp.x > 0) {
                                        root.mediaPillCenterX = gp.x
                                        root.mediaPillHalfW = width * 0.5
                                    }
                                }
                                onWidthChanged: Qt.callLater(syncWaveCoords)
                                onXChanged: Qt.callLater(syncWaveCoords)
                                Component.onCompleted: Qt.callLater(syncWaveCoords)
                                Connections {
                                    target: leftModWrap
                                    function onXChanged() { Qt.callLater(mediaPillBox.syncWaveCoords) }
                                }
                                Connections {
                                    target: topBarContainer
                                    function onXChanged() { Qt.callLater(mediaPillBox.syncWaveCoords) }
                                }

                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.mediaSeek(e.angleDelta.y > 0 ? 5 : -5) } }

                                // Режим 1: Плавные VSync столбики внутри пилюли музыки с отступами по краям и приглушением при открытии настроек
                                Row {
                                    id: insidePillEqRow
                                    z: 1
                                    visible: opacity > 0.01
                                    opacity: (root.anyMusicWaveOn && root.waveMode === 1) ? (0.54 - 0.10 * topBarContainer.settingsOpenWeight) : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    readonly property int sidePad: Math.max(10, topBarContainer.pillRadius + 3)
                                    readonly property int pBarW: Waybar ? Waybar.pillWaveWidth : 2
                                    readonly property int pGapW: Waybar ? Waybar.pillWaveGap : 1
                                    readonly property real pMaxH: (Waybar ? Waybar.pillWaveHeight : 70) / 100.0
                                    spacing: pGapW
                                    readonly property int availW: Math.max(10, mediaPillBox.width - sidePad * 2)
                                    readonly property int barCnt: Math.max(3, Math.floor((availW + pGapW) / Math.max(2, pBarW + pGapW)))

                                    Repeater {
                                        model: insidePillEqRow.visible ? insidePillEqRow.barCnt : 0
                                        delegate: Rectangle {
                                            width: insidePillEqRow.pBarW
                                            radius: 0
                                            antialiasing: true
                                            anchors.bottom: parent.bottom
                                            readonly property real bLvl: root.smoothBass
                                            readonly property real mLvl: root.smoothMid
                                            readonly property real tLvl: root.smoothTreb
                                            readonly property real eMix: (index % 3 === 0) ? bLvl : ((index % 3 === 1) ? mLvl : tLvl)
                                            readonly property real s1: 0.5 + 0.5 * Math.sin(root.musicWavePhase * 1.9 + index * 0.85)
                                            readonly property real s2: 0.5 + 0.5 * Math.cos(root.musicWavePhase * 3.1 - index * 0.71)
                                            readonly property real waveOsc: Math.pow(s1 * 0.58 + s2 * 0.42, 0.78)
                                            readonly property real audioBoost: Math.max(0.68, Math.min(1.35, 0.52 + eMix * 1.05))
                                            readonly property real edgeTaper: Math.min(1.0, Math.min(index + 1, insidePillEqRow.barCnt - index) / 1.8)
                                            readonly property real amp: Math.min(1.0, (0.24 + 0.76 * waveOsc) * audioBoost) * (0.60 + 0.40 * edgeTaper)
                                            height: Math.max(2.0, amp * (topBarContainer.pillHeight - 2) * insidePillEqRow.pMaxH)
                                            readonly property color baseCol: (Theme && Theme.isRounded && Config) ? Config.m3Primary : (Config ? Config.accentColor : "#a8c7fa")
                                            color: Qt.darker(baseCol, 1.0 + 0.10 * topBarContainer.settingsOpenWeight)
                                        }
                                    }
                                }

                                // Свернутый режим (клик ЛКМ разворачивает, ПКМ пауза/играть)
                                Item {
                                    z: 10
                                    anchors.fill: parent
                                    opacity: mediaPillBox.isCollapsed ? 1.0 : 0.0
                                    scale: mediaPillBox.isCollapsed ? 1.0 : 0.72
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            text: (Waybar && Waybar.mediaPlaying) ? "󰎆" : "󰐊"
                                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "›"
                                            color: expandMediaMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#cccccc"
                                            font.pixelSize: 13
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: expandMediaMa
                                        enabled: !topBarContainer.editMode
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                if (Waybar) Waybar.mediaPlayPause()
                                            } else {
                                                if (Waybar) Waybar.toggleMediaCollapsed()
                                            }
                                        }
                                    }
                                }

                                // Развернутый режим (уменьшенные отступы, компактная длина и бегущая строка)
                                Row {
                                    id: mediaInnerRow
                                    z: 5
                                    height: topBarContainer.pillHeight
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: !mediaPillBox.isCollapsed ? 1.0 : 0.0
                                    scale: !mediaPillBox.isCollapsed ? 1.0 : 0.92
                                    visible: opacity > 0.01
                                    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    spacing: 2

                                    Item {
                                        width: 11; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: "󰒮"; color: prevMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 10 }
                                        MouseArea { id: prevMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPrev() }
                                    }

                                    Item {
                                        width: 11; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: (Waybar && Waybar.mediaPlaying) ? "󰏤" : "󰐊"; color: playMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 10 }
                                        MouseArea { id: playMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPlayPause() }
                                    }

                                    Item {
                                        width: 11; height: topBarContainer.pillHeight
                                        Text { anchors.centerIn: parent; text: "󰒭"; color: nextMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#ffffff"; font.pixelSize: 10 }
                                        MouseArea { id: nextMa; enabled: !topBarContainer.editMode; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaNext() }
                                    }

                                    Item {
                                        id: mediaTitleBox
                                        readonly property string trackStr: ((Config && Config.musicPrivacyMode) && !(Waybar && Waybar.currentTrackPublic)) ? "Плеер" : (Waybar ? (Waybar.mediaTitle.length > 0 ? Waybar.mediaTitle : "Плеер") : "Плеер")
                                        readonly property int maxTitleW: (!root.hasWinTitle && !root.isFixedTitle) ? 210 : 90
                                        property real trackAnimY: 0.0
                                        property real trackAnimOp: 1.0
                                        ParallelAnimation {
                                            id: pillTrackChangeAnim
                                            NumberAnimation { target: mediaTitleBox; property: "trackAnimY"; from: 11.0; to: 0.0; duration: 220; easing.type: Easing.OutQuint }
                                            NumberAnimation { target: mediaTitleBox; property: "trackAnimOp"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                                        }
                                        onTrackStrChanged: {
                                            if (mediaPillBox.visible && !mediaPillBox.isCollapsed) {
                                                pillTrackChangeAnim.restart()
                                            }
                                        }
                                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                        readonly property bool needMarquee: mediaTrackMeasure.implicitWidth > maxTitleW
                                        readonly property real scrollStepW: mediaTrackMeasure.implicitWidth + mediaSepMeasure.implicitWidth
                                        width: Math.min(maxTitleW, Math.max(28, mediaTrackMeasure.implicitWidth))
                                        height: topBarContainer.pillHeight
                                        clip: true

                                        Text {
                                            id: mediaTrackMeasure
                                            visible: false
                                            text: mediaTitleBox.trackStr
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        Text {
                                            id: mediaSepMeasure
                                            visible: false
                                            text: "        "
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        // Статичный текст, когда название помещается целиком
                                        Text {
                                            visible: !mediaTitleBox.needMarquee
                                            anchors.verticalCenter: parent.verticalCenter
                                            opacity: mediaTitleBox.trackAnimOp
                                            transform: Translate { y: mediaTitleBox.trackAnimY }
                                            text: mediaTitleBox.trackStr
                                            color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        // Бесшовная бегущая строка, когда название не влезает
                                        Row {
                                            id: marqueeRow
                                            visible: mediaTitleBox.needMarquee
                                            height: parent.height
                                            x: 0
                                            opacity: mediaTitleBox.trackAnimOp
                                            transform: Translate { y: mediaTitleBox.trackAnimY }

                                            onVisibleChanged: {
                                                marqueeAnim.stop()
                                                x = 0
                                                if (visible) marqueeAnim.start()
                                            }
                                            Connections {
                                                target: mediaTitleBox
                                                function onTrackStrChanged() {
                                                    marqueeAnim.stop()
                                                    marqueeRow.x = 0
                                                    if (mediaTitleBox.needMarquee && marqueeRow.visible) marqueeAnim.start()
                                                }
                                            }

                                            SequentialAnimation on x {
                                                id: marqueeAnim
                                                loops: Animation.Infinite
                                                running: mediaTitleBox.needMarquee && mediaPillBox.visible && !mediaPillBox.isCollapsed
                                                PauseAnimation { duration: 1200 }
                                                NumberAnimation {
                                                    from: 0
                                                    to: -mediaTitleBox.scrollStepW
                                                    duration: Math.max(2500, Math.round(mediaTitleBox.scrollStepW * 36))
                                                    easing.type: Easing.Linear
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mediaTitleBox.trackStr
                                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "        "
                                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#aaaaaa"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: mediaTitleBox.trackStr
                                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            enabled: !topBarContainer.editMode
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (mouse.button === Qt.RightButton) {
                                                    if (Waybar) Waybar.toggleMediaCollapsed()
                                                } else {
                                                    root.openDrawerWithMode("settings", 27)
                                                }
                                            }
                                        }
                                    }

                                    // Кнопка сворачивания виджета музыки ‹
                                    Item {
                                        z: 15
                                        width: 11; height: topBarContainer.pillHeight
                                        Text {
                                            anchors.centerIn: parent
                                            text: "‹"
                                            color: colMediaMa.containsMouse ? (Config ? Config.m3Primary : "#a8c7fa") : "#cccccc"
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                        MouseArea {
                                            id: colMediaMa
                                            enabled: !topBarContainer.editMode
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onPressed: (mouse) => {
                                                mouse.accepted = true
                                                if (Waybar) Waybar.toggleMediaCollapsed()
                                            }
                                        }
                                    }
                                }
                            }

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
                                    enabled: false
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
                                        } else if (dx > 28 && modKey === "window" && index === Waybar.leftBarOrder.length - 1) {
                                            Waybar.moveWindowModuleToSide("center")
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

            Text {
                id: winTitleMeasure
                visible: false
                text: (Waybar && Waybar.activeWindowTitle.length > 0) ? Waybar.activeWindowTitle : (topBarContainer.editMode ? "Заголовок окна" : "")
                font.pixelSize: 10
                font.bold: (Theme && Theme.isRounded)
            }

            Rectangle {
                id: centerTitlePill; z: 5
                readonly property real leftEdge: leftBarRow.x + leftBarRow.width
                readonly property real rightEdge: rightBarRow.x
                readonly property real availGap: Math.max(0, rightEdge - leftEdge - 14)
                readonly property real targetPillW: (root.isFixedTitle || root.hasWinTitle || topBarContainer.editMode)
                                                    ? Math.round(Math.min(availGap, Math.max(topBarContainer.editMode ? 110 : 0, root.winPillTargetW)))
                                                    : 0
                readonly property real minLeftX: leftEdge + 7
                readonly property real maxRightX: Math.max(minLeftX, rightEdge - 7 - targetPillW)
                readonly property real gapCenterX: leftEdge + (rightEdge - leftEdge - targetPillW) * 0.5
                readonly property real trueCenterX: (parent.width - targetPillW) * 0.5
                readonly property bool useBarCenter: Waybar ? Waybar.centerTitleOnBar : true
                readonly property real targetCenterX: Math.round(Math.max(minLeftX, Math.min(maxRightX, useBarCenter ? trueCenterX : gapCenterX)))

                visible: !root.isVertBar && !root.winInSideOrder && width > 0.5 && availGap > 24
                opacity: (root.barDragActive || barChewAnim.running) ? 0.0 : ((root.isFixedTitle || root.hasWinTitle || topBarContainer.editMode) ? 1.0 : 0.0)
                clip: true
                width: targetPillW
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                x: Math.round(targetCenterX + (targetPillW - width) * 0.5)
                anchors.verticalCenter: parent.verticalCenter
                height: topBarContainer.pillHeight
                radius: topBarContainer.pillRadius
                color: (root.hasWinTitle || topBarContainer.editMode) ? topBarContainer.pillColor : "transparent"

                Text {
                    id: winLbl
                    anchors.centerIn: parent
                    // Фиксированная целевая ширина текста: elide считается ровно 1 раз при смене заголовка и не дергает текст во время анимации!
                    width: Math.max(10, centerTitlePill.targetPillW - 18)
                    text: winTitleMeasure.text
                    color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ececec"
                    font.pixelSize: 10
                    font.bold: (Theme && Theme.isRounded)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }

                Rectangle {
                    visible: topBarContainer.editMode
                    anchors.fill: parent
                    radius: topBarContainer.pillRadius
                    color: centerDragMa.pressed ? Qt.rgba(0.4, 0.7, 1.0, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Config ? Config.m3Primary : "#a8c7fa"
                    border.width: 1
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -2
                        color: "#ff5555"
                        Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: 7; font.bold: true }
                    }
                    MouseArea {
                        id: centerDragMa
                        enabled: false
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.SizeHorCursor
                        property real pressX: 0
                        onPressed: (mouse) => {
                            if (mouse.button === Qt.RightButton || (mouse.x > width - 11 && mouse.y < 11)) {
                                if (Waybar) Waybar.setBarModuleVisible("window", false)
                                mouse.accepted = true
                                return
                            }
                            pressX = mouse.x
                        }
                        onPositionChanged: (mouse) => {
                            if (!(pressedButtons & Qt.LeftButton) || !Waybar) return
                            var dx = mouse.x - pressX
                            if (dx < -35) Waybar.moveWindowModuleToSide("left")
                            else if (dx > 35) Waybar.moveWindowModuleToSide("right")
                        }
                    }
                }
            }

            Row {
                id: rightBarRow; z: 5; visible: !root.isVertBar
                opacity: (root.barDragActive || barChewAnim.running) ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                move: Transition { NumberAnimation { properties: "x"; duration: 150; easing.type: Easing.OutQuint } }
                anchors.right: parent.right; anchors.rightMargin: (Theme && Theme.isRounded) ? 8 : 4; anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // Таблетка записи экрана
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: recPillBox.width > 0.5
                    Rectangle {
                        id: recPillBox
                        property bool isRec: Waybar ? Waybar.recording : false
                        opacity: isRec ? 1.0 : 0.0
                        clip: true
                        height: topBarContainer.pillHeight
                        width: isRec ? (recRow.implicitWidth + 18) : 0
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        anchors.verticalCenter: parent.verticalCenter
                        radius: topBarContainer.pillRadius
                        color: (Theme && Theme.isRounded) ? topBarContainer.pillColor : Qt.rgba(1, 0.25, 0.25, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1, 0.30, 0.30, 0.55)

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
                    Item { width: Waybar ? Waybar.spacing : 4; height: 1 }
                }

                // Таблетка Таймера (слева от системной инфы)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: timerPillBox.width > 0.5
                    Rectangle {
                        id: timerPillBox
                        opacity: root.timerActive ? 1.0 : 0.0
                        clip: true
                        height: topBarContainer.pillHeight
                        width: root.timerActive ? (timerBarInnerRow.implicitWidth + 18) : 0
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        anchors.verticalCenter: parent.verticalCenter
                        radius: topBarContainer.pillRadius
                        color: (Theme && Theme.isRounded) ? topBarContainer.pillColor : Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            id: timerBarInnerRow
                            height: topBarContainer.pillHeight
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: root.timerRunning ? "󰔛" : "󰏤"
                                color: root.timerRunning ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae") : "#ffd54f"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.timerBarText
                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) root.toggleTimerPause()
                                else { root.timeSubTab = 2; root.openDrawerWithMode("settings", 22) }
                            }
                        }
                    }
                    Item { width: Waybar ? Waybar.spacing : 4; height: 1 }
                }

                // Таблетка Секундомера (слева от системной инфы)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: stopwatchPillBox.width > 0.5
                    Rectangle {
                        id: stopwatchPillBox
                        opacity: root.stopwatchActive ? 1.0 : 0.0
                        clip: true
                        height: topBarContainer.pillHeight
                        width: root.stopwatchActive ? (swBarInnerRow.implicitWidth + 18) : 0
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        anchors.verticalCenter: parent.verticalCenter
                        radius: topBarContainer.pillRadius
                        color: (Theme && Theme.isRounded) ? topBarContainer.pillColor : Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            id: swBarInnerRow
                            height: topBarContainer.pillHeight
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: root.stopwatchRunning ? "󱎫" : "󰏤"
                                color: root.stopwatchRunning ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae") : "#ffd54f"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.stopwatchBarText
                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) root.toggleStopwatch()
                                else { root.timeSubTab = 3; root.openDrawerWithMode("settings", 22) }
                            }
                        }
                    }
                    Item { width: Waybar ? Waybar.spacing : 4; height: 1 }
                }

                // Таблетка хода проверки конфигов VPN (слева от системной инфы)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    visible: vpnAuditPillBox.width > 0.5
                    Rectangle {
                        id: vpnAuditPillBox
                        readonly property bool auditActive: Waybar ? Waybar.vpnBusy : false
                        opacity: auditActive ? 1.0 : 0.0
                        clip: true
                        height: topBarContainer.pillHeight
                        width: auditActive ? (vpnAuditBarRow.implicitWidth + 18) : 0
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        anchors.verticalCenter: parent.verticalCenter
                        radius: topBarContainer.pillRadius
                        color: (Theme && Theme.isRounded) ? topBarContainer.pillColor : Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            height: 2
                            width: parent.width * Math.max(0.05, Math.min(1.0, (Waybar ? Waybar.vpnProgressPercent : 0) / 100.0))
                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            id: vpnAuditBarRow
                            height: topBarContainer.pillHeight
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰓅"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffd54f"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: {
                                    if (!Waybar) return "VPN"
                                    var pct = Waybar.vpnProgressPercent + "%"
                                    var pt = Waybar.vpnProgressText || ""
                                    var m = pt.match(/(\d+)\s*✓/)
                                    if (m) return pct + " • " + m[1] + "✓"
                                    return "VPN " + pct
                                }
                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (Waybar) Waybar.stopVpnConfigAudit()
                                } else {
                                    root.openDrawerWithMode("settings", 26)
                                }
                            }
                        }
                    }
                    Item { width: Waybar ? Waybar.spacing : 4; height: 1 }
                }

                Repeater {
                    id: rightModRepeater
                    model: Waybar ? Waybar.rightBarOrder.length : 9
                    delegate: Row {
                        id: rightModWrap
                        spacing: 0
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property string modKey: (Waybar && index < Waybar.rightBarOrder.length) ? Waybar.rightBarOrder[index] : ""
                        readonly property bool modVis: {
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            var _t = Waybar ? Waybar.trayApps : []
                            if (modKey === "sep") return true
                            if (Waybar && !Waybar.isBarModuleVisible(modKey)) return false
                            if (modKey === "tray") return (Waybar && (Waybar.trayApps.length > 0 || Waybar.vpnActive)) || topBarContainer.editMode
                            return true
                        }
                        visible: modVis

                        readonly property bool isStatusMod: topBarContainer.isStatusClusterMod(modKey)
                        readonly property bool isFirstStatusMod: {
                            if (!isStatusMod) return false
                            var ord = Waybar ? Waybar.rightBarOrder : []
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            for (var i = 0; i < index; ++i) {
                                var k = ord[i]
                                if (topBarContainer.isStatusClusterMod(k) && (!Waybar || Waybar.isBarModuleVisible(k))) return false
                            }
                            return true
                        }
                        readonly property bool isLastStatusMod: {
                            if (!isStatusMod) return false
                            var ord = Waybar ? Waybar.rightBarOrder : []
                            var _ = Waybar ? Waybar.hiddenBarModules : ""
                            for (var i = index + 1; i < ord.length; ++i) {
                                var k = ord[i]
                                if (topBarContainer.isStatusClusterMod(k) && (!Waybar || Waybar.isBarModuleVisible(k))) return false
                            }
                            return true
                        }

                        readonly property bool isMacroBoundary: (modKey === "tray" || isFirstStatusMod || modKey === "power") && index > 0
                        readonly property real bodyOffsetX: rightGapItem.visible ? rightGapItem.width : 0
                        readonly property real bodyWidth: rightModBody.width

                        Item {
                            id: rightGapItem
                            visible: index > 0
                            width: parent.isMacroBoundary
                                   ? (topBarContainer.macroStepGap + 4)
                                   : (parent.isStatusMod ? 7 : (Waybar ? Waybar.spacing : 4))
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
                            height: topBarContainer.height
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property int clusterEdgePad: (rightModWrap.isFirstStatusMod ? 13 : 0) + (rightModWrap.isLastStatusMod ? 13 : 0)
                            width: {
                                if (modKey === "sep") return topBarContainer.editMode ? 12 : 5
                                if (modKey === "sysinfo") return sysRow.implicitWidth + 24
                                if (modKey === "tray") return Math.max(28, trayRow.implicitWidth + 22)
                                if (modKey === "bluetooth") return ((Waybar && Waybar.btConnectedCount > 0) ? (btPillInnerRow.implicitWidth + 14) : 16) + clusterEdgePad
                                if (modKey === "network" || modKey === "clipboard") return 16 + clusterEdgePad
                                if (modKey === "volume") return volInnerRow.implicitWidth + 6 + clusterEdgePad
                                if (modKey === "language") return 21 + clusterEdgePad
                                if (modKey === "clock") return barClockText.implicitWidth + 8 + clusterEdgePad
                                if (modKey === "power") return 28
                                if (modKey === "window") return Math.max(90, root.winPillTargetW)
                                return 0
                            }

                            readonly property real innerShiftX: (rightModWrap.isFirstStatusMod ? 6.5 : 0) - (rightModWrap.isLastStatusMod ? 6.5 : 0)

                            Rectangle {
                                visible: modKey === "sep"
                                anchors.centerIn: parent
                                width: 1; height: topBarContainer.pillHeight - 4
                                color: Qt.rgba(1, 1, 1, 0.32)
                            }

                            // Контент: window (при перетаскивании в левый или правый блок)
                            Rectangle {
                                visible: modKey === "window"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    text: (Waybar && Waybar.activeWindowTitle.length > 0) ? Waybar.activeWindowTitle : "Заголовок окна"
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ececec"
                                    font.pixelSize: 10; font.bold: (Theme && Theme.isRounded)
                                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }
                            }

                            Rectangle {
                                visible: modKey === "sysinfo"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Row {
                                    id: sysRow; height: topBarContainer.pillHeight; anchors.centerIn: parent; spacing: 5
                                    Item { width: 40; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 3; Text { text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: (Waybar ? Waybar.cpuUsage : 0) + "%"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                    Item { width: 36; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 3; Text { text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: (Waybar ? Waybar.cpuTemp : 40) + "°C"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                    Item { width: 41; height: topBarContainer.pillHeight; Row { anchors.centerIn: parent; spacing: 3; Text { text: "󰍛"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } Text { text: Waybar ? Waybar.memUsageText : "0.0G"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter } } }
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 21) }
                            }

                            Rectangle {
                                visible: modKey === "tray"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Row {
                                    id: trayRow; anchors.centerIn: parent; spacing: 7
                                    Rectangle {
                                        visible: Waybar ? Waybar.vpnActive : false
                                        width: 32; height: topBarContainer.pillHeight - 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: (Theme && Theme.isRounded) ? Math.max(4, topBarContainer.pillRadius - 2) : 0
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : "transparent"
                                        border.color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: "VPN"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 9; font.bold: true }
                                        MouseArea {
                                            enabled: !topBarContainer.editMode
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openDrawerWithMode("settings", 26)
                                        }
                                    }
                                    Repeater {
                                        model: (modKey === "tray" && Waybar) ? Waybar.trayApps : []
                                        delegate: Item {
                                            id: trayItemDel; width: 16; height: topBarContainer.height; anchors.verticalCenter: parent.verticalCenter
                                            readonly property bool isAyuIcon: String(modelData.icon || "").toLowerCase().indexOf("ayugram") !== -1 || String(modelData.class || "").toLowerCase().indexOf("ayugram") !== -1
                                            Text {
                                                visible: trayItemDel.isAyuIcon
                                                anchors.centerIn: parent
                                                anchors.verticalCenterOffset: -1.5
                                                text: ""
                                                font.pixelSize: 13
                                                color: (Theme && Theme.isRounded && Config) ? Qt.darker(Config.m3Primary, 1.25) : "#ffffff"
                                            }
                                            Image {
                                                visible: !trayItemDel.isAyuIcon
                                                anchors.centerIn: parent
                                                width: 16; height: 16
                                                source: visible ? ("image://appicon/mono:" + modelData.icon + "?tint=" + topBarContainer.trayTintHex) : ""
                                                cache: true
                                                sourceSize: Qt.size(16, 16)
                                                smooth: true
                                            }
                                            MouseArea {
                                                enabled: !topBarContainer.editMode
                                                anchors.fill: parent; anchors.margins: -3; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
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

                                // Обычная иконка, когда ничего не подключено
                                Text {
                                    visible: !Waybar || Waybar.btConnectedCount <= 0
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: rightModBody.innerShiftX
                                    text: "󰂯"
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                    font.pixelSize: 12
                                }

                                // Таблетка (в стиле VPN) с количеством подключенных устройств, когда btConnectedCount > 0
                                Rectangle {
                                    visible: Waybar ? (Waybar.btConnectedCount > 0) : false
                                    width: btPillInnerRow.implicitWidth + 12
                                    height: topBarContainer.pillHeight - 4
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: rightModBody.innerShiftX
                                    radius: (Theme && Theme.isRounded) ? Math.max(4, topBarContainer.pillRadius - 2) : 0
                                    color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : "transparent"
                                    border.color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                    border.width: 1

                                    Row {
                                        id: btPillInnerRow
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            text: "󰂱"
                                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: Waybar ? String(Waybar.btConnectedCount) : "1"
                                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 9
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("bluetooth", undefined, parent.mapToItem(sceneRoot, parent.width * 0.5, 0).x) }
                            }

                            Item {
                                visible: modKey === "network"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: rightModBody.innerShiftX; text: Waybar ? Waybar.netIcon : "󰖪"; color: (Waybar && !Waybar.netConnected) ? "#ff6b6b" : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"); font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 6) }
                            }

                            Item {
                                visible: modKey === "clipboard"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: rightModBody.innerShiftX; text: "󰅌"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("clipboard", undefined, parent.mapToItem(sceneRoot, parent.width * 0.5, 0).x) }
                            }

                            Item {
                                visible: modKey === "volume"
                                anchors.fill: parent
                                Row {
                                    id: volInnerRow; anchors.centerIn: parent; anchors.horizontalCenterOffset: rightModBody.innerShiftX; spacing: 3
                                    Text { text: (Waybar && Waybar.muted) ? "󰝟" : "󰕾"; color: (Waybar && Waybar.muted) ? "#ff6b6b" : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"); font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: (Waybar && Waybar.muted) ? "Mute" : ((Waybar ? Waybar.volume : 50) + "%"); color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                }
                                WheelHandler { enabled: !topBarContainer.editMode; onWheel: (e) => { if (Waybar) Waybar.changeVolume(e.angleDelta.y > 0 ? 5 : -5) } }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("volume", undefined, parent.mapToItem(sceneRoot, parent.width * 0.5, 0).x) }
                            }

                            Item {
                                visible: modKey === "language"
                                anchors.fill: parent
                                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: rightModBody.innerShiftX; text: Waybar ? Waybar.kbLayout : "RU"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 25) }
                            }

                            Item {
                                visible: modKey === "clock"
                                anchors.fill: parent
                                Text {
                                    id: barClockText; anchors.centerIn: parent; anchors.horizontalCenterOffset: rightModBody.innerShiftX
                                    text: Qt.formatDateTime(new Date(), "hh:mm")
                                    color: (root.drawerOpen && root.drawerMode === "calendar")
                                           ? (Config ? Config.m3Primary : "#a8c7fa")
                                           : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                                    font.pixelSize: 10; font.bold: true
                                    Timer { interval: 5000; running: modKey === "clock"; repeat: true; onTriggered: barClockText.text = Qt.formatDateTime(new Date(), "hh:mm") }
                                }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("calendar", undefined, parent.mapToItem(sceneRoot, parent.width * 0.5, 0).x) }
                            }

                            Rectangle {
                                visible: modKey === "power"
                                width: parent.width; height: topBarContainer.pillHeight; anchors.centerIn: parent
                                radius: topBarContainer.pillRadius; color: topBarContainer.pillColor
                                Text { anchors.centerIn: parent; text: "⏻"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 12 }
                                MouseArea { enabled: !topBarContainer.editMode; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("power", undefined, parent.mapToItem(sceneRoot, parent.width * 0.5, 0).x) }
                            }

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
                                    enabled: false
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
                                        } else if (dx < -28 && modKey === "window" && index === 0) {
                                            Waybar.moveWindowModuleToSide("center")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }


            // ЕДИНЫЙ НЕРАЗРУШАЕМЫЙ СЛОЙ ПЕРЕТАСКИВАНИЯ БЛОКОВ ПАНЕЛИ ЗАДАЧ
            Item {
                id: barEditDragLayer
                anchors.fill: parent
                visible: topBarContainer.editMode && !root.isVertBar
                z: 500

                property string activeKey: ""
                property string activeSide: ""
                property real ghostX: 0
                property real ghostW: 56

                function prevVisibleIdx(rep, fromIdx) {
                    for (var i = fromIdx - 1; i >= 0; --i) {
                        var it = rep.itemAt(i)
                        if (it && it.visible && it.bodyWidth > 2) return i
                    }
                    return -1
                }

                function nextVisibleIdx(rep, fromIdx) {
                    for (var i = fromIdx + 1; i < rep.count; ++i) {
                        var it = rep.itemAt(i)
                        if (it && it.visible && it.bodyWidth > 2) return i
                    }
                    return -1
                }

                function hitTestBarItem(mx, my) {
                    for (var i = 0; i < leftModRepeater.count; ++i) {
                        var lw = leftModRepeater.itemAt(i)
                        if (!lw || !lw.visible || !lw.modKey || lw.bodyWidth <= 2) continue
                        var lx = leftBarRow.x + lw.x + lw.bodyOffsetX
                        var lwBody = lw.bodyWidth
                        if (mx >= lx - 4 && mx <= lx + lwBody + 4) {
                            return { side: "left", idx: i, key: lw.modKey, x: lx, w: lwBody }
                        }
                    }
                    if (centerTitlePill.visible) {
                        var cx = centerTitlePill.x
                        var cw = centerTitlePill.width
                        if (mx >= cx - 4 && mx <= cx + cw + 4) {
                            return { side: "center", idx: 0, key: "window", x: cx, w: cw }
                        }
                    }
                    for (var j = 0; j < rightModRepeater.count; ++j) {
                        var rw = rightModRepeater.itemAt(j)
                        if (!rw || !rw.visible || !rw.modKey || rw.bodyWidth <= 2) continue
                        var rx = rightBarRow.x + rw.x + rw.bodyOffsetX
                        var rwBody = rw.bodyWidth
                        if (mx >= rx - 4 && mx <= rx + rwBody + 4) {
                            return { side: "right", idx: j, key: rw.modKey, x: rx, w: rwBody }
                        }
                    }
                    return null
                }

                Rectangle {
                    visible: barEditDragLayer.activeKey !== ""
                    x: barEditDragLayer.ghostX - width * 0.5
                    width: Math.max(32, barEditDragLayer.ghostW)
                    height: topBarContainer.pillHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: topBarContainer.pillRadius
                    color: Qt.rgba(Config ? Config.m3Primary.r : 0.5, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 0.4, 0.35)
                    border.color: Config ? Config.m3Primary : "#ffffff"
                    border.width: 1.5
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: barEditDragLayer.activeKey !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: (mouse) => {
                        if (!Waybar) return
                        var hit = barEditDragLayer.hitTestBarItem(mouse.x, mouse.y)
                        if (!hit) {
                            mouse.accepted = false
                            return
                        }
                        // Скрытие модуля ТОЛЬКО по правой кнопке мыши (ПКМ), чтобы ЛКМ никогда случайно не удалял блок!
                        if (mouse.button === Qt.RightButton) {
                            if (hit.side === "center") Waybar.setBarModuleVisible("window", false)
                            else Waybar.removeBarItemAt(hit.side, hit.idx)
                            barEditDragLayer.activeKey = ""
                            return
                        }
                        barEditDragLayer.activeKey = hit.key
                        barEditDragLayer.activeSide = hit.side
                        barEditDragLayer.ghostW = hit.w
                        barEditDragLayer.ghostX = mouse.x
                    }

                    onPositionChanged: (mouse) => {
                        if (!(pressedButtons & Qt.LeftButton) || barEditDragLayer.activeKey === "" || !Waybar) return
                        var cx = mouse.x
                        barEditDragLayer.ghostX = cx

                        var leftEnd = leftBarRow.x + leftBarRow.width
                        var rightStart = rightBarRow.x

                        // 1. Перетаскивание заголовка окна ("window") между левым блоком, центром и правым блоком
                        if (barEditDragLayer.activeKey === "window") {
                            if (barEditDragLayer.activeSide === "center") {
                                if (cx < leftEnd + 16) {
                                    barEditDragLayer.activeSide = Waybar.transferBarModule("window", "center", -1)
                                    return
                                }
                                if (cx > rightStart - 16) {
                                    barEditDragLayer.activeSide = Waybar.transferBarModule("window", "center", 1)
                                    return
                                }
                                return
                            } else if (barEditDragLayer.activeSide === "left") {
                                var wL = Waybar.leftBarOrder.indexOf("window")
                                if (wL !== -1 && barEditDragLayer.nextVisibleIdx(leftModRepeater, wL) === -1 && cx > leftEnd + 32) {
                                    barEditDragLayer.activeSide = Waybar.transferBarModule("window", "left", 1)
                                    return
                                }
                            } else if (barEditDragLayer.activeSide === "right") {
                                var wR = Waybar.rightBarOrder.indexOf("window")
                                if (wR !== -1 && barEditDragLayer.prevVisibleIdx(rightModRepeater, wR) === -1 && cx < rightStart - 32) {
                                    barEditDragLayer.activeSide = Waybar.transferBarModule("window", "right", -1)
                                    return
                                }
                            }
                        }

                        // 2. Перестановка внутри левого ряда (строго по пересечению центра соседа — без пинг-понга!)
                        if (barEditDragLayer.activeSide === "left") {
                            var curL = Waybar.leftBarOrder.indexOf(barEditDragLayer.activeKey)
                            if (curL === -1) return
                            var pIdx = barEditDragLayer.prevVisibleIdx(leftModRepeater, curL)
                            if (pIdx !== -1) {
                                var prevLW = leftModRepeater.itemAt(pIdx)
                                var prevCenter = leftBarRow.x + prevLW.x + prevLW.bodyOffsetX + prevLW.bodyWidth * 0.5
                                if (cx < prevCenter) {
                                    Waybar.moveBarModule("left", curL, pIdx)
                                    return
                                }
                            }
                            var nIdx = barEditDragLayer.nextVisibleIdx(leftModRepeater, curL)
                            if (nIdx !== -1) {
                                var nextLW = leftModRepeater.itemAt(nIdx)
                                var nextCenter = leftBarRow.x + nextLW.x + nextLW.bodyOffsetX + nextLW.bodyWidth * 0.5
                                if (cx > nextCenter) {
                                    Waybar.moveBarModule("left", curL, nIdx)
                                    return
                                }
                            }
                        }

                        // 3. Перестановка внутри правого ряда (строго по пересечению центра соседа — без пинг-понга!)
                        else if (barEditDragLayer.activeSide === "right") {
                            var curR = Waybar.rightBarOrder.indexOf(barEditDragLayer.activeKey)
                            if (curR === -1) return
                            var prIdx = barEditDragLayer.prevVisibleIdx(rightModRepeater, curR)
                            if (prIdx !== -1) {
                                var prevRW = rightModRepeater.itemAt(prIdx)
                                var prevRCenter = rightBarRow.x + prevRW.x + prevRW.bodyOffsetX + prevRW.bodyWidth * 0.5
                                if (cx < prevRCenter) {
                                    Waybar.moveBarModule("right", curR, prIdx)
                                    return
                                }
                            }
                            var nrIdx = barEditDragLayer.nextVisibleIdx(rightModRepeater, curR)
                            if (nrIdx !== -1) {
                                var nextRW = rightModRepeater.itemAt(nrIdx)
                                var nextRCenter = rightBarRow.x + nextRW.x + nextRW.bodyOffsetX + nextRW.bodyWidth * 0.5
                                if (cx > nextRCenter) {
                                    Waybar.moveBarModule("right", curR, nrIdx)
                                    return
                                }
                            }
                        }
                    }

                    onReleased: {
                        barEditDragLayer.activeKey = ""
                        barEditDragLayer.activeSide = ""
                    }
                    onCanceled: {
                        barEditDragLayer.activeKey = ""
                        barEditDragLayer.activeSide = ""
                    }
                }
            }

            // =================================================================
            // ВЕРТИКАЛЬНАЯ ПАНЕЛЬ ЗАДАЧ (ДЛЯ РЕЖИМОВ СЛЕВА И СПРАВА)
            // =================================================================
            Item {
                id: vertBarLayout
                anchors.fill: parent
                visible: root.isVertBar
                z: 6

                Column {
                    id: vertTopCol
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    // 1. Логотип CachyOS в таблетке
                    Rectangle {
                        visible: (!Waybar || Waybar.isBarModuleVisible("launcher")) && topBarContainer.launcherVis > 0.05
                        width: topBarContainer.pillHeight
                        height: (topBarContainer.pillHeight + 8) * topBarContainer.launcherVis
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor
                        opacity: topBarContainer.launcherVis
                        clip: true
                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                            source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 16) }
                    }

                    // 2. Рабочие столы (вертикальная таблетка без обводки + растягивающиеся точки)
                    Item {
                        id: vWsBox
                        visible: !Waybar || Waybar.isBarModuleVisible("workspaces")
                        readonly property bool isDots: Waybar ? Waybar.workspaceDots : false
                                readonly property int dotSz: Waybar ? Waybar.workspaceDotSize : 5
                                readonly property int actDotSz: Math.max(dotSz + 2, Math.round(dotSz * 1.8))
                        width: topBarContainer.pillHeight
                        height: isDots ? (vWsDotsCol.implicitHeight + 16) : vWsCol.implicitHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        property int hoveredIdx: -1
                        property int lastHoverIdx: 0
                        readonly property int btnH: 24
                        readonly property int gap: (Theme && Theme.isRounded) ? 3 : 2
                        readonly property int step: btnH + gap
                        readonly property real outerR: topBarContainer.pillRadius
                        readonly property real innerR: (Theme && Theme.isRounded) ? 5 : 0
                        readonly property int activeIdx: {
                            var list = Waybar ? Waybar.workspaces : []
                            for (var i = 0; i < list.length; ++i) if (list[i].active === true) return i
                            return 0
                        }
                        WheelHandler { onWheel: (e) => { if (Waybar) Waybar.stepWorkspace(e.angleDelta.y > 0 ? -1 : 1) } }

                        Rectangle {
                            z: 0
                            visible: vWsBox.isDots
                            anchors.fill: parent
                            radius: vWsBox.outerR
                            color: topBarContainer.pillColor
                        }

                        Column {
                            id: vWsCol; z: 1; visible: !vWsBox.isDots; anchors.centerIn: parent; spacing: vWsBox.gap
                            Repeater {
                                id: vWsRep
                                model: Waybar ? Waybar.workspaces.length : 0
                                delegate: Rectangle {
                                    readonly property bool isFirst: index === 0
                                    readonly property bool isLast: index === vWsRep.count - 1
                                    width: topBarContainer.pillHeight; height: vWsBox.btnH
                                    topLeftRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                                    topRightRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                                    bottomLeftRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                                    bottomRightRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                                    color: topBarContainer.pillColor
                                }
                            }
                        }

                        Rectangle {
                            id: vWsHoverPill; z: 2
                            visible: !vWsBox.isDots
                            width: topBarContainer.pillHeight; height: vWsBox.btnH
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property bool isFirst: vWsBox.lastHoverIdx === 0
                            readonly property bool isLast: vWsBox.lastHoverIdx === Math.max(0, vWsRep.count - 1)
                            topLeftRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                            topRightRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                            bottomLeftRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                            bottomRightRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                            color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.20)
                            opacity: (vWsBox.hoveredIdx >= 0 && vWsBox.hoveredIdx !== vWsBox.activeIdx) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            y: vWsBox.lastHoverIdx * vWsBox.step
                            Behavior on y { enabled: vWsHoverPill.opacity > 0.05; NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                        }

                        Rectangle {
                            id: vWsActivePill; z: 3
                            visible: !vWsBox.isDots
                            width: topBarContainer.pillHeight; height: vWsBox.btnH
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property bool isFirst: vWsBox.activeIdx === 0
                            readonly property bool isLast: vWsBox.activeIdx === Math.max(0, vWsRep.count - 1)
                            topLeftRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                            topRightRadius: isFirst ? vWsBox.outerR : vWsBox.innerR
                            bottomLeftRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                            bottomRightRadius: isLast ? vWsBox.outerR : vWsBox.innerR
                            Behavior on topLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            Behavior on topRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            Behavior on bottomLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            Behavior on bottomRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            color: Config ? Config.m3Primary : "#ffffff"
                            y: vWsBox.activeIdx * vWsBox.step
                            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                        }

                        Column {
                            z: 4; visible: !vWsBox.isDots; anchors.centerIn: parent; spacing: vWsBox.gap
                            Repeater {
                                model: Waybar ? Waybar.workspaces.length : 0
                                delegate: Item {
                                    readonly property var wsItem: (Waybar && index < Waybar.workspaces.length)
                                                                  ? Waybar.workspaces[index]
                                                                  : ({ id: index + 1, active: false, windows: 0 })
                                    property bool act: wsItem.active === true
                                    property bool occ: (wsItem.windows || 0) > 0
                                    property bool hov: vWsMa.containsMouse
                                    width: topBarContainer.pillHeight; height: vWsBox.btnH
                                    Text {
                                        anchors.centerIn: parent; text: parent.wsItem.id; font.pixelSize: 11; font.bold: parent.act || parent.hov
                                        color: parent.act ? (Config ? Config.accentTextColor : "#000000") : (parent.hov ? "#ffffff" : (parent.occ ? (Theme && Theme.isRounded && Config ? Config.m3OnPrimaryContainer : "#ffffff") : "#7c8292"))
                                        Behavior on color { ColorAnimation { duration: 180 } }
                                    }
                                    MouseArea {
                                        id: vWsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: { vWsBox.lastHoverIdx = index; vWsBox.hoveredIdx = index }
                                        onExited: if (vWsBox.hoveredIdx === index) vWsBox.hoveredIdx = -1
                                        onClicked: if (Waybar) Waybar.switchWorkspace(parent.wsItem.id)
                                    }
                                }
                            }
                        }

                        Column {
                            id: vWsDotsCol
                            z: 4
                            visible: vWsBox.isDots
                            anchors.centerIn: parent
                            spacing: 3
                            Repeater {
                                id: vWsDotsRep
                                model: Waybar ? Waybar.workspaces.length : 0
                                delegate: Item {
                                    readonly property var wsItem: (Waybar && index < Waybar.workspaces.length)
                                                                  ? Waybar.workspaces[index]
                                                                  : ({ id: index + 1, active: false, windows: 0 })
                                    property bool act: wsItem.active === true
                                    property bool occ: (wsItem.windows || 0) > 0
                                    property bool hov: vWsDotMa.containsMouse
                                    width: topBarContainer.pillHeight
                                    height: vDotRect.height

                                    Rectangle {
                                        id: vDotRect
                                        anchors.centerIn: parent
                                        width: vWsBox.dotSz
                                        height: parent.act ? vWsBox.actDotSz : vWsBox.dotSz
                                        radius: (Theme && Theme.isRounded) ? width / 2 : 1
                                        color: parent.act
                                               ? (Config ? Config.m3Primary : "#ffffff")
                                               : (parent.hov
                                                  ? (Theme && Theme.isRounded && Config
                                                     ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.80)
                                                     : Qt.rgba(1, 1, 1, 0.85))
                                                  : (parent.occ
                                                     ? (Theme && Theme.isRounded && Config
                                                        ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.65)
                                                        : Qt.rgba(1, 1, 1, 0.65))
                                                     : Qt.rgba(1, 1, 1, 0.25)))
                                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                        Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        id: vWsDotMa; anchors.fill: parent; anchors.topMargin: -2; anchors.bottomMargin: -2; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: { vWsBox.lastHoverIdx = index; vWsBox.hoveredIdx = index }
                                        onExited: if (vWsBox.hoveredIdx === index) vWsBox.hoveredIdx = -1
                                        onClicked: if (Waybar) Waybar.switchWorkspace(parent.wsItem.id)
                                    }
                                }
                            }
                        }
                    }

                    // 3. Погода (иконка и градусы друг под другом)
                    Rectangle {
                        visible: !Waybar || Waybar.isBarModuleVisible("weather")
                        width: topBarContainer.pillHeight
                        height: vWeatherCol.implicitHeight + 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor
                        Column {
                            id: vWeatherCol
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (Waybar ? Waybar.weatherText : "☁️ +3°C").split(" ")[0]
                                font.pixelSize: 12
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    var p = (Waybar ? Waybar.weatherText : "☁️ +3°C").split(" ")
                                    return p.length > 1 ? p[1] : p[0]
                                }
                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                font.pixelSize: 9; font.bold: true
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 20) }
                    }

                    // 4. Музыка (кнопки столбиком)
                    Rectangle {
                        visible: (!Waybar || Waybar.isBarModuleVisible("media")) && (Waybar && Waybar.mediaActive)
                        width: topBarContainer.pillHeight
                        height: vMediaCol.implicitHeight + 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor
                        Column {
                            id: vMediaCol; anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰒮"; color: "#ffffff"; font.pixelSize: 11; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPrev() } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Waybar && Waybar.mediaPlaying) ? "󰏤" : "󰐊"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 12; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaPlayPause() } }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰒭"; color: "#ffffff"; font.pixelSize: 11; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Waybar) Waybar.mediaNext() } }
                        }
                    }
                }

                // 5. Заголовок активного окна (повернут боком на 90 градусов!)
                Rectangle {
                    id: vertTitlePill
                    readonly property real topEdge: vertTopCol.y + vertTopCol.height
                    readonly property real botEdge: vertBottomCol.y
                    readonly property real availH: Math.max(0, botEdge - topEdge - 16)
                    readonly property real gapCenterY: Math.round(topEdge + (botEdge - topEdge - height) * 0.5)
                    readonly property real trueCenterY: Math.round((parent.height - height) * 0.5)
                    readonly property bool useBarCenter: Waybar ? Waybar.centerTitleOnBar : true
                    readonly property real targetY: useBarCenter ? trueCenterY : gapCenterY

                    visible: height > 10 && availH > 30
                    opacity: (root.isFixedTitle || root.hasWinTitle) ? 1.0 : 0.0
                    width: topBarContainer.pillHeight
                    height: (root.isFixedTitle || root.hasWinTitle) ? Math.min(availH, root.winPillTargetW) : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(topEdge + 8, Math.min(Math.max(topEdge + 8, botEdge - 8 - height), targetY))
                    radius: topBarContainer.pillRadius
                    color: root.hasWinTitle ? topBarContainer.pillColor : "transparent"
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        width: vertTitlePill.height - 20
                        rotation: root.barPos === 2 ? -90 : 90
                        text: Waybar ? Waybar.activeWindowTitle : ""
                        color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ececec"
                        font.pixelSize: 10
                        font.bold: (Theme && Theme.isRounded)
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings") }
                }

                // 6. Нижний столбик модулей (Ресурсы, Трей, Сис лоток + Часы в 2 строчки, Питание)
                Column {
                    id: vertBottomCol
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    // Ресурсы (CPU / Temp / RAM друг над другом)
                    Rectangle {
                        visible: !Waybar || Waybar.isBarModuleVisible("sysinfo")
                        width: topBarContainer.pillHeight
                        height: vSysCol.implicitHeight + 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor
                        Column {
                            id: vSysCol; anchors.centerIn: parent; spacing: 5
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 0
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Waybar ? Waybar.cpuUsage : 0) + "%"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 8; font.bold: true }
                            }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 0
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Waybar ? Waybar.cpuTemp : 40) + "°"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 8; font.bold: true }
                            }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 0
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍛"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 11 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Waybar ? Waybar.memUsageText : "0G"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 8; font.bold: true }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 21) }
                    }

                    // Трей (столбиком)
                    Rectangle {
                        visible: topBarContainer.trayBlockVis
                        width: topBarContainer.pillHeight
                        height: vTrayCol.implicitHeight + 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor
                        Column {
                            id: vTrayCol; anchors.centerIn: parent; spacing: 6
                            Rectangle {
                                visible: Waybar ? Waybar.vpnActive : false
                                width: topBarContainer.pillHeight - 4; height: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: (Theme && Theme.isRounded) ? 5 : 0
                                color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : "transparent"
                                border.color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; border.width: 1
                                Text { anchors.centerIn: parent; text: "VPN"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 7; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 26) }
                            }
                            Repeater {
                                model: Waybar ? Waybar.trayApps : []
                                delegate: Item {
                                    id: vTrayDel; width: topBarContainer.pillHeight; height: 18
                                    readonly property bool isAyuIcon: String(modelData.icon || "").toLowerCase().indexOf("ayugram") !== -1 || String(modelData.class || "").toLowerCase().indexOf("ayugram") !== -1
                                    Text {
                                        visible: vTrayDel.isAyuIcon
                                        anchors.centerIn: parent
                                        text: ""
                                        font.pixelSize: 13
                                        color: (Theme && Theme.isRounded && Config) ? Qt.darker(Config.m3Primary, 1.25) : "#ffffff"
                                    }
                                    Image {
                                        visible: !vTrayDel.isAyuIcon
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: visible ? ("image://appicon/mono:" + modelData.icon + "?tint=" + topBarContainer.trayTintHex) : ""
                                        cache: false; sourceSize: Qt.size(16, 16); smooth: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                var gp = vTrayDel.mapToItem(sceneRoot, vTrayDel.width * 0.5, 0)
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

                    // Единая вертикальная таблетка: Системный лоток + Часы на 2 строчках (ЧЧ и ММ)
                    Rectangle {
                        width: topBarContainer.pillHeight
                        height: vStatusCol.implicitHeight + 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: topBarContainer.pillColor

                        Column {
                            id: vStatusCol
                            anchors.centerIn: parent
                            spacing: 7

                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("bluetooth")
                                width: topBarContainer.pillHeight; height: 15
                                Text { anchors.centerIn: parent; text: "󰂯"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("bluetooth") }
                            }
                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("network")
                                width: topBarContainer.pillHeight; height: 15
                                Text { anchors.centerIn: parent; text: Waybar ? Waybar.netIcon : "󰖪"; color: (Waybar && !Waybar.netConnected) ? "#ff6b6b" : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"); font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 6) }
                            }
                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("clipboard")
                                width: topBarContainer.pillHeight; height: 15
                                Text { anchors.centerIn: parent; text: "󰅌"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 23) }
                            }
                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("volume")
                                width: topBarContainer.pillHeight; height: 22
                                WheelHandler { onWheel: (e) => { if (Waybar) Waybar.changeVolume(e.angleDelta.y > 0 ? 5 : -5) } }
                                Column {
                                    anchors.centerIn: parent; spacing: 0
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Waybar && Waybar.muted) ? "󰝟" : "󰕾"; color: (Waybar && Waybar.muted) ? "#ff6b6b" : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"); font.pixelSize: 12 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: (Waybar && Waybar.muted) ? "M" : ((Waybar ? Waybar.volume : 50) + "%"); color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 8; font.bold: true }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("volume") }
                            }
                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("language")
                                width: topBarContainer.pillHeight; height: 14
                                Text { anchors.centerIn: parent; text: Waybar ? Waybar.kbLayout : "RU"; color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"; font.pixelSize: 10; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("settings", 25) }
                            }
                            Item {
                                visible: !Waybar || Waybar.isBarModuleVisible("clock")
                                width: topBarContainer.pillHeight; height: 26
                                Column {
                                    anchors.centerIn: parent; spacing: 0
                                    Text {
                                        id: vClockH; anchors.horizontalCenter: parent.horizontalCenter
                                        text: Qt.formatDateTime(new Date(), "hh")
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: 10; font.bold: true
                                    }
                                    Text {
                                        id: vClockM; anchors.horizontalCenter: parent.horizontalCenter
                                        text: Qt.formatDateTime(new Date(), "mm")
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#ffffff"
                                        font.pixelSize: 10; font.bold: true
                                    }
                                    Timer {
                                        interval: 5000; running: root.isVertBar; repeat: true
                                        onTriggered: {
                                            var d = new Date()
                                            vClockH.text = Qt.formatDateTime(d, "hh")
                                            vClockM.text = Qt.formatDateTime(d, "mm")
                                        }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("calendar") }
                            }
                        }
                    }

                    // Питание
                    Rectangle {
                        visible: !Waybar || Waybar.isBarModuleVisible("power")
                        width: topBarContainer.pillHeight; height: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: topBarContainer.pillRadius
                        color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : "transparent"
                        Text { anchors.centerIn: parent; text: "⏻"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openDrawerWithMode("power") }
                    }
                }
            }

            // Пунктирная обводка и подсказка при перетаскивании файла на панель задач
            Item {
                id: barDashedDropOverlay
                z: 890
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: (root.barDragActive && !barChewAnim.running) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                onVisibleChanged: if (visible) dashedBorderCanvas.requestPaint()

                Canvas {
                    id: dashedBorderCanvas
                    anchors.fill: parent
                    anchors.margins: 4
                    onWidthChanged: if (visible) requestPaint()
                    onHeightChanged: if (visible) requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (width <= 8 || height <= 8) return
                        var r = (Theme && Theme.isRounded) ? Math.min(height * 0.42, Config ? Math.round(Config.m3WindowRadius * 0.55) : 11) : 0
                        var x = 1.5, y = 1.5, w = width - 3.0, h = height - 3.0
                        ctx.save()
                        ctx.beginPath()
                        ctx.setLineDash([7, 5])
                        ctx.lineWidth = 1.8
                        ctx.strokeStyle = Config ? Config.m3Primary.toString() : "#ffffff"
                        if (r <= 1) {
                            ctx.rect(x, y, w, h)
                        } else {
                            ctx.moveTo(x + r, y)
                            ctx.lineTo(x + w - r, y)
                            ctx.arcTo(x + w, y, x + w, y + r, r)
                            ctx.lineTo(x + w, y + h - r)
                            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                            ctx.lineTo(x + r, y + h)
                            ctx.arcTo(x, y + h, x, y + h - r, r)
                            ctx.lineTo(x, y + r)
                            ctx.arcTo(x, y, x + r, y, r)
                        }
                        ctx.closePath()
                        ctx.stroke()
                        ctx.restore()
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰇚"
                        color: Config ? Config.m3Primary : "#ffffff"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Отпустите файл здесь"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Иконка заглатываемого файла во время жевания
            Rectangle {
                z: 895
                visible: root.swallowIconScale > 0.02
                x: Math.max(12, Math.min(topBarContainer.width - 44, (root.barDropX - topBarContainer.x) - 18))
                y: root.swallowIconY
                width: 36; height: 36; radius: 18
                scale: root.swallowIconScale
                color: Config ? Config.m3Primary : "#ffffff"
                Text {
                    anchors.centerIn: parent
                    text: "󰈔"
                    font.pixelSize: 18
                    color: Config ? Config.accentTextColor : "#000000"
                }
            }

            // Зона приёма перетаскиваемых файлов (DropArea не блокирует обычные клики мыши!)
            DropArea {
                id: barFileDropArea
                z: 900
                anchors.fill: parent
                anchors.bottomMargin: -24
                onEntered: (drag) => {
                    root.barDragActive = true
                    root.barDropX = topBarContainer.x + drag.x
                }
                onPositionChanged: (drag) => {
                    root.barDropX = topBarContainer.x + drag.x
                }
                onExited: {
                    if (!barChewAnim.running) {
                        root.barDragActive = false
                        root.chewWaveActive = false
                    }
                }
                onDropped: (drop) => {
                    var rawPath = ""
                    if (drop.hasUrls && drop.urls.length > 0) {
                        rawPath = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                    } else if (drop.hasText && drop.text.trim().length > 0) {
                        rawPath = drop.text.trim().split(/\r?\n/)[0].replace(/^file:\/\//, "").trim()
                    }
                    if (rawPath.length > 0) {
                        root.droppedFilePath = rawPath
                        var parts = rawPath.split("/")
                        root.droppedFileName = parts.length > 0 ? parts[parts.length - 1] : rawPath
                        root.barDropX = topBarContainer.x + drop.x
                        barChewAnim.restart()
                        drop.accept()
                    } else {
                        root.barDragActive = false
                        root.chewWaveActive = false
                    }
                }
            }

        }

        // ПРАВЫЙ СТЕК УВЕДОМЛЕНИЙ (ПОВЕРХ ОКНА НАСТРОЕК С СОБСТВЕННОЙ ПОДЛОЖКОЙ ПРИ ОТКРЫТОМ ОКНЕ)
        Item {
            id: notifClipBox
            x: root.notifX; y: root.notifY; width: root.notifW; height: root.animNotifH
            clip: true; visible: root.notifActive; z: 15

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
            }

            readonly property bool overlapsOpenDrawer: root.drawerActive

            Rectangle {
                anchors.fill: parent
                visible: notifClipBox.overlapsOpenDrawer
                color: mergedShellBg.surfCol
                opacity: mergedShellBg.currentOpacity
                radius: (Theme && Theme.isRounded) ? Math.round(mergedShellBg.u_radius * 1.25) : 0
                border.width: 1
                border.color: Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.32) : Qt.rgba(1, 1, 1, 0.20)
            }

            Column {
                id: notifStackCol
                z: 2
                width: root.notifW
                y: -(1.0 - root.notifProgress) * 18
                opacity: Math.min(1.0, root.notifProgress * 1.35)
                spacing: 0; topPadding: 2; bottomPadding: 4

                Repeater {
                    model: Mako ? Mako.activePopups : []
                    delegate: Item {
                        width: root.notifW
                        height: Math.max(44, notifTextCol.implicitHeight + (Mako ? Mako.padding : 12))

                        // Красная обводка только внутри самого важного (critical) уведомления
                        Rectangle {
                            visible: modelData.critical === true
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            radius: (Theme && Theme.isRounded) ? (Config ? Math.min(10, Math.round(Config.m3CardRadius * 0.55)) : 8) : 0
                            color: Qt.rgba(1.0, 0.25, 0.25, 0.08)
                            border.width: Math.max(1, Mako ? Mako.borderSize : 1)
                            border.color: Mako ? Mako.criticalBorderColor : "#ff6b6b"
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 6; anchors.bottomMargin: 6; spacing: 10
                            Image { visible: Mako && Mako.icons && modelData.icon && modelData.icon.length > 0; source: visible ? ("image://appicon/" + modelData.icon) : ""; Layout.preferredWidth: 22; Layout.preferredHeight: 22; sourceSize: Qt.size(22, 22); Layout.alignment: Qt.AlignVCenter }
                            ColumnLayout {
                                id: notifTextCol; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.summary
                                        color: modelData.critical
                                               ? (Mako ? Mako.criticalBorderColor : "#ff6b6b")
                                               : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : (Mako ? Mako.textColor : "#ffffff"))
                                        font.pixelSize: Mako ? Mako.fontSize : 11
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: "✕"
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3Outline : "#888888"
                                        font.pixelSize: 9
                                        Layout.alignment: Qt.AlignTop
                                    }
                                }
                                Text {
                                    text: modelData.body
                                    color: (Theme && Theme.isRounded && Config)
                                           ? Config.m3OnPrimaryContainer
                                           : (Mako ? Qt.lighter(Mako.textColor, 0.85) : "#cccccc")
                                    font.pixelSize: Mako ? Math.max(8, Mako.fontSize - 1) : 10
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Rectangle {
                            visible: index < root.notifCount - 1 || (Mako && Mako.hiddenPopupCount > 0)
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            height: 1
                            color: (Theme && Theme.isRounded && Config)
                                   ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.25)
                                   : Qt.rgba(1, 1, 1, 0.14)
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (Mako) Mako.dismissPopup(modelData.id) }
                    }
                }

                Item {
                    visible: Mako && Mako.hiddenPopupCount > 0
                    width: root.notifW
                    height: visible ? 24 : 0

                    Text {
                        anchors.centerIn: parent
                        text: "+" + (Mako ? Mako.hiddenPopupCount : 0) + " скрытых"
                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#aaaaaa"
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
                width: root.targetDrawerW
                height: root.targetDrawerH
                x: root.barPos === 2
                   ? (-(1.0 - root.drawerProgress) * 68)
                   : (root.barPos === 3 ? ((1.0 - root.drawerProgress) * 68) : Math.round((parent.width - width) * 0.5))
                y: root.isVertBar
                   ? Math.round((parent.height - height) * 0.5)
                   : (root.barPos === 1 ? ((1.0 - root.drawerProgress) * 68) : (-(1.0 - root.drawerProgress) * 68))
                transform: Scale {
                    origin.x: drawerInner.width * 0.5
                    origin.y: 0
                    xScale: root.contentMaxBounce * root.drawerWidthScale * ((root.openFxMode === "zoom_spring" && root.drawerOpen) ? (0.90 + 0.10 * root.drawerProgress) : 1.0)
                    yScale: root.contentMaxBounce * (0.90 + 0.10 * root.drawerProgress)
                }
                opacity: Math.min(1.0, Math.max(0.0, root.drawerProgress) * 1.35)

                MouseArea {
                    anchors.fill: parent; z: 1000
                    acceptedButtons: Qt.LeftButton | Qt.RightButton; hoverEnabled: false
                    onPressed: (mouse) => {
                        root.triggerClickRipple(mouse.x, mouse.y)
                        var sc = Config ? Config.uiScale : 1.0
                        if (mouse.button === Qt.LeftButton && root.drawerMode === "settings" && pageController.currentIndex > 0 &&
                            mouse.x >= 0 && mouse.x <= pageController.sidebarW * sc && mouse.y >= 0 && mouse.y <= 38 * sc) {
                            Qt.callLater(() => pageController.switchPage(0))
                        }
                        mouse.accepted = false
                    }
                }

                // 0a. МЕНЮ ДЕЙСТВИЙ СО СЪЕДЕННЫМ ПАНЕЛЬЮ ФАЙЛОМ (FILEDROP)
                Item {
                    id: fileDropMenuBox
                    anchors.fill: parent
                    visible: root.drawerMode === "filedrop"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 28; height: 28
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰈔"
                                    font.pixelSize: 15
                                    color: Config ? Config.accentTextColor : "#000000"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: root.droppedFileName.length > 0 ? root.droppedFileName : "Файл получен"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: root.droppedFilePath
                                    color: "#888888"
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.10)
                        }

                        Item {
                            id: fdItemsArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property int itemCount: 5
                            readonly property real gap: 5
                            readonly property real btnH: Math.max(28, (height - gap * (itemCount - 1)) / itemCount)

                            Rectangle {
                                x: 0
                                y: root.fileDropSelectedIndex * (fdItemsArea.btnH + fdItemsArea.gap)
                                width: fdItemsArea.width
                                height: fdItemsArea.btnH
                                radius: (Theme && Theme.isRounded) ? 9 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                            }

                            Repeater {
                                model: [
                                    { label: "󰄜   Отправить на телефон", idx: 0 },
                                    { label: "󰅧   Быстрая ссылка + QR в облако", idx: 1 },
                                    { label: "󰸉   Установить как обои рабочего стола", idx: 2 },
                                    { label: "󰆏   Скопировать путь в буфер обмена", idx: 3 },
                                    { label: "󰉋   Открыть файл в системе", idx: 4 }
                                ]
                                delegate: Rectangle {
                                    x: 0
                                    y: index * (fdItemsArea.btnH + fdItemsArea.gap)
                                    width: fdItemsArea.width
                                    height: fdItemsArea.btnH
                                    readonly property bool isSel: root.fileDropSelectedIndex === modelData.idx
                                    radius: (Theme && Theme.isRounded) ? 9 : 0
                                    color: "transparent"
                                    border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: parent.isSel
                                        color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        Behavior on color { ColorAnimation { duration: 110 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.fileDropSelectedIndex = modelData.idx
                                        onPositionChanged: root.fileDropSelectedIndex = modelData.idx
                                        onClicked: root.executeDroppedFileAction(modelData.idx)
                                    }
                                }
                            }
                        }
                    }
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
                    id: powerMenuBox
                    anchors.fill: parent
                    visible: root.drawerMode === "power"
                    focus: root.drawerOpen && root.drawerMode === "power"
                    Keys.onUpPressed: (event) => { root.powerSelectedIndex = (root.powerSelectedIndex + 5) % 6; event.accepted = true }
                    Keys.onDownPressed: (event) => { root.powerSelectedIndex = (root.powerSelectedIndex + 1) % 6; event.accepted = true }
                    Keys.onReturnPressed: (event) => { root.triggerPowerAction(root.powerSelectedIndex); event.accepted = true }
                    Keys.onEnterPressed: (event) => { root.triggerPowerAction(root.powerSelectedIndex); event.accepted = true }
                    Keys.onEscapePressed: (event) => { root.requestCloseDrawer(); event.accepted = true }

                    onVisibleChanged: {
                        if (visible && root.drawerOpen) Qt.callLater(() => powerMenuBox.forceActiveFocus())
                    }
                    Connections {
                        target: root
                        function onDrawerOpenChanged() {
                            if (root.drawerOpen && root.drawerMode === "power") {
                                Qt.callLater(() => powerMenuBox.forceActiveFocus())
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Text { text: "Power Menu"; color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 2 }

                        Item {
                            id: powerItemsArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property int itemCount: 6
                            readonly property real gap: 6
                            readonly property real btnH: Math.max(28, (height - gap * (itemCount - 1)) / itemCount)

                            Rectangle {
                                id: powerSlidePill
                                x: 0
                                y: root.powerSelectedIndex * (powerItemsArea.btnH + powerItemsArea.gap)
                                width: powerItemsArea.width
                                height: powerItemsArea.btnH
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                Behavior on radius { NumberAnimation { duration: 150 } }
                            }

                            Repeater {
                                id: powerRepeater
                                model: [
                                    { label: "󰌾   Lock", idx: 0 },
                                    { label: "󰒲   Sleep", idx: 1 },
                                    { label: "󰤄   Hibernate", idx: 2 },
                                    { label: "󰍃   Logout", idx: 3 },
                                    { label: "󰜉   Reboot", idx: 4 },
                                    { label: "⏻   Shutdown", idx: 5 }
                                ]
                                delegate: Rectangle {
                                    x: 0
                                    y: index * (powerItemsArea.btnH + powerItemsArea.gap)
                                    width: powerItemsArea.width
                                    height: powerItemsArea.btnH
                                    property bool isSel: root.powerSelectedIndex === modelData.idx
                                    radius: (Theme && Theme.isRounded) ? 10 : 0
                                    color: "transparent"
                                    border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.16)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.bold: parent.isSel
                                        color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    MouseArea {
                                        id: pmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: root.powerSelectedIndex = modelData.idx
                                        onPositionChanged: root.powerSelectedIndex = modelData.idx
                                        onClicked: root.triggerPowerAction(modelData.idx)
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. БУФЕР ОБМЕНА (С ПЛАВНОЙ СКОЛЬЗЯЩЕЙ ПЛАШКОЙ НАВЕДЕНИЯ)
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
                        Item {
                            id: clipListArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            property bool isHovering: false
                            property int hoveredIndex: -1
                            property real hovY: 0
                            property real hovH: 32

                            Timer {
                                id: clipHoverHold
                                interval: 45
                                onTriggered: {
                                    clipListArea.isHovering = false
                                    clipListArea.hoveredIndex = -1
                                }
                            }

                            // Плавно скользящая за мышью плашка наведения
                            Rectangle {
                                id: clipSlidePill
                                z: 1
                                opacity: clipListArea.isHovering ? 1.0 : 0.0
                                x: 0
                                y: clipListArea.hovY - clipPopupList.contentY
                                width: clipPopupList.width
                                height: clipListArea.hovH
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                Behavior on height { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            ListView {
                                id: clipPopupList
                                z: 2
                                anchors.fill: parent
                                clip: true
                                spacing: 5
                                cacheBuffer: 160
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                model: {
                                    if (!root.drawerActive || root.drawerMode !== "clipboard" || !Waybar) return []
                                    var raw = Waybar.clipboardItems || []
                                    var q = root.clipSearchQuery.trim()
                                    if (q.length === 0) return raw
                                    var filtered = []
                                    for (var i = 0; i < raw.length; ++i) {
                                        if ((raw[i].label || "").toLowerCase().indexOf(q) !== -1) filtered.push(raw[i])
                                    }
                                    return filtered
                                }

                                delegate: Rectangle {
                                    id: clipDelRect
                                    readonly property bool isHov: clipListArea.isHovering && clipListArea.hoveredIndex === index
                                    width: ListView.view.width
                                    height: modelData.isImage ? 54 : 32
                                    radius: (Theme && Theme.isRounded) ? 8 : 0
                                    color: "transparent"
                                    border.color: isHov ? "transparent" : Qt.rgba(1, 1, 1, 0.16)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                                        Text {
                                            text: modelData.label
                                            color: clipDelRect.isHov ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                            Behavior on color { ColorAnimation { duration: 110 } }
                                            font.pixelSize: 11
                                            font.bold: clipDelRect.isHov
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
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
                                        id: clipItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        function syncHover() {
                                            clipHoverHold.stop()
                                            clipListArea.hovY = clipDelRect.y
                                            clipListArea.hovH = clipDelRect.height
                                            clipListArea.hoveredIndex = index
                                            clipListArea.isHovering = true
                                        }
                                        onEntered: syncHover()
                                        onPositionChanged: syncHover()
                                        onExited: clipHoverHold.restart()
                                        onClicked: {
                                            if (Waybar) Waybar.selectClipboardItem(modelData.index)
                                            root.drawerOpen = false
                                        }
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

                // 3b. КОМПАКТНОЕ ОКНО ЗВУКА И МИКШЕРА ПРИЛОЖЕНИЙ
                Item {
                    id: volumePopupBox
                    anchors.fill: parent
                    visible: root.drawerMode === "volume"
                    property bool anyStreamSliderPressed: false

                    Timer {
                        interval: 1800
                        repeat: true
                        running: root.drawerOpen && root.drawerMode === "volume" && !volumePopupBox.anyStreamSliderPressed && !masterVolSlider.pressed
                        onTriggered: if (Waybar) Waybar.refreshAudioStreams()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "󰕾  Громкость и микшер"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "󰒓 Настройки"
                                implicitHeight: 22
                                onClicked: root.openDrawerWithMode("settings", 5)
                            }
                        }

                        // Карточка общей системной громкости
                        GlassPanel {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: (Theme && Theme.isRounded) ? 10 : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                StyledButton {
                                    text: (Waybar && Waybar.muted) ? "󰝟" : "󰕾"
                                    isIconOnly: true
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    isActive: Waybar ? !Waybar.muted : true
                                    onClicked: if (Waybar) Waybar.toggleMute()
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "Общая громкость"
                                            color: "#dddddd"
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: (Waybar && Waybar.muted) ? "Mute" : ((Waybar ? Waybar.volume : 50) + "%")
                                            color: (Waybar && Waybar.muted) ? "#ff6b6b" : (Config ? Config.m3Primary : "#ffffff")
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                    StyledSlider {
                                        id: masterVolSlider
                                        Layout.fillWidth: true
                                        from: 0; to: 100; stepSize: 1
                                        Component.onCompleted: if (Waybar) value = Waybar.volume
                                        Connections {
                                            target: Waybar
                                            function onAudioChanged() {
                                                if (!masterVolSlider.pressed && Waybar) masterVolSlider.value = Waybar.volume
                                            }
                                        }
                                        onMoved: if (Waybar) Waybar.setVolumeExact(Math.round(value))
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Приложения • " + (Waybar ? Waybar.audioStreams.length : 0)
                                color: "#aaaaaa"
                                font.pixelSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "󰑐"
                                isIconOnly: true
                                implicitWidth: 22; implicitHeight: 22
                                onClicked: if (Waybar) Waybar.refreshAudioStreams()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                visible: !Waybar || Waybar.audioStreams.length === 0
                                anchors.centerIn: parent
                                text: "Нет активных аудио-потоков приложений"
                                color: "#777777"
                                font.pixelSize: 11
                            }

                            ListView {
                                anchors.fill: parent
                                clip: true
                                spacing: 6
                                visible: Waybar && Waybar.audioStreams.length > 0
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                model: (root.drawerActive && root.drawerMode === "volume" && Waybar) ? Waybar.audioStreams.length : 0

                                delegate: GlassPanel {
                                    readonly property var streamData: (Waybar && index < Waybar.audioStreams.length)
                                                                      ? Waybar.audioStreams[index]
                                                                      : ({ id: -1, name: "", subtitle: "", volume: 100, muted: false })
                                    width: ListView.view.width
                                    implicitHeight: 52
                                    height: 52
                                    radius: (Theme && Theme.isRounded) ? 10 : 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        StyledButton {
                                            text: streamData.muted ? "󰝟" : "󰕾"
                                            isIconOnly: true
                                            implicitWidth: 28; implicitHeight: 28
                                            isActive: !streamData.muted
                                            onClicked: if (Waybar && streamData.id >= 0) Waybar.toggleStreamMute(streamData.id)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    text: streamData.name + (streamData.subtitle && streamData.subtitle.length > 0 ? (" — " + streamData.subtitle) : "")
                                                    color: "#ffffff"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: streamData.muted ? "Mute" : (Math.round(appVolSlider.value) + "%")
                                                    color: streamData.muted ? "#ff6b6b" : (Config ? Config.m3Primary : "#cccccc")
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                            StyledSlider {
                                                id: appVolSlider
                                                Layout.fillWidth: true
                                                from: 0; to: 100; stepSize: 1
                                                property double lastUserMoveMs: 0
                                                Component.onCompleted: value = streamData.volume
                                                Connections {
                                                    target: Waybar
                                                    function onAudioStreamsChanged() {
                                                        if (!appVolSlider.pressed && (Date.now() - appVolSlider.lastUserMoveMs > 900)) {
                                                            appVolSlider.value = streamData.volume
                                                        }
                                                    }
                                                }
                                                onPressedChanged: {
                                                    volumePopupBox.anyStreamSliderPressed = pressed
                                                    if (!pressed) lastUserMoveMs = Date.now()
                                                }
                                                onMoved: {
                                                    lastUserMoveMs = Date.now()
                                                    if (Waybar && streamData.id >= 0) Waybar.setStreamVolume(streamData.id, Math.round(value))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3c. КОМПАКТНОЕ ОКНО BLUETOOTH
                Item {
                    id: bluetoothPopupBox
                    anchors.fill: parent
                    visible: root.drawerMode === "bluetooth"

                    Timer {
                        interval: 3000
                        repeat: true
                        running: root.drawerOpen && root.drawerMode === "bluetooth"
                        onTriggered: if (Bluetooth && !Bluetooth.scanning) Bluetooth.refresh()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: "󰂯  Bluetooth"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: (Bluetooth && Bluetooth.scanning) ? "󰑐 Поиск..." : "󰍉 Поиск"
                                implicitHeight: 22
                                isActive: Bluetooth && Bluetooth.scanning
                                onClicked: if (Bluetooth) Bluetooth.scanDevices()
                            }
                            StyledButton {
                                text: "󰒓"
                                isIconOnly: true
                                implicitWidth: 24; implicitHeight: 22
                                onClicked: root.openDrawerWithMode("settings", 7)
                            }
                        }

                        GlassPanel {
                            Layout.fillWidth: true
                            implicitHeight: 64
                            radius: (Theme && Theme.isRounded) ? 10 : 0

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12
                                anchors.topMargin: 6; anchors.bottomMargin: 6
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Адаптер Bluetooth"
                                        color: "#ffffff"
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledSwitch {
                                        checked: Bluetooth ? Bluetooth.powered : false
                                        onToggled: if (Bluetooth) Bluetooth.powered = checked
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Автоподключение к наушникам"
                                        color: "#aaaaaa"
                                        font.pixelSize: 10
                                        Layout.fillWidth: true
                                    }
                                    StyledSwitch {
                                        checked: Bluetooth ? Bluetooth.autoConnect : true
                                        onToggled: if (Bluetooth) Bluetooth.autoConnect = checked
                                    }
                                }
                            }
                        }

                        Text {
                            visible: Bluetooth && Bluetooth.powered && (!Bluetooth.devices || Bluetooth.devices.length === 0)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Нет обнаруженных устройств"
                            color: "#777777"
                            font.pixelSize: 11
                        }

                        ListView {
                            visible: Bluetooth && Bluetooth.powered && Bluetooth.devices && Bluetooth.devices.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 5
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            model: (root.drawerActive && root.drawerMode === "bluetooth" && Bluetooth) ? Bluetooth.devices : []

                            delegate: GlassPanel {
                                width: ListView.view.width
                                height: 42
                                implicitHeight: 42
                                radius: (Theme && Theme.isRounded) ? 8 : 0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.isAudio ? "󰋋" : (modelData.connected ? "󰂱" : "󰂯")
                                        color: modelData.connected ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                                        font.pixelSize: 14
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        RowLayout {
                                            spacing: 6
                                            Text {
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: 11
                                                font.bold: modelData.connected
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                visible: modelData.battery !== undefined && modelData.battery >= 0
                                                text: "󰁹 " + modelData.battery + "%"
                                                color: Config ? Config.m3Primary : "#69f0ae"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                        Text {
                                            text: modelData.connected ? "Подключено" : (modelData.paired ? "Сопряжено" : modelData.mac)
                                            color: modelData.connected ? "#69f0ae" : "#777777"
                                            font.pixelSize: 9
                                        }
                                    }

                                    StyledButton {
                                        text: modelData.connected ? "Откл." : "Подкл."
                                        implicitHeight: 22
                                        isActive: modelData.connected
                                        onClicked: if (Bluetooth) Bluetooth.toggleConnect(modelData.mac, modelData.connected)
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
                    clip: pageController.inTransition || pageController.currentIndex !== 0
                    layer.enabled: root.anyModalActive && Config && Config.dialogBlur > 0.01
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property var source: scaledRoot
                        property vector2d u_resolution: Qt.vector2d(Math.max(1, scaledRoot.width), Math.max(1, scaledRoot.height))
                        property real u_blur: Config ? Config.dialogBlur : 0.65
                        fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                    }
                    Item {
                    id: pageController
                    anchors.fill: parent
                    clip: pageController.inTransition || pageController.currentIndex !== 0

                    property int currentIndex: 0
                    property int previousIndex: 0
                    property bool inTransition: false
                    property int sidebarW: sidebar.width

                    onCurrentIndexChanged: {
                        root.syncWallpapersModeState()
                    }

                    function basePageX(idx) { return idx === 0 ? 0 : sidebarW }
                    function basePageW(idx) { return idx === 0 ? pageController.width : (pageController.width - sidebarW) }

                    property bool suppressCleanup: false
                    function stopAllTransitions() {
                        suppressCleanup = true
                        pageSlideAnim.stop()
                        pageFadeAnim.stop()
                        depthTransition.stop()
                        bounceTransition.stop()
                        vortexTransition.stop()
                        blackholeTransition.stop()
                        portalTransition.stop()
                        shatterTransition.stop()
                        suppressCleanup = false
                    }

                    function jumpToPageInstant(targetIdx) {
                        stopAllTransitions()
                        inTransition = false
                        for (var i = 0; i < pageRepeater.count; ++i) {
                            var p = pageRepeater.itemAt(i)
                            if (p) {
                                p.visible = (i === targetIdx)
                                p.opacity = (i === targetIdx) ? 1.0 : 0.0
                                p.x = Qt.binding(function() { return i === 0 ? 0 : pageController.sidebarW })
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
                            newPage.x = Qt.binding(function() { return newIdx === 0 ? 0 : pageController.sidebarW })
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
                        previousIndex = currentIndex
                        currentIndex = targetIdx
                        inTransition = true
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
                        if (suppressCleanup) return
                        var pIdx = pageController.previousIndex
                        var cIdx = pageController.currentIndex
                        var p = pageRepeater.itemAt(pIdx)
                        if (p && pIdx !== cIdx) {
                            p.visible = false
                            p.x = Qt.binding(function() { return pIdx === 0 ? 0 : pageController.sidebarW })
                            p.y = 0
                            p.scale = 1.0
                            p.rotation = 0
                            p.opacity = 0.0
                            p.vortexProgress = 0.0
                        }
                        var cur = pageRepeater.itemAt(cIdx)
                        if (cur) {
                            cur.visible = true
                            cur.x = Qt.binding(function() { return cIdx === 0 ? 0 : pageController.sidebarW })
                            cur.y = 0
                            cur.scale = 1.0
                            cur.rotation = 0
                            cur.opacity = 1.0
                            cur.vortexProgress = 0.0
                        }
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
                            "views/MusicView.qml",
                            "views/TimerView.qml",
                            "views/BackupView.qml",
                            "views/PhoneBridgeView.qml"
                        ]

                        Loader {
                            id: pageLoader
                            z: (pageController.inTransition && index === pageController.previousIndex) ? 2 : 1
                            x: index === 0 ? 0 : pageController.sidebarW
                            width: index === 0 ? pageController.width : (pageController.width - pageController.sidebarW)
                            height: pageController.height
                            active: index === 0 || (root.drawerActive && root.drawerMode === "settings" && (
                                    index === pageController.currentIndex ||
                                    (pageController.inTransition && index === pageController.previousIndex)))
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
                                property var source: pageLoader
                                property vector2d u_resolution: Qt.vector2d(pageLoader.width, pageLoader.height)
                                property real u_progress: pageLoader.vortexProgress
                                property real u_direction: pageLoader.vortexDir
                                property real u_mode: pageLoader.vortexMode
                                fragmentShader: "qrc:/shaders/qml/shaders/vortex_suck.frag.qsb"
                            }

                            onLoaded: {
                                if ((index === 0 || index === 12 || index === 16) && item && item.focusSearchInput && index === pageController.currentIndex) Qt.callLater(item.focusSearchInput)
                                if (index === 0 && item) {
                                    item.navigateTo.connect((target) => pageController.switchPage(target))
                                }
                            }
                        }
                    }
                }

                Sidebar {
                    id: sidebar
                    height: parent.height
                    property bool showBar: pageController.currentIndex > 0 && !(blackholeTransition.running && pageController.previousIndex === 0 && bhInOp.target && bhInOp.target.opacity < 0.05)
                    x: showBar ? 0 : -width
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
                    property real u_cursor_strength: 0.0
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

                // Мастер первоначальной настройки при первом запуске (First-Run Setup Wizard)
                Rectangle {
                    visible: root.setupWizardOpen
                    anchors.fill: parent
                    z: 995
                    color: Qt.rgba(0, 0, 0, 0.62)

                    MouseArea { anchors.fill: parent; onClicked: {} }

                    GlassPanel {
                        anchors.centerIn: parent
                        width: 480
                        implicitHeight: wizCol.implicitHeight + 32
                        radius: (Theme && Theme.isRounded) ? 16 : 0

                        property bool dlWallsOnStart: true

                        ColumnLayout {
                            id: wizCol
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: "🚀  Добро пожаловать в HySett!"
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Выберите рабочие папки и параметры оформления перед началом работы:"
                                color: "#bbbbbb"
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Стиль оформления:"; color: "#cccccc"; font.pixelSize: 11; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 220
                                    options: ["Квадратный", "Скругленный"]
                                    selectedIndex: (Theme && Theme.isRounded) ? 1 : 0
                                    onSelected: (idx) => { if (Theme) Theme.setRoundedState(idx === 1) }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Папка обоев:"; color: "#aaaaaa"; font.pixelSize: 10 }
                                TextField {
                                    id: wizWallDir
                                    Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                                    color: "#ffffff"; font.pixelSize: 11
                                    text: Config ? Config.wallpapersDir : "/home/whrr/Pictures/Wallpapers"
                                    background: Rectangle { radius: (Theme && Theme.isRounded) ? 8 : 0; color: Qt.rgba(1,1,1,0.08); border.color: Qt.rgba(1,1,1,0.16) }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Папка музыки (Яндекс.Музыка):"; color: "#aaaaaa"; font.pixelSize: 10 }
                                TextField {
                                    id: wizMusDir
                                    Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                                    color: "#ffffff"; font.pixelSize: 11
                                    text: Config ? Config.musicDir : "/home/whrr/Music/YandexMusic"
                                    background: Rectangle { radius: (Theme && Theme.isRounded) ? 8 : 0; color: Qt.rgba(1,1,1,0.08); border.color: Qt.rgba(1,1,1,0.16) }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Папка для архивов бэкапа:"; color: "#aaaaaa"; font.pixelSize: 10 }
                                TextField {
                                    id: wizBakDir
                                    Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                                    color: "#ffffff"; font.pixelSize: 11
                                    text: Config ? Config.backupsDir : "/home/whrr/hysett/backups/archives"
                                    background: Rectangle { radius: (Theme && Theme.isRounded) ? 8 : 0; color: Qt.rgba(1,1,1,0.08); border.color: Qt.rgba(1,1,1,0.16) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Скачать обои по умолчанию с GitHub в фоне:"
                                    color: "#cccccc"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap
                                }
                                StyledSwitch {
                                    id: wizDlSwitch
                                    checked: true
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 8
                                StyledButton {
                                    text: "Отмена"
                                    visible: Config ? Config.firstRunCompleted : false
                                    onClicked: root.setupWizardOpen = false
                                }
                                StyledButton {
                                    text: "✓ Сохранить и начать"
                                    isActive: true
                                    onClicked: {
                                        if (Config) {
                                            Config.completeFirstRunSetup(wizWallDir.text, wizMusDir.text, wizBakDir.text, wizDlSwitch.checked)
                                        }
                                        if (Wallpapers) Wallpapers.reloadWallpapers()
                                        root.setupWizardOpen = false
                                    }
                                }
                            }
                        }
                    }
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
                                    text: "Сохранить"
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
