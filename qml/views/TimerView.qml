import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: timeRoot
    property var winObj: ApplicationWindow.window
    readonly property bool isM3: Theme && Theme.isRounded

    // 0 = Часы, 1 = Календарь, 2 = Таймер, 3 = Секундомер
    property int subTab: (winObj && winObj.timeSubTab !== undefined) ? winObj.timeSubTab : 0
    onSubTabChanged: {
        if (winObj && winObj.timeSubTab !== subTab) winObj.timeSubTab = subTab
        if (subTab !== 2) kbEditActive = false
        requestAllCanvases()
    }

    Connections {
        target: winObj
        function onTimeSubTabChanged() {
            if (winObj && timeRoot.subTab !== winObj.timeSubTab)
                timeRoot.subTab = winObj.timeSubTab
        }
        function onTimerRemainingMsChanged() { timerArcCanvas.requestPaint() }
        function onTimerTotalMsChanged() {
            if (!timeRoot.syncingTumblers && (!winObj || !winObj.timerActive)) {
                timeRoot.loadTumblersFromMs(winObj ? winObj.timerTotalMs : 300000)
            }
            timerArcCanvas.requestPaint()
        }
        function onTimerRunningChanged() { timerArcCanvas.requestPaint() }
        function onTimerActiveChanged() {
            if (winObj && !winObj.timerActive) {
                timeRoot.loadTumblersFromMs(winObj.timerTotalMs)
            }
            timerArcCanvas.requestPaint()
        }
        function onStopwatchElapsedMsChanged() { swArcCanvas.requestPaint() }
        function onStopwatchRunningChanged() { swArcCanvas.requestPaint() }
    }

    Connections {
        target: Config
        function onM3PrimaryChanged() { timeRoot.requestAllCanvases() }
        function onM3SecondaryContainerChanged() { timeRoot.requestAllCanvases() }
        function onAccentColorChanged() { timeRoot.requestAllCanvases() }
    }

    Connections {
        target: Theme
        function onIsRoundedChanged() { timeRoot.requestAllCanvases() }
    }

    function requestAllCanvases() {
        clockDialCanvas.requestPaint()
        timerArcCanvas.requestPaint()
        swArcCanvas.requestPaint()
    }

    // Состояние часов и календаря
    property var nowDate: new Date()
    property bool clock24h: true
    property bool clockShowSec: true
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    property int selectedCalDay: new Date().getDate()

    Timer {
        interval: 250
        running: timeRoot.visible && (timeRoot.subTab === 0 || timeRoot.subTab === 1)
        repeat: true
        onTriggered: {
            timeRoot.nowDate = new Date()
            if (timeRoot.subTab === 0) clockDialCanvas.requestPaint()
        }
    }

    // Состояние телефонного барабана и клавиатурного ввода таймера
    property bool syncingTumblers: false
    property bool kbEditActive: false

    function loadTumblersFromMs(ms) {
        syncingTumblers = true
        var totSec = Math.max(0, Math.round(ms / 1000))
        var h = Math.min(23, Math.floor(totSec / 3600))
        var m = Math.floor((totSec % 3600) / 60)
        var s = totSec % 60
        if (hoursTumbler.currentIndex !== h) hoursTumbler.currentIndex = h
        if (minsTumbler.currentIndex !== m) minsTumbler.currentIndex = m
        if (secsTumbler.currentIndex !== s) secsTumbler.currentIndex = s
        kbHoursInput.text = String(h).padStart(2, '0')
        kbMinsInput.text = String(m).padStart(2, '0')
        kbSecsInput.text = String(s).padStart(2, '0')
        syncingTumblers = false
    }

    function applyTumblerToTimer() {
        if (syncingTumblers || !winObj || winObj.timerActive) return
        var h = hoursTumbler.currentIndex
        var m = minsTumbler.currentIndex
        var s = secsTumbler.currentIndex
        var ms = (h * 3600 + m * 60 + s) * 1000
        if (ms < 1000) {
            secsTumbler.currentIndex = 5
            ms = 5000
        }
        winObj.setTimerPreset(ms)
    }

    function applyKeyboardInputToTimer() {
        if (!winObj) return
        var h = Math.max(0, Math.min(23, parseInt(kbHoursInput.text) || 0))
        var m = Math.max(0, Math.min(59, parseInt(kbMinsInput.text) || 0))
        var s = Math.max(0, Math.min(59, parseInt(kbSecsInput.text) || 0))
        var ms = Math.max(1000, (h * 3600 + m * 60 + s) * 1000)
        winObj.setTimerPreset(ms)
        loadTumblersFromMs(ms)
        kbEditActive = false
    }

    Component.onCompleted: {
        loadTumblersFromMs(winObj ? winObj.timerTotalMs : 300000)
        Qt.callLater(requestAllCanvases)
    }
    onVisibleChanged: if (visible) {
        nowDate = new Date()
        if (!winObj || !winObj.timerActive) loadTumblersFromMs(winObj ? winObj.timerTotalMs : 300000)
        requestAllCanvases()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // ЛЕВАЯ БОКОВАЯ ПАНЕЛЬ РАЗДЕЛОВ ВРЕМЕНИ (КАК В НАСТРОЙКАХ И ВИДЖЕТАХ)
        // =====================================================================
        Rectangle {
            id: subSidebar
            Layout.preferredWidth: timeRoot.isM3 ? 174 : 154
            Layout.fillHeight: true
            color: "transparent"

            property Item activeCardObj: {
                if (timeRoot.subTab === 0) return tCard0
                if (timeRoot.subTab === 1) return tCard1
                if (timeRoot.subTab === 2) return tCard2
                return tCard3
            }
            property Item hoveredCardObj: null
            property Item lastHoveredCardObj: null

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: timeRoot.isM3 && Config
                       ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.22)
                       : Qt.rgba(1, 1, 1, 0.08)
            }

            Rectangle {
                id: timeHoverPill
                x: 6
                width: subSidebar.width - 12
                height: 32
                radius: timeRoot.isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 10) : 0
                color: timeRoot.isM3 && Config
                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12)
                       : Qt.rgba(1, 1, 1, 0.08)
                opacity: subSidebar.hoveredCardObj && subSidebar.hoveredCardObj !== subSidebar.activeCardObj ? 1.0 : 0.0
                y: subSidebar.lastHoveredCardObj ? (subCol.y + subSidebar.lastHoveredCardObj.y) : 38
                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }

            Rectangle {
                id: timeActivePill
                x: 6
                width: subSidebar.width - 12
                height: 32
                radius: timeRoot.isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 10) : 0
                color: timeRoot.isM3 && Config ? Config.m3Primary : (Config ? Config.accentColor : "#ffffff")
                y: subSidebar.activeCardObj ? (subCol.y + subSidebar.activeCardObj.y) : 38
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                Behavior on radius { NumberAnimation { duration: 150 } }
            }

            ColumnLayout {
                id: subCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: Config ? (Config.language, Config.trAuto("󱑂  Время и Даты")) : "󱑂  Время и Даты"
                    color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 6
                    Layout.leftMargin: 6
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: timeRoot.isM3 && Config
                           ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18)
                           : Qt.rgba(1, 1, 1, 0.06)
                    Layout.bottomMargin: 2
                }

                Item {
                    id: tCard0
                    Layout.fillWidth: true
                    implicitHeight: 32
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: timeRoot.subTab = 0
                        onEntered: { subSidebar.lastHoveredCardObj = tCard0; subSidebar.hoveredCardObj = tCard0 }
                        onExited: if (subSidebar.hoveredCardObj === tCard0) subSidebar.hoveredCardObj = null
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            text: "󱑂  " + (Config ? (Config.language, Config.trAuto("Часы")) : "Часы")
                            color: timeRoot.subTab === 0
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : (subSidebar.hoveredCardObj === tCard0 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize
                            font.bold: timeRoot.subTab === 0
                            Layout.fillWidth: true
                        }
                    }
                }

                Item {
                    id: tCard1
                    Layout.fillWidth: true
                    implicitHeight: 32
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: timeRoot.subTab = 1
                        onEntered: { subSidebar.lastHoveredCardObj = tCard1; subSidebar.hoveredCardObj = tCard1 }
                        onExited: if (subSidebar.hoveredCardObj === tCard1) subSidebar.hoveredCardObj = null
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            text: "  " + (Config ? (Config.language, Config.trAuto("Календарь")) : "Календарь")
                            color: timeRoot.subTab === 1
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : (subSidebar.hoveredCardObj === tCard1 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize
                            font.bold: timeRoot.subTab === 1
                            Layout.fillWidth: true
                        }
                    }
                }

                Item {
                    id: tCard2
                    Layout.fillWidth: true
                    implicitHeight: 32
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: timeRoot.subTab = 2
                        onEntered: { subSidebar.lastHoveredCardObj = tCard2; subSidebar.hoveredCardObj = tCard2 }
                        onExited: if (subSidebar.hoveredCardObj === tCard2) subSidebar.hoveredCardObj = null
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 6
                        Text {
                            text: "󰔛  " + (Config ? (Config.language, Config.trAuto("Таймер")) : "Таймер")
                            color: timeRoot.subTab === 2
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : (subSidebar.hoveredCardObj === tCard2 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize
                            font.bold: timeRoot.subTab === 2
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: winObj && winObj.timerActive
                            width: 7; height: 7; radius: 3.5
                            color: timeRoot.subTab === 2
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : ((winObj && winObj.timerRunning) ? "#69f0ae" : "#ffd54f")
                        }
                    }
                }

                Item {
                    id: tCard3
                    Layout.fillWidth: true
                    implicitHeight: 32
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: timeRoot.subTab = 3
                        onEntered: { subSidebar.lastHoveredCardObj = tCard3; subSidebar.hoveredCardObj = tCard3 }
                        onExited: if (subSidebar.hoveredCardObj === tCard3) subSidebar.hoveredCardObj = null
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 6
                        Text {
                            text: "󱎫  " + (Config ? (Config.language, Config.trAuto("Секундомер")) : "Секундомер")
                            color: timeRoot.subTab === 3
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : (subSidebar.hoveredCardObj === tCard3 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize
                            font.bold: timeRoot.subTab === 3
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: winObj && winObj.stopwatchActive
                            width: 7; height: 7; radius: 3.5
                            color: timeRoot.subTab === 3
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : ((winObj && winObj.stopwatchRunning) ? "#69f0ae" : "#ffd54f")
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Мини-сводка активного таймера/секундомера внизу панели
                GlassPanel {
                    visible: winObj && (winObj.timerActive || winObj.stopwatchActive)
                    Layout.fillWidth: true
                    implicitHeight: miniStatusCol.implicitHeight + 16
                    ColumnLayout {
                        id: miniStatusCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        Text {
                            text: "󰄬 На панели задач"
                            color: Config ? Config.m3Primary : "#69f0ae"
                            font.pixelSize: Config.fontSize - 2
                            font.bold: true
                        }
                        Text {
                            visible: winObj && winObj.timerActive
                            text: "󰔛 " + (winObj ? winObj.timerBarText : "00:00")
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize - 1
                            font.family: "monospace"
                            font.bold: true
                        }
                        Text {
                            visible: winObj && winObj.stopwatchActive
                            text: "󱎫 " + (winObj ? winObj.stopwatchBarText : "00:00.0")
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize - 1
                            font.family: "monospace"
                            font.bold: true
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ПРАВАЯ ОБЛАСТЬ СОДЕРЖИМОГО (4 ЭКРАНА)
        // =====================================================================
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: timeRoot.subTab

            // -----------------------------------------------------------------
            // ЭКРАН 0: ЧАСЫ (КРУГОВОЙ ЦИФЕРБЛАТ С ПРОГРЕССОМ + МИРОВОЕ ВРЕМЯ)
            // -----------------------------------------------------------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󱑂  Системные часы и мировое время"
                            color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                            font.pixelSize: Config.fontSize + 3
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        SegmentedButton {
                            Layout.preferredWidth: 170
                            options: ["24 часа", "12 часов"]
                            selectedIndex: timeRoot.clock24h ? 0 : 1
                            onSelected: (idx) => { timeRoot.clock24h = (idx === 0); clockDialCanvas.requestPaint() }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        // Левая карточка: Круговой циферблат с прогрессом секунд и минут
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.54)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Canvas {
                                        id: clockDialCanvas
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height, 260)
                                        height: width
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width * 0.5
                                            var cy = height * 0.5
                                            var rOuter = Math.max(20, Math.min(cx, cy) - 12)
                                            var rInner = rOuter - 12

                                            var d = timeRoot.nowDate
                                            var sec = d.getSeconds() + d.getMilliseconds() / 1000.0
                                            var min = d.getMinutes() + sec / 60.0
                                            var secProg = sec / 60.0
                                            var minProg = min / 60.0

                                            var primCol = (Config ? Config.m3Primary : Qt.rgba(0.66, 0.78, 0.98, 1))
                                            var secCol = (Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1))

                                            // Деления циферблата (60 засечек)
                                            for (var i = 0; i < 60; ++i) {
                                                var ang = (i / 60.0) * Math.PI * 2 - Math.PI * 0.5
                                                var isMajor = (i % 5 === 0)
                                                var r1 = rOuter + 4
                                                var r2 = rOuter + (isMajor ? 9 : 6)
                                                ctx.beginPath()
                                                ctx.moveTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1)
                                                ctx.lineTo(cx + Math.cos(ang) * r2, cy + Math.sin(ang) * r2)
                                                ctx.lineWidth = isMajor ? 2.0 : 1.0
                                                ctx.strokeStyle = isMajor ? Qt.rgba(primCol.r, primCol.g, primCol.b, 0.55) : "rgba(255,255,255,0.14)"
                                                ctx.stroke()
                                            }

                                            // Фоновое кольцо секунд
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rOuter - 4, 0, Math.PI * 2)
                                            ctx.lineWidth = 7
                                            ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.42)
                                            ctx.stroke()

                                            // Активная дуга секунд + бегущая точка
                                            var startA = -Math.PI * 0.5
                                            var endSecA = startA + Math.PI * 2 * secProg
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rOuter - 4, startA, endSecA, false)
                                            ctx.lineWidth = 7
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = primCol.toString()
                                            ctx.stroke()

                                            var dotX = cx + Math.cos(endSecA) * (rOuter - 4)
                                            var dotY = cy + Math.sin(endSecA) * (rOuter - 4)
                                            ctx.beginPath()
                                            ctx.arc(dotX, dotY, 5.5, 0, Math.PI * 2)
                                            ctx.fillStyle = "#ffffff"
                                            ctx.fill()

                                            // Внутреннее кольцо минут
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rInner - 4, 0, Math.PI * 2)
                                            ctx.lineWidth = 4
                                            ctx.strokeStyle = "rgba(255,255,255,0.08)"
                                            ctx.stroke()

                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rInner - 4, startA, startA + Math.PI * 2 * minProg, false)
                                            ctx.lineWidth = 4
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = Qt.rgba(primCol.r, primCol.g, primCol.b, 0.55)
                                            ctx.stroke()
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: {
                                                var d = timeRoot.nowDate
                                                var fmt = timeRoot.clock24h
                                                          ? (timeRoot.clockShowSec ? "HH:mm:ss" : "HH:mm")
                                                          : (timeRoot.clockShowSec ? "hh:mm:ss AP" : "hh:mm AP")
                                                return Qt.formatDateTime(d, fmt)
                                            }
                                            color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 34
                                            font.bold: true
                                            font.family: "monospace"
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: Qt.formatDateTime(timeRoot.nowDate, "dddd, d MMMM yyyy")
                                            color: timeRoot.isM3 && Config
                                                   ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.78)
                                                   : "#aaaaaa"
                                            font.pixelSize: Config.fontSize
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Показывать секунды на циферблате:"
                                        color: "#cccccc"
                                        font.pixelSize: Config.fontSize
                                        Layout.fillWidth: true
                                    }
                                    StyledSwitch {
                                        checked: timeRoot.clockShowSec
                                        onToggled: timeRoot.clockShowSec = checked
                                    }
                                }
                            }
                        }

                        // Правая карточка: Часовые пояса и информация о дне
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.46)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                Text {
                                    text: "🌍  Мировое время и сводка дня"
                                    color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                    font.pixelSize: Config.fontSize + 1
                                    font.bold: true
                                }

                                // Прогресс текущих суток
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 58
                                    radius: timeRoot.isM3 ? (Config ? Math.min(14, Config.m3CardRadius) : 12) : 0
                                    color: timeRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.42)
                                           : Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: timeRoot.isM3 && Config
                                                  ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.25)
                                                  : Qt.rgba(1, 1, 1, 0.10)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "Прогресс текущих суток"
                                                color: "#cccccc"
                                                font.pixelSize: Config.fontSize - 1
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                readonly property real pct: ((timeRoot.nowDate.getHours() * 3600 + timeRoot.nowDate.getMinutes() * 60 + timeRoot.nowDate.getSeconds()) / 86400.0) * 100.0
                                                text: pct.toFixed(1) + "%"
                                                color: Config ? Config.m3Primary : "#ffffff"
                                                font.pixelSize: Config.fontSize - 1
                                                font.bold: true
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 6
                                            radius: timeRoot.isM3 ? 3 : 0
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                            Rectangle {
                                                width: parent.width * Math.min(1.0, (timeRoot.nowDate.getHours() * 3600 + timeRoot.nowDate.getMinutes() * 60 + timeRoot.nowDate.getSeconds()) / 86400.0)
                                                height: parent.height
                                                radius: parent.radius
                                                color: Config ? Config.m3Primary : "#a8c7fa"
                                            }
                                        }
                                    }
                                }

                                Repeater {
                                    model: [
                                        { city: "Москва (MSK)", offset: 3 },
                                        { city: "Лондон (UTC)", offset: 0 },
                                        { city: "Нью-Йорк (EST)", offset: -5 },
                                        { city: "Токио (JST)", offset: 9 },
                                        { city: "Дубай (GST)", offset: 4 }
                                    ]
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: timeRoot.isM3 ? (Config ? Math.min(10, Config.m3ControlRadius) : 8) : 0
                                        color: timeRoot.isM3 && Config
                                               ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.55)
                                               : Qt.rgba(1, 1, 1, 0.04)
                                        border.width: 1
                                        border.color: timeRoot.isM3 && Config
                                                      ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18)
                                                      : Qt.rgba(1, 1, 1, 0.08)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            Text {
                                                text: modelData.city
                                                color: "#dddddd"
                                                font.pixelSize: Config.fontSize
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: (modelData.offset >= 0 ? "UTC+" : "UTC") + modelData.offset
                                                color: "#888888"
                                                font.pixelSize: Config.fontSize - 2
                                                Layout.rightMargin: 8
                                            }
                                            Text {
                                                text: {
                                                    var d = timeRoot.nowDate
                                                    var utcMs = d.getTime() + (d.getTimezoneOffset() * 60000)
                                                    var cityDate = new Date(utcMs + modelData.offset * 3600000)
                                                    return Qt.formatDateTime(cityDate, timeRoot.clock24h ? "HH:mm:ss" : "hh:mm AP")
                                                }
                                                color: Config ? Config.m3Primary : "#ffffff"
                                                font.pixelSize: Config.fontSize
                                                font.family: "monospace"
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // ЭКРАН 1: КАЛЕНДАРЬ С ВЫБОРОМ ДАТЫ И ПОДДЕРЖКОЙ ТЕМЫ
            // -----------------------------------------------------------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "  Календарь"
                            color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                            font.pixelSize: Config.fontSize + 3
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        StyledButton {
                            text: "󰃭  Сегодня"
                            implicitHeight: 28
                            onClicked: {
                                var now = new Date()
                                timeRoot.calYear = now.getFullYear()
                                timeRoot.calMonth = now.getMonth()
                                timeRoot.selectedCalDay = now.getDate()
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                StyledButton {
                                    text: "«"; isIconOnly: true; implicitWidth: 32; implicitHeight: 28
                                    onClicked: timeRoot.calYear--
                                }
                                StyledButton {
                                    text: "‹"; isIconOnly: true; implicitWidth: 32; implicitHeight: 28
                                    onClicked: {
                                        if (timeRoot.calMonth === 0) { timeRoot.calMonth = 11; timeRoot.calYear-- }
                                        else timeRoot.calMonth--
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"][timeRoot.calMonth] + " " + timeRoot.calYear
                                    color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                    font.pixelSize: Config.fontSize + 3
                                    font.bold: true
                                }
                                StyledButton {
                                    text: "›"; isIconOnly: true; implicitWidth: 32; implicitHeight: 28
                                    onClicked: {
                                        if (timeRoot.calMonth === 11) { timeRoot.calMonth = 0; timeRoot.calYear++ }
                                        else timeRoot.calMonth++
                                    }
                                }
                                StyledButton {
                                    text: "»"; isIconOnly: true; implicitWidth: 32; implicitHeight: 28
                                    onClicked: timeRoot.calYear++
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 7
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                                    delegate: Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: index >= 5
                                               ? (Config ? Config.m3Primary : "#a8c7fa")
                                               : "#888888"
                                        font.pixelSize: Config.fontSize
                                        font.bold: true
                                    }
                                }

                                Repeater {
                                    model: 42
                                    delegate: Rectangle {
                                        id: dayCell
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 32
                                        property var cellInfo: {
                                            var firstDay = (new Date(timeRoot.calYear, timeRoot.calMonth, 1).getDay() + 6) % 7
                                            var daysInM = new Date(timeRoot.calYear, timeRoot.calMonth + 1, 0).getDate()
                                            var dNum = index - firstDay + 1
                                            var valid = (dNum >= 1 && dNum <= daysInM)
                                            var now = timeRoot.nowDate
                                            var isToday = valid && (dNum === now.getDate() && timeRoot.calMonth === now.getMonth() && timeRoot.calYear === now.getFullYear())
                                            var isSel = valid && (dNum === timeRoot.selectedCalDay)
                                            return { day: valid ? dNum : "", valid: valid, today: isToday, selected: isSel }
                                        }

                                        radius: timeRoot.isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 10) : 0
                                        color: {
                                            if (!cellInfo.valid) return "transparent"
                                            if (cellInfo.today) return Config ? Config.m3Primary : "#ffffff"
                                            if (cellInfo.selected) return Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.16)
                                            if (dayMa.containsMouse) return Qt.rgba(1, 1, 1, 0.08)
                                            return timeRoot.isM3 && Config
                                                   ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.38)
                                                   : Qt.rgba(1, 1, 1, 0.03)
                                        }
                                        border.width: cellInfo.valid ? 1 : 0
                                        border.color: {
                                            if (!cellInfo.valid || cellInfo.today) return "transparent"
                                            if (cellInfo.selected) return Config ? Config.m3Primary : "#ffffff"
                                            return timeRoot.isM3 && Config
                                                   ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.22)
                                                   : Qt.rgba(1, 1, 1, 0.08)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.cellInfo.day
                                            color: {
                                                if (dayCell.cellInfo.today) return Config ? Config.accentTextColor : "#000000"
                                                if (dayCell.cellInfo.selected) return Config ? Config.m3Primary : "#ffffff"
                                                return "#ffffff"
                                            }
                                            font.pixelSize: Config.fontSize + 1
                                            font.bold: dayCell.cellInfo.today || dayCell.cellInfo.selected
                                        }

                                        MouseArea {
                                            id: dayMa
                                            anchors.fill: parent
                                            enabled: dayCell.cellInfo.valid
                                            hoverEnabled: true
                                            cursorShape: dayCell.cellInfo.valid ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: timeRoot.selectedCalDay = dayCell.cellInfo.day
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // ЭКРАН 2: ТАЙМЕР (КРУГ ПРОГРЕССА + БАРАБАН КАК НА ТЕЛЕФОНЕ + ВВОД С КЛАВИАТУРЫ)
            // -----------------------------------------------------------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󰔛  Таймер обратного отсчёта"
                            color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                            font.pixelSize: Config.fontSize + 3
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (winObj && winObj.timerRunning)
                                  ? "● Идёт отсчёт"
                                  : ((winObj && winObj.timerActive) ? "⏸ На паузе" : "Готов к запуску")
                            color: (winObj && winObj.timerRunning)
                                   ? (Config ? Config.m3Primary : "#69f0ae")
                                   : "#888888"
                            font.pixelSize: Config.fontSize
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        // Левая карточка: Большой круг прогресса с бегущей точкой и вводом с клавиатуры
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.50)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 190

                                    Canvas {
                                        id: timerArcCanvas
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height, 240)
                                        height: width
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width * 0.5
                                            var cy = height * 0.5
                                            var r = Math.max(16, Math.min(cx, cy) - 14)
                                            var total = (winObj && winObj.timerTotalMs > 0) ? winObj.timerTotalMs : 1
                                            var rem = winObj ? winObj.timerRemainingMs : 0
                                            var prog = Math.max(0.0, Math.min(1.0, rem / total))

                                            var primCol = Config ? Config.m3Primary : Qt.rgba(0.66, 0.78, 0.98, 1)
                                            var secCol = Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1)

                                            // Засечки по кругу
                                            for (var i = 0; i < 60; ++i) {
                                                var ang = (i / 60.0) * Math.PI * 2 - Math.PI * 0.5
                                                var isMaj = (i % 5 === 0)
                                                ctx.beginPath()
                                                ctx.moveTo(cx + Math.cos(ang) * (r + 5), cy + Math.sin(ang) * (r + 5))
                                                ctx.lineTo(cx + Math.cos(ang) * (r + (isMaj ? 10 : 7)), cy + Math.sin(ang) * (r + (isMaj ? 10 : 7)))
                                                ctx.lineWidth = isMaj ? 1.8 : 1.0
                                                ctx.strokeStyle = isMaj ? Qt.rgba(primCol.r, primCol.g, primCol.b, 0.45) : "rgba(255,255,255,0.12)"
                                                ctx.stroke()
                                            }

                                            // Подложка трека
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r - 3, 0, Math.PI * 2)
                                            ctx.lineWidth = 8
                                            ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.45)
                                            ctx.stroke()

                                            // Дуга прогресса + светящийся маркер-кружок на конце
                                            if (prog > 0.002) {
                                                var startA = -Math.PI * 0.5
                                                var endA = startA + Math.PI * 2 * prog
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r - 3, startA, endA, false)
                                                ctx.lineWidth = 8
                                                ctx.lineCap = "round"
                                                ctx.strokeStyle = primCol.toString()
                                                ctx.stroke()

                                                var tipX = cx + Math.cos(endA) * (r - 3)
                                                var tipY = cy + Math.sin(endA) * (r - 3)
                                                ctx.beginPath()
                                                ctx.arc(tipX, tipY, 6, 0, Math.PI * 2)
                                                ctx.fillStyle = "#ffffff"
                                                ctx.fill()
                                            }
                                        }
                                    }

                                    // Отображение времени ИЛИ прямой ввод с клавиатуры внутри круга
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        // Режим обычного показа цифр (клик включает ввод с клавиатуры)
                                        Item {
                                            visible: !timeRoot.kbEditActive
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: timerBigDigits.implicitWidth + 16
                                            implicitHeight: timerBigDigits.implicitHeight + 6

                                            Text {
                                                id: timerBigDigits
                                                anchors.centerIn: parent
                                                text: winObj ? winObj.timerBarText : "05:00"
                                                color: (winObj && winObj.timerRunning && Config) ? Config.m3Primary : "#ffffff"
                                                font.pixelSize: 34
                                                font.bold: true
                                                font.family: "monospace"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.IBeamCursor
                                                onClicked: {
                                                    if (winObj && winObj.timerRunning) winObj.toggleTimerPause()
                                                    timeRoot.loadTumblersFromMs(winObj ? winObj.timerRemainingMs : 300000)
                                                    timeRoot.kbEditActive = true
                                                    kbMinsInput.forceActiveFocus()
                                                    kbMinsInput.selectAll()
                                                }
                                            }
                                        }

                                        // Режим ввода с клавиатуры (ЧЧ : ММ : СС)
                                        RowLayout {
                                            visible: timeRoot.kbEditActive
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 2

                                            TextField {
                                                id: kbHoursInput
                                                Layout.preferredWidth: 44
                                                implicitHeight: 36
                                                horizontalAlignment: Text.AlignHCenter
                                                color: "#ffffff"
                                                font.pixelSize: 20
                                                font.bold: true
                                                font.family: "monospace"
                                                selectByMouse: true
                                                validator: IntValidator { bottom: 0; top: 23 }
                                                KeyNavigation.tab: kbMinsInput
                                                onAccepted: timeRoot.applyKeyboardInputToTimer()
                                                background: Rectangle {
                                                    radius: timeRoot.isM3 ? 8 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.10)
                                                    border.width: parent.activeFocus ? 1.5 : 1
                                                    border.color: parent.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.25)
                                                }
                                            }
                                            Text { text: ":"; color: "#ffffff"; font.pixelSize: 20; font.bold: true }
                                            TextField {
                                                id: kbMinsInput
                                                Layout.preferredWidth: 44
                                                implicitHeight: 36
                                                horizontalAlignment: Text.AlignHCenter
                                                color: "#ffffff"
                                                font.pixelSize: 20
                                                font.bold: true
                                                font.family: "monospace"
                                                selectByMouse: true
                                                validator: IntValidator { bottom: 0; top: 59 }
                                                KeyNavigation.tab: kbSecsInput
                                                onAccepted: timeRoot.applyKeyboardInputToTimer()
                                                background: Rectangle {
                                                    radius: timeRoot.isM3 ? 8 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.10)
                                                    border.width: parent.activeFocus ? 1.5 : 1
                                                    border.color: parent.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.25)
                                                }
                                            }
                                            Text { text: ":"; color: "#ffffff"; font.pixelSize: 20; font.bold: true }
                                            TextField {
                                                id: kbSecsInput
                                                Layout.preferredWidth: 44
                                                implicitHeight: 36
                                                horizontalAlignment: Text.AlignHCenter
                                                color: "#ffffff"
                                                font.pixelSize: 20
                                                font.bold: true
                                                font.family: "monospace"
                                                selectByMouse: true
                                                validator: IntValidator { bottom: 0; top: 59 }
                                                KeyNavigation.tab: kbHoursInput
                                                onAccepted: timeRoot.applyKeyboardInputToTimer()
                                                background: Rectangle {
                                                    radius: timeRoot.isM3 ? 8 : 0
                                                    color: Qt.rgba(1, 1, 1, 0.10)
                                                    border.width: parent.activeFocus ? 1.5 : 1
                                                    border.color: parent.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.25)
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: timeRoot.kbEditActive
                                                  ? "Нажмите Enter для сохранения"
                                                  : "󰌌 Нажмите на цифры для ввода с клавиатуры"
                                            color: timeRoot.kbEditActive ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                                            font.pixelSize: Config.fontSize - 2
                                        }
                                    }
                                }

                                // Кнопки быстрой подстройки на лету
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "-1 мин", delta: -60000 },
                                            { label: "+15 сек", delta: 15000 },
                                            { label: "+1 мин", delta: 60000 },
                                            { label: "+5 мин", delta: 300000 }
                                        ]
                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            implicitHeight: 28
                                            text: modelData.label
                                            onClicked: {
                                                if (winObj) {
                                                    winObj.addTimerMs(modelData.delta)
                                                    if (!winObj.timerActive) timeRoot.loadTumblersFromMs(winObj.timerTotalMs)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Запуск / Пауза / Сброс
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledButton {
                                        Layout.fillWidth: true
                                        allowFullWidth: true
                                        implicitHeight: 36
                                        isActive: winObj ? winObj.timerRunning : false
                                        text: timeRoot.kbEditActive
                                              ? "󰄬  Применить и запустить"
                                              : ((winObj && winObj.timerRunning)
                                                 ? "󰏤   Пауза"
                                                 : ((winObj && winObj.timerActive) ? "󰐊   Продолжить" : "󰐊   Запустить таймер"))
                                        onClicked: {
                                            if (timeRoot.kbEditActive) timeRoot.applyKeyboardInputToTimer()
                                            if (winObj) winObj.toggleTimerPause()
                                        }
                                    }

                                    StyledButton {
                                        implicitWidth: 110
                                        implicitHeight: 36
                                        enabled: winObj ? (winObj.timerActive || winObj.timerRemainingMs !== winObj.timerTotalMs) : false
                                        text: "󰑐   Сброс"
                                        onClicked: {
                                            if (winObj) {
                                                winObj.resetTimer()
                                                timeRoot.loadTumblersFromMs(winObj.timerTotalMs)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Правая карточка: Телефонный барабан прокрутки времени (ЧЧ : ММ : СС) + Ввод + Пресеты
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.50)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "󰓦  Выбор времени (прокрутка / ввод)"
                                        color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    StyledButton {
                                        text: timeRoot.kbEditActive ? "󰄬 Готово" : "󰌌 Ввести"
                                        implicitHeight: 26
                                        isActive: timeRoot.kbEditActive
                                        onClicked: {
                                            if (timeRoot.kbEditActive) {
                                                timeRoot.applyKeyboardInputToTimer()
                                            } else {
                                                if (winObj && winObj.timerRunning) winObj.toggleTimerPause()
                                                timeRoot.loadTumblersFromMs(winObj ? winObj.timerRemainingMs : 300000)
                                                timeRoot.kbEditActive = true
                                                kbMinsInput.forceActiveFocus()
                                                kbMinsInput.selectAll()
                                            }
                                        }
                                    }
                                }

                                // ТЕЛЕФОННЫЙ БАРАБАН ПРОКРУТКИ (ЧЧ : ММ : СС) С КОЛЕСИКОМ И СВАЙПОМ
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 138
                                    radius: timeRoot.isM3 ? (Config ? Math.min(16, Config.m3CardRadius) : 14) : 0
                                    color: timeRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.45)
                                           : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: timeRoot.isM3 && Config
                                                  ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.25)
                                                  : Qt.rgba(1, 1, 1, 0.10)
                                    clip: true

                                    // Центральная полоса выделения активной строки барабана
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        height: 36
                                        radius: timeRoot.isM3 ? (Config ? Math.min(10, Config.m3ControlRadius) : 8) : 0
                                        color: timeRoot.isM3 && Config
                                               ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.65)
                                               : Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1
                                        border.color: timeRoot.isM3 && Config
                                                      ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.55)
                                                      : Qt.rgba(1, 1, 1, 0.25)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 4

                                        // Барабан ЧАСЫ (0..23)
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Tumbler {
                                                id: hoursTumbler
                                                anchors.fill: parent
                                                model: 24
                                                visibleItemCount: 3
                                                wrap: true
                                                enabled: !winObj || !winObj.timerActive
                                                onCurrentIndexChanged: timeRoot.applyTumblerToTimer()
                                                background: Item {}
                                                delegate: Text {
                                                    text: String(modelData).padStart(2, '0') + " ч"
                                                    color: Tumbler.displacement === 0
                                                           ? (Config ? Config.m3Primary : "#ffffff")
                                                           : "#888888"
                                                    font.pixelSize: Math.abs(Tumbler.displacement) < 0.35 ? 20 : 14
                                                    font.bold: Math.abs(Tumbler.displacement) < 0.35
                                                    font.family: "monospace"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    opacity: Math.max(0.25, 1.0 - Math.abs(Tumbler.displacement) * 0.55)
                                                }
                                            }
                                            WheelHandler {
                                                enabled: !winObj || !winObj.timerActive
                                                onWheel: (e) => {
                                                    if (e.angleDelta.y < 0) hoursTumbler.currentIndex = (hoursTumbler.currentIndex + 1) % 24
                                                    else if (e.angleDelta.y > 0) hoursTumbler.currentIndex = (hoursTumbler.currentIndex + 23) % 24
                                                }
                                            }
                                        }

                                        Text { text: ":"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 20; font.bold: true }

                                        // Барабан МИНУТЫ (0..59)
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Tumbler {
                                                id: minsTumbler
                                                anchors.fill: parent
                                                model: 60
                                                visibleItemCount: 3
                                                wrap: true
                                                enabled: !winObj || !winObj.timerActive
                                                onCurrentIndexChanged: timeRoot.applyTumblerToTimer()
                                                background: Item {}
                                                delegate: Text {
                                                    text: String(modelData).padStart(2, '0') + " м"
                                                    color: Tumbler.displacement === 0
                                                           ? (Config ? Config.m3Primary : "#ffffff")
                                                           : "#888888"
                                                    font.pixelSize: Math.abs(Tumbler.displacement) < 0.35 ? 20 : 14
                                                    font.bold: Math.abs(Tumbler.displacement) < 0.35
                                                    font.family: "monospace"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    opacity: Math.max(0.25, 1.0 - Math.abs(Tumbler.displacement) * 0.55)
                                                }
                                            }
                                            WheelHandler {
                                                enabled: !winObj || !winObj.timerActive
                                                onWheel: (e) => {
                                                    if (e.angleDelta.y < 0) minsTumbler.currentIndex = (minsTumbler.currentIndex + 1) % 60
                                                    else if (e.angleDelta.y > 0) minsTumbler.currentIndex = (minsTumbler.currentIndex + 59) % 60
                                                }
                                            }
                                        }

                                        Text { text: ":"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 20; font.bold: true }

                                        // Барабан СЕКУНДЫ (0..59)
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Tumbler {
                                                id: secsTumbler
                                                anchors.fill: parent
                                                model: 60
                                                visibleItemCount: 3
                                                wrap: true
                                                enabled: !winObj || !winObj.timerActive
                                                onCurrentIndexChanged: timeRoot.applyTumblerToTimer()
                                                background: Item {}
                                                delegate: Text {
                                                    text: String(modelData).padStart(2, '0') + " с"
                                                    color: Tumbler.displacement === 0
                                                           ? (Config ? Config.m3Primary : "#ffffff")
                                                           : "#888888"
                                                    font.pixelSize: Math.abs(Tumbler.displacement) < 0.35 ? 20 : 14
                                                    font.bold: Math.abs(Tumbler.displacement) < 0.35
                                                    font.family: "monospace"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    opacity: Math.max(0.25, 1.0 - Math.abs(Tumbler.displacement) * 0.55)
                                                }
                                            }
                                            WheelHandler {
                                                enabled: !winObj || !winObj.timerActive
                                                onWheel: (e) => {
                                                    if (e.angleDelta.y < 0) secsTumbler.currentIndex = (secsTumbler.currentIndex + 1) % 60
                                                    else if (e.angleDelta.y > 0) secsTumbler.currentIndex = (secsTumbler.currentIndex + 59) % 60
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "Быстрые пресеты:"
                                    color: "#999999"
                                    font.pixelSize: Config.fontSize - 1
                                }

                                // Сетка быстрых пресетов
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
                                            implicitHeight: 28
                                            isActive: winObj && !winObj.timerActive && winObj.timerTotalMs === modelData.ms
                                            text: modelData.label
                                            onClicked: {
                                                if (winObj) {
                                                    winObj.setTimerPreset(modelData.ms)
                                                    timeRoot.loadTumblersFromMs(modelData.ms)
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

            // -----------------------------------------------------------------
            // ЭКРАН 3: СЕКУНДОМЕР С КРУГОВЫМ ПРОГРЕССОМ И ТАБЛИЦЕЙ КРУГОВ
            // -----------------------------------------------------------------
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󱎫  Секундомер и замер кругов"
                            color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                            font.pixelSize: Config.fontSize + 3
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (winObj && winObj.stopwatchRunning)
                                  ? "● Идёт замер"
                                  : ((winObj && winObj.stopwatchActive) ? "⏸ На паузе" : "Готов")
                            color: (winObj && winObj.stopwatchRunning)
                                   ? (Config ? Config.m3Primary : "#69f0ae")
                                   : "#888888"
                            font.pixelSize: Config.fontSize
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 14

                        // Левая карточка: Круговой прогресс 60-секундного оборота и текущего круга
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.50)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 190

                                    Canvas {
                                        id: swArcCanvas
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height, 240)
                                        height: width
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            var cx = width * 0.5
                                            var cy = height * 0.5
                                            var rOuter = Math.max(16, Math.min(cx, cy) - 14)
                                            var rInner = rOuter - 12

                                            var elapsed = winObj ? winObj.stopwatchElapsedMs : 0
                                            var lapElapsed = Math.max(0, elapsed - (winObj ? winObj.stopwatchLastLapMs : 0))
                                            var mainProg = (elapsed % 60000) / 60000.0
                                            var lapProg = (lapElapsed % 60000) / 60000.0

                                            var primCol = Config ? Config.m3Primary : Qt.rgba(0.66, 0.78, 0.98, 1)
                                            var secCol = Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1)

                                            // Засечки секундомера
                                            for (var i = 0; i < 60; ++i) {
                                                var ang = (i / 60.0) * Math.PI * 2 - Math.PI * 0.5
                                                var isMaj = (i % 5 === 0)
                                                ctx.beginPath()
                                                ctx.moveTo(cx + Math.cos(ang) * (rOuter + 5), cy + Math.sin(ang) * (rOuter + 5))
                                                ctx.lineTo(cx + Math.cos(ang) * (rOuter + (isMaj ? 10 : 7)), cy + Math.sin(ang) * (rOuter + (isMaj ? 10 : 7)))
                                                ctx.lineWidth = isMaj ? 1.8 : 1.0
                                                ctx.strokeStyle = isMaj ? Qt.rgba(primCol.r, primCol.g, primCol.b, 0.45) : "rgba(255,255,255,0.12)"
                                                ctx.stroke()
                                            }

                                            // Подложка внешнего круга
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rOuter - 3, 0, Math.PI * 2)
                                            ctx.lineWidth = 8
                                            ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.45)
                                            ctx.stroke()

                                            // Активная дуга оборота минуты + бегущая точка
                                            var startA = -Math.PI * 0.5
                                            if (elapsed > 0) {
                                                var endA = startA + Math.PI * 2 * (mainProg > 0.001 ? mainProg : 1.0)
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, rOuter - 3, startA, endA, false)
                                                ctx.lineWidth = 8
                                                ctx.lineCap = "round"
                                                ctx.strokeStyle = primCol.toString()
                                                ctx.stroke()

                                                var tipX = cx + Math.cos(endA) * (rOuter - 3)
                                                var tipY = cy + Math.sin(endA) * (rOuter - 3)
                                                ctx.beginPath()
                                                ctx.arc(tipX, tipY, 6, 0, Math.PI * 2)
                                                ctx.fillStyle = "#ffffff"
                                                ctx.fill()
                                            }

                                            // Внутренняя дуга текущего круга (Lap)
                                            if (winObj && winObj.stopwatchLaps.length > 0) {
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, rInner - 3, 0, Math.PI * 2)
                                                ctx.lineWidth = 4
                                                ctx.strokeStyle = "rgba(255,255,255,0.08)"
                                                ctx.stroke()

                                                ctx.beginPath()
                                                ctx.arc(cx, cy, rInner - 3, startA, startA + Math.PI * 2 * lapProg, false)
                                                ctx.lineWidth = 4
                                                ctx.lineCap = "round"
                                                ctx.strokeStyle = "#69f0ae"
                                                ctx.stroke()
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: winObj ? winObj.stopwatchFullText : "00:00.00"
                                            color: (winObj && winObj.stopwatchRunning && Config) ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 32
                                            font.bold: true
                                            font.family: "monospace"
                                        }

                                        Text {
                                            visible: winObj && winObj.stopwatchActive
                                            Layout.alignment: Qt.AlignHCenter
                                            text: {
                                                var curLap = winObj ? Math.max(0, winObj.stopwatchElapsedMs - winObj.stopwatchLastLapMs) : 0
                                                return "Текущий круг: " + (winObj ? winObj.formatClockMs(curLap, false, true) : "00:00.00")
                                            }
                                            color: "#69f0ae"
                                            font.pixelSize: Config.fontSize - 1
                                            font.family: "monospace"
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledButton {
                                        Layout.fillWidth: true
                                        allowFullWidth: true
                                        implicitHeight: 36
                                        isActive: winObj ? winObj.stopwatchRunning : false
                                        text: (winObj && winObj.stopwatchRunning)
                                              ? "󰏤   Пауза"
                                              : ((winObj && winObj.stopwatchActive) ? "󰐊   Продолжить" : "󰐊   Старт")
                                        onClicked: if (winObj) winObj.toggleStopwatch()
                                    }

                                    StyledButton {
                                        implicitWidth: 105
                                        implicitHeight: 36
                                        enabled: winObj ? winObj.stopwatchRunning : false
                                        text: "󰈻   Круг"
                                        onClicked: if (winObj) winObj.lapStopwatch()
                                    }

                                    StyledButton {
                                        implicitWidth: 105
                                        implicitHeight: 36
                                        enabled: winObj ? winObj.stopwatchActive : false
                                        text: "󰑐   Сброс"
                                        onClicked: if (winObj) { winObj.resetStopwatch(); swArcCanvas.requestPaint() }
                                    }
                                }
                            }
                        }

                        // Правая карточка: Таблица записанных кругов (Laps)
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: Math.round(parent.width * 0.50)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "󰈻  Записанные круги"
                                        color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: winObj && winObj.stopwatchLaps.length > 0
                                        text: "Всего: " + (winObj ? winObj.stopwatchLaps.length : 0)
                                        color: "#888888"
                                        font.pixelSize: Config.fontSize - 1
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        visible: !winObj || winObj.stopwatchLaps.length === 0
                                        anchors.centerIn: parent
                                        text: "Нажмите «Круг» во время работы секундомера\nдля записи промежуточных отрезков"
                                        horizontalAlignment: Text.AlignHCenter
                                        color: "#777777"
                                        font.pixelSize: Config.fontSize
                                    }

                                    ListView {
                                        id: lapsListView
                                        anchors.fill: parent
                                        clip: true
                                        spacing: 6
                                        visible: winObj && winObj.stopwatchLaps.length > 0
                                        model: winObj ? winObj.stopwatchLaps : []
                                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                        delegate: Rectangle {
                                            width: lapsListView.width
                                            height: 32
                                            radius: timeRoot.isM3 ? (Config ? Math.min(10, Config.m3ControlRadius) : 8) : 0
                                            color: index === 0
                                                   ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.10))
                                                   : (timeRoot.isM3 && Config
                                                      ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.42)
                                                      : Qt.rgba(1, 1, 1, 0.04))
                                            border.width: 1
                                            border.color: index === 0
                                                          ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.50) : Qt.rgba(1, 1, 1, 0.25))
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
                                                    Layout.preferredWidth: 80
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
                                                    Layout.preferredWidth: 88
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
        }
    }
}
