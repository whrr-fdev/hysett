import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: welcomeRoot
    signal navigateTo(int index)

    property string settingsSearchQuery: ""
    readonly property bool isSearching: settingsSearchQuery.length > 0
    readonly property int wMode: Config ? Config.welcomeAlignMode : 1
    property int visibleCardsHeight: 262

    // Плавный пересчет координат карточек: в обычном режиме 4 колонки, а при поиске — 1 колонка выше по центру!
    function recalcCardsLayout() {
        var cnt = welcomeCatRep.count
        if (cnt === 0) return

        var visList = []
        for (var i = 0; i < cnt; ++i) {
            var b = welcomeCatRep.itemAt(i)
            if (b && b.matchesFilter) visList.push(b)
        }

        var w = Math.max(400, gridWrapper.width)
        var cardH = 44
        var gap = 7

        if (welcomeRoot.isSearching) {
            var singleW = Math.min(440, Math.round(w * 0.56))
            var startX = Math.round((w - singleW) / 2)
            for (var m = 0; m < visList.length; ++m) {
                var item = visList[m]
                item.targetX = startX
                item.targetY = m * (cardH + 6)
                item.targetW = singleW
            }
            welcomeRoot.visibleCardsHeight = Math.max(cardH, visList.length * (cardH + 6))
        } else {
            var cols = 5
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
        contentWidth: availableWidth
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
            width: welcomeScroll.availableWidth
            height: Math.max(welcomeScroll.availableHeight, gridWrapper.y + welcomeRoot.visibleCardsHeight + 24)
            implicitHeight: height

            Item {
                id: mainContainer
                width: Math.min(parent.width - 56, 1040)
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter

                // При поиске приветствие и строка поиска плавно поднимаются наверх!
                Item {
                    id: heroWrapper
                    width: parent.width
                    height: heroBlock.implicitHeight
                    y: {
                        if (welcomeRoot.isSearching) return 26
                        var upperSpace = Math.max(heroBlock.implicitHeight + 32, Math.round((welcomeScroll.availableHeight - welcomeRoot.visibleCardsHeight) * 0.44))
                        return 14
                    }

                    Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }

                    ColumnLayout {
                        id: heroBlock
                        x: {
                            if (welcomeRoot.isSearching || welcomeRoot.wMode === 1) return Math.round((parent.width - width) / 2)
                            if (welcomeRoot.wMode === 0) return 0
                            return parent.width - width
                        }
                        spacing: 16

                        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

                        RowLayout {
                            Layout.alignment: welcomeRoot.isSearching ? Qt.AlignHCenter : (welcomeRoot.wMode === 0 ? Qt.AlignLeft : (welcomeRoot.wMode === 2 ? Qt.AlignRight : Qt.AlignHCenter))
                            spacing: 42

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                RowLayout {
                                    spacing: 8
                                    Text { text: "󰣇"; color: Config ? Config.accentColor : "#ffffff"; font.pixelSize: 18 }
                                    Text { text: "HYPRLAND"; color: "#ffffff"; font.pixelSize: 13; font.bold: false; font.letterSpacing: 2 }
                                }

                                Text {
                                    text: Config ? (Config.language, Config.trAuto("Привет, Whrr!")) : "Привет, Whrr!"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 8
                                    font.bold: false
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 48
                                color: Qt.rgba(1, 1, 1, 0.16)
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    id: timeLabel
                                    text: Qt.formatDateTime(new Date(), "hh:mm:ss")
                                    color: "#ffffff"
                                    font.pixelSize: 38
                                    font.bold: false
                                    font.letterSpacing: 2
                                    Layout.alignment: Qt.AlignLeft
                                }

                                Text {
                                    id: dateLabel
                                    text: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
                                    color: "#888888"
                                    font.pixelSize: Config.fontSize
                                    Layout.alignment: Qt.AlignLeft
                                }
                            }
                        }

                        TextField {
                            id: welcomeSearchField
                            Layout.alignment: welcomeRoot.isSearching ? Qt.AlignHCenter : (welcomeRoot.wMode === 0 ? Qt.AlignLeft : (welcomeRoot.wMode === 2 ? Qt.AlignRight : Qt.AlignHCenter))
                            Layout.preferredWidth: welcomeRoot.isSearching ? 440 : 340
                            implicitHeight: 30
                            leftPadding: 12
                            rightPadding: 12
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            placeholderText: Config ? (Config.language, Config.trAuto("Поиск по настройкам")) : "Поиск по настройкам"
                            placeholderTextColor: "#777777"

                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

                            background: GlassPanel {
                                radius: (Theme && Theme.isRounded) ? 16 : 0
                                tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08,
                                                   Config ? Config.cardBgColor.g : 0.08,
                                                   Config ? Config.cardBgColor.b : 0.10,
                                                   Math.max(0.02, Config ? Config.cardOpacity : 0.10))
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

                // Контейнер карточек категорий: при поиске плавно поднимается прямо под строку поиска!
                Item {
                    id: gridWrapper
                    width: parent.width
                    height: welcomeRoot.visibleCardsHeight
                    onWidthChanged: welcomeRoot.recalcCardsLayout()
                    y: {
                        if (welcomeRoot.isSearching) {
                            return heroWrapper.y + heroWrapper.height + 20
                        }

                        var minTop = heroWrapper.y + heroWrapper.height + 14
                        var midBottom = Math.round(heroWrapper.y + heroWrapper.height + (welcomeScroll.availableHeight - (heroWrapper.y + heroWrapper.height) - welcomeRoot.visibleCardsHeight) / 2)
                        return Math.max(minTop, midBottom)
                    }

                    Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }

                    property Item hoveredCardObj: null
                    property Item lastHoveredCardObj: null

                    Rectangle {
                        id: welcomeHoverPill
                        x: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetX : 0
                        y: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetY : 0
                        width: gridWrapper.lastHoveredCardObj ? gridWrapper.lastHoveredCardObj.targetW : 220
                        height: 44
                        radius: (Theme && Theme.isRounded) ? 16 : 0
                        color: Qt.rgba(Config ? Config.accentColor.r : 1, Config ? Config.accentColor.g : 1, Config ? Config.accentColor.b : 1, 0.11)
                        border.color: Qt.rgba(Config ? Config.accentColor.r : 1, Config ? Config.accentColor.g : 1, Config ? Config.accentColor.b : 1, 0.50)
                        border.width: 1
                        opacity: gridWrapper.hoveredCardObj && gridWrapper.hoveredCardObj.matchesFilter ? 1.0 : 0.0

                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                        Behavior on radius { NumberAnimation { duration: 150 } }
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
                            { title: "󰦝  VPN", desc: "StealthSurf подписка и легкий туннель", idx: 26, kw: "впн прокси трон обход vpn proxy throne singbox stealthsurf" },
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
                            { title: "󰒓  Настройки", desc: "Шрифт, масштаб, стекло", idx: 17, kw: "настройки шрифт масштаб жидкое стекло подсветка границ вспышка курсор язык цвет акцент палитра высота окна боковое меню settings font scale liquid glass border glow flash language color accent palette" }
                        ]

                        Button {
                            id: cardBtn
                            property int catIdx: modelData.idx
                            property real targetX: 0
                            property real targetY: 0
                            property real targetW: 220

                            property bool matchesFilter: {
                                var _ = Config ? Config.hiddenSidebarTabs : ""
                                var allowed = (modelData.idx === 17) ? true : (Config ? Config.isTabVisible(modelData.idx) : true)
                                if (!allowed) return false
                                var q = welcomeRoot.settingsSearchQuery
                                if (q.length === 0) return true
                                var trTitle = Config ? Config.trAuto(modelData.title).toLowerCase() : modelData.title.toLowerCase()
                                var trDesc = Config ? Config.trAuto(modelData.desc).toLowerCase() : modelData.desc.toLowerCase()
                                return trTitle.indexOf(q) !== -1 || trDesc.indexOf(q) !== -1 || modelData.kw.indexOf(q) !== -1
                            }

                            onMatchesFilterChanged: Qt.callLater(welcomeRoot.recalcCardsLayout)

                            x: targetX
                            y: targetY
                            width: targetW
                            height: 44
                            opacity: matchesFilter ? 1.0 : 0.0
                            scale: matchesFilter ? 1.0 : 0.88
                            visible: opacity > 0.01
                            enabled: matchesFilter
                            flat: true

                            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                            onHoveredChanged: {
                                if (hovered && matchesFilter) {
                                    gridWrapper.lastHoveredCardObj = cardBtn
                                    gridWrapper.hoveredCardObj = cardBtn
                                } else if (gridWrapper.hoveredCardObj === cardBtn) {
                                    gridWrapper.hoveredCardObj = null
                                }
                            }

                            onClicked: welcomeRoot.navigateTo(modelData.idx)

                            background: GlassPanel {
                                radius: (Theme && Theme.isRounded) ? 16 : 0
                                tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08,
                                                   Config ? Config.cardBgColor.g : 0.08,
                                                   Config ? Config.cardBgColor.b : 0.10,
                                                   Math.max(0.02, Config ? Config.cardOpacity : 0.10))
                            }

                            contentItem: ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 2

                                Text {
                                    text: Config ? (Config.language, Config.trAuto(modelData.title)) : modelData.title
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    font.bold: false
                                }
                                Text {
                                    text: Config ? (Config.language, Config.trAuto(modelData.desc)) : modelData.desc
                                    color: cardBtn.hovered ? "#aaaaaa" : "#777777"
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
