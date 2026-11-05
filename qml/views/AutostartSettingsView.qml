import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: asScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: asScroll.availableWidth
        implicitHeight: asCol.implicitHeight + 40

        ColumnLayout {
            id: asCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: Config ? (Config.language, Config.trAuto("Автозапуск приложений (hyprland.lua)")) : "Автозапуск приложений (hyprland.lua)"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 4
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: addRow.implicitHeight + 16

                RowLayout {
                    id: addRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    TextField {
                        id: newCmd
                        placeholderText: Config ? (Config.language, Config.trAuto("Команда запуска (например: waybar &)")) : "Команда запуска (например: waybar &)"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        implicitHeight: 22
                        Layout.fillWidth: true
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 4 : 0
                            color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                        }
                    }

                    TextField {
                        id: newWs
                        placeholderText: Config ? (Config.language, Config.trAuto("Стол")) : "Стол"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        implicitHeight: 22
                        Layout.preferredWidth: 100
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 4 : 0
                            color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                        }
                    }

                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("+ Добавить")) : "+ Добавить"
                        onClicked: {
                            if (newCmd.text.trim().length > 0) {
                                Autostart.addItem(newCmd.text, newWs.text)
                                newCmd.text = ""
                                newWs.text = ""
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Autostart.items

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: itemRow.implicitHeight + 14

                    RowLayout {
                        id: itemRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        StyledSwitch {
                            checked: modelData.enabled
                            onToggled: Autostart.toggleItem(index, checked)
                        }

                        TextField {
                            id: cmdField
                            text: modelData.cmd
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 22
                            Layout.fillWidth: true
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            }
                        }

                        TextField {
                            id: wsField
                            text: modelData.workspace
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 22
                            Layout.preferredWidth: 80
                            placeholderText: Config ? (Config.language, Config.trAuto("Стол")) : "Стол"
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            }
                        }

                        StyledButton {
                            text: "󰆓"
                            implicitWidth: 22
                            onClicked: Autostart.updateItem(index, modelData.enabled, cmdField.text, wsField.text)
                        }

                        StyledButton {
                            text: "󰆴"
                            implicitWidth: 22
                            onClicked: Autostart.deleteItem(index)
                        }
                    }
                }
            }
        }
    }
}
