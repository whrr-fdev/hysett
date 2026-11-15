import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: bootRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool showLegacyDrives: false

    function isLegacyDummy(title) {
        var t = String(title || "").toLowerCase().trim()
        return t === "hard drive" || t === "cd/dvd drive" || t === "usb hdd" || t === "usb fdd" || t === "network" || t === "uefi: built-in efi shell"
    }

    readonly property var visibleEfiEntries: {
        var raw = Config ? Config.bootloaderEfiEntries : []
        var out = []
        for (var i = 0; i < raw.length; ++i) {
            if (bootRoot.showLegacyDrives || !bootRoot.isLegacyDummy(raw[i].title)) {
                out.push(raw[i])
            }
        }
        return out
    }

    Component.onCompleted: {
        if (Config) Config.refreshBootloaderState()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshBootloaderState()
    }

    ScrollView {
        id: bootScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: bootScroll.availableWidth
            implicitHeight: bootCol.implicitHeight + 44

            ColumnLayout {
                id: bootCol
                width: Math.min(parent.width - 48, 860)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󰍛  Загрузчик системы и автовыбор ОС"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        onClicked: if (Config) Config.refreshBootloaderState()
                    }
                }

                // 1. КАРТОЧКА ПАРАМЕТРОВ ВРЕМЕНИ И АВТОВЫБОРА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: cfgCol.implicitHeight + 28

                    ColumnLayout {
                        id: cfgCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 9; height: 9; radius: 4.5
                                color: "#69f0ae"
                            }
                            Text {
                                text: Config ? Config.bootloaderStatus : "Загрузчик"
                                color: Config ? Config.m3Primary : "#a8c7fa"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Время ожидания перед автовыбором:"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.preferredWidth: 250
                            }
                            StyledSlider {
                                id: toSlider
                                Layout.fillWidth: true
                                from: 0; to: 30; stepSize: 1
                                value: Config ? Config.bootloaderTimeout : 5
                                onPressedChanged: if (!pressed && Config) Config.applyBootloaderSettings(Math.round(value), Config.bootloaderSavedDefault, Config.bootloaderEditor)
                            }
                            Text {
                                text: Math.round(toSlider.value) === 0 ? "0 сек (Сразу)" : (Math.round(toSlider.value) + " сек")
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                font.bold: true
                                Layout.preferredWidth: 92
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Запоминать последнюю выбранную вручную ОС (@saved):"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: Config ? Config.bootloaderSavedDefault : false
                                onToggled: if (Config) Config.applyBootloaderSettings(Config.bootloaderTimeout, checked, Config.bootloaderEditor)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Открыть настройки BIOS / UEFI при следующей обычной перезагрузке:"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: Config ? Config.bootloaderFwNext : false
                                onToggled: if (Config) Config.setFirmwareNextBoot(checked)
                            }
                        }

                        RowLayout {
                            visible: !Config || Config.bootloaderType === "systemd-boot"
                            Layout.fillWidth: true
                            Text {
                                text: "Разрешить редактирование параметров ядра в меню загрузки (клавиша E):"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: Config ? Config.bootloaderEditor : true
                                onToggled: if (Config) Config.applyBootloaderSettings(Config.bootloaderTimeout, Config.bootloaderSavedDefault, checked)
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА ВЫБОРА ЗАГРУЖАЕМОЙ ПО УМОЛЧАНИЮ ОС / ЯДРА
                GlassPanel {
                    visible: Config && Config.bootloaderEntries.length > 0
                    Layout.fillWidth: true
                    implicitHeight: entriesCol.implicitHeight + 28

                    ColumnLayout {
                        id: entriesCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                            text: "󰌽  Загрузочные записи • Кто загружается автоматически (" + (Config ? Config.bootloaderEntries.length : 0) + ")"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        Item {
                            id: entriesListBox
                            Layout.fillWidth: true
                            implicitHeight: entriesInnerCol.implicitHeight
                            property bool isHovering: false
                            property real hovY: 0
                            property real hovH: 48

                            Timer {
                                id: entriesHoverHold
                                interval: 45
                                onTriggered: entriesListBox.isHovering = false
                            }

                            Rectangle {
                                z: 1
                                opacity: entriesListBox.isHovering ? 1.0 : 0.0
                                x: 0
                                y: entriesListBox.hovY
                                width: entriesListBox.width
                                height: entriesListBox.hovH
                                radius: bootRoot.isM3 ? 10 : 0
                                color: bootRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                border.color: bootRoot.isM3 && Config
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.42)
                                              : Qt.rgba(1, 1, 1, 0.24)
                                Behavior on y { NumberAnimation { duration: 185; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            ColumnLayout {
                                id: entriesInnerCol
                                z: 2
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: Config ? Config.bootloaderEntries : []
                                    delegate: Rectangle {
                                        id: entryRowRect
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        radius: bootRoot.isM3 ? 10 : 0
                                        color: modelData.is_default
                                               ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.16)
                                               : Qt.rgba(1, 1, 1, 0.04)
                                        border.color: modelData.is_default
                                                      ? (Config ? Config.m3Primary : "#a8c7fa")
                                                      : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: {
                                                entriesHoverHold.stop()
                                                entriesListBox.hovY = entryRowRect.y
                                                entriesListBox.hovH = entryRowRect.height
                                                entriesListBox.isHovering = true
                                            }
                                            onExited: entriesHoverHold.restart()
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text {
                                                text: String(modelData.title).toLowerCase().indexOf("windows") !== -1 ? "󰍲" : "󰌽"
                                                color: modelData.is_default ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                font.pixelSize: 17
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                RowLayout {
                                                    spacing: 6
                                                    Rectangle {
                                                        visible: modelData.is_default === true
                                                        width: defBadge.implicitWidth + 10
                                                        height: 17
                                                        radius: 4
                                                        color: Qt.rgba(0.4, 0.95, 0.68, 0.18)
                                                        Text {
                                                            id: defBadge
                                                            anchors.centerIn: parent
                                                            text: "󰄬 АВТОЗАГРУЗКА"
                                                            color: "#69f0ae"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                        }
                                                    }
                                                    Rectangle {
                                                        visible: modelData.is_booted === true
                                                        width: curBadge.implicitWidth + 10
                                                        height: 17
                                                        radius: 4
                                                        color: Qt.rgba(1, 1, 1, 0.14)
                                                        Text {
                                                            id: curBadge
                                                            anchors.centerIn: parent
                                                            text: "АКТИВНА"
                                                            color: "#ffffff"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                        }
                                                    }
                                                    Text {
                                                        text: modelData.title
                                                        color: "#ffffff"
                                                        font.pixelSize: Config ? Config.fontSize : 11
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                                Text {
                                                    text: (modelData.version && modelData.version.length > 0 ? ("Ядро / Версия: " + modelData.version + "  •  ") : "") + "ID: " + modelData.id
                                                    color: "#888888"
                                                    font.pixelSize: Config ? Config.fontSize - 2 : 9
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            StyledButton {
                                                visible: !modelData.is_default
                                                text: "󰄬 По умолчанию"
                                                implicitHeight: 24
                                                onClicked: if (Config) Config.setDefaultBootEntry(modelData.id)
                                            }

                                            StyledButton {
                                                text: "󰇚 На 1 раз"
                                                implicitHeight: 24
                                                onClicked: if (Config) Config.bootEntryOneshot(modelData.id, false)
                                            }

                                            StyledButton {
                                                text: "󰜉 Перезагрузить в неё"
                                                implicitHeight: 24
                                                isActive: modelData.is_default
                                                onClicked: if (Config) Config.bootEntryOneshot(modelData.id, true)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. КАРТОЧКА ПОРЯДКА ЗАГРУЗКИ BIOS / UEFI + КНОПКА ПЕРЕЗАГРУЗКИ В BIOS ВНИЗУ
                GlassPanel {
                    visible: Config && Config.bootloaderEfiEntries.length > 0
                    Layout.fillWidth: true
                    implicitHeight: efiCol.implicitHeight + 28

                    ColumnLayout {
                        id: efiCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰍛  Порядок загрузки BIOS / UEFI (" + bootRoot.visibleEfiEntries.length + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: bootRoot.showLegacyDrives ? "󰈉 Скрыть пустые диски" : "󰈈 Показать все"
                                implicitHeight: 22
                                onClicked: bootRoot.showLegacyDrives = !bootRoot.showLegacyDrives
                            }
                        }

                        Item {
                            id: efiListBox
                            Layout.fillWidth: true
                            implicitHeight: efiInnerCol.implicitHeight
                            property bool isHovering: false
                            property real hovY: 0
                            property real hovH: 44

                            Timer {
                                id: efiHoverHold
                                interval: 45
                                onTriggered: efiListBox.isHovering = false
                            }

                            Rectangle {
                                z: 1
                                opacity: efiListBox.isHovering ? 1.0 : 0.0
                                x: 0
                                y: efiListBox.hovY
                                width: efiListBox.width
                                height: efiListBox.hovH
                                radius: bootRoot.isM3 ? 10 : 0
                                color: bootRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                border.color: bootRoot.isM3 && Config
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.42)
                                              : Qt.rgba(1, 1, 1, 0.24)
                                Behavior on y { NumberAnimation { duration: 185; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            ColumnLayout {
                                id: efiInnerCol
                                z: 2
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: bootRoot.visibleEfiEntries
                                    delegate: Rectangle {
                                        id: efiRowRect
                                        Layout.fillWidth: true
                                        implicitHeight: 44
                                        height: 44
                                        radius: bootRoot.isM3 ? 10 : 0
                                        color: modelData.is_first
                                               ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.12)
                                               : Qt.rgba(1, 1, 1, 0.04)
                                        border.color: modelData.is_first ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: {
                                                efiHoverHold.stop()
                                                efiListBox.hovY = efiRowRect.y
                                                efiListBox.hovH = efiRowRect.height
                                                efiListBox.isHovering = true
                                            }
                                            onExited: efiHoverHold.restart()
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text {
                                                text: String(modelData.title).toLowerCase().indexOf("windows") !== -1 ? "󰍲" : "󰌽"
                                                color: modelData.is_first ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                font.pixelSize: 16
                                            }

                                            Text {
                                                text: "Boot" + modelData.num
                                                color: modelData.is_first ? "#69f0ae" : "#aaaaaa"
                                                font.family: "monospace"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: true
                                            }

                                            Text {
                                                text: modelData.title
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: modelData.is_first
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                visible: modelData.is_first === true
                                                width: efiDefTxt.implicitWidth + 10
                                                height: 18
                                                radius: 4
                                                color: Qt.rgba(0.4, 0.95, 0.68, 0.18)
                                                Text {
                                                    id: efiDefTxt
                                                    anchors.centerIn: parent
                                                    text: "󰄬 АВТОЗАГРУЗКА"
                                                    color: "#69f0ae"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }

                                            StyledButton {
                                                visible: !modelData.is_first
                                                text: "󰁝 На 1-е место"
                                                implicitHeight: 24
                                                onClicked: if (Config) Config.setEfiBootFirst(modelData.num)
                                            }

                                            StyledButton {
                                                text: "󰜉 Загрузить сейчас"
                                                implicitHeight: 24
                                                isActive: modelData.is_first
                                                onClicked: if (Config) Config.bootEfiNext(modelData.num, true)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                        StyledButton {
                            Layout.fillWidth: true
                            allowFullWidth: true
                            implicitHeight: 32
                            isActive: true
                            text: "󰍛  Перезагрузиться в BIOS"
                            onClicked: if (Config) Config.rebootToFirmware()
                        }
                    }
                }
            }
        }
    }
}
