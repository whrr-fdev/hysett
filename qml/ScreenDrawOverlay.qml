import QtQuick
import QtQuick.Window
import HySett

Window {
    id: drawWin
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint
    width: Screen.width > 0 ? Screen.width : 1920
    height: Screen.height > 0 ? Screen.height : 1080

    property bool bindHeld: false
    property bool mouseHeld: false
    property bool inputCaptured: false
    property bool testBypassRecording: false
    property var strokes: []
    property var activeStroke: null
    property real cursorX: -100
    property real cursorY: -100
    property bool cursorInside: false
    property var quickPalette: ["#ff3b5c", "#00e5ff", "#39ff14", "#ffea00", "#c060ff", "#ff7a00", "#ffffff"]

    function currentStrokeColor() {
        if (!Config) return "#ff3b5c"
        if (Config.screenDrawUseThemeColor) return Config.m3Primary.toString()
        return Config.screenDrawColor.toString()
    }

    function hexToRgb(hexStr) {
        var s = String(hexStr || "#ff3b5c").trim()
        if (s.charAt(0) === "#") s = s.slice(1)
        if (s.length === 8) s = s.slice(2)
        if (s.length !== 6) return { r: 255, g: 59, b: 92 }
        var r = parseInt(s.slice(0, 2), 16)
        var g = parseInt(s.slice(2, 4), 16)
        var b = parseInt(s.slice(4, 6), 16)
        if (isNaN(r) || isNaN(g) || isNaN(b)) return { r: 255, g: 59, b: 92 }
        return { r: r, g: g, b: b }
    }

    function canActivate(isTest) {
        if (!Config || !ScreenDraw) return false
        if (ScreenDraw.isScreenLocked()) return false
        if (!isTest) {
            if (!Config.screenDrawEnabled) return false
            if (Config.screenDrawOnlyRecording && !ScreenDraw.isRecordingNow()) return false
        }
        return true
    }

    function beginCapture(isTest) {
        testBypassRecording = !!isTest
        inputCaptured = true
        var now = Date.now()
        for (var i = 0; i < strokes.length; ++i) {
            if (strokes[i].fadeStartMs > now) {
                strokes[i].fadeStartMs = 0
            }
        }
        if (ScreenDraw) ScreenDraw.setOverlayInput(drawWin, true, true)
        keyScope.forceActiveFocus()
        focusRetryCount = 0
        focusRetryTimer.restart()
        drawCanvas.requestPaint()
    }

    function finishActiveStroke() {
        if (activeStroke) {
            strokes.push(activeStroke)
            activeStroke = null
            drawCanvas.requestPaint()
        }
    }

    function releaseCaptureAndScheduleFade() {
        finishActiveStroke()
        inputCaptured = false
        testBypassRecording = false
        cursorInside = false
        focusRetryTimer.stop()
        if (ScreenDraw) ScreenDraw.setOverlayInput(drawWin, false, false)

        var now = Date.now()
        var delayMs = Config ? Math.round(Config.screenDrawFadeDelay * 1000) : 2500
        var durMs = Config ? Math.max(80, Math.round(Config.screenDrawFadeDuration * 1000)) : 800
        for (var i = 0; i < strokes.length; ++i) {
            if (strokes[i].fadeStartMs === 0) {
                strokes[i].fadeStartMs = now + delayMs
                strokes[i].fadeDurMs = durMs
            }
        }
        if (strokes.length === 0) {
            fadeAnimTimer.stop()
            fadeWaitTimer.stop()
            if (ScreenDraw) ScreenDraw.hideOverlay(drawWin)
        } else {
            scheduleNextFadeTick()
        }
    }

    function scheduleNextFadeTick() {
        var now = Date.now()
        var minStart = 0
        var hasFadingNow = false
        for (var i = 0; i < strokes.length; ++i) {
            var fs = strokes[i].fadeStartMs
            if (fs > 0) {
                if (now >= fs) {
                    hasFadingNow = true
                    break
                }
                if (minStart === 0 || fs < minStart) minStart = fs
            }
        }
        if (hasFadingNow) {
            fadeWaitTimer.stop()
            if (!fadeAnimTimer.running) fadeAnimTimer.start()
        } else if (minStart > 0) {
            fadeAnimTimer.stop()
            fadeWaitTimer.interval = Math.max(16, minStart - now)
            fadeWaitTimer.restart()
        } else {
            fadeAnimTimer.stop()
            fadeWaitTimer.stop()
        }
    }

    function handleDrawDown() {
        if (testBypassRecording && inputCaptured) {
            bindHeld = false
            mouseHeld = false
            releaseCaptureAndScheduleFade()
            return
        }
        if (!canActivate(false)) return
        if (Config && Config.screenDrawMode === 1) {
            if (inputCaptured) {
                bindHeld = false
                mouseHeld = false
                releaseCaptureAndScheduleFade()
            } else {
                beginCapture(false)
            }
            return
        }
        bindHeld = true
        if (!inputCaptured) beginCapture(false)
    }

    function handleDrawUp() {
        if (testBypassRecording) return
        if (Config && Config.screenDrawMode === 1) return
        bindHeld = false
        if (!mouseHeld && inputCaptured) {
            releaseCaptureAndScheduleFade()
        }
    }

    function handleDrawToggle() {
        if (inputCaptured) {
            bindHeld = false
            mouseHeld = false
            releaseCaptureAndScheduleFade()
        } else if (canActivate(false)) {
            beginCapture(false)
        }
    }

    function handleDrawTest() {
        if (!canActivate(true)) return
        bindHeld = false
        mouseHeld = false
        beginCapture(true)
    }

    function handleDrawClear() {
        strokes = []
        activeStroke = null
        drawCanvas.requestPaint()
        if (!inputCaptured) {
            fadeAnimTimer.stop()
            fadeWaitTimer.stop()
            if (ScreenDraw) ScreenDraw.hideOverlay(drawWin)
        }
    }

    function undoLastStroke() {
        if (activeStroke) {
            activeStroke = null
            mouseHeld = false
            drawCanvas.requestPaint()
            return
        }
        if (strokes.length > 0) {
            strokes.pop()
            drawCanvas.requestPaint()
        }
    }

    Connections {
        target: ScreenDraw
        function onDrawDownRequested() { drawWin.handleDrawDown() }
        function onDrawUpRequested() { drawWin.handleDrawUp() }
        function onDrawToggleRequested() { drawWin.handleDrawToggle() }
        function onDrawClearRequested() { drawWin.handleDrawClear() }
        function onDrawTestRequested() { drawWin.handleDrawTest() }
    }

    property int focusRetryCount: 0
    Timer {
        id: focusRetryTimer
        interval: 20
        repeat: true
        onTriggered: {
            drawWin.focusRetryCount++
            if (!drawWin.inputCaptured || drawWin.focusRetryCount > 12) {
                stop()
                return
            }
            if (!keyScope.activeFocus) {
                keyScope.forceActiveFocus()
            }
        }
    }

    Timer {
        id: fadeWaitTimer
        repeat: false
        onTriggered: drawWin.scheduleNextFadeTick()
    }

    Timer {
        id: fadeAnimTimer
        interval: 16
        repeat: true
        onTriggered: {
            var now = Date.now()
            var nextStrokes = []
            var anyActiveFade = false
            var nextWait = 0
            for (var i = 0; i < drawWin.strokes.length; ++i) {
                var st = drawWin.strokes[i]
                if (st.fadeStartMs > 0) {
                    if (now >= st.fadeStartMs) {
                        var t = Math.min(1.0, (now - st.fadeStartMs) / Math.max(80, st.fadeDurMs))
                        st.alpha = Math.max(0.0, 1.0 - t * t)
                        if (st.alpha > 0.008) {
                            nextStrokes.push(st)
                            anyActiveFade = true
                        }
                    } else {
                        st.alpha = 1.0
                        nextStrokes.push(st)
                        if (nextWait === 0 || st.fadeStartMs < nextWait) nextWait = st.fadeStartMs
                    }
                } else {
                    st.alpha = 1.0
                    nextStrokes.push(st)
                }
            }
            drawWin.strokes = nextStrokes
            drawCanvas.requestPaint()

            if (!anyActiveFade) {
                stop()
                if (nextWait > 0) {
                    fadeWaitTimer.interval = Math.max(16, nextWait - now)
                    fadeWaitTimer.restart()
                } else if (drawWin.strokes.length === 0 && !drawWin.activeStroke && !drawWin.inputCaptured) {
                    if (ScreenDraw) ScreenDraw.hideOverlay(drawWin)
                }
            }
        }
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!drawWin.inputCaptured) return
            if (event.key === Qt.Key_Escape) {
                drawWin.bindHeld = false
                drawWin.mouseHeld = false
                drawWin.releaseCaptureAndScheduleFade()
                event.accepted = true
            } else if (event.key === Qt.Key_C || event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                drawWin.handleDrawClear()
                event.accepted = true
            } else if (event.key === Qt.Key_Z) {
                drawWin.undoLastStroke()
                event.accepted = true
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_7) {
                var idx = event.key - Qt.Key_1
                if (Config && idx >= 0 && idx < drawWin.quickPalette.length) {
                    Config.screenDrawUseThemeColor = false
                    Config.screenDrawColor = drawWin.quickPalette[idx]
                }
                event.accepted = true
            }
        }

        Keys.onReleased: (event) => {
            if (event.isAutoRepeat) return
            if (Config && Config.screenDrawMode === 0 && !drawWin.testBypassRecording && drawWin.bindHeld) {
                if (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr ||
                    event.key === Qt.Key_QuoteLeft || event.key === Qt.Key_AsciiTilde ||
                    event.key === 1105 || event.key === 1025) {
                    drawWin.handleDrawUp()
                    event.accepted = true
                }
            }
        }

        Canvas {
            id: drawCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            antialiasing: true

            function traceStrokePath(ctx, st) {
                var pts = st.points
                if (!pts || pts.length === 0) return false
                ctx.beginPath()
                if (st.kind === "arrow" && pts.length >= 2) {
                    var p0 = pts[0]
                    var p1 = pts[pts.length - 1]
                    ctx.moveTo(p0.x, p0.y)
                    ctx.lineTo(p1.x, p1.y)
                    var angle = Math.atan2(p1.y - p0.y, p1.x - p0.x)
                    var headLen = Math.max(16, st.width * 3.4)
                    var spread = 0.48
                    ctx.moveTo(p1.x, p1.y)
                    ctx.lineTo(p1.x - headLen * Math.cos(angle - spread), p1.y - headLen * Math.sin(angle - spread))
                    ctx.moveTo(p1.x, p1.y)
                    ctx.lineTo(p1.x - headLen * Math.cos(angle + spread), p1.y - headLen * Math.sin(angle + spread))
                    return true
                }
                if (st.kind === "rect" && pts.length >= 2) {
                    var r0 = pts[0]
                    var r1 = pts[pts.length - 1]
                    var rx = Math.min(r0.x, r1.x)
                    var ry = Math.min(r0.y, r1.y)
                    var rw = Math.abs(r1.x - r0.x)
                    var rh = Math.abs(r1.y - r0.y)
                    var rad = Math.min(10, rw * 0.25, rh * 0.25)
                    ctx.moveTo(rx + rad, ry)
                    ctx.lineTo(rx + rw - rad, ry)
                    ctx.quadraticCurveTo(rx + rw, ry, rx + rw, ry + rad)
                    ctx.lineTo(rx + rw, ry + rh - rad)
                    ctx.quadraticCurveTo(rx + rw, ry + rh, rx + rw - rad, ry + rh)
                    ctx.lineTo(rx + rad, ry + rh)
                    ctx.quadraticCurveTo(rx, ry + rh, rx, ry + rh - rad)
                    ctx.lineTo(rx, ry + rad)
                    ctx.quadraticCurveTo(rx, ry, rx + rad, ry)
                    ctx.closePath()
                    return true
                }
                if (pts.length === 1) {
                    ctx.moveTo(pts[0].x, pts[0].y)
                    ctx.lineTo(pts[0].x + 0.15, pts[0].y + 0.15)
                    return true
                }
                if (pts.length === 2) {
                    ctx.moveTo(pts[0].x, pts[0].y)
                    ctx.lineTo(pts[1].x, pts[1].y)
                    return true
                }
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var i = 1; i < pts.length - 1; ++i) {
                    var mx = (pts[i].x + pts[i + 1].x) * 0.5
                    var my = (pts[i].y + pts[i + 1].y) * 0.5
                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my)
                }
                var last = pts[pts.length - 1]
                ctx.lineTo(last.x, last.y)
                return true
            }

            function drawSingleStroke(ctx, st) {
                var a = st.alpha
                if (a <= 0.005) return
                var rgb = drawWin.hexToRgb(st.color)
                var r = rgb.r, g = rgb.g, b = rgb.b
                var w = st.width
                var gs = st.glowStrength
                var gm = Math.min(1.4, gs)

                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                if (st.brushStyle === 0) {
                    if (!traceStrokePath(ctx, st)) return
                    ctx.lineWidth = w
                    ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.96 * a).toFixed(3) + ")"
                    ctx.stroke()
                    return
                }

                if (st.brushStyle === 1) {
                    // Светящиеся края: мягкий внешний ореол + яркая светящаяся кромка + насыщенная жила внутри
                    if (gs > 0.01) {
                        traceStrokePath(ctx, st)
                        ctx.lineWidth = w + 20.0 * gs
                        ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.08 * a * gm).toFixed(3) + ")"
                        ctx.stroke()

                        traceStrokePath(ctx, st)
                        ctx.lineWidth = w + 11.0 * gs
                        ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.18 * a * gm).toFixed(3) + ")"
                        ctx.stroke()

                        traceStrokePath(ctx, st)
                        ctx.lineWidth = w + 5.0 * gs
                        ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.42 * a * gm).toFixed(3) + ")"
                        ctx.stroke()
                    }
                    var er = Math.min(255, Math.round(r * 0.28 + 255 * 0.72))
                    var eg = Math.min(255, Math.round(g * 0.28 + 255 * 0.72))
                    var eb = Math.min(255, Math.round(b * 0.28 + 255 * 0.72))
                    traceStrokePath(ctx, st)
                    ctx.lineWidth = w + 1.8
                    ctx.strokeStyle = "rgba(" + er + "," + eg + "," + eb + "," + (0.95 * a).toFixed(3) + ")"
                    ctx.stroke()

                    var cr = Math.round(r * 0.56)
                    var cg = Math.round(g * 0.56)
                    var cb = Math.round(b * 0.56)
                    traceStrokePath(ctx, st)
                    ctx.lineWidth = Math.max(1.2, w * 0.58)
                    ctx.strokeStyle = "rgba(" + cr + "," + cg + "," + cb + "," + (0.94 * a).toFixed(3) + ")"
                    ctx.stroke()
                    return
                }

                // Стиль 2: Неоновый лазер (раскалённый светлый центр + широкий цветной ореол)
                if (gs > 0.01) {
                    traceStrokePath(ctx, st)
                    ctx.lineWidth = w + 24.0 * gs
                    ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.10 * a * gm).toFixed(3) + ")"
                    ctx.stroke()

                    traceStrokePath(ctx, st)
                    ctx.lineWidth = w + 13.0 * gs
                    ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.24 * a * gm).toFixed(3) + ")"
                    ctx.stroke()

                    traceStrokePath(ctx, st)
                    ctx.lineWidth = w + 5.5 * gs
                    ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.52 * a * gm).toFixed(3) + ")"
                    ctx.stroke()
                }
                traceStrokePath(ctx, st)
                ctx.lineWidth = w
                ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.96 * a).toFixed(3) + ")"
                ctx.stroke()

                var lr = Math.min(255, Math.round(r * 0.18 + 255 * 0.82))
                var lg = Math.min(255, Math.round(g * 0.18 + 255 * 0.82))
                var lb = Math.min(255, Math.round(b * 0.18 + 255 * 0.82))
                traceStrokePath(ctx, st)
                ctx.lineWidth = Math.max(1.2, w * 0.42)
                ctx.strokeStyle = "rgba(" + lr + "," + lg + "," + lb + "," + (0.98 * a).toFixed(3) + ")"
                ctx.stroke()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                for (var i = 0; i < drawWin.strokes.length; ++i) {
                    drawSingleStroke(ctx, drawWin.strokes[i])
                }
                if (drawWin.activeStroke) {
                    drawSingleStroke(ctx, drawWin.activeStroke)
                }
            }
        }

        MouseArea {
            id: drawMouse
            anchors.fill: parent
            enabled: drawWin.inputCaptured
            hoverEnabled: drawWin.inputCaptured
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor

            onEntered: drawWin.cursorInside = true
            onExited: drawWin.cursorInside = false

            onPressed: (mouse) => {
                drawWin.cursorX = mouse.x
                drawWin.cursorY = mouse.y
                drawWin.cursorInside = true
                if (mouse.button === Qt.RightButton) {
                    drawWin.undoLastStroke()
                    return
                }
                if (mouse.button === Qt.LeftButton) {
                    drawWin.mouseHeld = true
                    var kind = "free"
                    if (mouse.modifiers & Qt.ShiftModifier) kind = "arrow"
                    else if (mouse.modifiers & Qt.ControlModifier) kind = "rect"
                    drawWin.activeStroke = {
                        kind: kind,
                        points: [{ x: mouse.x, y: mouse.y }],
                        color: drawWin.currentStrokeColor(),
                        width: Config ? Config.screenDrawLineWidth : 5.0,
                        brushStyle: Config ? Config.screenDrawBrushStyle : 1,
                        glowStrength: Config ? Config.screenDrawGlowStrength : 0.90,
                        fadeStartMs: 0,
                        fadeDurMs: Config ? Math.max(80, Math.round(Config.screenDrawFadeDuration * 1000)) : 800,
                        alpha: 1.0
                    }
                    drawCanvas.requestPaint()
                }
            }

            onPositionChanged: (mouse) => {
                drawWin.cursorX = mouse.x
                drawWin.cursorY = mouse.y
                drawWin.cursorInside = true
                if (!drawWin.mouseHeld || !drawWin.activeStroke) return
                var pts = drawWin.activeStroke.points
                if (drawWin.activeStroke.kind === "arrow" || drawWin.activeStroke.kind === "rect") {
                    if (pts.length < 2) pts.push({ x: mouse.x, y: mouse.y })
                    else pts[1] = { x: mouse.x, y: mouse.y }
                    drawCanvas.requestPaint()
                    return
                }
                var prev = pts[pts.length - 1]
                var dx = mouse.x - prev.x
                var dy = mouse.y - prev.y
                if (dx * dx + dy * dy >= 5.0) {
                    pts.push({ x: mouse.x, y: mouse.y })
                    drawCanvas.requestPaint()
                }
            }

            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    drawWin.mouseHeld = false
                    drawWin.finishActiveStroke()
                    if (!drawWin.bindHeld && !drawWin.testBypassRecording && Config && Config.screenDrawMode === 0) {
                        drawWin.releaseCaptureAndScheduleFade()
                    }
                }
            }

            onCanceled: {
                drawWin.mouseHeld = false
                drawWin.finishActiveStroke()
                if (!drawWin.bindHeld && !drawWin.testBypassRecording && Config && Config.screenDrawMode === 0) {
                    drawWin.releaseCaptureAndScheduleFade()
                }
            }

            onWheel: (wheel) => {
                if (!Config) return
                var delta = wheel.angleDelta.y > 0 ? 1.0 : -1.0
                Config.screenDrawLineWidth = Math.max(1.5, Math.min(24.0, Config.screenDrawLineWidth + delta))
            }
        }

        // Кольцо кисти вокруг курсора во время рисования
        Rectangle {
            visible: drawWin.inputCaptured && drawWin.cursorInside && (!Config || Config.screenDrawShowHint)
            property real ringSz: Math.max(12, (Config ? Config.screenDrawLineWidth : 5) + 6)
            x: drawWin.cursorX - ringSz * 0.5
            y: drawWin.cursorY - ringSz * 0.5
            width: ringSz
            height: ringSz
            radius: ringSz * 0.5
            color: "transparent"
            border.width: 1.5
            border.color: drawWin.currentStrokeColor()
            opacity: 0.9
        }

    }
}
