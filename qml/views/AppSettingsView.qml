import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

RowLayout {
    id: appSetRoot
    spacing: 0

    property int subTab: 0
    onVisibleChanged: if (visible) subSidebar.playStaircase()
    Component.onCompleted: if (visible) Qt.callLater(() => subSidebar.playStaircase())
    readonly property bool isM3: Theme && Theme.isRounded

    ColorPickerModal {
        id: colorModal
        property int targetRole: 0
        onColorSelected: (c) => {
            if (targetRole === 0) Config.accentColor = c
            else if (targetRole === 1) Config.borderGlowCustomColor = c
            else if (targetRole === 2) Config.cursorCustomColor = c
            else if (targetRole === 3) Config.windowBgColor = c
            else if (targetRole === 4) Config.cardBgColor = c
            else if (targetRole === 5) Config.m3SecondaryColor = c
            else if (targetRole === 6) Config.m3TertiaryColor = c
        }
    }

    // Левое подменю разделов настроек
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
                function onPlayStaircase() {
                    attAnim.restart()
                }
            }

            Component.onCompleted: {
                if (att.parent) {
                    att.parent.transform = [attTrans, attScale]
                }
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

        property Item activeCardObj: subTab === 0 ? sCard0 : (subTab === 1 ? sCard1 : (subTab === 2 ? sCard2 : (subTab === 3 ? sCard3 : (subTab === 4 ? sCard4 : sCard5))))
        property Item hoveredCardObj: null
        property Item lastHoveredCardObj: null

        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: setHoverPill
            x: 4; width: subSidebar.width - 8; height: 30
            radius: (Theme && Theme.isRounded) ? 6 : 0
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: subSidebar.hoveredCardObj && subSidebar.hoveredCardObj !== subSidebar.activeCardObj ? 1.0 : 0.0
            y: subSidebar.lastHoveredCardObj ? (subCol.y + subSidebar.lastHoveredCardObj.y) : 34
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: setActivePill
            SubCascadeAttach { stepIdx: appSetRoot.subTab + 1 }
            x: 4; width: subSidebar.width - 8; height: 30
            radius: (Theme && Theme.isRounded) ? 6 : 0
            color: Config ? Config.m3Primary : "#ffffff"
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
                text: Config ? (Config.language, Config.trAuto("Настройки центра")) : "Настройки центра"
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
                id: sCard0; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 1 }
                MouseArea {
                    id: sMouse0; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard0; subSidebar.hoveredCardObj = sCard0 }
                        else if (subSidebar.hoveredCardObj === sCard0) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 0
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰏘"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (sMouse0.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Тема"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (sMouse0.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: sCard1; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 2 }
                MouseArea {
                    id: sMouse1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard1; subSidebar.hoveredCardObj = sCard1 }
                        else if (subSidebar.hoveredCardObj === sCard1) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 1
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰒓"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (sMouse1.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Интерфейс"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (sMouse1.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: sCard2; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 3 }
                MouseArea {
                    id: sMouse2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard2; subSidebar.hoveredCardObj = sCard2 }
                        else if (subSidebar.hoveredCardObj === sCard2) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 2
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󱐌"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (sMouse2.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Анимации"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (sMouse2.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: sCard3; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 4 }
                MouseArea {
                    id: sMouse3; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard3; subSidebar.hoveredCardObj = sCard3 }
                        else if (subSidebar.hoveredCardObj === sCard3) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 3
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰖨"; color: subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (sMouse3.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Стекло и Блюр"; color: subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (sMouse3.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: sCard4; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 5 }
                MouseArea {
                    id: sMouse4; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard4; subSidebar.hoveredCardObj = sCard4 }
                        else if (subSidebar.hoveredCardObj === sCard4) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 4
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰆿"; color: subTab === 4 ? (Config ? Config.accentTextColor : "#000000") : (sMouse4.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Свечение и Меню"; color: subTab === 4 ? (Config ? Config.accentTextColor : "#000000") : (sMouse4.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: sCard5; Layout.fillWidth: true; implicitHeight: 30
                SubCascadeAttach { stepIdx: 6 }
                MouseArea {
                    id: sMouse5; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = sCard5; subSidebar.hoveredCardObj = sCard5 }
                        else if (subSidebar.hoveredCardObj === sCard5) subSidebar.hoveredCardObj = null
                    }
                    onClicked: {
                        subTab = 5
                        if (Config) Config.refreshBackupInfo()
                    }
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "󰚰"; color: subTab === 5 ? (Config ? Config.accentTextColor : "#000000") : (sMouse5.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 }
                    Text { text: "Обновления"; color: subTab === 5 ? (Config ? Config.accentTextColor : "#000000") : (sMouse5.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    Rectangle {
                        visible: Config ? Config.updateAvailable : false
                        width: 7; height: 7; radius: 3.5
                        color: subTab === 5 ? (Config ? Config.accentTextColor : "#000000") : "#69f0ae"
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledButton {
                SubCascadeAttach { stepIdx: 6 }
                Layout.fillWidth: true
                allowFullWidth: true
                text: "↺ Сбросить всё"
                onClicked: Config.resetDefaults()
            }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: appSetRoot.subTab

        // =====================================================================
        // РАЗДЕЛ 0: ОФОРМЛЕНИЕ, ТЕМА И ЦВЕТА
        // =====================================================================
        ScrollView {
            id: scrTheme; contentWidth: availableWidth; clip: true
            Item {
                width: scrTheme.availableWidth; implicitHeight: colThemeMain.implicitHeight + 44
                ColumnLayout {
                    id: colThemeMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: appSetRoot.isM3 ? 14 : 10

                    Text {
                        text: "󰏘  Оформление, тема и цвета"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colMode.implicitHeight + 28
                        ColumnLayout {
                            id: colMode; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Тема:"
                                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                    Layout.fillWidth: true
                                }
                                SegmentedButton {
                                    Layout.preferredWidth: 280
                                    options: ["Квадратный", "Скругленный"]
                                    selectedIndex: (Theme && Theme.isRounded) ? 1 : 0
                                    onSelected: (idx) => { if (Theme) Theme.setRoundedState(idx === 1) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    text: "Цвета с текущих обоев:"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true
                                }

                                StyledSwitch {
                                    checked: Config ? Config.m3DynamicWallpaperColors : true
                                    onToggled: if (Config) Config.m3DynamicWallpaperColors = checked
                                }
                            }
                        }
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colM3Geom.implicitHeight + 28
                        ColumnLayout {
                            id: colM3Geom; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Геометрия и атрибуты поверхностей"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                                StyledButton { text: "↺ Сбросить геометрию"; onClicked: if (Config) Config.resetM3Attributes() }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Стиль карточек:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 320
                                    options: ["Тональный", "Контурный", "Приподнятый"]
                                    selectedIndex: Config ? Config.m3ElevationStyle : 0
                                    onSelected: (idx) => { if (Config) Config.m3ElevationStyle = idx }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Сила оттенка обоев на фоне и окнах:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3SurfaceTintStrength : 0.22; onMoved: if (Config) Config.m3SurfaceTintStrength = value }
                                Text { text: Math.round((Config ? Config.m3SurfaceTintStrength : 0.22) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Уровень контрастности:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3ContrastLevel : 0.50; onMoved: if (Config) Config.m3ContrastLevel = value }
                                Text { text: Math.round((Config ? Config.m3ContrastLevel : 0.50) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Радиус скругления окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 4; to: 32; stepSize: 1; value: Config ? Config.m3WindowRadius : 20; onMoved: if (Config) Config.m3WindowRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3WindowRadius : 20) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Радиус карточек:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 4; to: 28; stepSize: 1; value: Config ? Config.m3CardRadius : 16; onMoved: if (Config) Config.m3CardRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3CardRadius : 16) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Радиус кнопок и элементов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 2; to: 20; stepSize: 1; value: Config ? Config.m3ControlRadius : 12; onMoved: if (Config) Config.m3ControlRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3ControlRadius : 12) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Толщина и прозрачность контуров:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3OutlineOpacity : 0.28; onMoved: if (Config) Config.m3OutlineOpacity = value }
                                Text { text: Math.round((Config ? Config.m3OutlineOpacity : 0.28) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Скорость колебаний волны ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 4.0; stepSize: 0.05; value: Config ? Config.sliderWaveSpeed : 1.25; onMoved: if (Config) Config.sliderWaveSpeed = value }
                                Text { text: (Config ? Config.sliderWaveSpeed : 1.25).toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Амплитуда волны ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 5.5; stepSize: 0.1; value: Config ? Config.sliderWaveAmplitude : 2.0; onMoved: if (Config) Config.sliderWaveAmplitude = value }
                                Text { text: (Config ? Config.sliderWaveAmplitude : 2.0).toFixed(1) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Длина волны ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 10.0; to: 50.0; stepSize: 1.0; value: Config ? Config.sliderWaveLength : 24.0; onMoved: if (Config) Config.sliderWaveLength = value }
                                Text { text: Math.round(Config ? Config.sliderWaveLength : 24) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Толщина линии ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 260 }
                                StyledSlider { Layout.fillWidth: true; from: 1.4; to: 5.0; stepSize: 0.2; value: Config ? Config.sliderThickness : 2.4; onMoved: if (Config) Config.sliderThickness = value }
                                Text { text: (Config ? Config.sliderThickness : 2.4).toFixed(1) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colColors.implicitHeight + 28
                        ColumnLayout {
                            id: colColors; anchors.fill: parent; anchors.margins: 14; spacing: 10
                            Text { text: "Ручная настройка цветов палитры"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Синхронизировать свечение и курсор с основным акцентом:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config.syncColorsWithAccent; onToggled: Config.syncColorsWithAccent = checked }
                            }

                            Repeater {
                                model: [
                                    { label: "Основной акцент:", role: 0, col: Config.accentColor },
                                    { label: "Вторичный акцент:", role: 5, col: Config.m3SecondaryColor },
                                    { label: "Третичный акцент:", role: 6, col: Config.m3TertiaryColor },
                                    { label: "Фон окна:", role: 3, col: Config.windowBgColor },
                                    { label: "Фон карточек:", role: 4, col: Config.cardBgColor },
                                    { label: "Цвет свечения границ:", role: 1, col: Config.borderGlowCustomColor },
                                    { label: "Цвет курсора и вспышки:", role: 2, col: Config.cursorCustomColor }
                                ]
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    Text { text: modelData.label; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                    Rectangle {
                                        width: 24; height: 24; radius: appSetRoot.isM3 ? 12 : 0
                                        color: modelData.col; border.color: Qt.rgba(1, 1, 1, 0.35); border.width: 1
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { colorModal.targetRole = modelData.role; colorModal.openPicker(modelData.label, modelData.col) } }
                                    }
                                    Text { text: modelData.col.toString().toUpperCase(); color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1; Layout.preferredWidth: 66 }
                                    StyledButton { text: "Изменить"; onClicked: { colorModal.targetRole = modelData.role; colorModal.openPicker(modelData.label, modelData.col) } }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // РАЗДЕЛ 1: ИНТЕРФЕЙС
        // =====================================================================
        ScrollView {
            id: scrInt; contentWidth: availableWidth; clip: true
            Item {
                width: scrInt.availableWidth; implicitHeight: colIntMain.implicitHeight + 44
                ColumnLayout {
                    id: colIntMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󰒓  Параметры интерфейса и геометрии"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colInt.implicitHeight + 28
                        ColumnLayout {
                            id: colInt; anchors.fill: parent; anchors.margins: 14; spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Язык интерфейса:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 240
                                    options: ["Русский", "English"]
                                    selectedIndex: Config.language === "en" ? 1 : 0
                                    onSelected: (idx) => Config.language = (idx === 1 ? "en" : "ru")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Запоминать последнюю открытую вкладку:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config.rememberLastTab; onToggled: Config.rememberLastTab = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Высота окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 520; to: 960; stepSize: 10; value: Config.windowHeight; onMoved: Config.windowHeight = Math.round(value) }
                                Text { text: Config.windowHeight + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Масштаб интерфейса:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.80; to: 1.25; stepSize: 0.05; value: Config.uiScale; onMoved: Config.uiScale = value }
                                Text { text: Math.round(Config.uiScale * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Размер шрифта:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 9; to: 14; stepSize: 1; value: Config.fontSize; onMoved: Config.fontSize = Math.round(value) }
                                Text { text: Config.fontSize + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Текст бокового меню:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 240
                                    options: ["Слева", "По центру"]
                                    selectedIndex: Config.alignCenter ? 1 : 0
                                    onSelected: (idx) => Config.alignCenter = (idx === 1)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Выравнивание экрана приветствия:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 300
                                    options: ["Слева", "По центру", "Справа"]
                                    selectedIndex: Config.welcomeAlignMode
                                    onSelected: (idx) => Config.welcomeAlignMode = idx
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // РАЗДЕЛ 2: АНИМАЦИИ ОТКРЫТИЯ И ПЕРЕХОДОВ
        // =====================================================================
        ScrollView {
            id: scrAnim; contentWidth: availableWidth; clip: true
            Item {
                width: scrAnim.availableWidth; implicitHeight: colAnimMain.implicitHeight + 44
                ColumnLayout {
                    id: colAnimMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󱐌  Анимации открытия окна и переходов"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colAnim.implicitHeight + 28
                        ColumnLayout {
                            id: colAnim; anchors.fill: parent; anchors.margins: 14; spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "Эффект появления окна настроек:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Пружина", "Упругое желе", "Отскок", "Зум-пружина", "Плавный"]
                                    selectedIndex: {
                                        var t = Config ? Config.windowOpenAnimType : "spring"
                                        if (t === "elastic") return 1
                                        if (t === "bounce") return 2
                                        if (t === "zoom_spring") return 3
                                        if (t === "smooth") return 4
                                        return 0
                                    }
                                    onSelected: (idx) => { if (Config) Config.windowOpenAnimType = ["spring", "elastic", "bounce", "zoom_spring", "smooth"][idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Пружинистое растягивание окна в бока при открытии:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Waybar ? Waybar.windowSideStretch : true
                                    onToggled: if (Waybar) Waybar.windowSideStretch = checked
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "Переход с экрана приветствия:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Слайд", "Глубина", "Пружина", "Воронка", "Портал", "Телепорт", "Выкл"]
                                    selectedIndex: {
                                        var t = Config.welcomeAnimType
                                        if (t === "depth") return 1
                                        if (t === "bounce") return 2
                                        if (t === "blackhole") return 3
                                        if (t === "portal") return 4
                                        if (t === "shatter") return 5
                                        if (t === "none") return 6
                                        return 0
                                    }
                                    onSelected: (idx) => { Config.welcomeAnimType = ["slide", "depth", "bounce", "blackhole", "portal", "shatter", "none"][idx] }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "Тип анимации между вкладками:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Слайд", "Глубина", "Пружина", "Воронка", "Портал", "Телепорт", "Выкл"]
                                    selectedIndex: {
                                        var t = Config.animType
                                        if (t === "depth") return 1
                                        if (t === "bounce") return 2
                                        if (t === "blackhole") return 3
                                        if (t === "portal") return 4
                                        if (t === "shatter") return 5
                                        if (t === "none") return 6
                                        return 0
                                    }
                                    onSelected: (idx) => { Config.animType = ["slide", "depth", "bounce", "blackhole", "portal", "shatter", "none"][idx] }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Длительность переходов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 50; to: 600; stepSize: 10; value: Config.animDuration; onMoved: Config.animDuration = Math.round(value) }
                                Text { text: Config.animDuration + "ms"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // РАЗДЕЛ 3: СТЕКЛО И ПРОЗРАЧНОСТЬ
        // =====================================================================
        ScrollView {
            id: scrGlass; contentWidth: availableWidth; clip: true
            Item {
                width: scrGlass.availableWidth; implicitHeight: colGlassMain.implicitHeight + 44
                ColumnLayout {
                    id: colGlassMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󰖨  Прозрачность, Блюр и Жидкое стекло"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colOp.implicitHeight + 28
                        ColumnLayout {
                            id: colOp; anchors.fill: parent; anchors.margins: 14; spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Жидкое стекло для кнопок, тумблеров и ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Theme.controlsLiquidGlass; onToggled: Theme.controlsLiquidGlass = checked }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Главный фон окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.opacity; onMoved: Config.opacity = value }
                                Text { text: Math.round(Config.opacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Интенсивность блюра окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Theme.windowBlur; onMoved: Theme.windowBlur = value }
                                Text { text: Theme.windowBlur <= 0.01 ? "Выкл" : Math.round(Theme.windowBlur * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Прозрачность диалоговых окон:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.05; to: 1.0; value: Config.dialogOpacity; onMoved: Config.dialogOpacity = value }
                                Text { text: Math.round(Config.dialogOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Блюр диалоговых окон:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config.dialogBlur; onMoved: Config.dialogBlur = value }
                                Text { text: Config.dialogBlur <= 0.01 ? "Выкл" : Math.round(Config.dialogBlur * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Искажение стекла:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Theme.glassRefraction; onMoved: Theme.glassRefraction = value }
                                Text { text: Math.round(Theme.glassRefraction * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Боковое меню:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.sidebarOpacity; onMoved: Config.sidebarOpacity = value }
                                Text { text: Math.round(Config.sidebarOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Карточки и панели:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.cardOpacity; onMoved: Config.cardOpacity = value }
                                Text { text: Math.round(Config.cardOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // РАЗДЕЛ 4: СВЕЧЕНИЕ ГРАНИЦ, КУРСОР И БОКОВОЕ МЕНЮ
        // =====================================================================
        ScrollView {
            id: scrGlow; contentWidth: availableWidth; clip: true
            Item {
                width: scrGlow.availableWidth; implicitHeight: colGlowMain.implicitHeight + 44
                ColumnLayout {
                    id: colGlowMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󰆿  Подсветка границ, Курсор и Боковое меню"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colGlow.implicitHeight + 28
                        ColumnLayout {
                            id: colGlow; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            Text { text: "Подсветка границ окна и курсор"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Режим отображения границ:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 340
                                    options: ["На всех экранах", "Только приветствие", "Выкл"]
                                    selectedIndex: !Config.borderGlowEnabled ? 2 : (Config.borderGlowAllPages ? 0 : 1)
                                    onSelected: (idx) => {
                                        if (idx === 0) { Config.borderGlowEnabled = true; Config.borderGlowAllPages = true }
                                        else if (idx === 1) { Config.borderGlowEnabled = true; Config.borderGlowAllPages = false }
                                        else Config.borderGlowEnabled = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Направление движения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 340
                                    options: ["По часовой", "Против часовой", "Навстречу"]
                                    selectedIndex: Config.borderGlowDirection
                                    onSelected: (idx) => Config.borderGlowDirection = idx
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Палитра свечения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 420
                                    options: ["Монохром", "Холодный лед", "Аврора", "Теплый неон", "Свой цвет"]
                                    selectedIndex: Config.borderGlowColorMode
                                    onSelected: (idx) => Config.borderGlowColorMode = idx
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Яркость свечения границ:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.05; to: 1.0; value: Config.borderGlowIntensity; onMoved: Config.borderGlowIntensity = value }
                                Text { text: Math.round(Config.borderGlowIntensity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Ширина свечения у края:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.10; to: 1.0; value: Config.borderGlowSpread; onMoved: Config.borderGlowSpread = value }
                                Text { text: Math.round(Config.borderGlowSpread * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Скорость движения света:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.10; to: 2.50; value: Config.borderGlowSpeed; onMoved: Config.borderGlowSpeed = value }
                                Text { text: Math.round(Config.borderGlowSpeed * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Сила свечения и следа от курсора:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.cursorGlowIntensity; onMoved: Config.cursorGlowIntensity = value }
                                Text { text: Math.round(Config.cursorGlowIntensity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Форма вспышки / волны при клике:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 360
                                    options: ["Кольцо", "Импульс", "Звезда", "Двойная волна"]
                                    selectedIndex: Config.clickFlashShape
                                    onSelected: (idx) => Config.clickFlashShape = idx
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Сила вспышки при клике:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.clickFlashIntensity; onMoved: Config.clickFlashIntensity = value }
                                Text { text: Math.round(Config.clickFlashIntensity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colSideTabs.implicitHeight + 28
                        ColumnLayout {
                            id: colSideTabs; anchors.fill: parent; anchors.margins: 14; spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Отображаемые разделы (меню и приветствие)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                                StyledButton { text: "Показать все"; visible: Config.hiddenSidebarTabs.length > 0; onClicked: Config.hiddenSidebarTabs = "" }
                            }
                            GridLayout {
                                Layout.fillWidth: true; columns: 3; columnSpacing: 12; rowSpacing: 8
                                Repeater {
                                    model: [
                                        { title: "󰍉  Поиск", idx: 16 }, { title: "󰖙  Погода", idx: 20 }, { title: "󰎆  Музыка", idx: 27 },
                                        { title: "  Монитор", idx: 21 }, { title: "󱑂  Время", idx: 22 }, { title: "󰅌  Буфер", idx: 23 },
                                        { title: "󰌌  Язык", idx: 25 }, { title: "⏻  Питание", idx: 24 }, { title: "󰖲  Окна", idx: 1 },
                                        { title: "󱐌  Анимации", idx: 2 }, { title: "󰆿  Курсор", idx: 3 }, { title: "󰍹  Мониторы", idx: 4 },
                                        { title: "󰌌  Устройства", idx: 5 }, { title: "󰖩  Сеть", idx: 6 }, { title: "󰦝  VPN", idx: 26 },
                                        { title: "󰂯  Блютуз", idx: 7 }, { title: "󱓞  Панель", idx: 8 }, { title: "󰂚  Уведомления", idx: 18 },
                                        { title: "󰒲  Автозапуск", idx: 9 }, { title: "⌨  Бинды", idx: 10 }, { title: "󰘳  Правила окон", idx: 11 },
                                        { title: "󰀻  Приложения", idx: 12 }, { title: "󰏘  Шейдеры", idx: 13 }, { title: "󰸉  Обои", idx: 14 },
                                        { title: "󰕰  Виджеты", idx: 15 }, { title: "󰖗  Атмосфера", idx: 19 }, { title: "󰁯  Бэкап", idx: 29 }, { title: "󰄜  Телефон", idx: 30 },
                                        { title: "󰒓  Настройки", idx: 17 },
                                        { title: "✕  Кнопка Закрыть", idx: 99 }
                                    ]
                                    StyledCheckBox {
                                        text: modelData.title
                                        checked: { var _ = Config.hiddenSidebarTabs; return Config.isTabVisible(modelData.idx) }
                                        onToggled: Config.setTabVisible(modelData.idx, checked)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // РАЗДЕЛ 5: ОБНОВЛЕНИЯ СИСТЕМЫ И МАСТЕР ПЕРВОГО ЗАПУСКА
        // =====================================================================
        ScrollView {
            id: scrUpd; contentWidth: availableWidth; clip: true
            Item {
                width: scrUpd.availableWidth; implicitHeight: colUpdMain.implicitHeight + 44
                ColumnLayout {
                    id: colUpdMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󰚰  Центр обновлений HySett и пути"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colUpdCard.implicitHeight + 28
                        ColumnLayout {
                            id: colUpdCard; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: Config && Config.updateAvailable ? "Доступна новая версия HySett на GitHub!" : "Проверка и установка обновлений"
                                        color: Config && Config.updateAvailable ? "#69f0ae" : "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Текущая версия: " + (Config ? Config.localVersionInfo : "main") +
                                              "   •   На GitHub: " + (Config ? Config.remoteVersionInfo : "main")
                                        color: Config ? Config.m3Primary : "#a8c7fa"
                                        font.pixelSize: Config.fontSize
                                    }
                                }
                                StyledButton {
                                    text: "󰑐 Проверить обновления"
                                    enabled: Config ? !Config.sysBusy : true
                                    onClicked: if (Config) Config.checkUpdates()
                                }
                                StyledButton {
                                    text: "󰇚 Скачать и обновить"
                                    isActive: true
                                    enabled: Config ? !Config.sysBusy : true
                                    onClicked: if (Config) Config.installUpdate()
                                }
                            }

                            Rectangle {
                                visible: Config ? Config.sysBusy : false
                                Layout.fillWidth: true; height: 5; radius: 2.5
                                color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle {
                                    width: parent.width * Math.max(0.05, Math.min(1.0, (Config ? Config.sysProgress : 0) / 100.0))
                                    height: parent.height; radius: 2.5
                                    color: Config ? Config.m3Primary : "#69f0ae"
                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                visible: Config ? Config.sysStatusText.length > 0 : false
                                text: Config ? Config.sysStatusText : ""
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize - 1
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                            Text {
                                text: "Список изменений последнего релиза / коммита:"
                                color: "#aaaaaa"
                                font.pixelSize: Config.fontSize - 1
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Config ? Config.updateChangelog : ""
                                color: "#dddddd"
                                font.pixelSize: Config.fontSize
                            }
                        }
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colPathsCard.implicitHeight + 28
                        ColumnLayout {
                            id: colPathsCard; anchors.fill: parent; anchors.margins: 14; spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "󰉋  Рабочие пути и Мастер первоначальной настройки"
                                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                    Layout.fillWidth: true
                                }
                                StyledButton {
                                    text: "󰒓  Мастер настройки"
                                    onClicked: if (ApplicationWindow.window) ApplicationWindow.window.setupWizardOpen = true
                                }
                            }

                            Text {
                                text: "Папка обоев: " + (Config ? Config.wallpapersDir : "~/Pictures/Wallpapers")
                                color: "#cccccc"; font.pixelSize: Config.fontSize
                            }
                            Text {
                                text: "Папка музыки: " + (Config ? Config.musicDir : "~/Music/YandexMusic")
                                color: "#cccccc"; font.pixelSize: Config.fontSize
                            }
                            Text {
                                text: "Папка архивов бэкапа: " + (Config ? Config.backupsDir : "~/hysett/backups/archives")
                                color: "#cccccc"; font.pixelSize: Config.fontSize
                            }
                        }
                    }
                }
            }
        }
    }
}
