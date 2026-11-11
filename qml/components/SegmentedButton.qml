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
    readonly property real gap: isM3 ? 3 : 2
    readonly property int count: options ? options.length : 0
    readonly property real segW: count > 0 ? (width - gap * Math.max(0, count - 1)) / count : width
    readonly property real outerR: isM3 ? height / 2 : 0
    readonly property real innerR: isM3 ? 5 : 0

    property bool isHovering: false
    property int lastHoveredIdx: 0

    Layout.fillWidth: true
    implicitHeight: 28
    implicitWidth: 260

    Timer {
        id: segHoverHold
        interval: 45
        onTriggered: control.isHovering = false
    }

    // Слой 1: Фоны сегментов колбаски
    Row {
        z: 1
        anchors.fill: parent
        spacing: control.gap

        Repeater {
            model: control.count
            delegate: Rectangle {
                width: control.segW
                height: control.height
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === control.count - 1
                topLeftRadius: isFirst ? control.outerR : control.innerR
                bottomLeftRadius: isFirst ? control.outerR : control.innerR
                topRightRadius: isLast ? control.outerR : control.innerR
                bottomRightRadius: isLast ? control.outerR : control.innerR
                color: control.isM3 && Config ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.16)
                border.width: control.isM3 ? 0 : 1
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }

    // Слой 2: Плавно скользящая плашка наведения
    Rectangle {
        z: 2
        opacity: control.isHovering ? 1.0 : 0.0
        x: control.lastHoveredIdx * (control.segW + control.gap)
        y: 0
        width: control.segW
        height: control.height
        readonly property bool isFirst: control.lastHoveredIdx === 0
        readonly property bool isLast: control.lastHoveredIdx === control.count - 1
        topLeftRadius: isFirst ? control.outerR : control.innerR
        bottomLeftRadius: isFirst ? control.outerR : control.innerR
        topRightRadius: isLast ? control.outerR : control.innerR
        bottomRightRadius: isLast ? control.outerR : control.innerR
        color: control.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.14)
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 130 } }
    }

    // Слой 3: Плавно скользящая активная плашка выбора
    Rectangle {
        z: 3
        visible: control.count > 0
        x: Math.max(0, Math.min(control.count - 1, control.selectedIndex)) * (control.segW + control.gap)
        y: 0
        width: control.segW
        height: control.height
        readonly property bool isFirst: control.selectedIndex === 0
        readonly property bool isLast: control.selectedIndex === control.count - 1
        topLeftRadius: isFirst ? control.outerR : control.innerR
        bottomLeftRadius: isFirst ? control.outerR : control.innerR
        topRightRadius: isLast ? control.outerR : control.innerR
        bottomRightRadius: isLast ? control.outerR : control.innerR
        color: Config ? Config.m3Primary : "#ffffff"
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // Слой 4: Текст и разделенные иконки (без закрашивающего фона!)
    Row {
        z: 4
        anchors.fill: parent
        spacing: control.gap

        Repeater {
            model: control.options
            delegate: Item {
                id: segItem
                width: control.segW
                height: control.height
                readonly property bool isSel: control.selectedIndex === index
                readonly property string fullTxt: Config ? (Config.language, Config.trAuto(modelData)) : modelData
                readonly property var splitParts: {
                    var s = fullTxt.trim()
                    if (!s) return { icon: "", label: "" }
                    var cp = s.codePointAt(0)
                    if (cp >= 0xE000 || (cp >= 0x2190 && cp <= 0x2BFF)) {
                        var chLen = cp > 0xFFFF ? 2 : 1
                        var rest = s.slice(chLen).trim()
                        if (rest.length > 0) return { icon: s.slice(0, chLen), label: rest }
                    }
                    return { icon: "", label: s }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: segItem.splitParts.icon.length > 0 ? 7 : 0

                    Text {
                        visible: segItem.splitParts.icon.length > 0
                        text: segItem.splitParts.icon
                        color: segLabel.color
                        font.pixelSize: (Config ? Config.fontSize : 11) + 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: segLabel
                        text: segItem.splitParts.label
                        color: segItem.isSel
                               ? (Config ? Config.accentTextColor : "#000000")
                               : (control.isM3 && Config ? Config.m3OnPrimaryContainer : "#d0d0d0")
                        font.pixelSize: Config ? Config.fontSize : 11
                        font.bold: segItem.isSel
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        segHoverHold.stop()
                        control.lastHoveredIdx = index
                        control.isHovering = true
                    }
                    onExited: segHoverHold.restart()
                    onClicked: {
                        control.selectedIndex = index
                        control.selected(index)
                    }
                }
            }
        }
    }
}
