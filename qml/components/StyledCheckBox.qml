import QtQuick
import QtQuick.Controls
import HySett

CheckBox {
    id: control
    font.pixelSize: Config ? Config.fontSize : 11
    readonly property bool isM3: Theme && Theme.isRounded

    readonly property string fullTxt: Config ? (Config.language, Config.trAuto(control.text)) : control.text
    readonly property var splitParts: {
        var s = fullTxt.trim()
        if (!s) return { icon: "", label: "" }
        var cp = s.codePointAt(0)
        if (cp >= 0xE000 || (cp >= 0x2190 && cp <= 0x2BFF)) {
            var chLen = cp > 0xFFFF ? 2 : 1
            var rest = s.slice(chLen).replace(/^[\uFE0E\uFE0F]+/, "").trim()
            if (rest.length > 0) return { icon: s.slice(0, chLen), label: rest }
        }
        return { icon: "", label: s }
    }

    scale: control.hovered ? 1.03 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    indicator: Rectangle {
        implicitWidth: 16
        implicitHeight: 16
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: control.isM3 ? (Config ? Math.min(6, Math.round(Config.m3ControlRadius * 0.45)) : 5) : 0
        color: control.checked
               ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
               : (control.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.35) : Qt.rgba(1, 1, 1, 0.08))
        border.color: control.checked || control.hovered
                      ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
                      : (control.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, Math.max(0.35, Config.m3OutlineOpacity)) : Qt.rgba(1, 1, 1, 0.28))
        border.width: control.isM3 ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on radius { NumberAnimation { duration: 150 } }
    }

    contentItem: Item {
        implicitWidth: cbRow.implicitWidth + control.indicator.width + 8
        implicitHeight: Math.max(18, cbRow.implicitHeight)

        Row {
            id: cbRow
            x: control.indicator.width + 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: control.splitParts.icon.length > 0 ? 7 : 0

            Item {
                visible: control.splitParts.icon.length > 0
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: control.splitParts.icon
                    font.pixelSize: control.font.pixelSize + 1
                    color: control.checked ? (control.isM3 && Config ? Config.m3Primary : "#ffffff") : "#aaaaaa"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            Text {
                text: control.splitParts.label
                font: control.font
                color: control.checked ? "#ffffff" : "#cccccc"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}
