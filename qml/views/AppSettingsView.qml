import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

RowLayout {
    id: appSetRoot
    spacing: 0

    property int subTab: 0
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

    // Левое подменю разделов настроек (с плавной анимацией наведения и выбора как во вкладке Виджеты)
    Rectangle {
        id: subSidebar
        Layout.fillHeight: true
        Layout.preferredWidth: 195
        color: Qt.rgba(0.04, 0.04, 0.04, Config ? Config.sidebarOpacity : 0.35)

        property Item activeCardObj: subTab === 0 ? sCard0 : (subTab === 1 ? sCard1 : (subTab === 2 ? sCard2 : (subTab === 3 ? sCard3 : sCard4)))
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
                    Text { text: "Тема и Цвета"; color: subTab === 0 ? (Config ? Config.accentTextColor : "#000000") : (sMouse0.containsMouse ? "#ffffff" : "#cccccc"); font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                    StyledSwitch { z: 10; inverted: subTab === 0; checked: Theme && Theme.isRounded; onToggled: if (Theme) Theme.setRoundedState(checked) }
                }
            }

            Item {
                id: sCard1; Layout.fillWidth: true; implicitHeight: 30
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

            Item { Layout.fillHeight: true }

            StyledButton {
                Layout.fillWidth: true
                allowFullWidth: true
                text: "↺ Сбросить всё"
                onClicked: Config.resetDefaults()
            }
        }
    }

    // Правая область со страницами каждого раздела
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: appSetRoot.subTab

        // =====================================================================
        // РАЗДЕЛ 0: ТЕМА MATERIAL DESIGN 3 И ЦВЕТА (С ТУМБЛЕРОМ СКРУГЛЕНИЙ)
        // =====================================================================
        ScrollView {
            id: scrTheme; contentWidth: availableWidth; clip: true
            Item {
                width: scrTheme.availableWidth; implicitHeight: colThemeMain.implicitHeight + 44
                ColumnLayout {
                    id: colThemeMain
                    width: Math.min(parent.width - 36, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: appSetRoot.isM3 ? 14 : 10

                    Text {
                        text: "󰏘  Тема оформления, Скругление окон и Цвета (Material Design 3)"
                        color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
                    }

                    // Главная карточка переключения скруглений и палитры
                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colMode.implicitHeight + 28
                        ColumnLayout {
                            id: colMode; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Скругление окон и стиль Material Design 3:"
                                    color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true
                                    Layout.fillWidth: true
                                }
                                SegmentedButton {
                                    Layout.preferredWidth: 300
                                    options: ["Квадратный (Sharp)", "Material Design 3"]
                                    selectedIndex: (Theme && Theme.isRounded) ? 1 : 0
                                    onSelected: (idx) => { if (Theme) Theme.setRoundedState(idx === 1) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "Авто-палитра из текущих обоев (окрашивает HySett, Kitty, Firefox, GTK):"
                                    color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true
                                }
                                StyledButton {
                                    text: "󰸉 Извлечь из обоев"
                                    onClicked: if (Config) { Config.m3DynamicWallpaperColors = true; Config.extractPaletteFromWallpaper() }
                                }
                                StyledSwitch {
                                    checked: Config ? Config.m3DynamicWallpaperColors : true
                                    onToggled: if (Config) Config.m3DynamicWallpaperColors = checked
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true
                                    text: "↺ Классический дефолтный цвет (без палитр)"
                                    onClicked: if (Config) Config.resetToDefaultMonochrome()
                                }
                                StyledButton {
                                    Layout.fillWidth: true; allowFullWidth: true
                                    text: "󰏘 Применить тему обоев в AyuGram"
                                    onClicked: if (Waybar) Waybar.runCommand("env -u QT_SCALE_FACTOR AyuGram ~/.cache/hysett_ayugram.tdesktop-theme")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "Готовые тональные палитры Material You:"; color: "#cccccc"; font.pixelSize: Config.fontSize }
                                SegmentedButton {
                                    Layout.fillWidth: true
                                    options: ["Pixel Blue", "Emerald", "Lavender", "Sakura", "Amber", "Ocean"]
                                    selectedIndex: Config ? Config.m3Preset : 0
                                    onSelected: (idx) => { if (Config) Config.applyM3Preset(idx) }
                                }
                            }
                        }
                    }

                    // Карточка геометрии и атрибутов MD3
                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colM3Geom.implicitHeight + 28
                        ColumnLayout {
                            id: colM3Geom; anchors.fill: parent; anchors.margins: 14; spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Геометрия и атрибуты поверхностей MD3"; color: Config ? Config.m3Primary : "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                                StyledButton { text: "↺ Сбросить геометрию"; onClicked: if (Config) Config.resetM3Attributes() }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Стиль карточек (Elevation Style):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 320
                                    options: ["Тональный", "Контурный", "Приподнятый"]
                                    selectedIndex: Config ? Config.m3ElevationStyle : 0
                                    onSelected: (idx) => { if (Config) Config.m3ElevationStyle = idx }
                                }
                            }

                            RowLayout {
                                Text { text: "Сила оттенка обоев на фоне и окнах (Surface Tint):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3SurfaceTintStrength : 0.22; onMoved: if (Config) Config.m3SurfaceTintStrength = value }
                                Text { text: Math.round((Config ? Config.m3SurfaceTintStrength : 0.22) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Уровень контрастности MD3 (Contrast):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3ContrastLevel : 0.50; onMoved: if (Config) Config.m3ContrastLevel = value }
                                Text { text: Math.round((Config ? Config.m3ContrastLevel : 0.50) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Радиус скругления окна (Window Radius):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 4; to: 32; stepSize: 1; value: Config ? Config.m3WindowRadius : 20; onMoved: if (Config) Config.m3WindowRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3WindowRadius : 20) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Радиус карточек (Card Radius):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 4; to: 28; stepSize: 1; value: Config ? Config.m3CardRadius : 16; onMoved: if (Config) Config.m3CardRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3CardRadius : 16) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Радиус кнопок и элементов (Control Radius):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 2; to: 20; stepSize: 1; value: Config ? Config.m3ControlRadius : 12; onMoved: if (Config) Config.m3ControlRadius = Math.round(value) }
                                Text { text: (Config ? Config.m3ControlRadius : 12) + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Толщина и прозрачность контуров (Outline):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 270 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.m3OutlineOpacity : 0.28; onMoved: if (Config) Config.m3OutlineOpacity = value }
                                Text { text: Math.round((Config ? Config.m3OutlineOpacity : 0.28) * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }

                    // Ручное редактирование ролей палитры
                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colColors.implicitHeight + 28
                        ColumnLayout {
                            id: colColors; anchors.fill: parent; anchors.margins: 14; spacing: 10
                            Text { text: "Ручная настройка цветов палитры"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                            RowLayout {
                                Text { text: "Синхронизировать свечение и курсор с основным акцентом:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config.syncColorsWithAccent; onToggled: Config.syncColorsWithAccent = checked }
                            }

                            Repeater {
                                model: [
                                    { label: "Primary (Основной акцент MD3):", role: 0, col: Config.accentColor },
                                    { label: "Secondary (Вторичный акцент MD3):", role: 5, col: Config.m3SecondaryColor },
                                    { label: "Tertiary (Третичный акцент MD3):", role: 6, col: Config.m3TertiaryColor },
                                    { label: "Surface (Фон окна):", role: 3, col: Config.windowBgColor },
                                    { label: "Surface Container (Фон карточек):", role: 4, col: Config.cardBgColor },
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
                    width: Math.min(parent.width - 36, 860)
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
                                Text { text: "Язык интерфейса (Language):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 240
                                    options: ["Русский", "English"]
                                    selectedIndex: Config.language === "en" ? 1 : 0
                                    onSelected: (idx) => Config.language = (idx === 1 ? "en" : "ru")
                                }
                            }

                            RowLayout {
                                Text { text: "Запоминать последнюю открытую вкладку:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Config.rememberLastTab; onToggled: Config.rememberLastTab = checked }
                            }

                            RowLayout {
                                Text { text: "Высота окна (при след. запуске):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 520; to: 960; stepSize: 10; value: Config.windowHeight; onMoved: Config.windowHeight = Math.round(value) }
                                Text { text: Config.windowHeight + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Масштаб интерфейса (UI Scale):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.80; to: 1.25; stepSize: 0.05; value: Config.uiScale; onMoved: Config.uiScale = value }
                                Text { text: Math.round(Config.uiScale * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Размер шрифта:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 9; to: 14; stepSize: 1; value: Config.fontSize; onMoved: Config.fontSize = Math.round(value) }
                                Text { text: Config.fontSize + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Текст бокового меню:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 240
                                    options: ["Слева", "По центру"]
                                    selectedIndex: Config.alignCenter ? 1 : 0
                                    onSelected: (idx) => Config.alignCenter = (idx === 1)
                                }
                            }

                            RowLayout {
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
                    width: Math.min(parent.width - 36, 860)
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
        // РАЗДЕЛ 3: СТЕКЛО И ПРОЗРАЧНОСТЬ (LIQUID GLASS)
        // =====================================================================
        ScrollView {
            id: scrGlass; contentWidth: availableWidth; clip: true
            Item {
                width: scrGlass.availableWidth; implicitHeight: colGlassMain.implicitHeight + 44
                ColumnLayout {
                    id: colGlassMain
                    width: Math.min(parent.width - 36, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 20
                    spacing: 14

                    Text { text: "󰖨  Прозрачность, Блюр и Жидкое стекло (Liquid Glass)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: colOp.implicitHeight + 28
                        ColumnLayout {
                            id: colOp; anchors.fill: parent; anchors.margins: 14; spacing: 14

                            RowLayout {
                                Text { text: "Жидкое стекло для кнопок, тумблеров и ползунков:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                StyledSwitch { checked: Theme.controlsLiquidGlass; onToggled: Theme.controlsLiquidGlass = checked }
                            }

                            RowLayout {
                                Text { text: "Главный фон (Окно):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.opacity; onMoved: Config.opacity = value }
                                Text { text: Math.round(Config.opacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Интенсивность блюра окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Theme.windowBlur; onMoved: Theme.windowBlur = value }
                                Text { text: Theme.windowBlur <= 0.01 ? "Выкл" : Math.round(Theme.windowBlur * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Прозрачность диалоговых окон:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.05; to: 1.0; value: Config.dialogOpacity; onMoved: Config.dialogOpacity = value }
                                Text { text: Math.round(Config.dialogOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Блюр диалоговых окон:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; stepSize: 0.02; value: Config.dialogBlur; onMoved: Config.dialogBlur = value }
                                Text { text: Config.dialogBlur <= 0.01 ? "Выкл" : Math.round(Config.dialogBlur * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Искажение стекла (Refraction):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Theme.glassRefraction; onMoved: Theme.glassRefraction = value }
                                Text { text: Math.round(Theme.glassRefraction * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Боковое меню:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 230 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.sidebarOpacity; onMoved: Config.sidebarOpacity = value }
                                Text { text: Math.round(Config.sidebarOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
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
                    width: Math.min(parent.width - 36, 860)
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
                                Text { text: "Направление движения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 340
                                    options: ["По часовой", "Против часовой", "Навстречу"]
                                    selectedIndex: Config.borderGlowDirection
                                    onSelected: (idx) => Config.borderGlowDirection = idx
                                }
                            }

                            RowLayout {
                                Text { text: "Палитра свечения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 420
                                    options: ["Монохром", "Холодный лед", "Аврора", "Теплый неон", "Свой цвет"]
                                    selectedIndex: Config.borderGlowColorMode
                                    onSelected: (idx) => Config.borderGlowColorMode = idx
                                }
                            }

                            RowLayout {
                                Text { text: "Яркость свечения границ:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.05; to: 1.0; value: Config.borderGlowIntensity; onMoved: Config.borderGlowIntensity = value }
                                Text { text: Math.round(Config.borderGlowIntensity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Ширина свечения у края:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.10; to: 1.0; value: Config.borderGlowSpread; onMoved: Config.borderGlowSpread = value }
                                Text { text: Math.round(Config.borderGlowSpread * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Скорость движения света:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.10; to: 2.50; value: Config.borderGlowSpeed; onMoved: Config.borderGlowSpeed = value }
                                Text { text: Math.round(Config.borderGlowSpeed * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Сила свечения и следа от курсора:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                                StyledSlider { Layout.fillWidth: true; from: 0.0; to: 1.0; value: Config.cursorGlowIntensity; onMoved: Config.cursorGlowIntensity = value }
                                Text { text: Math.round(Config.cursorGlowIntensity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                            }

                            RowLayout {
                                Text { text: "Форма вспышки / волны при клике:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                SegmentedButton {
                                    Layout.preferredWidth: 360
                                    options: ["Кольцо", "Импульс", "Звезда", "Двойная волна"]
                                    selectedIndex: Config.clickFlashShape
                                    onSelected: (idx) => Config.clickFlashShape = idx
                                }
                            }

                            RowLayout {
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
                                Text { text: "Отображаемые пункты в боковом меню"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                                StyledButton { text: "Показать все"; visible: Config.hiddenSidebarTabs.length > 0; onClicked: Config.hiddenSidebarTabs = "" }
                            }
                            GridLayout {
                                Layout.fillWidth: true; columns: 3; columnSpacing: 12; rowSpacing: 8
                                Repeater {
                                    model: [
                                        { title: "󰍉  Поиск", idx: 16 }, { title: "󰖙  Погода", idx: 20 }, { title: "   Монитор", idx: 21 },
                                        { title: "  Календарь", idx: 22 }, { title: "󰅌  Буфер", idx: 23 }, { title: "󰖲  Окна", idx: 1 },
                                        { title: "󱐌  Анимации", idx: 2 }, { title: "󰆿  Курсор", idx: 3 }, { title: "󰍹   Мониторы", idx: 4 },
                                        { title: "󰌌  Устройства", idx: 5 }, { title: "󰖩  Сеть", idx: 6 }, { title: "󰂯  Блютуз", idx: 7 },
                                        { title: "󱓞   Панель", idx: 8 }, { title: "󰂚   Уведомления", idx: 18 }, { title: "󰒲   Автозапуск", idx: 9 },
                                        { title: "⌨  Бинды", idx: 10 }, { title: "󰘳  Правила окон", idx: 11 }, { title: "󰀻  Приложения", idx: 12 },
                                        { title: "󰏘  Шейдеры", idx: 13 }, { title: "󰸉  Обои", idx: 14 }, { title: "󰕰  Виджеты", idx: 15 },
                                        { title: "󰎆  Музыка", idx: 27 }, { title: "󰌌  Язык", idx: 25 }, { title: "⏻  Питание", idx: 24 },
                                        { title: "󰦝  VPN", idx: 26 }, { title: "󰖗  Атмосфера", idx: 19 }, { title: "✕  Кнопка Закрыть", idx: 99 }
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
    }
}
