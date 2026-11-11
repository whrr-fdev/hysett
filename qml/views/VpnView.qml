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
    property int activeSubTab: 0
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property bool isWlMode: Waybar ? Waybar.vpnWhitelistMode : false
    property real modeSlideProgress: isWlMode ? 1.0 : 0.0
    Behavior on modeSlideProgress { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

    contentWidth: availableWidth
    clip: true

    Timer {
        id: copyResetTimer
        interval: 1300
        onTriggered: {
            vpnScroll.copiedSubIdx = -1
            vpnScroll.copiedWlSubIdx = -1
        }
    }

    // Reusable inline component for Split Tunneling card (used on both pages of the full-page slider)
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
                Text {
                    text: "󰒓"
                    color: Config ? Config.m3Primary : "#ffffff"
                    font.pixelSize: Config.fontSize + 2
                }
                Text {
                    text: "Раздельное туннелирование (Split Tunneling + allow-domains / Re-filter)"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    Layout.fillWidth: true
                }
            }

            SegmentedButton {
                Layout.fillWidth: true
                implicitHeight: 30
                options: [
                    "󰈀 Обход РФ (RU Direct)",
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
                        return "Через VPN идут только заблокированные сайты и сервисы из списков (YouTube, Discord + голос, Telegram, ChatGPT, Instagram, X, HDRezka, Re-filter). Весь остальной трафик и игры идут напрямую.";
                    if (Waybar.vpnSplitMode === "all_vpn")
                        return "Весь трафик системы маршрутизируется через VPN-туннель (кроме доменов, добавленных в исключения ниже).";
                    return "Российские сайты (inside-raw.lst, .ru, .рф, Госуслуги, Банки, ВК, Яндекс, Ozon, WB) идут напрямую без потери скорости, но заблокированные сайты РФ (outside-raw.lst) и зарубежные ресурсы идут через VPN.";
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                TextField {
                    id: customDomField
                    Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                    color: "#ffffff"; font.pixelSize: 11
                    placeholderText: "Свой домен (например: kinopub.me или mybank.ru)..."
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

        // ВЕРХНЯЯ ШАПКА И ПЕРЕКЛЮЧАТЕЛЬ ВСЕГО ЭКРАНА (VPN <-> БЕЛЫЕ СПИСКИ)
        ColumnLayout {
            id: topHeaderCol
            width: Math.min(parent.width - 48, 780)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: "󰦝"
                    color: Config ? Config.m3Primary : "#ffffff"
                    font.pixelSize: Config.fontSize + 4
                }
                Text {
                    text: "VPN и Обход блокировок"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: (Waybar && Waybar.vpnBusy) ? "󰑐 Синхронизация..." : "󰊢 Обновить списки (Git)"
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

            // Переключатель режимов в едином стиле SegmentedButton (как на остальных вкладках)
            SegmentedButton {
                Layout.fillWidth: true
                implicitHeight: 34
                options: [
                    "󰦝 Обычный VPN (Мои подписки)",
                    "󰒃 Обход Белых Списков (БС)"
                ]
                selectedIndex: vpnScroll.isWlMode ? 1 : 0
                onSelected: (idx) => {
                    if (Waybar) Waybar.vpnWhitelistMode = (idx === 1)
                }
            }
        }

        // ПОЛНОЦЕННЫЙ ГОРИЗОНТАЛЬНЫЙ СЛАЙДЕР ВСЕЙ ВКЛАДКИ (ВО ВСЮ ШИРИНУ ОКНА БЕЗ ОБРЕЗКИ КАРТОЧЕК)
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
                // ЭКРАН 0: ПОЛНАЯ СТРАНИЦА «ОБЫЧНЫЙ VPN (МОИ ПОДПИСКИ)»
                // =========================================================================
                Item {
                    width: fullPageSlider.width
                    implicitHeight: normalFullCol.implicitHeight

                    ColumnLayout {
                        id: normalFullCol
                        width: Math.min(parent.width - 48, 780)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        // Карточка включения Обычного VPN
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 12 : 0
                                    color: (Waybar && Waybar.vpnActive)
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    Text {
                                        anchors.centerIn: parent; text: "󰦝"; font.pixelSize: 20
                                        color: (Waybar && Waybar.vpnActive)
                                               ? (Config ? Config.accentTextColor : "#000000")
                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    Text {
                                        text: Waybar ? Waybar.vpnServerName : "VPN"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 2; font.bold: true
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: 10
                                        Text {
                                            text: (Waybar && Waybar.vpnBusy) ? "󰑐 Обновление..." : ((Waybar && Waybar.vpnActive) ? "󰄬 Подключено (sing-box TUN)" : "○ Отключено")
                                            color: (Waybar && Waybar.vpnBusy) ? "#ffd54f" : ((Waybar && Waybar.vpnActive) ? "#69f0ae" : "#888888")
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

                        // Карточка управления подписками и вкладками подписок
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: subTabsCol.implicitHeight + 28

                            ColumnLayout {
                                id: subTabsCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "󰌘"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    Text {
                                        text: "Мои подписки и ключи"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: vpnScroll.hideSubLinks ? "󰈉 Показать ссылки" : "󰈈 Скрыть ссылки (блюр)"
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
                                        placeholderText: "Вставьте ссылку на подписку (https://...) или vless:// ключ..."
                                        placeholderTextColor: "#777777"
                                        background: Rectangle {
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1,1,1,0.06)
                                            border.color: Qt.rgba(1,1,1,0.16)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                        }
                                    }
                                    StyledButton {
                                        text: "+ Добавить подписку"
                                        implicitHeight: 28
                                        onClicked: {
                                            if (Waybar && subUrlField.text.trim().length > 0) {
                                                Waybar.addVpnSubUrl(subUrlField.text.trim())
                                                subUrlField.text = ""
                                            }
                                        }
                                    }
                                }

                                // Вкладки подписок (правильный z-order: фоны z:1, наведение z:2, активная плашка z:3, текст z:4)
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

                                    // Слой 2: Плавная плашка наведения
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

                                    // Слой 3: Активная плашка выбора (ПОВЕРХ фонов кнопок!)
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

                                    // Слой 1 (фоны): подложены под плашки
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

                                    // Слой 4: Только текст и MouseArea (без закрашивающего фона!)
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
                                                text: "Все (" + (Waybar ? Waybar.vpnServers.length : 0) + ")"
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
                                                onClicked: vpnScroll.activeSubTab = 0
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
                                                    text: modelData.title + " (" + modelData.count + ")"
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
                                                    onClicked: vpnScroll.activeSubTab = index + 1
                                                }
                                            }
                                        }
                                    }
                                }

                                // Список ссылок подписок с копированием и удалением
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
                                                        text: modelData.title + " [" + modelData.count + " серв.]  •  " + modelData.url
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
                                    Text { text: "󰈀"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    Text {
                                        text: {
                                            if (!Waybar) return "Серверы подписок";
                                            if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                                var g = Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1];
                                                return "Серверы из «" + g.title + "» (" + g.count + ")";
                                            }
                                            return "Доступные серверы подписок (" + (vpnScroll.isWlMode ? 0 : Waybar.vpnServers.length) + ")";
                                        }
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    visible: !Waybar || vpnScroll.isWlMode || Waybar.vpnServers.length === 0
                                    text: "Нет добавленных серверов. Вставьте ссылку на подписку или vless:// ключ выше."
                                    color: "#888888"; font.pixelSize: Config.fontSize - 1
                                }

                                Item {
                                    id: normalSrvListWrap
                                    visible: Waybar && !vpnScroll.isWlMode && Waybar.vpnServers.length > 0
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
                                            if (!Waybar || vpnScroll.isWlMode) return [];
                                            if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                                return Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1].servers;
                                            }
                                            var res = [];
                                            for (var i = 0; i < Waybar.vpnServers.length; ++i) {
                                                res.push({ name: Waybar.vpnServers[i], global_index: i });
                                            }
                                            return res;
                                        }

                                        delegate: Rectangle {
                                            width: normalSrvList.width; height: 30
                                            property int realIdx: modelData.global_index !== undefined ? modelData.global_index : index
                                            property bool isSel: Waybar && Waybar.vpnSelectedServer === realIdx
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                                Text {
                                                    text: modelData.name !== undefined ? modelData.name : modelData
                                                    color: parent.parent.isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                                    font.pixelSize: Config.fontSize
                                                    font.bold: parent.parent.isSel
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                                Text {
                                                    visible: parent.parent.isSel
                                                    text: "󰄬"
                                                    color: Config ? Config.accentTextColor : "#000000"
                                                    font.pixelSize: Config.fontSize
                                                }
                                            }
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
                                        }
                                    }
                                }
                            }
                        }

                        SplitTunnelCard {}
                    }
                }

                // =========================================================================
                // ЭКРАН 1: ПОЛНАЯ СТРАНИЦА «ОБХОД БЕЛЫХ СПИСКОВ (БС)»
                // =========================================================================
                Item {
                    width: fullPageSlider.width
                    implicitHeight: wlFullCol.implicitHeight

                    ColumnLayout {
                        id: wlFullCol
                        width: Math.min(parent.width - 48, 780)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        // Карточка включения Обхода Белых Списков
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true; implicitHeight: 82
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 16; spacing: 16

                                Rectangle {
                                    width: 44; height: 44
                                    radius: vpnScroll.isM3 ? 12 : 0
                                    color: (Waybar && Waybar.vpnActive)
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (vpnScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                                    Text {
                                        anchors.centerIn: parent; text: "󰒃"; font.pixelSize: 20
                                        color: (Waybar && Waybar.vpnActive)
                                               ? (Config ? Config.accentTextColor : "#000000")
                                               : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 3
                                    Text {
                                        text: Waybar ? Waybar.vpnServerName : "Обход Белых Списков"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 2; font.bold: true
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    RowLayout {
                                        spacing: 10
                                        Text {
                                            text: (Waybar && Waybar.vpnBusy) ? "󰑐 Проверка туннелей через sing-box (HTTP 204)..." : ((Waybar && Waybar.vpnActive) ? "󰄬 Подключено в режиме БС" : "○ Отключено")
                                            color: (Waybar && Waybar.vpnBusy) ? "#ffd54f" : ((Waybar && Waybar.vpnActive) ? "#69f0ae" : "#888888")
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

                        // Карточка категорий Белых Списков и своих БС-подписок (исправленный z-order!)
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: wlPanelCol.implicitHeight + 28

                            ColumnLayout {
                                id: wlPanelCol
                                anchors.fill: parent; anchors.margins: 14; spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "󰒃"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    Text {
                                        text: "Категории Белых Списков (bypass-lists и свои БС-подписки)"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: (Waybar && Waybar.vpnBusy) ? "󰑐 Тест HTTP 204..." : "󰓅 Проверить БС (HTTP 204 + CIDR/SNI)"
                                        implicitHeight: 26
                                        enabled: !(Waybar && Waybar.vpnBusy)
                                        onClicked: if (Waybar) Waybar.testWhitelistServers()
                                    }
                                }

                                // Сетка категорий БС: Слой 1 = фоны, Слой 2 = наведение, Слой 3 = активная плашка, Слой 4 = текст + иконка
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

                                    // Слой 2: Плавная плашка наведения
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

                                    // Слой 3: Яркая активная плашка ПОВЕРХ фонов кнопок
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

                                    // Слой 1: Фоны кнопок (под плашками z:2 и z:3!)
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

                                    // Слой 4: Только иконка + текст (отдельно друг от друга!) и MouseArea
                                    Flow {
                                        id: wlCatFlow
                                        z: 4; width: parent.width; spacing: 5
                                        Repeater {
                                            id: wlCatRepeater
                                            model: Waybar ? Waybar.vpnWhitelistFiles : []
                                            delegate: Item {
                                                id: catBtn
                                                width: catContentRow.implicitWidth + 22; height: 28
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
                                                    spacing: catBtn.splitParts.icon.length > 0 ? 7 : 0

                                                    Text {
                                                        visible: catBtn.splitParts.icon.length > 0
                                                        text: catBtn.splitParts.icon
                                                        font.pixelSize: Config.fontSize
                                                        color: catTxt.color
                                                        anchors.verticalCenter: parent.verticalCenter
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
                                                    onClicked: if (Waybar) Waybar.vpnWhitelistFile = modelData.key
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
                                    Text { text: "󰌘"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 1 }
                                    Text {
                                        text: "Свои подписки и ключи для Белых Списков (хранятся отдельно):"
                                        color: "#dddddd"; font.pixelSize: Config.fontSize; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: vpnScroll.hideSubLinks ? "󰈉 Показать" : "󰈈 Скрыть (блюр)"
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
                                        placeholderText: "Вставьте ссылку на БС-подписку или несколько vless:// ключей..."
                                        placeholderTextColor: "#777777"
                                        background: Rectangle {
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: vpnScroll.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1,1,1,0.06)
                                            border.color: Qt.rgba(1,1,1,0.16)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                        }
                                    }
                                    StyledButton {
                                        text: "+ Добавить в БС"
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
                                                        text: modelData.title + " [" + modelData.count + " серв.]  •  " + modelData.url
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
                                    Text { text: "󰒃"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 2 }
                                    Text {
                                        text: "Серверы Белого Списка (" + (Waybar && vpnScroll.isWlMode ? Waybar.vpnServers.length : 0) + ")"
                                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: "[󰄬 БС CIDR+SNI] = выживет при жестком белом списке"
                                        color: "#69f0ae"; font.pixelSize: Config.fontSize - 2
                                    }
                                }

                                Text {
                                    visible: !Waybar || !vpnScroll.isWlMode || Waybar.vpnServers.length === 0
                                    text: "Нет серверов в выбранной категории БС. Нажмите «󰊢 Обновить списки (Git)» или добавьте свою БС-подписку."
                                    color: "#888888"; font.pixelSize: Config.fontSize - 1
                                }

                                Item {
                                    id: wlSrvListWrap
                                    visible: Waybar && vpnScroll.isWlMode && Waybar.vpnServers.length > 0
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
                                        model: (Waybar && vpnScroll.isWlMode) ? Waybar.vpnServers : []

                                        delegate: Rectangle {
                                            width: wlSrvList.width; height: 30
                                            property bool isSel: Waybar && Waybar.vpnSelectedServer === index
                                            radius: vpnScroll.isM3 ? 8 : 0
                                            color: isSel
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (vpnScroll.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
                                            border.width: vpnScroll.isM3 ? 0 : 1
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                                Text {
                                                    text: modelData
                                                    color: parent.parent.isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (vpnScroll.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff")
                                                    font.pixelSize: Config.fontSize
                                                    font.bold: parent.parent.isSel
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                                Text {
                                                    visible: parent.parent.isSel
                                                    text: "󰄬"
                                                    color: Config ? Config.accentTextColor : "#000000"
                                                    font.pixelSize: Config.fontSize
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    wlSrvHoverHold.stop()
                                                    wlSrvListWrap.lastHoveredRow = index
                                                    wlSrvListWrap.isHovering = true
                                                }
                                                onExited: wlSrvHoverHold.restart()
                                                onClicked: if (Waybar) Waybar.selectVpnServer(index)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SplitTunnelCard {}
                    }
                }
            }
        }
    }
}
