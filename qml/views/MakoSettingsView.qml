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

                        Text {
                            visible: !Mako || Mako.history.length === 0
                            anchors.centerIn: parent
                            text: "История уведомлений пуста"
                            color: "#777777"
                            font.pixelSize: Config.fontSize
                        }

                        ListView {
                            id: histListView
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            visible: Mako && Mako.history.length > 0
                            model: Mako ? Mako.history : []
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            property Item hoveredCard: null
                            property Item lastHoveredCard: null

                            Rectangle {
                                id: histHoverPill
                                parent: histListView.contentItem
                                z: 0
                                x: 0
                                y: histListView.lastHoveredCard ? histListView.lastHoveredCard.y : 0
                                width: histListView.width
                                height: histListView.lastHoveredCard ? histListView.lastHoveredCard.height : 58
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: (Theme && Theme.isRounded && Config)
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.12)
                                       : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1
                                border.color: (Theme && Theme.isRounded && Config)
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45)
                                              : Qt.rgba(1, 1, 1, 0.30)
                                opacity: histListView.hoveredCard ? 1.0 : 0.0

                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }

                            delegate: Rectangle {
                                id: histCard
                                z: 1
                                width: histListView.width
                                implicitHeight: Math.max(54, histItemCol.implicitHeight + 16)
                                height: implicitHeight
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: modelData.critical
                                       ? Qt.rgba(1.0, 0.25, 0.25, 0.08)
                                       : (Theme && Theme.isRounded && Config
                                          ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.38)
                                          : Qt.rgba(1, 1, 1, 0.04))
                                border.width: 1
                                border.color: modelData.critical
                                              ? (Mako ? Mako.criticalBorderColor : "#ff6b6b")
                                              : Qt.rgba(1, 1, 1, 0.10)

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: {
                                        histListView.lastHoveredCard = histCard
                                        histListView.hoveredCard = histCard
                                    }
                                    onExited: {
                                        if (histListView.hoveredCard === histCard)
                                            histListView.hoveredCard = null
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Image {
                                        visible: Mako && Mako.icons && modelData.icon && modelData.icon.length > 0
                                        source: visible ? ("image://appicon/" + modelData.icon) : ""
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
                                                text: modelData.summary || modelData.app || "Уведомление"
                                                color: modelData.critical
                                                       ? (Mako ? Mako.criticalBorderColor : "#ff6b6b")
                                                       : ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#ffffff")
                                                font.pixelSize: Config.fontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.time || ""
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
                                                    onClicked: if (Mako) Mako.dismissHistoryItem(modelData.id)
                                                }
                                            }
                                        }

                                        Text {
                                            visible: modelData.body && modelData.body.length > 0
                                            text: modelData.body || ""
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
