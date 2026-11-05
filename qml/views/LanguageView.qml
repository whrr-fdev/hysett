import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: langScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: langScroll.availableWidth
        implicitHeight: lCol.implicitHeight + 40

        ColumnLayout {
            id: lCol
            width: Math.min(parent.width - 48, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 24
            spacing: 14

            Text {
                text: "󰌌  Язык системы и раскладка клавиатуры"
                color: "#ffffff"; font.pixelSize: Config.fontSize + 3; font.bold: true
            }

            GlassPanel {
                Layout.fillWidth: true; implicitHeight: kbCol.implicitHeight + 24
                ColumnLayout {
                    id: kbCol; anchors.fill: parent; anchors.margins: 14; spacing: 12
                    Text { text: "Активная раскладка ввода (Hyprland)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Текущая раскладка клавиатуры:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        SegmentedButton {
                            options: ["EN (English)", "RU (Русская)"]
                            selectedIndex: (Waybar && Waybar.kbLayout === "RU") ? 1 : 0
                            onSelected: (idx) => {
                                if (Waybar && ((idx === 1 && Waybar.kbLayout !== "RU") || (idx === 0 && Waybar.kbLayout === "RU"))) {
                                    Waybar.switchKbLayout()
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Комбинация клавиш для смены языка:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                        StyledComboBox {
                            Layout.fillWidth: true
                            model: ["Alt + Shift (grp:alt_shift_toggle)", "Ctrl + Shift (grp:ctrl_shift_toggle)", "Caps Lock (grp:caps_toggle)", "Win + Space (grp:win_space_toggle)"]
                            currentIndex: {
                                var opt = Devices ? Devices.kbOptions : ""
                                if (opt.indexOf("ctrl_shift") !== -1) return 1
                                if (opt.indexOf("caps") !== -1) return 2
                                if (opt.indexOf("win_space") !== -1) return 3
                                return 0
                            }
                            onActivated: (idx) => {
                                if (Devices) Devices.kbOptions = ["grp:alt_shift_toggle", "grp:ctrl_shift_toggle", "grp:caps_toggle", "grp:win_space_toggle"][idx]
                            }
                        }
                    }
                }
            }

            GlassPanel {
                Layout.fillWidth: true; implicitHeight: uiCol.implicitHeight + 24
                ColumnLayout {
                    id: uiCol; anchors.fill: parent; anchors.margins: 14; spacing: 10
                    Text { text: "Язык интерфейса HySett"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Язык меню и карточек настроек:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        SegmentedButton {
                            options: ["Русский (RU)", "English (EN)"]
                            selectedIndex: (Config && Config.language === "en") ? 1 : 0
                            onSelected: (idx) => { if (Config) Config.language = (idx === 1 ? "en" : "ru") }
                        }
                    }
                }
            }
        }
    }
}
