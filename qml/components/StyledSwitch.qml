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
    implicitHeight: 22
    implicitWidth: 36
    Layout.alignment: Qt.AlignVCenter
    readonly property bool isM3: Theme && Theme.isRounded

    indicator: Rectangle {
        implicitWidth: 36
        implicitHeight: 20
        x: 0
        y: Math.round((control.height - height) / 2)
        radius: control.isM3 ? height / 2 : 0
        color: control.inverted
               ? (control.checked ? "#15171e" : Qt.rgba(0, 0, 0, 0.18))
               : (control.checked
                  ? (Config ? Config.m3Primary : "#a8c7fa")
                  : (control.isM3 && Config ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.85) : Qt.rgba(1, 1, 1, 0.08)))
        border.color: control.checked
                      ? "transparent"
                      : (control.inverted ? Qt.rgba(0, 0, 0, 0.45) : (Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.75) : Qt.rgba(1, 1, 1, 0.35)))
        border.width: control.checked ? 0 : 1.5
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: control.down ? 17 : (control.checked ? 14 : 10)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? (parent.width - width - 3) : 5
            radius: control.isM3 ? height / 2 : 0
            color: control.inverted
                   ? (control.checked ? "#ffffff" : "#22252e")
                   : (control.checked
                      ? (Config ? Config.accentTextColor : "#0a1428")
                      : (Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.75) : "#b8bece"))
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on width { NumberAnimation { duration: 130 } }
        }
    }
}
