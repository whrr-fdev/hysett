import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: makoScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: makoScroll.availableWidth
        implicitHeight: makoCol.implicitHeight + 40

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
            id: makoCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Config ? (Config.language, Config.trAuto("Встроенные уведомления (HySett)")) : "Встроенные уведомления (HySett)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
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
                    text: "󰎟  Очистить все"
                    onClicked: Mako.dismissAll()
                }
            }

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
                        Text { text: Config ? (Config.language, Config.trAuto("Позиция на экране:")) : "Позиция на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledComboBox {
                            Layout.fillWidth: true
                            model: ["top-right", "top-left", "top-center", "bottom-right", "bottom-left", "bottom-center", "center"]
                            currentIndex: Math.max(0, model.indexOf(Mako.anchor))
                            onActivated: (idx) => Mako.anchor = model[idx]
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Ширина уведомления:")) : "Ширина уведомления:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 200; to: 600; stepSize: 10; value: Mako.width; onMoved: Mako.width = Math.round(value) }
                        Text { text: Mako.width + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Макс. высота:")) : "Макс. высота:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 60; to: 300; stepSize: 5; value: Mako.height; onMoved: Mako.height = Math.round(value) }
                        Text { text: Mako.height + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Внешний отступ (Margin):")) : "Внешний отступ (Margin):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 0; to: 50; stepSize: 1; value: Mako.margin; onMoved: Mako.margin = Math.round(value) }
                        Text { text: Mako.margin + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Внутренний отступ (Padding):")) : "Внутренний отступ (Padding):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 4; to: 32; stepSize: 1; value: Mako.padding; onMoved: Mako.padding = Math.round(value) }
                        Text { text: Mako.padding + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
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
                        Text { text: Config ? (Config.language, Config.trAuto("Прозрачность уведомлений:")) : "Прозрачность уведомлений:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 0.10; to: 1.0; stepSize: 0.02; value: Mako.bgOpacity; onMoved: Mako.bgOpacity = value }
                        Text { text: Math.round(Mako.bgOpacity * 100) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Толщина рамки:")) : "Толщина рамки:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 0; to: 6; stepSize: 1; value: Mako.borderSize; onMoved: Mako.borderSize = Math.round(value) }
                        Text { text: Mako.borderSize + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Скругление углов:")) : "Скругление углов:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 0; to: 24; stepSize: 1; value: Mako.borderRadius; onMoved: Mako.borderRadius = Math.round(value) }
                        Text { text: Mako.borderRadius + "px"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Размер шрифта:")) : "Размер шрифта:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 8; to: 18; stepSize: 1; value: Mako.fontSize; onMoved: Mako.fontSize = Math.round(value) }
                        Text { text: Mako.fontSize + "pt"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
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
                            Text { text: Config ? (Config.language, Config.trAuto(modelData.label)) : modelData.label; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
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
                        Text { text: Config ? (Config.language, Config.trAuto("Время показа (мс):")) : "Время показа (мс):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 1000; to: 15000; stepSize: 500; value: Mako.defaultTimeout; onMoved: Mako.defaultTimeout = Math.round(value) }
                        Text { text: (Mako.defaultTimeout / 1000).toFixed(1) + "s"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Макс. уведомлений на экране:")) : "Макс. уведомлений на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider { Layout.fillWidth: true; from: 1; to: 10; stepSize: 1; value: Mako.maxVisible; onMoved: Mako.maxVisible = Math.round(value) }
                        Text { text: Mako.maxVisible.toString(); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
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
