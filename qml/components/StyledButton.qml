import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Button {
    id: btn
    property bool isIconOnly: text.length <= 2
    property bool allowFullWidth: false
    property bool isActive: false
    readonly property bool isM3: Theme && Theme.isRounded

    implicitHeight: 26
    implicitWidth: isIconOnly ? 26 : implicitContentWidth + 20
    Layout.maximumWidth: allowFullWidth ? 9999 : (isIconOnly ? 30 : 300)
    flat: true

    scale: btn.down ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    contentItem: Text {
        text: Config ? (Config.language, Config.trAuto(btn.text)) : btn.text
        color: (btn.down || btn.hovered || btn.isActive)
               ? (Config ? Config.accentTextColor : "#000000")
               : (btn.enabled ? (btn.isM3 && Config ? Config.m3OnPrimaryContainer : "#ececec") : "#666666")
        font.pixelSize: Config ? Config.fontSize : 11
        font.bold: btn.isM3 || btn.isActive
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 110 } }
    }

    background: Item {
        id: bgWrap

        Rectangle {
            id: bgFill
            anchors.fill: parent
            radius: btn.isM3 ? (Config ? Math.min(height / 2, Config.m3ControlRadius + 3) : height / 2) : 0
            color: (btn.down || btn.hovered || btn.isActive)
                   ? (Config ? Config.m3Primary : "#ffffff")
                   : (btn.isM3 && Config
                      ? Config.m3SecondaryContainer
                      : Qt.rgba(1, 1, 1, Math.max(0.05, Config ? Config.cardOpacity * 0.18 : 0.07)))
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }

        ShaderEffect {
            anchors.fill: parent
            anchors.margins: 1
            visible: Theme && (Theme.controlsLiquidGlass || Theme.glassRefraction > 0.05) && !btn.hovered && !btn.down
            property vector2d u_resolution: Qt.vector2d(width, height)
            property real u_refraction: Theme ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.70 : 0.0) : 0.0
            property real u_radius: Math.max(0, bgFill.radius - 1)
            property real u_time: 1.0
            property vector4d u_base_color: Qt.vector4d(bgFill.color.r, bgFill.color.g, bgFill.color.b, bgFill.color.a)
            fragmentShader: "qrc:/shaders/qml/shaders/liquid_glass.frag.qsb"
        }

        Rectangle {
            anchors.fill: parent
            radius: bgFill.radius
            color: "transparent"
            border.color: (btn.down || btn.hovered || btn.isActive)
                          ? (Config ? Config.m3Primary : "#ffffff")
                          : Qt.rgba(1, 1, 1, 0.18)
            border.width: btn.isM3 ? 0 : 1
            visible: !btn.isM3
            z: 2
        }
    }
}
