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
                    Layout.alignment: Qt.AlignVCenter
                }
                StyledButton {
                    text: "󰑐 Обновить"
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: if (Bluetooth) Bluetooth.refresh()
                }
                StyledButton {
                    text: Bluetooth.scanning ? "󰑐 Поиск..." : "󰍉 Поиск устройств"
                    isActive: Bluetooth.scanning
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: Bluetooth.scanDevices()
                }
                StyledButton {
                    text: "󰒓 Blueman"
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: Bluetooth.openBlueman()
                }
            }

            // КАРТОЧКА 1: Питание адаптера
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: 50

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: Bluetooth.powered ? "󰂯" : "󰂲"
                            color: Bluetooth.powered ? (Config ? Config.m3Primary : "#ffffff") : "#777777"
                            font.pixelSize: 18
                        }
                    }

                    Text {
                        text: Config ? (Config.language, Config.trAuto("Питание адаптера Bluetooth")) : "Питание адаптера Bluetooth"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        visible: Waybar && Waybar.btConnectedCount > 0
                        Layout.preferredWidth: btConnBadgeTxt.implicitWidth + 14
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
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
                        Layout.alignment: Qt.AlignVCenter
                        checked: Bluetooth.powered
                        onToggled: Bluetooth.powered = checked
                    }
                }
            }

            // КАРТОЧКА 2: Автоподключение к наушникам
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: 52

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰋋"
                            color: Bluetooth.autoConnect ? (Config ? Config.m3Primary : "#ffffff") : "#777777"
                            font.pixelSize: 17
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: Config ? (Config.language, Config.trAuto("Автоподключение к наушникам")) : "Автоподключение к наушникам"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Автоматически подключать сопряженные наушники при их включении"
                            color: "#888888"
                            font.pixelSize: Config.fontSize - 2
                            elide: Text.ElideRight
                        }
                    }

                    StyledSwitch {
                        Layout.alignment: Qt.AlignVCenter
                        checked: Bluetooth.autoConnect
                        onToggled: Bluetooth.autoConnect = checked
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
                    implicitHeight: 54

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignVCenter
                            radius: btScroll.isM3 ? 9 : 0
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
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: modelData.connected
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Rectangle {
                                    visible: modelData.connected
                                    Layout.preferredWidth: connTagTxt.implicitWidth + 10
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter
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
                                    Layout.preferredWidth: batTagTxt.implicitWidth + 10
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: btScroll.isM3 ? 5 : 0
                                    color: btScroll.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.12)
                                    Text {
                                        id: batTagTxt
                                        anchors.centerIn: parent
                                        text: "󰁹  " + modelData.battery + "%"
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: Config.fontSize - 2
                                        font.bold: true
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.mac + (modelData.connected ? "  •  Активно" : (modelData.paired ? "  •  Сопряжено" : ""))
                                color: modelData.connected ? "#bbbbbb" : "#777777"
                                font.pixelSize: Config.fontSize - 2
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            StyledButton {
                                text: modelData.connected ? "Отключить" : "Подключить"
                                isActive: modelData.connected
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: Bluetooth.toggleConnect(modelData.mac, modelData.connected)
                            }

                            StyledButton {
                                text: "󰅖"
                                isIconOnly: true
                                implicitWidth: 26
                                implicitHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: Bluetooth.removeDevice(modelData.mac)
                            }
                        }
                    }
                }
            }
        }
    }
}
