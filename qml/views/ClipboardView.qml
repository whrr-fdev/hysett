import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: clipViewRoot
    property string query: ""
    readonly property bool isM3: Theme && Theme.isRounded

    onVisibleChanged: if (visible && Waybar) Waybar.refreshClipboard()

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var p = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                if (Config) Config.addStashedFile(p)
            }
        }
    }

    ColumnLayout {
        width: Math.min(parent.width - 48, 880)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 20
        anchors.bottomMargin: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰅌  История буфера обмена (Cliphist)"
                color: "#ffffff"
                font.pixelSize: Config ? Config.fontSize + 3 : 14
                font.bold: true
                Layout.fillWidth: true
            }
            StyledButton {
                text: "󰑐 Обновить"
                implicitHeight: 24
                onClicked: if (Waybar) Waybar.refreshClipboard()
            }
            StyledButton {
                text: "󰎟 Очистить всё"
                implicitHeight: 24
                onClicked: if (Waybar) Waybar.clearClipboard()
            }
        }

        // Блок файлов и папок, загруженных в панель задач
        GlassPanel {
            visible: Config && Config.stashedFiles.length > 0
            Layout.fillWidth: true
            implicitHeight: stashBoxCol.implicitHeight + 24

            ColumnLayout {
                id: stashBoxCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰇚"
                        color: Config ? Config.m3Primary : "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 1 : 12
                    }
                    Text {
                        text: "Загружено в панель задач (" + (Config ? Config.stashedFiles.length : 0) + ")"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 1 : 12
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: "󰎟 Очистить файлы"
                        implicitHeight: 22
                        onClicked: if (Config) Config.clearStashedFiles()
                    }
                }

                Item {
                    id: stashClipHoverWrap
                    Layout.fillWidth: true
                    implicitHeight: stashClipCol.implicitHeight
                    property bool isHovering: false
                    property real hovY: 0
                    property real hovH: 36

                    Timer {
                        id: stashClipHold
                        interval: 45
                        onTriggered: stashClipHoverWrap.isHovering = false
                    }

                    Rectangle {
                        z: 1
                        opacity: stashClipHoverWrap.isHovering ? 1.0 : 0.0
                        x: 0; y: stashClipHoverWrap.hovY
                        width: stashClipHoverWrap.width; height: stashClipHoverWrap.hovH
                        radius: clipViewRoot.isM3 ? 8 : 0
                        color: clipViewRoot.isM3 && Config
                               ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                               : Qt.rgba(1, 1, 1, 0.10)
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 115 } }
                    }

                    ColumnLayout {
                        id: stashClipCol
                        z: 2; width: parent.width; spacing: 5

                        Repeater {
                            model: Config ? Config.stashedFiles : []
                            delegate: Rectangle {
                                id: stashClipRow
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: clipViewRoot.isM3 ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: {
                                        stashClipHold.stop()
                                        stashClipHoverWrap.hovY = stashClipRow.y
                                        stashClipHoverWrap.hovH = stashClipRow.height
                                        stashClipHoverWrap.isHovering = true
                                    }
                                    onExited: stashClipHold.restart()
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.isDir ? "󰉋" : "󰈔"
                                        color: Config ? Config.m3Primary : "#a8c7fa"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: modelData.name
                                        color: "#ffffff"
                                        font.pixelSize: Config ? Config.fontSize : 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.size + " • " + modelData.time
                                        color: "#888888"
                                        font.pixelSize: Config ? Config.fontSize - 2 : 9
                                    }

                                    StyledButton {
                                        text: "󰆏 Путь"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.runCommand("printf '%s' '" + String(modelData.path).replace(/'/g, "'\\''") + "' | wl-copy")
                                    }

                                    StyledButton {
                                        text: "󰖟 В хостинг"
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.hostPathForFriend(modelData.path)
                                    }

                                    StyledButton {
                                        visible: !modelData.isDir
                                        text: "󰄜 На телефон"
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.shareFileToPhone(modelData.path)
                                    }

                                    StyledButton {
                                        text: "󰉋 Открыть"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.runCommand("xdg-open '" + String(modelData.path).replace(/'/g, "'\\''") + "'")
                                    }

                                    StyledButton {
                                        text: "󰅖"
                                        isIconOnly: true
                                        implicitWidth: 24; implicitHeight: 24
                                        onClicked: if (Config) Config.removeStashedFile(modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        TextField {
            Layout.fillWidth: true
            implicitHeight: 30
            leftPadding: 12; rightPadding: 12
            color: "#ffffff"
            font.pixelSize: 11
            placeholderText: "Поиск текста или скриншотов в буфере..."
            placeholderTextColor: "#777777"
            onTextChanged: clipViewRoot.query = text.toLowerCase()
            background: GlassPanel { radius: clipViewRoot.isM3 ? 10 : 0 }
        }

        Item {
            id: clipMainListArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property bool isHovering: false
            property int hoveredIndex: -1
            property real hovY: 0
            property real hovH: 34

            Timer {
                id: clipMainHoverHold
                interval: 45
                onTriggered: {
                    clipMainListArea.isHovering = false
                    clipMainListArea.hoveredIndex = -1
                }
            }

            Rectangle {
                id: clipMainSlidePill
                z: 1
                opacity: clipMainListArea.isHovering ? 1.0 : 0.0
                x: 0
                y: clipMainListArea.hovY - clipMainListView.contentY
                width: clipMainListView.width
                height: clipMainListArea.hovH
                radius: clipViewRoot.isM3 ? 8 : 0
                color: Config ? Config.m3Primary : "#ffffff"
                Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            ListView {
                id: clipMainListView
                z: 2
                anchors.fill: parent
                clip: true
                spacing: 6
                cacheBuffer: 200
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: {
                    if (!Waybar) return []
                    var raw = Waybar.clipboardItems || []
                    var q = clipViewRoot.query.trim()
                    if (q.length === 0) return raw
                    var filtered = []
                    for (var i = 0; i < raw.length; ++i) {
                        if ((raw[i].label || "").toLowerCase().indexOf(q) !== -1) filtered.push(raw[i])
                    }
                    return filtered
                }

                delegate: Rectangle {
                    id: clipMainDel
                    readonly property bool isHov: clipMainListArea.isHovering && clipMainListArea.hoveredIndex === index
                    width: ListView.view.width
                    height: modelData.isImage ? 62 : 34
                    radius: clipViewRoot.isM3 ? 8 : 0
                    color: "transparent"
                    border.color: isHov ? "transparent" : Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Text {
                            text: (Config && Config.streamerMode) ? "󰈉  Скрыто режимом стримера" : modelData.label
                            color: clipMainDel.isHov ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                            Behavior on color { ColorAnimation { duration: 110 } }
                            font.pixelSize: 11
                            font.bold: false
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Image {
                            visible: !(Config && Config.streamerMode) && modelData.isImage && modelData.thumb.length > 0
                            source: visible ? ("file://" + modelData.thumb) : ""
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        function syncHover() {
                            clipMainHoverHold.stop()
                            clipMainListArea.hovY = clipMainDel.y
                            clipMainListArea.hovH = clipMainDel.height
                            clipMainListArea.hoveredIndex = index
                            clipMainListArea.isHovering = true
                        }
                        onEntered: syncHover()
                        onPositionChanged: syncHover()
                        onExited: clipMainHoverHold.restart()
                        onClicked: if (Waybar) Waybar.selectClipboardItem(modelData.index)
                    }
                }
            }
        }
    }
}
