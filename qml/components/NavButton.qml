import QtQuick
import QtQuick.Controls
import HySett

Button {
    id: control
    property string iconSymbol: ""
    property bool isActive: false
    property int tabIdx: 0
    readonly property bool isM3: Theme && Theme.isRounded

    implicitHeight: isM3 ? 32 : 25
    flat: true

    contentItem: Item {
        anchors.fill: parent

        Row {
            id: contentRow
            spacing: control.isM3 ? 10 : 7
            anchors.verticalCenter: parent.verticalCenter
            x: (Config && Config.alignCenter)
               ? Math.round((parent.width - contentRow.width) / 2)
               : (control.isM3 ? 14 : 10)

            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Text {
                visible: control.iconSymbol.length > 0
                text: control.iconSymbol
                color: control.isActive
                       ? (control.isM3 && Config ? Config.m3Primary : (Config ? Config.accentTextColor : "#000000"))
                       : (control.hovered ? "#ffffff" : (control.isM3 && Config ? Config.m3OnPrimaryContainer : "#888888"))
                font.pixelSize: (Config ? Config.fontSize : 11) + (control.isM3 ? 2 : 0)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            Text {
                text: control.text
                color: control.isActive
                       ? (control.isM3 && Config ? Config.m3OnPrimaryContainer : (Config ? Config.accentTextColor : "#000000"))
                       : (control.hovered ? "#ffffff" : (control.isM3 && Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.82) : "#cccccc"))
                font.pixelSize: Config ? Config.fontSize : 11
                font.bold: control.isM3 && control.isActive
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }
    }
}
