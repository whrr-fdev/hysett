import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: sysMonRoot
    property int pendingKillPid: -1
    property string pendingKillName: ""
    property real graphPhase: 0.0
    property double lastTickMs: Date.now()

    // 30 FPS таймер плавного горизонтального сдвига (в 5 раз легче для CPU, чем 160 FPS NumberAnimation)
    Timer {
        interval: 33
        repeat: true
        running: sysMonRoot.visible && (ApplicationWindow.window ? ApplicationWindow.window.drawerActive : true)
        onTriggered: {
            var elapsed = Date.now() - sysMonRoot.lastTickMs
            sysMonRoot.graphPhase = Math.min(1.0, Math.max(0.0, elapsed / 450.0))
            cpuGraph.requestPaint()
            memGraph.requestPaint()
            vramGraph.requestPaint()
            netGraph.requestPaint()
        }
    }

    function drawSmoothGraph(ctx, w, h, hist, phase, strokeCol, fillTopCol, fillBotCol) {
        ctx.clearRect(0, 0, w, h)
        if (!hist || hist.length < 4) return
        var n = hist.length
        var visibleSegments = n - 2
        var step = w / Math.max(1, visibleSegments)
        var topPad = 24
        var usableH = Math.max(10, h - topPad - 2)

        // Точки сдвигаются строго ПО ГОРИЗОНТАЛИ: px = (i - phase) * step, а высота Y каждой точки неизменна!
        // Благодаря этому пики и впадины никогда не усредняются и не распрямляются.
        var pts = []
        for (var i = 0; i < n; ++i) {
            var px = (i - phase) * step
            var py = h - 2 - (Math.max(0, Math.min(100, hist[i])) / 100.0) * usableH
            pts.push({ x: px, y: py })
        }

        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        for (var j = 0; j < pts.length - 1; ++j) {
            var p0 = pts[Math.max(0, j - 1)]
            var p1 = pts[j]
            var p2 = pts[j + 1]
            var p3 = pts[Math.min(pts.length - 1, j + 2)]
            var cp1x = p1.x + (p2.x - p0.x) / 6.0
            var cp1y = Math.max(topPad - 2, Math.min(h - 1, p1.y + (p2.y - p0.y) / 6.0))
            var cp2x = p2.x - (p3.x - p1.x) / 6.0
            var cp2y = Math.max(topPad - 2, Math.min(h - 1, p2.y - (p3.y - p1.y) / 6.0))
            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
        }

        ctx.strokeStyle = strokeCol
        ctx.lineWidth = 2.0
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()

        var lastPt = pts[pts.length - 1]
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
            sysMonRoot.lastTickMs = Date.now()
            sysMonRoot.graphPhase = 0.0
            cpuGraph.requestPaint()
            memGraph.requestPaint()
            vramGraph.requestPaint()
            netGraph.requestPaint()
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
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "  Системный монитор ресурсов и процессов"
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

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

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

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: memGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.memHistory : [], sysMonRoot.graphPhase, "#80d8ff", "rgba(128, 216, 255, 0.28)", "rgba(128, 216, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "󰍛  ОЗУ"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.memDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true; implicitHeight: 86; clip: true
                Canvas {
                    id: vramGraph; anchors.fill: parent; anchors.margins: 6
                    onPaint: sysMonRoot.drawSmoothGraph(getContext("2d"), width, height, Waybar ? Waybar.vramHistory : [], sysMonRoot.graphPhase, "#b388ff", "rgba(179, 136, 255, 0.28)", "rgba(179, 136, 255, 0.02)")
                }
                RowLayout {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                    Text { text: "󰢮  Видеопамять"; color: "#cccccc"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                    Text { text: Waybar ? Waybar.vramDetailText : ""; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                }
            }

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
