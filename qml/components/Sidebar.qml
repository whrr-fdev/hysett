import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Rectangle {
    id: bar
    property int currentIndex: 0
    signal categorySelected(int index)
    signal returnToWelcome()

    color: (Theme && Theme.isRounded && Config) ? Qt.rgba(Config.m3SurfaceContainer.r, Config.m3SurfaceContainer.g, Config.m3SurfaceContainer.b, Math.max(0.42, Config.sidebarOpacity)) : Qt.rgba(0.04, 0.04, 0.04, Config ? Config.sidebarOpacity : 0.0)

    property Item activeBtnObj: {
        var _ = Config ? Config.hiddenSidebarTabs : ""
        if (bar.currentIndex === 17) return setBtn
        for (var i = 0; i < navRepeater.count; ++i) {
            var it = navRepeater.itemAt(i)
            if (it && it.tabIdx === bar.currentIndex) return it
        }
        return null
    }
    property Item hoveredBtnObj: null
    property Item lastHoveredBtnObj: null

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Выделение и ховер вне скролла (HYPRLAND / Настройки / Закрыть)
    Rectangle {
        id: staticHoverPill
        x: 4
        width: bar.width - 8
        height: 24
        radius: (Theme && Theme.isRounded) ? 12 : 0
        color: Qt.rgba(1, 1, 1, 0.08)
        readonly property bool isStaticTarget: bar.lastHoveredBtnObj === archHeaderItem || bar.lastHoveredBtnObj === setBtn || bar.lastHoveredBtnObj === closeBtn
        opacity: (bar.hoveredBtnObj && isStaticTarget && bar.hoveredBtnObj !== bar.activeBtnObj) ? 1.0 : 0.0
        y: isStaticTarget ? (mainColLayout.y + bar.lastHoveredBtnObj.y) : 0
        Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    Rectangle {
        id: settingsActivePill
        x: 4
        width: bar.width - 8
        height: 24
        radius: (Theme && Theme.isRounded) ? 12 : 0
        color: Config ? Config.accentColor : "#ffffff"
        visible: bar.currentIndex === 17
        y: mainColLayout.y + setBtn.y
    }

    // Клип-контейнер строго по границам catScroll (выделение никогда не залезает на HYPRLAND сверху и Настройки снизу!)
    Item {
        x: 0
        y: mainColLayout.y + catScroll.y
        width: bar.width
        height: catScroll.height
        clip: true

        Rectangle {
            id: globalHoverPill
            x: 4
            width: bar.width - 8
            height: 24
            radius: (Theme && Theme.isRounded) ? 12 : 0
            color: Qt.rgba(1, 1, 1, 0.08)
            readonly property bool isScrollTarget: bar.lastHoveredBtnObj && bar.lastHoveredBtnObj !== archHeaderItem && bar.lastHoveredBtnObj !== setBtn && bar.lastHoveredBtnObj !== closeBtn
            opacity: (bar.hoveredBtnObj && isScrollTarget && bar.hoveredBtnObj !== bar.activeBtnObj) ? 1.0 : 0.0
            y: isScrollTarget ? (bar.lastHoveredBtnObj.y - catScroll.contentItem.contentY) : 0
            Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: activeCategoryPill
            x: 4
            width: bar.width - 8
            height: 24
            radius: (Theme && Theme.isRounded) ? 12 : 0
            color: Config ? Config.accentColor : "#ffffff"
            visible: bar.currentIndex > 0 && bar.currentIndex !== 17 && bar.activeBtnObj !== null && bar.activeBtnObj.opacity > 0.5
            y: (bar.activeBtnObj && bar.activeBtnObj !== setBtn) ? (bar.activeBtnObj.y - catScroll.contentItem.contentY) : 0
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }
    }

    ColumnLayout {
        id: mainColLayout
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Button {
            id: archHeaderItem
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            Layout.minimumHeight: 24
            implicitHeight: 24
            flat: true
            background: Item {}
            contentItem: Item {
                anchors.fill: parent
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Image { width: 14; height: 14; sourceSize: Qt.size(28, 28); smooth: true; opacity: archHeaderItem.hovered ? 1.0 : 0.85; anchors.verticalCenter: parent.verticalCenter; source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg" }
                    Text { text: "HYPRLAND"; color: archHeaderItem.hovered ? "#ffffff" : "#aaaaaa"; font.pixelSize: 10; font.bold: false; font.letterSpacing: 1.2; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onHoveredChanged: {
                if (hovered) {
                    bar.lastHoveredBtnObj = archHeaderItem
                    bar.hoveredBtnObj = archHeaderItem
                } else if (bar.hoveredBtnObj === archHeaderItem) {
                    bar.hoveredBtnObj = null
                }
            }
            onClicked: { bar.categorySelected(0); bar.returnToWelcome() }
        }

        Rectangle {
            objectName: "sidebarSepLine"
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
            Layout.topMargin: 1
            Layout.bottomMargin: 2
        }

        ScrollView {
            id: catScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.35)
                }
            }

            ColumnLayout {
                id: navCol
                width: catScroll.availableWidth
                spacing: 0

                Repeater {
                    id: navRepeater
                    model: [
                        { title: "Поиск", icon: "󰍉", idx: 16 },
                        { title: "Погода", icon: "󰖙", idx: 20 },
                        { title: "Музыка", icon: "󰎆", idx: 27 },
                        { title: "Монитор", icon: "", idx: 21 },
                        { title: "Календарь", icon: "", idx: 22 },
                        { title: "Буфер", icon: "󰅌", idx: 23 },
                        { title: "Язык", icon: "󰌌", idx: 25 },
                        { title: "Питание", icon: "⏻", idx: 24 },
                        { title: "Окна", icon: "󰖲", idx: 1 },
                        { title: "Анимации", icon: "󱐌", idx: 2 },
                        { title: "Курсор", icon: "󰆿", idx: 3 },
                        { title: "Мониторы", icon: "󰍹", idx: 4 },
                        { title: "Устройства", icon: "󰌌", idx: 5 },
                        { title: "Сеть", icon: "󰖩", idx: 6 },
                        { title: "VPN", icon: "󰦝", idx: 26 },
                        { title: "Блютуз", icon: "󰂯", idx: 7 },
                        { title: "Панель", icon: "󱓞", idx: 8 },
                        { title: "Уведомления", icon: "󰂚", idx: 18 },
                        { title: "Автозапуск", icon: "󰒲", idx: 9 },
                        { title: "Бинды", icon: "⌨", idx: 10 },
                        { title: "Правила окон", icon: "󰘳", idx: 11 },
                        { title: "Приложения", icon: "󰀻", idx: 12 },
                        { title: "Шейдеры", icon: "󰏘", idx: 13 },
                        { title: "Обои", icon: "󰸉", idx: 14 },
                        { title: "Виджеты", icon: "󰕰", idx: 15 },
                        { title: "Атмосфера", icon: "󰖗", idx: 19 }
                    ]

                    NavButton {
                        id: nb
                        tabIdx: modelData.idx
                        property bool isShown: {
                            var _ = Config ? Config.hiddenSidebarTabs : ""
                            return Config ? Config.isTabVisible(modelData.idx) : true
                        }
                        Layout.fillWidth: true
                        Layout.preferredHeight: isShown ? 25 : 0
                        Layout.maximumHeight: isShown ? 25 : 0
                        implicitHeight: isShown ? 25 : 0
                        opacity: isShown ? 1.0 : 0.0
                        visible: Layout.preferredHeight > 0.5 || opacity > 0.01
                        enabled: isShown
                        clip: true

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on Layout.maximumHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        text: Config ? (Config.language, Config.trAuto(modelData.title)) : modelData.title
                        iconSymbol: modelData.icon
                        isActive: bar.currentIndex === modelData.idx
                        background: Item {}
                        onPressed: bar.categorySelected(modelData.idx)
                        onHoveredChanged: {
                            if (hovered && isShown) {
                                bar.lastHoveredBtnObj = nb
                                bar.hoveredBtnObj = nb
                            } else if (bar.hoveredBtnObj === nb) {
                                bar.hoveredBtnObj = null
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            objectName: "sidebarSepLine"
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        NavButton {
            id: setBtn
            tabIdx: 17
            Layout.fillWidth: true
            text: Config ? (Config.language, Config.trAuto("Настройки")) : "Настройки"
            iconSymbol: "󰒓"
            isActive: bar.currentIndex === 17
            background: Item {}
            onPressed: bar.categorySelected(17)
            onHoveredChanged: {
                if (hovered) {
                    bar.lastHoveredBtnObj = setBtn
                    bar.hoveredBtnObj = setBtn
                } else if (bar.hoveredBtnObj === setBtn) {
                    bar.hoveredBtnObj = null
                }
            }
        }

        Button {
            id: closeBtn
            property bool isCloseShown: {
                var _ = Config ? Config.hiddenSidebarTabs : ""
                return Config ? Config.isTabVisible(99) : true
            }
            Layout.fillWidth: true
            Layout.preferredHeight: isCloseShown ? 24 : 0
            Layout.maximumHeight: isCloseShown ? 24 : 0
            implicitHeight: isCloseShown ? 24 : 0
            opacity: isCloseShown ? 1.0 : 0.0
            visible: Layout.preferredHeight > 0.5 || opacity > 0.01
            enabled: isCloseShown
            clip: true
            flat: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            onClicked: if (ApplicationWindow.window) ApplicationWindow.window.requestCloseDrawer()

            contentItem: Item {
                anchors.fill: parent
                Row {
                    id: closeRow
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: (Config && Config.alignCenter)
                       ? Math.round((parent.width - closeRow.width) / 2)
                       : 10
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Text { text: "✕"; color: closeBtn.hovered ? "#ffffff" : "#888888"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Config ? (Config.language, Config.trAuto("Закрыть")) : "Закрыть"; color: closeBtn.hovered ? "#ffffff" : "#888888"; font.pixelSize: Config.fontSize; font.bold: false; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            background: Item {}

            onHoveredChanged: {
                if (hovered) {
                    bar.lastHoveredBtnObj = closeBtn
                    bar.hoveredBtnObj = closeBtn
                } else if (bar.hoveredBtnObj === closeBtn) {
                    bar.hoveredBtnObj = null
                }
            }
        }
    }
}
