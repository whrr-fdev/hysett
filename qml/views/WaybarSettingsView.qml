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
                implicitHeight: titleModeRow.implicitHeight + 16

                RowLayout {
                    id: titleModeRow
                    anchors.fill: parent
                    anchors.margins: 10

                    Text { text: "Размер заголовка активного окна:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                    Item { Layout.fillWidth: true }
                    SegmentedButton {
                        options: ["По размеру (≤ 220px)", "Фиксированный (200px)"]
                        selectedIndex: (Waybar && Waybar.fixedTitleWidth) ? 1 : 0
                        onSelected: (idx) => { if (Waybar) Waybar.fixedTitleWidth = (idx === 1) }
                    }
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: uniRow.implicitHeight + 16

                RowLayout {
                    id: uniRow
                    anchors.fill: parent
                    anchors.margins: 10

                    Text { text: "Отступы при расширении узкой панели:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                    Item { Layout.fillWidth: true }
                    SegmentedButton {
                        options: ["Только у заголовка", "Равномерно между блоками"]
                        selectedIndex: (Waybar && Waybar.uniformBarSpacing) ? 1 : 0
                        onSelected: (idx) => { if (Waybar) Waybar.uniformBarSpacing = (idx === 1) }
                    }
                }
            }

            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: editCol.implicitHeight + 20

                ColumnLayout {
                    id: editCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Редактирование блоков и разделители панели"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                        StyledButton {
                            text: (Waybar && Waybar.barEditMode) ? "✓ Готово (Выйти из ред.)" : "✎ Режим перетаскивания на панели"
                            implicitHeight: 24
                            isActive: Waybar ? Waybar.barEditMode : false
                            onClicked: if (Waybar) Waybar.barEditMode = !Waybar.barEditMode
                        }
                        StyledButton {
                            text: "↺ Сбросить порядок"
                            implicitHeight: 24
                            onClicked: if (Waybar) Waybar.resetBarOrder()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Вертикальные разделители между всеми блоками:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }

                        StyledSwitch {
                            checked: Waybar ? Waybar.barSeparators : false
                            onToggled: if (Waybar) Waybar.barSeparators = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Автоскрытие плеера музыки при паузе:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 120; stepSize: 5
                            value: Waybar ? Waybar.mediaHideTimeout : 15
                            onMoved: if (Waybar) Waybar.mediaHideTimeout = Math.round(value)
                        }
                        Text {
                            text: (Waybar && Waybar.mediaHideTimeout === 0) ? "Выкл" : ((Waybar ? Waybar.mediaHideTimeout : 15) + " сек")
                            color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight
                        }
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
                                { title: "󰣇   Кнопка пуска CachyOS", key: "launcher" },
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
                model: Waybar ? Waybar.specs.length : 0

                GlassPanel {
                    id: specCard
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colSp.implicitHeight + 16
                    readonly property var specItem: (Waybar && index < Waybar.specs.length)
                                                    ? Waybar.specs[index]
                                                    : ({ label: "", key: "", min: 0, max: 100, step: 1, value: 0, dec: 0 })

                    RowLayout {
                        id: colSp
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text { text: specCard.specItem.label + ":"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider {
                            id: spSlider
                            Layout.fillWidth: true
                            from: specCard.specItem.min; to: specCard.specItem.max; stepSize: specCard.specItem.step
                            Binding on value {
                                when: !spSlider.pressed
                                value: specCard.specItem.value
                            }
                            onMoved: Waybar.setSpecValue(index, value)
                        }
                        Text {
                            readonly property real curV: spSlider.pressed ? spSlider.value : specCard.specItem.value
                            text: specCard.specItem.key === "bar_anim_duration" ? (Math.round(curV) + "мс") : (specCard.specItem.dec === 0 ? Math.round(curV) + "px" : Math.round(curV * 100) + "%")
                            color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight
                        }
                        StyledButton { text: "↺"; implicitWidth: 22; onClicked: Waybar.resetSpec(index) }
                    }
                }
            }
        }
    }
}
