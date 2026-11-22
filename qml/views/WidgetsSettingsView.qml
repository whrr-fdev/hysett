import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

RowLayout {
    id: widgetsRoot
    spacing: 0

    property int subTab: 0
    property int prevSubTab: 0
    property real subPageOffsetY: 0.0
    property real subPageAlpha: 1.0
    property real subPageScale: 1.0
    ParallelAnimation {
        id: widSubTabAnim
        NumberAnimation { target: widgetsRoot; property: "subPageAlpha"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { id: widSubYAnim; target: widgetsRoot; property: "subPageOffsetY"; to: 0.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        NumberAnimation { target: widgetsRoot; property: "subPageScale"; from: 0.975; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
    }
    onSubTabChanged: {
        var dir = (subTab >= prevSubTab) ? 1 : -1
        prevSubTab = subTab
        widSubTabAnim.stop()
        widSubYAnim.from = dir * 24.0
        widSubTabAnim.start()
    }
    onVisibleChanged: if (visible) subSidebar.playStaircase()
    Component.onCompleted: if (visible) Qt.callLater(() => subSidebar.playStaircase())
    property int colorTarget: 0 // 0 = text_color, 1 = graph_color

    ColorPickerModal {
        id: sysColorModal
        onColorSelected: (newCol) => {
            var hex = newCol.toString()
            if (widgetsRoot.colorTarget === 0) Widgets.sysTextColor = hex
            else if (widgetsRoot.colorTarget === 1) Widgets.sysGraphColor = hex
            else if (widgetsRoot.colorTarget === 2 && Config) {
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

        property Item activeCardObj: subTab === 0 ? wCard0 : (subTab === 1 ? wCard1 : (subTab === 2 ? wCard2 : (subTab === 3 ? wCard3 : wCard4)))
        property Item hoveredCardObj: null
        property Item lastHoveredCardObj: null

        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }

        Rectangle {
            id: widgetHoverPill
            x: 4; width: subSidebar.width - 8; height: 30
            radius: (Theme && Theme.isRounded) ? 4 : 0
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: subSidebar.hoveredCardObj && subSidebar.hoveredCardObj !== subSidebar.activeCardObj ? 1.0 : 0.0
            y: subSidebar.lastHoveredCardObj ? (subCol.y + subSidebar.lastHoveredCardObj.y) : 34
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: widgetActivePill
            SubCascadeAttach { stepIdx: widgetsRoot.subTab + 1 }
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
                text: Config ? (Config.language, Config.trAuto("Виджеты и оверлеи")) : "Виджеты и оверлеи"
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
                id: wCard0
                SubCascadeAttach { stepIdx: 1 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: wMouse0; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = wCard0; subSidebar.hoveredCardObj = wCard0 }
                        else if (subSidebar.hoveredCardObj === wCard0) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 0
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰌌"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (wMouse0.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: Config ? (Config.language, Config.trAuto("Оверлей клавиш")) : "Оверлей клавиш"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (wMouse0.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 0; checked: Widgets.kbRunning; onToggled: Widgets.toggleKbProcess(checked) }
                }
            }

            Item {
                id: wCard1
                SubCascadeAttach { stepIdx: 2 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: wMouse1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = wCard1; subSidebar.hoveredCardObj = wCard1 }
                        else if (subSidebar.hoveredCardObj === wCard1) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 1
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰕰"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (wMouse1.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: Config ? (Config.language, Config.trAuto("Часы на фоне")) : "Часы на фоне"; color: subTab === 1 ? (Config ? Config.accentTextColor : "#000000") : (wMouse1.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 1; checked: Widgets.clockRunning; onToggled: Widgets.toggleClockProcess(checked) }
                }
            }

            Item {
                id: wCard2
                SubCascadeAttach { stepIdx: 3 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: wMouse2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = wCard2; subSidebar.hoveredCardObj = wCard2 }
                        else if (subSidebar.hoveredCardObj === wCard2) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 2
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰍹"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (wMouse2.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: Config ? (Config.language, Config.trAuto("Системный оверлей")) : "Системный оверлей"; color: subTab === 2 ? (Config ? Config.accentTextColor : "#000000") : (wMouse2.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 2; checked: Widgets.sysRunning; onToggled: Widgets.toggleSysProcess(checked) }
                }
            }

            Item {
                id: wCard3
                SubCascadeAttach { stepIdx: 4 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: wMouse3; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = wCard3; subSidebar.hoveredCardObj = wCard3 }
                        else if (subSidebar.hoveredCardObj === wCard3) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 3
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󱐌"; color: subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (wMouse3.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: Config ? (Config.language, Config.trAuto("Информеры")) : "Информеры"; color: subTab === 3 ? (Config ? Config.accentTextColor : "#000000") : (wMouse3.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                }
            }

            Item {
                id: wCard4
                SubCascadeAttach { stepIdx: 5 }
                objectName: "skipAtmoChildren"
                Layout.fillWidth: true; implicitHeight: 30
                MouseArea {
                    id: wMouse4; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) { subSidebar.lastHoveredCardObj = wCard4; subSidebar.hoveredCardObj = wCard4 }
                        else if (subSidebar.hoveredCardObj === wCard4) subSidebar.hoveredCardObj = null
                    }
                    onClicked: subTab = 4
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8; spacing: 9
                    Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Text { anchors.centerIn: parent; text: "󰏫"; color: subTab === 4 ? (Config ? Config.accentTextColor : "#000000") : (wMouse4.containsMouse ? "#ffffff" : "#888888"); font.pixelSize: 13 } }
                    Text { text: Config ? (Config.language, Config.trAuto("Рисование")) : "Рисование"; color: subTab === 4 ? (Config ? Config.accentTextColor : "#000000") : (wMouse4.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 4; checked: Config ? Config.screenDrawEnabled : true; onToggled: if (Config) Config.screenDrawEnabled = checked }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            RowLayout {
                SubCascadeAttach { stepIdx: 6 }
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: 8
                Text {
                    text: "󰏘  Цвета палитры обоев"
                    color: "#dddddd"
                    font.pixelSize: Config.fontSize - 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                StyledSwitch {
                    checked: Widgets ? Widgets.widgetsM3Sync : true
                    onToggled: if (Widgets) Widgets.widgetsM3Sync = checked
                }
            }
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: subTab
        opacity: widgetsRoot.subPageAlpha
        scale: widgetsRoot.subPageScale
        transform: Translate { y: widgetsRoot.subPageOffsetY }

        // Вкладка 0: Оверлей клавиш
        ScrollView {
            id: scrKb; contentWidth: availableWidth; clip: true
            Item {
                width: scrKb.availableWidth; implicitHeight: colKbMain.implicitHeight + 40
                ColumnLayout {
                    id: colKbMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    Text { text: Config ? (Config.language, Config.trAuto("Оверлей клавиатуры и мыши")) : "Оверлей клавиатуры и мыши"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colKb.implicitHeight + 18
                        ColumnLayout {
                            id: colKb; anchors.fill: parent; anchors.margins: 12; spacing: 8
                            Text { text: Config ? (Config.language, Config.trAuto("Компоненты отображения")) : "Компоненты отображения"; color: "#ffffff"; font.pixelSize: Config.fontSize; font.bold: true }
                            RowLayout {
                                spacing: 14
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Клавиатура")) : "Клавиатура"; checked: Widgets.kbShowKeyboard; onToggled: Widgets.kbShowKeyboard = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Мышь")) : "Мышь"; checked: Widgets.kbShowMouse; onToggled: Widgets.kbShowMouse = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Боковые кнопки")) : "Боковые кнопки"; checked: Widgets.kbShowSide; onToggled: Widgets.kbShowSide = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Колесико")) : "Колесико"; checked: Widgets.kbShowWheel; onToggled: Widgets.kbShowWheel = checked }
                            }
                            StyledCheckBox {
                                text: Config ? (Config.language, Config.trAuto("Отображать только комбинации клавиш (Ctrl/Alt/Super/Shift)")) : "Отображать только комбинации клавиш (Ctrl/Alt/Super/Shift)"
                                checked: Widgets.kbOnlyCombos; onToggled: Widgets.kbOnlyCombos = checked
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colKb2.implicitHeight + 18
                        ColumnLayout {
                            id: colKb2; anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text { text: Config ? (Config.language, Config.trAuto("Положение и управление")) : "Положение и управление"; color: "#ffffff"; font.pixelSize: Config.fontSize; font.bold: true }
                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Расположение на экране:")) : "Расположение на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: ["bottom-right", "bottom-left", "top-right", "top-left", "bottom-center", "top-center"]
                                    currentIndex: Math.max(0, model.indexOf(Widgets.kbPosition))
                                    onActivated: (idx) => Widgets.kbPosition = model[idx]
                                }
                            }
                            RowLayout {
                                spacing: 8
                                StyledButton { text: Config ? (Config.language, Config.trAuto("󰈈  Скрыть/Показать (Super + F9)")) : "󰈈  Скрыть/Показать (Super + F9)"; onClicked: Widgets.toggleKbVisibility() }
                                StyledButton { text: Config ? (Config.language, Config.trAuto("↺  Перезапустить процесс")) : "↺  Перезапустить процесс"; onClicked: Widgets.restartKbProcess() }
                            }
                        }
                    }
                }
            }
        }

        // Вкладка 1: Часы на фоне
        ScrollView {
            id: scrClk; contentWidth: availableWidth; clip: true
            Item {
                width: scrClk.availableWidth; implicitHeight: colClkMain.implicitHeight + 40
                ColumnLayout {
                    id: colClkMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    Text { text: Config ? (Config.language, Config.trAuto("Часы на рабочем столе")) : "Часы на рабочем столе"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colClk.implicitHeight + 18
                        ColumnLayout {
                            id: colClk; anchors.fill: parent; anchors.margins: 12; spacing: 10
                            RowLayout {
                                spacing: 14
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("24-часовой формат")) : "24-часовой формат"; checked: Widgets.clock24h; onToggled: Widgets.clock24h = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Секунды")) : "Секунды"; checked: Widgets.clockShowSeconds; onToggled: Widgets.clockShowSeconds = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Дата")) : "Дата"; checked: Widgets.clockShowDate; onToggled: Widgets.clockShowDate = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("День недели")) : "День недели"; checked: Widgets.clockShowWeekday; onToggled: Widgets.clockShowWeekday = checked }
                            }
                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Размер часов:")) : "Размер часов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 160 }
                                StyledSlider { Layout.fillWidth: true; from: 24; to: 140; stepSize: 2; value: Widgets.clockSize; onMoved: Widgets.clockSize = Math.round(value) }
                                Text { text: Widgets.clockSize + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 40 }
                            }
                            RowLayout {
                                Text { text: Config ? (Config.language, Config.trAuto("Прозрачность часов:")) : "Прозрачность часов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 160 }
                                StyledSlider { Layout.fillWidth: true; from: 0.1; to: 1.0; stepSize: 0.05; value: Widgets.clockOpacity; onMoved: Widgets.clockOpacity = value }
                                Text { text: Math.round(Widgets.clockOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 40 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Цвета темы (палитра обоев):")) : "Цвета темы (палитра обоев):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch {
                                    checked: Widgets ? Widgets.clockM3Sync : true
                                    onToggled: if (Widgets) Widgets.clockM3Sync = checked
                                }
                            }
                            RowLayout {
                                spacing: 8
                                StyledButton { text: Config ? (Config.language, Config.trAuto("󰆓  Сохранить параметры")) : "󰆓  Сохранить параметры"; onClicked: Widgets.saveClock() }
                                StyledButton { text: Config ? (Config.language, Config.trAuto("↺  Перезапустить часы")) : "↺  Перезапустить часы"; onClicked: Widgets.restartClockProcess() }
                            }
                        }
                    }
                }
            }
        }

        // Вкладка 2: Системный оверлей (sysinfo_overlay)
        ScrollView {
            id: scrSysInfo; contentWidth: availableWidth; clip: true
            Item {
                width: scrSysInfo.availableWidth; implicitHeight: colSysInfoMain.implicitHeight + 40
                ColumnLayout {
                    id: colSysInfoMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: Config ? (Config.language, Config.trAuto("Системный оверлей (SysInfo Overlay)")) : "Системный оверлей (SysInfo Overlay)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true; Layout.fillWidth: true }
                        StyledButton { text: Config ? (Config.language, Config.trAuto("↺  Перезапустить")) : "↺  Перезапустить"; onClicked: Widgets.restartSysProcess() }
                        StyledButton { text: Config ? (Config.language, Config.trAuto("Сброс")) : "Сброс"; onClicked: Widgets.resetSysDefaults() }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colSysMetrics.implicitHeight + 20
                        ColumnLayout {
                            id: colSysMetrics; anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text { text: Config ? (Config.language, Config.trAuto("Отображаемые графики и сводка")) : "Отображаемые графики и сводка"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 12
                                rowSpacing: 6
                                StyledCheckBox { text: "󰻠  CPU"; checked: Widgets.sysShowCpu; onToggled: Widgets.sysShowCpu = checked }
                                StyledCheckBox { text: "󰍛  RAM"; checked: Widgets.sysShowRam; onToggled: Widgets.sysShowRam = checked }
                                StyledCheckBox { text: "󰛳  NET"; checked: Widgets.sysShowNet; onToggled: Widgets.sysShowNet = checked }
                                StyledCheckBox { text: "  TEMP"; checked: Widgets.sysShowTemp; onToggled: Widgets.sysShowTemp = checked }
                                StyledCheckBox { text: "󰘳  Процессы"; checked: Widgets.sysShowProcs; onToggled: Widgets.sysShowProcs = checked }
                                StyledCheckBox { text: Config ? (Config.language, Config.trAuto("Диск / Uptime / Ядро")) : "Диск / Uptime / Ядро"; checked: Widgets.sysShowExtra; onToggled: Widgets.sysShowExtra = checked }
                            }
                            RowLayout {
                                visible: Widgets.sysShowProcs
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Сортировка процессов в оверлее:")) : "Сортировка процессов в оверлее:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["По CPU (%)", "По ОЗУ (RAM)"]
                                    selectedIndex: Widgets.sysProcSort === "ram" ? 1 : 0
                                    onSelected: (idx) => Widgets.sysProcSort = (idx === 1 ? "ram" : "cpu")
                                }
                            }
                            RowLayout {
                                visible: Widgets.sysShowProcs
                                Layout.fillWidth: true
                                Text { text: (Config ? (Config.language, Config.trAuto("Количество процессов:")) : "Количество процессов:") + " " + Widgets.sysProcCount; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 1; to: 20; stepSize: 1
                                    value: Widgets.sysProcCount
                                    onMoved: Widgets.sysProcCount = Math.round(value)
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Поверх всех окон (Top Layer / Overlay):")) : "Поверх всех окон (Top Layer / Overlay):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Widgets.sysTopLayer; onToggled: Widgets.sysTopLayer = checked }
                            }
                        }
                    }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colSysStyle.implicitHeight + 20
                        ColumnLayout {
                            id: colSysStyle; anchors.fill: parent; anchors.margins: 12; spacing: 10
                            Text { text: Config ? (Config.language, Config.trAuto("Позиция, размеры и цвета")) : "Позиция, размеры и цвета"; color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Позиция на экране:")) : "Позиция на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 190 }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["top-right", "top-left", "bottom-right", "bottom-left"]
                                    selectedIndex: Math.max(0, options.indexOf(Widgets.sysPosition))
                                    onSelected: (idx) => Widgets.sysPosition = options[idx]
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Масштаб оверлея:")) + " " + Widgets.sysScale.toFixed(2) + "x" : "Масштаб оверлея: " + Widgets.sysScale.toFixed(2) + "x"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.4; to: 2.2; stepSize: 0.05; value: Widgets.sysScale; onMoved: Widgets.sysScale = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Прозрачность:")) + " " + Math.round(Widgets.sysOpacity * 100) + "%" : "Прозрачность: " + Math.round(Widgets.sysOpacity * 100) + "%"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.1; to: 1.0; stepSize: 0.05; value: Widgets.sysOpacity; onMoved: Widgets.sysOpacity = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Шрифт заголовков:")) + " " + Widgets.sysTitleSize + " px" : "Шрифт заголовков: " + Widgets.sysTitleSize + " px"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 8; to: 28; stepSize: 1; value: Widgets.sysTitleSize; onMoved: Widgets.sysTitleSize = Math.round(value) }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Шрифт сводки (Диск/Ядро):")) + " " + Widgets.sysExtraSize + " px" : "Шрифт сводки (Диск/Ядро): " + Widgets.sysExtraSize + " px"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 8; to: 28; stepSize: 1; value: Widgets.sysExtraSize; onMoved: Widgets.sysExtraSize = Math.round(value) }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Отступ по горизонтали (X):")) + " " + Widgets.sysMarginX + " px" : "Отступ по горизонтали (X): " + Widgets.sysMarginX + " px"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0; to: 240; stepSize: 2; value: Widgets.sysMarginX; onMoved: Widgets.sysMarginX = Math.round(value) }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: Config ? (Config.language, Config.trAuto("Отступ по вертикали (Y):")) + " " + Widgets.sysMarginY + " px" : "Отступ по вертикали (Y): " + Widgets.sysMarginY + " px"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0; to: 240; stepSize: 2; value: Widgets.sysMarginY; onMoved: Widgets.sysMarginY = Math.round(value) }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                Text { text: Config ? (Config.language, Config.trAuto("Цвет текста:")) : "Цвет текста:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                Rectangle { width: 22; height: 22; radius: 4; color: Widgets.sysTextColor; border.color: "#55ffffff"; border.width: 1 }
                                StyledButton {
                                    text: Widgets.sysTextColor
                                    onClicked: { widgetsRoot.colorTarget = 0; sysColorModal.openPicker("Цвет текста оверлея", Widgets.sysTextColor) }
                                }
                                Item { Layout.fillWidth: true }
                                Text { text: Config ? (Config.language, Config.trAuto("Цвет графиков:")) : "Цвет графиков:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                Rectangle { width: 22; height: 22; radius: 4; color: Widgets.sysGraphColor; border.color: "#55ffffff"; border.width: 1 }
                                StyledButton {
                                    text: Widgets.sysGraphColor
                                    onClicked: { widgetsRoot.colorTarget = 1; sysColorModal.openPicker("Цвет графиков оверлея", Widgets.sysGraphColor) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Вкладка 3: Информеры
        ScrollView {
            id: scrSys; contentWidth: availableWidth; clip: true
            Item {
                width: scrSys.availableWidth; implicitHeight: colSysMain.implicitHeight + 40
                ColumnLayout {
                    id: colSysMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    Text { text: Config ? (Config.language, Config.trAuto("Мониторы процессов и системная сводка")) : "Мониторы процессов и системная сводка"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: infWrapper.implicitHeight + 24
                        Item {
                            id: infWrapper; anchors.fill: parent; anchors.margins: 12; implicitHeight: colSys.implicitHeight
                            property Item hoveredInfObj: null
                            property Item lastHoveredInfObj: null

                            Rectangle {
                                id: infHoverPill
                                x: 0; width: infWrapper.width
                                height: infWrapper.lastHoveredInfObj ? infWrapper.lastHoveredInfObj.height : 30
                                y: infWrapper.lastHoveredInfObj ? infWrapper.lastHoveredInfObj.y : 0
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: Qt.rgba(1, 1, 1, 0.10); border.color: Qt.rgba(1, 1, 1, 0.38); border.width: 1
                                opacity: infWrapper.hoveredInfObj ? 1.0 : 0.0
                                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 90 } }
                            }

                            ColumnLayout {
                                id: colSys; width: parent.width; spacing: 8
                                Repeater {
                                    model: [
                                        { title: Config ? (Config.language, Config.trAuto("🕒   Часы Peaclock (Foot)")) : "🕒   Часы Peaclock (Foot)", act: () => Widgets.launchPeaclock() },
                                        { title: Config ? (Config.language, Config.trAuto("󰣇   Информер Fastfetch (Foot)")) : "󰣇   Информер Fastfetch (Foot)", act: () => Widgets.launchFastfetch() },
                                        { title: Config ? (Config.language, Config.trAuto("󰍹   Монитор процессов Btop (Kitty)")) : "󰍹   Монитор процессов Btop (Kitty)", act: () => Widgets.launchBtop() }
                                    ]
                                    Button {
                                        id: infBtn; Layout.fillWidth: true; implicitHeight: 30; flat: true
                                        onClicked: modelData.act()
                                        onHoveredChanged: {
                                            if (hovered) { infWrapper.lastHoveredInfObj = infBtn; infWrapper.hoveredInfObj = infBtn }
                                            else if (infWrapper.hoveredInfObj === infBtn) infWrapper.hoveredInfObj = null
                                        }
                                        contentItem: Text {
                                            text: modelData.title; color: infBtn.hovered ? "#ffffff" : "#cccccc"
                                            font.pixelSize: Config.fontSize; verticalAlignment: Text.AlignVCenter; leftPadding: 10
                                        }
                                        background: Rectangle {
                                            radius: (Theme && Theme.isRounded) ? 4 : 0
                                            color: Qt.rgba(1, 1, 1, 0.03); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Вкладка 4: Рисование поверх экрана (Screen Draw)
        ScrollView {
            id: scrDraw; contentWidth: availableWidth; clip: true
            Item {
                width: scrDraw.availableWidth; implicitHeight: colDrawMain.implicitHeight + 44
                ColumnLayout {
                    id: colDrawMain
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 20; spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: Config ? (Config.language, Config.trAuto("Рисование поверх экрана")) : "Рисование поверх экрана"
                            color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            height: 26
                            radius: (Theme && Theme.isRounded) ? 13 : 0
                            width: drawRecLbl.implicitWidth + 18
                            color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.25, 0.25, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: (Waybar && Waybar.recording) ? Qt.rgba(1, 0.35, 0.35, 0.65) : Qt.rgba(1, 1, 1, 0.16)
                            Text {
                                id: drawRecLbl
                                anchors.centerIn: parent
                                text: (Waybar && Waybar.recording) ? "● Идёт запись" : "ALT + ~ (Ё)"
                                color: (Waybar && Waybar.recording) ? "#ff6b6b" : "#cccccc"
                                font.pixelSize: Config.fontSize - 1
                                font.bold: true
                            }
                        }
                        StyledButton {
                            text: "󰏫  Тест на экране"
                            onClicked: if (ScreenDraw) ScreenDraw.requestTest()
                        }
                    }

                    // Карточка кисти, цвета и свечения по краям
                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawBrush.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawBrush; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text {
                                text: Config ? (Config.language, Config.trAuto("Кисть, цвет и свечение по краям")) : "Кисть, цвет и свечение по краям"
                                color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true
                            }

                            // Живое превью линии
                            Rectangle {
                                Layout.fillWidth: true
                                height: 82
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: Qt.rgba(0.05, 0.05, 0.07, 0.92)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                clip: true

                                Canvas {
                                    id: drawPreviewCanvas
                                    anchors.fill: parent
                                    antialiasing: true

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
                                        var left = 26
                                        var right = width - 110
                                        var span = Math.max(80, right - left)
                                        ctx.moveTo(left, h + 10)
                                        ctx.bezierCurveTo(left + span * 0.25, h - 26, left + span * 0.45, h + 28, left + span * 0.72, h - 14)
                                        ctx.quadraticCurveTo(left + span * 0.88, h - 30, right, h + 6)
                                        // Мини-стрелка справа
                                        var ax0 = width - 86, ay0 = h + 14
                                        var ax1 = width - 26, ay1 = h - 14
                                        ctx.moveTo(ax0, ay0)
                                        ctx.lineTo(ax1, ay1)
                                        var ang = Math.atan2(ay1 - ay0, ax1 - ax0)
                                        var hl = 13
                                        ctx.moveTo(ax1, ay1)
                                        ctx.lineTo(ax1 - hl * Math.cos(ang - 0.5), ay1 - hl * Math.sin(ang - 0.5))
                                        ctx.moveTo(ax1, ay1)
                                        ctx.lineTo(ax1 - hl * Math.cos(ang + 0.5), ay1 - hl * Math.sin(ang + 0.5))
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        // Лёгкая сетка фона
                                        ctx.strokeStyle = "rgba(255,255,255,0.04)"
                                        ctx.lineWidth = 1
                                        for (var gx = 20; gx < width; gx += 24) {
                                            ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke()
                                        }
                                        for (var gy = 18; gy < height; gy += 24) {
                                            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
                                        }

                                        var colHex = (Config && Config.screenDrawUseThemeColor)
                                                     ? Config.m3Primary.toString()
                                                     : (Config ? Config.screenDrawColor.toString() : "#ff3b5c")
                                        var rgb = parseCol(colHex)
                                        var r = rgb.r, g = rgb.g, b = rgb.b
                                        var w = Config ? Config.screenDrawLineWidth : 5.0
                                        var st = Config ? Config.screenDrawBrushStyle : 1
                                        var gs = Config ? Config.screenDrawGlowStrength : 0.9
                                        var gm = Math.min(1.4, gs)

                                        ctx.lineCap = "round"
                                        ctx.lineJoin = "round"

                                        if (st === 0) {
                                            traceDemo(ctx)
                                            ctx.lineWidth = w
                                            ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ",0.96)"
                                            ctx.stroke()
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
                                            id: swMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (Config) {
                                                    Config.screenDrawUseThemeColor = false
                                                    Config.screenDrawColor = modelData
                                                }
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                StyledButton {
                                    text: "󰏘  " + (Config ? Config.screenDrawColor.toString().toUpperCase() : "#FF3B5C")
                                    onClicked: {
                                        widgetsRoot.colorTarget = 2
                                        sysColorModal.openPicker("Цвет кисти рисования", Config ? Config.screenDrawColor : "#ff3b5c")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Брать цвет из активной темы обоев:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch {
                                    checked: Config ? Config.screenDrawUseThemeColor : false
                                    onToggled: if (Config) Config.screenDrawUseThemeColor = checked
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Толщина линии: " + (Config ? Config.screenDrawLineWidth.toFixed(1) : "5.0") + " px"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 1.5; to: 24.0; stepSize: 0.5
                                    value: Config ? Config.screenDrawLineWidth : 5.0
                                    onMoved: if (Config) Config.screenDrawLineWidth = value
                                }
                            }

                            RowLayout {
                                visible: Config && Config.screenDrawBrushStyle !== 0
                                Layout.fillWidth: true
                                Text {
                                    text: "Сила свечения по краям: " + Math.round((Config ? Config.screenDrawGlowStrength : 0.9) * 100) + "%"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0.0; to: 1.5; stepSize: 0.05
                                    value: Config ? Config.screenDrawGlowStrength : 0.9
                                    onMoved: if (Config) Config.screenDrawGlowStrength = value
                                }
                            }
                        }
                    }

                    // Карточка поведения и таймеров исчезновения
                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawTiming.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawTiming; anchors.fill: parent; anchors.margins: 13; spacing: 11

                            Text {
                                text: Config ? (Config.language, Config.trAuto("Таймеры исчезновения и бинд")) : "Таймеры исчезновения и бинд"
                                color: Config.accentColor; font.pixelSize: Config.fontSize + 1; font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Активировать только во время записи экрана (Super + F10):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch {
                                    checked: Config ? Config.screenDrawOnlyRecording : true
                                    onToggled: if (Config) Config.screenDrawOnlyRecording = checked
                                }
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
                                Text {
                                    text: "Держать линии после отпускания: " + (Config ? Config.screenDrawFadeDelay.toFixed(1) : "2.5") + " сек"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0.0; to: 15.0; stepSize: 0.5
                                    value: Config ? Config.screenDrawFadeDelay : 2.5
                                    onMoved: if (Config) Config.screenDrawFadeDelay = value
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Плавность исчезновения: " + (Config ? Config.screenDrawFadeDuration.toFixed(1) : "0.8") + " сек"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270
                                }
                                StyledSlider {
                                    Layout.fillWidth: true
                                    from: 0.1; to: 4.0; stepSize: 0.1
                                    value: Config ? Config.screenDrawFadeDuration : 0.8
                                    onMoved: if (Config) Config.screenDrawFadeDuration = value
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Показывать кольцо кисти и подсказку внизу при рисовании:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch {
                                    checked: Config ? Config.screenDrawShowHint : true
                                    onToggled: if (Config) Config.screenDrawShowHint = checked
                                }
                            }
                        }
                    }

                    // Карточка подсказок управления
                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true; implicitHeight: colDrawKeys.implicitHeight + 22
                        ColumnLayout {
                            id: colDrawKeys; anchors.fill: parent; anchors.margins: 13; spacing: 7

                            Text { text: "⌨  Управление во время рисования"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            Repeater {
                                model: [
                                    { k: "ALT + ~ (Ё)", d: "Удерживать и рисовать (работает и в EN, и в RU раскладке; клики возвращаются сразу после отпускания)" },
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
