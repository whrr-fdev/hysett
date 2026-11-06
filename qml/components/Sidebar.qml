import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Rectangle {
    id: bar
    property int currentIndex: 0
    signal categorySelected(int index)
    signal returnToWelcome()
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property int itemH: isM3 ? 32 : 25
    readonly property int pillH: isM3 ? 30 : 24

    color: "transparent"

    // Фон M3 Navigation Drawer (отделенный скругленный контейнер в режиме MD3)
    Rectangle {
        anchors.fill: parent
        anchors.margins: bar.isM3 ? 6 : 0
        anchors.rightMargin: bar.isM3 ? 4 : 0
        radius: bar.isM3 ? (Config ? Math.min(22, Config.m3CardRadius + 4) : 20) : 0
        color: bar.isM3 && Config
               ? Qt.rgba(Config.m3SurfaceContainer.r, Config.m3SurfaceContainer.g, Config.m3SurfaceContainer.b, Math.max(0.72, Config.sidebarOpacity + 0.55))
               : Qt.rgba(0.04, 0.04, 0.04, Config ? Config.sidebarOpacity : 0.0)
        Behavior on radius { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

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
        visible: !bar.isM3
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    Rectangle {
        id: staticHoverPill
        x: bar.isM3 ? 10 : 4
        width: bar.width - (bar.isM3 ? 18 : 8)
        height: bar.pillH
        radius: bar.isM3 ? height / 2 : 0
        color: bar.isM3 && Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.08)
        readonly property bool isStaticTarget: bar.lastHoveredBtnObj === archHeaderItem || bar.lastHoveredBtnObj === setBtn || bar.lastHoveredBtnObj === closeBtn
        opacity: (bar.hoveredBtnObj && isStaticTarget && bar.hoveredBtnObj !== bar.activeBtnObj) ? 1.0 : 0.0
        y: isStaticTarget ? (mainColLayout.y + bar.lastHoveredBtnObj.y + (bar.lastHoveredBtnObj.height - height) * 0.5) : 0
        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 90 } }
    }

    Rectangle {
        id: settingsActivePill
        x: bar.isM3 ? 10 : 4
        width: bar.width - (bar.isM3 ? 18 : 8)
        height: bar.pillH
        radius: bar.isM3 ? height / 2 : 0
        color: bar.isM3 && Config ? Config.m3SecondaryContainer : (Config ? Config.accentColor : "#ffffff")
        visible: bar.currentIndex === 17
        y: mainColLayout.y + setBtn.y + (setBtn.height - height) * 0.5
    }

    Item {
        x: 0
        y: mainColLayout.y + catScroll.y
        width: bar.width
        height: catScroll.height
        clip: true

        Rectangle {
            id: globalHoverPill
            x: bar.isM3 ? 10 : 4
            width: bar.width - (bar.isM3 ? 18 : 8)
            height: bar.pillH
            radius: bar.isM3 ? height / 2 : 0
            color: bar.isM3 && Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.08)
            readonly property bool isScrollTarget: bar.lastHoveredBtnObj && bar.lastHoveredBtnObj !== archHeaderItem && bar.lastHoveredBtnObj !== setBtn && bar.lastHoveredBtnObj !== closeBtn
            opacity: (bar.hoveredBtnObj && isScrollTarget && bar.hoveredBtnObj !== bar.activeBtnObj) ? 1.0 : 0.0
            y: isScrollTarget ? (bar.lastHoveredBtnObj.y - catScroll.contentItem.contentY + (bar.itemH - height) * 0.5) : 0
            Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Rectangle {
            id: activeCategoryPill
            x: bar.isM3 ? 10 : 4
            width: bar.width - (bar.isM3 ? 18 : 8)
            height: bar.pillH
            radius: bar.isM3 ? height / 2 : 0
            color: bar.isM3 && Config ? Config.m3SecondaryContainer : (Config ? Config.accentColor : "#ffffff")
            visible: bar.currentIndex > 0 && bar.currentIndex !== 17 && bar.activeBtnObj !== null && bar.activeBtnObj.opacity > 0.5
            y: (bar.activeBtnObj && bar.activeBtnObj !== setBtn) ? (bar.activeBtnObj.y - catScroll.contentItem.contentY + (bar.itemH - height) * 0.5) : 0
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }
    }

    ColumnLayout {
        id: mainColLayout
        anchors.fill: parent
        anchors.margins: bar.isM3 ? 10 : 4
        spacing: bar.isM3 ? 4 : 2

        Button {
            id: archHeaderItem
            Layout.fillWidth: true
            Layout.preferredHeight: bar.isM3 ? 34 : 24
            Layout.minimumHeight: bar.isM3 ? 34 : 24
            implicitHeight: bar.isM3 ? 34 : 24
            flat: true
            background: Item {}
            contentItem: Item {
                anchors.fill: parent
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Image { width: 15; height: 15; sourceSize: Qt.size(30, 30); smooth: true; opacity: archHeaderItem.hovered ? 1.0 : 0.9; anchors.verticalCenter: parent.verticalCenter; source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg" }
                    Text { text: "HYPRLAND"; color: bar.isM3 && Config ? Config.m3Primary : (archHeaderItem.hovered ? "#ffffff" : "#aaaaaa"); font.pixelSize: 11; font.bold: bar.isM3; font.letterSpacing: 1.4; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onHoveredChanged: {
                if (hovered) { bar.lastHoveredBtnObj = archHeaderItem; bar.hoveredBtnObj = archHeaderItem }
                else if (bar.hoveredBtnObj === archHeaderItem) bar.hoveredBtnObj = null
            }
            onClicked: { bar.categorySelected(0); bar.returnToWelcome() }
        }

        Rectangle {
            objectName: "sidebarSepLine"
            Layout.fillWidth: true
            Layout.leftMargin: bar.isM3 ? 8 : 0
            Layout.rightMargin: bar.isM3 ? 8 : 0
            height: 1
            color: bar.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18) : Qt.rgba(1, 1, 1, 0.06)
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
                spacing: bar.isM3 ? 2 : 0

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
                        Layout.preferredHeight: isShown ? bar.itemH : 0
                        Layout.maximumHeight: isShown ? bar.itemH : 0
                        implicitHeight: isShown ? bar.itemH : 0
                        opacity: isShown ? 1.0 : 0.0
                        visible: Layout.preferredHeight > 0.5 || opacity > 0.01
                        enabled: isShown
                        clip: true

                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        text: Config ? (Config.language, Config.trAuto(modelData.title)) : modelData.title
                        iconSymbol: modelData.icon
                        isActive: bar.currentIndex === modelData.idx
                        background: Item {}
                        onPressed: bar.categorySelected(modelData.idx)
                        onHoveredChanged: {
                            if (hovered && isShown) { bar.lastHoveredBtnObj = nb; bar.hoveredBtnObj = nb }
                            else if (bar.hoveredBtnObj === nb) bar.hoveredBtnObj = null
                        }
                    }
                }
            }
        }

        Rectangle {
            objectName: "sidebarSepLine"
            Layout.fillWidth: true
            Layout.leftMargin: bar.isM3 ? 8 : 0
            Layout.rightMargin: bar.isM3 ? 8 : 0
            height: 1
            color: bar.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18) : Qt.rgba(1, 1, 1, 0.06)
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        NavButton {
            id: setBtn
            tabIdx: 17
            Layout.fillWidth: true
            Layout.preferredHeight: bar.itemH
            text: Config ? (Config.language, Config.trAuto("Настройки")) : "Настройки"
            iconSymbol: "󰒓"
            isActive: bar.currentIndex === 17
            background: Item {}
            onPressed: bar.categorySelected(17)
            onHoveredChanged: {
                if (hovered) { bar.lastHoveredBtnObj = setBtn; bar.hoveredBtnObj = setBtn }
                else if (bar.hoveredBtnObj === setBtn) bar.hoveredBtnObj = null
            }
        }

        Button {
            id: closeBtn
            property bool isCloseShown: {
                var _ = Config ? Config.hiddenSidebarTabs : ""
                return Config ? Config.isTabVisible(99) : true
            }
            Layout.fillWidth: true
            Layout.preferredHeight: isCloseShown ? (bar.isM3 ? 30 : 24) : 0
            Layout.maximumHeight: isCloseShown ? (bar.isM3 ? 30 : 24) : 0
            implicitHeight: isCloseShown ? (bar.isM3 ? 30 : 24) : 0
            opacity: isCloseShown ? 1.0 : 0.0
            visible: Layout.preferredHeight > 0.5 || opacity > 0.01
            enabled: isCloseShown
            clip: true
            flat: true
            onClicked: if (ApplicationWindow.window) ApplicationWindow.window.requestCloseDrawer()

            contentItem: Item {
                anchors.fill: parent
                Row {
                    id: closeRow
                    spacing: bar.isM3 ? 10 : 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: (Config && Config.alignCenter)
                       ? Math.round((parent.width - closeRow.width) / 2)
                       : (bar.isM3 ? 14 : 10)
                    Text { text: "✕"; color: closeBtn.hovered ? "#ff6b6b" : "#888888"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Config ? (Config.language, Config.trAuto("Закрыть")) : "Закрыть"; color: closeBtn.hovered ? "#ffffff" : "#888888"; font.pixelSize: Config.fontSize; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            background: Item {}
            onHoveredChanged: {
                if (hovered) { bar.lastHoveredBtnObj = closeBtn; bar.hoveredBtnObj = closeBtn }
                else if (bar.hoveredBtnObj === closeBtn) bar.hoveredBtnObj = null
            }
        }
    }
}
