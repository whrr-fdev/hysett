import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: webRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool hideUrl: false
    readonly property bool effHide: hideUrl || (Config && Config.streamerMode)
    property bool showHtmlEditor: false

    Component.onCompleted: {
        if (Config) Config.refreshWebShareState()
    }
    onVisibleChanged: {
        if (visible && Config) Config.refreshWebShareState()
    }

    Timer {
        interval: 2200
        repeat: true
        running: webRoot.visible && Config && Config.webShareRunning
        onTriggered: if (Config) Config.refreshWebShareState()
    }

    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                var p = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                pathField.text = p
                if (Config) Config.hostPathForFriend(p)
            }
        }
    }

    ScrollView {
        id: webScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: webScroll.availableWidth
            implicitHeight: webCol.implicitHeight + 44

            ColumnLayout {
                id: webCol
                width: Math.min(parent.width - 48, 860)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "󰖟  Хостинг сайтов (.html) и раздача файлов другу"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: webRoot.effHide ? "󰈉" : "󰈈"
                        isIconOnly: true
                        implicitWidth: 28
                        isActive: webRoot.effHide
                        onClicked: webRoot.hideUrl = !webRoot.hideUrl
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        onClicked: if (Config) Config.refreshWebShareState()
                    }
                }

                // 1. КАРТОЧКА ПУБЛИЧНОЙ ССЫЛКИ И ТУННЕЛЯ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: srvRow.implicitHeight + 28

                    RowLayout {
                        id: srvRow
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 18

                        Rectangle {
                            Layout.preferredWidth: 136
                            Layout.preferredHeight: 136
                            radius: webRoot.isM3 ? 14 : 0
                            color: (!webRoot.effHide && Config && Config.webShareQrPath.length > 0) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Config ? Config.m3Primary : "#ffffff"
                            border.width: 1.5

                            Image {
                                id: webQrImg
                                anchors.fill: parent
                                anchors.margins: 6
                                visible: !webRoot.effHide && status === Image.Ready && Config && Config.webShareQrPath.length > 0
                                source: (Config && Config.webShareQrPath.length > 0) ? ("file://" + Config.webShareQrPath) : ""
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                smooth: false
                            }

                            Text {
                                visible: !webQrImg.visible
                                anchors.centerIn: parent
                                text: webRoot.effHide ? "󰈉" : "󰖟"
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
                                    width: 9; height: 9; radius: 4.5
                                    color: (Config && Config.webShareRunning) ? "#69f0ae" : "#888888"
                                }
                                Text {
                                    text: (Config && Config.webShareRunning)
                                          ? ("Сервер активен • На главной: " + (Config.webShareActiveTitle.length > 0 ? Config.webShareActiveTitle : "Лента файлов"))
                                          : "Публичный веб-сервер выключен"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Config ? Config.webShareStatus : ""
                                color: (Config && Config.webShareRunning) ? Config.m3Primary : "#aaaaaa"
                                font.pixelSize: Config ? Config.fontSize : 11
                            }

                            RowLayout {
                                visible: Config && Config.webShareUrl.length > 0
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    radius: webRoot.isM3 ? 8 : 0
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        text: webRoot.effHide ? "https://••••••••••••••••••••••••" : (Config ? Config.webShareUrl : "")
                                        color: "#ffffff"
                                        font.pixelSize: Config ? Config.fontSize : 11
                                        font.family: "monospace"
                                    }
                                }

                                StyledButton {
                                    text: "󰆏 Копировать"
                                    onClicked: if (Waybar && Config) Waybar.runCommand("printf '%s' '" + Config.webShareUrl + "' | wl-copy")
                                }

                                StyledButton {
                                    text: "󰖟 Открыть"
                                    onClicked: if (Waybar && Config) Waybar.runCommand("xdg-open '" + Config.webShareUrl + "'")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                StyledButton {
                                    text: (Config && Config.webShareRunning) ? "󰅖  Остановить раздачу" : "󰖟  Запустить сервер"
                                    isActive: !(Config && Config.webShareRunning)
                                    onClicked: if (Config) Config.toggleWebShare()
                                }
                                StyledButton {
                                    text: webRoot.showHtmlEditor ? "󰌝  Скрыть HTML-редактор" : "󰌝  Создать сайт из HTML-кода"
                                    isActive: webRoot.showHtmlEditor
                                    onClicked: webRoot.showHtmlEditor = !webRoot.showHtmlEditor
                                }
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА ЗАГРУЗКИ САЙТА (.HTML / ПАПКА / ZIP) ИЛИ ФАЙЛА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: addCol.implicitHeight + 28

                    ColumnLayout {
                        id: addCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰇚  Загрузить сайт (.html / папку / .zip) или любой файл (можно перетащить сюда мышкой)"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 1 : 12
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: pathField
                                Layout.fillWidth: true
                                implicitHeight: 28
                                leftPadding: 10; rightPadding: 10
                                echoMode: webRoot.effHide ? TextInput.Password : TextInput.Normal
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize : 11
                                placeholderText: "Путь к .html файлу, папке с сайтом или любому файлу..."
                                placeholderTextColor: "#777777"
                                onAccepted: {
                                    if (text.trim().length > 0 && Config) Config.hostPathForFriend(text.trim())
                                }
                                background: Rectangle {
                                    radius: webRoot.isM3 ? 8 : 0
                                    color: webRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Qt.rgba(1, 1, 1, 0.16)
                                    border.width: webRoot.isM3 ? 0 : 1
                                }
                            }

                            StyledButton {
                                text: "󰈔 Файл..."
                                onClicked: if (Config) Config.pickFileForWebShare(false)
                            }

                            StyledButton {
                                text: "󰉋 Папка сайта..."
                                onClicked: if (Config) Config.pickFileForWebShare(true)
                            }

                            StyledButton {
                                text: "󰖟 Локально"
                                isActive: true
                                enabled: pathField.text.trim().length > 0
                                onClicked: if (Config && pathField.text.trim().length > 0) Config.hostPathForFriend(pathField.text.trim())
                            }

                            StyledButton {
                                text: "󰅧 Автономно 24/7"
                                isActive: true
                                enabled: pathField.text.trim().length > 0
                                onClicked: if (Config && pathField.text.trim().length > 0) Config.cloudHostPathForFriend(pathField.text.trim())
                            }
                        }

                        ColumnLayout {
                            visible: webRoot.showHtmlEditor
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                TextField {
                                    id: htmlTitleField
                                    Layout.preferredWidth: 220
                                    implicitHeight: 28
                                    leftPadding: 10; rightPadding: 10
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    placeholderText: "Название (например site.html)"
                                    placeholderTextColor: "#777777"
                                    background: Rectangle {
                                        radius: webRoot.isM3 ? 8 : 0
                                        color: webRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: Qt.rgba(1, 1, 1, 0.16)
                                        border.width: webRoot.isM3 ? 0 : 1
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                StyledButton {
                                    text: "󰖟 Локальный сайт"
                                    isActive: true
                                    enabled: htmlCodeArea.text.trim().length > 0
                                    onClicked: {
                                        if (Config && htmlCodeArea.text.trim().length > 0) {
                                            Config.hostHtmlCodeForFriend(htmlCodeArea.text, htmlTitleField.text)
                                            webRoot.showHtmlEditor = false
                                        }
                                    }
                                }
                                StyledButton {
                                    text: "󰅧 Автономный сайт 24/7"
                                    isActive: true
                                    enabled: htmlCodeArea.text.trim().length > 0
                                    onClicked: {
                                        if (Config && htmlCodeArea.text.trim().length > 0) {
                                            Config.cloudHostHtmlForFriend(htmlCodeArea.text, htmlTitleField.text)
                                            webRoot.showHtmlEditor = false
                                        }
                                    }
                                }
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 130
                                clip: true
                                TextArea {
                                    id: htmlCodeArea
                                    color: "#ffffff"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    placeholderText: "<!DOCTYPE html>\n<html>\n<body>\n  <h1>Привет!</h1>\n</body>\n</html>"
                                    placeholderTextColor: "#666666"
                                    background: Rectangle {
                                        radius: webRoot.isM3 ? 8 : 0
                                        color: Qt.rgba(0, 0, 0, 0.28)
                                        border.color: Qt.rgba(1, 1, 1, 0.14)
                                        border.width: 1
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. АВТОНОМНЫЕ ССЫЛКИ 24/7 (РАБОТАЮТ ПРИ ВЫКЛЮЧЕННОМ ПК)
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: cloudListCol.implicitHeight + 28

                    ColumnLayout {
                        id: cloudListCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰅧  Автономные сайты и файлы 24/7 • Работают при выкл. ПК (" + (Config ? Config.webShareCloudItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: !Config || Config.webShareCloudItems.length === 0
                            text: "Нажмите «󰅧 Автономно 24/7» выше, чтобы выложить сайт или файл, который будет открываться даже когда ваш ПК выключен."
                            color: "#777777"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.webShareCloudItems : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                radius: webRoot.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(0.41, 0.94, 0.68, 0.28)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: modelData.kind === "site" ? "󰖟" : "󰅧"
                                        color: "#69f0ae"
                                        font.pixelSize: 16
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        RowLayout {
                                            spacing: 6
                                            Rectangle {
                                                width: cBadgeTxt.implicitWidth + 10
                                                height: 17
                                                radius: 4
                                                color: Qt.rgba(0.4, 0.95, 0.68, 0.18)
                                                Text {
                                                    id: cBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.kind === "site" ? "24/7 САЙТ" : "24/7 ФАЙЛ"
                                                    color: "#69f0ae"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }
                                            Text {
                                                text: modelData.label
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Text {
                                            text: (webRoot.effHide ? "https://••••••••••••••••••••••••" : modelData.url) + "  •  " + modelData.size + "  •  " + modelData.time
                                            color: "#999999"
                                            elide: Text.ElideMiddle
                                            Layout.fillWidth: true
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                        }
                                    }

                                    StyledButton {
                                        text: "󰐲 QR"
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.selectCloudShareQr(modelData.id)
                                    }

                                    StyledButton {
                                        text: "󰆏 Ссылка"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.runCommand("printf '%s' '" + modelData.url + "' | wl-copy")
                                    }

                                    StyledButton {
                                        text: "󰖟 Открыть"
                                        implicitHeight: 24
                                        onClicked: if (Waybar) Waybar.runCommand("xdg-open '" + modelData.url + "'")
                                    }

                                    StyledButton {
                                        text: "󰅖"
                                        isIconOnly: true
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.removeCloudShareItem(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. ОПУБЛИКОВАННЫЕ САЙТЫ И ФАЙЛЫ
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: listCol.implicitHeight + 28

                    ColumnLayout {
                        id: listCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰋚  Опубликованные сайты и файлы (" + (Config ? Config.webShareItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                visible: Config && Config.webShareItems.length > 0
                                text: "󰎟 Очистить"
                                onClicked: if (Config) Config.clearWebShareItems()
                            }
                        }

                        Text {
                            visible: !Config || Config.webShareItems.length === 0
                            text: "Перетащите сюда .html файл сайта или любой файл — появится ссылка для друга."
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Repeater {
                            model: Config ? Config.webShareItems : []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: webRoot.isM3 ? 10 : 0
                                color: modelData.is_primary ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: modelData.is_primary ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: modelData.kind === "site" ? "󰖟" : "󰈔"
                                        color: modelData.kind === "site" ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                        font.pixelSize: 16
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        RowLayout {
                                            spacing: 6
                                            Rectangle {
                                                width: kindBadgeTxt.implicitWidth + 10
                                                height: 17
                                                radius: 4
                                                color: modelData.kind === "site" ? Qt.rgba(0.4, 0.95, 0.68, 0.18) : Qt.rgba(1, 1, 1, 0.12)
                                                Text {
                                                    id: kindBadgeTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.kind === "site" ? "САЙТ" : "ФАЙЛ"
                                                    color: modelData.kind === "site" ? "#69f0ae" : "#dddddd"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                }
                                            }
                                            Text {
                                                text: modelData.label
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Text {
                                            text: (modelData.is_primary ? "★ Открывается по главной ссылке  •  " : "") + modelData.size + "  •  " + modelData.time
                                            color: modelData.is_primary ? (Config ? Config.m3Primary : "#a8c7fa") : "#888888"
                                            font.pixelSize: Config ? Config.fontSize - 2 : 9
                                        }
                                    }

                                    StyledButton {
                                        visible: !modelData.is_primary
                                        text: "На главную"
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.setPrimaryWebShareItem(modelData.id)
                                    }

                                    StyledButton {
                                        text: "󰆏 Ссылка"
                                        implicitHeight: 24
                                        onClicked: {
                                            if (Waybar && Config && Config.webShareUrl.length > 0) {
                                                var base = Config.webShareUrl.replace(/\/$/, "")
                                                var direct = modelData.is_primary ? base : (modelData.kind === "site" ? (base + "/site/" + modelData.id + "/") : (base + "/f/" + modelData.id))
                                                Waybar.runCommand("printf '%s' '" + direct + "' | wl-copy")
                                            }
                                        }
                                    }

                                    StyledButton {
                                        text: "󰅖"
                                        isIconOnly: true
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        onClicked: if (Config) Config.removeWebShareItem(modelData.id)
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
