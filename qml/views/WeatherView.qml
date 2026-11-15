import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: weatherScroll
    contentWidth: availableWidth
    clip: true

    property int periodTab: 0
    property int previewWeatherMode: 0 // 0=Авто, 1=Ясно, 2=Дождь, 3=Снег
    property int hoveredHourIdx: -1
    property int lastHourIdx: 0
    property int hoveredWeekIdx: -1
    property int lastWeekIdx: 0
    property int hoveredMonthIdx: -1
    property int lastMonthIdx: 0

    readonly property bool isM3: Theme && Theme.isRounded
    readonly property color priCol: Config ? Config.m3Primary : "#a8c7fa"
    readonly property color onPriCol: Config ? Config.accentTextColor : "#000000"
    readonly property color surfHighCol: Config ? Config.m3SurfaceContainerHigh : "#252832"
    readonly property color outCol: Config ? Config.m3Outline : "#444854"

    onVisibleChanged: if (visible && Waybar && Waybar.weatherHourly.length === 0) Waybar.refreshWeather()

    // Преобразование любых эмодзи/описаний погоды в чистые монохромные иконки Nerd Font
    function toNerdWeatherIcon(rawIcon, descText) {
        var s = ((rawIcon || "") + " " + (descText || "")).toLowerCase()
        if (s.indexOf("гроз") !== -1 || s.indexOf("⚡") !== -1 || s.indexOf("⛈") !== -1) return "󰖓"
        if (s.indexOf("снег") !== -1 || s.indexOf("❄") !== -1 || s.indexOf("🌨") !== -1) return "󰼶"
        if (s.indexOf("ливень") !== -1 || s.indexOf("сильный дождь") !== -1) return "󰖖"
        if (s.indexOf("дожд") !== -1 || s.indexOf("осадк") !== -1 || s.indexOf("🌧") !== -1 || s.indexOf("🌦") !== -1) return "󰖗"
        if (s.indexOf("туман") !== -1 || s.indexOf("дымк") !== -1 || s.indexOf("🌫") !== -1) return "󰖑"
        if (s.indexOf("малооблач") !== -1 || s.indexOf("перемен") !== -1 || s.indexOf("облачно с проясн") !== -1 || s.indexOf("⛅") !== -1 || s.indexOf("🌤") !== -1) return "󰖕"
        if (s.indexOf("ясн") !== -1 || s.indexOf("солн") !== -1 || s.indexOf("☀") !== -1) return "󰖙"
        if (s.indexOf("пасмур") !== -1 || s.indexOf("облач") !== -1 || s.indexOf("☁") !== -1) return "󰖐"
        return "󰖕"
    }

    function weatherIconColor(rawIcon, descText) {
        var ic = toNerdWeatherIcon(rawIcon, descText)
        var base
        if (ic === "󰖙") base = Qt.rgba(1.0, 0.84, 0.42, 1.0)
        else if (ic === "󰖕") base = Qt.rgba(0.96, 0.82, 0.52, 1.0)
        else if (ic === "󰖗" || ic === "󰖖") base = Qt.rgba(0.52, 0.78, 1.0, 1.0)
        else if (ic === "󰼶") base = Qt.rgba(0.76, 0.91, 1.0, 1.0)
        else if (ic === "󰖓") base = Qt.rgba(0.84, 0.68, 1.0, 1.0)
        else base = Qt.rgba(0.78, 0.84, 0.92, 1.0)
        return Qt.rgba(
            base.r * 0.78 + weatherScroll.priCol.r * 0.22,
            base.g * 0.78 + weatherScroll.priCol.g * 0.22,
            base.b * 0.78 + weatherScroll.priCol.b * 0.22,
            1.0
        )
    }

    function parseTempNum(str) {
        if (!str) return 0
        var m = String(str).replace("−", "-").match(/-?\d+/)
        return m ? parseInt(m[0], 10) : 0
    }

    readonly property var activeHourlyModel: periodTab === 0 ? (Waybar ? Waybar.weatherHourly : []) : (Waybar ? Waybar.weatherTomorrow : [])
    onActiveHourlyModelChanged: hourlyCurveCanvas.requestPaint()
    onPeriodTabChanged: hourlyCurveCanvas.requestPaint()

    readonly property var weekMinMax: {
        var list = Waybar ? Waybar.weatherWeek : []
        if (!list || list.length === 0) return { min: -5, max: 10, span: 15 }
        var mn = 999
        var mx = -999
        for (var i = 0; i < list.length; ++i) {
            var t1 = parseTempNum(list[i].min)
            var t2 = parseTempNum(list[i].max)
            if (t1 < mn) mn = t1
            if (t2 > mx) mx = t2
        }
        if (mn > mx) { mn = 0; mx = 10 }
        return { min: mn, max: mx, span: Math.max(1, mx - mn) }
    }

    readonly property var todayMinMax: {
        var list = Waybar ? Waybar.weatherHourly : []
        if (!list || list.length === 0) return { min: "+1°", max: "+6°" }
        var mn = 999
        var mx = -999
        for (var i = 0; i < list.length; ++i) {
            var v = parseTempNum(list[i].temp)
            if (v < mn) mn = v
            if (v > mx) mx = v
        }
        if (mn > mx) return { min: "0°", max: "+5°" }
        return {
            min: (mn > 0 ? "+" + mn : String(mn)) + "°",
            max: (mx > 0 ? "+" + mx : String(mx)) + "°"
        }
    }

    Item {
        width: weatherScroll.availableWidth
        implicitHeight: wCol.implicitHeight + 40

        ColumnLayout {
            id: wCol
            width: Math.min(parent.width - 48, 860)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            spacing: 12

            // ШАПКА ВКЛАДКИ
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "󰖙  Погода и метеорадар"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                }
                Rectangle {
                    height: 22
                    width: cityTagRow.implicitWidth + 16
                    radius: weatherScroll.isM3 ? 11 : 0
                    color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.30)
                    Row {
                        id: cityTagRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "󰍎"; color: weatherScroll.priCol; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Петрозаводск"; color: "#e6e6e6"; font.pixelSize: Config.fontSize - 1; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Item { Layout.fillWidth: true }
                StyledButton {
                    text: "󰇧  Gismeteo"
                    implicitHeight: 28
                    onClicked: if (Waybar) Waybar.runCommand("xdg-open https://www.gismeteo.ru/")
                }
                StyledButton {
                    text: "󰑐  Обновить"
                    implicitHeight: 28
                    onClicked: if (Waybar) Waybar.refreshWeather()
                }
            }

            // ГЛАВНАЯ КАРТОЧКА ТЕКУЩЕЙ ПОГОДЫ
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: 154
                clip: true

                ShaderEffect {
                    id: weatherSkyShader
                    anchors.fill: parent
                    property real animT: 0.0
                    NumberAnimation on animT {
                        from: 0.0; to: 628.3185; duration: 600000
                        loops: Animation.Infinite
                        running: weatherScroll.visible
                    }
                    property vector2d u_resolution: Qt.vector2d(width, height)
                    property real u_time: animT
                    property real u_mode: {
                        var hr = new Date().getHours()
                        if (hr >= 20 || hr < 6) return 2.0
                        if (hr < 9 || hr >= 17) return 1.0
                        return 0.0
                    }
                    property real u_is_rain: weatherScroll.previewWeatherMode === 2 ? 1.0 : (weatherScroll.previewWeatherMode !== 0 ? 0.0 : ((Waybar && Waybar.weatherDetails && Waybar.weatherDetails.isRain) ? 1.0 : 0.0))
                    property real u_is_snow: weatherScroll.previewWeatherMode === 3 ? 1.0 : (weatherScroll.previewWeatherMode !== 0 ? 0.0 : ((Waybar && Waybar.weatherDetails && Waybar.weatherDetails.isSnow) ? 1.0 : 0.0))
                    property real u_radius: weatherScroll.isM3 ? (Config ? Config.m3CardRadius : 16.0) : 0.0
                    property vector3d u_accent: Qt.vector3d(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b)
                    property vector3d u_surface: Config ? Qt.vector3d(Config.m3SurfaceContainer.r, Config.m3SurfaceContainer.g, Config.m3SurfaceContainer.b) : Qt.vector3d(0.11, 0.12, 0.15)
                    fragmentShader: "qrc:/shaders/qml/shaders/weather_sky.frag.qsb"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 18

                    // Иконка текущей погоды в тональной капсуле
                    Rectangle {
                        Layout.preferredWidth: 74
                        Layout.preferredHeight: 74
                        Layout.alignment: Qt.AlignVCenter
                        radius: weatherScroll.isM3 ? 22 : 0
                        color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.35)

                        Text {
                            anchors.centerIn: parent
                            readonly property string curDesc: weatherScroll.previewWeatherMode === 1 ? "Ясно" : (weatherScroll.previewWeatherMode === 2 ? "Дождь" : (weatherScroll.previewWeatherMode === 3 ? "Снег" : ((Waybar && Waybar.weatherDetails) ? Waybar.weatherDetails.desc : "")))
                            text: weatherScroll.toNerdWeatherIcon(
                                      weatherScroll.previewWeatherMode === 0 && Waybar && Waybar.weatherDetails ? Waybar.weatherDetails.icon : "",
                                      curDesc)
                            color: weatherScroll.weatherIconColor("", curDesc)
                            font.pixelSize: 36
                        }
                    }

                    // Температура, описание и дневной коридор
                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            spacing: 10
                            Text {
                                text: (Waybar && Waybar.weatherDetails && Waybar.weatherDetails.temp) ? Waybar.weatherDetails.temp : "+3°C"
                                color: "#ffffff"
                                font.pixelSize: 38
                                font.bold: true
                            }
                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: "↑ " + weatherScroll.todayMinMax.max
                                    color: "#e0e0e0"
                                    font.pixelSize: Config.fontSize - 1
                                    font.bold: true
                                }
                                Text {
                                    text: "↓ " + weatherScroll.todayMinMax.min
                                    color: "#999999"
                                    font.pixelSize: Config.fontSize - 1
                                }
                            }
                        }

                        Text {
                            text: (Waybar && Waybar.weatherDetails && Waybar.weatherDetails.desc) ? Waybar.weatherDetails.desc : "Пасмурно"
                            color: weatherScroll.priCol
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // 3 карточки погодных метрик справа (Ощущается, Ветер, Влажность)
                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: [
                                {
                                    icon: "󰔏",
                                    title: "Ощущается",
                                    val: (Waybar && Waybar.weatherDetails && Waybar.weatherDetails.feels) ? Waybar.weatherDetails.feels : "+1°C"
                                },
                                {
                                    icon: "󰖝",
                                    title: "Ветер",
                                    val: ((Waybar && Waybar.weatherDetails && Waybar.weatherDetails.wind) ? Waybar.weatherDetails.wind : "3.0") + " м/с"
                                },
                                {
                                    icon: "󰖎",
                                    title: "Влажность",
                                    val: ((Waybar && Waybar.weatherDetails && Waybar.weatherDetails.humidity) ? Waybar.weatherDetails.humidity : "80") + "%"
                                }
                            ]
                            delegate: Rectangle {
                                Layout.preferredWidth: 108
                                Layout.preferredHeight: 86
                                radius: weatherScroll.isM3 ? 14 : 0
                                color: Qt.rgba(0, 0, 0, 0.24)
                                border.width: 1
                                border.color: Qt.rgba(weatherScroll.outCol.r, weatherScroll.outCol.g, weatherScroll.outCol.b, 0.30)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: modelData.icon
                                        color: weatherScroll.priCol
                                        font.pixelSize: 16
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.val
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.title
                                        color: "#999999"
                                        font.pixelSize: Config.fontSize - 2
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ПЕРЕКЛЮЧАТЕЛЬ ПЕРИОДА ПРОГНОЗА
            SegmentedButton {
                Layout.fillWidth: true
                options: ["Сегодня (Почасовой)", "Завтра", "На неделю (7 дней)", "На месяц (28 дней)"]
                selectedIndex: weatherScroll.periodTab
                onSelected: (idx) => weatherScroll.periodTab = idx
            }

            // 1. СЕГОДНЯ / ЗАВТРА (Почасовой прогноз + кривая температуры Безье)
            GlassPanel {
                visible: weatherScroll.periodTab === 0 || weatherScroll.periodTab === 1
                Layout.fillWidth: true
                implicitHeight: 196

                Item {
                    id: hourlyContainer
                    anchors.fill: parent
                    anchors.margins: 12

                    readonly property int count: weatherScroll.activeHourlyModel ? weatherScroll.activeHourlyModel.length : 0
                    readonly property real gap: 6
                    readonly property real colW: count > 0 ? ((width - gap * (count - 1)) / count) : 80

                    // Плавно скользящая плашка наведения
                    Rectangle {
                        id: hourlyHoverPill
                        visible: hourlyContainer.count > 0
                        x: weatherScroll.lastHourIdx * (hourlyContainer.colW + hourlyContainer.gap)
                        y: 0
                        width: hourlyContainer.colW
                        height: parent.height
                        radius: weatherScroll.isM3 ? 12 : 0
                        color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.42)
                        opacity: weatherScroll.hoveredHourIdx >= 0 ? 1.0 : 0.0
                        Behavior on x { enabled: hourlyHoverPill.opacity > 0.05; NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                    }

                    // Плавная кривая Безье температурного хода по часам
                    Canvas {
                        id: hourlyCurveCanvas
                        anchors.left: parent.left
                        anchors.right: parent.right
                        y: 92
                        height: 44
                        z: 2
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var list = weatherScroll.activeHourlyModel
                            if (!list || list.length < 2) return

                            var vals = []
                            var mn = 999, mx = -999
                            for (var i = 0; i < list.length; ++i) {
                                var v = weatherScroll.parseTempNum(list[i].temp)
                                vals.push(v)
                                if (v < mn) mn = v
                                if (v > mx) mx = v
                            }
                            var span = Math.max(2, mx - mn)
                            var pts = []
                            for (var j = 0; j < list.length; ++j) {
                                var px = j * (hourlyContainer.colW + hourlyContainer.gap) + hourlyContainer.colW * 0.5
                                var norm = (vals[j] - mn) / span
                                var py = height - 10 - norm * (height - 22)
                                pts.push({ x: px, y: py })
                            }

                            var r = Math.round(weatherScroll.priCol.r * 255)
                            var g = Math.round(weatherScroll.priCol.g * 255)
                            var b = Math.round(weatherScroll.priCol.b * 255)

                            // Мягкая заливка под кривой
                            var grad = ctx.createLinearGradient(0, 0, 0, height)
                            grad.addColorStop(0.0, "rgba(" + r + "," + g + "," + b + ",0.24)")
                            grad.addColorStop(1.0, "rgba(" + r + "," + g + "," + b + ",0.0)")
                            ctx.beginPath()
                            ctx.moveTo(pts[0].x, pts[0].y)
                            for (var k = 0; k < pts.length - 1; ++k) {
                                var cx = (pts[k].x + pts[k + 1].x) * 0.5
                                var cy = (pts[k].y + pts[k + 1].y) * 0.5
                                ctx.quadraticCurveTo(pts[k].x, pts[k].y, cx, cy)
                            }
                            ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
                            ctx.lineTo(pts[pts.length - 1].x, height)
                            ctx.lineTo(pts[0].x, height)
                            ctx.closePath()
                            ctx.fillStyle = grad
                            ctx.fill()

                            // Линия графика
                            ctx.beginPath()
                            ctx.moveTo(pts[0].x, pts[0].y)
                            for (var m = 0; m < pts.length - 1; ++m) {
                                var mcx = (pts[m].x + pts[m + 1].x) * 0.5
                                var mcy = (pts[m].y + pts[m + 1].y) * 0.5
                                ctx.quadraticCurveTo(pts[m].x, pts[m].y, mcx, mcy)
                            }
                            ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y)
                            ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ",0.85)"
                            ctx.lineWidth = 2.0
                            ctx.stroke()

                            // Точки на каждом часе
                            for (var p = 0; p < pts.length; ++p) {
                                ctx.beginPath()
                                ctx.arc(pts[p].x, pts[p].y, 3.2, 0, Math.PI * 2)
                                ctx.fillStyle = "#ffffff"
                                ctx.fill()
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        spacing: hourlyContainer.gap
                        z: 3

                        Repeater {
                            model: weatherScroll.activeHourlyModel
                            delegate: Rectangle {
                                width: hourlyContainer.colW
                                height: hourlyContainer.height
                                radius: weatherScroll.isM3 ? 12 : 0
                                color: Qt.rgba(1, 1, 1, 0.025)
                                border.width: 1
                                border.color: Qt.rgba(weatherScroll.outCol.r, weatherScroll.outCol.g, weatherScroll.outCol.b, 0.22)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 2

                                    Text {
                                        text: modelData.time
                                        color: "#aaaaaa"
                                        font.pixelSize: Config.fontSize - 1
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: weatherScroll.toNerdWeatherIcon(modelData.icon, "")
                                        color: weatherScroll.weatherIconColor(modelData.icon, "")
                                        font.pixelSize: 22
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: 2
                                    }

                                    Text {
                                        text: modelData.temp
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize + 2
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Item { Layout.fillHeight: true }

                                    Row {
                                        spacing: 3
                                        Layout.alignment: Qt.AlignHCenter
                                        Text {
                                            text: "󰖗"
                                            color: weatherScroll.priCol
                                            font.pixelSize: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.pop
                                            color: "#cccccc"
                                            font.pixelSize: Config.fontSize - 2
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            weatherScroll.lastHourIdx = index
                                            weatherScroll.hoveredHourIdx = index
                                        } else if (weatherScroll.hoveredHourIdx === index) {
                                            weatherScroll.hoveredHourIdx = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. НА НЕДЕЛЮ (7 ДНЕЙ С ВИЗУАЛЬНОЙ ШКАЛОЙ ДИАПАЗОНА ТЕМПЕРАТУР)
            GlassPanel {
                visible: weatherScroll.periodTab === 2
                Layout.fillWidth: true
                implicitHeight: weekListArea.implicitHeight + 24

                Item {
                    id: weekListArea
                    anchors.fill: parent
                    anchors.margins: 12
                    readonly property int rowH: 40
                    readonly property int gap: 6
                    readonly property int rowCount: (Waybar && Waybar.weatherWeek) ? Waybar.weatherWeek.length : 0
                    implicitHeight: rowCount > 0 ? (rowCount * rowH + (rowCount - 1) * gap) : 280

                    Rectangle {
                        id: weekHoverPill
                        x: 0
                        y: weatherScroll.lastWeekIdx * (weekListArea.rowH + weekListArea.gap)
                        width: parent.width
                        height: weekListArea.rowH
                        radius: weatherScroll.isM3 ? 10 : 0
                        color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.42)
                        opacity: weatherScroll.hoveredWeekIdx >= 0 ? 1.0 : 0.0
                        Behavior on y { enabled: weekHoverPill.opacity > 0.05; NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                    }

                    Column {
                        anchors.fill: parent
                        spacing: weekListArea.gap

                        Repeater {
                            model: Waybar ? Waybar.weatherWeek : []
                            delegate: Rectangle {
                                width: weekListArea.width
                                height: weekListArea.rowH
                                radius: weatherScroll.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.025)
                                border.width: 1
                                border.color: Qt.rgba(weatherScroll.outCol.r, weatherScroll.outCol.g, weatherScroll.outCol.b, 0.20)

                                readonly property int tMin: weatherScroll.parseTempNum(modelData.min)
                                readonly property int tMax: weatherScroll.parseTempNum(modelData.max)
                                readonly property real barStartNorm: Math.max(0.0, Math.min(1.0, (tMin - weatherScroll.weekMinMax.min) / weatherScroll.weekMinMax.span))
                                readonly property real barEndNorm: Math.max(barStartNorm + 0.08, Math.min(1.0, (tMax - weatherScroll.weekMinMax.min) / weatherScroll.weekMinMax.span))

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    Text {
                                        text: modelData.day
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        font.bold: true
                                        Layout.preferredWidth: 115
                                    }

                                    Text {
                                        text: weatherScroll.toNerdWeatherIcon(modelData.icon, modelData.desc)
                                        color: weatherScroll.weatherIconColor(modelData.icon, modelData.desc)
                                        font.pixelSize: 18
                                        Layout.preferredWidth: 26
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: modelData.desc
                                        color: "#bbbbbb"
                                        font.pixelSize: Config.fontSize
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Row {
                                        spacing: 4
                                        Layout.preferredWidth: 56
                                        Text {
                                            text: "󰖗"
                                            color: weatherScroll.priCol
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.pop
                                            color: "#cccccc"
                                            font.pixelSize: Config.fontSize - 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        text: modelData.min
                                        color: "#999999"
                                        font.pixelSize: Config.fontSize
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 38
                                    }

                                    // Шкала диапазона температур дня относительно недели
                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 6
                                        radius: 3
                                        color: Qt.rgba(1, 1, 1, 0.10)

                                        Rectangle {
                                            x: parent.width * barStartNorm
                                            width: Math.max(8, parent.width * (barEndNorm - barStartNorm))
                                            height: parent.height
                                            radius: 3
                                            color: weatherScroll.priCol
                                        }
                                    }

                                    Text {
                                        text: modelData.max
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 42
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            weatherScroll.lastWeekIdx = index
                                            weatherScroll.hoveredWeekIdx = index
                                        } else if (weatherScroll.hoveredWeekIdx === index) {
                                            weatherScroll.hoveredWeekIdx = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. НА МЕСЯЦ (28 ДНЕЙ СЕТКА 7x4 С ШАПКОЙ ДНЕЙ НЕДЕЛИ)
            GlassPanel {
                visible: weatherScroll.periodTab === 3
                Layout.fillWidth: true
                implicitHeight: monthOuterCol.implicitHeight + 24

                ColumnLayout {
                    id: monthOuterCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Шапка дней недели
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ["ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС"]
                            delegate: Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: (index >= 5) ? weatherScroll.priCol : "#888888"
                                font.pixelSize: Config.fontSize - 1
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        id: monthGrid
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: Waybar ? Waybar.weatherMonth : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 68
                                radius: weatherScroll.isM3 ? 10 : 0
                                readonly property bool isHov: weatherScroll.hoveredMonthIdx === index
                                color: isHov
                                       ? Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.025)
                                border.width: 1
                                border.color: isHov
                                              ? Qt.rgba(weatherScroll.priCol.r, weatherScroll.priCol.g, weatherScroll.priCol.b, 0.50)
                                              : Qt.rgba(weatherScroll.outCol.r, weatherScroll.outCol.g, weatherScroll.outCol.b, 0.22)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        text: modelData.date
                                        color: "#aaaaaa"
                                        font.pixelSize: Config.fontSize - 2
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: weatherScroll.toNerdWeatherIcon(modelData.icon, "")
                                        color: weatherScroll.weatherIconColor(modelData.icon, "")
                                        font.pixelSize: 18
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Row {
                                        spacing: 5
                                        Layout.alignment: Qt.AlignHCenter
                                        Text {
                                            text: modelData.max
                                            color: "#ffffff"
                                            font.pixelSize: Config.fontSize - 1
                                            font.bold: true
                                        }
                                        Text {
                                            text: modelData.min
                                            color: "#777777"
                                            font.pixelSize: Config.fontSize - 1
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            weatherScroll.lastMonthIdx = index
                                            weatherScroll.hoveredMonthIdx = index
                                        } else if (weatherScroll.hoveredMonthIdx === index) {
                                            weatherScroll.hoveredMonthIdx = -1
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
