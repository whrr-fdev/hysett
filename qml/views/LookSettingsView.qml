import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: lookScroll
    contentWidth: availableWidth
    clip: true

    property int borderColorTarget: 0 // 0 = activeBorder, 1 = inactiveBorder

    function rgbaToHexColor(rgbaStr, fallbackHex) {
        var m = String(rgbaStr || "").match(/rgba\(([0-9a-fA-F]{6})/)
        if (m && m[1]) return "#" + m[1]
        var m2 = String(rgbaStr || "").match(/#([0-9a-fA-F]{6})/)
        if (m2 && m2[1]) return "#" + m2[1]
        return fallbackHex
    }

    function hexToHyprRgba(colObj, alphaHex) {
        var s = colObj.toString().replace("#", "")
        if (s.length === 8) s = s.slice(2)
        return "rgba(" + s.toLowerCase() + (alphaHex || "ff") + ")"
    }

    ColorPickerModal {
        id: borderColorModal
        onColorSelected: (newCol) => {
            if (Look.borderSyncWithWallpaper) Look.borderSyncWithWallpaper = false
            if (lookScroll.borderColorTarget === 0) {
                Look.activeBorder = lookScroll.hexToHyprRgba(newCol, "ee")
            } else {
                Look.inactiveBorder = lookScroll.hexToHyprRgba(newCol, "aa")
            }
        }
    }

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
                implicitHeight: 36
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
                        Layout.preferredWidth: 250
                        elide: Text.ElideRight
                    }

                    Item {
                        id: placeholder
                        Layout.fillWidth: true
                        implicitHeight: 26
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

            // 0. Режим прозрачности только фона (без потери яркости текста)
            SettingRow {
                title: "Не менять прозрачность текста:"
                onResetClicked: Look.bgOnlyOpacity = true
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    StyledSwitch {
                        checked: Look.bgOnlyOpacity
                        onToggled: Look.bgOnlyOpacity = checked
                    }
                    Text {
                        text: Look.bgOnlyOpacity
                              ? "Прозрачным становится только фон окон (текст 100% чёткий даже на 0%)"
                              : "Обычная прозрачность всего окна целиком вместе с текстом"
                        color: Look.bgOnlyOpacity ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                        font.pixelSize: Config.fontSize - 1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // 1. Прозрачность активного окна
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Прозрачность активного окна:")) : "Прозрачность активного окна:"
                displayVal: Math.round(Look.activeOpacity * 100) + "%"
                onResetClicked: Look.activeOpacity = 0.85
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.02; value: Look.activeOpacity
                    onMoved: Look.activeOpacity = value
                }
            }

            // 2. Прозрачность неактивного
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Прозрачность неактивного:")) : "Прозрачность неактивного:"
                displayVal: Math.round(Look.inactiveOpacity * 100) + "%"
                onResetClicked: Look.inactiveOpacity = 0.75
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.02; value: Look.inactiveOpacity
                    onMoved: Look.inactiveOpacity = value
                }
            }

            // 2-other-a. Отдельная прозрачность прочих активных окон (браузер, AyuGram и др.)
            SettingRow {
                visible: Look.bgOnlyOpacity
                title: "Браузер, AyuGram (активные):"
                displayVal: Math.round(Look.otherActiveOpacity * 100) + "%"
                onResetClicked: Look.otherActiveOpacity = 0.75
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.15; to: 1.0; stepSize: 0.02; value: Look.otherActiveOpacity
                    onMoved: Look.otherActiveOpacity = value
                }
            }

            // 2-other-b. Отдельная прозрачность прочих неактивных окон
            SettingRow {
                visible: Look.bgOnlyOpacity
                title: "Браузер, AyuGram (неактивные):"
                displayVal: Math.round(Look.otherInactiveOpacity * 100) + "%"
                onResetClicked: Look.otherInactiveOpacity = 0.65
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.15; to: 1.0; stepSize: 0.02; value: Look.otherInactiveOpacity
                    onMoved: Look.otherInactiveOpacity = value
                }
            }

            // 2a. Отдельная прозрачность фона самого окна HySett
            SettingRow {
                title: "Прозрачность фона HySett:"
                displayVal: Math.round((Config ? Config.opacity : 0.70) * 100) + "%"
                onResetClicked: if (Config) Config.opacity = 0.70
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.opacity : 0.70
                    onMoved: if (Config) Config.opacity = value
                }
            }

            // 2b. Отдельная прозрачность карточек HySett
            SettingRow {
                title: "Прозрачность карточек HySett:"
                displayVal: Math.round((Config ? Config.cardOpacity : 0.10) * 100) + "%"
                onResetClicked: if (Config) Config.cardOpacity = 0.10
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 0.0; to: 1.0; stepSize: 0.02; value: Config ? Config.cardOpacity : 0.10
                    onMoved: if (Config) Config.cardOpacity = value
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
                onResetClicked: Look.blurSize = 6
                controlItem: StyledSlider {
                    anchors.fill: parent; from: 1; to: 16; stepSize: 1; value: Look.blurSize
                    onMoved: Look.blurSize = Math.round(value)
                }
            }

            // 8. Проходы блюра
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Проходы блюра:")) : "Проходы блюра:"
                displayVal: Look.blurPasses.toString()
                onResetClicked: Look.blurPasses = 3
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

            // 14a. Скрывать рамку, когда открыто одно окно на столе
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Без рамки у одного окна:")) : "Без рамки у одного окна:"
                onResetClicked: Look.noBorderSingleWindow = true
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    StyledSwitch {
                        checked: Look.noBorderSingleWindow
                        onToggled: Look.noBorderSingleWindow = checked
                    }
                    Text {
                        text: Look.noBorderSingleWindow
                              ? "Скрывать обводку, когда на столе одно окно (не плавающее)"
                              : "Показывать обводку всегда"
                        color: Look.noBorderSingleWindow ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                        font.pixelSize: Config.fontSize - 1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // 14b. Граница только у активного окна (убрать у неактивных и панели)
            SettingRow {
                title: "Граница только у активного окна:"
                onResetClicked: Look.activeBorderOnly = true
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    StyledSwitch {
                        checked: Look.activeBorderOnly
                        onToggled: Look.activeBorderOnly = checked
                    }
                    Text {
                        text: Look.activeBorderOnly
                              ? "Без обводки у неактивных окон и панели, мягкая граница у активного"
                              : "Обводка у всех окон и у панели задач"
                        color: Look.activeBorderOnly ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                        font.pixelSize: Config.fontSize - 1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
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

            // 16. Рамки окон в цвет обоев (динамическая палитра)
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Рамки окон в цвет обоев:")) : "Рамки окон в цвет обоев:"
                onResetClicked: Look.borderSyncWithWallpaper = true
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    StyledSwitch {
                        checked: Look.borderSyncWithWallpaper
                        onToggled: Look.borderSyncWithWallpaper = checked
                    }
                    Text {
                        text: Look.borderSyncWithWallpaper
                              ? "Автоматически из текущих обоев / темы"
                              : "Ручной выбор цвета рамки"
                        color: Look.borderSyncWithWallpaper ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                        font.pixelSize: Config.fontSize - 1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // 17. Цвет активной рамки (не обрезается + кнопка Палитра с модальным окном)
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Цвет активной рамки (RGBA):")) : "Цвет активной рамки (RGBA):"
                onResetClicked: { Look.borderSyncWithWallpaper = false; Look.activeBorder = "rgba(ccccccff)" }
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: lookScroll.rgbaToHexColor(Look.activeBorder, "#cccccc")
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lookScroll.borderColorTarget = 0
                                borderColorModal.openPicker("Цвет активной рамки", lookScroll.rgbaToHexColor(Look.activeBorder, "#cccccc"))
                            }
                        }
                    }

                    TextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 8
                        rightPadding: 8
                        verticalAlignment: TextInput.AlignVCenter
                        text: Look.activeBorder
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: parent.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.14)
                        }
                        onEditingFinished: {
                            Look.borderSyncWithWallpaper = false
                            Look.activeBorder = text.trim()
                        }
                    }

                    StyledButton {
                        text: "󰏘 Палитра"
                        implicitHeight: 22
                        onClicked: {
                            lookScroll.borderColorTarget = 0
                            borderColorModal.openPicker("Цвет активной рамки", lookScroll.rgbaToHexColor(Look.activeBorder, "#cccccc"))
                        }
                    }
                }
            }

            // 18. Цвет неактивной рамки (не обрезается + кнопка Палитра с модальным окном)
            SettingRow {
                title: Config ? (Config.language, Config.trAuto("Цвет неактивной рамки (RGBA):")) : "Цвет неактивной рамки (RGBA):"
                onResetClicked: { Look.borderSyncWithWallpaper = false; Look.inactiveBorder = "rgba(767676cc)" }
                controlItem: RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: (Theme && Theme.isRounded) ? 6 : 0
                        color: lookScroll.rgbaToHexColor(Look.inactiveBorder, "#333333")
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lookScroll.borderColorTarget = 1
                                borderColorModal.openPicker("Цвет неактивной рамки", lookScroll.rgbaToHexColor(Look.inactiveBorder, "#333333"))
                            }
                        }
                    }

                    TextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 8
                        rightPadding: 8
                        verticalAlignment: TextInput.AlignVCenter
                        text: Look.inactiveBorder
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        background: Rectangle {
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: parent.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.14)
                        }
                        onEditingFinished: {
                            Look.borderSyncWithWallpaper = false
                            Look.inactiveBorder = text.trim()
                        }
                    }

                    StyledButton {
                        text: "󰏘 Палитра"
                        implicitHeight: 22
                        onClicked: {
                            lookScroll.borderColorTarget = 1
                            borderColorModal.openPicker("Цвет неактивной рамки", lookScroll.rgbaToHexColor(Look.inactiveBorder, "#333333"))
                        }
                    }
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
