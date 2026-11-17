import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: canvasScroll
    contentWidth: availableWidth
    clip: true

    property real canvasSpeed: 3.2
    property int canvasInitScale: 78
    property real canvasAccel: 1.6
    property int canvasGap: 12
    property int canvasKeyStep: 110
    property bool canvasKeepSizeOnZoom: false
    property bool canvasInverted: false
    property bool canvasAllWorkspaces: true
    property bool canvasEdgePush: true

    function runCanvasCmd(argsStr) {
        if (Waybar) {
            Waybar.runCommand("python3 /home/whrr/hysett/scripts/hysett_infinite_canvas.py " + argsStr)
        }
    }

    Item {
        width: canvasScroll.availableWidth
        implicitHeight: mainCol.implicitHeight + 44

        ColumnLayout {
            id: mainCol
            width: Math.min(parent.width - 48, 860)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "󰆾  Бесконечный холст (Infinite Canvas)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                Rectangle {
                    height: 26
                    radius: (Theme && Theme.isRounded) ? 13 : 0
                    width: statusTxt.implicitWidth + 20
                    color: (Waybar && Waybar.canvasActive)
                           ? ((Theme && Theme.isRounded && Config) ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22) : Qt.rgba(0.4, 0.95, 0.65, 0.2))
                           : Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                    border.color: (Waybar && Waybar.canvasActive)
                                  ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae")
                                  : Qt.rgba(1, 1, 1, 0.18)
                    Text {
                        id: statusTxt
                        anchors.centerIn: parent
                        text: (Waybar && Waybar.canvasActive) ? "● АКТИВЕН (Super + S)" : "○ ВЫКЛЮЧЕН (Super + S)"
                        color: (Waybar && Waybar.canvasActive) ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae") : "#aaaaaa"
                        font.pixelSize: Config.fontSize - 1
                        font.bold: true
                    }
                }
            }

            // Карточка управления и быстрых действий
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: ctrlCol.implicitHeight + 28
                ColumnLayout {
                    id: ctrlCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Режим Бесконечного Холста"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                            }
                            Text {
                                text: "Объединяет окна со всех рабочих столов на единой бесконечной плоскости с возвратом на свои места при выходе"
                                color: "#aaaaaa"
                                font.pixelSize: Config.fontSize - 1
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        StyledSwitch {
                            checked: Waybar ? Waybar.canvasActive : false
                            onToggled: canvasScroll.runCanvasCmd("toggle")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        StyledButton {
                            text: (Waybar && Waybar.canvasActive) ? "󰅖 Выключить холст" : "󰆾 Включить холст"
                            Layout.fillWidth: true
                            onClicked: canvasScroll.runCanvasCmd("toggle")
                        }
                        StyledButton {
                            text: "󰕰 Собрать в сетку"
                            Layout.fillWidth: true
                            onClicked: canvasScroll.runCanvasCmd("home")
                        }
                        StyledButton {
                            text: "󰍸 Сбросить зум (100%)"
                            Layout.fillWidth: true
                            onClicked: canvasScroll.runCanvasCmd("zoom_reset")
                        }
                        StyledButton {
                            text: "󰒮 Пред. окно"
                            onClicked: canvasScroll.runCanvasCmd("prev")
                        }
                        StyledButton {
                            text: "󰒭 След. окно"
                            onClicked: canvasScroll.runCanvasCmd("next")
                        }
                    }
                }
            }

            // Карточка настроек физики, сетки и масштабирования
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: setCol.implicitHeight + 28
                ColumnLayout {
                    id: setCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "Параметры перемещения и сетки"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Скорость перетаскивания холста мышью:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 290 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 1.0; to: 6.0; stepSize: 0.1
                            value: canvasScroll.canvasSpeed
                            onMoved: {
                                canvasScroll.canvasSpeed = value
                                canvasScroll.runCanvasCmd("set speed " + value.toFixed(2))
                            }
                        }
                        Text { text: canvasScroll.canvasSpeed.toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Динамическое ускорение при резком взмахе:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 290 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0.0; to: 3.0; stepSize: 0.1
                            value: canvasScroll.canvasAccel
                            onMoved: {
                                canvasScroll.canvasAccel = value
                                canvasScroll.runCanvasCmd("set accel " + value.toFixed(2))
                            }
                        }
                        Text { text: "+" + canvasScroll.canvasAccel.toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Минимальный зазор между окнами в сетке:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 290 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 4; to: 64; stepSize: 2
                            value: canvasScroll.canvasGap
                            onMoved: {
                                canvasScroll.canvasGap = Math.round(value)
                                canvasScroll.runCanvasCmd("set min_gap " + canvasScroll.canvasGap)
                            }
                        }
                        Text { text: canvasScroll.canvasGap + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Шаг сдвига окна стрелками (Super + Shift + ←/→):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 290 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 24; to: 240; stepSize: 8
                            value: canvasScroll.canvasKeyStep
                            onMoved: {
                                canvasScroll.canvasKeyStep = Math.round(value)
                                canvasScroll.runCanvasCmd("set key_step " + canvasScroll.canvasKeyStep)
                            }
                        }
                        Text { text: canvasScroll.canvasKeyStep + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Размер окон при входе в холст (Super + S):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 290 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 55; to: 100; stepSize: 1
                            value: canvasScroll.canvasInitScale
                            onMoved: {
                                canvasScroll.canvasInitScale = Math.round(value)
                                canvasScroll.runCanvasCmd("set init_scale " + (canvasScroll.canvasInitScale / 100.0).toFixed(2))
                            }
                        }
                        Text { text: canvasScroll.canvasInitScale + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Собирать окна со всех рабочих столов (1–9):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: canvasScroll.canvasAllWorkspaces
                            onToggled: {
                                canvasScroll.canvasAllWorkspaces = checked
                                canvasScroll.runCanvasCmd("set all_workspaces " + (checked ? "true" : "false"))
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Сдвигать холст при подведении окна к краю экрана:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: canvasScroll.canvasEdgePush
                            onToggled: {
                                canvasScroll.canvasEdgePush = checked
                                canvasScroll.runCanvasCmd("set edge_push_enabled " + (checked ? "true" : "false"))
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Инвертировать направление перетаскивания мыши:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: canvasScroll.canvasInverted
                            onToggled: {
                                canvasScroll.canvasInverted = checked
                                canvasScroll.runCanvasCmd("set inverted " + (checked ? "true" : "false"))
                            }
                        }
                    }
                }
            }

            // Карточка всех горячих клавиш Бесконечного Холста
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: bindsCol.implicitHeight + 28
                ColumnLayout {
                    id: bindsCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "⌨  Горячие клавиши и управление Бесконечным Холстом"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                    }

                    Repeater {
                        model: [
                            { keys: "Super + S", desc: "Включить / выключить Бесконечный холст (переключает бинды и собирает окна со всех столов)", cmd: "toggle" },
                            { keys: "Super + ЛКМ (тянуть)", desc: "Перетаскивание всего бесконечного холста мышью (без Alt!)", cmd: "" },
                            { keys: "Super + ПКМ (тянуть)", desc: "Перетаскивание одного конкретного окна на холсте", cmd: "" },
                            { keys: "Super + ← / → / ↑ / ↓", desc: "Перелёт камеры к соседнему окну слева, справа, сверху или снизу с центрированием", cmd: "nav right" },
                            { keys: "Super + Колесо ↑ / ↓", desc: "Циклический перелёт по всем окнам на холсте по порядку (также Super + Tab)", cmd: "next" },
                            { keys: "Super + Shift + ← / → / ↑ / ↓", desc: "Сдвиг активного окна стрелками (при упоре в край экрана толкает остальной холст)", cmd: "" },
                            { keys: "Super + G", desc: "Собрать все разбросанные окна обратно в плотную сетку с минимальным зазором", cmd: "home" }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 210
                                    height: 26
                                    radius: (Theme && Theme.isRounded) ? 6 : 0
                                    color: (Theme && Theme.isRounded && Config)
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.16)
                                           : Qt.rgba(1, 1, 1, 0.10)
                                    border.width: 1
                                    border.color: (Theme && Theme.isRounded && Config)
                                                  ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45)
                                                  : Qt.rgba(1, 1, 1, 0.22)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.keys
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize - 1
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: modelData.desc
                                    color: "#dddddd"
                                    font.pixelSize: Config.fontSize - 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledButton {
                                    visible: modelData.cmd.length > 0
                                    text: "Тест"
                                    onClicked: canvasScroll.runCanvasCmd(modelData.cmd)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
