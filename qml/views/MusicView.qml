import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: musicRoot
    property var winObj: ApplicationWindow.window
    readonly property bool isM3: Theme && Theme.isRounded
    property string trackSearchQuery: ""
    onTrackSearchQueryChanged: trackListContainer.rebuildTrackModel()

    // 0 = Плеер и плейлисты, 1 = Настройки и синхронизация
    property int subTab: (winObj && winObj.musicSubTab !== undefined) ? winObj.musicSubTab : 0
    onSubTabChanged: {
        if (winObj && winObj.musicSubTab !== subTab) winObj.musicSubTab = subTab
    }

    Connections {
        target: winObj
        function onMusicSubTabChanged() {
            if (winObj && musicRoot.subTab !== winObj.musicSubTab)
                musicRoot.subTab = winObj.musicSubTab
        }
    }

    Connections {
        target: Waybar
        function onYmLibraryChanged() {
            trackListContainer.rebuildTrackModel()
        }
    }

    Component.onCompleted: {
        if (visible) Qt.callLater(() => subSidebar.playStaircase())
        if (Waybar) Waybar.refreshYmLibrary()
        trackListContainer.rebuildTrackModel()
    }

    onVisibleChanged: if (visible) {
        subSidebar.playStaircase()
        if (Waybar) Waybar.refreshYmLibrary()
        trackListContainer.rebuildTrackModel()
    }

    component IconHeader: RowLayout {
        property string iconGlyph: "󰎆"
        property string titleText: ""
        property int extraFont: 3
        property color iconColor: Config ? Config.m3Primary : "#ffffff"
        property color textColor: musicRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
        spacing: 10

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            Text {
                anchors.centerIn: parent
                text: parent.parent.iconGlyph
                color: parent.parent.iconColor
                font.pixelSize: Config.fontSize + parent.parent.extraFont + 1
            }
        }

        Text {
            text: parent.titleText
            color: parent.textColor
            font.pixelSize: Config.fontSize + parent.extraFont
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // =========================================================================
    // ЛЕВАЯ БОКОВАЯ ПАНЕЛЬ РАЗДЕЛОВ МУЗЫКИ
    // =========================================================================
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
                xScale: att.sc; yScale: att.sc
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
                    att.dY = 0.0; att.dX = 0.0; att.sc = 1.0
                }
            }
        }

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: musicRoot.isM3 ? 178 : 158
        color: "transparent"

        property Item activeCardObj: musicRoot.subTab === 0 ? mCard0 : mCard1
        property Item hoveredCardObj: null
        property Item lastHoveredCardObj: null

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: musicRoot.isM3 && Config
                   ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.22)
                   : Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: musicHoverPill
            x: 6
            width: subSidebar.width - 12
            height: 32
            radius: musicRoot.isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 10) : 0
            color: musicRoot.isM3 && Config
                   ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12)
                   : Qt.rgba(1, 1, 1, 0.08)
            opacity: subSidebar.hoveredCardObj && subSidebar.hoveredCardObj !== subSidebar.activeCardObj ? 1.0 : 0.0
            y: subSidebar.lastHoveredCardObj ? (subCol.y + subSidebar.lastHoveredCardObj.y) : 38
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: musicActivePill
            SubCascadeAttach { stepIdx: musicRoot.subTab + 1 }
            x: 6
            width: subSidebar.width - 12
            height: 32
            radius: musicRoot.isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 10) : 0
            color: musicRoot.isM3 && Config ? Config.m3Primary : (Config ? Config.accentColor : "#ffffff")
            y: subSidebar.activeCardObj ? (subCol.y + subSidebar.activeCardObj.y) : 38
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }

        ColumnLayout {
            id: subCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 6
                Layout.leftMargin: 6
                spacing: 8
                Item {
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: Config ? Config.m3Primary : "#ffffff"
                        font.pixelSize: Config.fontSize + 2
                    }
                }
                SubCascadeAttach { stepIdx: 0 }
                Text {
                    text: "Музыка"
                    color: musicRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: musicRoot.isM3 && Config
                       ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18)
                       : Qt.rgba(1, 1, 1, 0.06)
                Layout.bottomMargin: 2
            }

            Item {
                id: mCard0; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 1 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: musicRoot.subTab = 0
                    onEntered: { subSidebar.lastHoveredCardObj = mCard0; subSidebar.hoveredCardObj = mCard0 }
                    onExited: if (subSidebar.hoveredCardObj === mCard0) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: "󰎆"
                            color: musicRoot.subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === mCard0 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize + 1
                        }
                    }
                    Text {
                        text: "Плеер"
                        color: musicRoot.subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === mCard0 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: musicRoot.subTab === 0; Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: Waybar && Waybar.mediaPlaying
                        width: 7; height: 7; radius: 3.5
                        color: musicRoot.subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
                    }
                }
            }

            Item {
                id: mCard1; Layout.fillWidth: true; implicitHeight: 32
                SubCascadeAttach { stepIdx: 2 }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: musicRoot.subTab = 1
                    onEntered: { subSidebar.lastHoveredCardObj = mCard1; subSidebar.hoveredCardObj = mCard1 }
                    onExited: if (subSidebar.hoveredCardObj === mCard1) subSidebar.hoveredCardObj = null
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 10
                    Item {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        Text {
                            anchors.centerIn: parent; text: "󰒓"
                            color: musicRoot.subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === mCard1 ? "#ffffff" : "#bbbbbb")
                            font.pixelSize: Config.fontSize + 1
                        }
                    }
                    Text {
                        text: "Настройки"
                        color: musicRoot.subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (subSidebar.hoveredCardObj === mCard1 ? "#ffffff" : "#bbbbbb")
                        font.pixelSize: Config.fontSize; font.bold: musicRoot.subTab === 1; Layout.fillWidth: true
                    }
                    Rectangle {
                        visible: Waybar && Waybar.ymBusy
                        width: 7; height: 7; radius: 3.5
                        color: musicRoot.subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : "#ffd54f"
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledButton {
                Layout.fillWidth: true
                allowFullWidth: true
                implicitHeight: 30
                text: "󰓇 Включить волну"
                onClicked: if (Waybar) Waybar.playYmMyWave()
            }

            GlassPanel {
                visible: Waybar && Waybar.ymBusy
                Layout.fillWidth: true
                implicitHeight: miniSyncCol.implicitHeight + 16
                ColumnLayout {
                    id: miniSyncCol
                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                    RowLayout {
                        spacing: 6
                        Text { text: "󰇚"; color: Config ? Config.m3Primary : "#69f0ae"; font.pixelSize: Config.fontSize }
                        Text {
                            text: "Загрузка: " + (Waybar ? Waybar.ymProgress : 0) + "%"
                            color: Config ? Config.m3Primary : "#69f0ae"
                            font.pixelSize: Config.fontSize - 2; font.bold: true
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 4; radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        Rectangle {
                            width: parent.width * Math.max(0.05, Math.min(1.0, (Waybar ? Waybar.ymProgress : 0) / 100.0))
                            height: parent.height; radius: 2
                            color: Config ? Config.m3Primary : "#69f0ae"
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // ПРАВАЯ ОБЛАСТЬ СОДЕРЖИМОГО
    // =========================================================================
    Item {
        id: contentArea
        anchors.left: subSidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // ---------------------------------------------------------------------
        // ВКЛАДКА 0: ПЛЕЕР И ПЛЕЙЛИСТЫ С МИНИАТЮРАМИ
        // ---------------------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: musicRoot.subTab === 0

            ColumnLayout {
                width: Math.min(parent.width - 44, 840)
                height: parent.height - 32
                anchors.centerIn: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: "󰎆"
                        titleText: "Музыкальный плеер и плейлисты"
                    }
                    StyledButton {
                        text: "󰓇 Моя волна"
                        implicitHeight: 26
                        onClicked: if (Waybar) Waybar.playYmMyWave()
                    }
                    StyledButton {
                        text: "󰉋 Папка"
                        implicitHeight: 26
                        onClicked: if (Waybar) Waybar.openYmMusicFolder()
                    }
                    StyledButton {
                        text: (Waybar && Waybar.mediaDemoMode) ? "󰎆 Скрыть демо" : "󰎆 Пример"
                        implicitHeight: 26
                        isActive: Waybar ? Waybar.mediaDemoMode : false
                        onClicked: if (Waybar) Waybar.toggleMediaDemo()
                    }
                }

                // Карточка активного плеера с обложкой
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: playerCardCol.implicitHeight + 24

                    ColumnLayout {
                        id: playerCardCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                id: mainCoverBox
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                radius: musicRoot.isM3 ? 12 : 0
                                color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.12)
                                border.color: Config ? Config.m3Primary : "#ffffff"
                                border.width: 1
                                clip: true

                                Image {
                                    id: activeCoverImg
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: status === Image.Ready && (Waybar && Waybar.mediaCoverPath.length > 0)
                                    source: (Waybar && Waybar.mediaCoverPath.length > 0) ? ("file://" + Waybar.mediaCoverPath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }

                                Text {
                                    visible: !activeCoverImg.visible
                                    anchors.centerIn: parent
                                    text: "󰎆"
                                    font.pixelSize: 28
                                    color: Config ? Config.m3Primary : "#ffffff"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: (Waybar && Waybar.mediaTitle.length > 0) ? Waybar.mediaTitle : "Выберите трек или нажмите «Моя волна»"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 2
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: {
                                            if (!Waybar) return ""
                                            if (Waybar.mediaDemoMode && !Waybar.hasRealMedia) return "Демо-режим"
                                            return Waybar.mediaPlaying ? "Воспроизводится" : "На паузе"
                                        }
                                        color: Waybar && Waybar.mediaPlaying ? (Config ? Config.m3Primary : "#69f0ae") : "#999999"
                                        font.pixelSize: Config.fontSize - 1
                                    }
                                    Text {
                                        text: "•   " + ((Waybar && Waybar.ymShuffle) ? "󰒟  Вразнобой" : "󰒝  Подряд")
                                        color: "#888888"
                                        font.pixelSize: Config.fontSize - 1
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 6
                                StyledButton { text: "󰒮"; isIconOnly: true; implicitWidth: 32; implicitHeight: 30; onClicked: if (Waybar) Waybar.mediaPrev() }
                                StyledButton { text: "-10с"; implicitWidth: 42; implicitHeight: 30; onClicked: if (Waybar) Waybar.mediaSeek(-10) }
                                StyledButton {
                                    text: (Waybar && Waybar.mediaPlaying) ? "󰏤 Пауза" : "󰐊 Играть"
                                    implicitWidth: 92; implicitHeight: 32
                                    isActive: Waybar ? Waybar.mediaPlaying : false
                                    onClicked: if (Waybar) Waybar.mediaPlayPause()
                                }
                                StyledButton { text: "+10с"; implicitWidth: 42; implicitHeight: 30; onClicked: if (Waybar) Waybar.mediaSeek(10) }
                                StyledButton { text: "󰒭"; isIconOnly: true; implicitWidth: 32; implicitHeight: 30; onClicked: if (Waybar) Waybar.mediaNext() }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: Waybar ? Waybar.mediaPositionText : "00:00"
                                color: "#bbbbbb"
                                font.pixelSize: Config.fontSize - 1
                                font.features: { "tnum": 1 }
                            }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: Waybar ? Math.max(1, Waybar.mediaLengthSec) : 215
                                stepSize: 1
                                value: Waybar ? Waybar.mediaPosSec : 0
                                onMoved: if (Waybar) Waybar.seekToSecond(Math.round(value))
                            }
                            Text {
                                text: Waybar ? Waybar.mediaDurationText : "03:35"
                                color: "#bbbbbb"
                                font.pixelSize: Config.fontSize - 1
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }

                // Карточка плейлистов и треков с обложками, анимированным перетаскиванием и плавным наведением
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        // РЯД 1: ВКЛАДКИ ПЛЕЙЛИСТОВ (ВСЕГДА ПОЛНОСТЬЮ ВИДНЫ)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item {
                                id: plTabBar
                                Layout.fillWidth: true
                                implicitHeight: Math.max(28, plTabFlow.implicitHeight)
                                property Item activeItem: null
                                property Item hoveredItem: null
                                property Item lastHoveredItem: null

                                Rectangle {
                                    z: 1
                                    opacity: (plTabBar.hoveredItem && plTabBar.hoveredItem !== plTabBar.activeItem) ? 1.0 : 0.0
                                    x: plTabBar.lastHoveredItem ? plTabBar.lastHoveredItem.x : 0
                                    y: plTabBar.lastHoveredItem ? plTabBar.lastHoveredItem.y : 0
                                    width: plTabBar.lastHoveredItem ? plTabBar.lastHoveredItem.width : 90
                                    height: 28
                                    radius: musicRoot.isM3 ? 8 : 0
                                    color: musicRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18)
                                           : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                    border.color: musicRoot.isM3 && Config
                                                  ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.42)
                                                  : Qt.rgba(1, 1, 1, 0.24)
                                    Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                    Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.OutQuint } }
                                    Behavior on opacity { NumberAnimation { duration: 110 } }
                                }

                                Rectangle {
                                    z: 2
                                    visible: plTabBar.activeItem !== null
                                    x: plTabBar.activeItem ? plTabBar.activeItem.x : 0
                                    y: plTabBar.activeItem ? plTabBar.activeItem.y : 0
                                    width: plTabBar.activeItem ? plTabBar.activeItem.width : 90
                                    height: 28
                                    radius: musicRoot.isM3 ? 8 : 0
                                    color: Config ? Config.m3Primary : "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                                }

                                Flow {
                                    id: plTabFlow
                                    z: 3
                                    width: parent.width
                                    spacing: 6

                                    Repeater {
                                        model: Waybar ? Waybar.ymPlaylists : []
                                        delegate: Item {
                                            id: plBtn
                                            width: plBtnRow.implicitWidth + 22
                                            height: 28
                                            readonly property bool isSel: Waybar ? (Waybar.ymSelectedPlaylist === index) : (index === 0)
                                            onIsSelChanged: if (isSel) plTabBar.activeItem = plBtn
                                            Component.onCompleted: if (isSel) plTabBar.activeItem = plBtn

                                            Rectangle {
                                                anchors.fill: parent
                                                z: -1
                                                radius: musicRoot.isM3 ? 8 : 0
                                                color: plBtn.isSel
                                                       ? "transparent"
                                                       : (musicRoot.isM3 && Config
                                                          ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.42)
                                                          : Qt.rgba(1, 1, 1, 0.06))
                                                border.color: plBtn.isSel ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
                                                border.width: musicRoot.isM3 ? 0 : 1
                                            }

                                            Row {
                                                id: plBtnRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.title === "Мне нравится"
                                                          ? "cards-heart" in ({}) ? "󰐑" : "󰋑"
                                                          : (modelData.title === "Моя волна" ? "󰓇" : (modelData.title === "Скрытые" ? "󰈉" : "󰲸"))
                                                    font.pixelSize: Config.fontSize
                                                    color: plBtnTxt.color
                                                }

                                                Text {
                                                    id: plBtnTxt
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.title + " • " + modelData.count
                                                    font.pixelSize: Config.fontSize - 1
                                                    font.bold: plBtn.isSel
                                                    color: plBtn.isSel
                                                           ? (Config ? Config.accentTextColor : "#000000")
                                                           : (musicRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#e0e0e0")
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: { plTabBar.lastHoveredItem = plBtn; plTabBar.hoveredItem = plBtn }
                                                onExited: if (plTabBar.hoveredItem === plBtn) plTabBar.hoveredItem = null
                                                onPressed: {
                                                    if (Waybar) {
                                                        Waybar.ymSelectedPlaylist = index
                                                        trackListContainer.rebuildTrackModel()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            StyledButton {
                                text: "󰑐"
                                isIconOnly: true
                                implicitWidth: 28; implicitHeight: 28
                                Layout.alignment: Qt.AlignTop
                                onClicked: if (Waybar) Waybar.refreshYmLibrary()
                            }
                        }

                        // РЯД 2: РЕЖИМ ВОСПРОИЗВЕДЕНИЯ (ПОДРЯД / ВРАЗНОБОЙ) И ПОИСК ТРЕКА
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            SegmentedButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 230
                                implicitHeight: 28
                                options: ["󰒝  Подряд", "󰒟  Вразнобой"]
                                selectedIndex: (Waybar && Waybar.ymShuffle) ? 1 : 0
                                onSelected: (idx) => { if (Waybar) Waybar.ymShuffle = (idx === 1) }
                            }

                            TextField {
                                id: trSearchField
                                Layout.fillWidth: true
                                Layout.preferredWidth: 260
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 24
                                color: "#ffffff"; font.pixelSize: 11
                                placeholderText: "󰍉  Поиск трека в плейлисте..."
                                placeholderTextColor: "#777777"
                                text: musicRoot.trackSearchQuery
                                onTextEdited: musicRoot.trackSearchQuery = text
                                background: Rectangle {
                                    radius: musicRoot.isM3 ? 8 : 0
                                    color: musicRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: musicRoot.isM3 ? 0 : 1
                                }
                                Text {
                                    visible: trSearchField.text.length > 0
                                    anchors.right: parent.right; anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰅖"; color: "#aaaaaa"; font.pixelSize: 11
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { trSearchField.text = ""; musicRoot.trackSearchQuery = "" }
                                    }
                                }
                            }
                        }

                        // Список треков с живым анимированным перетаскиванием (ListModel.move) и плавной плашкой наведения
                        Item {
                            id: trackListContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            property bool isHovering: false
                            property int lastHoveredRow: 0
                            property int draggingRow: -1

                            ListModel {
                                id: trackListModel
                            }

                            Timer {
                                id: trackHoverHold
                                interval: 45
                                onTriggered: if (trackListContainer.draggingRow < 0) trackListContainer.isHovering = false
                            }

                            readonly property var currentPlaylistObj: {
                                if (!Waybar || Waybar.ymPlaylists.length === 0) return null
                                var idx = Math.max(0, Math.min(Waybar.ymPlaylists.length - 1, Waybar.ymSelectedPlaylist))
                                return Waybar.ymPlaylists[idx]
                            }

                            readonly property bool isHiddenPlaylist: currentPlaylistObj ? (currentPlaylistObj.title === "Скрытые") : false

                            function rebuildTrackModel() {
                                if (draggingRow >= 0) return
                                var savedY = tracksListView.contentY
                                trackListModel.clear()
                                if (!currentPlaylistObj || !currentPlaylistObj.tracks) return
                                var raw = currentPlaylistObj.tracks
                                var q = musicRoot.trackSearchQuery.trim().toLowerCase()
                                for (var i = 0; i < raw.length; ++i) {
                                    var t = raw[i]
                                    if (q.length > 0) {
                                        var ft = (t.fullTitle || "").toLowerCase()
                                        if (ft.indexOf(q) === -1) continue
                                    }
                                    trackListModel.append({
                                        realIdx: i,
                                        title: t.title || "",
                                        artist: t.artist || "",
                                        fullTitle: t.fullTitle || "",
                                        duration: t.duration || "",
                                        path: t.path || "",
                                        cover: t.cover || ""
                                    })
                                }
                                Qt.callLater(function() {
                                    var maxY = Math.max(0, tracksListView.contentHeight - tracksListView.height)
                                    tracksListView.contentY = Math.min(savedY, maxY)
                                })
                            }

                            // Плавно ездящая за мышкой плашка наведения
                            Rectangle {
                                id: trackHoverPill
                                z: 1
                                visible: trackListModel.count > 0
                                opacity: (trackListContainer.isHovering || trackListContainer.draggingRow >= 0) ? 1.0 : 0.0
                                x: 0
                                y: (trackListContainer.draggingRow >= 0 ? trackListContainer.draggingRow : trackListContainer.lastHoveredRow) * 51 - tracksListView.contentY
                                width: tracksListView.width
                                height: 46
                                radius: musicRoot.isM3 ? 10 : 0
                                color: musicRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, trackListContainer.draggingRow >= 0 ? 0.28 : 0.16)
                                       : Qt.rgba(1, 1, 1, trackListContainer.draggingRow >= 0 ? 0.18 : 0.10)
                                border.width: 1
                                border.color: musicRoot.isM3 && Config
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, trackListContainer.draggingRow >= 0 ? 0.75 : 0.42)
                                              : Qt.rgba(1, 1, 1, 0.25)
                                Behavior on y { NumberAnimation { duration: 165; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 115 } }
                            }

                            Column {
                                visible: trackListModel.count === 0
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (Waybar && Waybar.ymPlaylists.length === 0)
                                          ? "Плейлисты еще не загружены в ~/Music/YandexMusic"
                                          : "Треки по запросу не найдены"
                                    color: "#888888"
                                    font.pixelSize: Config.fontSize
                                }
                                Row {
                                    visible: Waybar && Waybar.ymPlaylists.length === 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 8
                                    StyledButton {
                                        text: "󰓇 Запустить «Мою волну»"
                                        onClicked: if (Waybar) Waybar.playYmMyWave()
                                    }
                                    StyledButton {
                                        text: "󰒓 Настроить токен и плейлисты"
                                        onClicked: musicRoot.subTab = 1
                                    }
                                }
                            }

                            ListView {
                                id: tracksListView
                                z: 2
                                anchors.fill: parent
                                clip: true
                                spacing: 5
                                cacheBuffer: 600
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                model: trackListModel

                                // Плавная анимация перестановки треков при перетаскивании!
                                move: Transition {
                                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuint }
                                }
                                moveDisplaced: Transition {
                                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuint }
                                }
                                remove: Transition {
                                    ParallelAnimation {
                                        NumberAnimation { property: "opacity"; to: 0.0; duration: 140 }
                                        NumberAnimation { property: "scale"; to: 0.92; duration: 140 }
                                    }
                                }
                                removeDisplaced: Transition {
                                    NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuint }
                                }

                                property real targetY: 0
                                NumberAnimation {
                                    id: smoothTrackScroll
                                    target: tracksListView
                                    property: "contentY"
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }

                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: (event) => {
                                        if (trackListContainer.draggingRow >= 0) return
                                        var step = (event.angleDelta.y / 120.0) * 68.0
                                        if (step === 0 && event.pixelDelta.y !== 0) step = event.pixelDelta.y * 1.4
                                        var maxY = Math.max(0, tracksListView.contentHeight - tracksListView.height)
                                        var base = smoothTrackScroll.running ? tracksListView.targetY : tracksListView.contentY
                                        var nextY = Math.max(0, Math.min(maxY, base - step))
                                        tracksListView.targetY = nextY
                                        smoothTrackScroll.stop()
                                        smoothTrackScroll.from = tracksListView.contentY
                                        smoothTrackScroll.to = nextY
                                        smoothTrackScroll.start()
                                        event.accepted = true
                                    }
                                }

                                delegate: Rectangle {
                                    id: trRow
                                    width: tracksListView.width
                                    height: 46
                                    z: isBeingDragged ? 20 : 1
                                    scale: isBeingDragged ? 1.012 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    readonly property bool isBeingDragged: trackListContainer.draggingRow === index
                                    readonly property bool isCurPlaying: Waybar && (Waybar.currentLocalTrackPath === model.path || (Waybar.mediaTitle.length > 0 && model.fullTitle.indexOf(Waybar.mediaTitle.replace(" — ", " - ")) !== -1))
                                    radius: musicRoot.isM3 ? 10 : 0
                                    color: isCurPlaying
                                           ? (Config ? Config.m3Primary : "#ffffff")
                                           : (isBeingDragged
                                              ? (musicRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.14))
                                              : (musicRoot.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.32) : Qt.rgba(1, 1, 1, 0.03)))
                                    border.width: (isCurPlaying && !isBeingDragged) ? 0 : 1
                                    border.color: isBeingDragged
                                                  ? (Config ? Config.m3Primary : "#ffffff")
                                                  : Qt.rgba(1, 1, 1, 0.08)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    MouseArea {
                                        id: trRowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            trackHoverHold.stop()
                                            trackListContainer.lastHoveredRow = index
                                            trackListContainer.isHovering = true
                                        }
                                        onPositionChanged: {
                                            trackHoverHold.stop()
                                            trackListContainer.lastHoveredRow = index
                                            trackListContainer.isHovering = true
                                        }
                                        onExited: trackHoverHold.restart()
                                        onClicked: {
                                            if (Waybar) {
                                                Waybar.playYmTrack(Waybar.ymSelectedPlaylist, index)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        z: 5
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            radius: musicRoot.isM3 ? 7 : 0
                                            color: trRow.isCurPlaying ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                                            clip: true

                                            Image {
                                                id: trThumb
                                                anchors.fill: parent
                                                visible: status === Image.Ready && model.cover.length > 0
                                                source: model.cover.length > 0 ? ("file://" + model.cover) : ""
                                                sourceSize: Qt.size(68, 68)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }

                                            Text {
                                                visible: !trThumb.visible
                                                anchors.centerIn: parent
                                                text: trRow.isCurPlaying && Waybar && Waybar.mediaPlaying ? "󰏤" : "󰎆"
                                                font.pixelSize: 15
                                                color: trRow.isCurPlaying ? (Config ? Config.accentTextColor : "#000000") : (Config ? Config.m3Primary : "#ffffff")
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.title
                                                color: trRow.isCurPlaying ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                                font.pixelSize: Config.fontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: model.artist
                                                color: trRow.isCurPlaying ? Qt.rgba(0, 0, 0, 0.72) : "#aaaaaa"
                                                font.pixelSize: Config.fontSize - 1
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            visible: model.duration.length > 0
                                            text: model.duration
                                            color: trRow.isCurPlaying ? (Config ? Config.accentTextColor : "#000000") : "#888888"
                                            font.pixelSize: Config.fontSize - 1
                                            font.features: { "tnum": 1 }
                                        }

                                        // Ручка живого перетаскивания трека вверх/вниз с мгновенной анимацией ListModel.move()
                                        Item {
                                            visible: musicRoot.trackSearchQuery.trim().length === 0
                                            Layout.preferredWidth: 26
                                            Layout.preferredHeight: 28

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: musicRoot.isM3 ? 6 : 0
                                                color: dragHandleMa.pressed
                                                       ? (Config ? Config.m3Primary : "#ffffff")
                                                       : (dragHandleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰍜"
                                                font.pixelSize: 14
                                                color: dragHandleMa.pressed
                                                       ? (Config ? Config.accentTextColor : "#000000")
                                                       : (trRow.isCurPlaying ? (Config ? Config.accentTextColor : "#000000") : "#aaaaaa")
                                            }

                                            MouseArea {
                                                id: dragHandleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                preventStealing: true
                                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeVerCursor
                                                onPressed: (mouse) => {
                                                    tracksListView.interactive = false
                                                    trackListContainer.draggingRow = index
                                                    trackListContainer.lastHoveredRow = index
                                                    trackListContainer.isHovering = true
                                                    mouse.accepted = true
                                                }
                                                onPositionChanged: (mouse) => {
                                                    if (!pressed || !Waybar) return
                                                    var posInList = dragHandleMa.mapToItem(tracksListView, 0, mouse.y).y + tracksListView.contentY
                                                    var targetIdx = Math.max(0, Math.min(trackListModel.count - 1, Math.floor(posInList / 51)))
                                                    if (targetIdx !== index) {
                                                        var fromIdx = index
                                                        trackListModel.move(fromIdx, targetIdx, 1)
                                                        trackListContainer.draggingRow = targetIdx
                                                        trackListContainer.lastHoveredRow = targetIdx
                                                        Waybar.moveYmTrack(Waybar.ymSelectedPlaylist, fromIdx, targetIdx)
                                                    }
                                                }
                                                onReleased: {
                                                    tracksListView.interactive = true
                                                    trackListContainer.draggingRow = -1
                                                }
                                                onCanceled: {
                                                    tracksListView.interactive = true
                                                    trackListContainer.draggingRow = -1
                                                }
                                            }
                                        }

                                        // Кнопка возврата трека в родной плейлист (во вкладке «Скрытые»)
                                        StyledButton {
                                            visible: trackListContainer.isHiddenPlaylist
                                            text: "󰑐"
                                            isIconOnly: true
                                            implicitWidth: 26; implicitHeight: 24
                                            onClicked: {
                                                if (Waybar) {
                                                    var rIdx = index
                                                    trackListModel.remove(rIdx, 1)
                                                    Waybar.restoreYmTrack(Waybar.ymSelectedPlaylist, rIdx)
                                                }
                                            }
                                        }

                                        // Кнопка скрытия/удаления трека (плавно убирает строку и переносит в «Скрытые»)
                                        StyledButton {
                                            text: "󰅖"
                                            isIconOnly: true
                                            implicitWidth: 26; implicitHeight: 24
                                            onClicked: {
                                                if (Waybar) {
                                                    var dIdx = index
                                                    trackListModel.remove(dIdx, 1)
                                                    Waybar.deleteYmTrack(Waybar.ymSelectedPlaylist, dIdx)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // ВКЛАДКА 1: НАСТРОЙКИ ВОЛН И СИНХРОНИЗАЦИИ ЯНДЕКС.МУЗЫКИ
        // ---------------------------------------------------------------------
        ScrollView {
            id: musicCfgScroll
            anchors.fill: parent
            visible: musicRoot.subTab === 1
            contentWidth: availableWidth
            clip: true

            Item {
                width: musicCfgScroll.availableWidth
                implicitHeight: cfgMainCol.implicitHeight + 36

                ColumnLayout {
                    id: cfgMainCol
                    width: Math.min(parent.width - 44, 720)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    spacing: 12

                    IconHeader {
                        Layout.fillWidth: true
                        iconGlyph: "󰒓"
                        titleText: "Настройки виджета музыки и автозагрузки"
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        implicitHeight: cfgCol.implicitHeight + 24

                        ColumnLayout {
                            id: cfgCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                text: "Поведение и волны музыки на панели задач"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Анимация волн музыки на панели задач:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Waybar ? Waybar.mediaWaves : true
                                    onToggled: if (Waybar) Waybar.mediaWaves = checked
                                }
                            }

                            RowLayout {
                                visible: Waybar ? Waybar.mediaWaves : true
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "Режим отображения волн:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 185
                                }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    options: ["Жидкие пики", "Внутри пилюли"]
                                    selectedIndex: Waybar ? Waybar.mediaWaveMode : 0
                                    onSelected: (idx) => { if (Waybar) Waybar.mediaWaveMode = idx }
                                }
                            }

                            ColumnLayout {
                                visible: Waybar ? (Waybar.mediaWaves && Waybar.mediaWaveMode === 0) : true
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Скорость жидких пиков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 0.2; to: 5.0; stepSize: 0.1; value: Waybar ? Waybar.mediaWaveSpeed : 1.5; onMoved: if (Waybar) Waybar.mediaWaveSpeed = value }
                                    Text { text: (Waybar ? Waybar.mediaWaveSpeed.toFixed(1) : "1.5") + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Размер (высота) пиков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 4.0; to: 26.0; stepSize: 0.5; value: Waybar ? Waybar.mediaWaveSize : 11.0; onMoved: if (Waybar) Waybar.mediaWaveSize = value }
                                    Text { text: Math.round(Waybar ? Waybar.mediaWaveSize : 11) + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Количество пиков на панели:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 20; to: 200; stepSize: 5; value: Waybar ? Waybar.mediaWaveCount : 95; onMoved: if (Waybar) Waybar.mediaWaveCount = Math.round(value) }
                                    Text { text: String(Waybar ? Waybar.mediaWaveCount : 95); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Острота и раздваивание пиков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 0.1; to: 1.0; stepSize: 0.05; value: Waybar ? Waybar.mediaWaveSharpness : 0.70; onMoved: if (Waybar) Waybar.mediaWaveSharpness = value }
                                    Text { text: Math.round((Waybar ? Waybar.mediaWaveSharpness : 0.70) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }
                            }

                            ColumnLayout {
                                visible: Waybar ? (Waybar.mediaWaves && Waybar.mediaWaveMode === 1) : false
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Скорость столбиков в пилюле:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 0.2; to: 5.0; stepSize: 0.1; value: Waybar ? Waybar.pillWaveSpeed : 1.6; onMoved: if (Waybar) Waybar.pillWaveSpeed = value }
                                    Text { text: (Waybar ? Waybar.pillWaveSpeed.toFixed(1) : "1.6") + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Высота столбиков в пилюле:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 20; to: 100; stepSize: 5; value: Waybar ? Waybar.pillWaveHeight : 70; onMoved: if (Waybar) Waybar.pillWaveHeight = Math.round(value) }
                                    Text { text: (Waybar ? Waybar.pillWaveHeight : 70) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Толщина столбиков в пилюле:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 1; to: 5; stepSize: 1; value: Waybar ? Waybar.pillWaveWidth : 2; onMoved: if (Waybar) Waybar.pillWaveWidth = Math.round(value) }
                                    Text { text: (Waybar ? Waybar.pillWaveWidth : 2) + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Text { text: "Зазор между столбиками:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                    StyledSlider { Layout.fillWidth: true; from: 1; to: 5; stepSize: 1; value: Waybar ? Waybar.pillWaveGap : 1; onMoved: if (Waybar) Waybar.pillWaveGap = Math.round(value) }
                                    Text { text: (Waybar ? Waybar.pillWaveGap : 1) + " px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignRight }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Свернуть виджет музыки на панели (компактный вид):"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Waybar ? Waybar.mediaCollapsed : false
                                    onToggled: if (Waybar) Waybar.mediaCollapsed = checked
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Показывать плеер на верхней панели:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: {
                                        var _ = Waybar ? Waybar.hiddenBarModules : ""
                                        return Waybar ? Waybar.isBarModuleVisible("media") : true
                                    }
                                    onToggled: if (Waybar) Waybar.setBarModuleVisible("media", checked)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "Скрывать с панели при паузе через:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 230
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 120; stepSize: 5
                                    value: Waybar ? Waybar.mediaHideTimeout : 15
                                    onMoved: if (Waybar) Waybar.mediaHideTimeout = Math.round(value)
                                }
                                Text {
                                    text: (Waybar && Waybar.mediaHideTimeout === 0) ? "Никогда" : ((Waybar ? Waybar.mediaHideTimeout : 15) + " сек")
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 58
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        implicitHeight: ymCol.implicitHeight + 28

                        ColumnLayout {
                            id: ymCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "󰓇  Яндекс.Музыка, обложки и автозагрузка"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 1
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                StyledButton {
                                    text: "󰉋 Папка музыки"
                                    implicitHeight: 24
                                    onClicked: if (Waybar) Waybar.openYmMusicFolder()
                                }
                                StyledButton {
                                    text: " Получить токен"
                                    implicitHeight: 24
                                    onClicked: if (Waybar) Waybar.openYmOAuth()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                TextField {
                                    id: ymTokenField
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    leftPadding: 10; rightPadding: 10
                                    echoMode: TextInput.Password
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    placeholderText: (Waybar && Waybar.ymHasToken) ? "OAuth-токен сохранен (вставьте новый для замены)..." : "Вставьте OAuth-токен или ссылку после авторизации..."
                                    placeholderTextColor: (Waybar && Waybar.ymHasToken) ? "#69f0ae" : "#777777"
                                    background: Rectangle {
                                        radius: musicRoot.isM3 ? 8 : 0
                                        color: musicRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: Qt.rgba(1, 1, 1, 0.16)
                                        border.width: musicRoot.isM3 ? 0 : 1
                                    }
                                }
                                StyledButton {
                                    text: "Сохранить"
                                    implicitHeight: 28
                                    onClicked: {
                                        if (Waybar && ymTokenField.text.trim().length > 0) {
                                            Waybar.saveYmToken(ymTokenField.text.trim())
                                            ymTokenField.text = ""
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                StyledButton {
                                    Layout.fillWidth: true
                                    allowFullWidth: true
                                    implicitHeight: 30
                                    isActive: Waybar && Waybar.ymBusy
                                    text: (Waybar && Waybar.ymBusy)
                                          ? ("󰑐 Синхронизация... " + Waybar.ymProgress + "%")
                                          : "󰑐 Синхронизировать плейлисты"
                                    enabled: !(Waybar && Waybar.ymBusy)
                                    onClicked: if (Waybar) Waybar.syncYmPlaylists()
                                }

                                StyledButton {
                                    Layout.fillWidth: true
                                    allowFullWidth: true
                                    implicitHeight: 30
                                    text: "󰎆 Скачать «Мою волну» (" + (Waybar ? Waybar.ymWaveCount : 100) + " тр.)"
                                    enabled: !(Waybar && Waybar.ymBusy)
                                    onClicked: if (Waybar) Waybar.downloadYmMyWave()
                                }

                                StyledButton {
                                    visible: Waybar && Waybar.ymBusy
                                    text: "󰅖 Стоп"
                                    implicitHeight: 30
                                    onClicked: if (Waybar) Waybar.stopYmSync()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "Количество треков «Моей волны» за раз:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 250
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 10; to: 500; stepSize: 10
                                    value: Waybar ? Waybar.ymWaveCount : 100
                                    onMoved: if (Waybar) Waybar.ymWaveCount = Math.round(value)
                                }
                                Text {
                                    text: (Waybar ? Waybar.ymWaveCount : 100) + " тр."
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: true
                                    Layout.preferredWidth: 58
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 1
                                color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            Text {
                                text: "Автодокачка при появлении интернета (с ожиданием VPN)"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Автоматически докачивать новые треки из плейлистов:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Waybar ? Waybar.ymAutoSyncPlaylists : true
                                    onToggled: if (Waybar) Waybar.ymAutoSyncPlaylists = checked
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Автоматически докачивать пачку «Моей волны» при старте:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Waybar ? Waybar.ymAutoSyncMyWave : false
                                    onToggled: if (Waybar) Waybar.ymAutoSyncMyWave = checked
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "Задержка после появления интернета:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 250
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 15; to: 180; stepSize: 5
                                    value: Waybar ? Waybar.ymAutoSyncDelay : 45
                                    onMoved: if (Waybar) Waybar.ymAutoSyncDelay = Math.round(value)
                                }
                                Text {
                                    text: (Waybar ? Waybar.ymAutoSyncDelay : 45) + " сек"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 58
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle {
                                visible: Waybar && Waybar.ymBusy
                                Layout.fillWidth: true
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(1, 1, 1, 0.10)
                                clip: true
                                Rectangle {
                                    width: parent.width * Math.max(0.05, Math.min(1.0, (Waybar ? Waybar.ymProgress : 0) / 100.0))
                                    height: parent.height
                                    radius: parent.radius
                                    color: Config ? Config.m3Primary : "#69f0ae"
                                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Waybar ? Waybar.ymStatusText : ""
                                color: "#aaaaaa"
                                font.pixelSize: Config.fontSize - 1
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
