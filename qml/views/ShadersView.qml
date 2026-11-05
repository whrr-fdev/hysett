import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: shaderScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: shaderScroll.availableWidth
        implicitHeight: shaderCol.implicitHeight + 40

        ColumnLayout {
            id: shaderCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: Config ? (Config.language, Config.trAuto("Шейдеры экрана (Screen Shaders)")) : "Шейдеры экрана (Screen Shaders)"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 3
                        font.bold: true
                    }
                    Text {
                        text: Shaders.currentShader.length > 0 ?
                              "Активный шейдер: " + Shaders.currentShader : "Шейдеры отключены"
                        color: Shaders.currentShader.length > 0 ? "#ffffff" : "#888888"
                        font.pixelSize: Config.fontSize - 1
                    }
                }

                StyledButton {
                    text: Config ? (Config.language, Config.trAuto("✕  Отключить шейдер")) : "✕  Отключить шейдер"
                    visible: Shaders.currentShader.length > 0
                    onClicked: Shaders.clearShader()
                }

                StyledButton {
                    text: Config ? (Config.language, Config.trAuto("↺  Обновить")) : "↺  Обновить"
                    onClicked: Shaders.refresh()
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 8
                Layout.fillWidth: true

                Repeater {
                    model: Shaders.shaders

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        implicitHeight: 44

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "󰏘"
                                color: Shaders.currentShader === modelData.name ? "#ffffff" : "#777777"
                                font.pixelSize: 14
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: false
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.fileName
                                    color: "#666666"
                                    font.pixelSize: Config.fontSize - 2
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Правая колонка с тумблером на фиксированной позиции
                            StyledSwitch {
                                checked: Shaders.currentShader === modelData.name
                                onToggled: {
                                    if (checked) {
                                        Shaders.applyShader(modelData.name)
                                    } else {
                                        Shaders.clearShader()
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
