import QtQuick
import QtQuick.Controls
import HySett

Switch {
    id: control
    implicitWidth: 30
    implicitHeight: 16
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    indicator: Rectangle {
        implicitWidth: 30
        implicitHeight: 16
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: (Theme && Theme.isRounded) ? height / 2 : 0
        color: control.checked
               ? (Config ? Config.m3Primary : "#a8c7fa")
               : Qt.rgba(1, 1, 1, 0.10)
        border.color: control.checked
                      ? (Config ? Config.m3Primary : "#a8c7fa")
                      : Qt.rgba(1, 1, 1, 0.28)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on radius { NumberAnimation { duration: 140 } }

        Rectangle {
            width: control.checked ? 10 : 8
            height: width
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? (parent.width - width - 3) : 3
            radius: (Theme && Theme.isRounded) ? width / 2 : 0
            color: control.checked
                   ? (Config ? Config.accentTextColor : "#000000")
                   : "#cccccc"

            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on radius { NumberAnimation { duration: 140 } }
        }
    }

    contentItem: Item {}
}
