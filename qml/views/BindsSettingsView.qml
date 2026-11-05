import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: bScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: bScroll.availableWidth
        implicitHeight: bCol.implicitHeight + 40

        ColumnLayout {
            id: bCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: Config ? (Config.language, Config.trAuto("Бинды клавиш (hyprland.lua)")) : "Бинды клавиш (hyprland.lua)"
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
                        id: newKey
                        placeholderText: "SUPER + Q"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        implicitHeight: 22
                        Layout.preferredWidth: 130
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 4 : 0
                            color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                        }
                    }

                    TextField {
                        id: newCmd
                        placeholderText: Config ? (Config.language, Config.trAuto("Команда запуска")) : "Команда запуска"
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

                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("+ Добавить")) : "+ Добавить"
                        onClicked: {
                            if (newKey.text.trim().length > 0 && newCmd.text.trim().length > 0) {
                                Binds.addItem(newKey.text, newCmd.text)
                                newKey.text = ""
                                newCmd.text = ""
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Binds.items

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
                            onToggled: Binds.toggleItem(index, checked)
                        }

                        TextField {
                            id: keyField
                            text: modelData.keys
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            font.bold: true
                            implicitHeight: 22
                            Layout.preferredWidth: 140
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                            }
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

                        StyledButton {
                            text: "󰆓"
                            implicitWidth: 22
                            onClicked: Binds.updateItem(index, modelData.enabled, keyField.text, cmdField.text)
                        }

                        StyledButton {
                            text: "󰆴"
                            implicitWidth: 22
                            onClicked: Binds.deleteItem(index)
                        }
                    }
                }
            }
        }
    }
}
