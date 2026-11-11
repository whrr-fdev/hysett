import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: netRoot

    Component.onCompleted: if (Network) Network.refresh()

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
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: "󰈀  Сеть и Интернет"
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize + 3
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: Network.scanning ? "󰑐  Поиск..." : "󰑐  Обновить"
                        onClicked: Network.refresh()
                    }
                    StyledButton {
                        text: "󰒓  Редактор соединений"
                        onClicked: Network.openConnectionEditor()
                    }
                }

                // ВЫБОР АКТИВНОГО ПОДКЛЮЧЕНИЯ (ЕСЛИ ПОДКЛЮЧЕНЫ И ТЕЛЕФОН USB, И ПРОВОД)
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: connSelectorCol.implicitHeight + 28

                    ColumnLayout {
                        id: connSelectorCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: (Network && Network.activeConnections.length > 1)
                                    ? "Активные подключения"
                                    : "Текущее подключение к интернету"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: Network && Network.activeConnections.length > 1
                                text: "Кликните для переключения маршрута"
                                color: "#888888"
                                font.pixelSize: Config.fontSize - 2
                            }
                        }

                        // Если нет ни одного подключения
                        Rectangle {
                            visible: !Network || Network.activeConnections.length === 0
                            Layout.fillWidth: true
                            implicitHeight: 58
                            radius: (Theme && Theme.isRounded) ? 10 : 0
                            color: Qt.rgba(1, 0.3, 0.3, 0.10)
                            border.color: "#ff6b6b"; border.width: 1

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 14
                                Text { text: "󰖪"; font.pixelSize: 22; color: "#ff6b6b" }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: "Нет подключения к сети"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }
                                    Text { text: "Подключите кабель Ethernet, USB-модем телефона или Wi-Fi"; color: "#ff8a80"; font.pixelSize: Config.fontSize - 1 }
                                }
                            }
                        }

                        // Список подключенных интерфейсов с плавной плашкой выбора и наведения
                        Item {
                            id: connListWrap
                            visible: Network && Network.activeConnections.length > 0
                            Layout.fillWidth: true
                            implicitHeight: connListCol.implicitHeight
                            property int hoveredIdx: -1
                            property int lastHoveredIdx: 0

                            Timer {
                                id: connHoverHold
                                interval: 45
                                onTriggered: connListWrap.hoveredIdx = -1
                            }

                            Rectangle {
                                z: 1
                                opacity: connListWrap.hoveredIdx >= 0 ? 1.0 : 0.0
                                x: 0
                                y: connListWrap.lastHoveredIdx * 62
                                width: connListWrap.width
                                height: 56
                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.07)
                                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }

                            ColumnLayout {
                                id: connListCol
                                z: 2
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: Network ? Network.activeConnections : []
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 56
                                        radius: (Theme && Theme.isRounded) ? 10 : 0
                                        color: modelData.selected
                                            ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1,1,1,0.14))
                                            : Qt.rgba(1, 1, 1, 0.03)
                                        border.color: modelData.selected ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.14)
                                        border.width: modelData.selected ? 1.5 : 1
                                        Behavior on color { ColorAnimation { duration: 160 } }

                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 12; spacing: 14

                                            Rectangle {
                                                width: 36; height: 36
                                                radius: (Theme && Theme.isRounded) ? 10 : 0
                                                color: modelData.selected ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.icon
                                                    font.pixelSize: 18
                                                    color: modelData.selected ? (Config ? Config.accentTextColor : "#000000") : "#ffffff"
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 2
                                                Text {
                                                    text: modelData.title
                                                    color: "#ffffff"
                                                    font.pixelSize: Config.fontSize + 1
                                                    font.bold: modelData.selected
                                                }
                                                Text {
                                                    text: (modelData.selected ? "󰄬 Основной маршрут интернета  •  " : "Доступно  •  ") + "IPv4: " + modelData.ip
                                                    color: modelData.selected ? "#69f0ae" : "#999999"
                                                    font.pixelSize: Config.fontSize - 1
                                                }
                                            }

                                            StyledButton {
                                                text: modelData.selected ? "󰄬 Выбрано" : "Выбрать"
                                                isActive: modelData.selected
                                                implicitHeight: 26
                                                onClicked: if (Network) Network.selectInterface(modelData.iface)
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: {
                                                connHoverHold.stop()
                                                connListWrap.lastHoveredIdx = index
                                                connListWrap.hoveredIdx = index
                                            }
                                            onExited: connHoverHold.restart()
                                            onClicked: if (Network) Network.selectInterface(modelData.iface)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // КАРТОЧКА УПРАВЛЕНИЯ WI-FI
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: statusCol.implicitHeight + 24

                    ColumnLayout {
                        id: statusCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Text {
                                text: "󰤨  Беспроводная сеть Wi-Fi"
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
                            visible: Network.currentSsid.length > 0
                            Text { text: "Подключенная сеть Wi-Fi:"; color: "#aaaaaa"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 180 }
                            Text {
                                text: Network.currentSsid
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "Отключить Wi-Fi"
                                onClicked: Network.disconnectCurrent()
                            }
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
                    visible: Network.wifiEnabled && Network.networks.length > 0
                    text: "Доступные сети Wi-Fi"
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
                                text: modelData.connected ? "󰤨" : "󰖩"
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
                                    text: "Сигнал: " + modelData.signal + "%  •  " + modelData.security
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
                    text: "Подключение к " + pwModal.targetSsid
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 1
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                TextField {
                    id: pwField
                    placeholderText: "Пароль сети Wi-Fi..."
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
                        text: "Отмена"
                        Layout.fillWidth: true
                        onClicked: { pwModal.opacity = 0.0; pwCard.scale = 0.92 }
                    }
                    StyledButton {
                        text: "Подключить"
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
