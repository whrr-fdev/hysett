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
                if (Config) {
                    Config.addStashedFile(p)
                    Config.hostPathForFriend(p)
                }
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
                        text: "󰖟  Хостинг сайтов и файлов"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 3 : 14
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                    StyledButton {
                        text: webRoot.effHide ? "󰈉" : "󰈈"
                        isIconOnly: true
                        implicitWidth: 28
                        isActive: webRoot.effHide
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: webRoot.hideUrl = !webRoot.hideUrl
                    }
                    StyledButton {
                        text: "󰑐 Обновить"
                        Layout.alignment: Qt.AlignVCenter
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
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 132
                            Layout.alignment: Qt.AlignVCenter
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
                                    Layout.preferredWidth: 9
                                    Layout.preferredHeight: 9
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4.5
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
                                    Layout.alignment: Qt.AlignVCenter
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
                            }
                        }
                    }
                }

                // 2. КАРТОЧКА ЗАГРУЗКИ САЙТА ИЛИ ФАЙЛА
                GlassPanel {
                    Layout.fillWidth: true
                    implicitHeight: addCol.implicitHeight + 28

                    ColumnLayout {
                        id: addCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "󰇚"
                                color: Config ? Config.m3Primary : "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 2 : 13
                            }
                            Text {
                                text: "Загрузить сайт (.html / папку / .zip) или файл"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
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
                                isActive: pathField.text.trim().length > 0
                                enabled: pathField.text.trim().length > 0
                                onClicked: if (Config && pathField.text.trim().length > 0) Config.hostPathForFriend(pathField.text.trim())
                            }

                            StyledButton {
                                text: "󰅧 Автономно 24/7"
                                enabled: pathField.text.trim().length > 0
                                onClicked: if (Config && pathField.text.trim().length > 0) Config.cloudHostPathForFriend(pathField.text.trim())
                            }
                        }

                        // Блок файлов, закинутых в панель задач
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
                                id: stashWebHoverWrap
                                Layout.fillWidth: true
                                implicitHeight: stashWebCol.implicitHeight
                                property bool isHovering: false
                                property real hovY: 0
                                property real hovH: 38

                                Timer {
                                    id: stashWebHold
                                    interval: 45
                                    onTriggered: stashWebHoverWrap.isHovering = false
                                }

                                Rectangle {
                                    z: 1
                                    opacity: stashWebHoverWrap.isHovering ? 1.0 : 0.0
                                    x: 0; y: stashWebHoverWrap.hovY
                                    width: stashWebHoverWrap.width; height: stashWebHoverWrap.hovH
                                    radius: webRoot.isM3 ? 8 : 0
                                    color: webRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                           : Qt.rgba(1, 1, 1, 0.10)
                                    Behavior on y { NumberAnimation { duration: 175; easing.type: Easing.OutQuint } }
                                    Behavior on opacity { NumberAnimation { duration: 115 } }
                                }

                                ColumnLayout {
                                    id: stashWebCol
                                    z: 2; width: parent.width; spacing: 5

                                    Repeater {
                                        model: Config ? Config.stashedFiles : []
                                        delegate: Rectangle {
                                            id: stashWebRow
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            radius: webRoot.isM3 ? 8 : 0
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.color: Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    stashWebHold.stop()
                                                    stashWebHoverWrap.hovY = stashWebRow.y
                                                    stashWebHoverWrap.hovH = stashWebRow.height
                                                    stashWebHoverWrap.isHovering = true
                                                }
                                                onExited: stashWebHold.restart()
                                                onClicked: pathField.text = modelData.path
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Text {
                                                    text: modelData.isDir ? "󰉋" : (String(modelData.name).toLowerCase().indexOf(".html") !== -1 ? "󰖟" : "󰈔")
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
                                                    text: "󰖟 Выложить локально"
                                                    implicitHeight: 24
                                                    onClicked: if (Config) Config.hostPathForFriend(modelData.path)
                                                }

                                                StyledButton {
                                                    text: "󰅧 Выложить 24/7"
                                                    implicitHeight: 24
                                                    onClicked: if (Config) Config.cloudHostPathForFriend(modelData.path)
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

                // 3. АВТОНОМНЫЕ ССЫЛКИ 24/7 (РАБОТАЮТ ПРИ ВЫКЛЮЧЕННОМ ПК)
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
                            spacing: 8
                            Text {
                                text: "󰅧"
                                color: Config ? Config.m3Primary : "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 2 : 13
                            }
                            Text {
                                text: "Автономные сайты и файлы 24/7 (" + (Config ? Config.webShareCloudItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            visible: !Config || Config.webShareCloudItems.length === 0
                            text: "Пока нет опубликованных автономных ссылок 24/7"
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Item {
                            id: cloudHoverWrap
                            visible: Config && Config.webShareCloudItems.length > 0
                            Layout.fillWidth: true
                            implicitHeight: cloudInnerCol.implicitHeight
                            property bool isHovering: false
                            property real hovY: 0
                            property real hovH: 48

                            Timer {
                                id: cloudHoverHold
                                interval: 45
                                onTriggered: cloudHoverWrap.isHovering = false
                            }

                            Rectangle {
                                z: 1
                                opacity: cloudHoverWrap.isHovering ? 1.0 : 0.0
                                x: 0; y: cloudHoverWrap.hovY
                                width: cloudHoverWrap.width; height: cloudHoverWrap.hovH
                                radius: webRoot.isM3 ? 10 : 0
                                color: webRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.10)
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 115 } }
                            }

                            ColumnLayout {
                                id: cloudInnerCol
                                z: 2; width: parent.width; spacing: 6

                                Repeater {
                                    model: Config ? Config.webShareCloudItems : []
                                    delegate: Rectangle {
                                        id: cloudRowRect
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        radius: webRoot.isM3 ? 10 : 0
                                        color: Qt.rgba(1, 1, 1, 0.04)
                                        border.color: Qt.rgba(0.41, 0.94, 0.68, 0.28)
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: {
                                                cloudHoverHold.stop()
                                                cloudHoverWrap.hovY = cloudRowRect.y
                                                cloudHoverWrap.hovH = cloudRowRect.height
                                                cloudHoverWrap.isHovering = true
                                            }
                                            onExited: cloudHoverHold.restart()
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Item {
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                Layout.alignment: Qt.AlignVCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.kind === "site" ? "󰖟" : "󰅧"
                                                    color: "#69f0ae"
                                                    font.pixelSize: 16
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 1

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Rectangle {
                                                        Layout.preferredWidth: cBadgeTxt.implicitWidth + 10
                                                        Layout.preferredHeight: 17
                                                        Layout.alignment: Qt.AlignVCenter
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
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (webRoot.effHide ? "https://••••••••••••••••••••••••" : modelData.url) + "  •  " + modelData.size + "  •  " + modelData.time
                                                    color: "#999999"
                                                    elide: Text.ElideMiddle
                                                    font.pixelSize: Config ? Config.fontSize - 2 : 9
                                                }
                                            }

                                            StyledButton {
                                                text: "󰐲 QR"
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
                                                onClicked: if (Config) Config.selectCloudShareQr(modelData.id)
                                            }

                                            StyledButton {
                                                text: "󰆏 Ссылка"
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
                                                onClicked: if (Waybar) Waybar.runCommand("printf '%s' '" + modelData.url + "' | wl-copy")
                                            }

                                            StyledButton {
                                                text: "󰖟 Открыть"
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
                                                onClicked: if (Waybar) Waybar.runCommand("xdg-open '" + modelData.url + "'")
                                            }

                                            StyledButton {
                                                text: "󰅖"
                                                isIconOnly: true
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
                                                onClicked: if (Config) Config.removeCloudShareItem(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. ОПУБЛИКОВАННЫЕ ЛОКАЛЬНЫЕ САЙТЫ И ФАЙЛЫ
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
                            spacing: 8
                            Text {
                                text: "󰋚"
                                color: Config ? Config.m3Primary : "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 2 : 13
                            }
                            Text {
                                text: "Опубликованные сайты и файлы (" + (Config ? Config.webShareItems.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            StyledButton {
                                visible: Config && Config.webShareItems.length > 0
                                text: "󰎟 Очистить"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: if (Config) Config.clearWebShareItems()
                            }
                        }

                        Text {
                            visible: !Config || Config.webShareItems.length === 0
                            text: "Список локальной раздачи пуст"
                            color: "#777777"
                            font.pixelSize: Config ? Config.fontSize : 11
                        }

                        Item {
                            id: localHoverWrap
                            visible: Config && Config.webShareItems.length > 0
                            Layout.fillWidth: true
                            implicitHeight: localInnerCol.implicitHeight
                            property bool isHovering: false
                            property real hovY: 0
                            property real hovH: 46

                            Timer {
                                id: localHoverHold
                                interval: 45
                                onTriggered: localHoverWrap.isHovering = false
                            }

                            Rectangle {
                                z: 1
                                opacity: localHoverWrap.isHovering ? 1.0 : 0.0
                                x: 0; y: localHoverWrap.hovY
                                width: localHoverWrap.width; height: localHoverWrap.hovH
                                radius: webRoot.isM3 ? 10 : 0
                                color: webRoot.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.10)
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 115 } }
                            }

                            ColumnLayout {
                                id: localInnerCol
                                z: 2; width: parent.width; spacing: 6

                                Repeater {
                                    model: Config ? Config.webShareItems : []
                                    delegate: Rectangle {
                                        id: localRowRect
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        radius: webRoot.isM3 ? 10 : 0
                                        color: modelData.is_primary ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                                        border.color: modelData.is_primary ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: {
                                                localHoverHold.stop()
                                                localHoverWrap.hovY = localRowRect.y
                                                localHoverWrap.hovH = localRowRect.height
                                                localHoverWrap.isHovering = true
                                            }
                                            onExited: localHoverHold.restart()
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Item {
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                Layout.alignment: Qt.AlignVCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.kind === "site" ? "󰖟" : "󰈔"
                                                    color: modelData.kind === "site" ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                    font.pixelSize: 16
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 1

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Rectangle {
                                                        Layout.preferredWidth: kindBadgeTxt.implicitWidth + 10
                                                        Layout.preferredHeight: 17
                                                        Layout.alignment: Qt.AlignVCenter
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
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (modelData.is_primary ? "󰄬 Открывается по главной ссылке  •  " : "") + modelData.size + "  •  " + modelData.time
                                                    color: modelData.is_primary ? (Config ? Config.m3Primary : "#a8c7fa") : "#888888"
                                                    font.pixelSize: Config ? Config.fontSize - 2 : 9
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            StyledButton {
                                                visible: !modelData.is_primary
                                                text: "На главную"
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
                                                onClicked: if (Config) Config.setPrimaryWebShareItem(modelData.id)
                                            }

                                            StyledButton {
                                                text: "󰆏 Ссылка"
                                                implicitHeight: 24
                                                Layout.alignment: Qt.AlignVCenter
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
                                                Layout.alignment: Qt.AlignVCenter
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
    }
}
