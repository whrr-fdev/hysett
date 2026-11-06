import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: devScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: devScroll.availableWidth
        implicitHeight: devCol.implicitHeight + 40

        ColumnLayout {
            id: devCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            Text {
                text: Config ? (Config.language, Config.trAuto("Устройства ввода (Devices)")) : "Устройства ввода (Devices)"
                color: "#ffffff"
                font.pixelSize: Config.fontSize + 3
                font.bold: true
                Layout.bottomMargin: 4
            }

            // 0. ЗВУК И АУДИО (AUDIO)
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colAudio.implicitHeight + 16

                ColumnLayout {
                    id: colAudio
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: Config ? (Config.language, Config.trAuto("Звук и Аудио (Audio)")) : "Звук и Аудио (Audio)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true; Layout.fillWidth: true }
                        StyledButton {
                            text: "󰕾  Pavucontrol"
                            implicitHeight: 22
                            onClicked: if (Waybar) Waybar.runCommand("pavucontrol")
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Громкость (Volume):")) : "Громкость (Volume):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 1
                            value: Waybar ? Waybar.volume : 50
                            onMoved: if (Waybar) Waybar.setVolumeExact(Math.round(value))
                        }
                        Text { text: (Waybar ? Waybar.volume : 50) + "%"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Отключить звук (Mute):")) : "Отключить звук (Mute):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch {
                            checked: Waybar ? Waybar.muted : false
                            onToggled: if (Waybar) Waybar.toggleMute()
                        }
                    }
                }
            }

            // 1. КЛАВИАТУРА
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colKb.implicitHeight + 16

                ColumnLayout {
                    id: colKb
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: Config ? (Config.language, Config.trAuto("Клавиатура (Keyboard)")) : "Клавиатура (Keyboard)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Раскладки клавиатуры:")) : "Раскладки клавиатуры:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        Text { text: Config ? (Config.language, Config.trAuto("Английская (США), Русская (us, ru)")) : "Английская (США), Русская (us, ru)"; color: "#888888"; font.pixelSize: Config.fontSize - 1 }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Переключение языка:")) : "Переключение языка:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledComboBox {
                            Layout.fillWidth: true
                            model: ["Alt + Shift (grp:alt_shift_toggle)", "Ctrl + Shift (grp:ctrl_shift_toggle)", "Caps Lock (grp:caps_toggle)", "Win + Space (grp:win_space_toggle)"]
                            currentIndex: {
                                var opt = Devices.kbOptions
                                if (opt.indexOf("ctrl_shift") !== -1) return 1
                                if (opt.indexOf("caps") !== -1) return 2
                                if (opt.indexOf("win_space") !== -1) return 3
                                return 0
                            }
                            onActivated: (idx) => {
                                var codes = ["grp:alt_shift_toggle", "grp:ctrl_shift_toggle", "grp:caps_toggle", "grp:win_space_toggle"]
                                Devices.kbOptions = codes[idx]
                            }
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Numlock по умолчанию:")) : "Numlock по умолчанию:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Devices.numlock; onToggled: Devices.numlock = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Частота повтора (Repeat rate):")) : "Частота повтора (Repeat rate):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider { Layout.fillWidth: true; from: 10; to: 80; stepSize: 5; value: Devices.repeatRate; onMoved: Devices.repeatRate = Math.round(value) }
                        Text { text: Devices.repeatRate.toString(); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Задержка повтора (Repeat delay):")) : "Задержка повтора (Repeat delay):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider { Layout.fillWidth: true; from: 200; to: 1200; stepSize: 50; value: Devices.repeatDelay; onMoved: Devices.repeatDelay = Math.round(value) }
                        Text { text: Devices.repeatDelay + "ms"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                    }
                }
            }

            // 2. МЫШЬ
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colM.implicitHeight + 16

                ColumnLayout {
                    id: colM
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: Config ? (Config.language, Config.trAuto("Мышь (Mouse)")) : "Мышь (Mouse)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Чувствительность (Sensitivity):")) : "Чувствительность (Sensitivity):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider { Layout.fillWidth: true; from: -1.0; to: 1.0; stepSize: 0.1; value: Devices.mouseSensitivity; onMoved: Devices.mouseSensitivity = value }
                        Text { text: Devices.mouseSensitivity.toFixed(2); color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Профиль ускорения:")) : "Профиль ускорения:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledComboBox {
                            Layout.fillWidth: true
                            model: ["По умолчанию (Default)", "Адаптивный (Adaptive)", "Прямой (Flat)"]
                            currentIndex: Devices.accelProfile === "adaptive" ? 1 : (Devices.accelProfile === "flat" ? 2 : 0)
                            onActivated: (idx) => Devices.accelProfile = ["default", "adaptive", "flat"][idx]
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Фокус за курсором (Follow mouse):")) : "Фокус за курсором (Follow mouse):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        Item { Layout.fillWidth: true }
                        SegmentedButton {
                            options: ["Откл", "Полный", "Свободный"]
                            selectedIndex: Devices.followMouse
                            onSelected: (idx) => Devices.followMouse = idx
                        }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Естественная прокрутка (Natural scroll):")) : "Естественная прокрутка (Natural scroll):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Devices.naturalScroll; onToggled: Devices.naturalScroll = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Множитель прокрутки (Scroll factor):")) : "Множитель прокрутки (Scroll factor):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 220 }
                        StyledSlider { Layout.fillWidth: true; from: 0.2; to: 4.0; stepSize: 0.2; value: Devices.scrollFactor; onMoved: Devices.scrollFactor = value }
                        Text { text: Devices.scrollFactor.toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Режим левши (Left-handed):")) : "Режим левши (Left-handed):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Devices.leftHanded; onToggled: Devices.leftHanded = checked }
                    }

                    RowLayout {
                        Text { text: Config ? (Config.language, Config.trAuto("Повторный фокус (Mouse refocus):")) : "Повторный фокус (Mouse refocus):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                        StyledSwitch { checked: Devices.mouseRefocus; onToggled: Devices.mouseRefocus = checked }
                    }
                }
            }

            // 3. ТАЧПАД
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: colTp.implicitHeight + 14

                ColumnLayout {
                    id: colTp
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text { text: Config ? (Config.language, Config.trAuto("Тачпад (Touchpad)")) : "Тачпад (Touchpad)"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                    Text {
                        text: Devices.hasTouchpad ? "󰌌  Тачпад подключен и активен" : "Тачпад не обнаружен (No touchpad detected)"
                        color: Devices.hasTouchpad ? "#ffffff" : "#888888"
                        font.pixelSize: Config.fontSize
                    }
                }
            }
        }
    }
}
