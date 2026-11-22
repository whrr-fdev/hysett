import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

RowLayout {
    id: recRoot
    spacing: 0

    property int subTab: 0
    property int prevSubTab: 0
    property real subPageOffsetY: 0.0
    property real subPageAlpha: 1.0
    property real subPageScale: 1.0

    ParallelAnimation {
        id: recSubTabAnim
        NumberAnimation { target: recRoot; property: "subPageAlpha"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { id: recSubYAnim; target: recRoot; property: "subPageOffsetY"; to: 0.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        NumberAnimation { target: recRoot; property: "subPageScale"; from: 0.975; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
    }

    onSubTabChanged: {
        var dir = (subTab >= prevSubTab) ? 1 : -1
        prevSubTab = subTab
        recSubTabAnim.stop()
        recSubYAnim.from = dir * 24.0
        recSubTabAnim.start()
    }
    onVisibleChanged: if (visible) subSidebar.playStaircase()
    Component.onCompleted: if (visible) Qt.callLater(() => subSidebar.playStaircase())

    ColorPickerModal {
        id: drawColorModal
        onColorSelected: (newCol) => {
            if (Config) {
                Config.screenDrawUseThemeColor = false
                Config.screenDrawColor = newCol
            }
        }
    }

    Rectangle {
        id: subSidebar
        signal playStaircase()

        component SubCascadeAttach: Item {
            id: att
            property int stepIdx: 0
            property real dY: 0.0
            property real dX: 0.0
            property real sc: 1.0

            Connections {
                target: subSidebar
                function onPlayStaircase() { attAnim.restart() }
            }
            Component.onCompleted: {
                if (att.parent) att.parent.transform = [attTrans, attScale]
            }
            Translate { id: attTrans; x: att.dX; y: att.dY }
            Scale {
                id: attScale
                origin.x: att.parent ? att.parent.width * 0.35 : 40
                origin.y: att.parent ? att.parent.height * 0.5 : 15
                xScale: att.sc
                yScale: att.sc
            }
            SequentialAnimation {
                id: attAnim
                PropertyAction { target: att.parent; property: "opacity"; value: 0.0 }
                PropertyAction { target: att; property: "dY"; value: -20.0 }
                PropertyAction { target: att; property: "dX"; value: -22.0 }
                PropertyAction { target: att; property: "sc"; value: 0.72 }
                PauseAnimation { duration: 25 + att.stepIdx * 38 }
                ParallelAnimation {
                    NumberAnimation { target: att.parent; property: "opacity"; from: 0.0; to: 1.0; duration: 210; easing.type: Easing.OutCubic }
                    NumberAnimation { target: att; property: "dY"; from: -20.0; to: 0.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
                    NumberAnimation { target: att; property: "dX"; from: -22.0; to: 0.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.45 }
                    NumberAnimation { target: att; property: "sc"; from: 0.72; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
                }
                onStopped: {
                    if (att.parent) att.parent.opacity = 1.0
                    att.dY = 0.0
                    att.dX = 0.0
                    att.sc = 1.0
                }
            }
        }

        Layout.fillHeight: true
        Layout.preferredWidth: 195
        color: Qt.rgba(0.04, 0.04, 0.04, Config ? Config.sidebarOpacity : 0.35)

        property Item activeCardObj: subTab === 0 ? rCard0 : (subTab === 1 ? rCard1 : rCard2)
        property Item hoveredCardObj: null
        property Item lastHoveredCardObj: null

        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: recHoverPill
            x: 4; width: subSidebar.width - 8; height: 30
            radius: (Theme && Theme.isRounded) ? 4 : 0
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: subSidebar.hoveredCardObj && subSidebar.hoveredCardObj !== subSidebar.activeCardObj ? 1.0 : 0.0
            y: subSidebar.lastHoveredCardObj ? (subCol.y + subSidebar.lastHoveredCardObj.y) : 34
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: recActivePill
            SubCascadeAttach { stepIdx: recRoot.subTab + 1 }
            x: 4; width: subSidebar.width - 8; height: 30
            radius: (Theme && Theme.isRounded) ? 4 : 0
            color: Config ? Config.accentColor : "#ffffff"
            y: subSidebar.activeCardObj ? (subCol.y + subSidebar.activeCardObj.y) : 34
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }

        ColumnLayout {
            id: subCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 3

            Text {
                SubCascadeAttach { stepIdx: 0 }
                text: "Запись и съёмка"
                color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                Layout.topMargin: 4; Layout.bottomMargin: 6; Layout.leftMargin: 4
            }

            Rectangle {
                objectName: "sidebarSepLine"
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
                Layout.bottomMargin: 2
            }

            Item {
                id: rCard0
                SubCascadeAttach { stepIdx: 1 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: rMouse0; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = rCard0; subSidebar.hoveredCardObj = rCard0 }
                        else if (subSidebar.hoveredCardObj === rCard0) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 0
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰑋"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (rMouse0.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: "Запись экрана"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (rMouse0.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: rCard1
                SubCascadeAttach { stepIdx: 2 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: rMouse1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = rCard1; subSidebar.hoveredCardObj = rCard1 }
                        else if (subSidebar.hoveredCardObj === rCard1) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 1
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰹑"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (rMouse1.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: "Скриншоты"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (rMouse1.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: rCard2
                SubCascadeAttach { stepIdx: 3 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: rMouse2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = rCard2; subSidebar.hoveredCardObj = rCard2 }
                        else if (subSidebar.hoveredCardObj === rCard2) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 2
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰏫"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (rMouse2.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: "Рисование"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (rMouse2.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 2; checked: Config ? Config.screenDrawEnabled : true; onToggled: if (Config) Config.screenDrawEnabled = checked }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: subTab
        opacity: recRoot.subPageAlpha
        scale: recRoot.subPageScale
        transform: Translate { y: recRoot.subPageOffsetY }

        // =====================================================================
        // ПОДВКЛАДКА 0: ЗАПИСЬ ЭКРАНА
        // =====================================================================
        ScrollView {
            id: scrRec; contentWidth: availableWidth; clip: true
            Item {
                width: scrRec.availableWidth; implicitHeight: colRecMain.implicitHeight + 44
                ColumnLayout {
                    id: colRecMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "Запись экрана (GPU Screen Recorder)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true; Layout.fillWidth: true }
                        Rectangle {
                            height: 26
                            radius: (Theme && Theme.isRounded) ? 13 : 0
                            width: recBadgeTxt.implicitWidth + 18
                            color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.25, 0.25, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.35, 0.35, 0.65) : Qt.rgba(1, 1, 1, 0.16)
                            Text {
                                id: recBadgeTxt; anchors.centerIn: parent
                                text: (Waybar && Waybar.recording) ? ("● ЗАПИСЬ  " + Waybar.recordingTimeText) : "Super + F10"
                                color: (Waybar && Waybar.recording) ? "#ff6b6b" : "#cccccc"
                                font.pixelSize: Config.fontSize - 1; font.bold: true
                            }
                        }
                        StyledButton {
                            text: (Waybar && Waybar.recording) ? "󰓛  Стоп" : "󰑋  Записать"
                            onClicked: if (Config) Config.toggleScreenRecording()
                        }
                        StyledButton {
                            text: "󰉋  Папка"
                            onClicked: if (Config) Config.openRecordDir()
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colRecVideo.implicitHeight + 22
                        ColumnLayout {
                            id: colRecVideo; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text { text: "Параметры видео и кодировщика"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Частота кадров (FPS):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var fpsVals: [30, 60, 90, 120, 160]
                                    options: ["30", "60", "90", "120", "160"]
                                    selectedIndex: Math.max(0, fpsVals.indexOf(Config ? Config.recFps : 60))
                                    onSelected: (idx) => { if (Config) Config.recFps = fpsVals[idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Видеокодек:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var vals: ["h264", "hevc", "av1"]
                                    options: ["H.264", "HEVC (H.265)", "AV1"]
                                    selectedIndex: Math.max(0, vals.indexOf(Config ? Config.recCodec : "h264"))
                                    onSelected: (idx) => { if (Config) Config.recCodec = vals[idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Качество записи:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var vals: ["medium", "high", "very_high", "ultra"]
                                    options: ["Среднее", "Высокое", "Очень выс.", "Ультра"]
                                    selectedIndex: Math.max(0, vals.indexOf(Config ? Config.recQuality : "very_high"))
                                    onSelected: (idx) => { if (Config) Config.recQuality = vals[idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Контейнер:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var vals: ["mp4", "mkv"]
                                    options: ["MP4", "MKV"]
                                    selectedIndex: Math.max(0, vals.indexOf(Config ? Config.recContainer : "mp4"))
                                    onSelected: (idx) => { if (Config) Config.recContainer = vals[idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Кодировщик:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var vals: ["gpu_fallback", "gpu", "cpu"]
                                    options: ["GPU (авто CPU)", "Только GPU", "CPU"]
                                    selectedIndex: Math.max(0, vals.indexOf(Config ? Config.recEncoder : "gpu_fallback"))
                                    onSelected: (idx) => { if (Config) Config.recEncoder = vals[idx] }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colRecAudio.implicitHeight + 22
                        ColumnLayout {
                            id: colRecAudio; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text { text: "Звук, папка и поведение"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Источник звука:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Система", "Микрофон", "Всё вместе", "Без звука"]
                                    selectedIndex: Config ? Config.recAudioMode : 0
                                    onSelected: (idx) => { if (Config) Config.recAudioMode = idx }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { text: "Папка записей:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                TextField {
                                    Layout.fillWidth: true; height: 30
                                    text: Config ? Config.recDir : ""
                                    color: "#ffffff"; font.pixelSize: Config.fontSize
                                    selectByMouse: true
                                    onEditingFinished: if (Config && text.trim().length > 0) Config.recDir = text.trim()
                                    background: Rectangle {
                                        radius: (Theme && Theme.isRounded) ? (Config ? Config.m3ControlRadius : 8) : 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: parent.activeFocus ? Config.accentColor : Qt.rgba(1, 1, 1, 0.16)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Записывать курсор мыши:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.recCursor : true; onToggled: if (Config) Config.recCursor = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Копировать видеофайл в буфер обмена после остановки:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.recCopyClipboard : true; onToggled: if (Config) Config.recCopyClipboard = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Показывать уведомления о старте и сохранении:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.recNotify : true; onToggled: if (Config) Config.recNotify = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                StyledButton { text: "↺  Сбросить настройки съёмки"; onClicked: if (Config) Config.resetCaptureDefaults() }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ПОДВКЛАДКА 1: СКРИНШОТЫ
        // =====================================================================
        ScrollView {
            id: scrShot; contentWidth: availableWidth; clip: true
            Item {
                width: scrShot.availableWidth; implicitHeight: colShotMain.implicitHeight + 44
                ColumnLayout {
                    id: colShotMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "Скриншоты (Grim + Slurp)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true; Layout.fillWidth: true }
                        StyledButton { text: "󰹑  Весь экран"; onClicked: if (Config) Config.takeScreenshot("full") }
                        StyledButton { text: "󰆞  Область"; onClicked: if (Config) Config.takeScreenshot("region") }
                        StyledButton { text: "󰉋  Папка"; onClicked: if (Config) Config.openScreenDir() }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colShotFmt.implicitHeight + 22
                        ColumnLayout {
                            id: colShotFmt; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text { text: "Формат, задержка и сохранение"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Формат изображения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 195 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    property var vals: ["png", "jpg"]
                                    options: ["PNG (без потерь)", "JPEG (меньше вес)"]
                                    selectedIndex: Math.max(0, vals.indexOf(Config ? Config.scrFormat : "png"))
                                    onSelected: (idx) => { if (Config) Config.scrFormat = vals[idx] }
                                }
                            }

                            RowLayout {
                                visible: Config && Config.scrFormat === "jpg"
                                Layout.fillWidth: true
                                Text { text: "Качество JPEG: " + (Config ? Config.scrJpegQuality : 92) + "%"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 50; to: 100; stepSize: 2
                                    value: Config ? Config.scrJpegQuality : 92
                                    onMoved: if (Config) Config.scrJpegQuality = Math.round(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Задержка перед снимком экрана: " + (Config ? Config.scrDelay : 0) + " сек"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 250 }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 10; stepSize: 1
                                    value: Config ? Config.scrDelay : 0
                                    onMoved: if (Config) Config.scrDelay = Math.round(value)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { text: "Папка скриншотов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 195 }
                                TextField {
                                    Layout.fillWidth: true; height: 30
                                    text: Config ? Config.scrDir : ""
                                    color: "#ffffff"; font.pixelSize: Config.fontSize
                                    selectByMouse: true
                                    onEditingFinished: if (Config && text.trim().length > 0) Config.scrDir = text.trim()
                                    background: Rectangle {
                                        radius: (Theme && Theme.isRounded) ? (Config ? Config.m3ControlRadius : 8) : 0
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        border.width: 1
                                        border.color: parent.activeFocus ? Config.accentColor : Qt.rgba(1, 1, 1, 0.16)
                                    }
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colShotBeh.implicitHeight + 22
                        ColumnLayout {
                            id: colShotBeh; anchors.fill: parent; anchors.margins: 13; spacing: 10

                            Text { text: "Поведение и выделение области"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Замораживать экран при выделении области (hyprpicker):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.scrFreezeRegion : true; onToggled: if (Config) Config.scrFreezeRegion = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Захватывать курсор мыши на скриншоте:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.scrCursor : false; onToggled: if (Config) Config.scrCursor = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Сохранять файл скриншота в папку:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.scrSaveFile : true; onToggled: if (Config) Config.scrSaveFile = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Копировать скриншот в буфер обмена:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.scrCopyClipboard : true; onToggled: if (Config) Config.scrCopyClipboard = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Показывать уведомление после скриншота:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.scrNotify : true; onToggled: if (Config) Config.scrNotify = checked }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colShotKeys.implicitHeight + 22
                        ColumnLayout {
                            id: colShotKeys; anchors.fill: parent; anchors.margins: 13; spacing: 7

                            Text { text: "⌨  Горячие клавиши скриншотов"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            Repeater {
                                model: [
                                    { k: "Print", d: "Скриншот всего экрана" },
                                    { k: "Super + Shift + S", d: "Скриншот выделенной области" },
                                    { k: "СКМ (колёсико)", d: "Быстрый скриншот выделенной области" }
                                ]
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Rectangle {
                                        Layout.preferredWidth: 150; height: 24
                                        radius: (Theme && Theme.isRounded) ? 6 : 0
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                                        Text { anchors.centerIn: parent; text: modelData.k; color: "#ffffff"; font.pixelSize: Config.fontSize - 1; font.bold: true }
                                    }
                                    Text { text: modelData.d; color: "#cccccc"; font.pixelSize: Config.fontSize - 1; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // ПОДВКЛАДКА 2: РИСОВАНИЕ ПОВЕРХ ЭКРАНА
        // =====================================================================
        ScrollView {
            id: scrDraw; contentWidth: availableWidth; clip: true
            Item {
                width: scrDraw.availableWidth; implicitHeight: colDrawMain.implicitHeight + 44
                ColumnLayout {
                    id: colDrawMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "Рисование поверх экрана"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true; Layout.fillWidth: true }
                        Rectangle {
                            height: 26
                            radius: (Theme && Theme.isRounded) ? 13 : 0
                            width: drawRecLbl.implicitWidth + 18
                            color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.25, 0.25, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.35, 0.35, 0.65) : Qt.rgba(1, 1, 1, 0.16)
                            Text {
                                id: drawRecLbl; anchors.centerIn: parent
                                text: (Waybar && Waybar.recording) ? "● Идёт запись" : "ALT + ~ (Ё)"
                                color: (Waybar && Waybar.recording) ? "#ff6b6b" : "#cccccc"
                                font.pixelSize: Config.fontSize - 1; font.bold: true
                            }
                        }
                        StyledButton {
                            text: "󰏫  Тест на экране"
                            onClicked: if (ScreenDraw) ScreenDraw.requestTest()
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawBrush.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawBrush; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text { text: "Кисть, цвет и свечение по краям"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            Rectangle {
                                Layout.fillWidth: true; height: 82
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: Qt.rgba(0.05, 0.05, 0.07, 0.92)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10)
                                clip: true

                                Canvas {
                                    id: drawPreviewCanvas
                                    anchors.fill: parent; antialiasing: true

                                    Connections {
                                        target: Config
                                        function onScreenDrawChanged() { drawPreviewCanvas.requestPaint() }
                                        function onAccentColorChanged() { drawPreviewCanvas.requestPaint() }
                                    }
                                    Component.onCompleted: requestPaint()

                                    function parseCol(hexStr) {
                                        var s = String(hexStr || "#ff3b5c").trim()
                                        if (s.charAt(0) === "#") s = s.slice(1)
                                        if (s.length === 8) s = s.slice(2)
                                        if (s.length !== 6) return { r: 255, g: 59, b: 92 }
                                        return { r: parseInt(s.slice(0,2), 16), g: parseInt(s.slice(2,4), 16), b: parseInt(s.slice(4,6), 16) }
                                    }

                                    function traceDemo(ctx) {
                                        ctx.beginPath()
                                        var h = height * 0.52
                                        var left = 26, right = width - 110
                                        var span = Math.max(80, right - left)
                                        ctx.moveTo(left, h + 10)
                                        ctx.bezierCurveTo(left + span * 0.25, h - 26, left + span * 0.45, h + 28, left + span * 0.72, h - 14)
                                        ctx.quadraticCurveTo(left + span * 0.88, h - 30, right, h + 6)
                                        var ax0 = width - 86, ay0 = h + 14, ax1 = width - 26, ay1 = h - 14
                                        ctx.moveTo(ax0, ay0); ctx.lineTo(ax1, ay1)
                                        var ang = Math.atan2(ay1 - ay0, ax1 - ax0), hl = 13
                                        ctx.moveTo(ax1, ay1); ctx.lineTo(ax1 - hl * Math.cos(ang - 0.5), ay1 - hl * Math.sin(ang - 0.5))
                                        ctx.moveTo(ax1, ay1); ctx.lineTo(ax1 - hl * Math.cos(ang + 0.5), ay1 - hl * Math.sin(ang + 0.5))
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = "rgba(255,255,255,0.04)"
                                        ctx.lineWidth = 1
                                        for (var gx = 20; gx < width; gx += 24) { ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke() }
                                        for (var gy = 18; gy < height; gy += 24) { ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke() }

                                        var colHex = (Config && Config.screenDrawUseThemeColor) ? Config.m3Primary.toString() : (Config ? Config.screenDrawColor.toString() : "#ff3b5c")
                                        var rgb = parseCol(colHex)
                                        var r = rgb.r, g = rgb.g, b = rgb.b
                                        var w = Config ? Config.screenDrawLineWidth : 5.0
                                        var st = Config ? Config.screenDrawBrushStyle : 1
                                        var gs = Config ? Config.screenDrawGlowStrength : 0.9
                                        var gm = Math.min(1.4, gs)

                                        ctx.lineCap = "round"; ctx.lineJoin = "round"
                                        if (st === 0) {
                                            traceDemo(ctx); ctx.lineWidth = w; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ",0.96)"; ctx.stroke()
                                        } else if (st === 1) {
                                            if (gs > 0.01) {
                                                traceDemo(ctx); ctx.lineWidth = w + 20 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.08 * gm).toFixed(3) + ")"; ctx.stroke()
                                                traceDemo(ctx); ctx.lineWidth = w + 11 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.18 * gm).toFixed(3) + ")"; ctx.stroke()
                                                traceDemo(ctx); ctx.lineWidth = w + 5 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.42 * gm).toFixed(3) + ")"; ctx.stroke()
                                            }
                                            var er = Math.min(255, Math.round(r * 0.28 + 255 * 0.72))
                                            var eg = Math.min(255, Math.round(g * 0.28 + 255 * 0.72))
                                            var eb = Math.min(255, Math.round(b * 0.28 + 255 * 0.72))
                                            traceDemo(ctx); ctx.lineWidth = w + 1.8; ctx.strokeStyle = "rgba(" + er + "," + eg + "," + eb + ",0.95)"; ctx.stroke()
                                            traceDemo(ctx); ctx.lineWidth = Math.max(1.2, w * 0.58); ctx.strokeStyle = "rgba(" + Math.round(r * 0.56) + "," + Math.round(g * 0.56) + "," + Math.round(b * 0.56) + ",0.94)"; ctx.stroke()
                                        } else {
                                            if (gs > 0.01) {
                                                traceDemo(ctx); ctx.lineWidth = w + 24 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.10 * gm).toFixed(3) + ")"; ctx.stroke()
                                                traceDemo(ctx); ctx.lineWidth = w + 13 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.24 * gm).toFixed(3) + ")"; ctx.stroke()
                                                traceDemo(ctx); ctx.lineWidth = w + 5.5 * gs; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + "," + (0.52 * gm).toFixed(3) + ")"; ctx.stroke()
                                            }
                                            traceDemo(ctx); ctx.lineWidth = w; ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ",0.96)"; ctx.stroke()
                                            var lr = Math.min(255, Math.round(r * 0.18 + 255 * 0.82))
                                            var lg = Math.min(255, Math.round(g * 0.18 + 255 * 0.82))
                                            var lb = Math.min(255, Math.round(b * 0.18 + 255 * 0.82))
                                            traceDemo(ctx); ctx.lineWidth = Math.max(1.2, w * 0.42); ctx.strokeStyle = "rgba(" + lr + "," + lg + "," + lb + ",0.98)"; ctx.stroke()
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Стиль линии:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Обычная", "Светящиеся края", "Неоновый лазер"]
                                    selectedIndex: Config ? Config.screenDrawBrushStyle : 1
                                    onSelected: (idx) => { if (Config) Config.screenDrawBrushStyle = idx }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { text: "Цвет кисти:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 177 }
                                Repeater {
                                    model: ["#ff3b5c", "#00e5ff", "#39ff14", "#ffea00", "#c060ff", "#ff7a00", "#4d88ff", "#ffffff"]
                                    Rectangle {
                                        width: 24; height: 24
                                        radius: (Theme && Theme.isRounded) ? 12 : 0
                                        color: modelData
                                        property bool isSel: Config && !Config.screenDrawUseThemeColor && Config.screenDrawColor.toString().toLowerCase() === modelData.toLowerCase()
                                        border.width: isSel ? 2.5 : 1
                                        border.color: isSel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.28)
                                        scale: isSel ? 1.12 : (swMouse.containsMouse ? 1.07 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                        MouseArea {
                                            id: swMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (Config) { Config.screenDrawUseThemeColor = false; Config.screenDrawColor = modelData } }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                StyledButton {
                                    text: "󰏘  " + (Config ? Config.screenDrawColor.toString().toUpperCase() : "#FF3B5C")
                                    onClicked: drawColorModal.openPicker("Цвет кисти рисования", Config ? Config.screenDrawColor : "#ff3b5c")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Брать цвет из активной темы обоев:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.screenDrawUseThemeColor : false; onToggled: if (Config) Config.screenDrawUseThemeColor = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Толщина линии: " + (Config ? Config.screenDrawLineWidth.toFixed(1) : "5.0") + " px"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider {
                                    Layout.fillWidth: true; from: 1.5; to: 24.0; stepSize: 0.5
                                    value: Config ? Config.screenDrawLineWidth : 5.0
                                    onMoved: if (Config) Config.screenDrawLineWidth = value
                                }
                            }

                            RowLayout {
                                visible: Config && Config.screenDrawBrushStyle !== 0
                                Layout.fillWidth: true
                                Text { text: "Сила свечения по краям: " + Math.round((Config ? Config.screenDrawGlowStrength : 0.9) * 100) + "%"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider {
                                    Layout.fillWidth: true; from: 0.0; to: 1.5; stepSize: 0.05
                                    value: Config ? Config.screenDrawGlowStrength : 0.9
                                    onMoved: if (Config) Config.screenDrawGlowStrength = value
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawTiming.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawTiming; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text { text: "Таймеры исчезновения и бинд"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Активировать только во время записи экрана (Super + F10):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.screenDrawOnlyRecording : true; onToggled: if (Config) Config.screenDrawOnlyRecording = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Режим клавиши ALT + ~ (Ё):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Удержание клавиши", "Нажал — вкл / выкл"]
                                    selectedIndex: Config ? Config.screenDrawMode : 0
                                    onSelected: (idx) => { if (Config) Config.screenDrawMode = idx }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Держать линии после отпускания: " + (Config ? Config.screenDrawFadeDelay.toFixed(1) : "2.5") + " сек"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider {
                                    Layout.fillWidth: true; from: 0.0; to: 15.0; stepSize: 0.5
                                    value: Config ? Config.screenDrawFadeDelay : 2.5
                                    onMoved: if (Config) Config.screenDrawFadeDelay = value
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Плавность исчезновения: " + (Config ? Config.screenDrawFadeDuration.toFixed(1) : "0.8") + " сек"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider {
                                    Layout.fillWidth: true; from: 0.1; to: 4.0; stepSize: 0.1
                                    value: Config ? Config.screenDrawFadeDuration : 0.8
                                    onMoved: if (Config) Config.screenDrawFadeDuration = value
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Показывать кольцо кисти вокруг курсора при рисовании:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config ? Config.screenDrawShowHint : true; onToggled: if (Config) Config.screenDrawShowHint = checked }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawKeys.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawKeys; anchors.fill: parent; anchors.margins: 13; spacing: 7

                            Text { text: "⌨  Управление во время рисования"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            Repeater {
                                model: [
                                    { k: "ALT + ~ (Ё)", d: "Удерживать и рисовать (EN / RU раскладки; ввод возвращается сразу после отпускания)" },
                                    { k: "ЛКМ", d: "Плавная свободная линия со сглаживанием" },
                                    { k: "Shift + ЛКМ", d: "Ровная стрелка для указания на элемент" },
                                    { k: "Ctrl + ЛКМ", d: "Скруглённая рамка для выделения области" },
                                    { k: "ПКМ  /  Z", d: "Отменить последний штрих" },
                                    { k: "Колесо мыши", d: "Быстро изменить толщину кисти на лету" },
                                    { k: "1 – 7  /  C  /  Esc", d: "Быстрая смена цвета / стереть всё / выйти" }
                                ]
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Rectangle {
                                        Layout.preferredWidth: 150; height: 24
                                        radius: (Theme && Theme.isRounded) ? 6 : 0
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.16)
                                        Text { anchors.centerIn: parent; text: modelData.k; color: "#ffffff"; font.pixelSize: Config.fontSize - 1; font.bold: true }
                                    }
                                    Text { text: modelData.d; color: "#cccccc"; font.pixelSize: Config.fontSize - 1; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
