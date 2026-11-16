import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: phoneRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool hideUrl: false
    readonly property bool effHide: hideUrl || (Config && Config.streamerMode)

    Component.onCompleted: {
        if (Config) Config.refreshPhoneBridgeState()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshPhoneBridgeState()
    }

    Timer {
        interval: 2200
        repeat: true
        running: phoneRoot.visible && Config && (Config.phoneBridgeRunning || Config.phoneScreenRunning)
        onTriggered: if (Config) Config.refreshPhoneBridgeState()
    }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var p = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                fileInputField.text = p
                if (Config) {
                    Config.addStashedFile(p)
                    Config.shareFileToPhone(p)
                }
            }
        }
    }

    ScrollView {
        id: phScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: phScroll.availableWidth
            implicitHeight: phCol.implicitHeight + 44

            ColumnLayout {
                id: phCol
                width: Math.min(parent.width - 48, 860)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󰄜  Телефон и управление"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledButton {
                        text: phoneRoot.effHide ? "󰈉" : "󰈈"
                        isIconOnly: true
                        implicitWidth: 28
                        isActive: phoneRoot.effHide
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: phoneRoot.hideUrl = !phoneRoot.hideUrl
                    }
                    StyledButton {
                        text: "󰉋 Принятые"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: if (Config) Config.openPhoneDownloadsFolder()
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: if (Config) Config.refreshPhoneBridgeState()
                    }
                }

                // 1. КАРТОЧКА ПРОСМОТРА И УПРАВЛЕНИЯ ЭКРАНОМ ТЕЛЕФОНА (ВСЕГДА 120 FPS)
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: scrCol.implicitHeight + 28

                    ColumnLayout {
                        id: scrCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 9
                                Layout.preferredHeight: 9
                                Layout.alignment: Qt.AlignVCenter
                                radius: 4.5
                                color: (Config && Config.phoneScreenRunning) ? "#69f0ae" : "#888888"
                            }
                            Text {
                                text: "󰄙  Экран телефона • 120 FPS"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledButton {
                                text: "⏻ Экран тел."
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (Config) Config.pressPhonePowerKey()
                            }
                            StyledButton {
                                text: "󰄙 Открыть по USB"
                                isActive: !(Config && Config.phoneScreenRunning)
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (Config) Config.startPhoneScreen("usb", phoneIpField.text, 120, Config.phoneTurnScreenOff)
                            }
                            StyledButton {
                                visible: Config ? Config.phoneScreenRunning : false
                                text: "󰅖 Выключить"
                                isActive: true
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (Config) Config.stopPhoneScreen()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: phoneIpField
                                Layout.fillWidth: true
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 10
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                text: Config ? Config.phoneWirelessIp : ""
                                echoMode: phoneRoot.effHide ? TextInput.Password : TextInput.Normal
                                Connections {
                                    target: Config
                                    function onPhoneBridgeChanged() {
                                        if (!phoneIpField.activeFocus && Config && Config.phoneWirelessIp.length > 0 && phoneIpField.text !== Config.phoneWirelessIp) {
                                            phoneIpField.text = Config.phoneWirelessIp
                                        }
                                    }
                                }
                                onEditingFinished: if (Config) Config.phoneWirelessIp = text.trim()
                                placeholderText: "IP телефона для подключения по Wi-Fi..."
                                placeholderTextColor: "#777777"
                                background: Rectangle {
                                    radius: phoneRoot.isM3 ? 8 : 0
                                    color: phoneRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: phoneRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰖩 Определить IP"
                                onClicked: if (Config) Config.startPhoneScreen("tcpip_init", "", 120, false)
                            }

                            StyledButton {
                                text: "󰄙 По воздуху"
                                isActive: true
                                onClicked: if (Config) Config.startPhoneScreen("wireless", phoneIpField.text.trim(), 120, Config.phoneTurnScreenOff)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Режим управления мышью и клавиатурой:"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            SegmentedButton {
                                Layout.preferredWidth: 310
                                Layout.alignment: Qt.AlignVCenter
                                options: ["Касания (SDK)", "USB-мышь (UHID)", "Прямой (AOA)"]
                                selectedIndex: Config ? Config.phoneMouseMode : 0
                                onSelected: (idx) => { if (Config) Config.phoneMouseMode = idx }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Гасить экран физического телефона при работе с ПК:"
                                color: "#cccccc"
                                font.pixelSize: Config ? Config.fontSize : 11
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledSwitch {
                                Layout.alignment: Qt.AlignVCenter
                                checked: Config ? Config.phoneTurnScreenOff : false
                                onToggled: if (Config) Config.phoneTurnScreenOff = checked
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА ИНТЕРНЕТ-МОСТА И QR-КОДА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: bridgeRow.implicitHeight + 28

                    RowLayout {
                        id: bridgeRow
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 18

                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 140
                            Layout.alignment: Qt.AlignVCenter
                            radius: phoneRoot.isM3 ? 14 : 0
                            color: (!phoneRoot.effHide && Config && Config.phoneBridgeQrPath.length > 0) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Config ? Config.m3Primary : "#ffffff"
                            border.width: 1.5

                            Image {
                                id: qrImg
                                anchors.fill: parent
                                anchors.margins: 6
                                visible: !phoneRoot.effHide && status === Image.Ready && Config && Config.phoneBridgeQrPath.length > 0
                                source: (Config && Config.phoneBridgeQrPath.length > 0) ? ("file://" + Config.phoneBridgeQrPath) : ""
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                smooth: false
                            }

                            Text {
                                visible: !qrImg.visible
                                anchors.centerIn: parent
                                text: phoneRoot.effHide ? "󰈉" : "󰐲"
                                font.pixelSize: 40
                                color: Config ? Config.m3Primary : "#ffffff"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    Layout.preferredWidth: 9
                                    Layout.preferredHeight: 9
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4.5
                                    color: (Config && Config.phoneBridgeRunning) ? "#69f0ae" : "#888888"
                                }
                                Text {
                                    text: (Config && Config.phoneBridgeRunning) ? "Интернет-мост активен" : "Интернет-мост"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Config ? Config.phoneBridgeStatus : ""
                                color: (Config && Config.phoneBridgeRunning) ? Config.m3Primary : "#aaaaaa"
                                font.pixelSize: Config ? Config.fontSize : 11
                            }

                            RowLayout {
                                visible: Config && Config.phoneBridgeUrl.length > 0
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    radius: phoneRoot.isM3 ? 8 : 0
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        text: phoneRoot.effHide ? "https://••••••••••••••••••••••••" : (Config ? Config.phoneBridgeUrl : "")
                                        color: "#ffffff"
                                        font.pixelSize: Config ? Config.fontSize : 11
                                        font.family: "monospace"
                                    }
                                }

                                StyledButton {
                                    text: "󰆏 Копировать"
                                    onClicked: if (Waybar && Config) Waybar.runCommand("printf '%s' '" + Config.phoneBridgeUrl + "' | wl-copy")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                StyledButton {
                                    text: (Config && Config.phoneBridgeRunning) ? "󰅖  Остановить мост" : "󰄜  Запустить мост"
                                    isActive: !(Config && Config.phoneBridgeRunning)
                                    onClicked: if (Config) Config.togglePhoneBridge()
                                }
                            }
                        }
                    }
                }

                // 3. КАРТОЧКА ОТПРАВКИ ТЕКСТА И ФАЙЛОВ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: sendCol.implicitHeight + 28

                    ColumnLayout {
                        id: sendCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰁕  Отправить на телефон"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: textShareField
                                Layout.fillWidth: true
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 10
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                placeholderText: "Текст или ссылка..."
                                placeholderTextColor: "#777777"
                                onAccepted: {
                                    if (text.trim().length > 0 && Config) {
                                        Config.sendTextToPhone(text.trim())
                                        text = ""
                                    }
                                }
                                background: Rectangle {
                                    radius: phoneRoot.isM3 ? 8 : 0
                                    color: phoneRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: phoneRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰅌 Буфер"
                                onClicked: if (Config) Config.sendClipboardToPhone()
                            }

                            StyledButton {
                                text: "󰁕 В мост"
                                isActive: true
                                enabled: textShareField.text.trim().length > 0
                                onClicked: {
                                    if (Config && textShareField.text.trim().length > 0) {
                                        Config.sendTextToPhone(textShareField.text.trim())
                                        textShareField.text = ""
                                    }
                                }
                            }

                            StyledButton {
                                text: "󰅧 Облако"
                                enabled: textShareField.text.trim().length > 0
                                onClicked: {
                                    if (Config && textShareField.text.trim().length > 0) {
                                        Config.quickCloudShare(textShareField.text.trim(), false)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: fileInputField
                                Layout.fillWidth: true
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 10
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                placeholderText: "Путь к файлу или папке..."
                                placeholderTextColor: "#777777"
                                onAccepted: {
                                    if (text.trim().length > 0 && Config) Config.shareFileToPhone(text.trim())
                                }
                                background: Rectangle {
                                    radius: phoneRoot.isM3 ? 8 : 0
                                    color: phoneRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: phoneRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰁕 В мост"
                                isActive: true
                                enabled: fileInputField.text.trim().length > 0
                                onClicked: if (Config) Config.shareFileToPhone(fileInputField.text.trim())
                            }

                            StyledButton {
                                text: "󰅧 Облако"
                                enabled: fileInputField.text.trim().length > 0
                                onClicked: if (Config) Config.quickCloudShare(fileInputField.text.trim(), true)
                            }
                        }

                        // Блок файлов, закинутых в панель задач (с плавной подсветкой наведения)
                        ColumnLayout {
                            visible: Config && Config.stashedFiles.length > 0
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "󰇚"
                                    color: Config ? Config.m3Primary : "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                }
                                Text {
                                    text: "Загружено в панель задач (" + (Config ? Config.stashedFiles.length : 0) + ")"
                                    color: "#cccccc"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                StyledButton {
                                    text: "󰎟 Очистить"
                                    implicitHeight: 22
                                    onClicked: if (Config) Config.clearStashedFiles()
                                }
                            }

                            Item {
                                id: stashPhHoverWrap
                                Layout.fillWidth: true
                                implicitHeight: stashPhCol.implicitHeight
                                property bool isHovering: false
                                property real hovY: 0
                                property real hovH: 36

                                Timer {
                                    id: stashPhHold
                                    interval: 45
                                    onTriggered: stashPhHoverWrap.isHovering = false
                                }

                                Rectangle {
                                    z: 1
                                    opacity: stashPhHoverWrap.isHovering ? 1.0 : 0.0
                                    x: 0; y: stashPhHoverWrap.hovY
                                    width: stashPhHoverWrap.width; height: stashPhHoverWrap.hovH
                                    radius: phoneRoot.isM3 ? 8 : 0
                                    color: phoneRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                           : Qt.rgba(1, 1, 1, 0.10)
                                    Behavior on y { NumberAnimation { duration: 175; easing.type: Easing.OutQuint } }
                                    Behavior on opacity { NumberAnimation { duration: 115 } }
                                }

                                ColumnLayout {
                                    id: stashPhCol
                                    z: 2; width: parent.width; spacing: 5

                                    Repeater {
                                        model: Config ? Config.stashedFiles : []
                                        delegate: Rectangle {
                                            id: stashPhRow
                                            Layout.fillWidth: true
                                            implicitHeight: 36
                                            radius: phoneRoot.isM3 ? 8 : 0
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    stashPhHold.stop()
                                                    stashPhHoverWrap.hovY = stashPhRow.y
                                                    stashPhHoverWrap.hovH = stashPhRow.height
                                                    stashPhHoverWrap.isHovering = true
                                                }
                                                onExited: stashPhHold.restart()
                                                onClicked: fileInputField.text = modelData.path
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Text {
                                                    text: modelData.isDir ? "󰉋" : "󰈔"
                                                    color: Config ? Config.m3Primary : "#a8c7fa"
                                                    font.pixelSize: 14
                                                }

                                                Text {
                                                    text: modelData.name
                                                    color: "#ffffff"
                                                    font.pixelSize: Config ? Config.fontSize : 11
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: modelData.size + " • " + modelData.time
                                                    color: "#888888"
                                                    font.pixelSize: Config ? Config.fontSize - 2 : 9
                                                }

                                                StyledButton {
                                                    text: "󰁕 В мост"
                                                    implicitHeight: 24
                                                    onClicked: if (Config) Config.shareFileToPhone(modelData.path)
                                                }

                                                StyledButton {
                                                    text: "󰅧 Облако"
                                                    implicitHeight: 24
                                                    onClicked: if (Config) Config.quickCloudShare(modelData.path, true)
                                                }

                                                StyledButton {
                                                    text: "󰅖"
                                                    isIconOnly: true
                                                    implicitWidth: 24; implicitHeight: 24
                                                    onClicked: if (Config) Config.removeStashedFile(modelData.path)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. ЛЕНТА ОБМЕНА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: feedCol.implicitHeight + 28

                    ColumnLayout {
                        id: feedCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰋚  Лента обмена (" + (Config ? Config.phoneSharedItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledButton {
                                visible: Config && Config.phoneSharedItems.length > 0
                                text: "󰎟 Очистить"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (Config) Config.clearPhoneItems()
                            }
                        }

                        Text {
                            visible: !Config || Config.phoneSharedItems.length === 0
                            text: "Лента пуста"
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.phoneSharedItems : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: phoneRoot.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Item {
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                        Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.kind === "file" ? "󰈔" : "󰅌"
                                            color: modelData.dir === "phone2pc" ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                            font.pixelSize: 15
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: (phoneRoot.effHide && modelData.kind === "text") ? "••••••••••••••••••••" : modelData.label
                                            color: "#ffffff"
                                            font.pixelSize: Config ? Config.fontSize : 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.dir === "phone2pc" ? "С телефона" : "С ПК") +
                                                  "  •  " + modelData.time +
                                                  (modelData.size && modelData.size.length > 0 ? ("  •  " + modelData.size) : "")
                                            color: "#888888"
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledButton {
                                        visible: modelData.kind === "text"
                                        text: "󰆏 Копировать"
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: if (Waybar) Waybar.runCommand("printf '%s' '" + String(modelData.label).replace(/'/g, "'\\''") + "' | wl-copy")
                                    }

                                    StyledButton {
                                        visible: modelData.kind === "file" && modelData.path && modelData.path.length > 0
                                        text: "󰉋 Открыть"
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: if (Waybar) Waybar.runCommand("xdg-open '" + String(modelData.path).replace(/'/g, "'\\''") + "'")
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
