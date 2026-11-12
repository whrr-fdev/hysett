import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: btScroll
    contentWidth: availableWidth
    clip: true

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
                Text {
                    text: Config ? (Config.language, Config.trAuto("Bluetooth и устройства")) : "Bluetooth и устройства"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: Bluetooth.scanning ? "󰑐 Поиск..." : "󰍉 Поиск устройств"
                    onClicked: Bluetooth.scanDevices()
                }
                StyledButton {
                    text: "󰒓  Blueman Manager"
                    onClicked: Bluetooth.openBlueman()
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: 46

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        text: Config ? (Config.language, Config.trAuto("Питание адаптера Bluetooth")) : "Питание адаптера Bluetooth"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        Layout.fillWidth: true
                    }
                    StyledSwitch {
                        checked: Bluetooth.powered
                        onToggled: Bluetooth.powered = checked
                    }
                }
            }

            Text {
                visible: Bluetooth.powered
                text: Config ? (Config.language, Config.trAuto("Устройства Bluetooth")) : "Устройства Bluetooth"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 1
                font.bold: true
                Layout.topMargin: 4
            }

            Repeater {
                model: Bluetooth.devices

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: 44

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: modelData.connected ? "󰂱" : "󰂯"
                            color: modelData.connected ? "#ffffff" : "#888888"
                            font.pixelSize: 15
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                            }
                            Text {
                                text: modelData.mac + (modelData.connected ? "  •  Подключено" : (modelData.paired ? "  •  Сопряжено" : ""))
                                color: "#777777"
                                font.pixelSize: Config.fontSize - 2
                            }
                        }

                        StyledButton {
                            text: modelData.connected ? "Отключить" : "Подключить"
                            onClicked: Bluetooth.toggleConnect(modelData.mac, modelData.connected)
                        }

                        StyledButton {
                            text: "✕"
                            implicitWidth: 22
                            onClicked: Bluetooth.removeDevice(modelData.mac)
                        }
                    }
                }
            }
        }
    }
}
