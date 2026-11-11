import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: curScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: curScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: Config ? (Config.language, Config.trAuto("Курсор")) : "Курсор"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 4
            }

            // КАРТОЧКА 1: Тема и размер
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colTh.implicitHeight + 18

                ColumnLayout {
                    id: colTh
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text { text: Config ? (Config.language, Config.trAuto("Тема и размер")) : "Тема и размер"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        spacing: 10

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: (Theme && Theme.isRounded) ? 4 : 0
                            color: Qt.rgba(1, 1, 1, Math.max(0.04, Config ? Config.cardOpacity * 0.15 : 0.06))
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: "image://cursor/" + Cursor.theme
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }

                        StyledComboBox {
                            Layout.fillWidth: true
                            model: Cursor.installedThemes
                            currentIndex: Cursor.installedThemes.indexOf(Cursor.theme)
                            onActivated: (index) => Cursor.theme = Cursor.installedThemes[index]
                        }

                        RowLayout {
                            spacing: 1
                            Rectangle {
                                implicitHeight: 22
                                implicitWidth: 84
                                radius: (Theme && Theme.isRounded) ? 3 : 0
                                color: Qt.rgba(1, 1, 1, Math.max(0.04, Config ? Config.cardOpacity * 0.15 : 0.06))
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    Button {
                                        text: "−"
                                        flat: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 24
                                        onClicked: Cursor.stepSize(-4)
                                        contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                    Text {
                                        text: Cursor.size.toString()
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Button {
                                        text: "+"
                                        flat: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 24
                                        onClicked: Cursor.stepSize(4)
                                        contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // КАРТОЧКА 2: Основные параметры
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colMain.implicitHeight + 18

                ColumnLayout {
                    id: colMain
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text { text: Config ? (Config.language, Config.trAuto("Основные параметры")) : "Основные параметры"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Аппаратный курсор (Hardware cursors):")) : "Аппаратный курсор (Hardware cursors):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                        Item { Layout.fillWidth: true }
                        SegmentedButton {
                            options: ["Вкл", "Выкл", "Авто"]
                            selectedIndex: Cursor.hwCursors === 0 ? 0 : (Cursor.hwCursors === 1 ? 1 : 2)
                            onSelected: (idx) => Cursor.hwCursors = idx === 0 ? 0 : (idx === 1 ? 1 : 2)
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Поддержка Hyprcursor:")) : "Поддержка Hyprcursor:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.enableHyprcursor; onToggled: Cursor.enableHyprcursor = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Отключить перемещение (no_warps):")) : "Отключить перемещение (no_warps):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.noWarps; onToggled: Cursor.noWarps = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Запоминать позицию (persistent_warps):")) : "Запоминать позицию (persistent_warps):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.persistentWarps; onToggled: Cursor.persistentWarps = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Перемещение при смене стола:")) : "Перемещение при смене стола:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                        Item { Layout.fillWidth: true }
                        SegmentedButton {
                            options: ["Выкл", "Вкл", "Принудительно"]
                            selectedIndex: Cursor.warpOnChangeWs
                            onSelected: (idx) => Cursor.warpOnChangeWs = idx
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Масштаб лупы (Zoom factor):")) : "Масштаб лупы (Zoom factor):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 1.0
                            to: 4.0
                            stepSize: 0.1
                            value: Cursor.zoomFactor
                            onMoved: Cursor.zoomFactor = value
                        }
                        Text { text: Cursor.zoomFactor.toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            // КАРТОЧКА 3: Видимость и скрытие
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colVis.implicitHeight + 18

                ColumnLayout {
                    id: colVis
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text { text: Config ? (Config.language, Config.trAuto("Видимость и скрытие")) : "Видимость и скрытие"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Таймаут скрытия:")) : "Таймаут скрытия:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0
                            to: 60
                            stepSize: 5
                            value: Cursor.inactiveTimeout
                            onMoved: Cursor.inactiveTimeout = value
                        }
                        Text { text: Cursor.inactiveTimeout === 0 ? "Никогда" : Math.round(Cursor.inactiveTimeout) + "с"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Скрывать при вводе с клавиатуры:")) : "Скрывать при вводе с клавиатуры:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.hideOnKeyPress; onToggled: Cursor.hideOnKeyPress = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Скрывать при сенсорном вводе:")) : "Скрывать при сенсорном вводе:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.hideOnTouch; onToggled: Cursor.hideOnTouch = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Скрывать при вводе с планшета:")) : "Скрывать при вводе с планшета:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Cursor.hideOnTablet; onToggled: Cursor.hideOnTablet = checked }
                    }
                }
            }
        }
    }
}
