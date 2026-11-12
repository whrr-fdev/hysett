import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: vpnScroll
    property bool hideSubLinks: false
    property int copiedSubIdx: -1
    property int copiedWlSubIdx: -1
    property string copiedSrvSig: ""
    property bool copiedLogs: false
    property int activeSubTab: 0
    readonly property bool isM3: Theme && Theme.isRounded

    property bool viewWlMode: Waybar ? Waybar.vpnWhitelistMode : false
    readonly property bool isWlMode: viewWlMode
    property real modeSlideProgress: viewWlMode ? 1.0 : 0.0
    Behavior on modeSlideProgress { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

    readonly property bool normalScreenVis: modeSlideProgress < 0.999
    readonly property bool wlScreenVis: modeSlideProgress > 0.001

    readonly property bool normalVpnOn: Waybar ? (Waybar.vpnActive && !Waybar.vpnActiveIsWl) : false
    readonly property bool wlVpnOn: Waybar ? (Waybar.vpnActive && Waybar.vpnActiveIsWl) : false

    contentWidth: availableWidth
    clip: true

    Timer {
        id: copyResetTimer
        interval: 1300
        onTriggered: {
            vpnScroll.copiedSubIdx = -1
            vpnScroll.copiedWlSubIdx = -1
            vpnScroll.copiedSrvSig = ""
            vpnScroll.copiedLogs = false
        }
    }

    Timer {
        interval: 750
        repeat: true
        running: vpnScroll.visible && Waybar && Waybar.vpnLogAutoRefresh && (ApplicationWindow.window ? ApplicationWindow.window.drawerOpen : true)
        triggeredOnStart: true
        onTriggered: if (Waybar) Waybar.refreshVpnLogs()
    }

    function parseServerItem(rawStr, isWl) {
        var s = (rawStr || "").trim()
        if (!s) return { icon: "󰈀", badge: "", ping: "", title: "Сервер" }
        if (s.indexOf("Авто-выбор") === 0) {
            return { icon: "󰓅", badge: "АВТО", ping: "", title: s }
        }
        var parts = s.split(" • ")
        if (parts.length >= 3 && parts[0].indexOf("мс") !== -1) {
            var b0 = parts[1]
            var ic0 = b0.indexOf("CIDR+SNI") !== -1 ? "󰄬" : (b0.indexOf("CIDR") !== -1 ? "󰞀" : (b0.indexOf("SNI") !== -1 ? "󰒃" : "󰈀"))
            return { icon: ic0, badge: b0, ping: parts[0], title: parts.slice(2).join(" • ") }
        }
        if (parts.length >= 2 && (parts[0] === "CIDR+SNI" || parts[0] === "CIDR РФ" || parts[0] === "Белый SNI" || parts[0] === "VLESS")) {
            var b1 = parts[0]
            var ic1 = b1 === "CIDR+SNI" ? "󰄬" : (b1 === "CIDR РФ" ? "󰞀" : (b1 === "Белый SNI" ? "󰒃" : "󰈀"))
            return { icon: ic1, badge: b1, ping: "", title: parts.slice(1).join(" • ") }
        }
        return { icon: isWl ? "󰒃" : "󰈀", badge: "", ping: "", title: s }
    }

    component VpnLogsCard: GlassPanel {
        id: logsCardRoot
        property bool activeScreen: true
        objectName: "atmoObstacle"
        Layout.fillWidth: true
        implicitHeight: logsInnerCol.implicitHeight + 28

        ColumnLayout {
            id: logsInnerCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item {
                    width: 18; height: 18
                    Text { anchors.centerIn: parent; text: "󰌱"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                }
                Text {
                    text: "Журнал событий и логов"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "󰑐 Обновить"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.refreshVpnLogs()
                }
                StyledButton {
                    text: vpnScroll.copiedLogs ? "󰄬 Скопировано" : "󰆏 Копировать"
                    implicitHeight: 24
                    isActive: vpnScroll.copiedLogs
                    onClicked: {
                        if (Waybar && Waybar.vpnLogs.length > 0) {
                            var safeTxt = Waybar.vpnLogs.join("\n").replace(/'/g, "'\\''")
                            Waybar.runCommand("printf '%s' '" + safeTxt + "' | wl-copy")
                            vpnScroll.copiedLogs = true
                            copyResetTimer.restart()
                        }
                    }
                }
                StyledButton {
                    text: "󰅖 Очистить"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.clearVpnLogs()
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Text { text: "Длина:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1 }
                SegmentedButton {
                    Layout.preferredWidth: 210
                    implicitHeight: 26
                    options: ["50", "100", "250", "500"]
                    selectedIndex: {
                        if (!Waybar) return 1
                        var m = Waybar.vpnLogMaxLines
                        if (m <= 50) return 0
                        if (m <= 100) return 1
                        if (m <= 250) return 2
                        return 3
                    }
                    onSelected: (idx) => {
                        if (!Waybar) return
                        var vals = [50, 100, 250, 500]
                        Waybar.vpnLogMaxLines = vals[idx]
                    }
                }

                Text { text: "Высота:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1 }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 90; to: 380; stepSize: 10
                    value: Waybar ? Waybar.vpnLogHeight : 160
                    onMoved: if (Waybar) Waybar.vpnLogHeight = Math.round(value)
                }

                SegmentedButton {
                    Layout.preferredWidth: 180
                    implicitHeight: 26
                    options: ["Инфо", "Ошибки", "Отладка"]
                    selectedIndex: {
                        if (!Waybar) return 0
                        if (Waybar.vpnLogLevel === "warn") return 1
                        if (Waybar.vpnLogLevel === "debug") return 2
                        return 0
                    }
                    onSelected: (idx) => {
                        if (!Waybar) return
                        var lvls = ["info", "warn", "debug"]
                        Waybar.vpnLogLevel = lvls[idx]
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 16
                StyledCheckBox {
                    text: "Живое обновление"
                    checked: Waybar ? Waybar.vpnLogAutoRefresh : true
                    onToggled: if (Waybar) Waybar.vpnLogAutoRefresh = checked
                }
                StyledCheckBox {
                    text: "Автопрокрутка вниз"
                    checked: Waybar ? Waybar.vpnLogAutoScroll : true
                    onToggled: {
                        if (Waybar) {
                            Waybar.vpnLogAutoScroll = checked
                            if (checked) logFlick.scrollToBottom()
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Строк: " + (Waybar ? Waybar.vpnLogs.length : 0)
                    color: "#888888"; font.pixelSize: Config.fontSize - 2
                }
            }

            Rectangle {
                readonly property int boxH: Waybar ? Waybar.vpnLogHeight : 160
                Layout.fillWidth: true
                Layout.preferredHeight: boxH
                implicitHeight: boxH
                height: boxH
                radius: vpnScroll.isM3 ? 8 : 0
                color: Qt.rgba(0, 0, 0, 0.28)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                Flickable {
                    id: logFlick
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: logEdit.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    property real targetY: 0
                    property real stableWrapW: 780

                    Timer {
                        id: wrapWidthDebounce
                        interval: 220
                        onTriggered: if (logFlick.width > 60) logFlick.stableWrapW = Math.round(logFlick.width - 10)
                    }

                    onWidthChanged: {
                        if (Math.abs(width - 10 - stableWrapW) > 260 && stableWrapW === 780 && width > 60) {
                            stableWrapW = Math.round(width - 10)
                        } else {
                            wrapWidthDebounce.restart()
                        }
                    }

                    NumberAnimation {
                        id: smoothLogAnim
                        target: logFlick
                        property: "contentY"
                        duration: 140
                        easing.type: Easing.OutCubic
                    }

                    function scrollToBottom() {
                        var maxY = Math.max(0, logFlick.contentHeight - logFlick.height)
                        if (Math.abs(logFlick.contentY - maxY) < 1.5) return
                        logFlick.targetY = maxY
                        smoothLogAnim.stop()
                        smoothLogAnim.from = logFlick.contentY
                        smoothLogAnim.to = maxY
                        smoothLogAnim.start()
                    }

                    onContentHeightChanged: {
                        if (Waybar && Waybar.vpnLogAutoScroll && !wrapWidthDebounce.running) {
                            var maxY = Math.max(0, logFlick.contentHeight - logFlick.height)
                            if (!smoothLogAnim.running) {
                                logFlick.contentY = maxY
                                logFlick.targetY = maxY
                            } else {
                                logFlick.scrollToBottom()
                            }
                        }
                    }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        blocking: true
                        onWheel: (event) => {
                            var step = (event.angleDelta.y / 120.0) * 58.0
                            if (step === 0 && event.pixelDelta.y !== 0) step = event.pixelDelta.y * 1.5
                            var maxY = Math.max(0, logFlick.contentHeight - logFlick.height)
                            var base = smoothLogAnim.running ? logFlick.targetY : logFlick.contentY
                            var nextY = Math.max(0, Math.min(maxY, base - step))

                            if (step > 0 && Waybar && Waybar.vpnLogAutoScroll && (maxY - nextY > 24)) {
                                Waybar.vpnLogAutoScroll = false
                            } else if (step < 0 && Waybar && !Waybar.vpnLogAutoScroll && (maxY - nextY <= 8)) {
                                Waybar.vpnLogAutoScroll = true
                            }

                            logFlick.targetY = nextY
                            smoothLogAnim.stop()
                            smoothLogAnim.from = logFlick.contentY
                            smoothLogAnim.to = nextY
                            smoothLogAnim.start()
                            event.accepted = true
                        }
                    }

                    TextEdit {
                        id: logEdit
                        width: logFlick.stableWrapW
                        readOnly: true
                        selectByMouse: true
                        textFormat: TextEdit.PlainText
                        wrapMode: TextEdit.WrapAnywhere
                        font.family: "monospace"
                        font.pixelSize: 10
                        color: "#cccccc"
                        text: (vpnScroll.visible && logsCardRoot.activeScreen && Waybar) ? Waybar.vpnLogHtml : ""
                    }
                }
            }
        }
    }

    component SplitTunnelCard: GlassPanel {
        objectName: "atmoObstacle"
        Layout.fillWidth: true
        implicitHeight: splitInnerCol.implicitHeight + 28

        ColumnLayout {
            id: splitInnerCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item {
                    width: 18; height: 18
                    Text { anchors.centerIn: parent; text: "󰒓"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                }
                Text {
                    text: "Раздельное туннелирование"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    Layout.fillWidth: true
                }
            }

            SegmentedButton {
                Layout.fillWidth: true
                implicitHeight: 30
                options: [
                    "󰈀 Обход РФ",
                    "󰞀 Только заблокированные",
                    "󰦝 Весь трафик в VPN"
                ]
                selectedIndex: {
                    if (!Waybar) return 0;
                    if (Waybar.vpnSplitMode === "only_blocked") return 1;
                    if (Waybar.vpnSplitMode === "all_vpn") return 2;
                    return 0;
                }
                onSelected: (idx) => {
                    if (!Waybar) return;
                    if (idx === 1) Waybar.vpnSplitMode = "only_blocked";
                    else if (idx === 2) Waybar.vpnSplitMode = "all_vpn";
                    else Waybar.vpnSplitMode = "ru_direct";
                }
            }

            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                color: "#999999"; font.pixelSize: Config.fontSize - 1
                text: {
                    if (!Waybar) return "";
                    if (Waybar.vpnSplitMode === "only_blocked")
                        return "Через VPN идут только заблокированные сайты и сервисы из списков. Весь остальной трафик и игры идут напрямую.";
                    if (Waybar.vpnSplitMode === "all_vpn")
                        return "Весь трафик системы направляется через VPN-туннель.";
                    return "Российские сайты и сервисы работают напрямую без потери скорости, а заблокированные и зарубежные ресурсы идут через VPN.";
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                TextField {
                    id: customDomField
                    Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                    color: "#ffffff"; font.pixelSize: 11
                    placeholderText: "Введите домен..."
                    placeholderTextColor: "#777777"
                    background: Rectangle {
                        radius: vpnScroll.isM3 ? 8 : 0
                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.16)
                        border.width: vpnScroll.isM3 ? 0 : 1
                    }
                }
                StyledButton {
                    text: "+ Через VPN"
                    implicitHeight: 28
                    onClicked: {
                        if (Waybar && customDomField.text.trim().length > 0) {
                            Waybar.addVpnCustomDomain(customDomField.text.trim(), false)
                            customDomField.text = ""
                        }
                    }
                }
                StyledButton {
                    text: "+ Напрямую"
                    implicitHeight: 28
                    onClicked: {
                        if (Waybar && customDomField.text.trim().length > 0) {
                            Waybar.addVpnCustomDomain(customDomField.text.trim(), true)
                            customDomField.text = ""
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true; spacing: 6
                visible: Waybar && (Waybar.vpnCustomProxyDomains.length > 0 || Waybar.vpnCustomDirectDomains.length > 0)

                Repeater {
                    model: Waybar ? Waybar.vpnCustomProxyDomains : []
                    delegate: StyledButton {
                        text: "󰅖 VPN: " + modelData
                        implicitHeight: 24
                        onClicked: if (Waybar) Waybar.removeVpnCustomDomain(index, false)
                    }
                }

                Repeater {
                    model: Waybar ? Waybar.vpnCustomDirectDomains : []
                    delegate: StyledButton {
                        text: "󰅖 Прямой: " + modelData
                        implicitHeight: 24
                        onClicked: if (Waybar) Waybar.removeVpnCustomDomain(index, true)
                    }
                }
            }
        }
    }

    // Плавающая закрепленная сверху плашка живой проверки 2ip.io
    Item {
        id: sticky2ipOverlay
        parent: vpnScroll
        z: 100
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 48, 880)
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: vpnScroll.isM3 ? 10 : 0
            color: vpnScroll.isM3 && Config
                   ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.96)
                   : Qt.rgba(0.08, 0.09, 0.12, 0.96)
            border.width: 1
            border.color: {
                var st = Waybar ? Waybar.vpnIpCheckState : 0
                if (st === 2) return Qt.rgba(0.41, 0.94, 0.68, 0.65)
                if (st === 3) return Qt.rgba(1.0, 0.42, 0.42, 0.70)
                if (st === 1) return Qt.rgba(1.0, 0.84, 0.31, 0.65)
                return Qt.rgba(1, 1, 1, 0.18)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: {
                        var st = Waybar ? Waybar.vpnIpCheckState : 0
                        if (st === 2) return "#69f0ae"
                        if (st === 3) return "#ff6b6b"
                        if (st === 1) return "#ffd54f"
                        return "#777777"
                    }
                }

                Text {
                    text: "󰍎 2ip.io:"
                    color: "#cccccc"
                    font.pixelSize: Config.fontSize - 1
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Config.fontSize
                    font.bold: (Waybar ? Waybar.vpnIpCheckState : 0) >= 1
                    color: {
                        if (!Waybar || !Waybar.vpnActive) return "#999999"
                        var st = Waybar.vpnIpCheckState
                        if (st === 2) return "#69f0ae"
                        if (st === 3) return "#ff8a80"
                        if (st === 1) return "#ffd54f"
                        return "#cccccc"
                    }
                    text: {
                        if (!Waybar || !Waybar.vpnActive) return "Туннель отключен"
                        var t = Waybar.vpnIpCheckText || ""
                        return t.length > 0 ? t : "Нажмите «Проверить 2ip.io»"
                    }
                }

                StyledButton {
                    text: (Waybar && Waybar.vpnIpCheckState === 1) ? "󰑐 Проверка..." : "󰑐 Проверить 2ip.io"
                    implicitHeight: 24
                    enabled: Waybar && Waybar.vpnActive && Waybar.vpnIpCheckState !== 1
                    onClicked: if (Waybar) Waybar.checkVpn2ip()
                }
            }
        }
    }

    Item {
        width: vpnScroll.availableWidth
        implicitHeight: topHeaderCol.implicitHeight + fullPageSlider.implicitHeight + 92

        ColumnLayout {
            id: topHeaderCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 58
            spacing: 12

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item {
                    width: 20; height: 20
                    Text { anchors.centerIn: parent; text: "󰦝"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 4 }
                }
                Text {
                    text: "VPN и Обход блокировок"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    visible: Waybar && Waybar.vpnLastUpdated.length > 0
                    text: "Обновлено: " + (Waybar ? Waybar.vpnLastUpdated : "")
                    color: "#999999"
                    font.pixelSize: Config.fontSize - 1
                }
                StyledButton {
                    text: (Waybar && Waybar.vpnBusy)
                          ? ("󰑐 " + Waybar.vpnProgressPercent + "% • " + (Waybar.vpnProgressText.length > 0 ? Waybar.vpnProgressText : "Обновление..."))
                          : "󰑐 Обновить всё"
                    implicitHeight: 26
                    enabled: !(Waybar && Waybar.vpnBusy)
                    onClicked: if (Waybar) Waybar.updateBypassLists()
                }
            }

            // Полоса прогресса при обновлении репозиториев или проверке серверов БС
            Rectangle {
                visible: Waybar && Waybar.vpnBusy
                Layout.fillWidth: true
                height: 6
                radius: vpnScroll.isM3 ? 3 : 0
                color: Qt.rgba(1, 1, 1, 0.10)
                clip: true

                Rectangle {
                    width: parent.width * Math.max(0.05, Math.min(1.0, (Waybar ? Waybar.vpnProgressPercent : 0) / 100.0))
                    height: parent.height
                    radius: parent.radius
                    color: Config ? Config.m3Primary : "#69f0ae"
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
            }

            SegmentedButton {
                Layout.fillWidth: true
                implicitHeight: 34
                options: [
                    "󰦝 Обычный VPN",
                    "󰒃 Белые списки"
                ]
                selectedIndex: vpnScroll.viewWlMode ? 1 : 0
                onSelected: (idx) => {
                    var targetWl = (idx === 1)
                    vpnScroll.viewWlMode = targetWl
                    if (Waybar) Waybar.vpnWhitelistMode = targetWl
                }
            }
        }

        Item {
            id: fullPageSlider
            anchors.top: topHeaderCol.bottom
            anchors.topMargin: 12
            width: parent.width
            clip: true
            implicitHeight: vpnScroll.viewWlMode ? wlFullCol.implicitHeight : normalFullCol.implicitHeight
            Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

            Item {
                anchors.fill: parent

                // =========================================================================
                // ЭКРАН 0: ОБЫЧНЫЙ VPN
                // =========================================================================
                Item {
                    x: -vpnScroll.modeSlideProgress * fullPageSlider.width
                    width: fullPageSlider.width
                    implicitHeight: normalFullCol.implicitHeight
                    visible: vpnScroll.normalScreenVis

                    ColumnLayout {
                        id: normalFullCol
                        width: Math.min(parent.width - 48, 880)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 10 : 0
                                    color: vpnScroll.normalVpnOn
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    border.color: vpnScroll.normalVpnOn
                                                  ? (Config ? Config.m3Primary : "#ffffff")
                                                  : Qt.rgba(1, 1, 1, 0.22)
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent; text: "󰦝"; font.pixelSize: 20
                                        color: vpnScroll.normalVpnOn
                                               ? (Config ? Config.accentTextColor : "#000000")
                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    Text {
                                        text: Waybar ? Waybar.vpnSubServerName : "VPN"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 2; font.bold: true
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            width: 7; height: 7; radius: 3.5
                                            color: vpnScroll.normalVpnOn ? "#69f0ae" : "#777777"
                                        }
                                        Text {
                                            text: vpnScroll.normalVpnOn ? "Подключено" : "Отключено"
                                            color: vpnScroll.normalVpnOn ? "#69f0ae" : "#888888"
                                            font.pixelSize: Config.fontSize - 1
                                        }
                                        Text {
                                            visible: Waybar && Waybar.vpnStatusHint.length > 0
                                            text: "•  " + (Waybar ? Waybar.vpnStatusHint : "")
                                            color: "#888888"; font.pixelSize: Config.fontSize - 2
                                        }
                                    }
                                }

                                StyledSwitch {
                                    checked: vpnScroll.normalVpnOn
                                    onToggled: if (Waybar) Waybar.toggleVpnForMode(false)
                                }
                            }
                        }

                        // Карточка подписок Обычного VPN
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: subTabsCol.implicitHeight + 28

                            ColumnLayout {
                                id: subTabsCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Item {
                                        width: 18; height: 18
                                        Text { anchors.centerIn: parent; text: "󰌘"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    }
                                    Text {
                                        text: "Мои подписки и ключи"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnSubUrls.length > 0
                                        text: "󰑐 Обновить подписки"
                                        implicitHeight: 24
                                        enabled: !(Waybar && Waybar.vpnBusy)
                                        onClicked: if (Waybar) Waybar.updateVpnSubscription()
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnSubUrls.length > 0
                                        text: vpnScroll.hideSubLinks ? "󰈉 Показать ссылки" : "󰈈 Блюр ссылок"
                                        implicitHeight: 24
                                        isActive: vpnScroll.hideSubLinks
                                        onClicked: vpnScroll.hideSubLinks = !vpnScroll.hideSubLinks
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    TextField {
                                        id: subUrlField
                                        Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                                        color: "#ffffff"; font.pixelSize: 11
                                        placeholderText: "Вставьте ссылку на подписку или ключ..."
                                        placeholderTextColor: "#777777"
                                        background: Rectangle {
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1,1,1,0.06)
                                            border.color: Qt.rgba(1,1,1,0.16)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                        }
                                    }
                                    StyledButton {
                                        text: "+ Добавить"
                                        implicitHeight: 28
                                        onClicked: {
                                            if (Waybar && subUrlField.text.trim().length > 0) {
                                                Waybar.addVpnSubUrl(subUrlField.text.trim())
                                                subUrlField.text = ""
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: subTabBar
                                    visible: Waybar && Waybar.vpnSubGroups.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: subTabFlow.implicitHeight
                                    property Item activeItem: allSubTabBtn
                                    property Item hoveredItem: null
                                    property Item lastHoveredItem: allSubTabBtn

                                    Rectangle {
                                        id: subTabHoverPill
                                        z: 2
                                        opacity: (subTabBar.hoveredItem && subTabBar.hoveredItem !== subTabBar.activeItem) ? 1.0 : 0.0
                                        x: subTabBar.lastHoveredItem ? subTabBar.lastHoveredItem.x : 0
                                        y: subTabBar.lastHoveredItem ? subTabBar.lastHoveredItem.y : 0
                                        width: subTabBar.lastHoveredItem ? subTabBar.lastHoveredItem.width : 90
                                        height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config
                                               ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22)
                                               : Qt.rgba(1, 1, 1, 0.14)
                                        border.width: 1
                                        border.color: vpnScroll.isM3 && Config
                                                      ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.48)
                                                      : Qt.rgba(1, 1, 1, 0.28)
                                        Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 110 } }
                                    }

                                    Rectangle {
                                        id: subTabActivePill
                                        z: 3
                                        visible: subTabBar.activeItem !== null
                                        x: subTabBar.activeItem ? subTabBar.activeItem.x : 0
                                        y: subTabBar.activeItem ? subTabBar.activeItem.y : 0
                                        width: subTabBar.activeItem ? subTabBar.activeItem.width : 90
                                        height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
                                    }

                                    Flow {
                                        id: subTabFlow
                                        z: 4; width: parent.width; spacing: 6

                                        Item {
                                            id: allSubTabBtn
                                            width: allSubTabTxt.implicitWidth + 24; height: 28
                                            property bool isSel: vpnScroll.activeSubTab === 0
                                            onIsSelChanged: if (isSel) subTabBar.activeItem = allSubTabBtn
                                            Component.onCompleted: if (isSel) subTabBar.activeItem = allSubTabBtn

                                            Rectangle {
                                                anchors.fill: parent
                                                z: -1
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: parent.isSel
                                                       ? "transparent"
                                                       : (vpnScroll.isM3 && Config
                                                          ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.42)
                                                          : Qt.rgba(1, 1, 1, 0.06))
                                                border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                                border.width: vpnScroll.isM3 ? 0 : 1
                                                Behavior on color { ColorAnimation { duration: 130 } }
                                            }

                                            Text {
                                                id: allSubTabTxt; anchors.centerIn: parent
                                                text: "Все • " + (Waybar ? Waybar.vpnSubServers.length : 0)
                                                font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                color: parent.isSel
                                                       ? (Config ? Config.accentTextColor : "#000000")
                                                       : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                                Behavior on color { ColorAnimation { duration: 120 } }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    subTabBar.lastHoveredItem = allSubTabBtn
                                                    subTabBar.hoveredItem = allSubTabBtn
                                                }
                                                onExited: if (subTabBar.hoveredItem === allSubTabBtn) subTabBar.hoveredItem = null
                                                onPressed: vpnScroll.activeSubTab = 0
                                            }
                                        }

                                        Repeater {
                                            id: oneSubTabRepeater
                                            model: Waybar ? Waybar.vpnSubGroups : []
                                            delegate: Item {
                                                id: oneSubTabBtn
                                                width: oneSubContentRow.implicitWidth + 24; height: 28
                                                property bool isSel: vpnScroll.activeSubTab === (index + 1)
                                                readonly property var splitParts: {
                                                    var st = (modelData.title || "").trim()
                                                    if (!st) return { icon: "", label: "" }
                                                    var cp = st.codePointAt(0)
                                                    if (cp >= 0xE000) {
                                                        var chLen = cp > 0xFFFF ? 2 : 1
                                                        return { icon: st.slice(0, chLen), label: st.slice(chLen).trim() }
                                                    }
                                                    return { icon: "", label: st }
                                                }
                                                onIsSelChanged: if (isSel) subTabBar.activeItem = oneSubTabBtn
                                                Component.onCompleted: if (isSel) subTabBar.activeItem = oneSubTabBtn

                                                Rectangle {
                                                    anchors.fill: parent
                                                    z: -1
                                                    radius: vpnScroll.isM3 ? 8 : 0
                                                    color: parent.isSel
                                                           ? "transparent"
                                                           : (vpnScroll.isM3 && Config
                                                              ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.42)
                                                              : Qt.rgba(1, 1, 1, 0.06))
                                                    border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                                    border.width: vpnScroll.isM3 ? 0 : 1
                                                    Behavior on color { ColorAnimation { duration: 130 } }
                                                }

                                                Row {
                                                    id: oneSubContentRow
                                                    anchors.centerIn: parent
                                                    spacing: oneSubTabBtn.splitParts.icon.length > 0 ? 7 : 0

                                                    Item {
                                                        visible: oneSubTabBtn.splitParts.icon.length > 0
                                                        width: 15; height: 16
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: oneSubTabBtn.splitParts.icon
                                                            font.pixelSize: Config.fontSize
                                                            color: oneSubTabTxt.color
                                                        }
                                                    }

                                                    Text {
                                                        id: oneSubTabTxt
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: oneSubTabBtn.splitParts.label + " • " + modelData.count
                                                        font.pixelSize: Config.fontSize - 1; font.bold: oneSubTabBtn.isSel
                                                        color: oneSubTabBtn.isSel
                                                               ? (Config ? Config.accentTextColor : "#000000")
                                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                                        Behavior on color { ColorAnimation { duration: 120 } }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onEntered: {
                                                        subTabBar.lastHoveredItem = oneSubTabBtn
                                                        subTabBar.hoveredItem = oneSubTabBtn
                                                    }
                                                    onExited: if (subTabBar.hoveredItem === oneSubTabBtn) subTabBar.hoveredItem = null
                                                    onPressed: vpnScroll.activeSubTab = index + 1
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: urlsBlurBox
                                    visible: Waybar && Waybar.vpnSubGroups.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: subListCol.implicitHeight
                                    property bool isHovering: false
                                    property real hovY: 0

                                    Timer {
                                        id: subRowHoverHold
                                        interval: 45
                                        onTriggered: urlsBlurBox.isHovering = false
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: urlsBlurBox.isHovering ? 1.0 : 0.0
                                        x: 0; y: urlsBlurBox.hovY
                                        width: urlsBlurBox.width; height: 34
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.10)
                                        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }

                                    ColumnLayout {
                                        id: subListCol
                                        z: 2; width: parent.width; spacing: 6

                                        Repeater {
                                            model: Waybar ? Waybar.vpnSubGroups : []
                                            delegate: Rectangle {
                                                id: subRowItem
                                                visible: !modelData.is_public_bl && (vpnScroll.activeSubTab === 0 || vpnScroll.activeSubTab === (index + 1))
                                                Layout.fillWidth: true; implicitHeight: 34
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: vpnScroll.isM3 && Config
                                                       ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                                clip: true

                                                MouseArea {
                                                    anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                                    onEntered: {
                                                        subRowHoverHold.stop()
                                                        urlsBlurBox.hovY = subRowItem.y
                                                        urlsBlurBox.isHovering = true
                                                    }
                                                    onExited: subRowHoverHold.restart()
                                                }

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8

                                                    Item {
                                                        id: subUrlBlurWrap
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        layer.enabled: vpnScroll.hideSubLinks
                                                        layer.smooth: true
                                                        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 0.22)), Math.max(1, Math.round(height * 0.35)))
                                                        layer.effect: ShaderEffect {
                                                            property var source: subUrlBlurWrap
                                                            property vector2d u_resolution: Qt.vector2d(Math.max(1, subUrlBlurWrap.width * 0.22), Math.max(1, subUrlBlurWrap.height * 0.35))
                                                            property real u_blur: 0.45
                                                            fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                                                        }

                                                        Text {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: parent.width
                                                            text: modelData.title + " • " + modelData.count + " серв. • " + modelData.url
                                                            color: "#ffffff"; font.pixelSize: 10
                                                            elide: Text.ElideMiddle
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: (modelData.country || "").length > 0
                                                        width: subCountryTxt.implicitWidth + 12
                                                        height: 22
                                                        radius: vpnScroll.isM3 ? 6 : 0
                                                        color: vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10)
                                                        Text {
                                                            id: subCountryTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.country || ""
                                                            font.pixelSize: Config.fontSize - 2
                                                            font.bold: true
                                                            color: vpnScroll.isM3 && Config ? Config.m3Primary : "#ffffff"
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: (modelData.ping || "").length > 0
                                                        width: subPingBadgeTxt.implicitWidth + 12
                                                        height: 22
                                                        radius: vpnScroll.isM3 ? 6 : 0
                                                        color: Qt.rgba(0.4, 0.95, 0.68, 0.16)
                                                        Text {
                                                            id: subPingBadgeTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.ping || ""
                                                            font.pixelSize: Config.fontSize - 2
                                                            font.bold: true
                                                            font.features: { "tnum": 1 }
                                                            color: "#69f0ae"
                                                        }
                                                    }

                                                    StyledButton {
                                                        text: vpnScroll.copiedSubIdx === index ? "󰄬 Скопировано" : "󰆏 Копировать"
                                                        implicitHeight: 22
                                                        isActive: vpnScroll.copiedSubIdx === index
                                                        onClicked: {
                                                            if (Waybar) {
                                                                var safeUrl = modelData.url.replace(/'/g, "'\\''");
                                                                Waybar.runCommand("printf '%s' '" + safeUrl + "' | wl-copy");
                                                                vpnScroll.copiedSubIdx = index;
                                                                copyResetTimer.restart();
                                                            }
                                                        }
                                                    }
                                                    StyledButton {
                                                        text: "󰅖 Удалить"
                                                        implicitHeight: 22
                                                        onClicked: {
                                                            if (Waybar) {
                                                                vpnScroll.activeSubTab = 0;
                                                                Waybar.removeVpnSubUrl(index);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Карточка серверов Обычного VPN
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: normalSrvCol.implicitHeight + 28

                            ColumnLayout {
                                id: normalSrvCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Item {
                                        width: 18; height: 18
                                        Text { anchors.centerIn: parent; text: "󰈀"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    }
                                    Text {
                                        text: {
                                            if (!Waybar) return "Серверы";
                                            if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                                var g = Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1];
                                                return "Серверы • " + g.title;
                                            }
                                            return "Доступные серверы • " + Waybar.vpnSubServers.length;
                                        }
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: (Waybar && Waybar.vpnBusy) ? ("󰑐 " + Waybar.vpnProgressPercent + "%") : "󰓅 Проверить доступные"
                                        implicitHeight: 24
                                        enabled: !(Waybar && Waybar.vpnBusy)
                                        onClicked: if (Waybar) Waybar.testNormalVpnServers()
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnFrozenCount > 0
                                        text: "󰑐 Разморозить все"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.clearFrozenVpnServers()
                                    }
                                }

                                Text {
                                    visible: !Waybar || Waybar.vpnSubServers.length === 0
                                    text: "Нет добавленных серверов. Вставьте ссылку на подписку или ключ выше."
                                    color: "#888888"; font.pixelSize: Config.fontSize - 1
                                }

                                Item {
                                    id: normalSrvListWrap
                                    visible: Waybar && Waybar.vpnSubServers.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: Math.min(normalSrvList.contentHeight, 238)
                                    clip: true
                                    property bool isHovering: false
                                    property int lastHoveredRow: 0

                                    Timer {
                                        id: normalSrvHoverHold
                                        interval: 45
                                        onTriggered: normalSrvListWrap.isHovering = false
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: normalSrvListWrap.isHovering ? 1.0 : 0.0
                                        x: 0; y: normalSrvListWrap.lastHoveredRow * 34 - normalSrvList.contentY
                                        width: normalSrvList.width; height: 30
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.10)
                                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }

                                    ListView {
                                        id: normalSrvList
                                        z: 2; anchors.fill: parent; spacing: 4
                                        cacheBuffer: 600
                                        boundsBehavior: Flickable.StopAtBounds
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                        property real savedContentY: 0
                                        property int lastTabIdx: vpnScroll.activeSubTab
                                        onContentYChanged: if (!moving && contentY >= 0) savedContentY = contentY

                                        model: {
                                            if (!Waybar || !vpnScroll.normalScreenVis) return [];
                                            if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                                return Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1].servers;
                                            }
                                            return Waybar.vpnSubServerItems;
                                        }
                                        onModelChanged: {
                                            if (lastTabIdx !== vpnScroll.activeSubTab) {
                                                lastTabIdx = vpnScroll.activeSubTab
                                                savedContentY = 0
                                                contentY = 0
                                            } else if (savedContentY > 0) {
                                                var restoreY = savedContentY
                                                Qt.callLater(function() {
                                                    var maxY = Math.max(0, normalSrvList.contentHeight - normalSrvList.height)
                                                    normalSrvList.contentY = Math.min(restoreY, maxY)
                                                })
                                            }
                                        }

                                        delegate: Rectangle {
                                            width: normalSrvList.width; height: 30
                                            property int realIdx: modelData.global_index !== undefined ? modelData.global_index : index
                                            property bool isSel: Waybar && Waybar.vpnSubSelectedServer === realIdx
                                            property bool isFrz: modelData.frozen === true
                                            property bool isPin: modelData.pinned === true
                                            property string srvUri: modelData.uri || ""
                                            property string srvSig: modelData.sig || ("sub_" + realIdx)
                                            property var parsed: vpnScroll.parseServerItem(modelData.name !== undefined ? modelData.name : modelData, false)
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            opacity: isFrz ? 0.42 : 1.0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (isFrz
                                                      ? Qt.rgba(0, 0, 0, 0.42)
                                                      : (isPin
                                                         ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                                                         : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))))
                                            border.color: isSel
                                                          ? "transparent"
                                                          : (isPin
                                                             ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.55) : Qt.rgba(1, 1, 1, 0.45))
                                                             : Qt.rgba(1, 1, 1, 0.14))
                                            border.width: (isPin && !isSel) ? 1 : (vpnScroll.isM3 ? 0 : 1)
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    normalSrvHoverHold.stop()
                                                    normalSrvListWrap.lastHoveredRow = index
                                                    normalSrvListWrap.isHovering = true
                                                }
                                                onExited: normalSrvHoverHold.restart()
                                                onClicked: if (Waybar) Waybar.selectVpnServer(parent.realIdx)
                                            }

                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8

                                                Item {
                                                    width: 16; height: 16
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isFrz ? "󰜺" : parsed.icon
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : (isFrz ? "#ff8a80" : (Config ? Config.m3Primary : "#ffffff"))
                                                        font.pixelSize: Config.fontSize + 1
                                                    }
                                                }

                                                Rectangle {
                                                    visible: isFrz
                                                    width: frzSubTxt.implicitWidth + 10; height: 18
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: Qt.rgba(1, 0.35, 0.35, 0.22)
                                                    Text {
                                                        id: frzSubTxt; anchors.centerIn: parent
                                                        text: "ЗАМОРОЖЕН"
                                                        font.pixelSize: Config.fontSize - 2; font.bold: true
                                                        color: "#ff8a80"
                                                    }
                                                }

                                                Text {
                                                    text: parsed.title
                                                    color: isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                                    font.pixelSize: Config.fontSize
                                                    font.bold: isSel
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    readonly property string ccLbl: modelData.country || ""
                                                    visible: !isFrz && ccLbl.length > 0
                                                    width: normSrvCcTxt.implicitWidth + 10
                                                    height: 20
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.18) : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10))
                                                    Text {
                                                        id: normSrvCcTxt
                                                        anchors.centerIn: parent
                                                        text: parent.ccLbl
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : (vpnScroll.isM3 && Config ? Config.m3Primary : "#dddddd")
                                                    }
                                                }

                                                Rectangle {
                                                    readonly property string pingLbl: modelData.ping || parsed.ping || ""
                                                    visible: !isFrz && pingLbl.length > 0
                                                    width: normSrvPingTxt.implicitWidth + 10
                                                    height: 20
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0.4, 0.95, 0.68, 0.16)
                                                    Text {
                                                        id: normSrvPingTxt
                                                        anchors.centerIn: parent
                                                        text: parent.pingLbl
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        font.features: { "tnum": 1 }
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
                                                    }
                                                }

                                                StyledButton {
                                                    visible: srvUri.length > 0
                                                    text: vpnScroll.copiedSrvSig === srvSig ? "󰄬" : "󰆏"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: vpnScroll.copiedSrvSig === srvSig
                                                    onClicked: {
                                                        if (Waybar && srvUri.length > 0) {
                                                            var safeU = srvUri.replace(/'/g, "'\\''");
                                                            Waybar.runCommand("printf '%s' '" + safeU + "' | wl-copy");
                                                            vpnScroll.copiedSrvSig = srvSig;
                                                            copyResetTimer.restart();
                                                        }
                                                    }
                                                }

                                                StyledButton {
                                                    text: isFrz ? "󰑐" : "󰜺"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: isFrz
                                                    onClicked: if (Waybar) Waybar.toggleFreezeVpnServer(realIdx, false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SplitTunnelCard {}

                        VpnLogsCard { activeScreen: vpnScroll.normalScreenVis }
                    }
                }

                // =========================================================================
                // ЭКРАН 1: БЕЛЫЕ СПИСКИ
                // =========================================================================
                Item {
                    x: (1.0 - vpnScroll.modeSlideProgress) * fullPageSlider.width
                    width: fullPageSlider.width
                    implicitHeight: wlFullCol.implicitHeight
                    visible: vpnScroll.wlScreenVis

                    ColumnLayout {
                        id: wlFullCol
                        width: Math.min(parent.width - 48, 880)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 10 : 0
                                    color: vpnScroll.wlVpnOn
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    border.color: vpnScroll.wlVpnOn
                                                  ? (Config ? Config.m3Primary : "#ffffff")
                                                  : Qt.rgba(1, 1, 1, 0.22)
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent; text: "󰒃"; font.pixelSize: 20
                                        color: vpnScroll.wlVpnOn
                                               ? (Config ? Config.accentTextColor : "#000000")
                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    Text {
                                        text: Waybar ? Waybar.vpnWlServerName : "Авто-выбор лучшего сервера"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 2; font.bold: true
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: 8
                                        Rectangle {
                                            width: 7; height: 7; radius: 3.5
                                            color: vpnScroll.wlVpnOn ? "#69f0ae" : "#777777"
                                        }
                                        Text {
                                            text: (Waybar && Waybar.vpnBusy) ? "Проверка туннелей..." : (vpnScroll.wlVpnOn ? "Подключено" : "Отключено")
                                            color: (Waybar && Waybar.vpnBusy) ? "#ffd54f" : (vpnScroll.wlVpnOn ? "#69f0ae" : "#888888")
                                            font.pixelSize: Config.fontSize - 1
                                        }
                                        Text {
                                            visible: Waybar && Waybar.vpnStatusHint.length > 0
                                            text: "•  " + (Waybar ? Waybar.vpnStatusHint : "")
                                            color: "#888888"; font.pixelSize: Config.fontSize - 2
                                        }
                                    }
                                }

                                StyledSwitch {
                                    checked: vpnScroll.wlVpnOn
                                    onToggled: if (Waybar) Waybar.toggleVpnForMode(true)
                                }
                            }
                        }

                        // Карточка категорий Белых Списков
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: wlPanelCol.implicitHeight + 28

                            ColumnLayout {
                                id: wlPanelCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Item {
                                        width: 18; height: 18
                                        Text { anchors.centerIn: parent; text: "󰒃"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    }
                                    Text {
                                        text: "Категории белых списков"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: (Waybar && Waybar.vpnBusy) ? ("󰑐 " + Waybar.vpnProgressPercent + "%") : "󰓅 Проверить серверы"
                                        implicitHeight: 26
                                        enabled: !(Waybar && Waybar.vpnBusy)
                                        onClicked: if (Waybar) Waybar.testWhitelistServers()
                                    }
                                }

                                Item {
                                    id: wlCatContainer
                                    Layout.fillWidth: true
                                    implicitHeight: wlCatFlow.implicitHeight
                                    property bool isHovering: false
                                    property real hovX: 0
                                    property real hovY: 0
                                    property real hovW: 110
                                    property var activeItem: null

                                    Timer {
                                        id: wlCatHoverHold
                                        interval: 45
                                        onTriggered: wlCatContainer.isHovering = false
                                    }

                                    Rectangle {
                                        z: 2
                                        opacity: wlCatContainer.isHovering ? 1.0 : 0.0
                                        x: wlCatContainer.hovX; y: wlCatContainer.hovY
                                        width: wlCatContainer.hovW; height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config
                                               ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22)
                                               : Qt.rgba(1, 1, 1, 0.14)
                                        border.width: 1
                                        border.color: vpnScroll.isM3 && Config
                                                      ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.48)
                                                      : Qt.rgba(1, 1, 1, 0.28)
                                        Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 110 } }
                                    }

                                    Rectangle {
                                        z: 3
                                        visible: wlCatContainer.activeItem !== null
                                        x: wlCatContainer.activeItem ? wlCatContainer.activeItem.x : 0
                                        y: wlCatContainer.activeItem ? wlCatContainer.activeItem.y : 0
                                        width: wlCatContainer.activeItem ? wlCatContainer.activeItem.width : 110
                                        height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                    }

                                    Flow {
                                        id: wlCatFlow
                                        z: 4; width: parent.width; spacing: 5
                                        Repeater {
                                            id: wlCatRepeater
                                            model: Waybar ? Waybar.vpnWhitelistFiles : []
                                            delegate: Item {
                                                id: catBtn
                                                width: catContentRow.implicitWidth + 24; height: 28
                                                property bool isSel: Waybar && Waybar.vpnWhitelistFile === modelData.key
                                                readonly property var splitParts: {
                                                    var s = (modelData.label || "").trim()
                                                    if (!s) return { icon: "", label: "" }
                                                    var cp = s.codePointAt(0)
                                                    if (cp >= 0xE000) {
                                                        var chLen = cp > 0xFFFF ? 2 : 1
                                                        return { icon: s.slice(0, chLen), label: s.slice(chLen).trim() }
                                                    }
                                                    return { icon: "", label: s }
                                                }
                                                onIsSelChanged: if (isSel) wlCatContainer.activeItem = catBtn
                                                Component.onCompleted: if (isSel) wlCatContainer.activeItem = catBtn

                                                Rectangle {
                                                    anchors.fill: parent
                                                    z: -1
                                                    radius: vpnScroll.isM3 ? 8 : 0
                                                    color: catBtn.isSel
                                                           ? "transparent"
                                                           : (vpnScroll.isM3 && Config
                                                              ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.42)
                                                              : Qt.rgba(1, 1, 1, 0.06))
                                                    border.color: catBtn.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                                    border.width: vpnScroll.isM3 ? 0 : 1
                                                    Behavior on color { ColorAnimation { duration: 130 } }
                                                }

                                                Row {
                                                    id: catContentRow
                                                    anchors.centerIn: parent
                                                    spacing: catBtn.splitParts.icon.length > 0 ? 8 : 0

                                                    Item {
                                                        visible: catBtn.splitParts.icon.length > 0
                                                        width: 15; height: 16
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: catBtn.splitParts.icon
                                                            font.pixelSize: Config.fontSize
                                                            color: catTxt.color
                                                        }
                                                    }
                                                    Text {
                                                        id: catTxt
                                                        text: catBtn.splitParts.label
                                                        font.pixelSize: Config.fontSize - 1
                                                        font.bold: catBtn.isSel
                                                        color: catBtn.isSel
                                                               ? (Config ? Config.accentTextColor : "#000000")
                                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        Behavior on color { ColorAnimation { duration: 120 } }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onEntered: {
                                                        wlCatHoverHold.stop()
                                                        wlCatContainer.hovX = catBtn.x
                                                        wlCatContainer.hovY = catBtn.y
                                                        wlCatContainer.hovW = catBtn.width
                                                        wlCatContainer.isHovering = true
                                                    }
                                                    onExited: wlCatHoverHold.restart()
                                                    onPressed: if (Waybar) Waybar.vpnWhitelistFile = modelData.key
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 1
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Item {
                                        width: 18; height: 18
                                        Text { anchors.centerIn: parent; text: "󰌘"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 1 }
                                    }
                                    Text {
                                        text: "Свои подписки для белых списков"
                                        color: "#dddddd"; font.pixelSize: Config.fontSize; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnWlSubGroups.length > 0
                                        text: "󰑐 Обновить подписки"
                                        implicitHeight: 24
                                        enabled: !(Waybar && Waybar.vpnBusy)
                                        onClicked: if (Waybar) Waybar.updateVpnSubscription()
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnWlSubGroups.length > 0
                                        text: vpnScroll.hideSubLinks ? "󰈉 Показать ссылки" : "󰈈 Блюр ссылок"
                                        implicitHeight: 24
                                        isActive: vpnScroll.hideSubLinks
                                        onClicked: vpnScroll.hideSubLinks = !vpnScroll.hideSubLinks
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    TextField {
                                        id: wlSubUrlField
                                        Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                                        color: "#ffffff"; font.pixelSize: 11
                                        placeholderText: "Вставьте ссылку на подписку или ключи..."
                                        placeholderTextColor: "#777777"
                                        background: Rectangle {
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1,1,1,0.06)
                                            border.color: Qt.rgba(1,1,1,0.16)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                        }
                                    }
                                    StyledButton {
                                        text: "+ Добавить"
                                        implicitHeight: 28
                                        onClicked: {
                                            if (Waybar && wlSubUrlField.text.trim().length > 0) {
                                                Waybar.addVpnWlSubUrl(wlSubUrlField.text.trim())
                                                wlSubUrlField.text = ""
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: wlSubsBlurBox
                                    visible: Waybar && Waybar.vpnWlSubGroups.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: wlSubListCol.implicitHeight
                                    property bool isHovering: false
                                    property real hovY: 0

                                    Timer {
                                        id: wlSubHoverHold
                                        interval: 45
                                        onTriggered: wlSubsBlurBox.isHovering = false
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: wlSubsBlurBox.isHovering ? 1.0 : 0.0
                                        x: 0; y: wlSubsBlurBox.hovY
                                        width: wlSubsBlurBox.width; height: 34
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.10)
                                        Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }

                                    ColumnLayout {
                                        id: wlSubListCol
                                        z: 2; width: parent.width; spacing: 6

                                        Repeater {
                                            model: Waybar ? Waybar.vpnWlSubGroups : []
                                            delegate: Rectangle {
                                                id: wlSubRowItem
                                                Layout.fillWidth: true; implicitHeight: 34
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: vpnScroll.isM3 && Config
                                                       ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.14); border.width: 1
                                                clip: true

                                                MouseArea {
                                                    anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                                    onEntered: {
                                                        wlSubHoverHold.stop()
                                                        wlSubsBlurBox.hovY = wlSubRowItem.y
                                                        wlSubsBlurBox.isHovering = true
                                                    }
                                                    onExited: wlSubHoverHold.restart()
                                                }

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8

                                                    Item {
                                                        id: wlUrlBlurWrap
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        layer.enabled: vpnScroll.hideSubLinks
                                                        layer.smooth: true
                                                        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 0.22)), Math.max(1, Math.round(height * 0.35)))
                                                        layer.effect: ShaderEffect {
                                                            property var source: wlUrlBlurWrap
                                                            property vector2d u_resolution: Qt.vector2d(Math.max(1, wlUrlBlurWrap.width * 0.22), Math.max(1, wlUrlBlurWrap.height * 0.35))
                                                            property real u_blur: 0.45
                                                            fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                                                        }

                                                        Text {
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: parent.width
                                                            text: modelData.title + " • " + modelData.count + " серв. • " + modelData.url
                                                            color: "#ffffff"; font.pixelSize: 10; font.bold: true
                                                            elide: Text.ElideMiddle
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: (modelData.country || "").length > 0
                                                        width: wlSubCountryTxt.implicitWidth + 12
                                                        height: 22
                                                        radius: vpnScroll.isM3 ? 6 : 0
                                                        color: vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10)
                                                        Text {
                                                            id: wlSubCountryTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.country || ""
                                                            font.pixelSize: Config.fontSize - 2
                                                            font.bold: true
                                                            color: vpnScroll.isM3 && Config ? Config.m3Primary : "#ffffff"
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: (modelData.ping || "").length > 0
                                                        width: wlSubPingBadgeTxt.implicitWidth + 12
                                                        height: 22
                                                        radius: vpnScroll.isM3 ? 6 : 0
                                                        color: Qt.rgba(0.4, 0.95, 0.68, 0.16)
                                                        Text {
                                                            id: wlSubPingBadgeTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.ping || ""
                                                            font.pixelSize: Config.fontSize - 2
                                                            font.bold: true
                                                            font.features: { "tnum": 1 }
                                                            color: "#69f0ae"
                                                        }
                                                    }

                                                    StyledButton {
                                                        text: vpnScroll.copiedWlSubIdx === index ? "󰄬 Скопировано" : "󰆏 Копировать"
                                                        implicitHeight: 22
                                                        isActive: vpnScroll.copiedWlSubIdx === index
                                                        onClicked: {
                                                            if (Waybar) {
                                                                var safeUrl = modelData.url.replace(/'/g, "'\\''");
                                                                Waybar.runCommand("printf '%s' '" + safeUrl + "' | wl-copy");
                                                                vpnScroll.copiedWlSubIdx = index;
                                                                copyResetTimer.restart();
                                                            }
                                                        }
                                                    }
                                                    StyledButton {
                                                        text: "󰅖 Удалить"
                                                        implicitHeight: 22
                                                        onClicked: if (Waybar) Waybar.removeVpnWlSubUrl(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Карточка серверов Белого Списка
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: wlSrvCol.implicitHeight + 28

                            ColumnLayout {
                                id: wlSrvCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Item {
                                        width: 18; height: 18
                                        Text { anchors.centerIn: parent; text: "󰒃"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    }
                                    Text {
                                        text: "Серверы белого списка • " + (Waybar ? Waybar.vpnWlServerItems.length : 0)
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        visible: Waybar && Waybar.vpnFrozenCount > 0
                                        text: "󰑐 Разморозить все"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.clearFrozenVpnServers()
                                    }
                                }

                                Text {
                                    visible: !Waybar || Waybar.vpnWlServerItems.length === 0
                                    text: "Нет серверов в выбранной категории. Нажмите «Обновить списки» или добавьте свою подписку."
                                    color: "#888888"; font.pixelSize: Config.fontSize - 1
                                }

                                Item {
                                    id: wlSrvListWrap
                                    visible: Waybar && Waybar.vpnWlServerItems.length > 0
                                    Layout.fillWidth: true
                                    implicitHeight: Math.min(wlSrvList.contentHeight, 238)
                                    clip: true
                                    property bool isHovering: false
                                    property int lastHoveredRow: 0

                                    Timer {
                                        id: wlSrvHoverHold
                                        interval: 45
                                        onTriggered: wlSrvListWrap.isHovering = false
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: wlSrvListWrap.isHovering ? 1.0 : 0.0
                                        x: 0; y: wlSrvListWrap.lastHoveredRow * 34 - wlSrvList.contentY
                                        width: wlSrvList.width; height: 30
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.10)
                                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }

                                    ListView {
                                        id: wlSrvList
                                        z: 2; anchors.fill: parent; spacing: 4
                                        cacheBuffer: 600
                                        boundsBehavior: Flickable.StopAtBounds
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                        property real savedContentY: 0
                                        property string lastWlKey: Waybar ? Waybar.vpnWhitelistFile : ""
                                        onContentYChanged: if (!moving && contentY >= 0) savedContentY = contentY
                                        model: (Waybar && vpnScroll.wlScreenVis) ? Waybar.vpnWlServerItems : []
                                        onModelChanged: {
                                            var curKey = Waybar ? Waybar.vpnWhitelistFile : ""
                                            if (lastWlKey !== curKey) {
                                                lastWlKey = curKey
                                                savedContentY = 0
                                                contentY = 0
                                            } else if (savedContentY > 0) {
                                                var restoreY = savedContentY
                                                Qt.callLater(function() {
                                                    var maxY = Math.max(0, wlSrvList.contentHeight - wlSrvList.height)
                                                    wlSrvList.contentY = Math.min(restoreY, maxY)
                                                })
                                            }
                                        }

                                        delegate: Rectangle {
                                            width: wlSrvList.width; height: 30
                                            property int realIdx: modelData.global_index !== undefined ? modelData.global_index : index
                                            property bool isSel: Waybar && Waybar.vpnWlSelectedServer === realIdx
                                            property bool isFrz: modelData.frozen === true
                                            property bool isPin: modelData.pinned === true
                                            property string srvUri: modelData.uri || ""
                                            property string srvSig: modelData.sig || ("wl_" + index)
                                            property var parsed: vpnScroll.parseServerItem(modelData.name || "", true)
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            opacity: isFrz ? 0.42 : 1.0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (isFrz
                                                      ? Qt.rgba(0, 0, 0, 0.42)
                                                      : (isPin
                                                         ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                                                         : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))))
                                            border.color: isSel
                                                          ? "transparent"
                                                          : (isPin
                                                             ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.55) : Qt.rgba(1, 1, 1, 0.45))
                                                             : Qt.rgba(1, 1, 1, 0.14))
                                            border.width: (isPin && !isSel) ? 1 : (vpnScroll.isM3 ? 0 : 1)
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    wlSrvHoverHold.stop()
                                                    wlSrvListWrap.lastHoveredRow = index
                                                    wlSrvListWrap.isHovering = true
                                                }
                                                onExited: wlSrvHoverHold.restart()
                                                onClicked: if (Waybar) Waybar.selectVpnServer(parent.realIdx)
                                            }

                                            RowLayout {
                                                z: 5
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8

                                                Item {
                                                    width: 16; height: 16
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isFrz ? "󰜺" : (isPin ? "󰐃" : parsed.icon)
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : (isFrz ? "#ff8a80" : (isPin ? "#69f0ae" : (Config ? Config.m3Primary : "#ffffff")))
                                                        font.pixelSize: Config.fontSize + 1
                                                    }
                                                }

                                                Rectangle {
                                                    visible: isPin && !isFrz
                                                    width: pinBadgeTxt.implicitWidth + 10; height: 18
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0.4, 0.95, 0.68, 0.20)
                                                    Text {
                                                        id: pinBadgeTxt; anchors.centerIn: parent
                                                        text: "ЗАКРЕПЛЕН"
                                                        font.pixelSize: Config.fontSize - 2; font.bold: true
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
                                                    }
                                                }

                                                Rectangle {
                                                    visible: isFrz
                                                    width: frzBadgeTxt.implicitWidth + 10; height: 18
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: Qt.rgba(1, 0.35, 0.35, 0.22)
                                                    Text {
                                                        id: frzBadgeTxt; anchors.centerIn: parent
                                                        text: "ЗАМОРОЖЕН"
                                                        font.pixelSize: Config.fontSize - 2; font.bold: true
                                                        color: "#ff8a80"
                                                    }
                                                }

                                                Rectangle {
                                                    visible: !isFrz && parsed.badge.length > 0
                                                    width: badgeTxt.implicitWidth + 12
                                                    height: 18
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel
                                                           ? Qt.rgba(0, 0, 0, 0.18)
                                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10))

                                                    Text {
                                                        id: badgeTxt
                                                        anchors.centerIn: parent
                                                        text: parsed.badge
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        color: isSel
                                                               ? (Config ? Config.accentTextColor : "#000000")
                                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#dddddd")
                                                    }
                                                }

                                                Text {
                                                    text: parsed.title
                                                    color: isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                                    font.pixelSize: Config.fontSize
                                                    font.bold: isSel
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }

                                                Rectangle {
                                                    readonly property string ccLbl: modelData.country || ""
                                                    visible: !isFrz && ccLbl.length > 0
                                                    width: wlSrvCcTxt.implicitWidth + 10
                                                    height: 20
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.18) : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10))
                                                    Text {
                                                        id: wlSrvCcTxt
                                                        anchors.centerIn: parent
                                                        text: parent.ccLbl
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : (vpnScroll.isM3 && Config ? Config.m3Primary : "#dddddd")
                                                    }
                                                }

                                                Rectangle {
                                                    readonly property string pingLbl: modelData.ping || parsed.ping || ""
                                                    visible: !isFrz && pingLbl.length > 0
                                                    width: pingTxt.implicitWidth + 10
                                                    height: 20
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0.4, 0.95, 0.68, 0.16)

                                                    Text {
                                                        id: pingTxt
                                                        anchors.centerIn: parent
                                                        text: parent.pingLbl
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        font.features: { "tnum": 1 }
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
                                                    }
                                                }

                                                StyledButton {
                                                    visible: srvUri.length > 0
                                                    text: vpnScroll.copiedSrvSig === srvSig ? "󰄬" : "󰆏"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: vpnScroll.copiedSrvSig === srvSig
                                                    onClicked: {
                                                        if (Waybar && srvUri.length > 0) {
                                                            var safeU = srvUri.replace(/'/g, "'\\''");
                                                            Waybar.runCommand("printf '%s' '" + safeU + "' | wl-copy");
                                                            vpnScroll.copiedSrvSig = srvSig;
                                                            copyResetTimer.restart();
                                                        }
                                                    }
                                                }

                                                StyledButton {
                                                    visible: index > 0
                                                    text: "󰐃"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: isPin
                                                    onClicked: if (Waybar) Waybar.togglePinVpnServer(realIdx, true)
                                                }

                                                StyledButton {
                                                    visible: index > 0
                                                    text: isFrz ? "󰑐" : "󰜺"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: isFrz
                                                    onClicked: if (Waybar) Waybar.toggleFreezeVpnServer(realIdx, true)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SplitTunnelCard {}

                        VpnLogsCard { activeScreen: vpnScroll.wlScreenVis }
                    }
                }
            }
        }
    }
}
