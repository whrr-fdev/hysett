import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: backupRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property string selectedArchivePath: ""

    Component.onCompleted: {
        if (Config) Config.refreshBackupInfo()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshBackupInfo()
    }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var p = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                backupRoot.selectedArchivePath = p
                if (Config) Config.addStashedFile(p)
            }
        }
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
                width: Math.min(parent.width - 48, 880)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󰁯  Перенос и восстановление системы на новом ПК"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledButton {
                        text: "󰉋 Папка архивов"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: if (Config) Config.openBackupsFolder()
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: if (Config) Config.refreshBackupInfo()
                    }
                }

                // Полоса прогресса и статуса
                GlassPanel {
                    visible: Config ? (Config.sysBusy || (Config.sysStatusText.length > 0 && Config.sysStatusText !== "Готово к работе")) : false
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
                                color: Config && Config.sysBusy ? Config.m3Primary : "#cccccc"
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

                // 1. КАРТОЧКА РАЗДЕЛЬНОГО РАЗВЕРТЫВАНИЯ НА НОВОМ ПК В 1 КЛИК
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: migCol.implicitHeight + 28

                    ColumnLayout {
                        id: migCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "󰍹  Восстановление и сохранение по разделам (в 1 клик)"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 620 ? 2 : 1
                            columnSpacing: 12
                            rowSpacing: 12

                            // БЛОК А: НАСТРОЙКИ + HYPRLAND + ВСЕ ПАКЕТЫ
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: colSetBox.implicitHeight + 24
                                radius: backupRoot.isM3 ? 12 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1

                                ColumnLayout {
                                    id: colSetBox
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text {
                                            text: "󰒓"
                                            color: Config ? Config.m3Primary : "#a8c7fa"
                                            font.pixelSize: 18
                                        }
                                        Text {
                                            text: "Настройки + Hyprland + Пакеты"
                                            color: "#ffffff"
                                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        text: "Конфиги Hyprland, Kitty, Fish, Btop, GTK, темы курсоров, скрипты HySett и установка Hyprland + всех пакетов (" +
                                              (Config ? Config.pkgNativeCount : 0) + " Pacman + " + (Config ? Config.pkgAurCount : 0) + " AUR)."
                                        color: "#aaaaaa"
                                        font.pixelSize: Config ? Config.fontSize - 1 : 10
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            text: "󰆓 Сохранить настройки"
                                            enabled: Config ? !Config.sysBusy : true
                                            onClicked: if (Config) Config.createTypedBackup("settings")
                                        }

                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            isActive: true
                                            text: "󰑐 Восстановить + Hyprland"
                                            enabled: Config ? !Config.sysBusy : true
                                            onClicked: if (Config) Config.restoreTypedBackup(backupRoot.selectedArchivePath, "settings_pkgs")
                                        }
                                    }
                                }
                            }

                            // БЛОК Б: ЛИЧНЫЕ ДАННЫЕ ОТДЕЛЬНО В 1 КЛИК
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: colDataBox.implicitHeight + 24
                                radius: backupRoot.isM3 ? 12 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(0.41, 0.94, 0.68, 0.35)
                                border.width: 1

                                ColumnLayout {
                                    id: colDataBox
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text {
                                            text: "󰉋"
                                            color: "#69f0ae"
                                            font.pixelSize: 18
                                        }
                                        Text {
                                            text: "Личные данные (отдельно)"
                                            color: "#ffffff"
                                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        text: "Вся скачанная музыка и плейлисты Яндекс.Музыки, коллекция обоев и пресетов, подписки и ключи VPN, шрифты и файлы телефона."
                                        color: "#aaaaaa"
                                        font.pixelSize: Config ? Config.fontSize - 1 : 10
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            text: "󰆓 Сохранить данные"
                                            enabled: Config ? !Config.sysBusy : true
                                            onClicked: if (Config) Config.createTypedBackup("data")
                                        }

                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            isActive: true
                                            text: "󰁯 Восстановить данные"
                                            enabled: Config ? !Config.sysBusy : true
                                            onClicked: if (Config) Config.restoreTypedBackup(backupRoot.selectedArchivePath, "data")
                                        }
                                    }
                                }
                            }
                        }

                        // Нижняя панель действий в 1 клик (Пакеты + Полный архив)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                text: "󰏖 Докачать Hyprland и все пакеты (" + (Config ? (Config.pkgNativeCount + Config.pkgAurCount) : 0) + ")"
                                isActive: true
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.installAllBackupPackages()
                            }

                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                text: "󰆓 Скрипт пакетов (.sh)"
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.generatePackageScript()
                            }

                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                text: "󰀼 Создать полный архив (Всё)"
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.createTypedBackup("full")
                            }
                        }
                    }
                }

                // 2. ВЫБОР ВНЕШНЕГО АРХИВА ИЛИ ИЗ БУФЕРА ПАНЕЛИ ЗАДАЧ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: impCol.implicitHeight + 28

                    ColumnLayout {
                        id: impCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰋺  Восстановление из выбранного файла архива"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
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
                                text: backupRoot.selectedArchivePath
                                onTextEdited: backupRoot.selectedArchivePath = text.trim()
                                placeholderText: "Путь к архиву .tar.gz / .tar.zst (по умолчанию берется последний свежий архив)..."
                                placeholderTextColor: "#777777"
                                background: Rectangle {
                                    radius: backupRoot.isM3 ? 8 : 0
                                    color: backupRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: backupRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰈔 Выбрать архив..."
                                onClicked: {
                                    if (Config) {
                                        var p = Config.pickBackupArchive()
                                        if (p.length > 0) backupRoot.selectedArchivePath = p
                                    }
                                }
                            }

                            StyledButton {
                                text: "󰁯 Восстановить всё"
                                isActive: true
                                enabled: Config ? !Config.sysBusy : true
                                onClicked: if (Config) Config.restoreTypedBackup(backupRoot.selectedArchivePath, "full_all")
                            }
                        }
                    }
                }

                // 3. СПИСОК СОХРАНЕННЫХ АРХИВОВ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: archCol.implicitHeight + 28

                    ColumnLayout {
                        id: archCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: "󰀼  Сохранённые архивы (" + (Config ? Config.backupArchives.length : 0) + ")"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        Text {
                            visible: !Config || Config.backupArchives.length === 0
                            text: "Сохранённых архивов пока нет"
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.backupArchives : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 50
                                radius: backupRoot.isM3 ? 10 : 0
                                color: backupRoot.selectedArchivePath === modelData.path
                                       ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Item {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.kind === "data" ? "󰉋" : (modelData.kind === "settings" ? "󰒓" : "󰀼")
                                            color: modelData.kind === "data" ? "#69f0ae" : (Config ? Config.m3Primary : "#ffffff")
                                            font.pixelSize: 16
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: bTxt.implicitWidth + 10
                                                Layout.preferredHeight: 17
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: backupRoot.isM3 ? 4 : 0
                                                color: modelData.kind === "data"
                                                       ? Qt.rgba(0.41, 0.94, 0.68, 0.18)
                                                       : Qt.rgba(0.66, 0.78, 0.98, 0.18)
                                                Text {
                                                    id: bTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.badge || "ПОЛНЫЙ"
                                                    color: modelData.kind === "data" ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.date + "   •   " + modelData.size
                                            color: "#888888"
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledButton {
                                        visible: modelData.kind !== "data"
                                        text: "󰒓 Конфиги"
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreTypedBackup(modelData.path, "settings_only")
                                    }

                                    StyledButton {
                                        visible: modelData.kind !== "data"
                                        text: "󰏖 Настройки + Пакеты"
                                        isActive: modelData.kind === "settings"
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreTypedBackup(modelData.path, "settings_pkgs")
                                    }

                                    StyledButton {
                                        visible: modelData.kind !== "settings"
                                        text: "󰉋 Данные"
                                        isActive: modelData.kind === "data"
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreTypedBackup(modelData.path, "data")
                                    }

                                    StyledButton {
                                        visible: modelData.kind === "full"
                                        text: "󰁯 Всё"
                                        isActive: true
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.restoreTypedBackup(modelData.path, "full_all")
                                    }

                                    StyledButton {
                                        text: "󰅖"
                                        isIconOnly: true
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: Config ? !Config.sysBusy : true
                                        onClicked: if (Config) Config.deleteBackupArchive(modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
