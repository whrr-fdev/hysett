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

    Item {
        width: weatherScroll.availableWidth
        implicitHeight: wCol.implicitHeight + 36

        ColumnLayout {
            id: wCol
            width: Math.min(parent.width - 36, 820)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰖙  Погода и метеорадар (Петрозаводск)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: "↺  Обновить"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.refreshWeather()
                }
            }

            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: 138
                clip: true

                Canvas {
                    id: weatherAnimCanvas
                    anchors.fill: parent
                    property real animT: 0.0
                    NumberAnimation on animT { from: 0; to: 628.3; duration: 60000; loops: Animation.Infinite; running: weatherScroll.visible }
                    onAnimTChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var det = Waybar ? Waybar.weatherDetails : ({})
                        var isRain = det.isRain === true
                        var isSnow = det.isSnow === true
                        var hr = new Date().getHours()
                        var isNight = (hr >= 20 || hr < 6)
                        var isTwilight = (!isNight && (hr < 9 || hr >= 17))

                        ctx.save()
                        // Многослойный атмосферный градиент неба
                        var sky = ctx.createLinearGradient(0, 0, 0, height)
                        if (isNight) {
                            sky.addColorStop(0.0, "rgba(7, 10, 24, 0.90)")
                            sky.addColorStop(0.6, "rgba(15, 22, 46, 0.70)")
                            sky.addColorStop(1.0, "rgba(28, 38, 72, 0.45)")
                        } else if (isTwilight) {
                            sky.addColorStop(0.0, "rgba(26, 22, 52, 0.80)")
                            sky.addColorStop(0.6, "rgba(88, 45, 72, 0.55)")
                            sky.addColorStop(1.0, "rgba(185, 92, 58, 0.40)")
                        } else {
                            sky.addColorStop(0.0, "rgba(24, 62, 128, 0.65)")
                            sky.addColorStop(0.6, "rgba(48, 98, 168, 0.42)")
                            sky.addColorStop(1.0, "rgba(85, 138, 198, 0.22)")
                        }
                        ctx.fillStyle = sky
                        ctx.fillRect(0, 0, width, height)

                        if (isNight) {
                            // Туманность Млечного пути и звезды с мягким свечением
                            var neb = ctx.createRadialGradient(width * 0.45, height * 0.3, 10, width * 0.45, height * 0.3, 260)
                            neb.addColorStop(0, "rgba(90, 125, 220, 0.10)")
                            neb.addColorStop(1, "rgba(90, 125, 220, 0.0)")
                            ctx.fillStyle = neb; ctx.fillRect(0, 0, width, height)

                            for (var st = 0; st < 55; ++st) {
                                var sx = (st * 131 + 19) % width
                                var sy = (st * 53 + 7) % (height * 0.88)
                                var tw = 0.20 + 0.80 * Math.pow(0.5 + 0.5 * Math.sin(animT * 6.0 + st * 2.1), 2.0)
                                var sr = (st % 7 === 0) ? 1.8 : ((st % 3 === 0) ? 1.2 : 0.8)
                                if (st % 7 === 0) {
                                    var sg = ctx.createRadialGradient(sx, sy, 0, sx, sy, 7)
                                    sg.addColorStop(0, "rgba(220, 235, 255, " + (tw * 0.55).toFixed(2) + ")")
                                    sg.addColorStop(1, "rgba(220, 235, 255, 0.0)")
                                    ctx.fillStyle = sg; ctx.fillRect(sx - 7, sy - 7, 14, 14)
                                }
                                ctx.fillStyle = "rgba(245, 248, 255, " + (tw * 0.92).toFixed(2) + ")"
                                ctx.beginPath(); ctx.arc(sx, sy, sr, 0, Math.PI * 2); ctx.fill()
                            }

                            // Объемная Луна с атмосферным гало и текстурой морей (слева от текста!)
                            var mx = width * 0.62, my = 44
                            var halo = ctx.createRadialGradient(mx, my, 12, mx, my, 78)
                            halo.addColorStop(0.0, "rgba(210, 228, 255, 0.32)")
                            halo.addColorStop(0.4, "rgba(160, 195, 255, 0.10)")
                            halo.addColorStop(1.0, "rgba(160, 195, 255, 0.0)")
                            ctx.fillStyle = halo; ctx.beginPath(); ctx.arc(mx, my, 78, 0, Math.PI * 2); ctx.fill()

                            var mBody = ctx.createRadialGradient(mx - 5, my - 5, 2, mx, my, 18)
                            mBody.addColorStop(0.0, "rgba(255, 255, 250, 0.96)")
                            mBody.addColorStop(0.75, "rgba(215, 226, 245, 0.92)")
                            mBody.addColorStop(1.0, "rgba(175, 192, 222, 0.85)")
                            ctx.fillStyle = mBody; ctx.beginPath(); ctx.arc(mx, my, 18, 0, Math.PI * 2); ctx.fill()

                            // Мягкие лунные моря (кратеры)
                            ctx.fillStyle = "rgba(140, 158, 190, 0.28)"
                            ctx.beginPath(); ctx.arc(mx - 5, my - 3, 5, 0, Math.PI * 2); ctx.fill()
                            ctx.beginPath(); ctx.arc(mx + 6, my + 4, 4, 0, Math.PI * 2); ctx.fill()
                            ctx.beginPath(); ctx.arc(mx + 2, my - 7, 3, 0, Math.PI * 2); ctx.fill()
                        } else {
                            // Объемное Солнце с многослойной короной
                            var sunX = width * 0.62, sunY = isTwilight ? 64 : 42
                            var sGlow = ctx.createRadialGradient(sunX, sunY, 4, sunX, sunY, 95)
                            sGlow.addColorStop(0.0, isTwilight ? "rgba(255, 200, 130, 0.65)" : "rgba(255, 248, 210, 0.60)")
                            sGlow.addColorStop(0.35, isTwilight ? "rgba(255, 130, 80, 0.24)" : "rgba(255, 220, 140, 0.20)")
                            sGlow.addColorStop(1.0, "rgba(255, 180, 100, 0.0)")
                            ctx.fillStyle = sGlow; ctx.beginPath(); ctx.arc(sunX, sunY, 95, 0, Math.PI * 2); ctx.fill()

                            ctx.fillStyle = "rgba(255, 252, 235, 0.95)"
                            ctx.beginPath(); ctx.arc(sunX, sunY, 15, 0, Math.PI * 2); ctx.fill()
                        }

                        // Объемные мягкие облака (через размытые радиальные градиенты, без резких кругов!)
                        for (var c = 0; c < 6; ++c) {
                            var cx = ((c * 170 + animT * (14 + (c % 3) * 5)) % (width + 260)) - 130
                            var cy = 32 + (c % 3) * 28
                            var cr = 65 + (c % 2) * 25
                            var cg = ctx.createRadialGradient(cx, cy, 4, cx, cy, cr)
                            var cAlpha = isNight ? 0.11 : 0.16
                            cg.addColorStop(0.0, "rgba(220, 230, 248, " + cAlpha + ")")
                            cg.addColorStop(0.55, "rgba(190, 205, 230, " + (cAlpha * 0.45).toFixed(2) + ")")
                            cg.addColorStop(1.0, "rgba(190, 205, 230, 0.0)")
                            ctx.fillStyle = cg
                            ctx.save()
                            ctx.scale(1.8, 0.65)
                            ctx.beginPath(); ctx.arc(cx / 1.8, cy / 0.65, cr, 0, Math.PI * 2); ctx.fill()
                            ctx.restore()
                        }

                        // Реалистичные осадки с параллаксом (3 слоя глубины)
                        if (isRain) {
                            for (var i = 0; i < 48; ++i) {
                                var depth = 0.4 + (i % 3) * 0.3
                                var rx = ((i * 67 + animT * 95 * depth) % (width + 40)) - 20
                                var ry = ((i * 43 + animT * 480 * depth) % (height + 24)) - 12
                                var rGrad = ctx.createLinearGradient(rx, ry, rx - 5 * depth, ry + 18 * depth)
                                rGrad.addColorStop(0, "rgba(160, 210, 255, 0.0)")
                                rGrad.addColorStop(1, "rgba(160, 210, 255, " + (0.45 * depth).toFixed(2) + ")")
                                ctx.strokeStyle = rGrad
                                ctx.lineWidth = 1.2 * depth
                                ctx.beginPath(); ctx.moveTo(rx, ry); ctx.lineTo(rx - 5 * depth, ry + 18 * depth); ctx.stroke()
                            }
                        } else if (isSnow) {
                            for (var k = 0; k < 40; ++k) {
                                var sDepth = 0.4 + (k % 3) * 0.3
                                var kx = ((k * 73 + Math.sin(animT * 2.5 + k) * 18) % width)
                                var ky = ((k * 51 + animT * 115 * sDepth) % height)
                                var rad = 2.8 * sDepth
                                var fg = ctx.createRadialGradient(kx, ky, 0, kx, ky, rad * 1.8)
                                fg.addColorStop(0, "rgba(255, 255, 255, " + (0.75 * sDepth).toFixed(2) + ")")
                                fg.addColorStop(1, "rgba(255, 255, 255, 0.0)")
                                ctx.fillStyle = fg
                                ctx.beginPath(); ctx.arc(kx, ky, rad * 1.8, 0, Math.PI * 2); ctx.fill()
                            }
                        }
                        ctx.restore()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 20

                    Text {
                        text: (Waybar && Waybar.weatherDetails.icon) ? Waybar.weatherDetails.icon : "☁️"
                        font.pixelSize: 48
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: (Waybar && Waybar.weatherDetails.temp) ? Waybar.weatherDetails.temp : "+3°C"
                            color: "#ffffff"
                            font.pixelSize: 32
                            font.bold: true
                        }
                        Text {
                            text: (Waybar && Waybar.weatherDetails.desc) ? Waybar.weatherDetails.desc : "Пасмурно"
                            color: Config ? Config.m3Primary : "#a8c7fa"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        spacing: 5
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: "Ощущается как: " + ((Waybar && Waybar.weatherDetails.feels) ? Waybar.weatherDetails.feels : "+1°C")
                            color: "#ececec"; font.pixelSize: Config.fontSize
                        }
                        Text {
                            text: "Ветер: " + ((Waybar && Waybar.weatherDetails.wind) ? Waybar.weatherDetails.wind : "3.0") + " м/с"
                            color: "#cccccc"; font.pixelSize: Config.fontSize
                        }
                        Text {
                            text: "Влажность: " + ((Waybar && Waybar.weatherDetails.humidity) ? Waybar.weatherDetails.humidity : "80") + "%"
                            color: "#cccccc"; font.pixelSize: Config.fontSize
                        }
                    }
                }
            }

            SegmentedButton {
                Layout.fillWidth: true
                options: ["Сегодня (Почасовой)", "Завтра", "На неделю (7 дней)", "На месяц (28 дней)"]
                selectedIndex: weatherScroll.periodTab
                onSelected: (idx) => weatherScroll.periodTab = idx
            }

            GlassPanel {
                visible: weatherScroll.periodTab === 0 || weatherScroll.periodTab === 1
                Layout.fillWidth: true
                implicitHeight: 118

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Repeater {
                        model: weatherScroll.periodTab === 0 ? (Waybar ? Waybar.weatherHourly : []) : (Waybar ? Waybar.weatherTomorrow : [])
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: (Theme && Theme.isRounded) ? 10 : 0
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 4
                                Text { text: modelData.time; color: "#aaaaaa"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                Text { text: modelData.icon; font.pixelSize: 20; Layout.alignment: Qt.AlignHCenter }
                                Text { text: modelData.temp; color: "#ffffff"; font.pixelSize: 12; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "💧" + modelData.pop; color: "#7ab8ff"; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                visible: weatherScroll.periodTab === 2
                Layout.fillWidth: true
                implicitHeight: weekCol.implicitHeight + 20
                ColumnLayout {
                    id: weekCol; anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Repeater {
                        model: Waybar ? Waybar.weatherWeek : []
                        delegate: Rectangle {
                            Layout.fillWidth: true; implicitHeight: 36
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                                Text { text: modelData.day; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 110 }
                                Text { text: modelData.icon; font.pixelSize: 18; Layout.preferredWidth: 28 }
                                Text { text: modelData.desc; color: "#bbbbbb"; font.pixelSize: 11; Layout.fillWidth: true }
                                Text { text: "💧 " + modelData.pop; color: "#7ab8ff"; font.pixelSize: 10; Layout.preferredWidth: 54 }
                                Text { text: "мин " + modelData.min; color: "#888888"; font.pixelSize: 11; Layout.preferredWidth: 64 }
                                Text { text: "макс " + modelData.max; color: "#ffffff"; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 68; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                }
            }

            GlassPanel {
                visible: weatherScroll.periodTab === 3
                Layout.fillWidth: true
                implicitHeight: monthGrid.implicitHeight + 24
                GridLayout {
                    id: monthGrid; anchors.fill: parent; anchors.margins: 12; columns: 7; columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: Waybar ? Waybar.weatherMonth : []
                        delegate: Rectangle {
                            Layout.fillWidth: true; implicitHeight: 64
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                Text { text: modelData.day + " " + modelData.date; color: "#999999"; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                                Text { text: modelData.icon; font.pixelSize: 16; Layout.alignment: Qt.AlignHCenter }
                                Row {
                                    spacing: 4; Layout.alignment: Qt.AlignHCenter
                                    Text { text: modelData.max; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    Text { text: modelData.min; color: "#777777"; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
