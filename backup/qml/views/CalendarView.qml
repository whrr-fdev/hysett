import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: calViewRoot
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    ColumnLayout {
        width: Math.min(parent.width - 48, 560)
        anchors.centerIn: parent
        spacing: 14

        GlassPanel {
            Layout.fillWidth: true
            implicitHeight: 84
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    id: bigClockLbl
                    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                    color: "#ffffff"; font.pixelSize: 32; font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    Timer { interval: 1000; running: calViewRoot.visible; repeat: true; onTriggered: bigClockLbl.text = Qt.formatDateTime(new Date(), "hh:mm:ss") }
                }
                Text {
                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                    color: "#aaaaaa"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        GlassPanel {
            Layout.fillWidth: true
            implicitHeight: calInnerCol.implicitHeight + 28
            ColumnLayout {
                id: calInnerCol
                anchors.fill: parent; anchors.margins: 14; spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    StyledButton { text: "‹"; isIconOnly: true; onClicked: { if (calViewRoot.calMonth === 0) { calViewRoot.calMonth = 11; calViewRoot.calYear-- } else calViewRoot.calMonth-- } }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        text: ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"][calViewRoot.calMonth] + " " + calViewRoot.calYear
                        color: "#ffffff"; font.pixelSize: 15; font.bold: true
                    }
                    StyledButton { text: "›"; isIconOnly: true; onClicked: { if (calViewRoot.calMonth === 11) { calViewRoot.calMonth = 0; calViewRoot.calYear++ } else calViewRoot.calMonth++ } }
                }
                GridLayout {
                    Layout.fillWidth: true; columns: 7; columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                        delegate: Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: "#888888"; font.pixelSize: 11; font.bold: true }
                    }
                    Repeater {
                        model: 42
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34
                            property var cellInfo: {
                                var firstDay = (new Date(calViewRoot.calYear, calViewRoot.calMonth, 1).getDay() + 6) % 7
                                var daysInM = new Date(calViewRoot.calYear, calViewRoot.calMonth + 1, 0).getDate()
                                var dNum = index - firstDay + 1
                                var valid = (dNum >= 1 && dNum <= daysInM)
                                var now = new Date()
                                var isToday = valid && (dNum === now.getDate() && calViewRoot.calMonth === now.getMonth() && calViewRoot.calYear === now.getFullYear())
                                return { day: valid ? dNum : "", valid: valid, today: isToday }
                            }
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: cellInfo.today ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                            border.color: cellInfo.today ? "transparent" : (cellInfo.valid ? Qt.rgba(1,1,1,0.10) : "transparent")
                            border.width: 1
                            Text { anchors.centerIn: parent; text: parent.cellInfo.day; color: parent.cellInfo.today ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"; font.pixelSize: 12; font.bold: parent.cellInfo.today }
                        }
                    }
                }
            }
        }
    }
}
