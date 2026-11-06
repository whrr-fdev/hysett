import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Slider {
    id: control
    padding: 0
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 20
    Layout.alignment: Qt.AlignVCenter

    background: Item {
        x: control.leftPadding
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: 180
        implicitHeight: 10
        width: control.availableWidth
        height: control.hovered || control.pressed ? 12 : 9
        Behavior on height { NumberAnimation { duration: 130 } }

        Rectangle {
            anchors.fill: parent
            radius: (Theme && Theme.isRounded) ? height / 2 : 0
            color: Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.55) : Qt.rgba(1, 1, 1, 0.12)
        }
        Rectangle {
            width: Math.max(height, control.visualPosition * parent.width)
            height: parent.height
            radius: (Theme && Theme.isRounded) ? height / 2 : 0
            color: Config ? Config.m3Primary : "#a8c7fa"
            visible: control.visualPosition > 0.005
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: control.pressed ? 6 : 8
        implicitHeight: control.pressed ? 22 : 18
        radius: (Theme && Theme.isRounded) ? width / 2 : 0
        color: Config ? Config.m3Primary : "#a8c7fa"
        border.color: Config ? Config.m3Surface : "#111318"
        border.width: 2
    }
}
