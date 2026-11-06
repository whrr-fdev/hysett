import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: pwrRoot
    property int selIdx: 0
    focus: visible

    onVisibleChanged: {
        if (visible) Qt.callLater(() => pwrRoot.forceActiveFocus())
    }

    Shortcut {
        sequences: ["Up", "K"]
        context: Qt.ApplicationShortcut
        enabled: pwrRoot.visible
        onActivated: pwrRoot.selIdx = (pwrRoot.selIdx + 5) % 6
    }
    Shortcut {
        sequences: ["Down", "J"]
        context: Qt.ApplicationShortcut
        enabled: pwrRoot.visible
        onActivated: pwrRoot.selIdx = (pwrRoot.selIdx + 1) % 6
    }
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        context: Qt.ApplicationShortcut
        enabled: pwrRoot.visible
        onActivated: pwrRoot.execPower(pwrRoot.selIdx)
    }

    Keys.onUpPressed: (event) => { pwrRoot.selIdx = (pwrRoot.selIdx + 5) % 6; event.accepted = true }
    Keys.onDownPressed: (event) => { pwrRoot.selIdx = (pwrRoot.selIdx + 1) % 6; event.accepted = true }
    Keys.onReturnPressed: (event) => { pwrRoot.execPower(pwrRoot.selIdx); event.accepted = true }
    Keys.onEnterPressed: (event) => { pwrRoot.execPower(pwrRoot.selIdx); event.accepted = true }

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
        spacing: 12

        Text {
            text: "⏻  Управление питанием (Power Menu)"
            color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
            Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 4
        }

        Item {
            id: pwrListContainer
            Layout.fillWidth: true
            implicitHeight: 6 * 46 + 5 * 10

            readonly property int itemH: 46
            readonly property int gap: 10

            // Плавно скользящая плашка выбора/наведения
            Rectangle {
                id: powerViewSlidePill
                x: 0
                y: pwrRoot.selIdx * (pwrListContainer.itemH + pwrListContainer.gap)
                width: pwrListContainer.width
                height: pwrListContainer.itemH
                radius: (Theme && Theme.isRounded) ? 12 : 0
                color: Config ? Config.m3Primary : "#ffffff"

                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                Behavior on radius { NumberAnimation { duration: 150 } }
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
                    x: 0
                    y: index * (pwrListContainer.itemH + pwrListContainer.gap)
                    width: pwrListContainer.width
                    height: pwrListContainer.itemH
                    property bool isSel: pwrRoot.selIdx === modelData.idx
                    radius: (Theme && Theme.isRounded) ? 12 : 0
                    color: "transparent"
                    border.color: isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 14
                        font.bold: parent.isSel
                        color: parent.isSel ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: pMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: pwrRoot.selIdx = modelData.idx
                        onPositionChanged: pwrRoot.selIdx = modelData.idx
                        onClicked: pwrRoot.execPower(modelData.idx)
                    }
                }
            }
        }
    }
}
