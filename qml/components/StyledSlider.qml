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
    implicitHeight: 24
    Layout.alignment: Qt.AlignVCenter
    readonly property bool isM3: Theme && Theme.isRounded

    background: Item {
        x: control.leftPadding
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: 180
        implicitHeight: control.isM3 ? 14 : 10
        width: control.availableWidth
        height: control.isM3 ? (control.hovered || control.pressed ? 16 : 14) : (control.hovered || control.pressed ? 12 : 9)
        Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutQuint } }

        readonly property real handleX: control.visualPosition * (width - 6) + 3
        readonly property real gapHalf: control.isM3 ? 6 : 0

        // Активная левая часть трека (M3 Primary со скруглением слева и прямым срезом у бегунка)
        Rectangle {
            x: 0
            y: 0
            width: Math.max(0, parent.handleX - parent.gapHalf)
            height: parent.height
            radius: control.isM3 ? height / 2 : 0
            color: Config ? Config.m3Primary : "#a8c7fa"
            visible: width > 2

            Rectangle {
                visible: control.isM3 && parent.width > parent.height
                anchors.right: parent.right
                width: Math.min(6, parent.width * 0.5)
                height: parent.height
                radius: 2
                color: parent.color
            }
        }

        // Неактивная правая часть трека (M3 SecondaryContainer с разрывом вокруг бегунка)
        Rectangle {
            x: control.isM3 ? Math.min(parent.width, parent.handleX + parent.gapHalf) : 0
            y: 0
            width: control.isM3 ? Math.max(0, parent.width - x) : parent.width
            height: parent.height
            z: control.isM3 ? 1 : -1
            radius: control.isM3 ? height / 2 : 0
            color: Config
                   ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, control.isM3 ? 0.78 : 0.45)
                   : Qt.rgba(1, 1, 1, 0.14)
            visible: width > 2

            Rectangle {
                visible: control.isM3 && parent.width > parent.height
                anchors.left: parent.left
                width: Math.min(6, parent.width * 0.5)
                height: parent.height
                radius: 2
                color: parent.color
            }

            // Точка-индикатор конца трека M3
            Rectangle {
                visible: control.isM3 && parent.width > 12
                width: 4; height: 4; radius: 2
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                color: Config ? Config.m3Primary : "#a8c7fa"
            }
        }
    }

    // Вертикальный бегунок-палочка M3 Expressive
    handle: Rectangle {
        x: Math.round(control.leftPadding + control.visualPosition * (control.availableWidth - width))
        y: Math.round(control.topPadding + (control.availableHeight - height) / 2)
        implicitWidth: control.isM3 ? (control.pressed ? 3 : 4) : (control.pressed ? 6 : 8)
        implicitHeight: control.isM3 ? (control.pressed ? 24 : 22) : (control.pressed ? 22 : 18)
        radius: control.isM3 ? width / 2 : 0
        color: Config ? Config.m3Primary : "#a8c7fa"
        Behavior on implicitWidth { NumberAnimation { duration: 100 } }
        Behavior on implicitHeight { NumberAnimation { duration: 100 } }
    }
}
