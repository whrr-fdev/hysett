import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Item {
    id: control
    property var options: []
    property int selectedIndex: 0
    signal selected(int index)
    readonly property bool isM3: Theme && Theme.isRounded

    implicitHeight: 28
    implicitWidth: 220
    Layout.fillWidth: true

    Rectangle {
        id: capsuleBg
        anchors.fill: parent
        radius: control.isM3 ? height / 2 : 0
        color: control.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: control.isM3 && Config
                      ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.45)
                      : Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on radius { NumberAnimation { duration: 150 } }

        // Плавно скользящая капсула выбранного сегмента внутри общей таблетки
        Rectangle {
            id: activeSegPill
            readonly property int cnt: Math.max(1, control.options.length)
            readonly property real segW: (parent.width - 2) / cnt
            visible: control.options.length > 0
            x: 1 + Math.max(0, Math.min(cnt - 1, control.selectedIndex)) * segW
            y: 1
            width: segW
            height: parent.height - 2
            radius: control.isM3 ? height / 2 : 0
            color: Config ? Config.m3Primary : "#ffffff"

            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            Repeater {
                model: control.options
                Item {
                    id: segItem
                    width: (capsuleBg.width - 2) / Math.max(1, control.options.length)
                    height: capsuleBg.height - 2
                    readonly property bool isSel: control.selectedIndex === index
                    readonly property bool hov: segMa.containsMouse

                    // Тонкий вертикальный разделитель между невыбранными сегментами
                    Rectangle {
                        visible: index > 0 && !segItem.isSel && (control.selectedIndex !== index - 1)
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height * 0.55
                        color: control.isM3 && Config
                               ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.38)
                               : Qt.rgba(1, 1, 1, 0.14)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: control.isM3 ? height / 2 : 0
                        color: (!segItem.isSel && segItem.hov)
                               ? (control.isM3 && Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.08))
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            visible: control.isM3 && segItem.isSel
                            text: "✓"
                            color: Config ? Config.accentTextColor : "#000000"
                            font.pixelSize: Config ? Config.fontSize - 1 : 10
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: Config ? (Config.language, Config.trAuto(modelData)) : modelData
                            color: segItem.isSel
                                   ? (Config ? Config.accentTextColor : "#000000")
                                   : (control.isM3 && Config ? Config.m3OnPrimaryContainer : "#d0d0d0")
                            font.pixelSize: Config ? Config.fontSize : 11
                            font.bold: segItem.isSel
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            control.selectedIndex = index
                            control.selected(index)
                        }
                    }
                }
            }
        }
    }
}
