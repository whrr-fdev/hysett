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

    spacing: isM3 ? 3 : 2

    Repeater {
        model: control.options
        Button {
            id: btn
            text: modelData
            flat: true
            Layout.fillWidth: true
            implicitHeight: 28
            readonly property bool isSel: control.selectedIndex === index
            readonly property bool isFirst: index === 0
            readonly property bool isLast: index === control.options.length - 1
            readonly property real outerR: control.isM3 ? height / 2 : 0
            readonly property real innerR: control.isM3 ? 5 : 0

            contentItem: Row {
                anchors.centerIn: parent
                spacing: 4
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
                readonly property color segColor: btn.isSel
                       ? (Config ? Config.m3Primary : "#ffffff")
                       : (btn.hovered
                          ? (control.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.12))
                          : (control.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.06)))

                // Основная форма: внешние края колбасы круглые (outerR), внутренние стыки с малым скруглением (innerR)
                Rectangle {
                    anchors.fill: parent
                    radius: (btn.isFirst || btn.isLast) ? btn.outerR : btn.innerR
                    color: parent.segColor
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                // Малое скругление правого края у первой кнопки (и для активной, и для неактивной)
                Rectangle {
                    visible: control.isM3 && btn.isFirst && !btn.isLast
                    anchors.right: parent.right
                    width: Math.min(parent.width * 0.55, btn.outerR + 2)
                    height: parent.height
                    radius: btn.innerR
                    color: parent.segColor
                    Behavior on color { ColorAnimation { duration: 130 } }
                }

                // Малое скругление левого края у последней кнопки (и для активной, и для неактивной)
                Rectangle {
                    visible: control.isM3 && btn.isLast && !btn.isFirst
                    anchors.left: parent.left
                    width: Math.min(parent.width * 0.55, btn.outerR + 2)
                    height: parent.height
                    radius: btn.innerR
                    color: parent.segColor
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
            }

            onClicked: {
                control.selectedIndex = index
                control.selected(index)
            }
        }
    }
}
