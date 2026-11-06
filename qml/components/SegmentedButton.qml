import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

RowLayout {
    id: control
    property var options: []
    property int selectedIndex: 0
    signal selected(int index)

    spacing: (Theme && Theme.isRounded) ? 3 : 2

    Repeater {
        model: control.options
        Button {
            id: btn
            text: modelData
            flat: true
            Layout.fillWidth: true
            implicitHeight: 24
            readonly property bool isSel: control.selectedIndex === index
            readonly property bool isM3: Theme && Theme.isRounded

            contentItem: Text {
                text: Config ? (Config.language, Config.trAuto(btn.text)) : btn.text
                color: btn.isSel ? (Config ? Config.accentTextColor : "#000000") : (btn.isM3 && Config ? Config.m3OnPrimaryContainer : "#d0d0d0")
                font.pixelSize: Config ? Config.fontSize : 11
                font.bold: btn.isSel
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 110 } }
            }

            background: Rectangle {
                radius: btn.isM3 ? (Config ? Math.min(height / 2, Config.m3ControlRadius) : 10) : 0
                color: btn.isSel
                       ? (Config ? Config.m3Primary : "#ffffff")
                       : (btn.hovered
                          ? (btn.isM3 && Config ? Qt.rgba(Config.m3PrimaryContainer.r, Config.m3PrimaryContainer.g, Config.m3PrimaryContainer.b, 0.55) : Qt.rgba(1, 1, 1, 0.12))
                          : (btn.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.36) : Qt.rgba(1, 1, 1, 0.05)))
                border.color: btn.isM3 && Config && !btn.isSel
                              ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, Config.m3OutlineOpacity * 0.85)
                              : "transparent"
                border.width: (btn.isM3 && Config && !btn.isSel) ? Config.m3OutlineWidth : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on radius { NumberAnimation { duration: 150 } }
            }

            onClicked: {
                control.selectedIndex = index
                control.selected(index)
            }
        }
    }
}
