import QtQuick
import QtQuick.Controls
import HySett

Button {
    id: control
    property string iconSymbol: ""
    property bool isActive: false
    property bool collapsed: false
    property int tabIdx: 0
    readonly property bool isM3: Theme && Theme.isRounded

    implicitHeight: isM3 ? 32 : 25
    flat: true
    clip: true

    contentItem: Item {
        anchors.fill: parent

        Text {
            id: iconTxt
            visible: control.iconSymbol.length > 0
            text: control.iconSymbol
            x: control.collapsed
               ? Math.round((parent.width - width) * 0.5)
               : ((Config && Config.alignCenter)
                  ? Math.round((parent.width - (width + (control.collapsed ? 0 : (lblTxt.implicitWidth + (control.isM3 ? 10 : 7))))) * 0.5)
                  : (control.isM3 ? 14 : 10))
            anchors.verticalCenter: parent.verticalCenter
            color: control.isActive
                   ? (control.isM3 && Config ? Config.m3Primary : (Config ? Config.accentTextColor : "#000000"))
                   : (control.hovered ? "#ffffff" : (control.isM3 && Config ? Config.m3OnPrimaryContainer : "#888888"))
            font.pixelSize: (Config ? Config.fontSize : 11) + (control.isM3 ? 2 : 0)
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Text {
            id: lblTxt
            text: control.text
            x: iconTxt.x + iconTxt.width + (control.isM3 ? 10 : 7)
            anchors.verticalCenter: parent.verticalCenter
            opacity: control.collapsed ? 0.0 : 1.0
            visible: opacity > 0.01
            color: control.isActive
                   ? (control.isM3 && Config ? Config.m3OnPrimaryContainer : (Config ? Config.accentTextColor : "#000000"))
                   : (control.hovered ? "#ffffff" : (control.isM3 && Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.82) : "#cccccc"))
            font.pixelSize: Config ? Config.fontSize : 11
            font.bold: control.isM3 && control.isActive
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }
}
