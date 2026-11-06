import QtQuick
import HySett

Item {
    id: control
    readonly property int elevStyle: Config ? Config.m3ElevationStyle : 0
    property color baseSurf: Config ? (elevStyle === 2 ? Config.m3SurfaceContainerHigh : Config.m3SurfaceContainer) : "#1e2028"
    readonly property real baseAlpha: Config ? (elevStyle === 1 ? Math.max(0.08, Config.cardOpacity * 0.5) : Math.max(0.26, Config.cardOpacity + 0.18)) : 0.32
    property color tintColor: Qt.rgba(baseSurf.r, baseSurf.g, baseSurf.b, baseAlpha)
    property real radius: (Theme && Theme.isRounded) ? (Config ? Config.m3CardRadius : 16) : 0
    readonly property bool isSquareTheme: Theme ? !Theme.isRounded : false
    default property alias content: placeholder.data

    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

    Rectangle {
        anchors.fill: parent
        radius: control.radius
        color: control.isSquareTheme ? "transparent" : control.tintColor
        visible: !Theme || (Theme.glassRefraction <= 0.01 && !Theme.controlsLiquidGlass)
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    ShaderEffect {
        id: liquidEffect
        anchors.fill: parent
        anchors.margins: 1
        visible: !control.isSquareTheme && Theme && (Theme.glassRefraction > 0.01 || Theme.controlsLiquidGlass)
        property vector2d u_resolution: Qt.vector2d(width, height)
        property real u_refraction: Theme ? Math.max(Theme.glassRefraction, Theme.controlsLiquidGlass ? 0.55 : 0.0) : 0.55
        property real u_radius: Math.max(0, control.radius - 1)
        property vector4d u_base_color: Qt.vector4d(control.tintColor.r, control.tintColor.g, control.tintColor.b, control.tintColor.a)
        fragmentShader: "qrc:/shaders/qml/shaders/liquid_panel.frag.qsb"
    }

    Rectangle {
        anchors.fill: parent
        radius: control.radius
        color: "transparent"
        border.color: (Theme && Theme.isRounded && Config)
                      ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, control.elevStyle === 1 ? Math.min(1.0, Config.m3OutlineOpacity * 1.65) : Config.m3OutlineOpacity)
                      : Qt.rgba(1, 1, 1, 0.14)
        border.width: (Theme && Theme.isRounded && Config) ? Config.m3OutlineWidth : 1
        visible: border.width > 0.05
        z: 3
    }

    Item {
        id: placeholder
        anchors.fill: parent
        z: 2
    }
}
