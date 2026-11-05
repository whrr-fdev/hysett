import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: wbScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: wbScroll.availableWidth
        implicitHeight: wbCol.implicitHeight + 40

        ColumnLayout {
            id: wbCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: "Настройки верхней панели (TopBar)"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 4
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: posRow.implicitHeight + 16
                RowLayout {
                    id: posRow; anchors.fill: parent; anchors.margins: 10
                    Text { text: "Расположение панели на экране:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                    Item { Layout.fillWidth: true }
                    SegmentedButton {
                        options: ["Сверху", "Снизу", "Слева", "Справа"]
                        selectedIndex: Waybar ? Waybar.barPosition : 0
                        onSelected: (idx) => { if (Waybar) Waybar.barPosition = idx }
                    }
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: modeRow.implicitHeight + 16

                RowLayout {
                    id: modeRow
                    anchors.fill: parent
                    anchors.margins: 10

                    Text { text: "Режим компоновки панели:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                    Item { Layout.fillWidth: true }
                    SegmentedButton {
                        options: ["Заданная ширина / Полная", "По центру (Островок)"]
                        selectedIndex: (Waybar && Waybar.centeredBar) ? 1 : 0
                        onSelected: (idx) => { if (Waybar) Waybar.centeredBar = (idx === 1) }
                    }
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: modsCol.implicitHeight + 20

                ColumnLayout {
                    id: modsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Отображаемые компоненты на панели задач"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                        StyledButton {
                            text: "Включить все"
                            implicitHeight: 20
                            visible: Waybar && Waybar.hiddenBarModules.length > 0
                            onClicked: if (Waybar) Waybar.hiddenBarModules = ""
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 14
                        rowSpacing: 6

                        Repeater {
                            model: [
                                { title: "   Кнопка пуска (Поиск)", key: "launcher" },
                                { title: "󰖲   Рабочие столы (1..5)", key: "workspaces" },
                                { title: "☁️   Погода", key: "weather" },
                                { title: "󰘳   Заголовок окна", key: "window" },
                                { title: "   Ресурсы (CPU/RAM)", key: "sysinfo" },
                                { title: "󰀻   Системный трей", key: "tray" },
                                { title: "󰂯   Bluetooth", key: "bluetooth" },
                                { title: "󰈀   Сеть", key: "network" },
                                { title: "󰅌   Буфер обмена", key: "clipboard" },
                                { title: "󰕾   Громкость", key: "volume" },
                                { title: "⌨   Язык (RU/EN)", key: "language" },
                                { title: "🕒   Часы и календарь", key: "clock" },
                                { title: "⏻   Кнопка питания", key: "power" }
                            ]

                            StyledCheckBox {
                                text: modelData.title
                                checked: {
                                    var _ = Waybar ? Waybar.hiddenBarModules : ""
                                    return Waybar ? Waybar.isBarModuleVisible(modelData.key) : true
                                }
                                onToggled: if (Waybar) Waybar.setBarModuleVisible(modelData.key, checked)
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Waybar ? Waybar.specs : []

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colSp.implicitHeight + 16

                    RowLayout {
                        id: colSp
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text { text: modelData.label + ":"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: modelData.min; to: modelData.max; stepSize: modelData.step
                            value: modelData.value
                            onMoved: Waybar.setSpecValue(index, value)
                        }
                        Text {
                            text: modelData.dec === 0 ? Math.round(modelData.value) + "px" : Math.round(modelData.value * 100) + "%"
                            color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight
                        }
                        StyledButton { text: "↺"; implicitWidth: 22; onClicked: Waybar.resetSpec(index) }
                    }
                }
            }
        }
    }
}
