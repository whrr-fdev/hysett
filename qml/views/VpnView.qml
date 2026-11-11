import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: vpnScroll
    property bool hideSubLinks: false
    property int copiedSubIdx: -1
    contentWidth: availableWidth
    clip: true

    Timer {
        id: copyResetTimer
        interval: 1300
        onTriggered: vpnScroll.copiedSubIdx = -1
    }

    Item {
        width: vpnScroll.availableWidth
        implicitHeight: vCol.implicitHeight + 44

        ColumnLayout {
            id: vCol
            width: Math.min(parent.width - 48, 780)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 20
            spacing: 12

            // ЗАГОЛОВОК И КНОПКИ ОБНОВЛЕНИЯ
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: "󰦝  VPN и Обход блокировок"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: (Waybar && Waybar.vpnBusy) ? "⟳ Синхронизация..." : "󰊢  Обновить списки (Git)"
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

            // ГЛАВНАЯ КАРТОЧКА ВКЛЮЧЕНИЯ VPN
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 84
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 16

                    Rectangle {
                        width: 46; height: 46
                        radius: (Theme && Theme.isRounded) ? 14 : 0
                        color: (Waybar && Waybar.vpnActive) ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.20); border.width: 1
                        Text {
                            anchors.centerIn: parent; text: "󰦝"; font.pixelSize: 22
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
                                text: (Waybar && Waybar.vpnBusy) ? "⟳ Проверка туннелей через sing-box (HTTP 204)..." : ((Waybar && Waybar.vpnActive) ? "●  Подключено (sing-box TUN)" : "○  Отключено")
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

            // ПЕРЕКЛЮЧАТЕЛЬ ИСТОЧНИКА + КАТЕГОРИИ БЕЛЫХ СПИСКОВ С ПЛАВНЫМ БЕГУНКОМ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: srcCol.implicitHeight + 24
                ColumnLayout {
                    id: srcCol; anchors.fill: parent; anchors.margins: 14; spacing: 10

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text {
                            text: "Источник VLESS / прокси-серверов"
                            color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                            Layout.fillWidth: true
                        }

                        // Сегментный переключатель источника с плавным наведением и выбором
                        Item {
                            id: srcSegWrap
                            width: 340; height: 28
                            property int hoveredIdx: -1
                            property int activeIdx: (Waybar && Waybar.vpnWhitelistMode) ? 1 : 0

                            Rectangle {
                                anchors.fill: parent
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                            }

                            Rectangle {
                                visible: srcSegWrap.hoveredIdx >= 0 && srcSegWrap.hoveredIdx !== srcSegWrap.activeIdx
                                x: srcSegWrap.hoveredIdx === 1 ? parent.width * 0.5 : 0
                                y: 0; width: parent.width * 0.5; height: parent.height
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.10)
                                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                            }

                            Rectangle {
                                x: srcSegWrap.activeIdx === 1 ? parent.width * 0.5 : 0
                                y: 0; width: parent.width * 0.5; height: parent.height
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                            }

                            Row {
                                anchors.fill: parent
                                Repeater {
                                    model: ["🔗 Мои подписки", "🛡️ Белые списки (БС)"]
                                    delegate: Item {
                                        width: srcSegWrap.width * 0.5; height: srcSegWrap.height
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: Config.fontSize - 1
                                            font.bold: srcSegWrap.activeIdx === index
                                            color: srcSegWrap.activeIdx === index ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: srcSegWrap.hoveredIdx = index
                                            onExited: if (srcSegWrap.hoveredIdx === index) srcSegWrap.hoveredIdx = -1
                                            onClicked: if (Waybar) Waybar.vpnWhitelistMode = (index === 1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Настройки и категории режима Белых списков
                    ColumnLayout {
                        visible: Waybar && Waybar.vpnWhitelistMode
                        Layout.fillWidth: true; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                text: "Категория из ~/bypass-lists/repos (проверка CIDR РФ + белый SNI + пробив HTTP 204):"
                                color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1
                                Layout.fillWidth: true; wrapMode: Text.WordWrap
                            }
                            StyledButton {
                                text: (Waybar && Waybar.vpnBusy) ? "⟳ Тест туннелей..." : "⚡ Проверить БС (HTTP 204 + CIDR/SNI)"
                                implicitHeight: 26
                                enabled: !(Waybar && Waybar.vpnBusy)
                                onClicked: if (Waybar) Waybar.testWhitelistServers()
                            }
                        }

                        // Сетка категорий с плавным 2D-бегунком наведения и выбора
                        Item {
                            id: wlCatContainer
                            Layout.fillWidth: true
                            implicitHeight: wlCatFlow.implicitHeight
                            property var hoveredItem: null
                            property var activeItem: null

                            Rectangle {
                                id: wlHoverPill
                                z: 1
                                visible: wlCatContainer.hoveredItem !== null && wlCatContainer.hoveredItem !== wlCatContainer.activeItem
                                x: wlCatContainer.hoveredItem ? wlCatContainer.hoveredItem.x : 0
                                y: wlCatContainer.hoveredItem ? wlCatContainer.hoveredItem.y : 0
                                width: wlCatContainer.hoveredItem ? wlCatContainer.hoveredItem.width : 0
                                height: wlCatContainer.hoveredItem ? wlCatContainer.hoveredItem.height : 26
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.12)
                                Behavior on x { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                                Behavior on width { NumberAnimation { duration: 210; easing.type: Easing.OutQuint } }
                            }

                            Rectangle {
                                id: wlActivePill
                                z: 2
                                visible: wlCatContainer.activeItem !== null
                                x: wlCatContainer.activeItem ? wlCatContainer.activeItem.x : 0
                                y: wlCatContainer.activeItem ? wlCatContainer.activeItem.y : 0
                                width: wlCatContainer.activeItem ? wlCatContainer.activeItem.width : 0
                                height: wlCatContainer.activeItem ? wlCatContainer.activeItem.height : 26
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Config ? Config.m3Primary : "#ffffff"
                                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                            }

                            Flow {
                                id: wlCatFlow
                                z: 3
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: Waybar ? Waybar.vpnWhitelistFiles : []
                                    delegate: Item {
                                        id: catBtn
                                        width: catTxt.implicitWidth + 20
                                        height: 26
                                        property bool isSel: Waybar && Waybar.vpnWhitelistFile === modelData.key
                                        onIsSelChanged: if (isSel) wlCatContainer.activeItem = catBtn
                                        Component.onCompleted: if (isSel) wlCatContainer.activeItem = catBtn

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: (Theme && Theme.isRounded) ? 6 : 0
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.color: parent.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.14); border.width: 1
                                        }
                                        Text {
                                            id: catTxt
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.pixelSize: Config.fontSize - 1
                                            font.bold: parent.isSel
                                            color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: wlCatContainer.hoveredItem = catBtn
                                            onExited: if (wlCatContainer.hoveredItem === catBtn) wlCatContainer.hoveredItem = null
                                            onClicked: if (Waybar) Waybar.vpnWhitelistFile = modelData.key
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // СПИСОК СЕРВЕРОВ (С КОМПАКТНОЙ ПРОКРУТКОЙ)
            GlassPanel {
                objectName: "atmoObstacle"
                visible: Waybar && Waybar.vpnServers.length > 0
                Layout.fillWidth: true
                implicitHeight: srvCol.implicitHeight + 24

                ColumnLayout {
                    id: srvCol
                    anchors.fill: parent; anchors.margins: 14; spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: (Waybar && Waybar.vpnWhitelistMode ? "Серверы из белого списка (" : "Доступные серверы (") + (Waybar ? Waybar.vpnServers.length : 0) + ")"
                            color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: Waybar && Waybar.vpnWhitelistMode
                            text: "[✅ БС CIDR+SNI] = выживет при жестком белом списке"
                            color: "#69f0ae"; font.pixelSize: Config.fontSize - 2
                        }
                    }

                    ListView {
                        id: srvList
                        Layout.fillWidth: true
                        implicitHeight: Math.min(contentHeight, 220)
                        clip: true
                        spacing: 5
                        model: Waybar ? Waybar.vpnServers : []
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            width: srvList.width
                            height: 30
                            property bool isSel: Waybar && Waybar.vpnSelectedServer === index
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: isSel ? (Config ? Config.m3Primary : "#ffffff") : (srvMa.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.04))
                            border.color: isSel ? "transparent" : Qt.rgba(1,1,1,0.14); border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                Text {
                                    text: modelData
                                    color: parent.parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: parent.parent.isSel
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: srvMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (Waybar) Waybar.selectVpnServer(index)
                            }
                        }
                    }
                }
            }

            // КАРТОЧКА РАЗДЕЛЬНОГО ТУННЕЛИРОВАНИЯ С ПЛАВНЫМ БЕГУНКОМ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: splitCol.implicitHeight + 24
                ColumnLayout {
                    id: splitCol; anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Text {
                        text: "Раздельное туннелирование (Split Tunneling + allow-domains / Re-filter)"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    }

                    Item {
                        id: splitSegWrap
                        Layout.fillWidth: true; height: 30
                        property int hoveredIdx: -1
                        property int activeIdx: {
                            if (!Waybar) return 0;
                            if (Waybar.vpnSplitMode === "only_blocked") return 1;
                            if (Waybar.vpnSplitMode === "all_vpn") return 2;
                            return 0;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                        }

                        Rectangle {
                            visible: splitSegWrap.hoveredIdx >= 0 && splitSegWrap.hoveredIdx !== splitSegWrap.activeIdx
                            x: splitSegWrap.hoveredIdx * (parent.width / 3.0)
                            y: 0; width: parent.width / 3.0; height: parent.height
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.10)
                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        }

                        Rectangle {
                            x: splitSegWrap.activeIdx * (parent.width / 3.0)
                            y: 0; width: parent.width / 3.0; height: parent.height
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Config ? Config.m3Primary : "#ffffff"
                            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                        }

                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: [
                                    { key: "ru_direct", label: "🇷🇺 Обход РФ (RU Direct)" },
                                    { key: "only_blocked", label: "🎯 Только заблокированные" },
                                    { key: "all_vpn", label: "🌐 Весь трафик в VPN" }
                                ]
                                delegate: Item {
                                    width: splitSegWrap.width / 3.0; height: splitSegWrap.height
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Config.fontSize - 1
                                        font.bold: splitSegWrap.activeIdx === index
                                        color: splitSegWrap.activeIdx === index ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: splitSegWrap.hoveredIdx = index
                                        onExited: if (splitSegWrap.hoveredIdx === index) splitSegWrap.hoveredIdx = -1
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
                                        text: "✕"; color: "#cccccc"; font.pixelSize: 10
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
                                        text: "✕"; color: "#cccccc"; font.pixelSize: 10
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Waybar.removeVpnCustomDomain(index, true) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // КАРТОЧКА ССЫЛОК ПОДПИСОК С КНОПКОЙ КОПИРОВАНИЯ И ПЛАВНЫМ БЕГУНКОМ НАВЕДЕНИЯ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: subCol.implicitHeight + 24
                ColumnLayout {
                    id: subCol; anchors.fill: parent; anchors.margins: 14; spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Ссылки на подписки и личные ключи (vless://, trojan://, https://...)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                        StyledButton {
                            text: vpnScroll.hideSubLinks ? "󰈉  Показать ссылки" : "󰈈  Скрыть (блюр)"
                            implicitHeight: 22
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
                            placeholderText: "Вставьте ссылку на подписку или vless:// ключ..."
                            placeholderTextColor: "#777777"
                            background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.18) }
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
                        id: urlsBlurBox
                        Layout.fillWidth: true
                        implicitHeight: subListCol.implicitHeight
                        property int hoveredSubIdx: -1

                        layer.enabled: vpnScroll.hideSubLinks
                        layer.smooth: true
                        layer.effect: ShaderEffect {
                            property vector2d u_resolution: Qt.vector2d(Math.max(1, urlsBlurBox.width), Math.max(1, urlsBlurBox.height))
                            property real u_blur: 0.92
                            fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                        }

                        // Плавно скользящая плашка наведения (как на боковой панели)
                        Rectangle {
                            id: subHoverPill
                            z: 1
                            visible: urlsBlurBox.hoveredSubIdx >= 0
                            x: 0
                            y: Math.max(0, urlsBlurBox.hoveredSubIdx) * 36
                            width: urlsBlurBox.width
                            height: 30
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.16) : Qt.rgba(1, 1, 1, 0.12)
                            border.color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45) : Qt.rgba(1, 1, 1, 0.25)
                            border.width: 1
                            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        }

                        ColumnLayout {
                            id: subListCol
                            z: 2
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: Waybar ? Waybar.vpnSubUrls : []
                                delegate: Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 30
                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        onEntered: urlsBlurBox.hoveredSubIdx = index
                                        onExited: if (urlsBlurBox.hoveredSubIdx === index) urlsBlurBox.hoveredSubIdx = -1
                                    }

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 6
                                        Text {
                                            text: (index + 1) + ". " + modelData
                                            color: urlsBlurBox.hoveredSubIdx === index ? "#ffffff" : "#cccccc"
                                            font.pixelSize: 10
                                            Layout.fillWidth: true; elide: Text.ElideMiddle
                                        }
                                        StyledButton {
                                            text: vpnScroll.copiedSubIdx === index ? "✓ Скопировано" : "󰆏 Копировать"
                                            implicitHeight: 22
                                            isActive: vpnScroll.copiedSubIdx === index
                                            enabled: !vpnScroll.hideSubLinks
                                            onClicked: {
                                                if (Waybar) {
                                                    var safeUrl = modelData.replace(/'/g, "'\\''");
                                                    Waybar.runCommand("printf '%s' '" + safeUrl + "' | wl-copy");
                                                    vpnScroll.copiedSubIdx = index;
                                                    copyResetTimer.restart();
                                                }
                                            }
                                        }
                                        StyledButton {
                                            text: "✕"
                                            implicitWidth: 22; implicitHeight: 22
                                            enabled: !vpnScroll.hideSubLinks
                                            onClicked: if (Waybar) Waybar.removeVpnSubUrl(index)
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
