import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: phoneRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool hideUrl: false

    Component.onCompleted: {
        if (Config) Config.refreshPhoneBridgeState()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshPhoneBridgeState()
    }

    Timer {
        interval: 2500
        repeat: true
        running: phoneRoot.visible && Config && Config.phoneBridgeRunning
        onTriggered: if (Config) Config.refreshPhoneBridgeState()
    }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var p = String(drop.urls[0]).replace(/^file:\/\//, "")
                fileInputField.text = decodeURIComponent(p)
                if (Config) Config.shareFileToPhone(fileInputField.text)
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
                        text: "󰄜  Обмен файлами и текстом с телефоном"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: phoneRoot.hideUrl ? "󰈉 Ссылка скрыта" : "󰈈 Скрыть ссылку"
                        isActive: phoneRoot.hideUrl
                        onClicked: phoneRoot.hideUrl = !phoneRoot.hideUrl
                    }
                    StyledButton {
                        text: "󰉋 Папка принятых"
                        onClicked: if (Config) Config.openPhoneDownloadsFolder()
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        onClicked: if (Config) Config.refreshPhoneBridgeState()
                    }
                }

                // 1. КАРТОЧКА ИНТЕРНЕТ-МОСТА И QR-КОДА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: bridgeRow.implicitHeight + 28

                    RowLayout {
                        id: bridgeRow
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 18

                        // Блок QR-кода
                        Rectangle {
                            Layout.preferredWidth: 144
                            Layout.preferredHeight: 144
                            radius: phoneRoot.isM3 ? 14 : 0
                            color: (!phoneRoot.hideUrl && Config && Config.phoneBridgeQrPath.length > 0) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Config ? Config.m3Primary : "#ffffff"
                            border.width: 1.5

                            Image {
                                id: qrImg
                                anchors.fill: parent
                                anchors.margins: 6
                                visible: !phoneRoot.hideUrl && status === Image.Ready && Config && Config.phoneBridgeQrPath.length > 0
                                source: (Config && Config.phoneBridgeQrPath.length > 0) ? ("file://" + Config.phoneBridgeQrPath) : ""
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                smooth: false
                            }

                            ColumnLayout {
                                visible: !qrImg.visible
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: phoneRoot.hideUrl ? "󰈉" : "󰐲"
                                    font.pixelSize: 38
                                    color: Config ? Config.m3Primary : "#ffffff"
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: phoneRoot.hideUrl ? "QR скрыт" : "QR появится\nпосле старта"
                                    horizontalAlignment: Text.AlignHCenter
                                    color: "#888888"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        // Управление мостом и ссылкой
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 9; height: 9; radius: 4.5
                                    color: (Config && Config.phoneBridgeRunning) ? "#69f0ae" : "#888888"
                                }
                                Text {
                                    text: (Config && Config.phoneBridgeRunning)
                                          ? "Двусторонний интернет-мост активен (ПК ⇄ Телефон)"
                                          : "Двусторонний интернет-мост (без одной Wi-Fi сети)"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Config ? Config.phoneBridgeStatus : ""
                                color: (Config && Config.phoneBridgeRunning) ? (Config.m3Primary) : "#aaaaaa"
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
                                        text: phoneRoot.hideUrl ? "https://••••••••••••••••••••••••" : (Config ? Config.phoneBridgeUrl : "")
                                        color: "#ffffff"
                                        font.pixelSize: Config ? Config.fontSize : 11
                                        font.family: "monospace"
                                    }
                                }

                                StyledButton {
                                    text: "󰆏 Копировать URL"
                                    onClicked: if (Waybar && Config) Waybar.runCommand("printf '%s' '" + Config.phoneBridgeUrl + "' | wl-copy")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                StyledButton {
                                    text: (Config && Config.phoneBridgeRunning)
                                          ? "󰅖  Остановить интернет-мост"
                                          : "󰄜  Запустить интернет-мост (QR)"
                                    isActive: !(Config && Config.phoneBridgeRunning)
                                    onClicked: if (Config) Config.togglePhoneBridge()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: "Работает через 4G/LTE и любую сеть без установки приложений"
                                    color: "#777777"
                                    font.pixelSize: Config ? Config.fontSize - 2 : 9
                                }
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА ОТПРАВКИ ТЕКСТА И ФАЙЛОВ НА ТЕЛЕФОН
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: sendCol.implicitHeight + 28

                    ColumnLayout {
                        id: sendCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "ddd  Отправить текст или файл с ПК на телефон"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        // Отправка текста
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
                                placeholderText: "Введите текст, ссылку или заметку для отправки на телефон..."
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
                                text: "󰅌 Из буфера ПК"
                                onClicked: if (Config) Config.sendClipboardToPhone()
                            }

                            StyledButton {
                                text: "ddd В мост"
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
                                text: "󰅧 Облако + QR"
                                enabled: textShareField.text.trim().length > 0
                                onClicked: {
                                    if (Config && textShareField.text.trim().length > 0) {
                                        Config.quickCloudShare(textShareField.text.trim(), false)
                                    }
                                }
                            }
                        }

                        // Отправка файла
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
                                placeholderText: "Путь к файлу (или перетащите файл мышкой прямо в это окно)..."
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
                                text: "ddd Расшарить в мост"
                                isActive: true
                                enabled: fileInputField.text.trim().length > 0
                                onClicked: if (Config) Config.shareFileToPhone(fileInputField.text.trim())
                            }

                            StyledButton {
                                text: "󰅧 Файл в облако + QR"
                                enabled: fileInputField.text.trim().length > 0
                                onClicked: if (Config) Config.quickCloudShare(fileInputField.text.trim(), true)
                            }
                        }
                    }
                }

                // 3. ЛЕНТА ОБМЕНА (ПК ⇄ ТЕЛЕФОН)
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
                                text: "󰋚  Лента переданных файлов и текста (" + (Config ? Config.phoneSharedItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                visible: Config && Config.phoneSharedItems.length > 0
                                text: "󰎟 Очистить ленту"
                                onClicked: if (Config) Config.clearPhoneItems()
                            }
                        }

                        Text {
                            visible: !Config || Config.phoneSharedItems.length === 0
                            text: "Лента обмена пуста. Отправьте текст/файл выше или загрузите их со смартфона по QR-коду."
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.phoneSharedItems : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 44
                                radius: phoneRoot.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: modelData.kind === "file" ? "󰈔" : "󰅌"
                                        color: modelData.dir === "phone2pc" ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                        font.pixelSize: 15
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.label
                                            color: "#ffffff"
                                            font.pixelSize: Config ? Config.fontSize : 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: (modelData.dir === "phone2pc" ? "📱 С телефона на ПК" : "💻 С ПК на телефон") +
                                                  "  •  " + modelData.time +
                                                  (modelData.size && modelData.size.length > 0 ? ("  •  " + modelData.size) : "")
                                            color: "#888888"
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                        }
                                    }

                                    StyledButton {
                                        visible: modelData.kind === "text"
                                        text: "󰆏 Копировать"
                                        onClicked: if (Waybar) Waybar.runCommand("printf '%s' \"" + String(modelData.label).replace(/"/g, '\\"') + "\" | wl-copy")
                                    }

                                    StyledButton {
                                        visible: modelData.kind === "file" && modelData.path && modelData.path.length > 0
                                        text: "󰉋 Открыть"
                                        onClicked: if (Waybar) Waybar.runCommand("xdg-open \"" + modelData.path + "\"")
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
