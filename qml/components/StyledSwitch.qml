import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Switch {
    id: control
    property bool inverted: false
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 20
    implicitWidth: 30
    Layout.alignment: Qt.AlignVCenter

    indicator: Rectangle {
        implicitWidth: 30
        implicitHeight: 16
        x: 0
        y: Math.round((control.height - height) / 2)
        radius: (Theme && Theme.isRounded) ? 8 : 0
        color: control.inverted
               ? (control.checked ? "#15171e" : Qt.rgba(0, 0, 0, 0.15))
               : (control.checked ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.08))
        border.color: control.checked
                      ? "transparent"
                      : (control.inverted ? Qt.rgba(0, 0, 0, 0.45) : (control.hovered ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.25)))
        border.width: control.checked ? 0 : 1.5
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: control.down ? 18 : (control.checked ? 10 : 8)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? (parent.width - width - 3) : 4
            radius: (Theme && Theme.isRounded) ? height / 2 : 0
            color: control.inverted
                   ? (control.checked ? "#ffffff" : "#22252e")
                   : (control.checked ? (Config ? Config.accentTextColor : "#0a1428") : "#b8bece")
            Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutBack } }
            Behavior on width { NumberAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.bold: true
                color: control.inverted ? "#15171e" : (Config ? Config.m3Primary : "#a8c7fa")
                opacity: control.checked ? 1.0 : 0.0
            }
        }
    }
}
