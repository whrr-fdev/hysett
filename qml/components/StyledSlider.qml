import QtQuick
import QtQuick.Controls
import HySett

Slider {
    id: control
    implicitWidth: 160
    implicitHeight: 18
    hoverEnabled: true

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 160
        implicitHeight: 4
        width: control.availableWidth
        height: implicitHeight
        radius: (Theme && Theme.isRounded) ? 2 : 0
        color: Qt.rgba(1, 1, 1, 0.14)

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Config ? Config.m3Primary : "#a8c7fa"
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 12
        implicitHeight: 12
        radius: (Theme && Theme.isRounded) ? 6 : 0
        color: control.pressed ? "#ffffff" : (Config ? Config.m3Primary : "#ffffff")
        border.color: Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        scale: control.pressed || control.hovered ? 1.12 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
        Behavior on radius { NumberAnimation { duration: 140 } }
    }
}
