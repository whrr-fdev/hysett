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
    onVisibleChanged: if (visible && Waybar && Waybar.weatherHourly.length === 0) Waybar.refreshWeather()

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
                    text: "🌐  Gismeteo"
                    implicitHeight: 24
                    onClicked: if (Waybar) Waybar.runCommand("xdg-open https://www.gismeteo.ru/")
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
                    property real u_is_rain: (Waybar && Waybar.weatherDetails && Waybar.weatherDetails.isRain) ? 1.0 : 0.0
                    property real u_is_snow: (Waybar && Waybar.weatherDetails && Waybar.weatherDetails.isSnow) ? 1.0 : 0.0
                    property real u_radius: (Theme && Theme.isRounded) ? 14.0 : 0.0
                    fragmentShader: "qrc:/shaders/qml/shaders/weather_sky.frag.qsb"
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
