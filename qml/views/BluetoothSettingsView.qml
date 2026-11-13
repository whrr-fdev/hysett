import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: btScroll
    contentWidth: availableWidth
    clip: true
    readonly property bool isM3: Theme && Theme.isRounded

    Component.onCompleted: if (Bluetooth) Bluetooth.refresh()
    onVisibleChanged: if (visible && Bluetooth) Bluetooth.refresh()

    Timer {
        interval: 3000
        repeat: true
        running: btScroll.visible && (ApplicationWindow.window ? ApplicationWindow.window.drawerOpen : true)
        onTriggered: if (Bluetooth && !Bluetooth.scanning) Bluetooth.refresh()
    }

    Item {
        width: btScroll.availableWidth
        implicitHeight: btCol.implicitHeight + 40

        ColumnLayout {
            id: btCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Config ? (Config.language, Config.trAuto("Bluetooth и устройства")) : "Bluetooth и устройства"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "󰑐 Обновить"
                    onClicked: if (Bluetooth) Bluetooth.refresh()
                }
                StyledButton {
                    text: Bluetooth.scanning ? "󰑐 Поиск..." : "󰍉 Поиск устройств"
                    isActive: Bluetooth.scanning
                    onClicked: Bluetooth.scanDevices()
                }
                StyledButton {
                    text: "󰒓 Blueman"
                    onClicked: Bluetooth.openBlueman()
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: 48

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Text {
                        text: Bluetooth.powered ? "󰂯" : "󰂲"
                        color: Bluetooth.powered ? (Config ? Config.m3Primary : "#ffffff") : "#777777"
                        font.pixelSize: 18
                    }

                    Text {
                        text: Config ? (Config.language, Config.trAuto("Питание адаптера Bluetooth")) : "Питание адаптера Bluetooth"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: Waybar && Waybar.btConnectedCount > 0
                        width: btConnBadgeTxt.implicitWidth + 14
                        height: 22
                        radius: btScroll.isM3 ? 6 : 0
                        color: Qt.rgba(0.41, 0.94, 0.68, 0.18)
                        border.width: 1
                        border.color: Qt.rgba(0.41, 0.94, 0.68, 0.45)
                        Text {
                            id: btConnBadgeTxt
                            anchors.centerIn: parent
                            text: "Подключено: " + (Waybar ? Waybar.btConnectedCount : 0)
                            color: "#69f0ae"
                            font.pixelSize: Config.fontSize - 2
                            font.bold: true
                        }
                    }

                    StyledSwitch {
                        checked: Bluetooth.powered
                        onToggled: Bluetooth.powered = checked
                    }
                }
            }

            Text {
                visible: Bluetooth.powered
                text: (Config ? (Config.language, Config.trAuto("Устройства Bluetooth")) : "Устройства Bluetooth") + " • " + (Bluetooth ? Bluetooth.devices.length : 0)
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 1
                font.bold: true
                Layout.topMargin: 4
            }

            Text {
                visible: Bluetooth.powered && Bluetooth.devices.length === 0
                text: "Нет обнаруженных или сопряженных устройств. Нажмите «Поиск устройств»."
                color: "#888888"
                font.pixelSize: Config.fontSize - 1
            }

            Repeater {
                model: Bluetooth.devices

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: 50

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            width: 32; height: 32
                            radius: btScroll.isM3 ? 8 : 0
                            color: modelData.connected
                                   ? (Config ? Config.m3Primary : "#ffffff")
                                   : (btScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08))
                            Text {
                                anchors.centerIn: parent
                                text: modelData.isAudio ? "󰋋" : (modelData.connected ? "󰂱" : "󰂯")
                                color: modelData.connected
                                       ? (Config ? Config.accentTextColor : "#000000")
                                       : (Config ? Config.m3Primary : "#aaaaaa")
                                font.pixelSize: 15
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: modelData.connected
                                }
                                Rectangle {
                                    visible: modelData.connected
                                    width: connTagTxt.implicitWidth + 10
                                    height: 18
                                    radius: btScroll.isM3 ? 5 : 0
                                    color: Qt.rgba(0.41, 0.94, 0.68, 0.20)
                                    Text {
                                        id: connTagTxt
                                        anchors.centerIn: parent
                                        text: "ПОДКЛЮЧЕНО"
                                        color: "#69f0ae"
                                        font.pixelSize: Config.fontSize - 3
                                        font.bold: true
                                    }
                                }
                                Rectangle {
                                    visible: modelData.battery !== undefined && modelData.battery >= 0
                                    width: batTagTxt.implicitWidth + 10
                                    height: 18
                                    radius: btScroll.isM3 ? 5 : 0
                                    color: btScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.12)
                                    Text {
                                        id: batTagTxt
                                        anchors.centerIn: parent
                                        text: "󰁹 " + modelData.battery + "%"
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: Config.fontSize - 2
                                        font.bold: true
                                    }
                                }
                            }
                            Text {
                                text: modelData.mac + (modelData.connected ? "  •  Активно" : (modelData.paired ? "  •  Сопряжено" : ""))
                                color: modelData.connected ? "#bbbbbb" : "#777777"
                                font.pixelSize: Config.fontSize - 2
                            }
                        }

                        StyledButton {
                            text: modelData.connected ? "Отключить" : "Подключить"
                            isActive: modelData.connected
                            onClicked: Bluetooth.toggleConnect(modelData.mac, modelData.connected)
                        }

                        StyledButton {
                            text: "󰅖"
                            implicitWidth: 26
                            onClicked: Bluetooth.removeDevice(modelData.mac)
                        }
                    }
                }
            }
        }
    }
}
