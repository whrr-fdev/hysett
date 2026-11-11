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
    property bool isWlMode: Waybar ? Waybar.vpnWhitelistMode : false
    property real modeSlideProgress: isWlMode ? 1.0 : 0.0
    Behavior on modeSlideProgress { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

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

    Item {
        width: vpnScroll.availableWidth
        implicitHeight: vCol.implicitHeight + 44

        ColumnLayout {
            id: vCol
            width: Math.min(parent.width - 48, 780)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 18
            spacing: 12

            // 1. ВЕРХНИЙ ЗАГОЛОВОК И КНОПКИ СИНХРОНИЗАЦИИ
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: "󰦝  VPN и Обход блокировок"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: (Waybar && Waybar.vpnBusy) ? "󰑐  Синхронизация..." : "󰊢  Обновить списки (Git)"
                    implicitHeight: 26
                    enabled: !(Waybar && Waybar.vpnBusy)
                    onClicked: if (Waybar) Waybar.updateBypassLists()
                }
                StyledButton {
                    text: "󰑐  Обновить подписки"
                    implicitHeight: 26
                    enabled: !(Waybar && Waybar.vpnBusy)
                    onClicked: if (Waybar) Waybar.updateVpnSubscription()
                }
            }

            // 2. ПЕРЕКЛЮЧАТЕЛЬ РЕЖИМА В СТИЛЕ СЕГМЕНТНОЙ КОЛБАСКИ (БЕЗ МИГАНИЯ ПРИ НАВЕДЕНИИ)
            Item {
                id: topModeSeg
                Layout.fillWidth: true
                implicitHeight: 38
                property bool m3: Theme && Theme.isRounded
                property real outerR: m3 ? 12 : 0
                property real innerR: m3 ? 5 : 0
                property int hoveredIdx: -1
                property int lastHoveredIdx: 0
                property int activeIdx: vpnScroll.isWlMode ? 1 : 0

                Timer {
                    id: topModeHoverHold
                    interval: 50
                    onTriggered: topModeSeg.hoveredIdx = -1
                }

                Row {
                    anchors.fill: parent
                    spacing: 3
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            width: (topModeSeg.width - 3) * 0.5
                            height: topModeSeg.height
                            radius: topModeSeg.innerR
                            color: (topModeSeg.m3 && Config) ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.05)
                            border.color: (topModeSeg.m3 && Config) ? Config.m3OutlineVariant : Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1

                            Rectangle {
                                visible: topModeSeg.m3 && index === 0
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: topModeSeg.outerR; radius: topModeSeg.outerR; color: parent.color
                            }
                            Rectangle {
                                visible: topModeSeg.m3 && index === 1
                                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: topModeSeg.outerR; radius: topModeSeg.outerR; color: parent.color
                            }
                        }
                    }
                }

                // Непрерывно скользящая плашка наведения
                Rectangle {
                    z: 2
                    opacity: topModeSeg.hoveredIdx >= 0 ? 1.0 : 0.0
                    x: topModeSeg.lastHoveredIdx * ((topModeSeg.width - 3) * 0.5 + 3)
                    y: 0
                    width: (topModeSeg.width - 3) * 0.5
                    height: topModeSeg.height
                    radius: topModeSeg.lastHoveredIdx === 0 || topModeSeg.lastHoveredIdx === 1 ? topModeSeg.innerR : topModeSeg.innerR
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Плашка активного режима
                Rectangle {
                    z: 3
                    x: topModeSeg.activeIdx * ((topModeSeg.width - 3) * 0.5 + 3)
                    y: 0
                    width: (topModeSeg.width - 3) * 0.5
                    height: topModeSeg.height
                    radius: topModeSeg.innerR
                    color: Config ? Config.m3Primary : "#ffffff"
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

                    Rectangle {
                        visible: topModeSeg.m3 && topModeSeg.activeIdx === 0
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: topModeSeg.outerR; radius: topModeSeg.outerR; color: parent.color
                    }
                    Rectangle {
                        visible: topModeSeg.m3 && topModeSeg.activeIdx === 1
                        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: topModeSeg.outerR; radius: topModeSeg.outerR; color: parent.color
                    }
                }

                Row {
                    z: 4
                    anchors.fill: parent
                    spacing: 3
                    Repeater {
                        model: [
                            "󰦝  Режим: Обычный VPN (Мои подписки)",
                            "󰒃  Режим: Обход Белых Списков (БС)"
                        ]
                        delegate: Item {
                            width: (topModeSeg.width - 3) * 0.5
                            height: topModeSeg.height
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Config.fontSize
                                font.bold: topModeSeg.activeIdx === index
                                color: topModeSeg.activeIdx === index ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    topModeHoverHold.stop()
                                    topModeSeg.lastHoveredIdx = index
                                    topModeSeg.hoveredIdx = index
                                }
                                onExited: topModeHoverHold.restart()
                                onClicked: if (Waybar) Waybar.vpnWhitelistMode = (index === 1)
                            }
                        }
                    }
                }
            }

            // 3. ГЛАВНАЯ КАРТОЧКА ВКЛЮЧЕНИЯ VPN
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 80
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 16

                    Rectangle {
                        width: 44; height: 44
                        radius: (Theme && Theme.isRounded) ? 12 : 0
                        color: (Waybar && Waybar.vpnActive) ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.20); border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: vpnScroll.isWlMode ? "󰒃" : "󰦝"
                            font.pixelSize: 20
                            color: (Waybar && Waybar.vpnActive) ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
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
                                text: (Waybar && Waybar.vpnBusy) ? "󰑐  Проверка и применение..." : ((Waybar && Waybar.vpnActive) ? "󰄬  Подключено (sing-box TUN)" : "○  Отключено")
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

            // 4. ПОЛНОЦЕННЫЙ ГОРИЗОНТАЛЬНЫЙ СЛАЙДЕР СТРАНИЦ: [СТРАНИЦА 0: ОБЫЧНЫЙ VPN] <-> [СТРАНИЦА 1: БЕЛЫЕ СПИСКИ]
            Item {
                id: modePagesViewport
                Layout.fillWidth: true
                implicitHeight: vpnScroll.isWlMode ? wlModePage.implicitHeight : normalVpnPage.implicitHeight
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }

                Row {
                    width: modePagesViewport.width * 2
                    x: -vpnScroll.modeSlideProgress * modePagesViewport.width

                    // ================= СТРАНИЦА 0: ОБЫЧНЫЙ VPN (ПОДПИСКИ И ВКЛАДКИ) =================
                    Item {
                        id: normalVpnPage
                        width: modePagesViewport.width
                        implicitHeight: normalVpnCol.implicitHeight

                        ColumnLayout {
                            id: normalVpnCol
                            width: parent.width
                            spacing: 12

                            GlassPanel {
                                objectName: "atmoObstacle"
                                Layout.fillWidth: true
                                implicitHeight: subTabsCol.implicitHeight + 24

                                ColumnLayout {
                                    id: subTabsCol
                                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "󰌘  Мои подписки и ключи"
                                            color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        StyledButton {
                                            text: vpnScroll.hideSubLinks ? "󰈉  Показать ссылки" : "󰈈  Скрыть ссылки (блюр)"
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
                                            background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.18) }
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

                                    // Вкладки подписок с бесшовным скольжением плашки наведения
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
                                            interval: 50
                                            onTriggered: subTabBar.isHovering = false
                                        }

                                        Rectangle {
                                            z: 1
                                            opacity: subTabBar.isHovering ? 1.0 : 0.0
                                            x: subTabBar.hovX; y: subTabBar.hovY
                                            width: subTabBar.hovW; height: 28
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Qt.rgba(1, 1, 1, 0.11)
                                            Behavior on x { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on width { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        Rectangle {
                                            z: 2
                                            visible: subTabBar.activeItem !== null
                                            x: subTabBar.activeItem ? subTabBar.activeItem.x : 0
                                            y: subTabBar.activeItem ? subTabBar.activeItem.y : 0
                                            width: subTabBar.activeItem ? subTabBar.activeItem.width : 90
                                            height: 28
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Config ? Config.m3Primary : "#ffffff"
                                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        }

                                        Flow {
                                            id: subTabFlow
                                            z: 3; width: parent.width; spacing: 5

                                            Item {
                                                id: allSubTabBtn
                                                width: allSubTabTxt.implicitWidth + 22; height: 28
                                                property bool isSel: vpnScroll.activeSubTab === 0
                                                onIsSelChanged: if (isSel) subTabBar.activeItem = allSubTabBtn

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.04)
                                                    border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14); border.width: 1
                                                }
                                                Text {
                                                    id: allSubTabTxt; anchors.centerIn: parent
                                                    text: "Все (" + (Waybar ? Waybar.vpnServers.length : 0) + ")"
                                                    font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                    color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
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
                                                model: Waybar ? Waybar.vpnSubGroups : []
                                                delegate: Item {
                                                    id: oneSubTabBtn
                                                    width: oneSubTabTxt.implicitWidth + 22; height: 28
                                                    property bool isSel: vpnScroll.activeSubTab === (index + 1)
                                                    onIsSelChanged: if (isSel) subTabBar.activeItem = oneSubTabBtn

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: (Theme && Theme.isRounded) ? 6 : 0
                                                        color: Qt.rgba(1, 1, 1, 0.04)
                                                        border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14); border.width: 1
                                                    }
                                                    Text {
                                                        id: oneSubTabTxt; anchors.centerIn: parent
                                                        text: modelData.title + " (" + modelData.count + ")"
                                                        font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                        color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
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

                                    // Список ссылок подписок с плавной плашкой наведения и копированием
                                    Item {
                                        id: urlsBlurBox
                                        visible: Waybar && Waybar.vpnSubGroups.length > 0
                                        Layout.fillWidth: true
                                        implicitHeight: subListCol.implicitHeight
                                        property bool isHovering: false
                                        property real hovY: 0

                                        Timer {
                                            id: subRowHoverHold
                                            interval: 50
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
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14) : Qt.rgba(1, 1, 1, 0.10)
                                            border.color: Config ? Config.m3Primary : "#ffffff"; border.width: 1
                                            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
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
                                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.04)
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
                        }
                    }

                    // ================= СТРАНИЦА 1: БЕЛЫЕ СПИСКИ (КАТЕГОРИИ И СВОИ БС-ПОДПИСКИ) =================
                    Item {
                        id: wlModePage
                        width: modePagesViewport.width
                        implicitHeight: wlPageCol.implicitHeight

                        ColumnLayout {
                            id: wlPageCol
                            width: parent.width
                            spacing: 12

                            GlassPanel {
                                objectName: "atmoObstacle"
                                Layout.fillWidth: true
                                implicitHeight: wlPanelCol.implicitHeight + 24

                                ColumnLayout {
                                    id: wlPanelCol
                                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 8
                                        Text {
                                            text: "󰒃  Категории Белых Списков (bypass-lists и свои подписки БС)"
                                            color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        StyledButton {
                                            text: (Waybar && Waybar.vpnBusy) ? "󰑐  Тест HTTP 204..." : "󰓅  Проверить БС (HTTP 204 + CIDR/SNI)"
                                            implicitHeight: 26
                                            enabled: !(Waybar && Waybar.vpnBusy)
                                            onClicked: if (Waybar) Waybar.testWhitelistServers()
                                        }
                                    }

                                    // Сетка категорий БС в стиле колбаски с бесшовным 2D-бегунком наведения
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
                                            interval: 50
                                            onTriggered: wlCatContainer.isHovering = false
                                        }

                                        Rectangle {
                                            z: 1
                                            opacity: wlCatContainer.isHovering ? 1.0 : 0.0
                                            x: wlCatContainer.hovX; y: wlCatContainer.hovY
                                            width: wlCatContainer.hovW; height: 28
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Qt.rgba(1, 1, 1, 0.11)
                                            Behavior on x { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on width { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        Rectangle {
                                            z: 2
                                            visible: wlCatContainer.activeItem !== null
                                            x: wlCatContainer.activeItem ? wlCatContainer.activeItem.x : 0
                                            y: wlCatContainer.activeItem ? wlCatContainer.activeItem.y : 0
                                            width: wlCatContainer.activeItem ? wlCatContainer.activeItem.width : 110
                                            height: 28
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Config ? Config.m3Primary : "#ffffff"
                                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                        }

                                        Flow {
                                            id: wlCatFlow
                                            z: 3; width: parent.width; spacing: 5
                                            Repeater {
                                                model: Waybar ? Waybar.vpnWhitelistFiles : []
                                                delegate: Item {
                                                    id: catBtn
                                                    width: catTxt.implicitWidth + 20; height: 28
                                                    property bool isSel: Waybar && Waybar.vpnWhitelistFile === modelData.key
                                                    onIsSelChanged: if (isSel) wlCatContainer.activeItem = catBtn
                                                    Component.onCompleted: if (isSel) wlCatContainer.activeItem = catBtn

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: (Theme && Theme.isRounded) ? 6 : 0
                                                        color: (Theme && Theme.isRounded && Config) ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.04)
                                                        border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14); border.width: 1
                                                    }
                                                    Text {
                                                        id: catTxt; anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.pixelSize: Config.fontSize - 1; font.bold: parent.isSel
                                                        color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
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
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 8
                                        Text {
                                            text: "󰌘  Свои подписки и ключи для Белых Списков (хранятся отдельно):"
                                            color: "#dddddd"; font.pixelSize: Config.fontSize; font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        StyledButton {
                                            text: vpnScroll.hideSubLinks ? "󰈉  Показать" : "󰈈  Скрыть (блюр)"
                                            implicitHeight: 22
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
                                            background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.18) }
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
                                            interval: 50
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
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14) : Qt.rgba(1, 1, 1, 0.10)
                                            border.color: Config ? Config.m3Primary : "#ffffff"; border.width: 1
                                            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        ColumnLayout {
                                            id: wlSubListCol
                                            z: 2; width: parent.width; spacing: 6

                                            Repeater {
                                                model: Waybar ? Waybar.vpnWlSubGroups : []
                                                delegate: Rectangle {
                                                    id: wlSubRowItem
                                                    Layout.fillWidth: true; implicitHeight: 32
                                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.04)
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
                        }
                    }
                }
            }

            // 5. СПИСОК СЕРВЕРОВ С ПЛАВНОЙ СКОЛЬЗЯЩЕЙ ПЛАШКОЙ НАВЕДЕНИЯ И ВЫБОРА
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: srvCol.implicitHeight + 24

                ColumnLayout {
                    id: srvCol
                    anchors.fill: parent; anchors.margins: 14; spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: {
                                if (!Waybar) return "󰈀  Серверы";
                                if (vpnScroll.isWlMode) return "󰒃  Серверы Белого Списка (" + Waybar.vpnServers.length + ")";
                                if (vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                    var g = Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1];
                                    return "󰈀  Серверы из «" + g.title + "» (" + g.count + ")";
                                }
                                return "󰈀  Доступные серверы (" + Waybar.vpnServers.length + ")";
                            }
                            color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: vpnScroll.isWlMode
                            text: "[󰄬 БС CIDR+SNI] = выживет при жестком белом списке"
                            color: "#69f0ae"; font.pixelSize: Config.fontSize - 2
                        }
                    }

                    Text {
                        visible: !Waybar || Waybar.vpnServers.length === 0
                        text: vpnScroll.isWlMode
                            ? "Нет серверов в выбранной категории БС. Нажмите «󰊢 Обновить списки (Git)» или добавьте свою БС-подписку."
                            : "Нет добавленных серверов. Добавьте ссылку на подписку или vless:// ключ выше."
                        color: "#888888"; font.pixelSize: Config.fontSize - 1
                    }

                    Item {
                        id: srvListContainer
                        visible: Waybar && Waybar.vpnServers.length > 0
                        Layout.fillWidth: true
                        implicitHeight: Math.min(srvList.contentHeight, 238)
                        clip: true
                        property bool isHovering: false
                        property int lastHoveredRow: 0

                        Timer {
                            id: srvHoverHold
                            interval: 50
                            onTriggered: srvListContainer.isHovering = false
                        }

                        // Плавно скользящая плашка наведения по списку серверов
                        Rectangle {
                            z: 1
                            opacity: srvListContainer.isHovering ? 1.0 : 0.0
                            x: 0
                            y: srvListContainer.lastHoveredRow * 34 - srvList.contentY
                            width: srvList.width
                            height: 30
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14) : Qt.rgba(1, 1, 1, 0.10)
                            border.color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45) : Qt.rgba(1, 1, 1, 0.22)
                            border.width: 1
                            Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        ListView {
                            id: srvList
                            z: 2
                            anchors.fill: parent
                            spacing: 4
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            model: {
                                if (!Waybar) return [];
                                if (!vpnScroll.isWlMode && vpnScroll.activeSubTab > 0 && vpnScroll.activeSubTab <= Waybar.vpnSubGroups.length) {
                                    return Waybar.vpnSubGroups[vpnScroll.activeSubTab - 1].servers;
                                }
                                var res = [];
                                for (var i = 0; i < Waybar.vpnServers.length; ++i) {
                                    res.push({ name: Waybar.vpnServers[i], global_index: i });
                                }
                                return res;
                            }

                            delegate: Rectangle {
                                width: srvList.width
                                height: 30
                                property int realIdx: modelData.global_index !== undefined ? modelData.global_index : index
                                property bool isSel: Waybar && Waybar.vpnSelectedServer === realIdx
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: isSel ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.03)
                                border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                Behavior on color { ColorAnimation { duration: 160 } }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    Text {
                                        text: modelData.name !== undefined ? modelData.name : modelData
                                        color: parent.parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
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
                                        srvHoverHold.stop()
                                        srvListContainer.lastHoveredRow = index
                                        srvListContainer.isHovering = true
                                    }
                                    onExited: srvHoverHold.restart()
                                    onClicked: if (Waybar) Waybar.selectVpnServer(parent.realIdx)
                                }
                            }
                        }
                    }
                }
            }

            // 6. КАРТОЧКА РАЗДЕЛЬНОГО ТУННЕЛИРОВАНИЯ В СТИЛЕ СЕГМЕНТНОЙ КОЛБАСКИ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: splitCol.implicitHeight + 24
                ColumnLayout {
                    id: splitCol; anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Text {
                        text: "󰒓  Раздельное туннелирование (Split Tunneling + allow-domains / Re-filter)"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    }

                    Item {
                        id: splitSegWrap
                        Layout.fillWidth: true; height: 32
                        property bool m3: Theme && Theme.isRounded
                        property real outerR: m3 ? 10 : 0
                        property real innerR: m3 ? 5 : 0
                        property real itemW: (width - 6) / 3.0
                        property int hoveredIdx: -1
                        property int lastHoveredIdx: 0
                        property int activeIdx: {
                            if (!Waybar) return 0;
                            if (Waybar.vpnSplitMode === "only_blocked") return 1;
                            if (Waybar.vpnSplitMode === "all_vpn") return 2;
                            return 0;
                        }

                        Timer {
                            id: splitHoverHold
                            interval: 50
                            onTriggered: splitSegWrap.hoveredIdx = -1
                        }

                        Row {
                            anchors.fill: parent; spacing: 3
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    width: splitSegWrap.itemW; height: splitSegWrap.height
                                    radius: splitSegWrap.innerR
                                    color: (splitSegWrap.m3 && Config) ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: (splitSegWrap.m3 && Config) ? Config.m3OutlineVariant : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                }
                            }
                        }

                        Rectangle {
                            z: 2
                            opacity: splitSegWrap.hoveredIdx >= 0 ? 1.0 : 0.0
                            x: splitSegWrap.lastHoveredIdx * (splitSegWrap.itemW + 3)
                            y: 0; width: splitSegWrap.itemW; height: splitSegWrap.height
                            radius: splitSegWrap.innerR
                            color: Qt.rgba(1, 1, 1, 0.10)
                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        Rectangle {
                            z: 3
                            x: splitSegWrap.activeIdx * (splitSegWrap.itemW + 3)
                            y: 0; width: splitSegWrap.itemW; height: splitSegWrap.height
                            radius: splitSegWrap.innerR
                            color: Config ? Config.m3Primary : "#ffffff"
                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        }

                        Row {
                            z: 4; anchors.fill: parent; spacing: 3
                            Repeater {
                                model: [
                                    { key: "ru_direct", label: "󰈀  Обход РФ (RU Direct)" },
                                    { key: "only_blocked", label: "󰞀  Только заблокированные" },
                                    { key: "all_vpn", label: "󰦝  Весь трафик в VPN" }
                                ]
                                delegate: Item {
                                    width: splitSegWrap.itemW; height: splitSegWrap.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Config.fontSize - 1
                                        font.bold: splitSegWrap.activeIdx === index
                                        color: splitSegWrap.activeIdx === index ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            splitHoverHold.stop()
                                            splitSegWrap.lastHoveredIdx = index
                                            splitSegWrap.hoveredIdx = index
                                        }
                                        onExited: splitHoverHold.restart()
                                        onClicked: if (Waybar) Waybar.vpnSplitMode = modelData.key
                                    }
                                }
                            }
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
                            background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.18) }
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
                            delegate: Rectangle {
                                height: 22; width: cpRow.implicitWidth + 14
                                radius: (Theme && Theme.isRounded) ? 5 : 0
                                color: Qt.rgba(0.3, 0.7, 1.0, 0.16); border.color: Qt.rgba(0.3, 0.7, 1.0, 0.4)
                                RowLayout {
                                    id: cpRow; anchors.centerIn: parent; spacing: 5
                                    Text { text: "VPN: " + modelData; color: "#ffffff"; font.pixelSize: 10 }
                                    Text {
                                        text: "󰅖"; color: "#cccccc"; font.pixelSize: 10
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Waybar.removeVpnCustomDomain(index, false) }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: Waybar ? Waybar.vpnCustomDirectDomains : []
                            delegate: Rectangle {
                                height: 22; width: cdRow.implicitWidth + 14
                                radius: (Theme && Theme.isRounded) ? 5 : 0
                                color: Qt.rgba(0.3, 0.9, 0.5, 0.16); border.color: Qt.rgba(0.3, 0.9, 0.5, 0.4)
                                RowLayout {
                                    id: cdRow; anchors.centerIn: parent; spacing: 5
                                    Text { text: "Прямой: " + modelData; color: "#ffffff"; font.pixelSize: 10 }
                                    Text {
                                        text: "󰅖"; color: "#cccccc"; font.pixelSize: 10
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Waybar.removeVpnCustomDomain(index, true) }
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
