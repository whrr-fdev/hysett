import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett

Rectangle {
    id: bar
    property int currentIndex: 0
    property int prevIndex: 0
    signal categorySelected(int index)
    signal returnToWelcome()
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property int itemH: isM3 ? 32 : 25
    readonly property int pillH: isM3 ? 30 : 24

    readonly property bool sidebarHovered: sidebarHoverHandler.hovered
    readonly property bool forceExpanded: (ApplicationWindow.window && ApplicationWindow.window.isSettingsMaximized && bar.currentIndex !== 14)
    property bool collapsed: !forceExpanded && !sidebarHovered
    readonly property int targetWidth: collapsed ? (isM3 ? 56 : 46) : (isM3 ? 168 : 136)

    property var winObj: ApplicationWindow.window
    readonly property bool winMax: winObj ? (winObj.isSettingsMaximized || winObj.isWallpaperExpanded) : false
    property real sidebarSpringScale: 1.0

    property real headerAlpha: 1.0
    property real headerDropY: 0.0
    property real headerStepX: 0.0
    property real headerPopScale: 1.0

    property real closeAlpha: 1.0
    property real closeDropY: 0.0
    property real closeStepX: 0.0
    property real closePopScale: 1.0

    property real pillCascade: 1.0

    SequentialAnimation {
        id: headerCascadeAnim
        PropertyAction { target: bar; property: "headerAlpha"; value: 0.0 }
        PropertyAction { target: bar; property: "headerDropY"; value: -20.0 }
        PropertyAction { target: bar; property: "headerStepX"; value: -22.0 }
        PropertyAction { target: bar; property: "headerPopScale"; value: 0.25 }
        PauseAnimation { duration: 20 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "headerAlpha"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "headerDropY"; from: -20.0; to: 0.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
            NumberAnimation { target: bar; property: "headerStepX"; from: -22.0; to: 0.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.45 }
            NumberAnimation { target: bar; property: "headerPopScale"; from: 0.25; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.75 }
        }
    }

    SequentialAnimation {
        id: closeCascadeAnim
        PropertyAction { target: bar; property: "closeAlpha"; value: 0.0 }
        PropertyAction { target: bar; property: "closeDropY"; value: -20.0 }
        PropertyAction { target: bar; property: "closeStepX"; value: -22.0 }
        PropertyAction { target: bar; property: "closePopScale"; value: 0.25 }
        PauseAnimation { id: closeCascadeDelay; duration: 350 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "closeAlpha"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "closeDropY"; from: -20.0; to: 0.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.65 }
            NumberAnimation { target: bar; property: "closeStepX"; from: -22.0; to: 0.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.45 }
            NumberAnimation { target: bar; property: "closePopScale"; from: 0.25; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.75 }
        }
    }

    SequentialAnimation {
        id: pillCascadeAnim
        PropertyAction { target: bar; property: "pillCascade"; value: 0.0 }
        PauseAnimation { id: pillCascadeDelay; duration: 90 }
        NumberAnimation { target: bar; property: "pillCascade"; from: 0.0; to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
    }

    function triggerStaircaseCascade() {
        headerCascadeAnim.restart()
        var step = 0
        var activeDelay = 80
        for (var i = 0; i < navRepeater.count; ++i) {
            var it = navRepeater.itemAt(i)
            if (it && it.isShown) {
                step++
                var d = 20 + step * 26
                if (it.tabIdx === bar.currentIndex) activeDelay = d
                it.playCascade(d)
            }
        }
        step++
        var setDelay = 20 + step * 26
        if (bar.currentIndex === 17) activeDelay = setDelay
        setBtn.playCascade(setDelay)
        closeCascadeDelay.duration = 20 + (step + 1) * 26
        closeCascadeAnim.restart()
        pillCascadeDelay.duration = activeDelay
        pillCascadeAnim.restart()
    }

    onVisibleChanged: {
        if (visible && bar.currentIndex > 0) {
            triggerStaircaseCascade()
        }
    }

    onCurrentIndexChanged: {
        if (bar.prevIndex === 0 && bar.currentIndex > 0 && bar.visible) {
            triggerStaircaseCascade()
        }
        bar.prevIndex = bar.currentIndex
    }

    SequentialAnimation {
        id: sidebarMaxSpringAnim
        NumberAnimation { target: bar; property: "sidebarSpringScale"; from: 1.0; to: 1.045; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: bar; property: "sidebarSpringScale"; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.75 }
    }

    onWinMaxChanged: sidebarMaxSpringAnim.restart()

    transform: Scale {
        origin.x: 0
        origin.y: bar.height * 0.5
        xScale: bar.sidebarSpringScale
        yScale: bar.sidebarSpringScale
    }

    width: targetWidth
    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

    HoverHandler {
        id: sidebarHoverHandler
    }

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.margins: bar.isM3 ? 6 : 0
        anchors.topMargin: bar.isM3 ? 8 : 4
        anchors.rightMargin: bar.isM3 ? 4 : 0
        radius: bar.isM3 ? (Config ? Math.min(22, Config.m3CardRadius + 4) : 20) : 0
        color: bar.isM3 && Config
               ? Qt.rgba(Config.m3SurfaceContainer.r, Config.m3SurfaceContainer.g, Config.m3SurfaceContainer.b, Math.max(0.75, Config.sidebarOpacity + 0.58))
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
        anchors.topMargin: 6
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
        opacity: bar.pillCascade
        scale: 0.7 + 0.3 * bar.pillCascade
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
            opacity: bar.pillCascade
            scale: 0.7 + 0.3 * bar.pillCascade
            y: (bar.activeBtnObj && bar.activeBtnObj !== setBtn) ? (bar.activeBtnObj.y - catScroll.contentItem.contentY + (bar.itemH - height) * 0.5) : 0
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 150 } }
        }
    }

    ColumnLayout {
        id: mainColLayout
        anchors.fill: parent
        anchors.margins: bar.isM3 ? 10 : 4
        anchors.topMargin: bar.isM3 ? 12 : 6
        spacing: bar.isM3 ? 4 : 2

        Button {
            id: archHeaderItem
            Layout.fillWidth: true
            Layout.preferredHeight: bar.isM3 ? 34 : 24
            Layout.minimumHeight: bar.isM3 ? 34 : 24
            implicitHeight: bar.isM3 ? 34 : 24
            flat: true
            clip: false
            opacity: bar.headerAlpha
            background: Item {}
            contentItem: Item {
                anchors.fill: parent
                Image {
                    id: headerLogo
                    width: 15; height: 15
                    sourceSize: Qt.size(30, 30)
                    smooth: true
                    opacity: archHeaderItem.hovered ? 1.0 : 0.9
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.headerDropY
                    scale: bar.headerPopScale
                    x: (bar.collapsed
                        ? Math.round((parent.width - width) * 0.5)
                        : Math.round((parent.width - (width + 8 + headerTitleTxt.implicitWidth)) * 0.5)) + bar.headerStepX
                    Behavior on x { enabled: !headerCascadeAnim.running; NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                    source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                }
                Text {
                    id: headerTitleTxt
                    x: headerLogo.x + headerLogo.width + 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.headerDropY
                    text: "HYPRLAND"
                    opacity: bar.collapsed ? 0.0 : 1.0
                    visible: opacity > 0.01
                    color: bar.isM3 && Config ? Config.m3Primary : (archHeaderItem.hovered ? "#ffffff" : "#aaaaaa")
                    font.pixelSize: 11
                    font.bold: bar.isM3
                    font.letterSpacing: 1.4
                    Behavior on opacity { NumberAnimation { duration: 120 } }
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
            Layout.leftMargin: bar.isM3 ? 6 : 0
            Layout.rightMargin: bar.isM3 ? 6 : 0
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
                        { title: "Время", icon: "󱑂", idx: 22 },
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
                        { title: "Атмосфера", icon: "󰖗", idx: 19 },
                        { title: "Бэкап", icon: "󰁯", idx: 29 }
                    ]

                    NavButton {
                        id: nb
                        tabIdx: modelData.idx
                        collapsed: bar.collapsed
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
                        clip: !isShown

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
            Layout.leftMargin: bar.isM3 ? 6 : 0
            Layout.rightMargin: bar.isM3 ? 6 : 0
            height: 1
            color: bar.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.18) : Qt.rgba(1, 1, 1, 0.06)
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        NavButton {
            id: setBtn
            tabIdx: 17
            collapsed: bar.collapsed
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
            opacity: isCloseShown ? bar.closeAlpha : 0.0
            visible: Layout.preferredHeight > 0.5 || opacity > 0.01
            enabled: isCloseShown
            clip: !isCloseShown
            flat: true
            onClicked: if (ApplicationWindow.window) ApplicationWindow.window.requestCloseDrawer()

            contentItem: Item {
                anchors.fill: parent
                Text {
                    id: closeIconTxt
                    text: "✕"
                    color: closeBtn.hovered ? "#ff6b6b" : "#888888"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.closeDropY
                    scale: bar.closePopScale
                    x: (bar.collapsed
                        ? Math.round((parent.width - width) * 0.5)
                        : ((Config && Config.alignCenter)
                           ? Math.round((parent.width - (width + (bar.isM3 ? 10 : 7) + closeLblTxt.implicitWidth)) * 0.5)
                           : (bar.isM3 ? 14 : 10))) + bar.closeStepX
                    Behavior on x { enabled: !closeCascadeAnim.running; NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                }
                Text {
                    id: closeLblTxt
                    x: closeIconTxt.x + closeIconTxt.width + (bar.isM3 ? 10 : 7)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: bar.closeDropY
                    text: Config ? (Config.language, Config.trAuto("Закрыть")) : "Закрыть"
                    opacity: bar.collapsed ? 0.0 : 1.0
                    visible: opacity > 0.01
                    color: closeBtn.hovered ? "#ffffff" : "#888888"
                    font.pixelSize: Config.fontSize
                    Behavior on opacity { NumberAnimation { duration: 120 } }
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
