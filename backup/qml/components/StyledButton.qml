import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Button {
    id: btn
    property bool isIconOnly: text.trim().length <= 2
    property bool allowFullWidth: false
    property bool isActive: false
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property bool useGlassShader: Theme && (Theme.controlsLiquidGlass || Theme.glassRefraction > 0.05)

    readonly property string fullTxt: Config ? (Config.language, Config.trAuto(btn.text)) : btn.text
    readonly property var splitParts: {
        var s = fullTxt.trim()
        if (!s) return { icon: "", label: "" }
        var cp = s.codePointAt(0)
        if (cp >= 0xE000 || (cp >= 0x2190 && cp <= 0x2BFF) || cp === 0x002B) {
            var chLen = cp > 0xFFFF ? 2 : 1
            var rest = s.slice(chLen).trim()
            if (rest.length > 0) {
                return { icon: s.slice(0, chLen), label: rest }
            }
        }
        return { icon: "", label: s }
    }

    implicitHeight: 26
    implicitWidth: isIconOnly ? 26 : contentRow.implicitWidth + 24
    Layout.maximumWidth: allowFullWidth ? 9999 : (isIconOnly ? 30 : 340)
    flat: true

    scale: btn.down ? 0.96 : 1.0
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: btn.splitParts.icon.length > 0 ? 8 : 0

            Item {
                visible: btn.splitParts.icon.length > 0
                width: 15
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: btn.splitParts.icon
                    color: labelTxt.color
                    font.pixelSize: (Config ? Config.fontSize : 11) + 1
                }
            }

            Text {
                id: labelTxt
                text: btn.splitParts.label
                color: (btn.down || btn.hovered || btn.isActive)
                       ? (Config ? Config.accentTextColor : "#000000")
                       : (btn.enabled ? (btn.isM3 && Config ? Config.m3OnPrimaryContainer : "#ececec") : "#666666")
                font.pixelSize: Config ? Config.fontSize : 11
                font.bold: btn.isM3 || btn.isActive
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 110 } }
            }
        }
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

        Loader {
            anchors.fill: parent
            anchors.margins: 1
            active: btn.useGlassShader && !btn.hovered && !btn.down
            sourceComponent: ShaderEffect {
                property vector2d u_resolution: Qt.vector2d(width, height)
                property real u_refraction: Theme ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.70 : 0.0) : 0.0
                property real u_radius: Math.max(0, bgFill.radius - 1)
                property real u_time: 1.0
                property vector4d u_base_color: Qt.vector4d(bgFill.color.r, bgFill.color.g, bgFill.color.b, bgFill.color.a)
                fragmentShader: "qrc:/shaders/qml/shaders/liquid_glass.frag.qsb"
            }
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
