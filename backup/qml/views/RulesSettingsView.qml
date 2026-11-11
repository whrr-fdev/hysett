import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: rScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: rScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: Config ? (Config.language, Config.trAuto("Правила окон (hyprland.lua)")) : "Правила окон (hyprland.lua)"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 4
            }

            Repeater {
                model: Rules.rules

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colR.implicitHeight + 16

                    ColumnLayout {
                        id: colR
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Text {
                                text: "🗔  " + (modelData.className || modelData.name)
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            StyledSwitch {
                                checked: modelData.enabled
                                onToggled: Rules.toggleRule(index, checked)
                            }

                            StyledButton {
                                text: Config ? (Config.language, Config.trAuto("Удалить")) : "Удалить"
                                onClicked: Rules.deleteRule(index)
                            }
                        }

                        Text {
                            text: Config ? (Config.language, Config.trAuto("Плавающее: ")) : "Плавающее: " + (modelData.float ? "Да" : "Нет") +
                                  " | Центр: " + (modelData.center ? "Да" : "Нет") +
                                  " | Размер: " + (modelData.sizeW ? modelData.sizeW + "x" + modelData.sizeH : "-") +
                                  " | Стол: " + (modelData.workspace ? modelData.workspace : "-")
                            color: "#777777"
                            font.pixelSize: Config.fontSize - 2
                        }
                    }
                }
            }
        }
    }
}
