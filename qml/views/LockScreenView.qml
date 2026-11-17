import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: lsScroll
    contentWidth: availableWidth
    clip: true

    property var winObj: ApplicationWindow.window
    property real bgBlurStrength: 0.62
    property real bgDimStrength: 0.38
    property int clockFontSize: 78
    property bool clockShowSeconds: true
    property string customGreeting: "Привет, Whrr!"

    property var widgetsCfg: ({
        "clock":         { enabled: true,  nx: 0.50, ny: 0.25, title: "Часы и дата", icon: "󱑂" },
        "greeting":      { enabled: true,  nx: 0.50, ny: 0.39, title: "Приветствие", icon: "󰀄" },
        "password":      { enabled: true,  nx: 0.50, ny: 0.50, title: "Поле пароля", icon: "" },
        "status":        { enabled: true,  nx: 0.50, ny: 0.59, title: "Раскладка и гео", icon: "󰇧" },
        "notifications": { enabled: true,  nx: 0.50, ny: 0.71, title: "Скрытые уведомления", icon: "󰂚" },
        "media":         { enabled: true,  nx: 0.50, ny: 0.85, title: "Музыкальный плеер", icon: "󰎆" },
        "weather":       { enabled: true,  nx: 0.12, ny: 0.08, title: "Погода", icon: "󰖙" },
        "sysinfo":       { enabled: true,  nx: 0.88, ny: 0.08, title: "Система CPU/RAM", icon: "" }
    })

    function defaultWidgetsCfg() {
        return {
            "clock":         { enabled: true,  nx: 0.50, ny: 0.25, title: "Часы и дата", icon: "󱑂" },
            "greeting":      { enabled: true,  nx: 0.50, ny: 0.39, title: "Приветствие", icon: "󰀄" },
            "password":      { enabled: true,  nx: 0.50, ny: 0.50, title: "Поле пароля", icon: "" },
            "status":        { enabled: true,  nx: 0.50, ny: 0.59, title: "Раскладка и гео", icon: "󰇧" },
            "notifications": { enabled: true,  nx: 0.50, ny: 0.71, title: "Скрытые уведомления", icon: "󰂚" },
            "media":         { enabled: true,  nx: 0.50, ny: 0.85, title: "Музыкальный плеер", icon: "󰎆" },
            "weather":       { enabled: true,  nx: 0.12, ny: 0.08, title: "Погода", icon: "󰖙" },
            "sysinfo":       { enabled: true,  nx: 0.88, ny: 0.08, title: "Система CPU/RAM", icon: "" }
        }
    }

    function loadCfg() {
        if (!Waybar) return
        var raw = Waybar.lockScreenConfigJson
        if (!raw || raw.length === 0) return
        try {
            var d = JSON.parse(raw)
            if (d.bgBlurStrength !== undefined) bgBlurStrength = d.bgBlurStrength
            if (d.bgDimStrength !== undefined) bgDimStrength = d.bgDimStrength
            if (d.clockFontSize !== undefined) clockFontSize = d.clockFontSize
            if (d.clockShowSeconds !== undefined) clockShowSeconds = d.clockShowSeconds
            if (d.customGreeting !== undefined) customGreeting = d.customGreeting
            if (d.widgets) {
                var def = defaultWidgetsCfg()
                for (var k in def) {
                    if (d.widgets[k]) {
                        def[k].enabled = (d.widgets[k].enabled !== undefined) ? d.widgets[k].enabled : def[k].enabled
                        def[k].nx = (d.widgets[k].nx !== undefined) ? d.widgets[k].nx : def[k].nx
                        def[k].ny = (d.widgets[k].ny !== undefined) ? d.widgets[k].ny : def[k].ny
                    }
                }
                widgetsCfg = def
            }
        } catch (e) {}
    }

    function saveCfg() {
        if (!Waybar) return
        var obj = {
            bgBlurStrength: bgBlurStrength,
            bgDimStrength: bgDimStrength,
            clockFontSize: clockFontSize,
            clockShowSeconds: clockShowSeconds,
            customGreeting: customGreeting,
            widgets: widgetsCfg
        }
        Waybar.saveLockScreenConfig(JSON.stringify(obj, null, 2))
    }

    Component.onCompleted: loadCfg()
    Connections {
        target: Waybar
        function onLockConfigChanged() { lsScroll.loadCfg() }
    }

    Item {
        width: lsScroll.availableWidth
        implicitHeight: lsCol.implicitHeight + 44

        ColumnLayout {
            id: lsCol
            width: Math.min(parent.width - 48, 860)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "󰌾  Экран блокировки HySett (Super + L)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "󰕰 Полноэкранный редактор"
                    onClicked: if (lsScroll.winObj) lsScroll.winObj.activateLockScreen(true)
                }
                StyledButton {
                    text: "󰌾 Заблокировать (Super + L)"
                    onClicked: if (lsScroll.winObj) lsScroll.winObj.activateLockScreen(false)
                }
            }

            // Интерактивный мини-макет 16:9 прямо во вкладке (можно двигать виджеты мышкой!)
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: previewCol.implicitHeight + 28
                ColumnLayout {
                    id: previewCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Интерактивный макет экрана (перетаскивай блоки мышью):"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        StyledButton {
                            text: "↺ Сбросить позиции"
                            onClicked: {
                                lsScroll.widgetsCfg = lsScroll.defaultWidgetsCfg()
                                lsScroll.saveCfg()
                            }
                        }
                    }

                    Rectangle {
                        id: stageBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * 9 / 16)
                        radius: (Theme && Theme.isRounded) ? 12 : 0
                        color: "#0d0f14"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: "file:///home/whrr/.cache/lock_bg.png"
                            opacity: 1.0 - lsScroll.bgDimStrength * 0.75
                        }

                        // Центральные направляющие
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }

                        Repeater {
                            model: ["clock", "greeting", "password", "status", "notifications", "media", "weather", "sysinfo"]
                            delegate: Rectangle {
                                id: miniToken
                                readonly property var wObj: lsScroll.widgetsCfg[modelData] || { enabled: true, nx: 0.5, ny: 0.5, title: modelData, icon: "󰕰" }
                                visible: wObj.enabled
                                width: tokenRow.implicitWidth + 20
                                height: 28
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                x: Math.round(wObj.nx * stageBox.width - width * 0.5)
                                y: Math.round(wObj.ny * stageBox.height - height * 0.5)
                                color: dragTokenMa.pressed
                                       ? ((Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae")
                                       : Qt.rgba(0.06, 0.07, 0.10, 0.86)
                                border.width: 1
                                border.color: (Config && Theme && Theme.isRounded) ? Config.m3Primary : "#69f0ae"

                                Row {
                                    id: tokenRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: miniToken.wObj.icon + "  " + miniToken.wObj.title
                                        color: dragTokenMa.pressed ? "#000000" : "#ffffff"
                                        font.pixelSize: Config.fontSize - 1
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: dragTokenMa
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeAllCursor
                                    property real sx: 0; property real sy: 0
                                    onPressed: (m) => { sx = m.x; sy = m.y }
                                    onPositionChanged: (m) => {
                                        if (!pressed) return
                                        var cx = miniToken.x + (m.x - sx) + miniToken.width * 0.5
                                        var cy = miniToken.y + (m.y - sy) + miniToken.height * 0.5
                                        if (Math.abs(cx - stageBox.width * 0.5) < 10) cx = stageBox.width * 0.5
                                        var copy = JSON.parse(JSON.stringify(lsScroll.widgetsCfg))
                                        copy[modelData].nx = Math.max(0.06, Math.min(0.94, cx / stageBox.width))
                                        copy[modelData].ny = Math.max(0.06, Math.min(0.94, cy / stageBox.height))
                                        lsScroll.widgetsCfg = copy
                                    }
                                    onReleased: lsScroll.saveCfg()
                                }
                            }
                        }
                    }
                }
            }

            // Включаемые виджеты на экране блокировки
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: visCol.implicitHeight + 28
                ColumnLayout {
                    id: visCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "Отображаемые элементы на экране блокировки"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 8

                        Repeater {
                            model: ["clock", "greeting", "password", "status", "notifications", "media", "weather", "sysinfo"]
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                readonly property var wObj: lsScroll.widgetsCfg[modelData] || { enabled: true, title: modelData, icon: "󰕰" }
                                Text {
                                    text: wObj.icon + "  " + wObj.title
                                    color: "#dddddd"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: wObj.enabled
                                    onToggled: {
                                        var copy = JSON.parse(JSON.stringify(lsScroll.widgetsCfg))
                                        copy[modelData].enabled = checked
                                        lsScroll.widgetsCfg = copy
                                        lsScroll.saveCfg()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Параметры размытия, часов и приветствия
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: styleCol.implicitHeight + 28
                ColumnLayout {
                    id: styleCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "Оформление фона и часов"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Сила размытия обоев (Blur):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0.0; to: 0.95; stepSize: 0.02
                            value: lsScroll.bgBlurStrength
                            onMoved: { lsScroll.bgBlurStrength = value; lsScroll.saveCfg() }
                        }
                        Text { text: Math.round(lsScroll.bgBlurStrength * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Затемнение фона (Dim):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0.05; to: 0.85; stepSize: 0.02
                            value: lsScroll.bgDimStrength
                            onMoved: { lsScroll.bgDimStrength = value; lsScroll.saveCfg() }
                        }
                        Text { text: Math.round(lsScroll.bgDimStrength * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Размер шрифта часов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 44; to: 120; stepSize: 2
                            value: lsScroll.clockFontSize
                            onMoved: { lsScroll.clockFontSize = Math.round(value); lsScroll.saveCfg() }
                        }
                        Text { text: lsScroll.clockFontSize + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Показывать секунды на часах:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: lsScroll.clockShowSeconds
                            onToggled: { lsScroll.clockShowSeconds = checked; lsScroll.saveCfg() }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Текст приветствия:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                        TextField {
                            text: lsScroll.customGreeting
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 28
                            Layout.fillWidth: true
                            onEditingFinished: { lsScroll.customGreeting = text; lsScroll.saveCfg() }
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.16)
                            }
                        }
                    }
                }
            }
        }
    }
}
