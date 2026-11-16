import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: sysMonRoot
    property int pendingKillPid: -1
    property string pendingKillName: ""
    property real graphPhase: 1.0
    property double lastTickMs: Date.now()
    readonly property bool isM3: Theme && Theme.isRounded

    ListModel {
        id: procListModel
    }

    function syncProcessModel() {
        if (!Waybar || !Waybar.processList) return
        var src = Waybar.processList
        var savedY = procListView.contentY
        var n = src.length
        for (var i = 0; i < n; ++i) {
            var it = src[i]
            var rowObj = {
                pid: Number(it.pid || 0),
                name: String(it.name || ""),
                cmd: String(it.cmd || ""),
                cpu: String(it.cpu || "0.0%"),
                mem: String(it.mem || "0 MB")
            }
            if (i < procListModel.count) {
                procListModel.set(i, rowObj)
            } else {
                procListModel.append(rowObj)
            }
        }
        if (procListModel.count > n) {
            procListModel.remove(n, procListModel.count - n)
        }
        var maxY = Math.max(0, procListView.contentHeight - procListView.height)
        procListView.contentY = Math.min(savedY, maxY > 0 ? maxY : savedY)
    }

    Timer {
        id: slideAnimTimer
        interval: 45
        repeat: true
        running: sysMonRoot.visible && sysMonRoot.graphPhase < 1.0 && (ApplicationWindow.window ? ApplicationWindow.window.drawerActive : true)
        onTriggered: {
            var elapsed = Date.now() - sysMonRoot.lastTickMs
            sysMonRoot.graphPhase = Math.min(1.0, Math.max(0.0, elapsed / 420.0))
            cpuGraph.requestPaint()
            netGraph.requestPaint()
        }
    }

    function repaintAllGraphs() {
        cpuGraph.requestPaint()
        memGraph.requestPaint()
        vramGraph.requestPaint()
        netGraph.requestPaint()
    }

    function drawSmoothGraph(ctx, w, h, hist, phase, strokeCol, fillTopCol, fillBotCol) {
        ctx.clearRect(0, 0, w, h)
        if (!hist || hist.length < 4) return
        var n = hist.length
        var visibleSegments = n - 2
        var step = w / Math.max(1, visibleSegments)
        var topPad = 24
        var usableH = Math.max(10, h - topPad - 2)

        var pts = []
        for (var i = 0; i < n; ++i) {
            var px = (i - phase) * step
            var py = h - 2 - (Math.max(0, Math.min(100, hist[i])) / 100.0) * usableH
            pts.push({ x: px, y: py })
        }

        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        for (var j = 0; j < pts.length - 1; ++j) {
            var p1 = pts[j]
            var p2 = pts[j + 1]
            var midX = (p1.x + p2.x) * 0.5
            var midY = (p1.y + p2.y) * 0.5
            ctx.quadraticCurveTo(p1.x, p1.y, midX, midY)
        }
        var lastPt = pts[pts.length - 1]
        ctx.lineTo(lastPt.x, lastPt.y)

        ctx.strokeStyle = strokeCol
        ctx.lineWidth = 2.0
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        ctx.lineTo(lastPt.x, h)
        ctx.lineTo(pts[0].x, h)
        ctx.closePath()
        var grad = ctx.createLinearGradient(0, topPad, 0, h)
        grad.addColorStop(0.0, fillTopCol)
        grad.addColorStop(1.0, fillBotCol)
        ctx.fillStyle = grad
        ctx.fill()
    }

    function askKillProcess(pid, name) {
        pendingKillPid = pid
        pendingKillName = name
        if (ApplicationWindow.window) ApplicationWindow.window.modalOpen = true
    }

    function closeKillModal() {
        pendingKillPid = -1
        pendingKillName = ""
        if (ApplicationWindow.window) ApplicationWindow.window.modalOpen = false
    }

    Component.onCompleted: {
        syncProcessModel()
    }

    onVisibleChanged: {
        if (!visible && pendingKillPid !== -1) closeKillModal()
        if (visible) {
            sysMonRoot.lastTickMs = Date.now()
            sysMonRoot.graphPhase = 1.0
            syncProcessModel()
            repaintAllGraphs()
        }
    }

    Timer {
        interval: 2500
        running: sysMonRoot.visible && sysMonRoot.pendingKillPid === -1
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Waybar) Waybar.refreshProcesses()
    }

    Connections {
        target: Waybar
        function onSysStatsChanged() {
            if (!sysMonRoot.visible) return
            sysMonRoot.lastTickMs = Date.now()
            sysMonRoot.graphPhase = 0.0
            memGraph.requestPaint()
            vramGraph.requestPaint()
            cpuGraph.requestPaint()
            netGraph.requestPaint()
        }
        function onProcessesChanged() {
            if (!sysMonRoot.visible && procListModel.count > 0) return
            sysMonRoot.syncProcessModel()
        }
    }

    ColumnLayout {
        width: Math.min(parent.width - 48, 960)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 8

        // Заголовок
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Config ? Config.m3Primary : "#ffffff"
                    font.pixelSize: Config.fontSize + 4
                }
            }

            Text {
                text: "Системный монитор ресурсов и процессов"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.fillWidth: true
            }

            StyledButton {
                text: "btop"
                implicitHeight: 24
                onClicked: if (Waybar) Waybar.runCommand("kitty --class waybar-btop -e btop")
            }
        }

        // Сетка 2x2: [1] CPU + Ядра пополам в одной карточке, [2] Скорость сети, [3] ОЗУ, [4] Видеопамять
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            // 1. Карточка CPU (левая половина — график CPU, правая половина — сжатые ядра C0..C7 с температурой)
            GlassPanel {
                id: coresCard
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                Layout.preferredWidth: 460
                implicitHeight: 88
                clip: true

                readonly property int totalCores: (Waybar && Waybar.cpuCores) ? Waybar.cpuCores.length : 8
                readonly property int rowsCount: Math.max(1, Math.ceil(totalCores / 2))

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Левая половина карточки: график CPU
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 100

                        Canvas {
                            id: cpuGraph
                            anchors.fill: parent
                            anchors.margins: 6
                            onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.cpuHistory : [], sysMonRoot.graphPhase, "#a8c7fa", "rgba(168, 199, 250, 0.28)", "rgba(168, 199, 250, 0.02)")
                        }

                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                            spacing: 5
                            Item {
                                Layout.preferredWidth: 15; Layout.preferredHeight: 15
                                Text { anchors.centerIn: parent; text: ""; color: "#cccccc"; font.pixelSize: 11 }
                            }
                            Text { text: "CPU"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                            Text { text: (Waybar ? Waybar.cpuUsage : 0) + "% |"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                            Item {
                                Layout.preferredWidth: 10; Layout.preferredHeight: 15
                                Text { anchors.centerIn: parent; text: ""; color: "#cccccc"; font.pixelSize: 10 }
                            }
                            Text { text: (Waybar ? Waybar.cpuTemp : 40) + "°C"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                        }
                    }

                    // Разделитель между графиком CPU и ядрами
                    Rectangle {
                        visible: Waybar && Waybar.cpuCores && Waybar.cpuCores.length > 0
                        width: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    // Правая половина карточки: ядра C0..C3 | C4..C7
                    RowLayout {
                        visible: Waybar && Waybar.cpuCores && Waybar.cpuCores.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 115
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2

                            Repeater {
                                model: coresCard.rowsCount
                                delegate: RowLayout {
                                    id: leftCoreRow
                                    Layout.fillWidth: true
                                    spacing: 3
                                    readonly property int coreIdx: index
                                    readonly property var cObj: (Waybar && coreIdx < Waybar.cpuCores.length) ? Waybar.cpuCores[coreIdx] : ({ usage: 0, temp: 40 })
                                    readonly property int cPct: cObj.usage !== undefined ? Number(cObj.usage) : Number(cObj || 0)
                                    readonly property int cTmp: cObj.temp !== undefined ? Number(cObj.temp) : (Waybar ? Waybar.cpuTemp : 40)

                                    Text {
                                        text: "C" + leftCoreRow.coreIdx
                                        color: "#bbbbbb"; font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 14
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: sysMonRoot.isM3 ? 2 : 0
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                        clip: true

                                        Rectangle {
                                            width: parent.width * Math.max(0.04, Math.min(1.0, leftCoreRow.cPct / 100.0))
                                            height: parent.height
                                            radius: parent.radius
                                            color: leftCoreRow.cPct > 85 ? "#ff6b6b" : (leftCoreRow.cPct > 55 ? "#ffd54f" : (Config ? Config.m3Primary : "#69f0ae"))
                                            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Text {
                                        text: leftCoreRow.cPct + "%"
                                        color: Config ? Config.m3Primary : "#69f0ae"
                                        font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 21
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Text {
                                        text: leftCoreRow.cTmp + "°"
                                        color: leftCoreRow.cTmp >= 80 ? "#ff6b6b" : (leftCoreRow.cTmp >= 65 ? "#ffd54f" : "#80d8ff")
                                        font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 18
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            Layout.fillHeight: true
                            Layout.topMargin: 2; Layout.bottomMargin: 2
                            color: Qt.rgba(1, 1, 1, 0.12)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 2

                            Repeater {
                                model: Math.max(0, coresCard.totalCores - coresCard.rowsCount)
                                delegate: RowLayout {
                                    id: rightCoreRow
                                    Layout.fillWidth: true
                                    spacing: 3
                                    readonly property int coreIdx: index + coresCard.rowsCount
                                    readonly property var cObj: (Waybar && coreIdx < Waybar.cpuCores.length) ? Waybar.cpuCores[coreIdx] : ({ usage: 0, temp: 40 })
                                    readonly property int cPct: cObj.usage !== undefined ? Number(cObj.usage) : Number(cObj || 0)
                                    readonly property int cTmp: cObj.temp !== undefined ? Number(cObj.temp) : (Waybar ? Waybar.cpuTemp : 40)

                                    Text {
                                        text: "C" + rightCoreRow.coreIdx
                                        color: "#bbbbbb"; font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 14
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: sysMonRoot.isM3 ? 2 : 0
                                        color: Qt.rgba(1, 1, 1, 0.10)
                                        clip: true

                                        Rectangle {
                                            width: parent.width * Math.max(0.04, Math.min(1.0, rightCoreRow.cPct / 100.0))
                                            height: parent.height
                                            radius: parent.radius
                                            color: rightCoreRow.cPct > 85 ? "#ff6b6b" : (rightCoreRow.cPct > 55 ? "#ffd54f" : (Config ? Config.m3Primary : "#69f0ae"))
                                            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Text {
                                        text: rightCoreRow.cPct + "%"
                                        color: Config ? Config.m3Primary : "#69f0ae"
                                        font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 21
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Text {
                                        text: rightCoreRow.cTmp + "°"
                                        color: rightCoreRow.cTmp >= 80 ? "#ff6b6b" : (rightCoreRow.cTmp >= 65 ? "#ffd54f" : "#80d8ff")
                                        font.pixelSize: 9; font.bold: true
                                        font.features: { "tnum": 1 }
                                        Layout.preferredWidth: 18
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. Справа от CPU: Скорость сети
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; Layout.preferredWidth: 460; implicitHeight: 88; clip: true
                Canvas {
                    id: netGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.netHistory : [], sysMonRoot.graphPhase, "#69f0ae", "rgba(105, 240, 174, 0.28)", "rgba(105, 240, 174, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    spacing: 6
                    Item {
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        Text { anchors.centerIn: parent; text: "󰈀"; color: "#cccccc"; font.pixelSize: 12 }
                    }
                    Text { text: "Скорость сети"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.netSpeedText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            // 3. Снизу слева: ОЗУ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; Layout.preferredWidth: 460; implicitHeight: 80; clip: true
                Canvas {
                    id: memGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.memHistory : [], 1.0, "#80d8ff", "rgba(128, 216, 255, 0.28)", "rgba(128, 216, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    spacing: 6
                    Item {
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        Text { anchors.centerIn: parent; text: "󰍛"; color: "#cccccc"; font.pixelSize: 12 }
                    }
                    Text { text: "ОЗУ"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.memDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            // 4. Снизу справа: Видеопамять
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; Layout.preferredWidth: 460; implicitHeight: 80; clip: true
                Canvas {
                    id: vramGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.vramHistory : [], 1.0, "#b388ff", "rgba(179, 136, 255, 0.28)", "rgba(179, 136, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    spacing: 6
                    Item {
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        Text { anchors.centerIn: parent; text: "󰢮"; color: "#cccccc"; font.pixelSize: 12 }
                    }
                    Text { text: "Видеопамять"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.vramDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }
        }

        // Таблица активных процессов (с сохранением позиции скролла при обновлениях)
        GlassPanel {
            objectName: "atmoObstacle"
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10; Layout.rightMargin: 8
                    spacing: 10

                    Text { text: "PID"; color: "#777777"; font.pixelSize: 10; font.bold: true; Layout.preferredWidth: 64 }
                    Text { text: "Активные процессы (" + procListModel.count + ")"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 155 }
                    Text { text: "Запущенная команда"; color: "#888888"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }

                    Item {
                        Layout.preferredWidth: 64; implicitHeight: 20
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: (Waybar && Waybar.processSortMode === 0) ? "CPU ↓" : "CPU"
                            color: (Waybar && Waybar.processSortMode === 0) ? (Config ? Config.m3Primary : "#ffffff") : (cpuColMa.containsMouse ? "#ffffff" : "#888888")
                            font.pixelSize: 11; font.bold: true
                        }
                        MouseArea {
                            id: cpuColMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: if (Waybar) Waybar.processSortMode = 0
                        }
                    }

                    Item {
                        Layout.preferredWidth: 72; implicitHeight: 20
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: (Waybar && Waybar.processSortMode === 1) ? "RAM ↓" : "RAM"
                            color: (Waybar && Waybar.processSortMode === 1) ? (Config ? Config.m3Primary : "#ffffff") : (ramColMa.containsMouse ? "#ffffff" : "#888888")
                            font.pixelSize: 11; font.bold: true
                        }
                        MouseArea {
                            id: ramColMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: if (Waybar) Waybar.processSortMode = 1
                        }
                    }

                    Item { Layout.preferredWidth: 22 }
                }

                ListView {
                    id: procListView
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    cacheBuffer: 160
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    model: procListModel
                    delegate: Rectangle {
                        width: procListView.width; height: 26
                        radius: sysMonRoot.isM3 ? 6 : 0
                        color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                            Text {
                                text: "PID " + model.pid
                                color: "#888888"; font.pixelSize: 10
                                font.features: { "tnum": 1 }
                                Layout.preferredWidth: 64
                            }
                            Text {
                                text: model.name
                                color: "#ffffff"; font.pixelSize: 11; font.bold: true
                                Layout.preferredWidth: 155
                                elide: Text.ElideRight
                            }
                            Text {
                                text: model.cmd
                                color: "#777777"; font.pixelSize: 10
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: model.cpu
                                color: (Waybar && Waybar.processSortMode === 0) ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 0)
                                font.features: { "tnum": 1 }
                                Layout.preferredWidth: 64
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: model.mem
                                color: (Waybar && Waybar.processSortMode === 1) ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 1)
                                font.features: { "tnum": 1 }
                                Layout.preferredWidth: 72
                                horizontalAlignment: Text.AlignRight
                            }
                            Rectangle {
                                Layout.preferredWidth: 22; Layout.preferredHeight: 20
                                radius: sysMonRoot.isM3 ? 5 : 0
                                color: killMa.containsMouse ? "#ff5252" : Qt.rgba(1, 1, 1, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: killMa.containsMouse ? "#ffffff" : "#cccccc"
                                    font.pixelSize: 10; font.bold: true
                                }
                                MouseArea {
                                    id: killMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: sysMonRoot.askKillProcess(model.pid, model.name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: sysMonRoot.pendingKillPid !== -1 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        MouseArea {
            anchors.fill: parent
            onClicked: sysMonRoot.closeKillModal()
        }

        GlassPanel {
            anchors.centerIn: parent
            width: 320
            implicitHeight: killCol.implicitHeight + 28
            scale: sysMonRoot.pendingKillPid !== -1 ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }
            radius: sysMonRoot.isM3 ? 10 : 0
            tintColor: Qt.rgba(0.04, 0.04, 0.05, Config ? Config.dialogOpacity : 0.65)

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: killCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Завершить процесс?"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 2
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: "Вы действительно хотите принудительно завершить процесс «" + sysMonRoot.pendingKillName + "» (PID " + sysMonRoot.pendingKillPid + ")?"
                    color: "#cccccc"
                    font.pixelSize: Config.fontSize
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    StyledButton {
                        text: "✕ Завершить"
                        isActive: true
                        implicitHeight: 26
                        onClicked: {
                            var pid = sysMonRoot.pendingKillPid
                            sysMonRoot.closeKillModal()
                            if (Waybar && pid > 1) Waybar.killProcess(pid)
                        }
                    }

                    StyledButton {
                        text: "Отмена"
                        implicitHeight: 26
                        onClicked: sysMonRoot.closeKillModal()
                    }
                }
            }
        }
    }
}
