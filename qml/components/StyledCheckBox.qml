import QtQuick
import QtQuick.Controls
import HySett

CheckBox {
    id: control
    font.pixelSize: Config ? Config.fontSize : 11
    readonly property bool isM3: Theme && Theme.isRounded

    scale: control.hovered ? 1.03 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    indicator: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: control.isM3 ? (Config ? Math.min(6, Math.round(Config.m3ControlRadius * 0.45)) : 5) : 0
        color: control.checked
               ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
               : (control.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: control.checked || control.hovered
                      ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
                      : (control.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, Math.max(0.35, Config.m3OutlineOpacity)) : Qt.rgba(1, 1, 1, 0.28))
        border.width: control.isM3 ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on radius { NumberAnimation { duration: 150 } }
    }

    contentItem: Text {
        text: Config ? (Config.language, Config.trAuto(control.text)) : control.text
        font: control.font
        color: control.checked ? "#ffffff" : "#cccccc"
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + 8
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
