import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: timerRoot
    property var winObj: ApplicationWindow.window
    readonly property bool isM3: Theme && Theme.isRounded

    Connections {
        target: winObj
        function onTimerRemainingMsChanged() { timerArcCanvas.requestPaint() }
        function onTimerTotalMsChanged() { timerArcCanvas.requestPaint() }
        function onTimerRunningChanged() { timerArcCanvas.requestPaint() }
    }

    onVisibleChanged: if (visible) timerArcCanvas.requestPaint()

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󱎫  Таймер и Секундомер"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                visible: winObj && (winObj.timerActive || winObj.stopwatchActive)
                width: barHintTxt.implicitWidth + 16
                height: 24
                radius: timerRoot.isM3 ? 12 : 0
                color: timerRoot.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.08)
                Text {
                    id: barHintTxt
                    anchors.centerIn: parent
                    text: "󰄬 Отображается на панели задач"
                    color: timerRoot.isM3 && Config ? Config.m3Primary : "#69f0ae"
                    font.pixelSize: Config.fontSize - 1
                    font.bold: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // =================================================================
            // ЛЕВАЯ КАРТОЧКА: ТАЙМЕР ОБРАТНОГО ОТСЧЕТА
            // =================================================================
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(parent.width * 0.5)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "󰔛  Таймер"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 2
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (winObj && winObj.timerRunning)
                                  ? "Идёт отсчёт"
                                  : ((winObj && winObj.timerActive) ? "На паузе" : "Готов")
                            color: (winObj && winObj.timerRunning) ? "#69f0ae" : "#888888"
                            font.pixelSize: Config.fontSize - 1
                            font.bold: true
                        }
                    }

                    // Круговой индикатор и время таймера
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 150

                        Canvas {
                            id: timerArcCanvas
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height, 190)
                            height: width
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cx = width * 0.5
                                var cy = height * 0.5
                                var r = Math.max(10, Math.min(cx, cy) - 10)
                                var total = (winObj && winObj.timerTotalMs > 0) ? winObj.timerTotalMs : 1
                                var rem = winObj ? winObj.timerRemainingMs : 0
                                var prog = Math.max(0.0, Math.min(1.0, rem / total))

                                ctx.beginPath()
                                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                ctx.lineWidth = 7
                                ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
                                ctx.stroke()

                                if (prog > 0.002) {
                                    ctx.beginPath()
                                    var startA = -Math.PI * 0.5
                                    var endA = startA + Math.PI * 2 * prog
                                    ctx.arc(cx, cy, r, startA, endA, false)
                                    ctx.lineWidth = 7
                                    ctx.lineCap = "round"
                                    ctx.strokeStyle = Config ? Config.m3Primary.toString() : "#a8c7fa"
                                    ctx.stroke()
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: winObj ? winObj.timerBarText : "05:00"
                                color: "#ffffff"
                                font.pixelSize: 34
                                font.bold: true
                                font.family: "monospace"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: {
                                    var tot = winObj ? Math.round(winObj.timerTotalMs / 1000) : 300
                                    var m = Math.floor(tot / 60)
                                    var s = tot % 60
                                    return "Всего: " + (m > 0 ? m + " мин " : "") + (s > 0 ? s + " сек" : "")
                                }
                                color: "#888888"
                                font.pixelSize: Config.fontSize - 1
                            }
                        }
                    }

                    // Кнопки быстрой подстройки времени
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "-1 мин", delta: -60000 },
                                { label: "+10 сек", delta: 10000 },
                                { label: "+1 мин", delta: 60000 },
                                { label: "+5 мин", delta: 300000 }
                            ]
                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                implicitHeight: 26
                                text: modelData.label
                                onClicked: if (winObj) winObj.addTimerMs(modelData.delta)
                            }
                        }
                    }

                    // Пресеты длительности
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: [
                                { label: "1 мин", ms: 60000 },
                                { label: "3 мин", ms: 180000 },
                                { label: "5 мин", ms: 300000 },
                                { label: "10 мин", ms: 600000 },
                                { label: "15 мин", ms: 900000 },
                                { label: "25 мин", ms: 1500000 },
                                { label: "30 мин", ms: 1800000 },
                                { label: "60 мин", ms: 3600000 }
                            ]
                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                implicitHeight: 26
                                isActive: winObj && !winObj.timerActive && winObj.timerTotalMs === modelData.ms
                                text: modelData.label
                                onClicked: if (winObj) winObj.setTimerPreset(modelData.ms)
                            }
                        }
                    }

                    // Управление таймером
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledButton {
                            Layout.fillWidth: true
                            allowFullWidth: true
                            implicitHeight: 34
                            isActive: winObj ? winObj.timerRunning : false
                            text: (winObj && winObj.timerRunning)
                                  ? "󰏤   Пауза"
                                  : ((winObj && winObj.timerActive) ? "󰐊   Продолжить" : "󰐊   Запустить таймер")
                            onClicked: if (winObj) winObj.toggleTimerPause()
                        }

                        StyledButton {
                            implicitWidth: 110
                            implicitHeight: 34
                            enabled: winObj ? (winObj.timerActive || winObj.timerRemainingMs !== winObj.timerTotalMs) : false
                            text: "󰑐   Сброс"
                            onClicked: if (winObj) winObj.resetTimer()
                        }
                    }
                }
            }

            // =================================================================
            // ПРАВАЯ КАРТОЧКА: СЕКУНДОМЕР С КРУГАМИ (LAPS)
            // =================================================================
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(parent.width * 0.5)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "󱎫  Секундомер"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 2
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (winObj && winObj.stopwatchRunning)
                                  ? "Идёт замер"
                                  : ((winObj && winObj.stopwatchActive) ? "На паузе" : "00:00.00")
                            color: (winObj && winObj.stopwatchRunning) ? "#69f0ae" : "#888888"
                            font.pixelSize: Config.fontSize - 1
                            font.bold: true
                        }
                    }

                    // Табло секундомера
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 92
                        radius: timerRoot.isM3 ? 14 : 0
                        color: timerRoot.isM3 && Config
                               ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.35)
                               : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: (winObj && winObj.stopwatchRunning && Config)
                                      ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.55)
                                      : Qt.rgba(1, 1, 1, 0.12)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: winObj ? winObj.stopwatchFullText : "00:00.00"
                                color: (winObj && winObj.stopwatchRunning && Config) ? Config.m3Primary : "#ffffff"
                                font.pixelSize: 36
                                font.bold: true
                                font.family: "monospace"
                            }

                            Text {
                                visible: winObj && winObj.stopwatchLaps.length > 0
                                Layout.alignment: Qt.AlignHCenter
                                text: "Кругов записано: " + (winObj ? winObj.stopwatchLaps.length : 0)
                                color: "#888888"
                                font.pixelSize: Config.fontSize - 2
                            }
                        }
                    }

                    // Кнопки управления секундомером
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledButton {
                            Layout.fillWidth: true
                            allowFullWidth: true
                            implicitHeight: 34
                            isActive: winObj ? winObj.stopwatchRunning : false
                            text: (winObj && winObj.stopwatchRunning)
                                  ? "󰏤   Пауза"
                                  : ((winObj && winObj.stopwatchActive) ? "󰐊   Продолжить" : "󰐊   Старт")
                            onClicked: if (winObj) winObj.toggleStopwatch()
                        }

                        StyledButton {
                            implicitWidth: 105
                            implicitHeight: 34
                            enabled: winObj ? winObj.stopwatchRunning : false
                            text: "OutlinedFlag   Круг".replace("OutlinedFlag", "󰈻")
                            onClicked: if (winObj) winObj.lapStopwatch()
                        }

                        StyledButton {
                            implicitWidth: 105
                            implicitHeight: 34
                            enabled: winObj ? winObj.stopwatchActive : false
                            text: "󰑐   Сброс"
                            onClicked: if (winObj) winObj.resetStopwatch()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Список кругов (Laps)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            visible: !winObj || winObj.stopwatchLaps.length === 0
                            anchors.centerIn: parent
                            text: "Нажмите «Круг» во время работы секундомера\nдля записи промежуточных отрезков"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#777777"
                            font.pixelSize: Config.fontSize - 1
                        }

                        ListView {
                            id: lapsListView
                            anchors.fill: parent
                            clip: true
                            spacing: 5
                            visible: winObj && winObj.stopwatchLaps.length > 0
                            model: winObj ? winObj.stopwatchLaps : []
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                width: lapsListView.width
                                height: 30
                                radius: timerRoot.isM3 ? 8 : 0
                                color: index === 0
                                       ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.16) : Qt.rgba(1, 1, 1, 0.10))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: index === 0
                                              ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45) : Qt.rgba(1, 1, 1, 0.25))
                                              : Qt.rgba(1, 1, 1, 0.08)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: "Круг #" + modelData.num
                                        color: index === 0 ? (Config ? Config.m3Primary : "#ffffff") : "#cccccc"
                                        font.pixelSize: Config.fontSize
                                        font.bold: index === 0
                                        Layout.preferredWidth: 75
                                    }

                                    Text {
                                        text: "+" + modelData.lapTime
                                        color: "#69f0ae"
                                        font.pixelSize: Config.fontSize
                                        font.family: "monospace"
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: modelData.totalTime
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        font.family: "monospace"
                                        Layout.preferredWidth: 85
                                        horizontalAlignment: Text.AlignRight
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
