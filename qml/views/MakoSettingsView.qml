import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: makoRoot

    ColorPickerModal {
        id: makoColorModal
        property int colorRole: 0
        onColorSelected: (c) => {
            if (colorRole === 0) Mako.bgColor = c
            else if (colorRole === 1) Mako.textColor = c
            else if (colorRole === 2) Mako.borderColor = c
            else if (colorRole === 3) Mako.criticalBorderColor = c
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        // Верхняя шапка вкладки
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: Config ? (Config.language, Config.trAuto("Встроенные уведомления (HySett)")) : "Встроенные уведомления (HySett)"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            StyledButton {
                text: "󰂚  Тест обычного"
                onClicked: Mako.sendTestNotification()
            }
            StyledButton {
                text: "󰂞  Тест ×50"
                onClicked: Mako.send50TestNotifications()
            }
            StyledButton {
                text: "󰀨  Тест важного"
                onClicked: Mako.sendCriticalNotification()
            }
            StyledButton {
                text: "󰎟  Скрыть активные"
                onClicked: Mako.dismissAll()
            }
        }

        // Основная область: 2/3 слева — настройки, 1/3 справа — история уведомлений (до 50 шт.)
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ЛЕВАЯ ЧАСТЬ (2/3): Настройки уведомлений
            ScrollView {
                id: makoScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round(parent.width * 0.64)
                contentWidth: availableWidth
                clip: true

                Item {
                    width: makoScroll.availableWidth
                    implicitHeight: makoCol.implicitHeight + 24

                    ColumnLayout {
                        id: makoCol
                        width: parent.width - 6
                        spacing: 12

                        // КАРТОЧКА 1: Позиция и размеры
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: colPos.implicitHeight + 20

                            ColumnLayout {
                                id: colPos
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text { text: Config ? (Config.language, Config.trAuto("Расположение и геометрия")) : "Расположение и геометрия"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Позиция на экране:")) : "Позиция на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledComboBox {
                                        Layout.fillWidth: true
                                        model: ["top-right", "top-left", "top-center", "bottom-right", "bottom-left", "bottom-center", "center"]
                                        currentIndex: Math.max(0, model.indexOf(Mako.anchor))
                                        onActivated: (idx) => Mako.anchor = model[idx]
                                    }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Ширина уведомления:")) : "Ширина уведомления:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 200; to: 600; stepSize: 10; value: Mako.width; onMoved: Mako.width = Math.round(value) }
                                    Text { text: Mako.width + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Макс. высота:")) : "Макс. высота:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 60; to: 300; stepSize: 5; value: Mako.height; onMoved: Mako.height = Math.round(value) }
                                    Text { text: Mako.height + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Внешний отступ (Margin):")) : "Внешний отступ (Margin):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 0; to: 50; stepSize: 1; value: Mako.margin; onMoved: Mako.margin = Math.round(value) }
                                    Text { text: Mako.margin + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Внутренний отступ (Padding):")) : "Внутренний отступ (Padding):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 4; to: 32; stepSize: 1; value: Mako.padding; onMoved: Mako.padding = Math.round(value) }
                                    Text { text: Mako.padding + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }
                            }
                        }

                        // КАРТОЧКА 2: Оформление и цвета
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: colStyle.implicitHeight + 20

                            ColumnLayout {
                                id: colStyle
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text { text: Config ? (Config.language, Config.trAuto("Оформление, рамка и цвета")) : "Оформление, рамка и цвета"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Прозрачность уведомлений:")) : "Прозрачность уведомлений:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 0.10; to: 1.0; stepSize: 0.02; value: Mako.bgOpacity; onMoved: Mako.bgOpacity = value }
                                    Text { text: Math.round(Mako.bgOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Толщина рамки:")) : "Толщина рамки:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 0; to: 6; stepSize: 1; value: Mako.borderSize; onMoved: Mako.borderSize = Math.round(value) }
                                    Text { text: Mako.borderSize + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Скругление углов:")) : "Скругление углов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 0; to: 24; stepSize: 1; value: Mako.borderRadius; onMoved: Mako.borderRadius = Math.round(value) }
                                    Text { text: Mako.borderRadius + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Размер шрифта:")) : "Размер шрифта:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 8; to: 18; stepSize: 1; value: Mako.fontSize; onMoved: Mako.fontSize = Math.round(value) }
                                    Text { text: Mako.fontSize + "pt"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                Repeater {
                                    model: [
                                        { label: "Цвет фона уведомлений:", role: 0, col: Mako.bgColor },
                                        { label: "Цвет текста:", role: 1, col: Mako.textColor },
                                        { label: "Цвет обычной рамки:", role: 2, col: Mako.borderColor },
                                        { label: "Цвет рамки важных (Critical):", role: 3, col: Mako.criticalBorderColor }
                                    ]

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text { text: Config ? (Config.language, Config.trAuto(modelData.label)) : modelData.label; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Rectangle {
                                            width: 22; height: 22
                                            radius: (Theme && Theme.isRounded) ? 4 : 0
                                            color: modelData.col
                                            border.color: Qt.rgba(1, 1, 1, 0.35)
                                            border.width: 1
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    makoColorModal.colorRole = modelData.role
                                                    makoColorModal.openPicker(Config.trAuto(modelData.label), modelData.col)
                                                }
                                            }
                                        }
                                        Text { text: modelData.col.toString().toUpperCase(); color: "#aaaaaa"; font.pixelSize: Config.fontSize - 1; Layout.preferredWidth: 62 }
                                        StyledButton {
                                            text: "Изменить"
                                            implicitHeight: 22
                                            onClicked: {
                                                makoColorModal.colorRole = modelData.role
                                                makoColorModal.openPicker(Config.trAuto(modelData.label), modelData.col)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // КАРТОЧКА 3: Поведение
                        GlassPanel {
                            objectName: "atmoObstacle"
                            Layout.fillWidth: true
                            implicitHeight: colBeh.implicitHeight + 20

                            ColumnLayout {
                                id: colBeh
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text { text: Config ? (Config.language, Config.trAuto("Поведение и таймаут")) : "Поведение и таймаут"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Время показа (мс):")) : "Время показа (мс):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 1000; to: 15000; stepSize: 500; value: Mako.defaultTimeout; onMoved: Mako.defaultTimeout = Math.round(value) }
                                    Text { text: (Mako.defaultTimeout / 1000).toFixed(1) + "s"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Макс. уведомлений на экране:")) : "Макс. уведомлений на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 185 }
                                    StyledSlider { Layout.fillWidth: true; from: 1; to: 10; stepSize: 1; value: Mako.maxVisible; onMoved: Mako.maxVisible = Math.round(value) }
                                    Text { text: Mako.maxVisible.toString(); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                                }

                                RowLayout {
                                    Text { text: Config ? (Config.language, Config.trAuto("Показывать иконки приложений:")) : "Показывать иконки приложений:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                                    StyledSwitch { checked: Mako.icons; onToggled: Mako.icons = checked }
                                }
                            }
                        }

                        StyledButton {
                            text: "↺   Сбросить настройки уведомлений по умолчанию"
                            Layout.alignment: Qt.AlignHCenter
                            implicitHeight: 26
                            onClicked: Mako.resetDefaults()
                        }
                    }
                }
            }

            // ПРАВАЯ ЧАСТЬ (1/3): История уведомлений (до 50 штук)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(250, Math.round(parent.width * 0.34))

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "󰋚  История"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }

                        Rectangle {
                            width: histCntTxt.implicitWidth + 12
                            height: 18
                            radius: (Theme && Theme.isRounded) ? 9 : 0
                            color: (Theme && Theme.isRounded && Config) ? Config.m3SecondaryContainer : Qt.rgba(1, 1, 1, 0.10)
                            Text {
                                id: histCntTxt
                                anchors.centerIn: parent
                                text: (Mako ? Mako.history.length : 0) + " / 50"
                                color: (Theme && Theme.isRounded && Config) ? Config.m3Primary : "#cccccc"
                                font.pixelSize: Config.fontSize - 2
                                font.bold: true
                            }
                        }

                        Item { Layout.fillWidth: true }

                        StyledButton {
                            text: "󰎟 Очистить"
                            implicitHeight: 22
                            enabled: Mako && Mako.history.length > 0
                            onClicked: if (Mako) Mako.clearHistory()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListModel {
                            id: histListModel
                        }

                        Text {
                            visible: histListModel.count === 0
                            anchors.centerIn: parent
                            text: "История уведомлений пуста"
                            color: "#777777"
                            font.pixelSize: Config.fontSize
                        }

                        // Плавающая таблетка "↑ 1 новое / 2 новых" (уменьшается по мере прокрутки вверх)
                        Rectangle {
                            id: newHistBadge
                            z: 20
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: newHistBadgeTxt.implicitWidth + 24
                            height: 26
                            radius: (Theme && Theme.isRounded) ? 13 : 0
                            color: Config ? Config.m3Primary : "#ffffff"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                            visible: opacity > 0.01
                            opacity: histListView.unreadNewCount > 0 ? 1.0 : 0.0
                            scale: histListView.unreadNewCount > 0 ? (newBadgeMa.pressed ? 0.94 : (newBadgeMa.containsMouse ? 1.05 : 1.0)) : 0.72

                            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.55 } }

                            Text {
                                id: newHistBadgeTxt
                                anchors.centerIn: parent
                                text: {
                                    var n = histListView.unreadNewCount
                                    var isOne = (n % 10 === 1) && (n % 100 !== 11)
                                    return "↑  " + n + (isOne ? " новое" : " новых")
                                }
                                color: Config ? Config.accentTextColor : "#000000"
                                font.pixelSize: Config.fontSize - 1
                                font.bold: true
                            }

                            MouseArea {
                                id: newBadgeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: histListView.scrollToTopAndMarkAllRead()
                            }
                        }

                        ListView {
                            id: histListView
                            anchors.fill: parent
                            anchors.leftMargin: -6
                            anchors.rightMargin: -6
                            topMargin: 8
                            bottomMargin: 8
                            clip: true
                            spacing: 6
                            visible: histListModel.count > 0
                            model: histListModel
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            property var shownIdMap: ({})
                            property int unreadNewCount: 0
                            property bool suppressReadCheck: false
                            readonly property bool isScrolledDown: (contentY - originY) > 12

                            property Item hoveredCard: null
                            property Item lastHoveredCard: null
                            property bool readyForAnims: false
                            property int activeSpringId: -1

                            NumberAnimation {
                                id: scrollToTopAnim
                                target: histListView
                                property: "contentY"
                                duration: 240
                                easing.type: Easing.OutQuint
                                onFinished: histListView.markAllRead()
                            }

                            function scrollToTopAndMarkAllRead() {
                                scrollToTopAnim.stop()
                                scrollToTopAnim.from = histListView.contentY
                                scrollToTopAnim.to = histListView.originY - histListView.topMargin
                                scrollToTopAnim.start()
                            }

                            function markAllRead() {
                                for (var i = 0; i < histListModel.count; ++i) {
                                    if (histListModel.get(i).unread) {
                                        histListModel.setProperty(i, "unread", false)
                                    }
                                }
                                unreadNewCount = 0
                            }

                            function recalcUnreadCount() {
                                var cnt = 0
                                for (var i = 0; i < histListModel.count; ++i) {
                                    if (histListModel.get(i).unread) cnt++
                                }
                                unreadNewCount = cnt
                            }

                            function checkVisibleUnreadItems() {
                                if (suppressReadCheck || unreadNewCount <= 0) return
                                if (!isScrolledDown) {
                                    markAllRead()
                                    return
                                }
                                var viewTop = histListView.contentY
                                var ch = histListView.contentItem.children
                                var changed = false
                                for (var i = 0; i < ch.length; ++i) {
                                    var d = ch[i]
                                    if (d && d.isHistDelegate === true && d.itemUnread === true) {
                                        // Как только хотя бы половина карточки вошла в видимую область сверху — считаем её прочитанной
                                        if (d.y + d.height * 0.45 >= viewTop) {
                                            if (d.itemIndex >= 0 && d.itemIndex < histListModel.count) {
                                                histListModel.setProperty(d.itemIndex, "unread", false)
                                                changed = true
                                            }
                                        }
                                    }
                                }
                                if (changed) recalcUnreadCount()
                            }

                            onContentYChanged: checkVisibleUnreadItems()

                            function syncFromMako() {
                                var src = Mako ? Mako.history : []
                                if (!src || src.length === 0) {
                                    histListModel.clear()
                                    shownIdMap = ({})
                                    unreadNewCount = 0
                                    return
                                }

                                // 1. Проверяем, были ли удалены какие-то элементы (например, по крестику)
                                var srcIdSet = {}
                                for (var sIdx = 0; sIdx < src.length; ++sIdx) {
                                    srcIdSet[src[sIdx].id] = true
                                }
                                for (var mIdx = histListModel.count - 1; mIdx >= 0; --mIdx) {
                                    var oldId = histListModel.get(mIdx).notifId
                                    if (!srcIdSet[oldId]) {
                                        histListModel.remove(mIdx, 1)
                                        delete shownIdMap[oldId]
                                    }
                                }

                                // 2. Находим новые уведомления, которых ещё нет в histListModel
                                var newItems = []
                                for (var i = 0; i < src.length; ++i) {
                                    var it = src[i]
                                    if (!shownIdMap[it.id]) {
                                        newItems.push({
                                            notifId: it.id,
                                            app: it.app || "",
                                            summary: it.summary || "",
                                            body: it.body || "",
                                            icon: it.icon || "",
                                            critical: it.critical === true,
                                            time: it.time || ""
                                        })
                                    }
                                }

                                if (newItems.length === 0) {
                                    recalcUnreadCount()
                                    return
                                }

                                var scrolled = histListView.isScrolledDown && histListModel.count > 0
                                var prevDistFromBottom = (histListView.originY + histListView.contentHeight) - histListView.contentY

                                suppressReadCheck = true
                                if (!scrolled && histListView.readyForAnims) {
                                    activeSpringId = newItems[0].notifId
                                } else {
                                    activeSpringId = -1
                                }

                                // Вставляем новые элементы в начало в правильном порядке (от более старых из новых к самому свежему)
                                for (var k = newItems.length - 1; k >= 0; --k) {
                                    var nw = newItems[k]
                                    shownIdMap[nw.notifId] = true
                                    nw.unread = scrolled
                                    histListModel.insert(0, nw)
                                }

                                if (scrolled) {
                                    histListView.forceLayout()
                                    histListView.contentY = (histListView.originY + histListView.contentHeight) - prevDistFromBottom
                                    Qt.callLater(function() {
                                        histListView.forceLayout()
                                        histListView.contentY = (histListView.originY + histListView.contentHeight) - prevDistFromBottom
                                        histListView.suppressReadCheck = false
                                        histListView.recalcUnreadCount()
                                    })
                                } else {
                                    suppressReadCheck = false
                                    recalcUnreadCount()
                                }
                            }

                            Connections {
                                target: Mako
                                function onPopupChanged() {
                                    histListView.syncFromMako()
                                }
                            }

                            Timer {
                                id: histHoverHold
                                interval: 45
                                onTriggered: histListView.hoveredCard = null
                            }

                            Component.onCompleted: {
                                syncFromMako()
                                Qt.callLater(function() { histListView.readyForAnims = true })
                            }

                            Rectangle {
                                id: histHoverPill
                                parent: histListView.contentItem
                                z: 5
                                x: 6
                                y: histListView.lastHoveredCard ? histListView.lastHoveredCard.y : 0
                                width: histListView.width - 12
                                height: histListView.lastHoveredCard ? histListView.lastHoveredCard.height : 58
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: (Theme && Theme.isRounded && Config)
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.10)
                                       : Qt.rgba(1, 1, 1, 0.07)
                                border.width: 1
                                border.color: (Theme && Theme.isRounded && Config)
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.55)
                                              : Qt.rgba(1, 1, 1, 0.35)
                                opacity: histListView.hoveredCard ? 1.0 : 0.0

                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }

                            delegate: Item {
                                id: histDelegateWrap
                                readonly property bool isHistDelegate: true
                                readonly property int itemIndex: index
                                readonly property bool itemUnread: model.unread === true
                                z: index === 0 ? 3 : 1
                                width: histListView.width
                                height: histCard.height

                                Rectangle {
                                    id: histCard
                                    x: 6
                                    width: parent.width - 12
                                    implicitHeight: Math.max(54, histItemCol.implicitHeight + 16)
                                    height: implicitHeight
                                    radius: (Theme && Theme.isRounded) ? 10 : 0

                                    property real enterY: 0
                                    property real enterScale: 1.0
                                    property real enterOp: 1.0

                                    opacity: enterOp
                                    transform: [
                                        Scale {
                                            origin.x: histCard.width * 0.5
                                            origin.y: histCard.height * 0.5
                                            xScale: histCard.enterScale
                                            yScale: histCard.enterScale
                                        },
                                        Translate {
                                            y: histCard.enterY
                                        }
                                    ]

                                    ParallelAnimation {
                                        id: newCardSpringAnim
                                        NumberAnimation { target: histCard; property: "enterOp"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: histCard; property: "enterScale"; from: 0.80; to: 1.0; duration: 430; easing.type: Easing.OutBack; easing.overshoot: 1.32 }
                                        NumberAnimation { target: histCard; property: "enterY"; from: 16; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                                    }

                                    NumberAnimation {
                                        id: cascadePushSpringAnim
                                        target: histCard
                                        property: "enterY"
                                        from: -54
                                        to: 0
                                        duration: 390
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.25
                                    }

                                    Component.onCompleted: {
                                        if (!histListView.readyForAnims || histListView.activeSpringId <= 0) return
                                        if (index === 0 && model.notifId === histListView.activeSpringId) {
                                            newCardSpringAnim.restart()
                                        } else if (index > 0 && index <= 14) {
                                            cascadePushSpringAnim.restart()
                                        }
                                    }

                                    color: model.critical
                                           ? Qt.rgba(1.0, 0.25, 0.25, 0.08)
                                           : (model.unread
                                              ? (Theme && Theme.isRounded && Config
                                                 ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                                 : Qt.rgba(1, 1, 1, 0.09))
                                              : (Theme && Theme.isRounded && Config
                                                 ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.38)
                                                 : Qt.rgba(1, 1, 1, 0.04)))
                                    border.width: 1
                                    border.color: model.critical
                                                  ? (Mako ? Mako.criticalBorderColor : "#ff6b6b")
                                                  : (model.unread
                                                     ? (Theme && Theme.isRounded && Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.50) : Qt.rgba(1, 1, 1, 0.30))
                                                     : Qt.rgba(1, 1, 1, 0.10))
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                    Behavior on border.color { ColorAnimation { duration: 220 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        onEntered: {
                                            histHoverHold.stop()
                                            histListView.lastHoveredCard = histDelegateWrap
                                            histListView.hoveredCard = histDelegateWrap
                                        }
                                        onExited: histHoverHold.restart()
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Image {
                                            visible: Mako && Mako.icons && model.icon && model.icon.length > 0
                                            source: visible ? ("image://appicon/" + model.icon) : ""
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            sourceSize: Qt.size(20, 20)
                                            Layout.alignment: Qt.AlignTop
                                            Layout.topMargin: 2
                                        }

                                        ColumnLayout {
                                            id: histItemCol
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: model.summary || model.app || "Уведомление"
                                                    color: model.critical
                                                           ? (Mako ? Mako.criticalBorderColor : "#ff6b6b")
                                                           : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                                                    font.pixelSize: Config.fontSize
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: model.time || ""
                                                    color: "#888888"
                                                    font.pixelSize: Config.fontSize - 2
                                                }

                                                Rectangle {
                                                    width: 18; height: 18
                                                    radius: (Theme && Theme.isRounded) ? 5 : 0
                                                    color: delHistMa.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.25) : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "✕"
                                                        color: delHistMa.containsMouse ? "#ff8a80" : "#888888"
                                                        font.pixelSize: 9
                                                    }
                                                    MouseArea {
                                                        id: delHistMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onEntered: {
                                                            histHoverHold.stop()
                                                            histListView.lastHoveredCard = histDelegateWrap
                                                            histListView.hoveredCard = histDelegateWrap
                                                        }
                                                        onExited: histHoverHold.restart()
                                                        onClicked: if (Mako) Mako.dismissHistoryItem(model.notifId)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: model.body && model.body.length > 0
                                                text: model.body || ""
                                                color: (Theme && Theme.isRounded && Config) ? Config.m3OnPrimaryContainer : "#cccccc"
                                                font.pixelSize: Config.fontSize - 1
                                                wrapMode: Text.Wrap
                                                Layout.fillWidth: true
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
}
