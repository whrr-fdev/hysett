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
        paintActiveCanvas()
    }

    property int curHours: 0
    property int curMinutes: 0
    property int curSeconds: 0
    property string curTimeText: "00:00:00"
    property string curDateText: ""
    property int todayDay: 1
    property int todayMonth: 0
    property int todayYear: 2026

    property bool clock24h: true
    property bool clockShowSec: true
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    property int selectedCalDay: new Date().getDate()

    property int drumHours: 0
    property int drumMins: 5
    property int drumSecs: 0
    property bool kbEditActive: false

    function updateClockState() {
        var d = new Date()
        curHours = d.getHours()
        curMinutes = d.getMinutes()
        curSeconds = d.getSeconds()
        todayDay = d.getDate()
        todayMonth = d.getMonth()
        todayYear = d.getFullYear()
        var fmt = clock24h
                  ? (clockShowSec ? "HH:mm:ss" : "HH:mm")
                  : (clockShowSec ? "hh:mm:ss AP" : "hh:mm AP")
        curTimeText = Qt.formatDateTime(d, fmt)
        curDateText = Qt.formatDateTime(d, "dddd, d MMMM yyyy")
        if (timeRoot.visible && timeRoot.subTab === 0 && clockDialCanvas.available) {
            clockDialCanvas.requestPaint()
        }
    }

    function syncDrumsFromMs(ms) {
        var totSec = Math.max(0, Math.round(ms / 1000))
        drumHours = Math.min(23, Math.floor(totSec / 3600))
        drumMins = Math.floor((totSec % 3600) / 60)
        drumSecs = totSec % 60
        kbHoursInput.text = String(drumHours).padStart(2, '0')
        kbMinsInput.text = String(drumMins).padStart(2, '0')
        kbSecsInput.text = String(drumSecs).padStart(2, '0')
    }

    function commitDrumsToTimer() {
        if (!winObj) return
        var ms = (drumHours * 3600 + drumMins * 60 + drumSecs) * 1000
        if (ms < 1000) {
            drumSecs = 5
            ms = 5000
        }
        winObj.setTimerPreset(ms)
        kbHoursInput.text = String(drumHours).padStart(2, '0')
        kbMinsInput.text = String(drumMins).padStart(2, '0')
        kbSecsInput.text = String(drumSecs).padStart(2, '0')
    }

    function applyKeyboardInputToTimer() {
        if (!winObj) return
        var h = Math.max(0, Math.min(23, parseInt(kbHoursInput.text) || 0))
        var m = Math.max(0, Math.min(59, parseInt(kbMinsInput.text) || 0))
        var s = Math.max(0, Math.min(59, parseInt(kbSecsInput.text) || 0))
        var ms = Math.max(1000, (h * 3600 + m * 60 + s) * 1000)
        winObj.setTimerPreset(ms)
        syncDrumsFromMs(ms)
        kbEditActive = false
    }

    function paintActiveCanvas() {
        if (!timeRoot.visible) return
        if (subTab === 0 && clockDialCanvas.available) clockDialCanvas.requestPaint()
        else if (subTab === 2 && timerArcCanvas.available) timerArcCanvas.requestPaint()
        else if (subTab === 3 && swArcCanvas.available) swArcCanvas.requestPaint()
    }

    Connections {
        target: winObj
        function onTimeSubTabChanged() {
            if (winObj && timeRoot.subTab !== winObj.timeSubTab)
                timeRoot.subTab = winObj.timeSubTab
        }
        function onTimerRemainingMsChanged() {
            if (timeRoot.visible && timeRoot.subTab === 2 && timerArcCanvas.available)
                timerArcCanvas.requestPaint()
        }
        function onTimerTotalMsChanged() {
            if (!winObj || !winObj.timerActive)
                timeRoot.syncDrumsFromMs(winObj ? winObj.timerTotalMs : 300000)
            if (timeRoot.visible && timeRoot.subTab === 2 && timerArcCanvas.available)
                timerArcCanvas.requestPaint()
        }
        function onTimerRunningChanged() {
            if (timeRoot.visible && timeRoot.subTab === 2 && timerArcCanvas.available)
                timerArcCanvas.requestPaint()
        }
        function onTimerActiveChanged() {
            if (winObj && !winObj.timerActive)
                timeRoot.syncDrumsFromMs(winObj.timerTotalMs)
            if (timeRoot.visible && timeRoot.subTab === 2 && timerArcCanvas.available)
                timerArcCanvas.requestPaint()
        }
        function onStopwatchElapsedMsChanged() {
            if (timeRoot.visible && timeRoot.subTab === 3 && swArcCanvas.available)
                swArcCanvas.requestPaint()
        }
        function onStopwatchRunningChanged() {
            if (timeRoot.visible && timeRoot.subTab === 3 && swArcCanvas.available)
                swArcCanvas.requestPaint()
        }
        function onStopwatchLapsChanged() {
            if (timeRoot.visible && timeRoot.subTab === 3 && swArcCanvas.available)
                swArcCanvas.requestPaint()
        }
    }

    Connections {
        target: Config
        function onM3PrimaryChanged() { timeRoot.paintActiveCanvas() }
        function onM3SecondaryContainerChanged() { timeRoot.paintActiveCanvas() }
        function onAccentColorChanged() { timeRoot.paintActiveCanvas() }
    }

    Connections {
        target: Theme
        function onIsRoundedChanged() { timeRoot.paintActiveCanvas() }
    }

    Timer {
        interval: 1000
        running: timeRoot.visible && timeRoot.subTab === 0
        repeat: true
        onTriggered: timeRoot.updateClockState()
    }

    Component.onCompleted: {
        if (visible) Qt.callLater(() => subSidebar.playStaircase())
        updateClockState()
        syncDrumsFromMs(winObj ? winObj.timerTotalMs : 300000)
    }

    onVisibleChanged: if (visible) {
        subSidebar.playStaircase()
        updateClockState()
        if (!winObj || !winObj.timerActive) syncDrumsFromMs(winObj ? winObj.timerTotalMs : 300000)
        paintActiveCanvas()
    }

    // Компонент строки заголовка с отдельным слотом под иконку (чтобы глиф никогда не наезжал на текст)
    component IconHeader: RowLayout {
        property string iconGlyph: "󱑂"
        property string titleText: ""
        property int extraFont: 3
        property color iconColor: Config ? Config.m3Primary : "#ffffff"
        property color textColor: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
        spacing: 10

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            Text {
                anchors.centerIn: parent
                text: parent.parent.iconGlyph
                color: parent.parent.iconColor
                font.pixelSize: Config.fontSize + parent.parent.extraFont + 1
            }
        }

        Text {
            text: parent.titleText
            color: parent.textColor
            font.pixelSize: Config.fontSize + parent.extraFont
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Телефонный барабан (колесико мыши + перетаскивание вверх/вниз + клик)
    component PhoneDrumWheel: Item {
        id: drumCol
        property int value: 0
        property int maxVal: 60
        property string suffix: "м"
        signal valueEdited(int newVal)

        property real slideOffset: 0
        NumberAnimation on slideOffset {
            id: rollAnim
            to: 0
            duration: 120
            easing.type: Easing.OutCubic
        }

        function stepBy(delta) {
            if (timeRoot.winObj && timeRoot.winObj.timerRunning) {
                timeRoot.winObj.toggleTimerPause()
            }
            slideOffset = delta > 0 ? 12 : -12
            rollAnim.restart()
            value = (value + delta + maxVal * 10) % maxVal
            valueEdited(value)
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: drumCol.slideOffset
            spacing: 8

            Text {
                width: drumCol.width
                horizontalAlignment: Text.AlignHCenter
                text: String((drumCol.value + drumCol.maxVal - 1) % drumCol.maxVal).padStart(2, '0') + " " + drumCol.suffix
                color: "#777777"
                font.pixelSize: 14
                font.features: { "tnum": 1 }
                opacity: 0.45
            }

            Text {
                width: drumCol.width
                horizontalAlignment: Text.AlignHCenter
                text: String(drumCol.value).padStart(2, '0') + " " + drumCol.suffix
                color: Config ? Config.m3Primary : "#ffffff"
                font.pixelSize: 20
                font.bold: true
                font.features: { "tnum": 1 }
            }

            Text {
                width: drumCol.width
                horizontalAlignment: Text.AlignHCenter
                text: String((drumCol.value + 1) % drumCol.maxVal).padStart(2, '0') + " " + drumCol.suffix
                color: "#777777"
                font.pixelSize: 14
                font.features: { "tnum": 1 }
                opacity: 0.45
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeVerCursor
            property real accumY: 0
            property bool dragged: false

            onWheel: (wheel) => {
                var dy = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (dy < 0) drumCol.stepBy(1)
                else if (dy > 0) drumCol.stepBy(-1)
                wheel.accepted = true
            }

            onPressed: (mouse) => {
                accumY = mouse.y
                dragged = false
            }
            onPositionChanged: (mouse) => {
                var dy = mouse.y - accumY
                if (Math.abs(dy) >= 18) {
                    var steps = Math.trunc(dy / 18)
                    drumCol.stepBy(-steps)
                    accumY += steps * 18
                    dragged = true
                }
            }
            onClicked: (mouse) => {
                if (dragged) return
                if (mouse.y < height * 0.35) drumCol.stepBy(-1)
                else if (mouse.y > height * 0.65) drumCol.stepBy(1)
                else {
                    timeRoot.kbEditActive = true
                    kbMinsInput.forceActiveFocus()
                    kbMinsInput.selectAll()
                }
            }
        }
    }

    // =========================================================================
    // ЛЕВАЯ БОКОВАЯ ПАНЕЛЬ РАЗДЕЛОВ ВРЕМЕНИ
    // =========================================================================
    Rectangle {
        id: subSidebar
        signal playStaircase()

        component SubCascadeAttach: Item {
            id: att
            property int stepIdx: 0
            property real dY: 0.0
            property real dX: 0.0
            property real sc: 1.0

            Connections {
                target: subSidebar
                function onPlayStaircase() {
                    attAnim.restart()
                }
            }

            Component.onCompleted: {
                if (att.parent) {
                    att.parent.transform = [attTrans, attScale]
                }
            }

            Translate { id: attTrans; x: att.dX; y: att.dY }
            Scale {
                id: attScale
                origin.x: att.parent ? att.parent.width * 0.35 : 40
                origin.y: att.parent ? att.parent.height * 0.5 : 15
                xScale: att.sc
                yScale: att.sc
            }

            SequentialAnimation {
                id: attAnim
                PropertyAction { target: att.parent; property: "opacity"; value: 0.0 }
                PropertyAction { target: att; property: "dY"; value: -20.0 }
                PropertyAction { target: att; property: "dX"; value: -22.0 }
                PropertyAction { target: att; property: "sc"; value: 0.72 }
                PauseAnimation { duration: 25 + att.stepIdx * 38 }
                ParallelAnimation {
                    NumberAnimation { target: att.parent; property: "opacity"; from: 0.0; to: 1.0; duration: 210; easing.type: Easing.OutCubic }
                    NumberAnimation { target: att; property: "dY"; from: -20.0; to: 0.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
                    NumberAnimation { target: att; property: "dX"; from: -22.0; to: 0.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.45 }
                    NumberAnimation { target: att; property: "sc"; from: 0.72; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
                }
                onStopped: {
                    if (att.parent) att.parent.opacity = 1.0
                    att.dY = 0.0
                    att.dX = 0.0
                    att.sc = 1.0
                }
            }
        }
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: timeRoot.isM3 ? 178 : 158
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
            SubCascadeAttach { stepIdx: timeRoot.subTab + 1 }
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

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 6
                Layout.leftMargin: 6
                spacing: 8
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Text {
                        anchors.centerIn: parent
                        text: "󱑂"
                        color: Config ? Config.m3Primary : "#ffffff"
                        font.pixelSize: Config.fontSize + 2
                    }
                }
                SubCascadeAttach { stepIdx: 0 }
                Text {
                    text: "Время и Даты"
                    color: timeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
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
                id: tCard0; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 1 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: timeRoot.subTab = 0
                    onEntered: { subSidebar.lastHoveredCardObj = tCard0; subSidebar.hoveredCardObj = tCard0 }
                    onExited: if (subSidebar.hoveredCardObj === tCard0) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: "󱑂"
                            color: timeRoot.subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard0 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize + 1
                        }
                    }
                    Text {
                        text: "Часы"
                        color: timeRoot.subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard0 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: timeRoot.subTab === 0; Layout.fillWidth: true
                    }
                }
            }

            Item {
                id: tCard1; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 2 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: timeRoot.subTab = 1
                    onEntered: { subSidebar.lastHoveredCardObj = tCard1; subSidebar.hoveredCardObj = tCard1 }
                    onExited: if (subSidebar.hoveredCardObj === tCard1) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: ""
                            color: timeRoot.subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard1 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize
                        }
                    }
                    Text {
                        text: "Календарь"
                        color: timeRoot.subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard1 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: timeRoot.subTab === 1; Layout.fillWidth: true
                    }
                }
            }

            Item {
                id: tCard2; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 3 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: timeRoot.subTab = 2
                    onEntered: { subSidebar.lastHoveredCardObj = tCard2; subSidebar.hoveredCardObj = tCard2 }
                    onExited: if (subSidebar.hoveredCardObj === tCard2) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: "󰔛"
                            color: timeRoot.subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard2 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize + 1
                        }
                    }
                    Text {
                        text: "Таймер"
                        color: timeRoot.subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard2 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: timeRoot.subTab === 2; Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: winObj && winObj.timerActive
                        width: 7; height: 7; radius: 3.5
                        color: timeRoot.subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : ((winObj && winObj.timerRunning) ? "#69f0ae" : "#ffd54f")
                    }
                }
            }

            Item {
                id: tCard3; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 4 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: timeRoot.subTab = 3
                    onEntered: { subSidebar.lastHoveredCardObj = tCard3; subSidebar.hoveredCardObj = tCard3 }
                    onExited: if (subSidebar.hoveredCardObj === tCard3) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: "󱎫"
                            color: timeRoot.subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard3 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize + 1
                        }
                    }
                    Text {
                        text: "Секундомер"
                        color: timeRoot.subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === tCard3 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: timeRoot.subTab === 3; Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: winObj && winObj.stopwatchActive
                        width: 7; height: 7; radius: 3.5
                        color: timeRoot.subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : ((winObj && winObj.stopwatchRunning) ? "#69f0ae" : "#ffd54f")
                    }
                }
            }

            Item { Layout.fillHeight: true }

            GlassPanel {
                visible: winObj && (winObj.timerActive || winObj.stopwatchActive)
                Layout.fillWidth: true
                implicitHeight: miniStatusCol.implicitHeight + 16
                ColumnLayout {
                    id: miniStatusCol
                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                    RowLayout {
                        spacing: 6
                        Item {
                            Layout.preferredWidth: 14; Layout.preferredHeight: 14
                            Text { anchors.centerIn: parent; text: "󰄬"; color: Config ? Config.m3Primary : "#69f0ae"; font.pixelSize: Config.fontSize - 1 }
                        }
                        Text {
                            text: "На панели задач"
                            color: Config ? Config.m3Primary : "#69f0ae"
                            font.pixelSize: Config.fontSize - 2; font.bold: true
                        }
                    }
                    RowLayout {
                        visible: winObj && winObj.timerActive
                        spacing: 6
                        Item {
                            Layout.preferredWidth: 14; Layout.preferredHeight: 14
                            Text { anchors.centerIn: parent; text: "󰔛"; color: "#ffffff"; font.pixelSize: Config.fontSize - 1 }
                        }
                        Text {
                            text: winObj ? winObj.timerBarText : "00:00"
                            color: "#ffffff"; font.pixelSize: Config.fontSize - 1; font.bold: true
                            font.features: { "tnum": 1 }
                        }
                    }
                    RowLayout {
                        visible: winObj && winObj.stopwatchActive
                        spacing: 6
                        Item {
                            Layout.preferredWidth: 14; Layout.preferredHeight: 14
                            Text { anchors.centerIn: parent; text: "󱎫"; color: "#ffffff"; font.pixelSize: Config.fontSize - 1 }
                        }
                        Text {
                            text: winObj ? winObj.stopwatchBarText : "00:00.0"
                            color: "#ffffff"; font.pixelSize: Config.fontSize - 1; font.bold: true
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // ПРАВАЯ ОБЛАСТЬ СОДЕРЖИМОГО
    // =========================================================================
    Item {
        id: contentArea
        anchors.left: subSidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // ---------------------------------------------------------------------
        // ЭКРАН 0: ЧАСЫ
        // ---------------------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: timeRoot.subTab === 0

            ColumnLayout {
                width: Math.min(parent.width - 48, 880)
                height: Math.min(parent.height - 40, 560)
                anchors.centerIn: parent
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: "󱑂"
                        titleText: "Системные часы и мировое время"
                    }
                    SegmentedButton {
                        Layout.preferredWidth: 170
                        options: ["24 часа", "12 часов"]
                        selectedIndex: timeRoot.clock24h ? 0 : 1
                        onSelected: (idx) => { timeRoot.clock24h = (idx === 0); timeRoot.updateClockState() }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 54

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
                                    width: 220
                                    height: 220
                                    onAvailableChanged: if (available && timeRoot.subTab === 0) requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width * 0.5
                                        var cy = height * 0.5
                                        var rOuter = 94
                                        var rInner = 80

                                        var secProg = timeRoot.curSeconds / 60.0
                                        var minProg = (timeRoot.curMinutes + secProg) / 60.0

                                        var primHex = Config ? Config.m3Primary.toString() : "#a8c7fa"
                                        var secCol = Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1)

                                        ctx.beginPath()
                                        for (var i = 0; i < 12; ++i) {
                                            var ang = (i / 12.0) * Math.PI * 2 - Math.PI * 0.5
                                            ctx.moveTo(cx + Math.cos(ang) * (rOuter + 6), cy + Math.sin(ang) * (rOuter + 6))
                                            ctx.lineTo(cx + Math.cos(ang) * (rOuter + 11), cy + Math.sin(ang) * (rOuter + 11))
                                        }
                                        ctx.lineWidth = 2.0
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.25)"
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.arc(cx, cy, rOuter, 0, Math.PI * 2)
                                        ctx.lineWidth = 7
                                        ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.45)
                                        ctx.stroke()

                                        var startA = -Math.PI * 0.5
                                        var endSecA = startA + Math.PI * 2 * (secProg > 0.002 ? secProg : 0.008)
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, rOuter, startA, endSecA, false)
                                        ctx.lineWidth = 7
                                        ctx.lineCap = "round"
                                        ctx.strokeStyle = primHex
                                        ctx.stroke()

                                        var dotX = cx + Math.cos(endSecA) * rOuter
                                        var dotY = cy + Math.sin(endSecA) * rOuter
                                        ctx.beginPath()
                                        ctx.arc(dotX, dotY, 5.5, 0, Math.PI * 2)
                                        ctx.fillStyle = "#ffffff"
                                        ctx.fill()

                                        ctx.beginPath()
                                        ctx.arc(cx, cy, rInner, 0, Math.PI * 2)
                                        ctx.lineWidth = 4
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.arc(cx, cy, rInner, startA, startA + Math.PI * 2 * minProg, false)
                                        ctx.lineWidth = 4
                                        ctx.lineCap = "round"
                                        ctx.strokeStyle = primHex
                                        ctx.stroke()
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: timeRoot.curTimeText
                                        color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: 30
                                        font.bold: true
                                        font.features: { "tnum": 1 }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: timeRoot.curDateText
                                        color: timeRoot.isM3 && Config
                                               ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.78)
                                               : "#aaaaaa"
                                        font.pixelSize: Config.fontSize - 1
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Показывать секунды:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: timeRoot.clockShowSec
                                    onToggled: { timeRoot.clockShowSec = checked; timeRoot.updateClockState() }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 46

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            IconHeader {
                                Layout.fillWidth: true
                                iconGlyph: "󰇧"
                                titleText: "Мировое время и прогресс суток"
                                extraFont: 1
                                textColor: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                            }

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
                                    anchors.fill: parent; anchors.margins: 10; spacing: 6
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Прошло времени за сегодня"; color: "#cccccc"; font.pixelSize: Config.fontSize - 1; Layout.fillWidth: true }
                                        Text {
                                            readonly property real pct: ((timeRoot.curHours * 3600 + timeRoot.curMinutes * 60 + timeRoot.curSeconds) / 86400.0) * 100.0
                                            text: pct.toFixed(1) + "%"
                                            color: Config ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: Config.fontSize - 1; font.bold: true
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true; height: 6; radius: timeRoot.isM3 ? 3 : 0
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                        Rectangle {
                                            width: parent.width * Math.min(1.0, (timeRoot.curHours * 3600 + timeRoot.curMinutes * 60 + timeRoot.curSeconds) / 86400.0)
                                            height: parent.height; radius: parent.radius
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
                                    Layout.fillWidth: true; height: 36
                                    radius: timeRoot.isM3 ? (Config ? Math.min(10, Config.m3ControlRadius) : 8) : 0
                                    color: timeRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.55)
                                           : Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: timeRoot.isM3 && Config
                                                  ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18)
                                                  : Qt.rgba(1, 1, 1, 0.08)

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                        Text { text: modelData.city; color: "#dddddd"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                        Text { text: (modelData.offset >= 0 ? "UTC+" : "UTC") + modelData.offset; color: "#888888"; font.pixelSize: Config.fontSize - 2; Layout.rightMargin: 8 }
                                        Text {
                                            readonly property int utcH: (timeRoot.curHours + (new Date().getTimezoneOffset() / 60) + modelData.offset + 48) % 24
                                            text: String(Math.floor(utcH)).padStart(2, '0') + ":" + String(timeRoot.curMinutes).padStart(2, '0') + (timeRoot.clockShowSec ? (":" + String(timeRoot.curSeconds).padStart(2, '0')) : "")
                                            color: Config ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: Config.fontSize; font.bold: true
                                            font.features: { "tnum": 1 }
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

        // ---------------------------------------------------------------------
        // ЭКРАН 1: КАЛЕНДАРЬ (КОМПАКТНЫЙ И СГРУППИРОВАННЫЙ ПО ЦЕНТРУ)
        // ---------------------------------------------------------------------
        Item {
            id: calPage
            anchors.fill: parent
            visible: timeRoot.subTab === 1
            readonly property int firstWeekdayOffset: (new Date(timeRoot.calYear, timeRoot.calMonth, 1).getDay() + 6) % 7
            readonly property int daysInCurrentMonth: new Date(timeRoot.calYear, timeRoot.calMonth + 1, 0).getDate()

            ColumnLayout {
                width: Math.min(parent.width - 48, 520)
                anchors.centerIn: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: ""
                        titleText: "Календарь"
                    }
                    StyledButton {
                        text: "󰃭 Сегодня"
                        implicitHeight: 28
                        onClicked: {
                            timeRoot.calYear = timeRoot.todayYear
                            timeRoot.calMonth = timeRoot.todayMonth
                            timeRoot.selectedCalDay = timeRoot.todayDay
                        }
                    }
                }

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: calCardInnerCol.implicitHeight + 32

                    ColumnLayout {
                        id: calCardInnerCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            StyledButton { text: "«"; isIconOnly: true; implicitWidth: 30; implicitHeight: 26; onClicked: timeRoot.calYear-- }
                            StyledButton {
                                text: "‹"; isIconOnly: true; implicitWidth: 30; implicitHeight: 26
                                onClicked: {
                                    if (timeRoot.calMonth === 0) { timeRoot.calMonth = 11; timeRoot.calYear-- }
                                    else timeRoot.calMonth--
                                }
                            }
                            Text {
                                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                text: ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"][timeRoot.calMonth] + " " + timeRoot.calYear
                                color: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                font.pixelSize: Config.fontSize + 2; font.bold: true
                            }
                            StyledButton {
                                text: "›"; isIconOnly: true; implicitWidth: 30; implicitHeight: 26
                                onClicked: {
                                    if (timeRoot.calMonth === 11) { timeRoot.calMonth = 0; timeRoot.calYear++ }
                                    else timeRoot.calMonth++
                                }
                            }
                            StyledButton { text: "»"; isIconOnly: true; implicitWidth: 30; implicitHeight: 26; onClicked: timeRoot.calYear++ }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                                delegate: Text {
                                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: index >= 5 ? (Config ? Config.m3Primary : "#a8c7fa") : "#888888"
                                    font.pixelSize: Config.fontSize - 1; font.bold: true
                                }
                            }

                            Repeater {
                                model: 42
                                delegate: Rectangle {
                                    id: dayCell
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    readonly property int dNum: index - calPage.firstWeekdayOffset + 1
                                    readonly property bool isValid: dNum >= 1 && dNum <= calPage.daysInCurrentMonth
                                    readonly property bool isToday: isValid && dNum === timeRoot.todayDay && timeRoot.calMonth === timeRoot.todayMonth && timeRoot.calYear === timeRoot.todayYear
                                    readonly property bool isSel: isValid && dNum === timeRoot.selectedCalDay

                                    radius: timeRoot.isM3 ? (Config ? Math.min(10, Config.m3ControlRadius) : 8) : 0
                                    color: {
                                        if (!isValid) return "transparent"
                                        if (isToday) return Config ? Config.m3Primary : "#ffffff"
                                        if (isSel) return Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.16)
                                        if (dayMa.containsMouse) return Qt.rgba(1, 1, 1, 0.08)
                                        return timeRoot.isM3 && Config
                                               ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.38)
                                               : Qt.rgba(1, 1, 1, 0.03)
                                    }
                                    border.width: isValid ? 1 : 0
                                    border.color: {
                                        if (!isValid || isToday) return "transparent"
                                        if (isSel) return Config ? Config.m3Primary : "#ffffff"
                                        return timeRoot.isM3 && Config
                                               ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.22)
                                               : Qt.rgba(1, 1, 1, 0.08)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.isValid ? dayCell.dNum : ""
                                        color: {
                                            if (dayCell.isToday) return Config ? Config.accentTextColor : "#000000"
                                            if (dayCell.isSel) return Config ? Config.m3Primary : "#ffffff"
                                            return "#ffffff"
                                        }
                                        font.pixelSize: Config.fontSize
                                        font.bold: dayCell.isToday || dayCell.isSel
                                    }

                                    MouseArea {
                                        id: dayMa
                                        anchors.fill: parent
                                        enabled: dayCell.isValid
                                        hoverEnabled: true
                                        cursorShape: dayCell.isValid ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: timeRoot.selectedCalDay = dayCell.dNum
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // ЭКРАН 2: ТАЙМЕР
        // ---------------------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: timeRoot.subTab === 2

            ColumnLayout {
                width: Math.min(parent.width - 48, 880)
                height: Math.min(parent.height - 40, 560)
                anchors.centerIn: parent
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: "󰔛"
                        titleText: "Таймер обратного отсчёта"
                    }
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: (winObj && winObj.timerRunning)
                                   ? (Config ? Config.m3Primary : "#69f0ae")
                                   : ((winObj && winObj.timerActive) ? "#ffd54f" : "#666666")
                        }
                        Text {
                            text: (winObj && winObj.timerRunning)
                                  ? "Идёт отсчёт"
                                  : ((winObj && winObj.timerActive) ? "На паузе" : "Готов к запуску")
                            color: (winObj && winObj.timerRunning) ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                            font.pixelSize: Config.fontSize; font.bold: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Canvas {
                                    id: timerArcCanvas
                                    anchors.centerIn: parent
                                    width: 216
                                    height: 216
                                    onAvailableChanged: if (available && timeRoot.subTab === 2) requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width * 0.5
                                        var cy = height * 0.5
                                        var r = 92
                                        var total = (winObj && winObj.timerTotalMs > 0) ? winObj.timerTotalMs : 1
                                        var rem = winObj ? winObj.timerRemainingMs : 0
                                        var prog = Math.max(0.0, Math.min(1.0, rem / total))

                                        var primHex = Config ? Config.m3Primary.toString() : "#a8c7fa"
                                        var secCol = Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1)

                                        ctx.beginPath()
                                        for (var i = 0; i < 12; ++i) {
                                            var ang = (i / 12.0) * Math.PI * 2 - Math.PI * 0.5
                                            ctx.moveTo(cx + Math.cos(ang) * (r + 7), cy + Math.sin(ang) * (r + 7))
                                            ctx.lineTo(cx + Math.cos(ang) * (r + 12), cy + Math.sin(ang) * (r + 12))
                                        }
                                        ctx.lineWidth = 2.0
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.22)"
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                        ctx.lineWidth = 8
                                        ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.45)
                                        ctx.stroke()

                                        if (prog > 0.002) {
                                            var startA = -Math.PI * 0.5
                                            var endA = startA + Math.PI * 2 * prog
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, startA, endA, false)
                                            ctx.lineWidth = 8
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = primHex
                                            ctx.stroke()

                                            var tipX = cx + Math.cos(endA) * r
                                            var tipY = cy + Math.sin(endA) * r
                                            ctx.beginPath()
                                            ctx.arc(tipX, tipY, 6, 0, Math.PI * 2)
                                            ctx.fillStyle = "#ffffff"
                                            ctx.fill()
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Item {
                                        visible: !timeRoot.kbEditActive
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitWidth: timerBigDigits.implicitWidth + 16
                                        implicitHeight: timerBigDigits.implicitHeight + 6

                                        Text {
                                            id: timerBigDigits
                                            anchors.centerIn: parent
                                            text: winObj ? winObj.timerBarText : "05:00"
                                            color: (winObj && winObj.timerRunning && Config) ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: 32
                                            font.bold: true
                                            font.features: { "tnum": 1 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: {
                                                if (winObj && winObj.timerRunning) winObj.toggleTimerPause()
                                                timeRoot.syncDrumsFromMs(winObj ? winObj.timerRemainingMs : 300000)
                                                timeRoot.kbEditActive = true
                                                kbMinsInput.forceActiveFocus()
                                                kbMinsInput.selectAll()
                                            }
                                        }
                                    }

                                    Row {
                                        visible: timeRoot.kbEditActive
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        TextField {
                                            id: kbHoursInput
                                            width: 44; height: 36
                                            horizontalAlignment: Text.AlignHCenter
                                            color: "#ffffff"; font.pixelSize: 19; font.bold: true
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
                                        Text { text: ":"; color: "#ffffff"; font.pixelSize: 20; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                        TextField {
                                            id: kbMinsInput
                                            width: 44; height: 36
                                            horizontalAlignment: Text.AlignHCenter
                                            color: "#ffffff"; font.pixelSize: 19; font.bold: true
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
                                        Text { text: ":"; color: "#ffffff"; font.pixelSize: 20; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                        TextField {
                                            id: kbSecsInput
                                            width: 44; height: 36
                                            horizontalAlignment: Text.AlignHCenter
                                            color: "#ffffff"; font.pixelSize: 19; font.bold: true
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

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6
                                        Item {
                                            width: 15; height: 15
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                text: timeRoot.kbEditActive ? "󰄬" : "󰌌"
                                                color: timeRoot.kbEditActive ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                                                font.pixelSize: Config.fontSize - 1
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: timeRoot.kbEditActive ? "Enter — сохранить" : "Нажмите для ввода"
                                            color: timeRoot.kbEditActive ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                                            font.pixelSize: Config.fontSize - 2
                                        }
                                    }
                                }
                            }

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
                                        Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 28
                                        text: modelData.label
                                        onClicked: {
                                            if (winObj) {
                                                winObj.addTimerMs(modelData.delta)
                                                if (!winObj.timerActive) timeRoot.syncDrumsFromMs(winObj.timerTotalMs)
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 36
                                    isActive: winObj ? winObj.timerRunning : false
                                    text: timeRoot.kbEditActive
                                          ? "󰄬 Применить"
                                          : ((winObj && winObj.timerRunning)
                                             ? "󰏤 Пауза"
                                             : ((winObj && winObj.timerActive) ? "󰐊 Продолжить" : "󰐊 Запустить таймер"))
                                    onClicked: {
                                        if (timeRoot.kbEditActive) timeRoot.applyKeyboardInputToTimer()
                                        if (winObj) winObj.toggleTimerPause()
                                    }
                                }

                                StyledButton {
                                    implicitWidth: 112; implicitHeight: 36
                                    enabled: winObj ? (winObj.timerActive || winObj.timerRemainingMs !== winObj.timerTotalMs) : false
                                    text: "󰑐 Сброс"
                                    onClicked: {
                                        if (winObj) {
                                            winObj.resetTimer()
                                            timeRoot.syncDrumsFromMs(winObj.timerTotalMs)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                IconHeader {
                                    Layout.fillWidth: true
                                    iconGlyph: "󰓦"
                                    titleText: "Барабан времени"
                                    extraFont: 1
                                    textColor: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                }
                                StyledButton {
                                    text: timeRoot.kbEditActive ? "󰄬 Готово" : "󰌌 С клавиатуры"
                                    implicitHeight: 28
                                    isActive: timeRoot.kbEditActive
                                    onClicked: {
                                        if (timeRoot.kbEditActive) {
                                            timeRoot.applyKeyboardInputToTimer()
                                        } else {
                                            if (winObj && winObj.timerRunning) winObj.toggleTimerPause()
                                            timeRoot.syncDrumsFromMs(winObj ? winObj.timerRemainingMs : 300000)
                                            timeRoot.kbEditActive = true
                                            kbMinsInput.forceActiveFocus()
                                            kbMinsInput.selectAll()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: timeRoot.isM3 ? (Config ? Math.min(16, Config.m3CardRadius) : 14) : 0
                                color: timeRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.45)
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: timeRoot.isM3 && Config
                                              ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.25)
                                              : Qt.rgba(1, 1, 1, 0.10)
                                clip: true

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
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
                                    anchors.leftMargin: 14; anchors.rightMargin: 14
                                    spacing: 4

                                    PhoneDrumWheel {
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                        maxVal: 24; suffix: "ч"
                                        value: timeRoot.drumHours
                                        onValueEdited: (v) => { timeRoot.drumHours = v; timeRoot.commitDrumsToTimer() }
                                    }

                                    Text { text: ":"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 20; font.bold: true }

                                    PhoneDrumWheel {
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                        maxVal: 60; suffix: "м"
                                        value: timeRoot.drumMins
                                        onValueEdited: (v) => { timeRoot.drumMins = v; timeRoot.commitDrumsToTimer() }
                                    }

                                    Text { text: ":"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 20; font.bold: true }

                                    PhoneDrumWheel {
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                        maxVal: 60; suffix: "с"
                                        value: timeRoot.drumSecs
                                        onValueEdited: (v) => { timeRoot.drumSecs = v; timeRoot.commitDrumsToTimer() }
                                    }
                                }
                            }

                            Text {
                                text: "Быстрые пресеты:"
                                color: "#999999"
                                font.pixelSize: Config.fontSize - 1
                            }

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
                                        Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 28
                                        isActive: winObj && !winObj.timerActive && winObj.timerTotalMs === modelData.ms
                                        text: modelData.label
                                        onClicked: {
                                            if (winObj) {
                                                winObj.setTimerPreset(modelData.ms)
                                                timeRoot.syncDrumsFromMs(modelData.ms)
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

        // ---------------------------------------------------------------------
        // ЭКРАН 3: СЕКУНДОМЕР
        // ---------------------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: timeRoot.subTab === 3

            ColumnLayout {
                width: Math.min(parent.width - 48, 880)
                height: Math.min(parent.height - 40, 560)
                anchors.centerIn: parent
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: "󱎫"
                        titleText: "Секундомер и замер кругов"
                    }
                    RowLayout {
                        spacing: 6
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: (winObj && winObj.stopwatchRunning)
                                   ? (Config ? Config.m3Primary : "#69f0ae")
                                   : ((winObj && winObj.stopwatchActive) ? "#ffd54f" : "#666666")
                        }
                        Text {
                            text: (winObj && winObj.stopwatchRunning)
                                  ? "Идёт замер"
                                  : ((winObj && winObj.stopwatchActive) ? "На паузе" : "Готов")
                            color: (winObj && winObj.stopwatchRunning) ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                            font.pixelSize: Config.fontSize; font.bold: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Canvas {
                                    id: swArcCanvas
                                    anchors.centerIn: parent
                                    width: 216
                                    height: 216
                                    onAvailableChanged: if (available && timeRoot.subTab === 3) requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width * 0.5
                                        var cy = height * 0.5
                                        var rOuter = 92
                                        var rInner = 78

                                        var elapsed = winObj ? winObj.stopwatchElapsedMs : 0
                                        var lapElapsed = Math.max(0, elapsed - (winObj ? winObj.stopwatchLastLapMs : 0))
                                        var mainProg = (elapsed % 60000) / 60000.0
                                        var lapProg = (lapElapsed % 60000) / 60000.0

                                        var primHex = Config ? Config.m3Primary.toString() : "#a8c7fa"
                                        var secCol = Config ? Config.m3SecondaryContainer : Qt.rgba(0.3, 0.35, 0.45, 1)

                                        ctx.beginPath()
                                        for (var i = 0; i < 12; ++i) {
                                            var ang = (i / 12.0) * Math.PI * 2 - Math.PI * 0.5
                                            ctx.moveTo(cx + Math.cos(ang) * (rOuter + 7), cy + Math.sin(ang) * (rOuter + 7))
                                            ctx.lineTo(cx + Math.cos(ang) * (rOuter + 12), cy + Math.sin(ang) * (rOuter + 12))
                                        }
                                        ctx.lineWidth = 2.0
                                        ctx.strokeStyle = "rgba(255, 255, 255, 0.22)"
                                        ctx.stroke()

                                        ctx.beginPath()
                                        ctx.arc(cx, cy, rOuter, 0, Math.PI * 2)
                                        ctx.lineWidth = 8
                                        ctx.strokeStyle = Qt.rgba(secCol.r, secCol.g, secCol.b, 0.45)
                                        ctx.stroke()

                                        var startA = -Math.PI * 0.5
                                        if (elapsed > 0) {
                                            var endA = startA + Math.PI * 2 * (mainProg > 0.001 ? mainProg : 1.0)
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rOuter, startA, endA, false)
                                            ctx.lineWidth = 8
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = primHex
                                            ctx.stroke()

                                            var tipX = cx + Math.cos(endA) * rOuter
                                            var tipY = cy + Math.sin(endA) * rOuter
                                            ctx.beginPath()
                                            ctx.arc(tipX, tipY, 6, 0, Math.PI * 2)
                                            ctx.fillStyle = "#ffffff"
                                            ctx.fill()
                                        }

                                        if (winObj && winObj.stopwatchLaps.length > 0) {
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rInner, 0, Math.PI * 2)
                                            ctx.lineWidth = 4
                                            ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
                                            ctx.stroke()

                                            ctx.beginPath()
                                            ctx.arc(cx, cy, rInner, startA, startA + Math.PI * 2 * lapProg, false)
                                            ctx.lineWidth = 4
                                            ctx.lineCap = "round"
                                            ctx.strokeStyle = "#69f0ae"
                                            ctx.stroke()
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: winObj ? winObj.stopwatchFullText : "00:00.00"
                                        color: (winObj && winObj.stopwatchRunning && Config) ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: 30
                                        font.bold: true
                                        font.features: { "tnum": 1 }
                                    }

                                    Text {
                                        visible: winObj && winObj.stopwatchActive
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: {
                                            var curLap = winObj ? Math.max(0, winObj.stopwatchElapsedMs - winObj.stopwatchLastLapMs) : 0
                                            return "Круг: " + (winObj ? winObj.formatClockMs(curLap, false, true) : "00:00.00")
                                        }
                                        color: "#69f0ae"
                                        font.pixelSize: Config.fontSize - 1
                                        font.features: { "tnum": 1 }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 36
                                    isActive: winObj ? winObj.stopwatchRunning : false
                                    text: (winObj && winObj.stopwatchRunning)
                                          ? "󰏤 Пауза"
                                          : ((winObj && winObj.stopwatchActive) ? "󰐊 Далее" : "󰐊 Старт")
                                    onClicked: if (winObj) winObj.toggleStopwatch()
                                }

                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 36
                                    enabled: winObj ? winObj.stopwatchRunning : false
                                    text: "󰈻 Круг"
                                    onClicked: if (winObj) winObj.lapStopwatch()
                                }

                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true; implicitHeight: 36
                                    enabled: winObj ? winObj.stopwatchActive : false
                                    text: "󰑐 Сброс"
                                    onClicked: if (winObj) { winObj.resetStopwatch(); swArcCanvas.requestPaint() }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                IconHeader {
                                    Layout.fillWidth: true
                                    iconGlyph: "󰈻"
                                    titleText: "Записанные круги" + (winObj && winObj.stopwatchLaps.length > 0 ? (" (" + winObj.stopwatchLaps.length + ")") : "")
                                    extraFont: 1
                                    textColor: timeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                }
                                StyledButton {
                                    text: "󰎟 Сбросить флаги"
                                    implicitHeight: 28
                                    enabled: winObj ? (winObj.stopwatchLaps.length > 0) : false
                                    onClicked: if (winObj) { winObj.clearStopwatchLaps(); swArcCanvas.requestPaint() }
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
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
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
                                                font.bold: true
                                                font.features: { "tnum": 1 }
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            Text {
                                                text: modelData.totalTime
                                                color: "#ffffff"
                                                font.pixelSize: Config.fontSize
                                                font.features: { "tnum": 1 }
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
