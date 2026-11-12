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

    property real cascadeProgress: 1.0

    SequentialAnimation {
        id: cascadeAnim
        PropertyAction { target: control; property: "cascadeProgress"; value: 0.0 }
        PauseAnimation { id: cascadeDelay; duration: 0 }
        NumberAnimation {
            target: control
            property: "cascadeProgress"
            from: 0.0
            to: 1.0
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.35
        }
    }

    function playCascade(delayMs) {
        cascadeDelay.duration = Math.max(0, delayMs)
        cascadeAnim.restart()
    }

    implicitHeight: isM3 ? 32 : 25
    flat: true

    scale: (control.down ? 0.96 : 1.0) * (0.86 + 0.14 * cascadeProgress)
    Behavior on scale { enabled: !cascadeAnim.running; NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: -14 * (1.0 - control.cascadeProgress)
        y: -14 * (1.0 - control.cascadeProgress)
    }

    contentItem: Item {
        anchors.fill: parent
        opacity: Math.min(1.0, control.cascadeProgress * 1.25)

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
            x: parent.targetIconX
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

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
            x: iconContainer.x + iconContainer.width + parent.gap
            width: Math.max(0, parent.width - x - 6)
            anchors.verticalCenter: parent.verticalCenter
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
