import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: clipViewRoot
    property string query: ""
    onVisibleChanged: if (visible && Waybar) Waybar.refreshClipboard()

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰅌  История буфера обмена (Cliphist)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true; Layout.fillWidth: true }
            StyledButton { text: "↺ Обновить"; implicitHeight: 24; onClicked: if (Waybar) Waybar.refreshClipboard() }
            StyledButton { text: "󰎟 Очистить всё"; implicitHeight: 24; onClicked: if (Waybar) Waybar.clearClipboard() }
        }
        TextField {
            Layout.fillWidth: true; implicitHeight: 30; leftPadding: 12; rightPadding: 12
            color: "#ffffff"; font.pixelSize: 11; placeholderText: "Поиск текста или скриншотов в буфере..."; placeholderTextColor: "#777777"
            onTextChanged: clipViewRoot.query = text.toLowerCase()
            background: GlassPanel { radius: (Theme && Theme.isRounded) ? 10 : 0 }
        }
        ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
            model: Waybar ? Waybar.clipboardItems : []
            delegate: Rectangle {
                property bool matches: clipViewRoot.query.length === 0 || modelData.label.toLowerCase().indexOf(clipViewRoot.query) !== -1
                width: ListView.view.width
                height: matches ? (modelData.isImage ? 62 : 34) : 0
                visible: matches
                radius: (Theme && Theme.isRounded) ? 8 : 0
                color: cMouse.containsMouse ? (Config ? Config.m3Primary : "#ffffff") : "transparent"
                border.color: cMouse.containsMouse ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                    Text { text: modelData.label; color: cMouse.containsMouse ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                    Image { visible: modelData.isImage && modelData.thumb.length > 0; source: visible ? ("file://" + modelData.thumb) : ""; Layout.preferredWidth: 50; Layout.preferredHeight: 50; asynchronous: true; fillMode: Image.PreserveAspectCrop }
                }
                MouseArea {
                    id: cMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (Waybar) Waybar.selectClipboardItem(modelData.index)
                }
            }
        }
    }
}
