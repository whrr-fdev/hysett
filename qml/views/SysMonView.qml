import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: sysMonRoot
    property string procFilter: ""

    Timer {
        interval: 2000
        running: sysMonRoot.visible
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
                text: "󰍹  Открыть полный Btop"
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

        // СПИСОК ПРОЦЕССОВ С ФИЛЬТРАМИ ПО ПРОЦУ (CPU) И ПО ОЗУ (RAM)
        GlassPanel {
            objectName: "atmoObstacle"
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 6
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text { text: "Активные процессы"; color: "#ffffff"; font.pixelSize: 12; font.bold: true }
                    SegmentedButton {
                        options: [" По процу (CPU)", "󰍛 По ОЗУ (RAM)"]
                        selectedIndex: Waybar ? Waybar.processSortMode : 0
                        onSelected: (idx) => { if (Waybar) Waybar.processSortMode = idx }
                    }
                    Item { Layout.fillWidth: true }
                    TextField {
                        Layout.preferredWidth: 190; implicitHeight: 24; leftPadding: 8; rightPadding: 8
                        color: "#ffffff"; font.pixelSize: 11; placeholderText: "Поиск процесса..."; placeholderTextColor: "#777777"
                        onTextChanged: sysMonRoot.procFilter = text.toLowerCase()
                        background: Rectangle { radius: (Theme && Theme.isRounded) ? 6 : 0; color: Qt.rgba(1,1,1,0.06); border.color: Qt.rgba(1,1,1,0.16) }
                    }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    model: Waybar ? Waybar.processList : []
                    delegate: Rectangle {
                        property bool vis: sysMonRoot.procFilter.length === 0 || modelData.name.toLowerCase().indexOf(sysMonRoot.procFilter) !== -1
                        width: ListView.view.width; height: vis ? 26 : 0; visible: vis
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                            Text { text: "PID " + modelData.pid; color: "#888888"; font.pixelSize: 10; Layout.preferredWidth: 64 }
                            Text { text: modelData.name; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                text: " " + modelData.cpu
                                color: (Waybar && Waybar.processSortMode === 0) ? "#a8c7fa" : "#bbbbbb"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 0)
                                Layout.preferredWidth: 68
                                horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: "󰍛 " + modelData.mem
                                color: (Waybar && Waybar.processSortMode === 1) ? "#80d8ff" : "#cccccc"
                                font.pixelSize: 11
                                font.bold: (Waybar && Waybar.processSortMode === 1)
                                Layout.preferredWidth: 74
                                horizontalAlignment: Text.AlignRight
                            }
                            StyledButton { text: "✕"; isIconOnly: true; implicitHeight: 20; implicitWidth: 22; onClicked: if (Waybar) Waybar.killProcess(modelData.pid) }
                        }
                    }
                }
            }
        }
    }
}
