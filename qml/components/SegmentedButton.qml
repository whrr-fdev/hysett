import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

RowLayout {
    id: control
    property var options: []
    property int selectedIndex: 0
    signal selected(int index)
    readonly property bool isM3: Theme && Theme.isRounded

    spacing: isM3 ? 2 : 2

    Repeater {
        model: control.options
        Button {
            id: btn
            text: modelData
            flat: true
            Layout.fillWidth: true
            implicitHeight: 26
            readonly property bool isSel: control.selectedIndex === index
            readonly property bool isFirst: index === 0
            readonly property bool isLast: index === control.options.length - 1
            readonly property real outerR: control.isM3 ? (Config ? Math.min(height / 2, Config.m3ControlRadius + 3) : 13) : 0
            readonly property real innerR: control.isM3 ? 4 : 0

            contentItem: Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    visible: control.isM3 && btn.isSel
                    text: "✓"
                    color: Config ? Config.accentTextColor : "#000000"
                    font.pixelSize: Config ? Config.fontSize - 1 : 10
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Config ? (Config.language, Config.trAuto(btn.text)) : btn.text
                    color: btn.isSel
                           ? (Config ? Config.accentTextColor : "#000000")
                           : (control.isM3 && Config ? Config.m3OnPrimaryContainer : "#d0d0d0")
                    font.pixelSize: Config ? Config.fontSize : 11
                    font.bold: btn.isSel
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
            }

            background: Item {
                Rectangle {
                    id: mainSegBg
                    anchors.fill: parent
                    radius: btn.isSel ? btn.outerR : (btn.isFirst || btn.isLast ? btn.outerR : btn.innerR)
                    color: btn.isSel
                           ? (Config ? Config.m3Primary : "#ffffff")
                           : (btn.hovered
                              ? (control.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.12))
                              : (control.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.05)))
                    Behavior on color { ColorAnimation { duration: 130 } }

                    // Выпрямление внутренних углов для крайних кнопок в группе M3
                    Rectangle {
                        visible: control.isM3 && !btn.isSel && btn.isFirst && control.options.length > 1
                        anchors.right: parent.right
                        width: Math.min(parent.width * 0.5, btn.outerR)
                        height: parent.height
                        radius: btn.innerR
                        color: parent.color
                    }
                    Rectangle {
                        visible: control.isM3 && !btn.isSel && btn.isLast && control.options.length > 1
                        anchors.left: parent.left
                        width: Math.min(parent.width * 0.5, btn.outerR)
                        height: parent.height
                        radius: btn.innerR
                        color: parent.color
                    }
                }
            }

            onClicked: {
                control.selectedIndex = index
                control.selected(index)
            }
        }
    }
}
