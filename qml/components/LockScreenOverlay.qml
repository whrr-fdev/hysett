import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett

FocusScope {
    id: lockRoot
    anchors.fill: parent
    visible: active || unlockAnim.running
    focus: active
    z: 99999

    property bool active: false
    property bool editMode: false
    property bool checkingAuth: false
    property string passwordText: ""
    property bool showPlainPassword: false
    property string errorText: ""
    property int failedAttempts: 0
    property real revealProgress: 0.0
    property real widgetsEnterProgress: 0.0
    property real shakeOffset: 0.0

    property bool powerMenuOpen: false
    property int powerSelectedIndex: 0
    property int focusGrabTicks: 0

    property real bgBlurStrength: 0.62
    property real bgDimStrength: 0.38
    property int clockFontSize: 78
    property bool clockShowSeconds: true
    property string customGreeting: "Привет, Whrr!"

    property var seenNotifIds: ({})
    property int totalLockedNotifs: 0
    ListModel { id: lockedNotifsModel }

    readonly property var lockPowerActions: [
        { icon: "󰒲", label: "Sleep",     act: 1 },
        { icon: "󰤄", label: "Hibernate", act: 2 },
        { icon: "󰍃", label: "Logout",    act: 3 },
        { icon: "󰜉", label: "Reboot",    act: 4 },
        { icon: "⏻", label: "Shutdown",  act: 5 }
    ]

    function triggerLockPowerAction(act) {
        lockRoot.powerMenuOpen = false
        ensureFocus()
        if (!Waybar) return
        if (act === 1) Waybar.runCommand("sleep 0.15 && systemctl suspend && sleep 1.0 && /home/whrr/.config/hypr/scripts/resume_restore.sh")
        else if (act === 2) Waybar.runCommand("sleep 0.15 && systemctl hibernate && sleep 1.0 && /home/whrr/.config/hypr/scripts/resume_restore.sh")
        else if (act === 3) Waybar.runCommand("hyprshutdown --post-cmd \"bash -c 'pkill -KILL -u $(whoami)'\"")
        else if (act === 4) Waybar.runCommand("systemctl reboot")
        else if (act === 5) Waybar.runCommand("systemctl poweroff")
    }

    property var widgetsCfg: ({
        "clock":         { enabled: true,  nx: 0.50, ny: 0.25, title: "Часы и дата" },
        "greeting":      { enabled: true,  nx: 0.50, ny: 0.39, title: "Приветствие" },
        "password":      { enabled: true,  nx: 0.50, ny: 0.50, title: "Поле пароля" },
        "status":        { enabled: true,  nx: 0.50, ny: 0.59, title: "Раскладка и гео" },
        "notifications": { enabled: true,  nx: 0.50, ny: 0.71, title: "Скрытые уведомления" },
        "media":         { enabled: true,  nx: 0.50, ny: 0.85, title: "Музыкальный плеер" },
        "weather":       { enabled: true,  nx: 0.12, ny: 0.08, title: "Погода" },
        "sysinfo":       { enabled: true,  nx: 0.88, ny: 0.08, title: "Система CPU/RAM" },
        "power":         { enabled: true,  nx: 0.95, ny: 0.92, title: "Меню питания" }
    })

    function defaultWidgetsCfg() {
        return {
            "clock":         { enabled: true,  nx: 0.50, ny: 0.25, title: "Часы и дата" },
            "greeting":      { enabled: true,  nx: 0.50, ny: 0.39, title: "Приветствие" },
            "password":      { enabled: true,  nx: 0.50, ny: 0.50, title: "Поле пароля" },
            "status":        { enabled: true,  nx: 0.50, ny: 0.59, title: "Раскладка и гео" },
            "notifications": { enabled: true,  nx: 0.50, ny: 0.71, title: "Скрытые уведомления" },
            "media":         { enabled: true,  nx: 0.50, ny: 0.85, title: "Музыкальный плеер" },
            "weather":       { enabled: true,  nx: 0.12, ny: 0.08, title: "Погода" },
            "sysinfo":       { enabled: true,  nx: 0.88, ny: 0.08, title: "Система CPU/RAM" },
            "power":         { enabled: true,  nx: 0.95, ny: 0.92, title: "Меню питания" }
        }
    }

    function ensureFocus() {
        if (!lockRoot.active) return
        if (ApplicationWindow.window) ApplicationWindow.window.requestActivate()
        lockRoot.forceActiveFocus()
        lockKeyCatcher.forceActiveFocus()
    }

    Window.onActiveChanged: {
        if (lockRoot.active && Window.active) {
            lockRoot.ensureFocus()
        }
    }

    Timer {
        id: fastFocusTimer
        interval: 35
        repeat: true
        running: lockRoot.active && lockRoot.focusGrabTicks < 16
        onTriggered: {
            lockRoot.focusGrabTicks += 1
            lockRoot.ensureFocus()
        }
    }

    function pluralNotif(n) {
        var m10 = n % 10
        var m100 = n % 100
        if (m10 === 1 && m100 !== 11) return n + " уведомление"
        if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return n + " уведомления"
        return n + " уведомлений"
    }

    function ingestMakoNotifications() {
        if (!lockRoot.active || !Mako) return
        var lists = [Mako.activePopups || [], Mako.history || []]
        for (var li = 0; li < lists.length; ++li) {
            var arr = lists[li]
            for (var i = 0; i < arr.length; ++i) {
                var it = arr[i]
                var nid = String(it.id !== undefined ? it.id : "")
                if (nid.length === 0 || lockRoot.seenNotifIds[nid]) continue
                lockRoot.seenNotifIds[nid] = true

                var app = String(it.appName || it.app_name || it.app || "").trim()
                if (app.length === 0 || app === "notify-send") {
                    var sum = String(it.summary || "").trim()
                    app = sum.length > 0 ? sum.split(" ")[0] : "Система"
                }

                var foundIdx = -1
                for (var k = 0; k < lockedNotifsModel.count; ++k) {
                    if (lockedNotifsModel.get(k).appSource === app) {
                        foundIdx = k
                        break
                    }
                }
                if (foundIdx >= 0) {
                    var curCnt = lockedNotifsModel.get(foundIdx).count + 1
                    lockedNotifsModel.setProperty(foundIdx, "count", curCnt)
                } else {
                    lockedNotifsModel.insert(0, { "appSource": app, "count": 1 })
                }
                lockRoot.totalLockedNotifs += 1
            }
        }
        if (!lockRoot.editMode && Mako.activePopups && Mako.activePopups.length > 0) {
            Qt.callLater(() => {
                if (lockRoot.active && !lockRoot.editMode && Mako) Mako.dismissAll()
            })
        }
    }

    function loadConfig() {
        if (!Waybar) return
        var raw = Waybar.lockScreenConfigJson
        if (!raw || raw.length === 0) return
        try {
            var d = JSON.parse(raw)
            if (d.bgBlurStrength !== undefined) bgBlurStrength = d.bgBlurStrength
            if (d.bgDimStrength !== undefined) bgDimStrength = d.bgDimStrength
            if (d.clockFontSize !== undefined) clockFontSize = d.clockFontSize
            if (d.clockShowSeconds !== undefined) clockShowSeconds = d.clockShowSeconds
            if (d.customGreeting !== undefined) customGreeting = d.customGreeting
            if (d.widgets) {
                var def = defaultWidgetsCfg()
                for (var k in def) {
                    if (d.widgets[k]) {
                        def[k].enabled = (d.widgets[k].enabled !== undefined) ? d.widgets[k].enabled : def[k].enabled
                        def[k].nx = (d.widgets[k].nx !== undefined) ? d.widgets[k].nx : def[k].nx
                        def[k].ny = (d.widgets[k].ny !== undefined) ? d.widgets[k].ny : def[k].ny
                    }
                }
                widgetsCfg = def
            }
        } catch (e) {}
    }

    onBgBlurStrengthChanged: if (active && Theme) Theme.applyEffectiveBlur(Math.max(0.12, bgBlurStrength))

    function saveConfig() {
        if (!Waybar) return
        var obj = {
            bgBlurStrength: bgBlurStrength,
            bgDimStrength: bgDimStrength,
            clockFontSize: clockFontSize,
            clockShowSeconds: clockShowSeconds,
            customGreeting: customGreeting,
            widgets: widgetsCfg
        }
        Waybar.saveLockScreenConfig(JSON.stringify(obj, null, 2))
    }

    function resetLayout() {
        widgetsCfg = defaultWidgetsCfg()
        bgBlurStrength = 0.62
        bgDimStrength = 0.38
        clockFontSize = 78
        clockShowSeconds = true
        saveConfig()
    }

    function setWidgetPos(key, nx, ny) {
        var copy = JSON.parse(JSON.stringify(widgetsCfg))
        if (!copy[key]) return
        copy[key].nx = Math.max(0.03, Math.min(0.97, nx))
        copy[key].ny = Math.max(0.04, Math.min(0.96, ny))
        widgetsCfg = copy
        saveConfig()
    }

    function setWidgetEnabled(key, en) {
        var copy = JSON.parse(JSON.stringify(widgetsCfg))
        if (!copy[key]) return
        copy[key].enabled = en
        widgetsCfg = copy
        saveConfig()
    }

    function lockNow(openInEditMode) {
        var wantEdit = (openInEditMode === true)
        if (active && !unlockAnim.running && editMode === wantEdit) {
            focusGrabTicks = 0
            ensureFocus()
            return
        }
        loadConfig()
        if (Waybar) Waybar.prepareLockScreenBg()
        passwordText = ""
        charDotCounts = []
        pendingDotsToSpawn = 0
        errorText = ""
        checkingAuth = false
        powerMenuOpen = false
        powerSelectedIndex = 0
        editMode = wantEdit
        dotsModel.clear()

        var initSeen = {}
        if (Mako) {
            var h = Mako.history || []
            for (var i = 0; i < h.length; ++i) {
                if (h[i].id !== undefined) initSeen[String(h[i].id)] = true
            }
            var ap = Mako.activePopups || []
            for (var j = 0; j < ap.length; ++j) {
                if (ap[j].id !== undefined) initSeen[String(ap[j].id)] = true
            }
            if (!editMode && ap.length > 0) Mako.dismissAll()
        }
        seenNotifIds = initSeen
        totalLockedNotifs = 0
        lockedNotifsModel.clear()

        active = true
        focusGrabTicks = 0
        if (Theme) {
            Theme.applyEffectiveXray(true)
            Theme.applyEffectiveBlur(Math.max(0.12, lockRoot.bgBlurStrength))
        }
        ingestMakoNotifications()
        unlockAnim.stop()
        lockInAnim.restart()
        ensureFocus()
        Qt.callLater(ensureFocus)
    }

    function unlockNow() {
        editMode = false
        checkingAuth = false
        powerMenuOpen = false
        // Мгновенно возвращаем маску ввода, режим xray и фокус рабочему столу в начале анимации разблокировки
        if (Waybar) Waybar.setLockScreenLayer(ApplicationWindow.window, false)
        if (Theme) {
            Theme.applyEffectiveXray(Theme.windowXray)
            Theme.applyEffectiveBlur(Theme.windowBlur)
        }
        unlockAnim.restart()
    }

    Connections {
        target: Mako
        function onPopupChanged() {
            if (lockRoot.active) lockRoot.ingestMakoNotifications()
        }
    }

    Connections {
        target: Waybar
        function onLockConfigChanged() {
            if (!lockRoot.active) lockRoot.loadConfig()
        }
        function onLockAuthResult(success, errorMsg) {
            if (!lockRoot.active) return
            lockRoot.checkingAuth = false
            if (success) {
                lockRoot.unlockNow()
            } else {
                lockRoot.failedAttempts += 1
                lockRoot.errorText = errorMsg + " (" + lockRoot.failedAttempts + ")"
                lockRoot.clearPasswordAnimated()
                shakeAnim.restart()
                lockRoot.ensureFocus()
            }
        }
    }

    Component.onCompleted: loadConfig()

    ParallelAnimation {
        id: lockInAnim
        NumberAnimation {
            target: lockRoot
            property: "revealProgress"
            from: 0.0; to: 1.0
            duration: 340
            easing.type: Easing.OutQuint
        }
        SequentialAnimation {
            PauseAnimation { duration: 45 }
            NumberAnimation {
                target: lockRoot
                property: "widgetsEnterProgress"
                from: 0.0; to: 1.0
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.32
            }
        }
    }

    SequentialAnimation {
        id: unlockAnim
        ParallelAnimation {
            NumberAnimation {
                target: lockRoot
                property: "revealProgress"
                to: 0.0
                duration: 220
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: lockRoot
                property: "widgetsEnterProgress"
                to: 1.08
                duration: 220
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                lockRoot.active = false
                lockRoot.widgetsEnterProgress = 0.0
                lockRoot.passwordText = ""
                dotsModel.clear()
                if (Waybar) Waybar.setLockScreenLayer(ApplicationWindow.window, false)
                if (Theme) {
                    Theme.applyEffectiveXray(Theme.windowXray)
                    Theme.applyEffectiveBlur(Theme.windowBlur)
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: lockRoot; property: "shakeOffset"; to: -16; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: lockRoot; property: "shakeOffset"; to: 16;  duration: 75; easing.type: Easing.InOutSine }
        NumberAnimation { target: lockRoot; property: "shakeOffset"; to: -11; duration: 65; easing.type: Easing.InOutSine }
        NumberAnimation { target: lockRoot; property: "shakeOffset"; to: 8;   duration: 55; easing.type: Easing.InOutSine }
        NumberAnimation { target: lockRoot; property: "shakeOffset"; to: 0;   duration: 50; easing.type: Easing.OutBack }
    }

    ListModel { id: dotsModel }
    property var charDotCounts: []
    property int pendingDotsToSpawn: 0

    Timer {
        id: staggeredDotTimer
        interval: 42
        repeat: true
        running: lockRoot.pendingDotsToSpawn > 0
        onTriggered: {
            if (lockRoot.pendingDotsToSpawn > 0) {
                lockRoot.pendingDotsToSpawn -= 1
                dotsModel.append({ "closing": false })
            }
        }
    }

    function appendPasswordChar(ch) {
        if (checkingAuth || editMode) return
        if (powerMenuOpen) powerMenuOpen = false
        errorText = ""
        passwordText += ch
        var countForKey = 2 + Math.floor(Math.random() * 3)
        var arr = charDotCounts.slice()
        arr.push(countForKey)
        charDotCounts = arr

        dotsModel.append({ "closing": false })
        pendingDotsToSpawn += (countForKey - 1)
    }

    function popPasswordChar() {
        if (checkingAuth || editMode || passwordText.length === 0) return
        passwordText = passwordText.slice(0, -1)
        var arr = charDotCounts.slice()
        var toRemove = arr.length > 0 ? arr.pop() : 1
        charDotCounts = arr

        if (pendingDotsToSpawn > 0) {
            var takePending = Math.min(pendingDotsToSpawn, toRemove)
            pendingDotsToSpawn -= takePending
            toRemove -= takePending
        }

        for (var i = dotsModel.count - 1; i >= 0 && toRemove > 0; --i) {
            if (!dotsModel.get(i).closing) {
                dotsModel.setProperty(i, "closing", true)
                toRemove -= 1
            }
        }
    }

    function clearPasswordAnimated() {
        passwordText = ""
        charDotCounts = []
        pendingDotsToSpawn = 0
        for (var i = 0; i < dotsModel.count; ++i) {
            dotsModel.setProperty(i, "closing", true)
        }
    }

    function submitPassword() {
        if (checkingAuth || editMode) return
        if (passwordText.length === 0) {
            shakeAnim.restart()
            return
        }
        checkingAuth = true
        errorText = ""
        if (Waybar) Waybar.verifyLockPassword(passwordText)
    }

    Item {
        id: lockKeyCatcher
        focus: true
        Keys.onPressed: (event) => {
            if (!lockRoot.active) return
            if (lockRoot.powerMenuOpen) {
                if (event.key === Qt.Key_Escape) {
                    lockRoot.powerMenuOpen = false
                    event.accepted = true
                    return
                } else if (event.key === Qt.Key_Up) {
                    lockRoot.powerSelectedIndex = (lockRoot.powerSelectedIndex + lockRoot.lockPowerActions.length - 1) % lockRoot.lockPowerActions.length
                    event.accepted = true
                    return
                } else if (event.key === Qt.Key_Down) {
                    lockRoot.powerSelectedIndex = (lockRoot.powerSelectedIndex + 1) % lockRoot.lockPowerActions.length
                    event.accepted = true
                    return
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    var item = lockRoot.lockPowerActions[lockRoot.powerSelectedIndex]
                    if (item) lockRoot.triggerLockPowerAction(item.act)
                    event.accepted = true
                    return
                }
            }
            if (event.key === Qt.Key_Escape && lockRoot.editMode) {
                lockRoot.unlockNow()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                lockRoot.submitPassword()
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (event.modifiers & Qt.ControlModifier) lockRoot.clearPasswordAnimated()
                else lockRoot.popPasswordChar()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                lockRoot.clearPasswordAnimated()
                event.accepted = true
            } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
                lockRoot.clearPasswordAnimated()
                event.accepted = true
            } else if (event.text && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && !(event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier)) {
                lockRoot.appendPasswordChar(event.text)
                event.accepted = true
            }
        }
    }

    Timer {
        interval: 1000
        running: lockRoot.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            lockClockTxt.text = Qt.formatDateTime(now, lockRoot.clockShowSeconds ? "hh:mm:ss" : "hh:mm")
            lockDateTxt.text = Qt.formatDateTime(now, "dddd, d MMMM yyyy")
            if (!lockKeyCatcher.activeFocus) {
                lockRoot.ensureFocus()
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: Math.min(1.0, lockRoot.revealProgress * 1.15)

        // Полупрозрачная вуаль поверх живого xray-блюра обоев Hyprland
        Rectangle {
            id: liveBlurBackdrop
            anchors.fill: parent
            color: Qt.rgba(0.03, 0.04, 0.06, Math.max(0.04, lockRoot.bgDimStrength * lockRoot.revealProgress))
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onClicked: {
                if (lockRoot.powerMenuOpen) lockRoot.powerMenuOpen = false
                lockRoot.ensureFocus()
            }
        }

        // Осевые направляющие (видны только при запуске Полноэкранного редактора из настроек HySett)
        Rectangle {
            visible: lockRoot.editMode
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 1; color: Qt.rgba(1, 1, 1, 0.16)
        }
        Rectangle {
            visible: lockRoot.editMode
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.right: parent.right
            height: 1; color: Qt.rgba(1, 1, 1, 0.16)
        }

        Item {
            anchors.fill: parent
            scale: 0.88 + 0.12 * lockRoot.widgetsEnterProgress
            opacity: Math.max(0.0, Math.min(1.0, lockRoot.widgetsEnterProgress))

            // ==================== ВИДЖЕТ 1: ЧАСЫ И ДАТА ====================
            Item {
                id: wClock
                readonly property var cfg: lockRoot.widgetsCfg["clock"] || { enabled: true, nx: 0.5, ny: 0.25 }
                visible: cfg.enabled
                width: clockCol.implicitWidth + 32
                height: clockCol.implicitHeight + 20
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    visible: lockRoot.editMode
                    radius: 12
                    color: clockDragMa.pressed ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: (Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae"
                }

                Column {
                    id: clockCol
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        id: lockClockTxt
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(new Date(), lockRoot.clockShowSeconds ? "hh:mm:ss" : "hh:mm")
                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                        font.pixelSize: lockRoot.clockFontSize
                        font.bold: true
                        font.letterSpacing: 3
                    }

                    Text {
                        id: lockDateTxt
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                        color: Qt.rgba(0.92, 0.94, 0.98, 0.82)
                        font.pixelSize: 16
                    }
                }

                MouseArea {
                    id: clockDragMa
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wClock.x + (m.x - startX) + wClock.width * 0.5
                        var cy = wClock.y + (m.y - startY) + wClock.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("clock", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 2: ПРИВЕТСТВИЕ ====================
            Item {
                id: wGreeting
                readonly property var cfg: lockRoot.widgetsCfg["greeting"] || { enabled: true, nx: 0.5, ny: 0.39 }
                visible: cfg.enabled
                width: greetRow.implicitWidth + 28
                height: greetRow.implicitHeight + 16
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    visible: lockRoot.editMode
                    radius: 10
                    color: greetDragMa.pressed ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: (Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae"
                }

                Row {
                    id: greetRow
                    anchors.centerIn: parent
                    spacing: 10
                    Image {
                        width: 22; height: 22
                        sourceSize: Qt.size(44, 44)
                        smooth: true
                        anchors.verticalCenter: parent.verticalCenter
                        source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                    }
                    Text {
                        text: lockRoot.customGreeting
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: greetDragMa
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wGreeting.x + (m.x - startX) + wGreeting.width * 0.5
                        var cy = wGreeting.y + (m.y - startY) + wGreeting.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("greeting", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 3: ПЛАВНОЕ ПОЛЕ ВВОДА ПАРОЛЯ ====================
            Item {
                id: wPassword
                readonly property var cfg: lockRoot.widgetsCfg["password"] || { enabled: true, nx: 0.5, ny: 0.50 }
                visible: cfg.enabled
                width: pwCol.implicitWidth + 32
                height: pwCol.implicitHeight + 24
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5 + lockRoot.shakeOffset)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Column {
                    id: pwCol
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: pwPill
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property real contentW: Math.min(340, dotsRow.width)
                        width: Math.max(270, Math.min(440, contentW + 96))
                        height: 50
                        radius: (Theme && Theme.isRounded) ? 25 : 0
                        color: Qt.rgba(0.07, 0.08, 0.11, 0.78)
                        border.width: lockRoot.editMode ? 1.5 : 2
                        border.color: {
                            if (lockRoot.errorText.length > 0) return "#ff5252"
                            if (lockRoot.checkingAuth) return "#ffd54f"
                            if (lockRoot.passwordText.length > 0) return (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                            return Qt.rgba(1, 1, 1, 0.25)
                        }

                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: lockRoot.checkingAuth ? "󰑐" : (lockRoot.errorText.length > 0 ? "󰌾" : "")
                            color: lockRoot.errorText.length > 0
                                   ? "#ff5252"
                                   : ((lockRoot.passwordText.length > 0 && Theme && Theme.isRounded && Config) ? Config.m3Primary : Qt.rgba(1, 1, 1, 0.65))
                            font.pixelSize: 15
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: opacity > 0.01
                            opacity: (lockRoot.passwordText.length === 0 && dotsModel.count === 0) ? 0.55 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            text: lockRoot.checkingAuth ? "Проверка..." : "Введите пароль..."
                            color: "#ffffff"
                            font.pixelSize: 13
                        }

                        // Область с обрезкой (clip: true), чтобы точки никогда не выходили за пределы капсулы
                        Item {
                            id: dotsViewport
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 46
                            anchors.rightMargin: 46
                            anchors.verticalCenter: parent.verticalCenter
                            height: 28
                            clip: true

                            Row {
                                id: dotsRow
                                anchors.verticalCenter: parent.verticalCenter
                                x: width <= dotsViewport.width ? Math.round((dotsViewport.width - width) * 0.5) : (dotsViewport.width - width)
                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                spacing: 0

                                Repeater {
                                    model: dotsModel
                                    delegate: Item {
                                        id: dotSlot
                                        readonly property bool isClosing: model.closing === true
                                        property real animW: 0.0
                                        property real dotSc: 0.0
                                        property real dotOp: 0.0
                                        property real dotY: 7.0

                                        width: animW
                                        height: 24

                                        Component.onCompleted: enterDotAnim.start()

                                        onIsClosingChanged: {
                                            if (isClosing) {
                                                enterDotAnim.stop()
                                                exitDotAnim.start()
                                            }
                                        }

                                        ParallelAnimation {
                                            id: enterDotAnim
                                            NumberAnimation { target: dotSlot; property: "animW"; from: 0.0; to: 15.0; duration: 190; easing.type: Easing.OutQuint }
                                            NumberAnimation { target: dotSlot; property: "dotSc"; from: 0.0; to: 1.0; duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.1 }
                                            NumberAnimation { target: dotSlot; property: "dotOp"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: dotSlot; property: "dotY";  from: 6.0; to: 0.0; duration: 200; easing.type: Easing.OutQuint }
                                        }

                                        SequentialAnimation {
                                            id: exitDotAnim
                                            ParallelAnimation {
                                                NumberAnimation { target: dotSlot; property: "animW"; to: 0.0; duration: 140; easing.type: Easing.OutQuint }
                                                NumberAnimation { target: dotSlot; property: "dotSc"; to: 0.0; duration: 130; easing.type: Easing.InBack }
                                                NumberAnimation { target: dotSlot; property: "dotOp"; to: 0.0; duration: 110; easing.type: Easing.OutQuad }
                                                NumberAnimation { target: dotSlot; property: "dotY";  to: -5.0; duration: 130; easing.type: Easing.OutQuad }
                                            }
                                            ScriptAction {
                                                script: {
                                                    if (index >= 0 && index < dotsModel.count) {
                                                        dotsModel.remove(index)
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: dotSlot.dotY
                                            width: 10; height: 10
                                            radius: (Theme && Theme.isRounded) ? 5 : 1
                                            scale: dotSlot.dotSc
                                            opacity: dotSlot.dotOp
                                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                        }
                                    }
                                }
                            }
                        }

                        // Кнопка отправки справа
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: lockRoot.passwordText.length > 0
                            width: 26; height: 26
                            radius: (Theme && Theme.isRounded) ? 13 : 0
                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                            Text {
                                anchors.centerIn: parent
                                text: "󰁔"
                                color: (Config && Theme && Theme.isRounded) ? Config.accentTextColor : "#000000"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lockRoot.submitPassword()
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lockRoot.errorText.length > 0
                        text: lockRoot.errorText
                        color: "#ff6b6b"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MouseArea {
                    id: pwDragMa
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wPassword.x + (m.x - startX) + wPassword.width * 0.5
                        var cy = wPassword.y + (m.y - startY) + wPassword.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("password", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 4: СТАТУС (РАСКЛАДКА И ГЕО) ====================
            Item {
                id: wStatus
                readonly property var cfg: lockRoot.widgetsCfg["status"] || { enabled: true, nx: 0.5, ny: 0.59 }
                visible: cfg.enabled
                width: statusRow.implicitWidth + 24
                height: 32
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        height: 26
                        width: kbInnerRow.implicitWidth + 22
                        radius: (Theme && Theme.isRounded) ? 8 : 0
                        color: Qt.rgba(0.08, 0.09, 0.12, 0.72)
                        border.width: 1
                        border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                        Row {
                            id: kbInnerRow
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "󰌌"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: kbTxt
                                text: Waybar ? Waybar.kbLayout : "EN"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            enabled: !lockRoot.editMode
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Waybar) Waybar.switchKbLayout()
                                lockRoot.ensureFocus()
                            }
                        }
                    }

                    Rectangle {
                        visible: Waybar && Waybar.netConnected && Waybar.geoLocationText.length > 0
                        height: 26
                        width: lockGeoInnerRow.implicitWidth + 22
                        radius: (Theme && Theme.isRounded) ? 8 : 0
                        color: Qt.rgba(0.08, 0.09, 0.12, 0.72)
                        border.width: 1
                        border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                        Row {
                            id: lockGeoInnerRow
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: "󰇧"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: lockGeoTxt
                                text: (Config && Config.streamerMode) ? "Скрыто" : (Waybar ? Waybar.geoLocationText.replace(/\s*\([^)]*\)/g, "") : "")
                                color: "#dddddd"
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wStatus.x + (m.x - startX) + wStatus.width * 0.5
                        var cy = wStatus.y + (m.y - startY) + wStatus.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("status", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 5: СКРЫТЫЕ УВЕДОМЛЕНИЯ ====================
            Item {
                id: wNotifications
                readonly property var cfg: lockRoot.widgetsCfg["notifications"] || { enabled: true, nx: 0.5, ny: 0.71 }
                readonly property bool hasNotifs: lockRoot.totalLockedNotifs > 0 || lockRoot.editMode
                visible: cfg.enabled && hasNotifs
                width: 340
                height: notifCol.implicitHeight + 24
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    radius: (Theme && Theme.isRounded) ? 14 : 0
                    color: Qt.rgba(0.07, 0.08, 0.11, 0.78)
                    border.width: 1
                    border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                    ColumnLayout {
                        id: notifCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "󰂚"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                                font.pixelSize: 14
                            }
                            Text {
                                text: lockRoot.totalLockedNotifs > 0
                                      ? ("Уведомления (" + lockRoot.totalLockedNotifs + ") • содержимое скрыто")
                                      : "Скрытые уведомления (пример)"
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        Repeater {
                            model: lockRoot.totalLockedNotifs > 0 ? lockedNotifsModel : [{ appSource: "AyuGram", count: 2 }]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.09)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Text {
                                        text: "󰌾"
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: modelData ? modelData.appSource : model.appSource
                                        color: "#eaeaea"
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: lockRoot.pluralNotif(modelData ? modelData.count : model.count)
                                        color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wNotifications.x + (m.x - startX) + wNotifications.width * 0.5
                        var cy = wNotifications.y + (m.y - startY) + wNotifications.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("notifications", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 6: МУЗЫКАЛЬНЫЙ ПЛЕЕР ====================
            Item {
                id: wMedia
                readonly property var cfg: lockRoot.widgetsCfg["media"] || { enabled: true, nx: 0.5, ny: 0.85 }
                readonly property bool hasMedia: (Waybar && Waybar.mediaActive) || lockRoot.editMode
                visible: cfg.enabled && hasMedia
                width: 340
                height: 62
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    radius: (Theme && Theme.isRounded) ? 16 : 0
                    color: Qt.rgba(0.07, 0.08, 0.11, 0.76)
                    border.width: 1
                    border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: (Waybar && Waybar.mediaTrackTitle.length > 0) ? Waybar.mediaTrackTitle : "Музыкальный плеер"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (Waybar && Waybar.mediaTrackArtist.length > 0) ? Waybar.mediaTrackArtist : "MPRIS2"
                                color: "#aaaaaa"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Row {
                            spacing: 10
                            Text {
                                text: "󰒮"
                                color: "#ffffff"; font.pixelSize: 16
                                MouseArea { enabled: !lockRoot.editMode; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { if (Waybar) Waybar.mediaPrev(); lockRoot.ensureFocus() } }
                            }
                            Text {
                                text: (Waybar && Waybar.mediaPlaying) ? "󰏤" : "󰐊"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"; font.pixelSize: 16
                                MouseArea { enabled: !lockRoot.editMode; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { if (Waybar) Waybar.mediaPlayPause(); lockRoot.ensureFocus() } }
                            }
                            Text {
                                text: "󰒭"
                                color: "#ffffff"; font.pixelSize: 16
                                MouseArea { enabled: !lockRoot.editMode; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { if (Waybar) Waybar.mediaNext(); lockRoot.ensureFocus() } }
                            }
                        }
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wMedia.x + (m.x - startX) + wMedia.width * 0.5
                        var cy = wMedia.y + (m.y - startY) + wMedia.height * 0.5
                        if (Math.abs(cx - lockRoot.width * 0.5) < 14) cx = lockRoot.width * 0.5
                        lockRoot.setWidgetPos("media", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 7: ПОГОДА ====================
            Item {
                id: wWeather
                readonly property var cfg: lockRoot.widgetsCfg["weather"] || { enabled: true, nx: 0.12, ny: 0.08 }
                visible: cfg.enabled
                width: weathRow.implicitWidth + 28
                height: 36
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    radius: (Theme && Theme.isRounded) ? 10 : 0
                    color: Qt.rgba(0.07, 0.08, 0.11, 0.72)
                    border.width: 1
                    border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                    Row {
                        id: weathRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: Waybar ? Waybar.weatherText : "☁️ +2°C"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wWeather.x + (m.x - startX) + wWeather.width * 0.5
                        var cy = wWeather.y + (m.y - startY) + wWeather.height * 0.5
                        lockRoot.setWidgetPos("weather", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 8: СИСТЕМА (CPU / TEMP / RAM) ====================
            Item {
                id: wSysinfo
                readonly property var cfg: lockRoot.widgetsCfg["sysinfo"] || { enabled: true, nx: 0.88, ny: 0.08 }
                visible: cfg.enabled
                width: lockSysRow.implicitWidth + 28
                height: 36
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)

                Rectangle {
                    anchors.fill: parent
                    radius: (Theme && Theme.isRounded) ? 10 : 0
                    color: Qt.rgba(0.07, 0.08, 0.11, 0.72)
                    border.width: 1
                    border.color: lockRoot.editMode ? "#69f0ae" : Qt.rgba(1, 1, 1, 0.16)

                    Row {
                        id: lockSysRow
                        anchors.centerIn: parent
                        spacing: 14
                        Row {
                            spacing: 6
                            Text { text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: (Waybar ? Waybar.cpuUsage : 0) + "%"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: 6
                            Text { text: ""; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: (Waybar ? Waybar.cpuTemp : 40) + "°C"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: 6
                            Text { text: "󰍛"; color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: Waybar ? Waybar.memUsageText : "0.0G"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wSysinfo.x + (m.x - startX) + wSysinfo.width * 0.5
                        var cy = wSysinfo.y + (m.y - startY) + wSysinfo.height * 0.5
                        lockRoot.setWidgetPos("sysinfo", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ==================== ВИДЖЕТ 9: КНОПКА И ВСПЛЫВАЮЩЕЕ МЕНЮ ПИТАНИЯ (POWER MENU) ====================
            Item {
                id: wPower
                readonly property var cfg: lockRoot.widgetsCfg["power"] || { enabled: true, nx: 0.95, ny: 0.92 }
                visible: cfg.enabled
                width: 44
                height: 44
                x: Math.round(cfg.nx * lockRoot.width - width * 0.5)
                y: Math.round(cfg.ny * lockRoot.height - height * 0.5)
                z: 40

                Rectangle {
                    anchors.fill: parent
                    radius: (Theme && Theme.isRounded) ? 22 : 0
                    color: lockRoot.powerMenuOpen
                           ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                           : Qt.rgba(0.07, 0.08, 0.11, 0.78)
                    border.width: lockRoot.editMode ? 1.5 : 1
                    border.color: lockRoot.editMode
                                  ? "#69f0ae"
                                  : (lockRoot.powerMenuOpen ? "transparent" : Qt.rgba(1, 1, 1, 0.22))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        font.pixelSize: 17
                        color: lockRoot.powerMenuOpen
                               ? ((Config && Theme && Theme.isRounded) ? Config.accentTextColor : "#000000")
                               : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                    }
                }

                MouseArea {
                    enabled: !lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        lockRoot.powerSelectedIndex = 0
                        lockRoot.powerMenuOpen = !lockRoot.powerMenuOpen
                        lockRoot.ensureFocus()
                    }
                }

                MouseArea {
                    visible: lockRoot.editMode
                    enabled: lockRoot.editMode
                    anchors.fill: parent
                    cursorShape: lockRoot.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
                    property real startX: 0; property real startY: 0
                    onPressed: (m) => { startX = m.x; startY = m.y }
                    onPositionChanged: (m) => {
                        if (!pressed) return
                        var cx = wPower.x + (m.x - startX) + wPower.width * 0.5
                        var cy = wPower.y + (m.y - startY) + wPower.height * 0.5
                        lockRoot.setWidgetPos("power", cx / lockRoot.width, cy / lockRoot.height)
                    }
                }
            }

            // ВСПЛЫВАЮЩЕЕ POWER MENU НА ЭКРАНЕ БЛОКИРОВКИ
            Rectangle {
                id: lockPowerPopup
                readonly property bool openAbove: (wPower.y + wPower.height * 0.5) > (lockRoot.height * 0.5)
                width: 210
                height: 242
                x: Math.max(16, Math.min(lockRoot.width - width - 16, Math.round(wPower.x + wPower.width * 0.5 - width * 0.5)))
                y: openAbove
                   ? Math.max(16, wPower.y - height - 10)
                   : Math.min(lockRoot.height - height - 16, wPower.y + wPower.height + 10)
                z: 45
                visible: opacity > 0.01 && !lockRoot.editMode
                opacity: lockRoot.powerMenuOpen ? 1.0 : 0.0
                scale: lockRoot.powerMenuOpen ? 1.0 : 0.90
                transformOrigin: openAbove ? Item.Bottom : Item.Top
                Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.35 } }

                radius: (Theme && Theme.isRounded) ? 16 : 0
                color: Qt.rgba(0.06, 0.07, 0.10, 0.92)
                border.width: 1
                border.color: (Theme && Theme.isRounded && Config)
                              ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.38)
                              : Qt.rgba(1, 1, 1, 0.22)

                MouseArea { anchors.fill: parent; onClicked: {} }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        text: "Power Menu"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 2
                    }

                    Item {
                        id: lockPowerItemsArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property int itemCount: lockRoot.lockPowerActions.length
                        readonly property real gap: 6
                        readonly property real btnH: Math.max(28, (height - gap * (itemCount - 1)) / itemCount)

                        Rectangle {
                            id: lockPowerSlidePill
                            x: 0
                            y: lockRoot.powerSelectedIndex * (lockPowerItemsArea.btnH + lockPowerItemsArea.gap)
                            width: lockPowerItemsArea.width
                            height: lockPowerItemsArea.btnH
                            radius: (Theme && Theme.isRounded) ? 10 : 0
                            color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff"
                            Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                        }

                        Repeater {
                            model: lockRoot.lockPowerActions
                            delegate: Rectangle {
                                x: 0
                                y: index * (lockPowerItemsArea.btnH + lockPowerItemsArea.gap)
                                width: lockPowerItemsArea.width
                                height: lockPowerItemsArea.btnH
                                readonly property bool isSelected: lockRoot.powerSelectedIndex === index
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: "transparent"
                                border.color: isSelected ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 13
                                        color: isSelected
                                               ? ((Config && Theme && Theme.isRounded) ? Config.accentTextColor : "#000000")
                                               : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.bold: isSelected
                                        color: isSelected
                                               ? ((Config && Theme && Theme.isRounded) ? Config.accentTextColor : "#000000")
                                               : "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: lockRoot.powerSelectedIndex = index
                                    onPositionChanged: lockRoot.powerSelectedIndex = index
                                    onClicked: {
                                        lockRoot.powerSelectedIndex = index
                                        lockRoot.triggerLockPowerAction(modelData.act)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Панель управления раскладкой (доступна ТОЛЬКО при открытии Полноэкранного редактора из настроек HySett)
        Rectangle {
            id: editToolbar
            visible: lockRoot.editMode
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: editBarCol.implicitWidth + 28
            height: editBarCol.implicitHeight + 20
            radius: (Theme && Theme.isRounded) ? 14 : 0
            color: Qt.rgba(0.06, 0.07, 0.10, 0.90)
            border.width: 1
            border.color: (Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae"

            ColumnLayout {
                id: editBarCol
                anchors.centerIn: parent
                spacing: 8

                RowLayout {
                    spacing: 10
                    Text {
                        text: "󰕰  Редактор макета блокировки (перетаскивай виджеты мышью)"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Rectangle {
                        height: 24; width: 98
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "↺"; color: "#ffffff"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Сбросить"; color: "#ffffff"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: lockRoot.resetLayout() }
                    }
                    Rectangle {
                        height: 24; width: 152
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: (Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae"
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "✓"; color: "#000000"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Сохранить и выйти"; color: "#000000"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: lockRoot.unlockNow() }
                    }
                }

                RowLayout {
                    spacing: 6
                    Repeater {
                        model: ["clock", "greeting", "password", "status", "notifications", "media", "weather", "sysinfo", "power"]
                        delegate: Rectangle {
                            readonly property var wItem: lockRoot.widgetsCfg[modelData] || { enabled: true, title: modelData }
                            height: 24
                            width: chipInnerRow.implicitWidth + 16
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: wItem.enabled
                                   ? ((Config && Theme && Theme.isRounded) ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.25) : Qt.rgba(0.4, 0.95, 0.65, 0.22))
                                   : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: wItem.enabled ? ((Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae") : Qt.rgba(1, 1, 1, 0.15)
                            Row {
                                id: chipInnerRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: wItem.enabled ? "✓" : "○"
                                    color: wItem.enabled ? ((Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae") : "#888888"
                                    font.pixelSize: 10
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: chipTxt
                                    text: wItem.title
                                    color: wItem.enabled ? "#ffffff" : "#888888"
                                    font.pixelSize: 10
                                    font.bold: wItem.enabled
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lockRoot.setWidgetEnabled(modelData, !wItem.enabled)
                            }
                        }
                    }
                }
            }
        }
    }
}
