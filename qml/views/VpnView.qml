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
    property int activeSubTab: 0
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property bool isWlMode: Waybar ? Waybar.vpnWhitelistMode : false
    property real modeSlideProgress: isWlMode ? 1.0 : 0.0
    Behavior on modeSlideProgress { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

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

    property int logViewHeight: 160
    property bool copiedLogs: false

    Timer {
        interval: 1500
        repeat: true
        running: vpnScroll.visible && Waybar && Waybar.vpnLogAutoRefresh && (ApplicationWindow.window ? ApplicationWindow.window.drawerActive : true)
        triggeredOnStart: true
        onTriggered: if (Waybar) Waybar.refreshVpnLogs()
    }

    component VpnLogsCard: GlassPanel {
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

            // Настройки длины (лимит строк + высота окна) и поведения (автообновление, автоскролл, уровень логов)
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
                    from: 90; to: 340; stepSize: 10
                    value: vpnScroll.logViewHeight
                    onMoved: vpnScroll.logViewHeight = Math.round(value)
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
                    onToggled: if (Waybar) Waybar.vpnLogAutoScroll = checked
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Строк: " + (Waybar ? Waybar.vpnLogs.length : 0)
                    color: "#888888"; font.pixelSize: Config.fontSize - 2
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: vpnScroll.logViewHeight
                radius: vpnScroll.isM3 ? 8 : 0
                color: Qt.rgba(0, 0, 0, 0.28)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                clip: true

                ListView {
                    id: logListView
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    model: Waybar ? Waybar.vpnLogs : []
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    onCountChanged: {
                        if (Waybar && Waybar.vpnLogAutoScroll && count > 0) {
                            Qt.callLater(() => logListView.positionViewAtEnd())
                        }
                    }

                    delegate: Text {
                        width: logListView.width - 10
                        text: modelData
                        font.family: "monospace"
                        font.pixelSize: 10
                        wrapMode: Text.WrapAnywhere
                        color: {
                            var s = (modelData || "").toLowerCase()
                            if (s.indexOf("error") !== -1 || s.indexOf("fatal") !== -1) return "#ff8a80"
                            if (s.indexOf("warn") !== -1) return "#ffd54f"
                            if (s.indexOf("outbound/vless") !== -1 || s.indexOf(" proxy") !== -1) return "#69f0ae"
                            return "#cccccc"
                        }
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

    Item {
        width: vpnScroll.availableWidth
        implicitHeight: topHeaderCol.implicitHeight + fullPageSlider.implicitHeight + 52

        ColumnLayout {
            id: topHeaderCol
            width: Math.min(parent.width - 48, 780)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 18
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
                StyledButton {
                    text: (Waybar && Waybar.vpnBusy) ? "󰑐 Синхронизация..." : "󰊢 Обновить списки"
                    implicitHeight: 26
                    enabled: !(Waybar && Waybar.vpnBusy)
                    onClicked: if (Waybar) Waybar.updateBypassLists()
                }
                StyledButton {
                    text: "󰑐 Обновить подписки"
                    implicitHeight: 26
                    enabled: !(Waybar && Waybar.vpnBusy)
                    onClicked: if (Waybar) Waybar.updateVpnSubscription()
                }
            }

            // Переключение по нажатию мыши (onPressed внутри SegmentedButton)
            SegmentedButton {
                Layout.fillWidth: true
                implicitHeight: 34
                options: [
                    "󰦝 Обычный VPN",
                    "󰒃 Белые списки"
                ]
                selectedIndex: vpnScroll.isWlMode ? 1 : 0
                onSelected: (idx) => {
                    if (Waybar) Waybar.vpnWhitelistMode = (idx === 1)
                }
            }
        }

        Item {
            id: fullPageSlider
            anchors.top: topHeaderCol.bottom
            anchors.topMargin: 12
            width: parent.width
            implicitHeight: vpnScroll.isWlMode ? wlFullCol.implicitHeight : normalFullCol.implicitHeight
            Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

            Row {
                width: fullPageSlider.width * 2
                x: -vpnScroll.modeSlideProgress * fullPageSlider.width

                // =========================================================================
                // ЭКРАН 0: ОБЫЧНЫЙ VPN
                // =========================================================================
                Item {
                    width: fullPageSlider.width
                    implicitHeight: normalFullCol.implicitHeight

                    ColumnLayout {
                        id: normalFullCol
                        width: Math.min(parent.width - 48, 780)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 12 : 0
                                    color: (Waybar && Waybar.vpnActive && !vpnScroll.isWlMode)
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    Text {
                                        anchors.centerIn: parent; text: "󰦝"; font.pixelSize: 20
                                        color: (Waybar && Waybar.vpnActive && !vpnScroll.isWlMode)
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
                                            color: (Waybar && Waybar.vpnActive && !vpnScroll.isWlMode) ? "#69f0ae" : "#777777"
                                        }
                                        Text {
                                            text: (Waybar && Waybar.vpnActive && !vpnScroll.isWlMode) ? "Подключено" : "Отключено"
                                            color: (Waybar && Waybar.vpnActive && !vpnScroll.isWlMode) ? "#69f0ae" : "#888888"
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
                                    checked: Waybar ? Waybar.vpnActive : false
                                    onToggled: if (Waybar) Waybar.toggleVpn()
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
                                        visible: Waybar && (vpnScroll.isWlMode ? Waybar.vpnWlSubGroups.length > 0 : Waybar.vpnSubGroups.length > 0)
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
                                    property bool isHovering: false
                                    property real hovX: 0
                                    property real hovY: 0
                                    property real hovW: 90
                                    property var activeItem: allSubTabBtn

                                    Timer {
                                        id: subTabHoverHold
                                        interval: 45
                                        onTriggered: subTabBar.isHovering = false
                                    }

                                    Rectangle {
                                        z: 2
                                        opacity: subTabBar.isHovering ? 1.0 : 0.0
                                        x: subTabBar.hovX; y: subTabBar.hovY
                                        width: subTabBar.hovW; height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.14)
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
                                    }

                                    Rectangle {
                                        z: 3
                                        visible: subTabBar.activeItem !== null
                                        x: subTabBar.activeItem ? subTabBar.activeItem.x : 0
                                        y: subTabBar.activeItem ? subTabBar.activeItem.y : 0
                                        width: subTabBar.activeItem ? subTabBar.activeItem.width : 90
                                        height: 28
                                        radius: vpnScroll.isM3 ? 8 : 0
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                    }

                                    Flow {
                                        z: 1
                                        width: parent.width; spacing: 5
                                        Rectangle {
                                            width: allSubTabBtn.width; height: 28
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.16); border.width: vpnScroll.isM3 ? 0 : 1
                                        }
                                        Repeater {
                                            model: Waybar ? Waybar.vpnSubGroups : []
                                            delegate: Rectangle {
                                                width: oneSubTabRepeater.itemAt(index) ? oneSubTabRepeater.itemAt(index).width : 100
                                                height: 28
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: Qt.rgba(1, 1, 1, 0.16); border.width: vpnScroll.isM3 ? 0 : 1
                                            }
                                        }
                                    }

                                    Flow {
                                        id: subTabFlow
                                        z: 4; width: parent.width; spacing: 5

                                        Item {
                                            id: allSubTabBtn
                                            width: allSubTabTxt.implicitWidth + 24; height: 28
                                            property bool isSel: vpnScroll.activeSubTab === 0
                                            onIsSelChanged: if (isSel) subTabBar.activeItem = allSubTabBtn

                                            Text {
                                                id: allSubTabTxt; anchors.centerIn: parent
                                                text: "Все • " + (Waybar ? Waybar.vpnSubServers.length : 0)
                                                font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                color: parent.isSel
                                                       ? (Config ? Config.accentTextColor : "#000000")
                                                       : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                            }
                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    subTabHoverHold.stop()
                                                    subTabBar.hovX = allSubTabBtn.x
                                                    subTabBar.hovY = allSubTabBtn.y
                                                    subTabBar.hovW = allSubTabBtn.width
                                                    subTabBar.isHovering = true
                                                }
                                                onExited: subTabHoverHold.restart()
                                                onPressed: vpnScroll.activeSubTab = 0
                                            }
                                        }

                                        Repeater {
                                            id: oneSubTabRepeater
                                            model: Waybar ? Waybar.vpnSubGroups : []
                                            delegate: Item {
                                                id: oneSubTabBtn
                                                width: oneSubTabTxt.implicitWidth + 24; height: 28
                                                property bool isSel: vpnScroll.activeSubTab === (index + 1)
                                                onIsSelChanged: if (isSel) subTabBar.activeItem = oneSubTabBtn

                                                Text {
                                                    id: oneSubTabTxt; anchors.centerIn: parent
                                                    text: modelData.title + " • " + modelData.count
                                                    font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                    color: parent.isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onEntered: {
                                                        subTabHoverHold.stop()
                                                        subTabBar.hovX = oneSubTabBtn.x
                                                        subTabBar.hovY = oneSubTabBtn.y
                                                        subTabBar.hovW = oneSubTabBtn.width
                                                        subTabBar.isHovering = true
                                                    }
                                                    onExited: subTabHoverHold.restart()
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

                                    layer.enabled: vpnScroll.hideSubLinks
                                    layer.smooth: true
                                    layer.effect: ShaderEffect {
                                        property vector2d u_resolution: Qt.vector2d(Math.max(1, urlsBlurBox.width), Math.max(1, urlsBlurBox.height))
                                        property real u_blur: 0.92
                                        fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: urlsBlurBox.isHovering ? 1.0 : 0.0
                                        x: 0; y: urlsBlurBox.hovY
                                        width: urlsBlurBox.width; height: 32
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
                                                visible: vpnScroll.activeSubTab === 0 || vpnScroll.activeSubTab === (index + 1)
                                                Layout.fillWidth: true; implicitHeight: 32
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

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
                                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 6
                                                    Text {
                                                        text: modelData.title + " • " + modelData.count + " серв. • " + modelData.url
                                                        color: "#ffffff"; font.pixelSize: 10
                                                        Layout.fillWidth: true; elide: Text.ElideMiddle
                                                    }
                                                    StyledButton {
                                                        text: vpnScroll.copiedSubIdx === index ? "󰄬 Скопировано" : "󰆏 Копировать"
                                                        implicitHeight: 22
                                                        isActive: vpnScroll.copiedSubIdx === index
                                                        enabled: !vpnScroll.hideSubLinks
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
                                                        enabled: !vpnScroll.hideSubLinks
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

                        // Карточка серверов Обычного VPN (с копированием ключа и заморозкой)
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
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                        model: {
                                            if (!Waybar) return [];
                                            if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                                return Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1].servers;
                                            }
                                            return Waybar.vpnSubServerItems;
                                        }

                                        delegate: Rectangle {
                                            width: normalSrvList.width; height: 30
                                            property int realIdx: modelData.global_index !== undefined ? modelData.global_index : index
                                            property bool isSel: Waybar && Waybar.vpnSubSelectedServer === realIdx
                                            property bool isFrz: modelData.frozen === true
                                            property string srvUri: modelData.uri || ""
                                            property string srvSig: modelData.sig || ("sub_" + realIdx)
                                            property var parsed: vpnScroll.parseServerItem(modelData.name !== undefined ? modelData.name : modelData, false)
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            opacity: isFrz ? 0.55 : 1.0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    normalSrvHoverHold.stop()
                                                    normalSrvListWrap.lastHoveredRow = index
                                                    normalSrvListWrap.isHovering = true
                                                }
                                                onExited: normalSrvHoverHold.restart()
                                                onPressed: if (Waybar) Waybar.selectVpnServer(parent.realIdx)
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

                        VpnLogsCard {}
                    }
                }

                // =========================================================================
                // ЭКРАН 1: БЕЛЫЕ СПИСКИ
                // =========================================================================
                Item {
                    width: fullPageSlider.width
                    implicitHeight: wlFullCol.implicitHeight

                    ColumnLayout {
                        id: wlFullCol
                        width: Math.min(parent.width - 48, 780)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 12 : 0
                                    color: (Waybar && Waybar.vpnActive && vpnScroll.isWlMode)
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    Text {
                                        anchors.centerIn: parent; text: "󰒃"; font.pixelSize: 20
                                        color: (Waybar && Waybar.vpnActive && vpnScroll.isWlMode)
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
                                            color: (Waybar && Waybar.vpnActive && vpnScroll.isWlMode) ? "#69f0ae" : "#777777"
                                        }
                                        Text {
                                            text: (Waybar && Waybar.vpnBusy) ? "Проверка туннелей..." : ((Waybar && Waybar.vpnActive && vpnScroll.isWlMode) ? "Подключено" : "Отключено")
                                            color: (Waybar && Waybar.vpnBusy) ? "#ffd54f" : ((Waybar && Waybar.vpnActive && vpnScroll.isWlMode) ? "#69f0ae" : "#888888")
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
                                    checked: Waybar ? Waybar.vpnActive : false
                                    onToggled: if (Waybar) Waybar.toggleVpn()
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
                                        text: (Waybar && Waybar.vpnBusy) ? "󰑐 Проверка..." : "󰓅 Проверить серверы"
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
                                        color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.14)
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on opacity { NumberAnimation { duration: 130 } }
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
                                        z: 1
                                        width: parent.width; spacing: 5
                                        Repeater {
                                            model: Waybar ? Waybar.vpnWhitelistFiles : []
                                            delegate: Rectangle {
                                                width: wlCatRepeater.itemAt(index) ? wlCatRepeater.itemAt(index).width : 110
                                                height: 28
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: Qt.rgba(1, 1, 1, 0.16)
                                                border.width: vpnScroll.isM3 ? 0 : 1
                                            }
                                        }
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
                                        visible: Waybar && (vpnScroll.isWlMode ? Waybar.vpnWlSubGroups.length > 0 : Waybar.vpnSubGroups.length > 0)
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

                                    layer.enabled: vpnScroll.hideSubLinks
                                    layer.smooth: true
                                    layer.effect: ShaderEffect {
                                        property vector2d u_resolution: Qt.vector2d(Math.max(1, wlSubsBlurBox.width), Math.max(1, wlSubsBlurBox.height))
                                        property real u_blur: 0.92
                                        fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                                    }

                                    Rectangle {
                                        z: 1
                                        opacity: wlSubsBlurBox.isHovering ? 1.0 : 0.0
                                        x: 0; y: wlSubsBlurBox.hovY
                                        width: wlSubsBlurBox.width; height: 32
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
                                                Layout.fillWidth: true; implicitHeight: 32
                                                radius: vpnScroll.isM3 ? 8 : 0
                                                color: Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.14); border.width: 1

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
                                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 6
                                                    Text {
                                                        text: modelData.title + " • " + modelData.count + " серв. • " + modelData.url
                                                        color: "#ffffff"; font.pixelSize: 10; font.bold: true
                                                        Layout.fillWidth: true; elide: Text.ElideMiddle
                                                    }
                                                    StyledButton {
                                                        text: vpnScroll.copiedWlSubIdx === index ? "󰄬 Скопировано" : "󰆏 Копировать"
                                                        implicitHeight: 22
                                                        isActive: vpnScroll.copiedWlSubIdx === index
                                                        enabled: !vpnScroll.hideSubLinks
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
                                                        enabled: !vpnScroll.hideSubLinks
                                                        onClicked: if (Waybar) Waybar.removeVpnWlSubUrl(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Карточка серверов Белого Списка (с копированием ключа и заморозкой)
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
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                        model: Waybar ? Waybar.vpnWlServerItems : []

                                        delegate: Rectangle {
                                            width: wlSrvList.width; height: 30
                                            property bool isSel: Waybar && Waybar.vpnWlSelectedServer === index
                                            property bool isFrz: modelData.frozen === true
                                            property string srvUri: modelData.uri || ""
                                            property string srvSig: modelData.sig || ("wl_" + index)
                                            property var parsed: vpnScroll.parseServerItem(modelData.name || "", true)
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            opacity: isFrz ? 0.55 : 1.0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    wlSrvHoverHold.stop()
                                                    wlSrvListWrap.lastHoveredRow = index
                                                    wlSrvListWrap.isHovering = true
                                                }
                                                onExited: wlSrvHoverHold.restart()
                                                onPressed: if (Waybar) Waybar.selectVpnServer(index)
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

                                                Rectangle {
                                                    visible: !isFrz && parsed.ping.length > 0
                                                    width: pingTxt.implicitWidth + 10
                                                    height: 18
                                                    radius: vpnScroll.isM3 ? 5 : 0
                                                    color: isSel ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0.4, 0.95, 0.68, 0.16)

                                                    Text {
                                                        id: pingTxt
                                                        anchors.centerIn: parent
                                                        text: parsed.ping
                                                        font.pixelSize: Config.fontSize - 2
                                                        font.bold: true
                                                        color: isSel ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
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
                                                    text: isFrz ? "󰑐" : "󰜺"
                                                    implicitWidth: 24; implicitHeight: 22
                                                    isActive: isFrz
                                                    onClicked: if (Waybar) Waybar.toggleFreezeVpnServer(index, true)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SplitTunnelCard {}

                        VpnLogsCard {}
                    }
                }
            }
        }
    }
}
