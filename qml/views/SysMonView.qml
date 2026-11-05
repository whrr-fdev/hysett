import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: sysMonRoot
    property int pendingKillPid: -1
    property string pendingKillName: ""

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
            cpuGraph.requestPaint()
            memGraph.requestPaint()
            vramGraph.requestPaint()
            netGraph.requestPaint()
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
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                        var h = Waybar ? Waybar.cpuHistory : []; if (h.length < 2) return
                        ctx.beginPath(); var step = width / (h.length - 1)
                        for (var i = 0; i < h.length; ++i) {
                            var x = i * step, y = height - (h[i] / 100.0) * (height - 22)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#a8c7fa"; ctx.lineWidth = 2; ctx.stroke()
                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                        ctx.fillStyle = "rgba(168, 199, 250, 0.16)"; ctx.fill()
                    }
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
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                        var h = Waybar ? Waybar.memHistory : []; if (h.length < 2) return
                        ctx.beginPath(); var step = width / (h.length - 1)
                        for (var i = 0; i < h.length; ++i) {
                            var x = i * step, y = height - (h[i] / 100.0) * (height - 22)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#80d8ff"; ctx.lineWidth = 2; ctx.stroke()
                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                        ctx.fillStyle = "rgba(128, 216, 255, 0.16)"; ctx.fill()
                    }
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
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                        var h = Waybar ? Waybar.vramHistory : []; if (h.length < 2) return
                        ctx.beginPath(); var step = width / (h.length - 1)
                        for (var i = 0; i < h.length; ++i) {
                            var x = i * step, y = height - (h[i] / 100.0) * (height - 22)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#b388ff"; ctx.lineWidth = 2; ctx.stroke()
                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                        ctx.fillStyle = "rgba(179, 136, 255, 0.16)"; ctx.fill()
                    }
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
                    onPaint: {
                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                        var h = Waybar ? Waybar.netHistory : []; if (h.length < 2) return
                        ctx.beginPath(); var step = width / (h.length - 1)
                        for (var i = 0; i < h.length; ++i) {
                            var x = i * step, y = height - (h[i] / 100.0) * (height - 22)
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#69f0ae"; ctx.lineWidth = 2; ctx.stroke()
                        ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                        ctx.fillStyle = "rgba(105, 240, 174, 0.16)"; ctx.fill()
                    }
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
