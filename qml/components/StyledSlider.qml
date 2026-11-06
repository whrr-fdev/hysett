import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Slider {
    id: control
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 22
    Layout.alignment: Qt.AlignVCenter
    readonly property bool isM3: Theme && Theme.isRounded

    readonly property real waveSpeed: Config ? Config.sliderWaveSpeed : 1.25
    readonly property real waveAmp: control.isM3 ? (Config ? Config.sliderWaveAmplitude : 2.4) : 0.0
    readonly property real waveLen: Config ? Config.sliderWaveLength : 22.0
    readonly property real lineThick: Config ? Config.sliderThickness : 2.4

    property real wavePhase: 0.0

    Timer {
        interval: 24
        repeat: true
        running: control.visible && control.isM3 && control.waveSpeed > 0.02 && control.waveAmp > 0.1 && control.visualPosition > 0.01
        onTriggered: {
            control.wavePhase = (control.wavePhase + 0.11 * control.waveSpeed) % (Math.PI * 200.0)
            waveCanvas.requestPaint()
        }
    }

    onVisualPositionChanged: if (control.isM3) waveCanvas.requestPaint()
    onWaveAmpChanged: waveCanvas.requestPaint()
    onWaveLenChanged: waveCanvas.requestPaint()
    onLineThickChanged: waveCanvas.requestPaint()

    Connections {
        target: Config
        function onAccentColorChanged() { waveCanvas.requestPaint() }
        function onM3AttributesChanged() { waveCanvas.requestPaint() }
    }

    background: Item {
        x: control.leftPadding
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: 180
        implicitHeight: 18
        width: control.availableWidth
        height: 18

        readonly property real handleX: control.visualPosition * (width - 10) + 5
        readonly property real gapHalf: control.isM3 ? 6 : 2

        // Активная левая часть: тонкая бегущая синусоидальная волна
        Canvas {
            id: waveCanvas
            x: 0
            y: 0
            width: Math.max(0, Math.ceil(parent.handleX - parent.gapHalf))
            height: parent.height
            visible: width > 2

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (width <= 2) return

                var cy = height * 0.5
                var amp = control.isM3 ? control.waveAmp : 0.0
                var wl = Math.max(8.0, control.waveLen)
                var thick = control.lineThick
                var col = Config ? Config.m3Primary.toString() : "#a8c7fa"

                ctx.beginPath()
                ctx.lineWidth = thick
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.strokeStyle = col

                var startX = thick
                var endX = Math.max(startX, width - thick)

                if (amp <= 0.12) {
                    ctx.moveTo(startX, cy)
                    ctx.lineTo(endX, cy)
                } else {
                    var step = 2.0
                    for (var px = startX; px <= endX; px += step) {
                        var edgeTaper = Math.min(1.0, Math.min(px - startX, endX - px) / 8.0)
                        var wy = cy + Math.sin((px / wl) * Math.PI * 2.0 - control.wavePhase) * amp * edgeTaper
                        if (px === startX) ctx.moveTo(px, wy)
                        else ctx.lineTo(px, wy)
                    }
                }
                ctx.stroke()
            }
        }

        // Неактивная правая часть: тонкая спокойная линия
        Rectangle {
            x: Math.min(parent.width, parent.handleX + parent.gapHalf)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - x - 2)
            height: control.lineThick
            radius: height / 2
            color: Config
                   ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.90)
                   : Qt.rgba(1, 1, 1, 0.18)
            visible: width > 2
        }
    }

    // Изящный бегунок
    handle: Rectangle {
        x: Math.round(control.leftPadding + control.visualPosition * (control.availableWidth - width))
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: control.isM3 ? (control.pressed ? 5 : 4) : (control.pressed ? 8 : 6)
        implicitHeight: control.isM3 ? (control.pressed ? 18 : 15) : (control.pressed ? 16 : 14)
        radius: control.isM3 ? width / 2 : 0
        color: Config ? Config.m3Primary : "#a8c7fa"
        Behavior on implicitWidth { NumberAnimation { duration: 100 } }
        Behavior on implicitHeight { NumberAnimation { duration: 100 } }
    }
}
