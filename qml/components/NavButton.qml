import QtQuick
import QtQuick.Controls
import HySett

Button {
    id: control
    property string iconSymbol: "•"
    property bool isActive: false
    property int tabIdx: -1
    property bool collapsed: false
    readonly property bool isM3: Theme && Theme.isRounded

    property real iconAlpha: 1.0
    property real iconDropY: 0.0
    property real iconStepX: 0.0
    property real iconPopScale: 1.0

    SequentialAnimation {
        id: cascadeAnim
        PropertyAction { target: control; property: "iconAlpha"; value: 0.0 }
        PropertyAction { target: control; property: "iconDropY"; value: -22.0 }
        PropertyAction { target: control; property: "iconStepX"; value: -24.0 }
        PropertyAction { target: control; property: "iconPopScale"; value: 0.25 }
        PauseAnimation { id: cascadeDelay; duration: 0 }
        ParallelAnimation {
            NumberAnimation {
                target: control
                property: "iconAlpha"
                from: 0.0; to: 1.0
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: control
                property: "iconDropY"
                from: -22.0; to: 0.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.65
            }
            NumberAnimation {
                target: control
                property: "iconStepX"
                from: -24.0; to: 0.0
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.45
            }
            NumberAnimation {
                target: control
                property: "iconPopScale"
                from: 0.25; to: 1.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.75
            }
        }
    }

    function playCascade(delayMs) {
        cascadeDelay.duration = Math.max(0, delayMs)
        cascadeAnim.restart()
    }

    implicitHeight: isM3 ? 32 : 25
    flat: true

    scale: control.down ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    contentItem: Item {
        anchors.fill: parent
        opacity: control.iconAlpha

        readonly property int iconBoxW: control.isM3 ? 20 : 18
        readonly property int gap: control.isM3 ? 10 : 7
        readonly property int totalExpandedW: iconBoxW + gap + lblText.implicitWidth
        readonly property int targetIconX: control.collapsed
                                           ? Math.round((width - iconBoxW) * 0.5)
                                           : ((Config && Config.alignCenter)
                                              ? Math.round((width - totalExpandedW) * 0.5)
                                              : (control.isM3 ? 14 : 10))

        Item {
            id: iconContainer
            width: parent.iconBoxW
            height: parent.iconBoxW
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: control.iconDropY
            x: parent.targetIconX + control.iconStepX
            scale: control.iconPopScale
            Behavior on x { enabled: !cascadeAnim.running; NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            Text {
                anchors.centerIn: parent
                text: control.iconSymbol
                font.pixelSize: Config.fontSize + (control.isM3 ? 2 : 1)
                color: control.isActive
                       ? (control.isM3 && Config ? Config.m3OnPrimaryContainer : (Config ? Config.accentTextColor : "#000000"))
                       : (control.hovered
                          ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
                          : "#90949c")
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        Text {
            id: lblText
            x: parent.targetIconX + iconContainer.width + parent.gap + control.iconStepX
            width: Math.max(0, parent.width - x - 6)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: control.iconDropY
            text: control.text
            opacity: control.collapsed ? 0.0 : 1.0
            visible: opacity > 0.01
            font.pixelSize: Config.fontSize
            font.bold: control.isActive
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
            color: control.isActive
                   ? (control.isM3 && Config ? Config.m3OnPrimaryContainer : (Config ? Config.accentTextColor : "#000000"))
                   : (control.hovered ? "#ffffff" : "#c4c7cf")
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    background: Item {}
}
