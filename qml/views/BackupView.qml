import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: backupRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool restoreWithPackages: true

    Component.onCompleted: {
        if (Config) Config.refreshBackupInfo()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshBackupInfo()
    }

    ScrollView {
        id: bakScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: bakScroll.availableWidth
            implicitHeight: bakCol.implicitHeight + 44

            ColumnLayout {
                id: bakCol
                width: Math.min(parent.width - 48, 860)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󰁯  Бэкап системы, конфигов и пакетов"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: "󰉋 Папка бэкапов"
                        onClicked: if (Config) Config.openBackupsFolder()
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        onClicked: if (Config) Config.refreshBackupInfo()
                    }
                }

                // Полоса прогресса активной операции
                GlassPanel {
                    visible: Config ? (Config.sysBusy || Config.sysStatusText.length > 0) : false
                    Layout.fillWidth: true
                    implicitHeight: statusCol.implicitHeight + 20

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: Config ? Config.sysStatusText : ""
                                color: Config && Config.sysBusy ? (Config.m3Primary) : "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                font.bold: Config ? Config.sysBusy : false
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: Config ? Config.sysBusy : false
                                text: (Config ? Config.sysProgress : 0) + "%"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                font.bold: true
                            }
                        }

                        Rectangle {
                            visible: Config ? Config.sysBusy : false
                            Layout.fillWidth: true
                            height: 5
                            radius: 2.5
                            color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * Math.max(0.05, Math.min(1.0, (Config ? Config.sysProgress : 0) / 100.0))
                                height: parent.height
                                radius: 2.5
                                color: Config ? Config.m3Primary : "#69f0ae"
                                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                // 1. КАРТОЧКА ПАКЕТОВ СИСТЕМЫ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: pkgCol.implicitHeight + 28

                    ColumnLayout {
                        id: pkgCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰏖  Установленные пакеты системы (Pacman + AUR)"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        Text {
                            text: "Официальные пакеты (pacman -Qqen): " + (Config ? Config.pkgNativeCount : 0) +
                                  "   •   Пакеты AUR (pacman -Qqem): " + (Config ? Config.pkgAurCount : 0)
                            color: Config ? Config.m3Primary : "#a8c7fa"
                            font.pixelSize: Config ? Config.fontSize : 11
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Генерирует автономный скрипт ~/install_my_packages.sh, который устанавливает все текущие официальные и AUR-пакеты (через paru/yay) одной командой."
                            color: "#aaaaaa"
                            font.pixelSize: Config ? Config.fontSize - 1 : 10
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            StyledButton {
                                text: "󰆓  Создать скрипт установки моих пакетов (install_my_packages.sh)"
                                isActive: true
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.generatePackageScript()
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА СОЗДАНИЯ И СПИСКА АРХИВОВ БЭКАПА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: archCol.implicitHeight + 28

                    ColumnLayout {
                        id: archCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "󰀼  Полный бэкап системы и настроек в архив (.tar.gz)"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                }
                                Text {
                                    text: "Включает конфиги ~/.config/hypr, kitty, btop, gtk, профили HySett и скрипт установки всех пакетов"
                                    color: "#999999"
                                    font.pixelSize: Config ? Config.fontSize - 1 : 10
                                }
                            }
                            StyledButton {
                                text: "󰁯  Создать полный бэкап"
                                isActive: true
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.createFullBackup()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Text {
                            visible: !Config || Config.backupArchives.length === 0
                            text: "Сохранённых архивов пока нет. Нажмите «Создать полный бэкап»."
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.backupArchives : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: backupRoot.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: "󰀼"
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: 16
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.name
                                            color: "#ffffff"
                                            font.pixelSize: Config ? Config.fontSize : 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.date + "   •   " + modelData.size
                                            color: "#888888"
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                        }
                                    }

                                    StyledButton {
                                        text: "󰑐 Конфиги"
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreFromBackup(modelData.path, false)
                                    }

                                    StyledButton {
                                        text: "󰏖 Всё + Пакеты"
                                        isActive: true
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreFromBackup(modelData.path, true)
                                    }

                                    StyledButton {
                                        text: "󰅖"
                                        isIconOnly: true
                                        implicitWidth: 26
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.deleteBackupArchive(modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. ВОССТАНОВЛЕНИЕ ИЗ СВОЕГО АРХИВА (НА НОВОМ ПК)
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: impCol.implicitHeight + 28

                    ColumnLayout {
                        id: impCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰋺  Восстановление из своего архива бэкапа (на новом ПК)"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Укажите путь к перенесённому архиву (.tar.gz / .tar.zst), чтобы автоматически раскатать все конфиги Hyprland/HySett и установить все ваши пакеты."
                            color: "#aaaaaa"
                            font.pixelSize: Config ? Config.fontSize - 1 : 10
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: customArchiveField
                                Layout.fillWidth: true
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 10
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                placeholderText: "~/hysett_system_backup_2026.tar.gz..."
                                placeholderTextColor: "#777777"
                                background: Rectangle {
                                    radius: backupRoot.isM3 ? 8 : 0
                                    color: backupRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: backupRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰁯  Восстановить"
                                isActive: true
                                enabled: (Config ? !Config.sysBusy : true) && customArchiveField.text.trim().length > 0
                                onClicked: if (Config) Config.restoreFromBackup(customArchiveField.text.trim(), backupRoot.restoreWithPackages)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Автоматически установить все пакеты (pacman + AUR) из архива:"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: backupRoot.restoreWithPackages
                                onToggled: backupRoot.restoreWithPackages = checked
                            }
                        }
                    }
                }
            }
        }
    }
}
