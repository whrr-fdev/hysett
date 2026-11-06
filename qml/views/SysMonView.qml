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

    NumberAnimation {
        id: smoothPhaseAnim
        target: sysMonRoot
        property: "graphPhase"
        from: 0.0
        to: 1.0
        duration: 450
        easing.type: Easing.Linear
    }

    onGraphPhaseChanged: {
        if (!sysMonRoot.visible) return
        cpuGraph.requestPaint()
        memGraph.requestPaint()
        vramGraph.requestPaint()
        netGraph.requestPaint()
    }

    function drawSmoothGraph(ctx, w, h, hist, phase, strokeCol, fillTopCol, fillBotCol) {
        ctx.clearRect(0, 0, w, h)
        if (!hist || hist.length < 3) return
        var n = hist.length
        var visibleCount = n - 2
        var step = w / Math.max(1, visibleCount - 1)
        var topPad = 24
        var usableH = Math.max(10, h - topPad - 2)

        var pts = []
        for (var i = 0; i < n - 1; ++i) {
            var val = hist[i] + (hist[i + 1] - hist[i]) * phase
            var px = i * step
            var py = h - 2 - (Math.max(0, Math.min(100, val)) / 100.0) * usableH
            pts.push({ x: px, y: py })
        }
        if (pts.length < 2) return

        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        for (var j = 1; j < pts.length - 1; ++j) {
            var midX = (pts[j].x + pts[j + 1].x) * 0.5
            var midY = (pts[j].y + pts[j + 1].y) * 0.5
            ctx.quadraticCurveTo(pts[j].x, pts[j].y, midX, midY)
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

    onVisibleChanged: {
        if (!visible && pendingKillPid !== -1) closeKillModal()
        if (visible) {
            cpuGraph.requestPaint()
            memGraph.requestPaint()
            vramGraph.requestPaint()
            netGraph.requestPaint()
        }
    }

    Timer {
        interval: 2000
        running: sysMonRoot.visible && sysMonRoot.pendingKillPid === -1
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Waybar) Waybar.refreshProcesses()
    }

    Connections {
        target: Waybar
        function onSysStatsChanged() {
            if (!sysMonRoot.visible) return
            smoothPhaseAnim.restart()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "  Системный монитор ресурсов и процессов (Btop)"
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

        // СЕТКА 2x2: 4 ПЛАВНЫХ ЖИВЫХ ГРАФИКА (CPU, RAM, VRAM, СЕТЬ)
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            // 1. CPU + TEMP
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: cpuGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.cpuHistory : [], sysMonRoot.graphPhase, "#a8c7fa", "rgba(168, 199, 250, 0.28)", "rgba(168, 199, 250, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "  CPU"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: (Waybar ? Waybar.cpuUsage : 0) + "%  |   " + (Waybar ? Waybar.cpuTemp : 40) + "°C"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            // 2. ОЗУ (RAM)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: memGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.memHistory : [], sysMonRoot.graphPhase, "#80d8ff", "rgba(128, 216, 255, 0.28)", "rgba(128, 216, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "󰍛  ОЗУ (RAM)"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.memDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            // 3. ВИДЕОПАМЯТЬ (GPU VRAM)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: vramGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.vramHistory : [], sysMonRoot.graphPhase, "#b388ff", "rgba(179, 136, 255, 0.28)", "rgba(179, 136, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "󰢮  Видеопамять (VRAM)"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.vramDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            // 4. СКОРОСТЬ СЕТИ (NETWORK RX/TX)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: netGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.netHistory : [], sysMonRoot.graphPhase, "#69f0ae", "rgba(105, 240, 174, 0.28)", "rgba(105, 240, 174, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "󰈀  Скорость сети"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.netSpeedText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }
        }

        // СПИСОК ПРОЦЕССОВ С КЛИКАБЕЛЬНЫМИ КОЛОНКАМИ CPU И RAM
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
                    Text { text: "Активные процессы"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }

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
                            onClicked: if (Waybar) Waybar.processSortMode = 0
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
                            onClicked: if (Waybar) Waybar.processSortMode = 1
                        }
                    }

                    Item { Layout.preferredWidth: 22 }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    model: Waybar ? Waybar.processList : []
                    delegate: Rectangle {
                        width: ListView.view.width; height: 26
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                            Text { text: "PID " + modelData.pid; color: "#888888"; font.pixelSize: 10; Layout.preferredWidth: 64 }
                            Text { text: modelData.name; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                text: modelData.cpu
                                color: (Waybar && Waybar.processSortMode === 0) ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 0)
                                Layout.preferredWidth: 64
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: modelData.mem
                                color: (Waybar && Waybar.processSortMode === 1) ? "#ffffff" : "#aaaaaa"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 1)
                                Layout.preferredWidth: 72
                                horizontalAlignment: Text.AlignRight
                            }
                            StyledButton {
                                text: "✕"; isIconOnly: true; implicitHeight: 20; implicitWidth: 22
                                onClicked: sysMonRoot.askKillProcess(modelData.pid, modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }

    // МОДАЛЬНОЕ ОКНО ПОДТВЕРЖДЕНИЯ ЗАВЕРШЕНИЯ ПРОЦЕССА
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
            radius: (Theme && Theme.isRounded) ? 10 : 0
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
                        text: "✕  Завершить"
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
