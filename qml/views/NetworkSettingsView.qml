import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: netRoot

    ScrollView {
        id: netScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: netScroll.availableWidth
            implicitHeight: netCol.implicitHeight + 40

            ColumnLayout {
                id: netCol
                width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: Config ? (Config.language, Config.trAuto("Сеть и Wi-Fi")) : "Сеть и Wi-Fi"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 3
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: Network.scanning ? "⏳ Поиск..." : "↺  Обновить"
                        onClicked: Network.refresh()
                    }
                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("⚙  Редактор соединений")) : "⚙  Редактор соединений"
                        onClicked: Network.openConnectionEditor()
                    }
                }

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: statusCol.implicitHeight + 20

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Text {
                                text: Config ? (Config.language, Config.trAuto("Беспроводная сеть (Wi-Fi)")) : "Беспроводная сеть (Wi-Fi)"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: Network.wifiEnabled
                                onToggled: Network.wifiEnabled = checked
                            }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Активное подключение:")) : "Активное подключение:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                            Text {
                                text: Network.currentSsid.length > 0 ? Network.currentSsid : "Не подключено"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                visible: Network.currentSsid.length > 0
                                text: Config ? (Config.language, Config.trAuto("Отключить")) : "Отключить"
                                onClicked: Network.disconnectCurrent()
                            }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("IPv4 адрес:")) : "IPv4 адрес:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                            Text { text: Network.ipAddress; color: "#cccccc"; font.pixelSize: Config.fontSize }
                        }

                        Text {
                            visible: Network.statusMessage.length > 0
                            text: Network.statusMessage
                            color: "#aaaaaa"
                            font.pixelSize: Config.fontSize - 1
                        }
                    }
                }

                Text {
                    visible: Network.wifiEnabled
                    text: Config ? (Config.language, Config.trAuto("Доступные сети Wi-Fi")) : "Доступные сети Wi-Fi"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    font.bold: true
                    Layout.topMargin: 4
                }

                Repeater {
                    model: Network.networks

                    GlassPanel {
                        objectName: "atmoObstacle"
                        Layout.fillWidth: true
                        implicitHeight: 44

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: modelData.connected ? "✓" : "󰖩"
                                color: modelData.connected ? "#ffffff" : "#888888"
                                font.pixelSize: 14
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.ssid
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                }
                                Text {
                                    text: Config ? (Config.language, Config.trAuto("Сигнал: ")) : "Сигнал: " + modelData.signal + "%  •  " + modelData.security
                                    color: "#777777"
                                    font.pixelSize: Config.fontSize - 2
                                }
                            }

                            StyledButton {
                                text: modelData.connected ? "Отключить" : "Подключить"
                                onClicked: {
                                    if (modelData.connected) {
                                        Network.disconnectCurrent()
                                    } else if (modelData.secured) {
                                        pwModal.targetSsid = modelData.ssid
                                        pwField.text = ""
                                        pwModal.opacity = 1.0
                                        pwCard.scale = 1.0
                                        pwField.forceActiveFocus()
                                    } else {
                                        Network.connectToWifi(modelData.ssid, "")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Модальное окно ввода пароля Wi-Fi в стиле основного окна
    Item {
        id: pwModal
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0.0
        property string targetSsid: ""

        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            anchors.fill: parent
            radius: (Theme && Theme.isRounded) ? 10 : 0
            color: Qt.rgba(0, 0, 0, 0.65)
            MouseArea { anchors.fill: parent; onClicked: { pwModal.opacity = 0.0; pwCard.scale = 0.92 } }
        }

        Rectangle {
            id: pwCard
            anchors.centerIn: parent
            width: 340
            implicitHeight: pwCol.implicitHeight + 28
            scale: 0.92
            radius: (Theme && Theme.isRounded) ? 10 : 0
            color: Qt.rgba(0.04, 0.04, 0.04, Math.max(0.90, Config.opacity))
            border.color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            ColumnLayout {
                id: pwCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Text {
                    text: Config ? (Config.language, Config.trAuto("Подключение к ")) : "Подключение к " + pwModal.targetSsid
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                TextField {
                    id: pwField
                    placeholderText: Config ? (Config.language, Config.trAuto("Пароль сети Wi-Fi...")) : "Пароль сети Wi-Fi..."
                    echoMode: TextInput.Password
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize
                    implicitHeight: 26
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: Qt.rgba(1, 1, 1, 0.07)
                        radius: (Theme && Theme.isRounded) ? 4 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                    }
                    onAccepted: {
                        Network.connectToWifi(pwModal.targetSsid, pwField.text)
                        pwModal.opacity = 0.0
                    }
                }

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("Отмена")) : "Отмена"
                        Layout.fillWidth: true
                        onClicked: { pwModal.opacity = 0.0; pwCard.scale = 0.92 }
                    }
                    StyledButton {
                        text: Config ? (Config.language, Config.trAuto("Подключить")) : "Подключить"
                        Layout.fillWidth: true
                        onClicked: {
                            Network.connectToWifi(pwModal.targetSsid, pwField.text)
                            pwModal.opacity = 0.0
                            pwCard.scale = 0.92
                        }
                    }
                }
            }
        }
    }
}
