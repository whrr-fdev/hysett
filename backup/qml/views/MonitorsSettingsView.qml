import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: monRoot

    ScrollView {
        id: monScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: monScroll.availableWidth
            implicitHeight: monCol.implicitHeight + 40

            ColumnLayout {
                id: monCol
                width: Math.min(parent.width - 48, 880)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: Config ? (Config.language, Config.trAuto("Дисплей и Мониторы")) : "Дисплей и Мониторы"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 3
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("↺  Обновить список")) : "↺  Обновить список"
                        onClicked: Monitors.refreshMonitors()
                    }
                }

                Repeater {
                    model: Monitors.monitors

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        implicitHeight: colM.implicitHeight + 20

                        ColumnLayout {
                            id: colM
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Text {
                                    text: (index + 1) + ". " + (modelData.description || modelData.name)
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 1
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "[" + modelData.name + "]"
                                    color: "#888888"
                                    font.pixelSize: Config.fontSize - 1
                                }
                                StyledSwitch {
                                    checked: !modelData.disabled
                                    onToggled: Monitors.setMonitorDisabled(index, !checked)
                                }
                            }

                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Разрешение и частота:")) : "Разрешение и частота:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: modelData.availableModes
                                    currentIndex: modelData.currentModeIndex
                                    onActivated: (idx) => Monitors.requestMonitorMode(index, modelData.availableModes[idx])
                                }
                            }

                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Масштабирование (Scale):")) : "Масштабирование (Scale):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["1.0", "1.25", "1.5", "1.75", "2.0"]
                                    selectedIndex: {
                                        var sc = Number(modelData.scale).toFixed(2);
                                        if (sc === "1.25") return 1;
                                        if (sc === "1.50") return 2;
                                        if (sc === "1.75") return 3;
                                        if (sc === "2.00") return 4;
                                        return 0;
                                    }
                                    onSelected: (idx) => {
                                        var val = [1.0, 1.25, 1.5, 1.75, 2.0][idx]
                                        Monitors.setMonitorScale(index, val)
                                    }
                                }
                            }

                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Ориентация экрана:")) : "Ориентация экрана:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: ["Обычная (Normal)", "90°", "180°", "270°", "Отразить (Flipped)", "Отразить 90°", "Отразить 180°", "Отразить 270°"]
                                    currentIndex: Math.min(modelData.transform, 7)
                                    onActivated: (idx) => Monitors.setMonitorTransform(index, idx)
                                }
                            }
                        }
                    }
                }

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colDisp.implicitHeight + 18

                    ColumnLayout {
                        id: colDisp
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text { text: Config ? (Config.language, Config.trAuto("Настройки дисплея (Display Settings)")) : "Настройки дисплея (Display Settings)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Адаптивная частота (VRR / FreeSync):")) : "Адаптивная частота (VRR / FreeSync):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                            Item { Layout.fillWidth: true }
                            SegmentedButton {
                                options: ["Выкл", "Вкл", "В играх"]
                                selectedIndex: Monitors.vrrMode
                                onSelected: (idx) => Monitors.vrrMode = idx
                            }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Пробуждать экран мышью (DPMS):")) : "Пробуждать экран мышью (DPMS):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Monitors.mouseMoveDpms; onToggled: Monitors.mouseMoveDpms = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Пробуждать экран клавишами (DPMS):")) : "Пробуждать экран клавишами (DPMS):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Monitors.keyPressDpms; onToggled: Monitors.keyPressDpms = checked }
                        }
                    }
                }
            }
        }
    }

    Item {
        parent: Overlay.overlay
        anchors.fill: parent
        visible: Monitors.revertDialogActive

        MouseArea { anchors.fill: parent }

        GlassPanel {
            id: confirmCard
            anchors.centerIn: parent
            width: 380
            implicitHeight: colConfirm.implicitHeight + 30
            radius: (Theme && Theme.isRounded) ? 10 : 0
            tintColor: Qt.rgba(0.04, 0.04, 0.05, Config ? Config.dialogOpacity : 0.45)

            ShaderEffect {
                anchors.fill: parent
                z: 20
                enabled: false
                visible: Config ? Config.borderGlowEnabled : true
                property vector2d u_resolution: Qt.vector2d(width, height)
                property real u_radius: confirmCard.radius
                property real u_time: (ApplicationWindow.window ? ApplicationWindow.window.liquidTime : 0.0) * (Config ? Config.borderGlowSpeed : 1.0)
                property real u_intensity: Config ? Config.borderGlowIntensity : 0.75
                property real u_spread: Config ? Config.borderGlowSpread * 0.7 : 0.35
                property real u_color_mode: Config ? Config.borderGlowColorMode : 0
                property real u_direction: Config ? Config.borderGlowDirection : 0
                property real u_cursor_strength: 0.0
                property vector2d u_mouse: Qt.vector2d(-999, -999)
                property vector3d u_custom_color: Config ? Qt.vector3d(Config.borderGlowCustomColor.r, Config.borderGlowCustomColor.g, Config.borderGlowCustomColor.b) : Qt.vector3d(1, 1, 1)
                fragmentShader: "qrc:/shaders/qml/shaders/neon_border.frag.qsb"
            }

            ColumnLayout {
                id: colConfirm
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Text {
                    text: Config ? (Config.language, Config.trAuto("Сохранить новое разрешение?")) : "Сохранить новое разрешение?"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 2
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: Config ? (Config.language, Config.trAuto("Откат к прежнему режиму через ")) : "Откат к прежнему режиму через " + Monitors.revertCountdown + " сек..."
                    color: "#aaaaaa"
                    font.pixelSize: Config.fontSize
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("Сохранить")) : "Сохранить"
                        implicitWidth: 120
                        implicitHeight: 28
                        onClicked: Monitors.confirmMonitorMode()
                    }

                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("Вернуть назад")) : "Вернуть назад"
                        implicitWidth: 120
                        implicitHeight: 28
                        onClicked: Monitors.cancelMonitorMode()
                    }
                }
            }
        }
    }
}
