import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: pwrRoot
    property int selIdx: 0

    function execPower(idx) {
        if (ApplicationWindow.window) ApplicationWindow.window.drawerOpen = false
        if (!Waybar) return
        if (idx === 0) Waybar.runCommand("hyprlock")
        else if (idx === 1) Waybar.runCommand("hyprlock & systemctl suspend")
        else if (idx === 2) Waybar.runCommand("hyprlock & systemctl hibernate")
        else if (idx === 3) Waybar.runCommand("hyprshutdown --post-cmd \"bash -c 'pkill -KILL -u $(whoami)'\"")
        else if (idx === 4) Waybar.runCommand("systemctl reboot")
        else if (idx === 5) Waybar.runCommand("systemctl poweroff")
    }

    ColumnLayout {
        width: Math.min(parent.width - 48, 420)
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "⏻  Управление питанием (Power Menu)"
            color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
            Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 6
        }

        Repeater {
            model: [
                { label: "󰌾   Lock", idx: 0 },
                { label: "󰒲   Sleep", idx: 1 },
                { label: "󰤄   Hibernate", idx: 2 },
                { label: "󰍃   Logout", idx: 3 },
                { label: "󰜉   Reboot", idx: 4 },
                { label: "⏻   Shutdown", idx: 5 }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; implicitHeight: 46
                property bool isSel: pwrRoot.selIdx === modelData.idx || pMouse.containsMouse
                radius: (Theme && Theme.isRounded) ? 12 : 0
                color: isSel ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                border.color: isSel ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.18)
                border.width: 1
                Text {
                    anchors.centerIn: parent; text: modelData.label; font.pixelSize: 14; font.bold: parent.isSel
                    color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                }
                MouseArea {
                    id: pMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: pwrRoot.selIdx = modelData.idx
                    onClicked: pwrRoot.execPower(modelData.idx)
                }
            }
        }
    }
}
