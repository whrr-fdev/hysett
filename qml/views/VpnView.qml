import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: vpnScroll
    property bool hideSubLinks: false
    contentWidth: availableWidth
    clip: true

    Item {
        width: vpnScroll.availableWidth
        implicitHeight: vCol.implicitHeight + 40

        ColumnLayout {
            id: vCol
            width: Math.min(parent.width - 48, 760)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 22
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰦝  VPN"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "󰑐  Обновить подписки"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.updateVpnSubscription()
                }
            }

            // ГЛАВНАЯ КАРТОЧКА ВКЛЮЧЕНИЯ VPN
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 82
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
                        }
                        Text {
                            text: (Waybar && Waybar.vpnActive) ? "●  Подключено" : "○  Отключено"
                            color: (Waybar && Waybar.vpnActive) ? "#69f0ae" : "#888888"
                            font.pixelSize: Config.fontSize - 1
                        }
                    }

                    StyledSwitch {
                        checked: Waybar ? Waybar.vpnActive : false
                        onToggled: if (Waybar) Waybar.toggleVpn()
                    }
                }
            }

            // СПИСОК СЕРВЕРОВ ИЗ ПОДПИСОК
            GlassPanel {
                objectName: "atmoObstacle"
                visible: Waybar && Waybar.vpnServers.length > 0
                Layout.fillWidth: true
                implicitHeight: srvCol.implicitHeight + 24

                ColumnLayout {
                    id: srvCol
                    anchors.fill: parent; anchors.margins: 14; spacing: 8

                    Text {
                        text: "Доступные серверы (" + (Waybar ? Waybar.vpnServers.length : 0) + ")"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                    }

                    Repeater {
                        model: Waybar ? Waybar.vpnServers : []
                        delegate: Rectangle {
                            Layout.fillWidth: true; implicitHeight: 30
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

            // КАРТОЧКА МАРШРУТИЗАЦИИ РФ ДОМЕНОВ БЕЗ VPN
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: ruRow.implicitHeight + 24
                RowLayout {
                    id: ruRow; anchors.fill: parent; anchors.margins: 14; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Прямой маршрут для российских сайтов (RU Direct)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }
                        Text { text: "Домены .ru, .рф, .su, Госуслуги, Банки, ВК, Яндекс, Ozon и WB работают напрямую без VPN"; color: "#888888"; font.pixelSize: Config.fontSize - 1 }
                    }
                    StyledSwitch {
                        checked: Waybar ? Waybar.vpnRuDirect : true
                        onToggled: if (Waybar) Waybar.vpnRuDirect = checked
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
                        Text { text: "Ссылки на подписки и ключи (vless://, trojan://, https://...)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
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
