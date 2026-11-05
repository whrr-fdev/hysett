import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: animScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: animScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Config ? (Config.language, Config.trAuto("Анимации окон и рабочих столов")) : "Анимации окон и рабочих столов"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: Config ? (Config.language, Config.trAuto("↩ Откатить (")) : "↩ Откатить (" + Anims.backupCount + ")"
                    enabled: Anims.backupCount > 0
                    onClicked: Anims.undo()
                }
            }

            Repeater {
                model: Anims.anims

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colA.implicitHeight + 16

                    ColumnLayout {
                        id: colA
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Text {
                                text: modelData.title
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "↺"
                                implicitWidth: 22
                                onClicked: Anims.resetItem(index)
                            }
                            StyledSwitch {
                                checked: modelData.enabled
                                onToggled: Anims.setAnimEnabled(index, checked)
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Text { text: Config ? (Config.language, Config.trAuto("Скорость:")) : "Скорость:"; color: "#888888"; font.pixelSize: Config.fontSize }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: 0.5
                                to: 15.0
                                stepSize: 0.1
                                value: modelData.speed
                                onMoved: Anims.setAnimSpeed(index, value)
                            }
                            Text { text: Number(modelData.speed).toFixed(1); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }

                            StyledComboBox {
                                Layout.preferredWidth: 190
                                model: [
                                    "bezier: default",
                                    "bezier: easeOutQuint",
                                    "bezier: easeInOutCubic",
                                    "bezier: linear",
                                    "bezier: almostLinear",
                                    "bezier: quick",
                                    "spring: easy"
                                ]
                                currentIndex: {
                                    var cur = modelData.curve_kind + ": " + modelData.curve_name;
                                    for (var i = 0; i < count; ++i) {
                                        if (textAt(i) === cur) return i;
                                    }
                                    return 0;
                                }
                                onActivated: (idx) => {
                                    var pairs = [
                                        ["bezier", "default"],
                                        ["bezier", "easeOutQuint"],
                                        ["bezier", "easeInOutCubic"],
                                        ["bezier", "linear"],
                                        ["bezier", "almostLinear"],
                                        ["bezier", "quick"],
                                        ["spring", "easy"]
                                    ];
                                    Anims.setAnimCurve(index, pairs[idx][0], pairs[idx][1]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
