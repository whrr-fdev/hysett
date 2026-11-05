import QtQuick
import QtQuick.Controls
import HySett

Slider {
    id: control
    implicitHeight: 26

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 180
        implicitHeight: 10
        width: control.availableWidth
        height: control.hovered || control.pressed ? 12 : 9
        Behavior on height { NumberAnimation { duration: 130 } }

        Rectangle {
            anchors.fill: parent
            radius: (Theme && Theme.isRounded) ? height / 2 : 2
            color: Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.55) : Qt.rgba(1, 1, 1, 0.12)
        }
        Rectangle {
            width: Math.max(height, control.visualPosition * parent.width)
            height: parent.height
            radius: (Theme && Theme.isRounded) ? height / 2 : 2
            color: Config ? Config.m3Primary : "#a8c7fa"
            visible: control.visualPosition > 0.005
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: control.pressed ? 6 : 8
        implicitHeight: control.pressed ? 24 : 20
        radius: (Theme && Theme.isRounded) ? width / 2 : 1
        color: Config ? Config.m3Primary : "#a8c7fa"
        border.color: Config ? Config.m3Surface : "#111318"
        border.width: 2
    }
}
