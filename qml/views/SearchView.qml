import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: searchScroll
    contentWidth: availableWidth
    clip: true

    property string queryText: ""
    property int filterMode: 0
    property bool searchEntireSystem: false
    property int kbIndex: 0

    function focusSearchInput() {
        uniSearchInput.forceActiveFocus()
        searchFocusRetry.restart()
    }

    function collectNavItems() {
        var list = []
        if (searchScroll.filterMode !== 1 && searchScroll.queryText.length > 0) {
            for (var i = 0; i < sAppsRepeater.count; ++i) {
                var a = sAppsRepeater.itemAt(i)
                if (a && a.visible) list.push({ type: "app", item: a, exec: a.appExec })
            }
        }
        if (searchScroll.filterMode !== 2 && searchScroll.queryText.length >= 2) {
            for (var j = 0; j < sFilesRepeater.count; ++j) {
                var f = sFilesRepeater.itemAt(j)
                if (f && f.visible) list.push({ type: "file", item: f, path: f.filePath })
            }
        }
        return list
    }

    function selectByKb(newIdx) {
        var list = collectNavItems()
        if (list.length === 0) {
            foundAppsWrap.hoveredObj = null
            filesListWrap.hoveredFileObj = null
            return
        }
        kbIndex = Math.max(0, Math.min(list.length - 1, newIdx))
        var entry = list[kbIndex]
        if (entry.type === "app") {
            filesListWrap.hoveredFileObj = null
            foundAppsWrap.lastHoveredObj = entry.item
            foundAppsWrap.hoveredObj = entry.item
        } else {
            foundAppsWrap.hoveredObj = null
            filesListWrap.lastHoveredFileObj = entry.item
            filesListWrap.hoveredFileObj = entry.item
        }
        var mapped = entry.item.mapToItem(searchCol, 0, 0)
        var flk = searchScroll.contentItem
        if (flk) {
            if (mapped.y < flk.contentY + 30) flk.contentY = Math.max(0, mapped.y - 30)
            else if (mapped.y + entry.item.height + 30 > flk.contentY + searchScroll.height)
                flk.contentY = mapped.y + entry.item.height + 30 - searchScroll.height
        }
    }

    Timer {
        id: searchFocusRetry
        interval: 45
        repeat: false
        onTriggered: if (searchScroll.visible) uniSearchInput.forceActiveFocus()
    }

    onVisibleChanged: if (visible) focusSearchInput()
    Component.onCompleted: if (visible) focusSearchInput()

    Connections {
        target: Apps
        function onFileResultsChanged() { Qt.callLater(() => searchScroll.selectByKb(searchScroll.kbIndex)) }
    }

    Timer {
        id: fileSearchDebounce
        interval: 200
        repeat: false
        onTriggered: {
            if (searchScroll.filterMode !== 2 && searchScroll.queryText.length >= 2) {
                Apps.searchFiles(searchScroll.queryText, searchScroll.searchEntireSystem)
            } else {
                Apps.clearFileSearch()
            }
            Qt.callLater(() => searchScroll.selectByKb(0))
        }
    }

    Item {
        width: searchScroll.availableWidth
        implicitHeight: searchCol.implicitHeight + 40

        ColumnLayout {
            id: searchCol
            width: Math.min(parent.width - 48, 920)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Config ? (Config.language, Config.trAuto("Глобальный поиск (Файлы и Приложения)")) : "Глобальный поиск (Файлы и Приложения)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    visible: Apps.isSearching
                    text: Config ? (Config.language, Config.trAuto("󰑐  Поиск...")) : "󰑐  Поиск..."
                    color: "#aaaaaa"
                    font.pixelSize: Config.fontSize
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: topControlsCol.implicitHeight + 20

                ColumnLayout {
                    id: topControlsCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    TextField {
                        id: uniSearchInput
                        placeholderText: Config ? (Config.language, Config.trAuto("Введите название файла, папки или приложения...")) : "Введите название файла, папки или приложения..."
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        implicitHeight: 30
                        Layout.fillWidth: true
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 5 : 0
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: uniSearchInput.activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1
                        }
                        onTextChanged: {
                            searchScroll.queryText = text.trim().toLowerCase()
                            searchScroll.kbIndex = 0
                            fileSearchDebounce.restart()
                            Qt.callLater(() => searchScroll.selectByKb(0))
                        }
                        Keys.onDownPressed: (event) => {
                            searchScroll.selectByKb(searchScroll.kbIndex + 1)
                            event.accepted = true
                        }
                        Keys.onUpPressed: (event) => {
                            searchScroll.selectByKb(searchScroll.kbIndex - 1)
                            event.accepted = true
                        }
                        Keys.onReturnPressed: (event) => {
                            var list = searchScroll.collectNavItems()
                            if (list.length > 0 && searchScroll.kbIndex < list.length) {
                                var e = list[searchScroll.kbIndex]
                                if (e.type === "app") Apps.launchApp(e.exec)
                                else Apps.openFile(e.path)
                            }
                            event.accepted = true
                        }
                        Keys.onEnterPressed: (event) => {
                            var list = searchScroll.collectNavItems()
                            if (list.length > 0 && searchScroll.kbIndex < list.length) {
                                var e = list[searchScroll.kbIndex]
                                if (e.type === "app") Apps.launchApp(e.exec)
                                else Apps.openFile(e.path)
                            }
                            event.accepted = true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: Config ? (Config.language, Config.trAuto("Показать:")) : "Показать:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1 }
                        SegmentedButton {
                            options: ["Все", "Только файлы", "Только приложения"]
                            selectedIndex: searchScroll.filterMode
                            onSelected: (idx) => {
                                searchScroll.filterMode = idx
                                fileSearchDebounce.restart()
                                uniSearchInput.forceActiveFocus()
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: searchScroll.filterMode !== 2
                            text: Config ? (Config.language, Config.trAuto("Область:")) : "Область:"
                            color: "#aaaaaa"
                            font.pixelSize: Config.fontSize - 1
                        }
                        SegmentedButton {
                            visible: searchScroll.filterMode !== 2
                            options: ["Домашняя (~)", "Вся система (/)"]
                            selectedIndex: searchScroll.searchEntireSystem ? 1 : 0
                            onSelected: (idx) => {
                                searchScroll.searchEntireSystem = (idx === 1)
                                fileSearchDebounce.restart()
                                uniSearchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: searchScroll.filterMode !== 1 && searchScroll.queryText.length > 0
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: Config ? (Config.language, Config.trAuto("Приложения")) : "Приложения"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                }

                Item {
                    id: foundAppsWrap
                    Layout.fillWidth: true
                    implicitHeight: foundAppsGrid.implicitHeight
                    property Item hoveredObj: null
                    property Item lastHoveredObj: null

                    Rectangle {
                        x: foundAppsWrap.lastHoveredObj ? foundAppsWrap.lastHoveredObj.x : 0
                        y: foundAppsWrap.lastHoveredObj ? foundAppsWrap.lastHoveredObj.y : 0
                        width: foundAppsWrap.lastHoveredObj ? foundAppsWrap.lastHoveredObj.width : 220
                        height: foundAppsWrap.lastHoveredObj ? foundAppsWrap.lastHoveredObj.height : 44
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: Qt.rgba(1, 1, 1, 0.09)
                        border.color: Qt.rgba(1, 1, 1, 0.42)
                        border.width: 1
                        opacity: foundAppsWrap.hoveredObj ? 1.0 : 0.0
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    GridLayout {
                        id: foundAppsGrid
                        width: parent.width
                        columns: 1
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            id: sAppsRepeater
                            model: Apps.apps

                            Button {
                                id: sAppBtn
                                property string appExec: modelData.exec
                                visible: {
                                    var q = searchScroll.queryText
                                    if (q.length === 0) return false
                                    return modelData.name.toLowerCase().indexOf(q) !== -1 ||
                                           modelData.comment.toLowerCase().indexOf(q) !== -1 ||
                                           modelData.exec.toLowerCase().indexOf(q) !== -1
                                }
                                Layout.fillWidth: true
                                Layout.preferredWidth: foundAppsGrid.width
                                implicitHeight: 44
                                flat: true

                                onHoveredChanged: {
                                    if (hovered) {
                                        filesListWrap.hoveredFileObj = null
                                        foundAppsWrap.lastHoveredObj = sAppBtn
                                        foundAppsWrap.hoveredObj = sAppBtn
                                    }
                                }

                                onClicked: Apps.launchApp(modelData.exec)

                                background: GlassPanel {
                                    radius: (Theme && Theme.isRounded) ? 5 : 0
                                    tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08, Config ? Config.cardBgColor.g : 0.08, Config ? Config.cardBgColor.b : 0.10, Math.max(0.02, Config ? Config.cardOpacity : 0.10))
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent; anchors.margins: 6; spacing: 8
                                    Image {
                                        source: "image://appicon/" + modelData.icon
                                        sourceSize.width: 24; sourceSize.height: 24; cache: true
                                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                        Layout.alignment: Qt.AlignVCenter; Layout.bottomMargin: 3
                                        fillMode: Image.PreserveAspectFit; smooth: true
                                    }
                                    ColumnLayout {
                                        spacing: 1; Layout.fillWidth: true
                                        Text { text: modelData.name; color: "#ffffff"; font.pixelSize: Config.fontSize; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.comment; color: "#888888"; font.pixelSize: Config.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: searchScroll.filterMode !== 2 && searchScroll.queryText.length >= 2
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: (Config ? (Config.language, Config.trAuto("Файлы и папки (")) : "Файлы и папки (") + Apps.fileResults.length + ")"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                }

                Item {
                    id: filesListWrap
                    Layout.fillWidth: true
                    implicitHeight: filesCol.implicitHeight
                    property Item hoveredFileObj: null
                    property Item lastHoveredFileObj: null

                    Rectangle {
                        x: 0; width: filesListWrap.width
                        height: filesListWrap.lastHoveredFileObj ? filesListWrap.lastHoveredFileObj.height : 38
                        y: filesListWrap.lastHoveredFileObj ? filesListWrap.lastHoveredFileObj.y : 0
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        border.width: 1
                        opacity: filesListWrap.hoveredFileObj ? 1.0 : 0.0
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 90 } }
                    }

                    ColumnLayout {
                        id: filesCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            id: sFilesRepeater
                            model: Apps.fileResults

                            GlassPanel {
                                objectName: "atmoObstacle"
                                id: fileRow
                                property string filePath: modelData.path
                                Layout.fillWidth: true
                                implicitHeight: 38
                                radius: (Theme && Theme.isRounded) ? 5 : 0
                                tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08, Config ? Config.cardBgColor.g : 0.08, Config ? Config.cardBgColor.b : 0.10, Math.max(0.02, Config ? Config.cardOpacity : 0.10))

                                MouseArea {
                                    id: fMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: {
                                        if (containsMouse) {
                                            foundAppsWrap.hoveredObj = null
                                            filesListWrap.lastHoveredFileObj = fileRow
                                            filesListWrap.hoveredFileObj = fileRow
                                        }
                                    }
                                    onClicked: Apps.openFile(modelData.path)
                                }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                                    Text { text: modelData.icon; color: "#ffffff"; font.pixelSize: 16 }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: modelData.name; color: "#ffffff"; font.pixelSize: Config.fontSize; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.path; color: "#777777"; font.pixelSize: Config.fontSize - 2; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                    }
                                    Text { text: modelData.sizeStr; color: "#999999"; font.pixelSize: Config.fontSize - 1 }
                                    StyledButton { z: 5; text: Config ? (Config.language, Config.trAuto("󰉋 Папка")) : "󰉋 Папка"; implicitHeight: 22; onClicked: Apps.openContainingFolder(modelData.path) }
                                    StyledButton { z: 5; text: Config ? (Config.language, Config.trAuto("󰆏 Путь")) : "󰆏 Путь"; implicitHeight: 22; onClicked: Apps.copyPath(modelData.path) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
