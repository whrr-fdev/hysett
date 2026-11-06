import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: lookScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: lookScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 5

            // Заголовок теперь внутри ScrollView — скроллится наверх вместе с контентом!
            Text {
                text: Config ? (Config.language, Config.trAuto("Окна и оформление рабочего стола")) : "Окна и оформление рабочего стола"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 8
            }

            component SettingRow: GlassPanel {
                id: rowRoot
                property string title: ""
                property alias controlItem: placeholder.children
                property string displayVal: ""
                signal resetClicked()

                Layout.fillWidth: true
                implicitHeight: 32
                radius: (Theme && Theme.isRounded) ? (Config ? Math.min(14, Config.m3CardRadius) : 12) : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 10

                    Text {
                        text: rowRoot.title
                        color: "#cccccc"
                        font.pixelSize: Config.fontSize
                        Layout.preferredWidth: 230
                    }

                    Item {
                        id: placeholder
                        Layout.fillWidth: true
                        implicitHeight: 20
                    }

                    Text {
                        visible: rowRoot.displayVal.length > 0
                        text: rowRoot.displayVal
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                    }

                    StyledButton {
                        text: "↺"
                        implicitWidth: 22
                        implicitHeight: 20
                        onClicked: rowRoot.resetClicked()
                    }
                }
            }

            // 0. РЕЖИМ СТИЛЯ: MATERIAL DESIGN 3 (СКРУГЛЕНИЕ ОКОН) И ПАЛИТРА
            GlassPanel {
                Layout.fillWidth: true
                implicitHeight: m3LookCol.implicitHeight + 20
                Layout.bottomMargin: 6

                ColumnLayout {
                    id: m3LookCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰏘  Стиль интерфейса и скругление окон (Material Design 3)"
                            color: Config ? Config.m3Primary : "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Режим оформления окон и контролов:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                        }
                        SegmentedButton {
                            Layout.preferredWidth: 320
                            options: ["Квадратный (Sharp)", "Material Design 3 (Скругленный)"]
                            selectedIndex: (Theme && Theme.isRounded) ? 1 : 0
                            onSelected: (idx) => { if (Theme) Theme.setRoundedState(idx === 1) }
                        }
                    }

                    RowLayout {
                        visible: Theme && Theme.isRounded
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Динамическая палитра из текущих обоев (Material You):"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                        }
                        StyledButton {
                            text: "󰸉 Обновить из обоев"
                            implicitHeight: 20
                            visible: Config ? Config.m3DynamicWallpaperColors : false
                            onClicked: if (Config) Config.extractPaletteFromWallpaper()
                        }
                        StyledSwitch {
                            checked: Config ? Config.m3DynamicWallpaperColors : true
                            onToggled: if (Config) Config.m3DynamicWallpaperColors = checked
                        }
                    }

                    RowLayout {
                        visible: Theme && Theme.isRounded
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Тональная палитра MD3:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 170
                        }
                        SegmentedButton {
                            Layout.fillWidth: true
                            options: ["Pixel Blue", "Emerald", "Lavender", "Sakura", "Amber", "Ocean"]
                            selectedIndex: Config ? Config.m3Preset : 0
                            onSelected: (idx) => { if (Config) Config.applyM3Preset(idx) }
                        }
                    }
                }
            }

            // 1. Прозрачность активного окна
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Прозрачность активного окна:")) : "Прозрачность активного окна:"
                displayVal: Number(Look.activeOpacity).toFixed(2)
                onResetClicked: Look.activeOpacity = 0.85
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.1; to: 1.0; stepSize: 0.05; value: Look.activeOpacity
                    onMoved: Look.activeOpacity = value
                }
            }

            // 2. Прозрачность неактивного
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Прозрачность неактивного:")) : "Прозрачность неактивного:"
                displayVal: Number(Look.inactiveOpacity).toFixed(2)
                onResetClicked: Look.inactiveOpacity = 0.75
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.1; to: 1.0; stepSize: 0.05; value: Look.inactiveOpacity
                    onMoved: Look.inactiveOpacity = value
                }
            }

            // 3. Затемнять неактивные
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Затемнять неактивные:")) : "Затемнять неактивные:"
                onResetClicked: Look.dimInactive = false
                controlItem: StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Look.dimInactive; onToggled: Look.dimInactive = checked
                }
            }

            // 4. Сила затемнения
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Сила затемнения:")) : "Сила затемнения:"
                displayVal: Number(Look.dimStrength).toFixed(2)
                onResetClicked: Look.dimStrength = 0.75
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.05; value: Look.dimStrength
                    onMoved: Look.dimStrength = value
                }
            }

            // 5. Затемнение вокруг (dimaround)
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Затемнение вокруг (dimaround):")) : "Затемнение вокруг (dimaround):"
                displayVal: Number(Look.dimAround).toFixed(2)
                onResetClicked: Look.dimAround = 0.40
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.05; value: Look.dimAround
                    onMoved: Look.dimAround = value
                }
            }

            // 6. Блюр
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Блюр:")) : "Блюр:"
                onResetClicked: Look.blurEnabled = true
                controlItem: StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Look.blurEnabled; onToggled: Look.blurEnabled = checked
                }
            }

            // 7. Размер блюра
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Размер блюра:")) : "Размер блюра:"
                displayVal: Look.blurSize.toString()
                onResetClicked: Look.blurSize = 1
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 1; to: 16; stepSize: 1; value: Look.blurSize
                    onMoved: Look.blurSize = Math.round(value)
                }
            }

            // 8. Проходы блюра
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Проходы блюра:")) : "Проходы блюра:"
                displayVal: Look.blurPasses.toString()
                onResetClicked: Look.blurPasses = 2
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 1; to: 6; stepSize: 1; value: Look.blurPasses
                    onMoved: Look.blurPasses = Math.round(value)
                }
            }

            // 9. Насыщенность блюра
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Насыщенность блюра:")) : "Насыщенность блюра:"
                displayVal: Number(Look.blurVibrancy).toFixed(2)
                onResetClicked: Look.blurVibrancy = 0.50
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.05; value: Look.blurVibrancy
                    onMoved: Look.blurVibrancy = value
                }
            }

            // 10. Тени
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Тени:")) : "Тени:"
                onResetClicked: Look.shadowEnabled = true
                controlItem: StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Look.shadowEnabled; onToggled: Look.shadowEnabled = checked
                }
            }

            // 11. Размер теней
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Размер теней:")) : "Размер теней:"
                displayVal: Look.shadowRange.toString()
                onResetClicked: Look.shadowRange = 4
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0; to: 40; stepSize: 1; value: Look.shadowRange
                    onMoved: Look.shadowRange = Math.round(value)
                }
            }

            // 12. Отступы между окнами
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Отступы между окнами:")) : "Отступы между окнами:"
                displayVal: Look.gapsIn.toString()
                onResetClicked: Look.gapsIn = 3
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0; to: 30; stepSize: 1; value: Look.gapsIn
                    onMoved: Look.gapsIn = Math.round(value)
                }
            }

            // 13. Внешние отступы
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Внешние отступы:")) : "Внешние отступы:"
                displayVal: Look.gapsOut.toString()
                onResetClicked: Look.gapsOut = 10
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0; to: 50; stepSize: 1; value: Look.gapsOut
                    onMoved: Look.gapsOut = Math.round(value)
                }
            }

            // 14. Толщина рамки
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Толщина рамки:")) : "Толщина рамки:"
                displayVal: Look.borderSize.toString()
                onResetClicked: Look.borderSize = 1
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0; to: 8; stepSize: 1; value: Look.borderSize
                    onMoved: Look.borderSize = Math.round(value)
                }
            }

            // 15. Анимации
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Анимации:")) : "Анимации:"
                onResetClicked: Look.animsEnabled = true
                controlItem: StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Look.animsEnabled; onToggled: Look.animsEnabled = checked
                }
            }

            // 16. Цвет активной рамки
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Цвет активной рамки (RGBA):")) : "Цвет активной рамки (RGBA):"
                onResetClicked: Look.activeBorder = "rgba(ccccccff)"
                controlItem: TextField {
                    anchors.fill: parent
                    text: Look.activeBorder
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize
                    background: Rectangle { color: "transparent" }
                    onEditingFinished: Look.activeBorder = text
                }
            }

            // 17. Цвет неактивной рамки
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Цвет неактивной рамки (RGBA):")) : "Цвет неактивной рамки (RGBA):"
                onResetClicked: Look.inactiveBorder = "rgba(333333ff)"
                controlItem: TextField {
                    anchors.fill: parent
                    text: Look.inactiveBorder
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize
                    background: Rectangle { color: "transparent" }
                    onEditingFinished: Look.inactiveBorder = text
                }
            }

            // Кнопки отката и сброса
            RowLayout {
                spacing: 8
                Layout.topMargin: 4

                StyledButton {
                    text: Config ? (Config.language, Config.trAuto("↩ Откатить (")) : "↩ Откатить (" + Look.backupCount + ")"
                    enabled: Look.backupCount > 0
                    implicitHeight: 22
                    onClicked: Look.undo()
                }

                StyledButton {
                    text: Config ? (Config.language, Config.trAuto("Сбросить к hyprland.lua")) : "Сбросить к hyprland.lua"
                    implicitHeight: 22
                    onClicked: Look.resetToDefaults()
                }
            }
        }
    }
}
