import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: vpnScroll
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
                    text: "󰦝  VPN и обход блокировок (StealthSurf / Sing-box)"
                    color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "󰑐  Обновить подписку"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.updateVpnSubscription()
                }
                StyledButton {
                    text: "Открыть Throne GUI"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.runCommand("throne")
                }
            }

            // ГЛАВНАЯ КАРТОЧКА ВКЛЮЧЕНИЯ VPN
            GlassPanel {
                Layout.fillWidth: true; implicitHeight: 86
                RowLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 16

                    Rectangle {
                        width: 48; height: 48
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
                            text: Waybar ? Waybar.vpnServerName : "StealthSurf VPN"
                            color: "#ffffff"; font.pixelSize: Config.fontSize + 2; font.bold: true
                        }
                        Text {
                            text: (Waybar && Waybar.vpnActive)
                                  ? "●  Подключено (Активен туннель / прокси 127.0.0.1:2080, ~15 МБ ОЗУ)"
                                  : "○  Отключено (Нажмите тумблер справа для быстрого подключения)"
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

            // КАРТОЧКА МАРШРУТИЗАЦИИ РФ ДОМЕНОВ БЕЗ VPN
            GlassPanel {
                Layout.fillWidth: true; implicitHeight: ruRow.implicitHeight + 24
                RowLayout {
                    id: ruRow; anchors.fill: parent; anchors.margins: 14; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Прямой маршрут для российских сайтов (RU Direct Routing)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }
                        Text { text: "Домены .ru, .рф, .su, Госуслуги, Банки, ВК, Яндекс, Ozon и WB работают напрямую без VPN"; color: "#888888"; font.pixelSize: Config.fontSize - 1 }
                    }
                    StyledSwitch {
                        checked: Waybar ? Waybar.vpnRuDirect : true
                        onToggled: if (Waybar) Waybar.vpnRuDirect = checked
                    }
                }
            }

            // КАРТОЧКА ПОДПИСКИ
            GlassPanel {
                Layout.fillWidth: true; implicitHeight: subCol.implicitHeight + 24
                ColumnLayout {
                    id: subCol; anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Text { text: "Ссылка на подписку (Subscription URL)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        TextField {
                            id: subUrlField
                            Layout.fillWidth: true; implicitHeight: 28; leftPadding: 10; rightPadding: 10
                            color: "#ffffff"; font.pixelSize: 11
                            text: Waybar ? Waybar.vpnSubUrl : ""
                            onEditingFinished: if (Waybar) Waybar.vpnSubUrl = text
                            background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.18) }
                        }
                        StyledButton {
                            text: "Сохранить и применить"
                            implicitHeight: 28
                            onClicked: {
                                if (Waybar) {
                                    Waybar.vpnSubUrl = subUrlField.text
                                    Waybar.updateVpnSubscription()
                                }
                            }
                        }
                    }
                    Text {
                        text: "Совет: для работы легкого режима без окна Throne убедитесь, что установлен пакет sing-box (sudo pacman -S sing-box)."
                        color: "#888888"; font.pixelSize: Config.fontSize - 1
                    }
                }
            }
        }
    }
}
