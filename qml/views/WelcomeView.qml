import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: welcomeRoot
    signal navigateTo(int index)

    property var winObj: ApplicationWindow.window
    readonly property bool isMaximized: winObj ? (winObj.isSettingsMaximized || winObj.isWallpaperExpanded) : false
    property string settingsSearchQuery: ""
    readonly property bool isSearching: settingsSearchQuery.length > 0
    readonly property int wMode: Config ? Config.welcomeAlignMode : 1
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property int cardHeight: isM3 ? (isMaximized ? 62 : 56) : (isMaximized ? 50 : 44)
    readonly property int cardGap: isM3 ? (isMaximized ? 14 : 11) : (isMaximized ? 10 : 7)
    property int visibleCardsHeight: 280
    property real springPulse: 1.0

    SequentialAnimation {
        id: welcomeMaxSpring
        NumberAnimation { target: welcomeRoot; property: "springPulse"; from: 1.0; to: 1.035; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: welcomeRoot; property: "springPulse"; to: 1.0; duration: 290; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    onIsMaximizedChanged: {
        welcomeMaxSpring.restart()
        Qt.callLater(recalcCardsLayout)
    }

    function recalcCardsLayout() {
        var cnt = welcomeCatRep.count
        if (cnt === 0) return

        var visList = []
        for (var i = 0; i < cnt; ++i) {
            var b = welcomeCatRep.itemAt(i)
            if (b && b.matchesFilter) visList.push(b)
        }

        var w = Math.max(400, gridWrapper.width)
        var cardH = welcomeRoot.cardHeight
        var gap = welcomeRoot.cardGap

        if (welcomeRoot.isSearching) {
            var singleW = Math.min(540, Math.round(w * 0.60))
            var startX = Math.round((w - singleW) / 2)
            for (var m = 0; m < visList.length; ++m) {
                var item = visList[m]
                item.targetX = startX
                item.targetY = m * (cardH + 8)
                item.targetW = singleW
            }
            welcomeRoot.visibleCardsHeight = Math.max(cardH, visList.length * (cardH + 8))
        } else {
            var cols = w > 1200 ? (welcomeRoot.isM3 ? 5 : 6) : (welcomeRoot.isM3 ? 4 : 5)
            var colW = Math.floor((w - (cols - 1) * gap) / cols)
            for (var k = 0; k < visList.length; ++k) {
                var card = visList[k]
                var c = k % cols
                var r = Math.floor(k / cols)
                card.targetX = c * (colW + gap)
                card.targetY = r * (cardH + gap)
                card.targetW = colW
            }
            var totalRows = Math.max(1, Math.ceil(visList.length / cols))
            welcomeRoot.visibleCardsHeight = totalRows * cardH + (totalRows - 1) * gap
        }
    }

    onIsM3Changed: Qt.callLater(recalcCardsLayout)
    onSettingsSearchQueryChanged: recalcCardsLayout()
    onWidthChanged: Qt.callLater(recalcCardsLayout)
    onHeightChanged: Qt.callLater(recalcCardsLayout)
    Component.onCompleted: Qt.callLater(recalcCardsLayout)

    Connections {
        target: Config
        function onHiddenSidebarTabsChanged() { welcomeRoot.recalcCardsLayout() }
        function onLanguageChanged() { welcomeRoot.recalcCardsLayout() }
    }

    ScrollView {
        id: welcomeScroll
        anchors.fill: parent
        contentWidth: welcomeRoot.width
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        clip: true

        Timer {
            interval: 500
            running: welcomeRoot.visible
            repeat: true
            onTriggered: {
                var now = new Date()
                timeLabel.text = Qt.formatDateTime(now, "hh:mm:ss")
                dateLabel.text = Qt.formatDateTime(now, "dddd, d MMMM yyyy")
            }
        }

        Item {
            id: scrollArea
            width: welcomeRoot.width
            implicitHeight: Math.max(welcomeRoot.height, gridWrapper.targetYPos + welcomeRoot.visibleCardsHeight + 28)
            height: implicitHeight

            Item {
                id: mainContainer
                width: Math.min(parent.width - (welcomeRoot.isM3 ? 52 : 56), welcomeRoot.isMaximized ? 1640 : 1040)
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.24 } }

                Item {
                    id: heroWrapper
                    width: parent.width
                    height: heroBlock.implicitHeight
                    y: welcomeRoot.isSearching ? 24 : (welcomeRoot.isMaximized ? 44 : 16)
                    scale: welcomeRoot.springPulse

                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.35 } }

                    ColumnLayout {
                        id: heroBlock
                        x: {
                            if (welcomeRoot.isSearching || welcomeRoot.wMode === 1) return Math.round((parent.width - width) / 2)
                            if (welcomeRoot.wMode === 0) return 0
                            return parent.width - width
                        }
                        spacing: welcomeRoot.isM3 ? 18 : 14

                        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                        RowLayout {
                            Layout.alignment: welcomeRoot.isSearching ? Qt.AlignHCenter : (welcomeRoot.wMode === 0 ? Qt.AlignLeft : (welcomeRoot.wMode === 2 ? Qt.AlignRight : Qt.AlignHCenter))
                            spacing: 42

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                RowLayout {
                                    spacing: 8
                                    Image { width: 18; height: 18; sourceSize: Qt.size(36, 36); smooth: true; source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg" }
                                    Text { text: "HYPRLAND"; color: welcomeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"; font.pixelSize: 13; font.bold: welcomeRoot.isM3; font.letterSpacing: 2 }
                                }

                                Text {
                                    text: Config ? (Config.language, Config.trAuto("Привет, Whrr!")) : "Привет, Whrr!"
                                    color: welcomeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                                    font.pixelSize: Config.fontSize + (welcomeRoot.isM3 ? 10 : 8)
                                    font.bold: welcomeRoot.isM3
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 48
                                color: welcomeRoot.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    id: timeLabel
                                    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                                    color: welcomeRoot.isM3 && Config ? Config.m3Primary : "#ffffff"
                                    font.pixelSize: 38
                                    font.bold: welcomeRoot.isM3
                                    font.letterSpacing: 2
                                    Layout.alignment: Qt.AlignLeft
                                }

                                Text {
                                    id: dateLabel
                                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                                    color: welcomeRoot.isM3 && Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.72) : "#888888"
                                    font.pixelSize: Config.fontSize
                                    Layout.alignment: Qt.AlignLeft
                                }
                            }
                        }

                        TextField {
                            id: welcomeSearchField
                            Layout.alignment: welcomeRoot.isSearching ? Qt.AlignHCenter : (welcomeRoot.wMode === 0 ? Qt.AlignLeft : (welcomeRoot.wMode === 2 ? Qt.AlignRight : Qt.AlignHCenter))
                            Layout.preferredWidth: welcomeRoot.isSearching ? 480 : (welcomeRoot.isMaximized ? 520 : (welcomeRoot.isM3 ? 400 : 340))
                            implicitHeight: welcomeRoot.isM3 ? 38 : 30
                            leftPadding: 16
                            rightPadding: 16
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + (welcomeRoot.isM3 ? 1 : 0)
                            placeholderText: Config ? (Config.language, Config.trAuto("Поиск по настройкам")) : "Поиск по настройкам"
                            placeholderTextColor: welcomeRoot.isM3 && Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.55) : "#777777"

                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.35 } }

                            background: GlassPanel {
                                radius: welcomeRoot.isM3 ? height / 2 : 0
                                baseSurf: Config ? Config.m3SurfaceContainerHigh : "#252832"
                            }
                            onTextChanged: welcomeRoot.settingsSearchQuery = text.trim().toLowerCase()
                            onAccepted: {
                                for (var i = 0; i < welcomeCatRep.count; ++i) {
                                    var b = welcomeCatRep.itemAt(i)
                                    if (b && b.matchesFilter) {
                                        welcomeRoot.navigateTo(b.catIdx)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: gridWrapper
                    width: parent.width
                    height: welcomeRoot.visibleCardsHeight
                    onWidthChanged: Qt.callLater(welcomeRoot.recalcCardsLayout)

                    readonly property real targetYPos: {
                        var heroBot = heroWrapper.y + heroWrapper.height
                        if (welcomeRoot.isSearching) return heroBot + 20
                        var minTop = heroBot + 18
                        var midBottom = Math.round(heroBot + (welcomeRoot.height - heroBot - welcomeRoot.visibleCardsHeight) / 2)
                        return Math.max(minTop, midBottom)
                    }
                    y: targetYPos

                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                    property Item hoveredCardObj: null
                    property Item lastHoveredCardObj: null

                    Rectangle {
                        id: welcomeHoverPill
                        x: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetX : 0
                        y: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetY : 0
                        width: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetW : 220
                        height: welcomeRoot.cardHeight
                        radius: welcomeRoot.isM3 ? (Config ? Config.m3CardRadius : 18) : 0
                        color: Qt.rgba(Config ? Config.m3Primary.r : 1, Config ? Config.m3Primary.g : 1, Config ? Config.m3Primary.b : 1, welcomeRoot.isM3 ? 0.16 : 0.11)
                        border.color: Qt.rgba(Config ? Config.m3Primary.r : 1, Config ? Config.m3Primary.g : 1, Config ? Config.m3Primary.b : 1, 0.55)
                        border.width: welcomeRoot.isM3 ? 1.5 : 1
                        opacity: gridWrapper.hoveredCardObj && gridWrapper.hoveredCardObj.matchesFilter ? 1.0 : 0.0

                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                    }

                    Repeater {
                        id: welcomeCatRep
                        onCountChanged: Qt.callLater(welcomeRoot.recalcCardsLayout)
                        model: [
                            { title: "󰍉  Поиск", desc: "Файлы системы и программы", idx: 16, kw: "поиск файлы папки система найти программы search files folders find fd" },
                            { title: "󰖙  Погода", desc: "Прогноз на день, неделю и месяц", idx: 20, kw: "погода дождь снег ветер температура прогноз gismeteo weather forecast" },
                            { title: "󰎆  Музыка", desc: "Плеер MPRIS2, перемотка и демо-трек", idx: 27, kw: "музыка плеер трек пауза перемотка звук mpris player music audio track" },
                            { title: "  Монитор", desc: "Графики CPU, ОЗУ и процессы Btop", idx: 21, kw: "монитор процессы нагрузка проц память температура btop htop cpu ram" },
                            { title: "  Календарь", desc: "Даты, дни недели и точное время", idx: 22, kw: "календарь дата время месяц год calendar date time" },
                            { title: "󰅌  Буфер", desc: "История скопированного текста и фото", idx: 23, kw: "буфер обмена история копировать вставить скриншоты clipboard cliphist" },
                            { title: "󰌌  Язык", desc: "Раскладка клавиатуры RU/EN и язык", idx: 25, kw: "язык раскладка клавиатура перевод ru en language layout" },
                            { title: "⏻  Питание", desc: "Сон, гибернация, перезагрузка и выход", idx: 24, kw: "питание выключить перезагрузка сон гибернация блокировка powermenu" },
                            { title: "󰖲  Окна", desc: "Рамки, блюр, прозрачность", idx: 1, kw: "окна рамки блюр прозрачность тени отступы зазоры затемнение скругления windows borders blur opacity shadow gaps dim rounding" },
                            { title: "󱐌  Анимации", desc: "Скорости и кривые Безье", idx: 2, kw: "анимации скорость кривые безье плавность переходы animations speed bezier curves fade slide popin" },
                            { title: "󰆿  Курсор", desc: "Тема, размер, лупа", idx: 3, kw: "курсор мышь тема размер лупа зум cursor theme size zoom hyprcursor" },
                            { title: "󰍹  Мониторы", desc: "Разрешение, Гц, VRR", idx: 4, kw: "мониторы экран дисплей разрешение герцовка частота гц масштаб ориентация фрисинк monitors display resolution hz scale vrr freesync dpms" },
                            { title: "󰌌  Устройства", desc: "Клавиатура, мышь, тачпад", idx: 5, kw: "устройства клавиатура мышь тачпад раскладка язык чувствительность сенса повтор клавиш devices keyboard mouse touchpad layout sensitivity" },
                            { title: "󰖩  Сеть", desc: "Wi-Fi сети и подключения", idx: 6, kw: "сеть вайфай интернет подключение пароль wifi network internet ssid" },
                            { title: "󰦝  VPN", desc: "Белые списки и раздельное туннелирование", idx: 26, kw: "впн прокси трон обход белые списки vpn proxy throne singbox" },
                            { title: "󰂯  Блютуз", desc: "Беспроводные устройства", idx: 7, kw: "блютуз наушники устройства сопряжение bluetooth audio pair" },
                            { title: "󱓞  Панель", desc: "Позиция, отступы, пилюли", idx: 8, kw: "вайбар панель сверху отступы пилюли рабочие столы waybar bar top margin pills workspaces" },
                            { title: "󰂚  Уведомления", desc: "Уведомления, таймаут, цвета", idx: 18, kw: "мако уведомления оповещения позиция таймаут рамка цвет mako notifications timeout anchor border color" },
                            { title: "󰒲  Автозапуск", desc: "Службы при старте системы", idx: 9, kw: "автозапуск старт службы программы демон autostart exec-once daemon" },
                            { title: "⌨  Бинды", desc: "Горячие клавиши Hyprland", idx: 10, kw: "бинды горячие клавиши хоткеи комбинации шорткаты binds keybinds shortcuts hotkeys super" },
                            { title: "󰘳  Правила окон", desc: "Плавающие окна и размеры", idx: 11, kw: "правила окон плавающие размер позиция прозрачность класс window rules float size center class" },
                            { title: "󰀻  Приложения", desc: "Лаунчер системных программ", idx: 12, kw: "приложения программы лаунчер запуск иконки apps applications launcher desktop" },
                            { title: "󰖗  Атмосфера", desc: "Дождь, снег, листья и физика", idx: 19, kw: "атмосфера погода дождь снег листья ветер сугробы мокрое стекло atmosphere weather rain snow leaves" },
                            { title: "󰏘  Шейдеры", desc: "Эффекты экрана и CRT", idx: 13, kw: "шейдеры эффекты экрана ретро чб фильтр shaders screen effects crt grayscale" },
                            { title: "󰸉  Обои", desc: "Галерея, пресеты и демон", idx: 14, kw: "обои фон видео живые пресеты автосмена галерея wallpapers background live video presets awww mpvpaper" },
                            { title: "󰕰  Виджеты", desc: "Часы, оверлей клавиш, сводка", idx: 15, kw: "виджеты часы оверлей клавиш информеры монитор процессов btop fastfetch peaclock widgets clock keyboard overlay" },
                            { title: "󰒓  Настройки", desc: "Тема MD3, шрифт, стекло", idx: 17, kw: "настройки шрифт масштаб жидкое стекло подсветка границ вспышка курсор язык цвет акцент палитра высота окна боковое меню settings font scale liquid glass border glow flash language color accent palette md3" }
                        ]

                        Button {
                            id: cardBtn
                            property int catIdx: modelData.idx
                            property real targetX: 0
                            property real targetY: 0
                            property real targetW: 220

                            readonly property string rawTitle: Config ? (Config.language, Config.trAuto(modelData.title)) : modelData.title
                            readonly property string iconPart: rawTitle.split(" ")[0]
                            readonly property string textPart: rawTitle.substring(iconPart.length).trim()

                            property bool matchesFilter: {
                                var _ = Config ? Config.hiddenSidebarTabs : ""
                                var allowed = (modelData.idx === 17) ? true : (Config ? Config.isTabVisible(modelData.idx) : true)
                                if (!allowed) return false
                                var q = welcomeRoot.settingsSearchQuery
                                if (q.length === 0) return true
                                var trTitle = rawTitle.toLowerCase()
                                var trDesc = (Config ? Config.trAuto(modelData.desc) : modelData.desc).toLowerCase()
                                return trTitle.indexOf(q) !== -1 || trDesc.indexOf(q) !== -1 || modelData.kw.indexOf(q) !== -1
                            }

                            onMatchesFilterChanged: Qt.callLater(welcomeRoot.recalcCardsLayout)

                            x: targetX
                            y: targetY
                            width: targetW
                            height: welcomeRoot.cardHeight
                            opacity: matchesFilter ? 1.0 : 0.0
                            scale: matchesFilter ? welcomeRoot.springPulse : 0.88
                            visible: opacity > 0.01
                            enabled: matchesFilter
                            flat: true

                            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.24 } }
                            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.24 } }
                            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.20 } }
                            Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.20 } }
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            onHoveredChanged: {
                                if (hovered && matchesFilter) {
                                    gridWrapper.lastHoveredCardObj = cardBtn
                                    gridWrapper.hoveredCardObj = cardBtn
                                } else if (gridWrapper.hoveredCardObj === cardBtn) {
                                    gridWrapper.hoveredCardObj = null
                                }
                            }

                            onPressed: welcomeRoot.navigateTo(modelData.idx)

                            background: GlassPanel {
                                radius: welcomeRoot.isM3 ? (Config ? Config.m3CardRadius : 18) : 0
                                baseSurf: Config ? (cardBtn.hovered ? Config.m3SurfaceContainerHigh : Config.m3SurfaceContainer) : "#1e2028"
                            }

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: welcomeRoot.isM3 ? 11 : 8
                                anchors.rightMargin: welcomeRoot.isM3 ? 11 : 8
                                spacing: welcomeRoot.isM3 ? 11 : 6

                                Rectangle {
                                    visible: welcomeRoot.isM3
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: Config ? Math.min(14, Config.m3ControlRadius + 2) : 12
                                    color: cardBtn.hovered
                                           ? (Config ? Config.m3Primary : "#a8c7fa")
                                           : (Config ? Config.m3SecondaryContainer : "#282c38")
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: cardBtn.iconPart
                                        font.pixelSize: 15
                                        color: cardBtn.hovered
                                               ? (Config ? Config.accentTextColor : "#000000")
                                               : (Config ? Config.m3Primary : "#ffffff")
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        text: welcomeRoot.isM3 ? cardBtn.textPart : cardBtn.rawTitle
                                        color: welcomeRoot.isM3 && Config ? Config.m3OnPrimaryContainer : "#ffffff"
                                        font.pixelSize: Config.fontSize + (welcomeRoot.isM3 ? 1 : 0)
                                        font.bold: welcomeRoot.isM3
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: Config ? (Config.language, Config.trAuto(modelData.desc)) : modelData.desc
                                        color: cardBtn.hovered
                                               ? (welcomeRoot.isM3 && Config ? Config.m3Primary : "#bbbbbb")
                                               : (welcomeRoot.isM3 && Config ? Qt.rgba(Config.m3OnPrimaryContainer.r, Config.m3OnPrimaryContainer.g, Config.m3OnPrimaryContainer.b, 0.62) : "#777777")
                                        font.pixelSize: Config.fontSize - 2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: 120 } }
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
