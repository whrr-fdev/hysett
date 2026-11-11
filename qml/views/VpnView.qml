import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: vpnScroll
    property bool hideSubLinks: false
    property bool customDomainIsDirect: false
    contentWidth: availableWidth
    clip: true

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
                                text: (Waybar && Waybar.vpnBusy) ? "⟳ Проверка и применение..." : ((Waybar && Waybar.vpnActive) ? "●  Подключено (sing-box TUN)" : "○  Отключено")
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

            // ПЕРЕКЛЮЧАТЕЛЬ ИСТОЧНИКА: МОИ ПОДПИСКИ / БЕЛЫЕ СПИСКИ (BYPASS-LISTS)
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
                        StyledButton {
                            text: "🔗 Мои подписки"
                            implicitHeight: 26
                            isActive: !(Waybar && Waybar.vpnWhitelistMode)
                            onClicked: if (Waybar) Waybar.vpnWhitelistMode = false
                        }
                        StyledButton {
                            text: "🛡️ Белые списки (bypass-lists)"
                            implicitHeight: 26
                            isActive: Waybar && Waybar.vpnWhitelistMode
                            onClicked: if (Waybar) Waybar.vpnWhitelistMode = true
                        }
                    }

                    // Настройки режима Белых списков
                    ColumnLayout {
                        visible: Waybar && Waybar.vpnWhitelistMode
                        Layout.fillWidth: true; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                text: "Файл конфигураций из ~/bypass-lists/repos:"
                                color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "⚡ Проверить пинг и отсортировать"
                                implicitHeight: 24
                                enabled: !(Waybar && Waybar.vpnBusy)
                                onClicked: if (Waybar) Waybar.testWhitelistServers()
                            }
                        }

                        Flow {
                            Layout.fillWidth: true; spacing: 6
                            Repeater {
                                model: Waybar ? Waybar.vpnWhitelistFiles : []
                                delegate: StyledButton {
                                    text: modelData.label
                                    implicitHeight: 24
                                    isActive: Waybar && Waybar.vpnWhitelistFile === modelData.key
                                    onClicked: if (Waybar) Waybar.vpnWhitelistFile = modelData.key
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
                            text: "Совет: пункт «⚡ Авто-выбор» сам переключает на самый быстрый сервер"
                            color: "#888888"; font.pixelSize: Config.fontSize - 2
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
                            color: isSel ? (Config ? Config.m3Primary : "#ffffff") : (srvMa.containsMouse ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04))
                            border.color: isSel ? "transparent" : Qt.rgba(1,1,1,0.14); border.width: 1

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

            // КАРТОЧКА РАЗДЕЛЬНОГО ТУННЕЛИРОВАНИЯ (SPLIT TUNNELING)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: splitCol.implicitHeight + 24
                ColumnLayout {
                    id: splitCol; anchors.fill: parent; anchors.margins: 14; spacing: 10

                    Text {
                        text: "Раздельное туннелирование (Split Tunneling + allow-domains / Re-filter)"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        StyledButton {
                            Layout.fillWidth: true; implicitHeight: 28
                            text: "🇷🇺 Обход РФ (RU Direct)"
                            isActive: Waybar && Waybar.vpnSplitMode === "ru_direct"
                            onClicked: if (Waybar) Waybar.vpnSplitMode = "ru_direct"
                        }
                        StyledButton {
                            Layout.fillWidth: true; implicitHeight: 28
                            text: "🎯 Только заблокированные"
                            isActive: Waybar && Waybar.vpnSplitMode === "only_blocked"
                            onClicked: if (Waybar) Waybar.vpnSplitMode = "only_blocked"
                        }
                        StyledButton {
                            Layout.fillWidth: true; implicitHeight: 28
                            text: "🌐 Весь трафик в VPN"
                            isActive: Waybar && Waybar.vpnSplitMode === "all_vpn"
                            onClicked: if (Waybar) Waybar.vpnSplitMode = "all_vpn"
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

                    // Пользовательские правила доменов
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

            // КАРТОЧКА УПРАВЛЕНИЯ НЕСКОЛЬКИМИ ССЫЛКАМИ ПОДПИСОК
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

                    ColumnLayout {
                        id: urlsBlurBox
                        Layout.fillWidth: true
                        spacing: 6
                        layer.enabled: vpnScroll.hideSubLinks
                        layer.smooth: true
                        layer.effect: ShaderEffect {
                            property vector2d u_resolution: Qt.vector2d(Math.max(1, urlsBlurBox.width), Math.max(1, urlsBlurBox.height))
                            property real u_blur: 0.92
                            fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
                        }

                        Repeater {
                            model: Waybar ? Waybar.vpnSubUrls : []
                            delegate: Rectangle {
                                Layout.fillWidth: true; implicitHeight: 28
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8
                                    Text {
                                        text: (index + 1) + ". " + modelData
                                        color: "#cccccc"; font.pixelSize: 10
                                        Layout.fillWidth: true; elide: Text.ElideMiddle
                                    }
                                    StyledButton {
                                        text: "✕"
                                        implicitWidth: 20; implicitHeight: 20
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
