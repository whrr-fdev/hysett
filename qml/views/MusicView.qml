import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: musicScroll
    contentWidth: availableWidth
    clip: true

    Item {
        width: musicScroll.availableWidth
        implicitHeight: musicCol.implicitHeight + 40

        ColumnLayout {
            id: musicCol
            width: Math.min(parent.width - 48, 680)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 22
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰎆  Музыкальный плеер"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 4
                    font.bold: true
                    Layout.fillWidth: true
                }
                StyledButton {
                    text: (Waybar && Waybar.mediaDemoMode) ? "󰎆 Скрыть пример трека" : "󰎆 Показать пример трека"
                    implicitHeight: 24
                    isActive: Waybar ? Waybar.mediaDemoMode : false
                    onClicked: if (Waybar) Waybar.toggleMediaDemo()
                }
            }

            // Главная карточка плеера
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: playerCardCol.implicitHeight + 28

                ColumnLayout {
                    id: playerCardCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        // Обложка / диск с мини-эквалайзером
                        Rectangle {
                            Layout.preferredWidth: 68
                            Layout.preferredHeight: 68
                            radius: (Theme && Theme.isRounded) ? 14 : 0
                            color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.12)
                            border.color: Config ? Config.m3Primary : "#ffffff"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                font.pixelSize: 30
                                color: Config ? Config.m3Primary : "#ffffff"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: (Waybar && Waybar.mediaTitle.length > 0) ? Waybar.mediaTitle : "Нет активного трека"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 3
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (!Waybar) return ""
                                    if (Waybar.mediaDemoMode && !Waybar.hasRealMedia) return "Демо-режим • Пример трека"
                                    return Waybar.mediaPlaying ? "Воспроизводится через MPRIS2" : "На паузе"
                                }
                                color: "#aaaaaa"
                                font.pixelSize: Config.fontSize
                            }
                        }
                    }

                    // Полоса перемотки трека
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0
                            to: Waybar ? Math.max(1, Waybar.mediaLengthSec) : 215
                            stepSize: 1
                            value: Waybar ? Waybar.mediaPosSec : 0
                            onMoved: if (Waybar) Waybar.seekToSecond(Math.round(value))
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: Waybar ? Waybar.mediaPositionText : "00:00"
                                color: "#bbbbbb"
                                font.pixelSize: Config.fontSize - 1
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Waybar ? Waybar.mediaDurationText : "03:35"
                                color: "#bbbbbb"
                                font.pixelSize: Config.fontSize - 1
                            }
                        }
                    }

                    // Кнопки управления воспроизведением и перемоткой
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        StyledButton {
                            text: "󰒮"
                            implicitWidth: 36; implicitHeight: 30
                            onClicked: if (Waybar) Waybar.mediaPrev()
                        }
                        StyledButton {
                            text: "-10с"
                            implicitWidth: 44; implicitHeight: 30
                            onClicked: if (Waybar) Waybar.mediaSeek(-10)
                        }
                        StyledButton {
                            text: (Waybar && Waybar.mediaPlaying) ? "󰏤  Пауза" : "󰐊  Играть"
                            implicitWidth: 96; implicitHeight: 32
                            isActive: Waybar ? Waybar.mediaPlaying : false
                            onClicked: if (Waybar) Waybar.mediaPlayPause()
                        }
                        StyledButton {
                            text: "+10с"
                            implicitWidth: 44; implicitHeight: 30
                            onClicked: if (Waybar) Waybar.mediaSeek(10)
                        }
                        StyledButton {
                            text: "󰒭"
                            implicitWidth: 36; implicitHeight: 30
                            onClicked: if (Waybar) Waybar.mediaNext()
                        }
                    }
                }
            }

            // Карточка настроек виджета плеера на панели задач
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: cfgCol.implicitHeight + 24

                ColumnLayout {
                    id: cfgCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "Поведение виджета музыки на панели задач"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 1
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Волны эквалайзера (прыгающие столбики снизу панели):"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: Waybar ? Waybar.mediaWaves : true
                            onToggled: if (Waybar) Waybar.mediaWaves = checked
                        }
                    }

                    RowLayout {
                        visible: Waybar ? Waybar.mediaWaves : true
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Скорость волн на панели:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 230
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0.2; to: 4.0; stepSize: 0.1
                            value: Waybar ? Waybar.mediaWaveSpeed : 1.5
                            onMoved: if (Waybar) Waybar.mediaWaveSpeed = value
                        }
                        Text {
                            text: (Waybar ? Waybar.mediaWaveSpeed.toFixed(1) : "1.5") + "x"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 58
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        visible: Waybar ? Waybar.mediaWaves : true
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Размер (высота) волн:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 230
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 4.0; to: 24.0; stepSize: 0.5
                            value: Waybar ? Waybar.mediaWaveSize : 11.0
                            onMoved: if (Waybar) Waybar.mediaWaveSize = value
                        }
                        Text {
                            text: Math.round(Waybar ? Waybar.mediaWaveSize : 11) + " px"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 58
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        visible: Waybar ? Waybar.mediaWaves : true
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Количество волн на панели:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 230
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 20; to: 200; stepSize: 5
                            value: Waybar ? Waybar.mediaWaveCount : 95
                            onMoved: if (Waybar) Waybar.mediaWaveCount = Math.round(value)
                        }
                        Text {
                            text: String(Waybar ? Waybar.mediaWaveCount : 95)
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 58
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Свернуть виджет музыки на панели (компактный вид):"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: Waybar ? Waybar.mediaCollapsed : false
                            onToggled: if (Waybar) Waybar.mediaCollapsed = checked
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Показывать плеер на верхней панели:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: {
                                var _ = Waybar ? Waybar.hiddenBarModules : ""
                                return Waybar ? Waybar.isBarModuleVisible("media") : true
                            }
                            onToggled: if (Waybar) Waybar.setBarModuleVisible("media", checked)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Скрывать с панели при паузе через:"
                            color: "#cccccc"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 230
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 120; stepSize: 5
                            value: Waybar ? Waybar.mediaHideTimeout : 15
                            onMoved: if (Waybar) Waybar.mediaHideTimeout = Math.round(value)
                        }
                        Text {
                            text: (Waybar && Waybar.mediaHideTimeout === 0) ? "Никогда" : ((Waybar ? Waybar.mediaHideTimeout : 15) + " сек")
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            Layout.preferredWidth: 58
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // Карточка синхронизации плейлистов Яндекс.Музыки и скачивания "Моей волны"
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: ymCol.implicitHeight + 28

                ColumnLayout {
                    id: ymCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "󰓇  Синхронизация Яндекс.Музыки и «Моя волна»"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        StyledButton {
                            text: "󰉋 Папка музыки"
                            implicitHeight: 24
                            onClicked: if (Waybar) Waybar.openYmMusicFolder()
                        }
                        StyledButton {
                            text: "󰌇 Получить токен"
                            implicitHeight: 24
                            onClicked: if (Waybar) Waybar.openYmOAuth()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: ymTokenField
                            Layout.fillWidth: true
                            implicitHeight: 28
                            leftPadding: 10; rightPadding: 10
                            echoMode: TextInput.Password
                            color: "#ffffff"
                            font.pixelSize: 11
                            placeholderText: (Waybar && Waybar.ymHasToken) ? "OAuth-токен сохранен (вставьте новый для замены)..." : "Вставьте OAuth-токен или ссылку после авторизации..."
                            placeholderTextColor: (Waybar && Waybar.ymHasToken) ? "#69f0ae" : "#777777"
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 8 : 0
                                color: (Theme && Theme.isRounded && Config) ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.16)
                                border.width: (Theme && Theme.isRounded) ? 0 : 1
                            }
                        }
                        StyledButton {
                            text: "Сохранить"
                            implicitHeight: 28
                            onClicked: {
                                if (Waybar && ymTokenField.text.trim().length > 0) {
                                    Waybar.saveYmToken(ymTokenField.text.trim())
                                    ymTokenField.text = ""
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledButton {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            isActive: Waybar && Waybar.ymBusy
                            text: (Waybar && Waybar.ymBusy)
                                  ? ("󰑐 Синхронизация... " + Waybar.ymProgress + "%")
                                  : "󰑐 Синхронизировать плейлисты (новые треки)"
                            enabled: !(Waybar && Waybar.ymBusy)
                            onClicked: if (Waybar) Waybar.syncYmPlaylists()
                        }

                        StyledButton {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            text: "󰎆 Скачать пачку из «Моей волны» (20 тр.)"
                            enabled: !(Waybar && Waybar.ymBusy)
                            onClicked: if (Waybar) Waybar.downloadYmMyWave()
                        }

                        StyledButton {
                            visible: Waybar && Waybar.ymBusy
                            text: "󰅖 Стоп"
                            implicitHeight: 30
                            onClicked: if (Waybar) Waybar.stopYmSync()
                        }
                    }

                    Rectangle {
                        visible: Waybar && Waybar.ymBusy
                        Layout.fillWidth: true
                        height: 5
                        radius: 2.5
                        color: Qt.rgba(1, 1, 1, 0.10)
                        clip: true
                        Rectangle {
                            width: parent.width * Math.max(0.05, Math.min(1.0, (Waybar ? Waybar.ymProgress : 0) / 100.0))
                            height: parent.height
                            radius: parent.radius
                            color: Config ? Config.m3Primary : "#69f0ae"
                            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Waybar ? Waybar.ymStatusText : ""
                        color: "#aaaaaa"
                        font.pixelSize: Config.fontSize - 1
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}