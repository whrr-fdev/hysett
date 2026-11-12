import QtQuick
import QtQuick.Window
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
    hoverEnabled: true
    Layout.alignment: Qt.AlignVCenter
    readonly property bool isM3: Theme && Theme.isRounded

    readonly property real waveSpeed: Config ? Config.sliderWaveSpeed : 1.25
    readonly property real baseWaveAmp: control.isM3 ? (Config ? Config.sliderWaveAmplitude : 2.0) : 0.0
    property real waveAmp: baseWaveAmp * (control.pressed ? 1.20 : (control.hovered ? 1.08 : 1.0))
    Behavior on waveAmp { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property real waveLen: Config ? Config.sliderWaveLength : 24.0
    readonly property real lineThick: Config ? Config.sliderThickness : 2.4

    property real animPos: control.visualPosition
    Behavior on animPos {
        enabled: !control.pressed
        NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
    }

    property real wavePhase: 0.0

    Timer {
        interval: 20
        repeat: true
        running: control.visible && control.isM3 && control.waveSpeed > 0.02 && control.waveAmp > 0.08 && control.animPos > 0.01 &&
                 (ApplicationWindow.window ? ApplicationWindow.window.drawerActive : true)
        onTriggered: {
            var boost = control.pressed ? 1.30 : (control.hovered ? 1.10 : 1.0)
            control.wavePhase = (control.wavePhase + 0.085 * control.waveSpeed * boost) % (Math.PI * 2.0)
            trackCanvas.requestPaint()
        }
    }

    onAnimPosChanged: trackCanvas.requestPaint()
    onWaveAmpChanged: trackCanvas.requestPaint()
    onWaveLenChanged: trackCanvas.requestPaint()
    onLineThickChanged: trackCanvas.requestPaint()
    onIsM3Changed: trackCanvas.requestPaint()

    Connections {
        target: Config
        function onAccentColorChanged() { trackCanvas.requestPaint() }
        function onM3AttributesChanged() { trackCanvas.requestPaint() }
    }

    background: Item {
        x: control.leftPadding
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: 180
        implicitHeight: 22
        width: control.availableWidth
        height: 22

        readonly property real handleX: control.animPos * (width - 12) + 6
        readonly property real gapHalf: control.isM3 ? 6 : 3

        Canvas {
            id: trackCanvas
            anchors.fill: parent
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (width <= 8) return

                var cy = height * 0.5
                var thick = control.lineThick
                var padX = Math.max(4.0, thick + 2.0)
                var maxAmp = Math.max(0.0, (height * 0.5) - thick - 2.0)
                var wl = Math.max(14.0, control.waveLen)
                // Ограничиваем крутизну волны относительно длины волны, чтобы изгибы всегда оставались плавными
                var amp = control.isM3 ? Math.min(maxAmp, Math.min(control.waveAmp, wl * 0.16)) : 0.0

                var activeEnd = Math.max(padX, parent.handleX - parent.gapHalf)
                var inactiveStart = Math.min(width - padX, parent.handleX + parent.gapHalf)

                // 1. Правая неактивная часть трека
                if (width - padX - inactiveStart > 2.0) {
                    ctx.beginPath()
                    ctx.lineWidth = thick
                    ctx.lineCap = control.isM3 ? "round" : "butt"
                    ctx.strokeStyle = Config
                        ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.90).toString()
                        : "rgba(255, 255, 255, 0.18)"
                    ctx.moveTo(inactiveStart, cy)
                    ctx.lineTo(width - padX, cy)
                    ctx.stroke()
                }

                // 2. Левая активная волнистая часть трека (гладкие кривые Безье + C1 smoothstep огибающая на краях)
                var span = activeEnd - padX
                if (span > 1.5) {
                    ctx.beginPath()
                    ctx.lineWidth = thick
                    ctx.lineCap = control.isM3 ? "round" : "butt"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = Config ? Config.m3Primary.toString() : "#a8c7fa"

                    if (amp <= 0.08 || span < 8.0) {
                        ctx.moveTo(padX, cy)
                        ctx.lineTo(activeEnd, cy)
                    } else {
                        var taper = Math.max(6.0, Math.min(22.0, span * 0.35))
                        var steps = Math.max(24, Math.ceil(span / 1.5))
                        var prevX = padX
                        var prevY = cy
                        ctx.moveTo(padX, cy)

                        for (var i = 1; i <= steps; ++i) {
                            var px = padX + (i / steps) * span
                            var uL = Math.min(1.0, Math.max(0.0, (px - padX) / taper))
                            var uR = Math.min(1.0, Math.max(0.0, (activeEnd - px) / taper))
                            var envL = uL * uL * (3.0 - 2.0 * uL)
                            var envR = uR * uR * (3.0 - 2.0 * uR)
                            var env = envL * envR
                            var wy = cy + Math.sin(((px - padX) / wl) * Math.PI * 2.0 - control.wavePhase) * amp * env

                            if (i === 1) {
                                ctx.lineTo(px, wy)
                            } else {
                                var midX = (prevX + px) * 0.5
                                var midY = (prevY + wy) * 0.5
                                ctx.quadraticCurveTo(prevX, prevY, midX, midY)
                            }
                            prevX = px
                            prevY = wy
                        }
                        ctx.lineTo(activeEnd, cy)
                    }
                    ctx.stroke()
                }
            }
        }
    }

    handle: Rectangle {
        x: Math.round(control.leftPadding + control.animPos * (control.availableWidth - width))
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        width: control.isM3 ? 4 : 6
        height: control.isM3 ? (control.pressed ? 18 : 15) : (control.pressed ? 16 : 14)
        radius: control.isM3 ? 2 : 0
        color: Config ? Config.m3Primary : "#a8c7fa"
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
}
