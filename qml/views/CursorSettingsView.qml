import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: curScroll
    contentWidth: availableWidth
    clip: true

    property int currentTab: 0
    property string selectedArchivePath: ""
    property bool applyImmediately: true
    property string searchQuery: ""
    property int sourceFilterIdx: 0
    readonly property var sourceCodes: ["all", "gnome-look", "github", "popular"]
    readonly property bool isM3: Theme && Theme.isRounded

    Item {
        width: curScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        DropArea {
            anchors.fill: parent
            onDropped: (drop) => {
                if (drop.hasUrls && drop.urls.length > 0) {
                    var p = decodeURIComponent(String(drop.urls[0]).replace(/^file:\/\//, ""))
                    if (Config) Config.addStashedFile(p)
                    curScroll.selectedArchivePath = p
                }
            }
        }

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 12

                Text {
                    text: Config ? (Config.language, Config.trAuto("Курсор")) : "Курсор"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                SegmentedButton {
                    options: ["󰇀 Настройки", "󰉍 Каталог и установка"]
                    selectedIndex: curScroll.currentTab
                    onSelected: (idx) => {
                        curScroll.currentTab = idx
                        if (idx === 1) {
                            Cursor.refreshDownloadArchives()
                            if (Cursor.onlineCursors.length === 0 && !Cursor.onlineLoading) {
                                Cursor.searchOnlineCursors(curScroll.searchQuery, curScroll.sourceCodes[curScroll.sourceFilterIdx])
                            }
                        }
                    }
                }
            }

            // ===================== ВКЛАДКА 0: НАСТРОЙКИ =====================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: curScroll.currentTab === 0

                // КАРТОЧКА 1: Тема и размер
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colTh.implicitHeight + 18

                    ColumnLayout {
                        id: colTh
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: Config ? (Config.language, Config.trAuto("Тема и размер")) : "Тема и размер"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            StyledButton {
                                text: "󰉍 Скачать / Установить"
                                onClicked: {
                                    curScroll.currentTab = 1
                                    Cursor.refreshDownloadArchives()
                                    if (Cursor.onlineCursors.length === 0 && !Cursor.onlineLoading) {
                                        Cursor.searchOnlineCursors(curScroll.searchQuery, curScroll.sourceCodes[curScroll.sourceFilterIdx])
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: curScroll.isM3 ? 10 : 0
                                color: Qt.rgba(1, 1, 1, Math.max(0.04, Config ? Config.cardOpacity * 0.15 : 0.06))
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 3
                                    width: 20
                                    height: 20
                                    source: "image://cursor/" + Cursor.theme
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            StyledComboBox {
                                Layout.fillWidth: true
                                itemIconPrefix: "image://cursor/"
                                model: Cursor.installedThemes
                                currentIndex: Cursor.installedThemes.indexOf(Cursor.theme)
                                onActivated: (index) => Cursor.theme = Cursor.installedThemes[index]
                            }

                            RowLayout {
                                spacing: 1
                                Rectangle {
                                    implicitHeight: 26
                                    implicitWidth: 84
                                    radius: curScroll.isM3 ? 8 : 0
                                    color: Qt.rgba(1, 1, 1, Math.max(0.04, Config ? Config.cardOpacity * 0.15 : 0.06))
                                    border.color: Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        Button {
                                            text: "−"
                                            flat: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 24
                                            onClicked: Cursor.stepSize(-4)
                                            contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                        Text {
                                            text: Cursor.size.toString()
                                            color: "#ffffff"
                                            font.pixelSize: Config.fontSize
                                            font.bold: true
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Button {
                                            text: "+"
                                            flat: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 24
                                            onClicked: Cursor.stepSize(4)
                                            contentItem: Text { text: parent.text; color: "#ffffff"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // КАРТОЧКА 2: Основные параметры
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colMain.implicitHeight + 18

                    ColumnLayout {
                        id: colMain
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text { text: Config ? (Config.language, Config.trAuto("Основные параметры")) : "Основные параметры"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Аппаратный курсор (Hardware cursors):")) : "Аппаратный курсор (Hardware cursors):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                            Item { Layout.fillWidth: true }
                            SegmentedButton {
                                options: ["Вкл", "Выкл", "Авто"]
                                selectedIndex: Cursor.hwCursors === 0 ? 0 : (Cursor.hwCursors === 1 ? 1 : 2)
                                onSelected: (idx) => Cursor.hwCursors = idx === 0 ? 0 : (idx === 1 ? 1 : 2)
                            }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Поддержка Hyprcursor:")) : "Поддержка Hyprcursor:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.enableHyprcursor; onToggled: Cursor.enableHyprcursor = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Отключить перемещение (no_warps):")) : "Отключить перемещение (no_warps):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.noWarps; onToggled: Cursor.noWarps = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Запоминать позицию (persistent_warps):")) : "Запоминать позицию (persistent_warps):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.persistentWarps; onToggled: Cursor.persistentWarps = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Перемещение при смене стола:")) : "Перемещение при смене стола:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 240 }
                            Item { Layout.fillWidth: true }
                            SegmentedButton {
                                options: ["Выкл", "Вкл", "Принудительно"]
                                selectedIndex: Cursor.warpOnChangeWs
                                onSelected: (idx) => Cursor.warpOnChangeWs = idx
                            }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Масштаб лупы (Zoom factor):")) : "Масштаб лупы (Zoom factor):"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: 1.0
                                to: 4.0
                                stepSize: 0.1
                                value: Cursor.zoomFactor
                                onMoved: Cursor.zoomFactor = value
                            }
                            Text { text: Cursor.zoomFactor.toFixed(1) + "x"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                        }
                    }
                }

                // КАРТОЧКА 3: Видимость и скрытие
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colVis.implicitHeight + 18

                    ColumnLayout {
                        id: colVis
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text { text: Config ? (Config.language, Config.trAuto("Видимость и скрытие")) : "Видимость и скрытие"; color: "#ffffff"; font.pixelSize: Config.fontSize + 1; font.bold: true }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Таймаут скрытия:")) : "Таймаут скрытия:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 200 }
                            StyledSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: 60
                                stepSize: 5
                                value: Cursor.inactiveTimeout
                                onMoved: Cursor.inactiveTimeout = value
                            }
                            Text { text: Cursor.inactiveTimeout === 0 ? "Никогда" : Math.round(Cursor.inactiveTimeout) + "с"; color: "#ffffff"; font.pixelSize: Config.fontSize; Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Скрывать при вводе с клавиатуры:")) : "Скрывать при вводе с клавиатуры:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.hideOnKeyPress; onToggled: Cursor.hideOnKeyPress = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Скрывать при сенсорном вводе:")) : "Скрывать при сенсорном вводе:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.hideOnTouch; onToggled: Cursor.hideOnTouch = checked }
                        }

                        RowLayout {
                            Text { text: Config ? (Config.language, Config.trAuto("Скрывать при вводе с планшета:")) : "Скрывать при вводе с планшета:"; color: "#cccccc"; font.pixelSize: Config.fontSize; Layout.fillWidth: true }
                            StyledSwitch { checked: Cursor.hideOnTablet; onToggled: Cursor.hideOnTablet = checked }
                        }
                    }
                }
            }

            // ===================== ВКЛАДКА 1: КАТАЛОГ И УСТАНОВКА =====================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: curScroll.currentTab === 1

                // Плашка статуса (общая для онлайн-скачивания и локальной установки)
                Rectangle {
                    visible: Cursor.installStatus !== ""
                    Layout.fillWidth: true
                    implicitHeight: statusRow.implicitHeight + 16
                    radius: curScroll.isM3 ? 10 : 0
                    color: Cursor.installSuccess ? Qt.rgba(0.18, 0.75, 0.42, 0.16) : Qt.rgba(0.92, 0.28, 0.28, 0.16)
                    border.color: Cursor.installSuccess ? Qt.rgba(0.25, 0.88, 0.52, 0.45) : Qt.rgba(0.95, 0.35, 0.35, 0.45)
                    border.width: 1

                    RowLayout {
                        id: statusRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: Cursor.downloadingId !== "" ? "󰑐" : (Cursor.installSuccess ? "󰄬" : "󰅙")
                            color: Cursor.installSuccess ? "#5eead4" : "#f87171"
                            font.pixelSize: Config.fontSize + 2
                            font.bold: true
                        }

                        Text {
                            text: Cursor.installStatus
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Блок файлов и папок, загруженных в панель задач (Drag-and-Drop через панель)
                GlassPanel {
                    objectName: "atmoObstacle"
                    visible: Config && Config.stashedFiles.length > 0
                    Layout.fillWidth: true
                    implicitHeight: stashCursorCol.implicitHeight + 24

                    ColumnLayout {
                        id: stashCursorCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

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
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            StyledButton {
                                text: "󰎟 Очистить файлы"
                                implicitHeight: 22
                                onClicked: if (Config) Config.clearStashedFiles()
                            }
                        }

                        Item {
                            id: stashCursorHoverWrap
                            Layout.fillWidth: true
                            implicitHeight: stashCursorListCol.implicitHeight
                            property bool isHovering: false
                            property real hovY: 0
                            property real hovH: 36

                            Timer {
                                id: stashCursorHold
                                interval: 45
                                onTriggered: stashCursorHoverWrap.isHovering = false
                            }

                            Rectangle {
                                z: 1
                                opacity: stashCursorHoverWrap.isHovering ? 1.0 : 0.0
                                x: 0; y: stashCursorHoverWrap.hovY
                                width: stashCursorHoverWrap.width; height: stashCursorHoverWrap.hovH
                                radius: curScroll.isM3 ? 8 : 0
                                color: curScroll.isM3 && Config
                                       ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                       : Qt.rgba(1, 1, 1, 0.10)
                                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                                Behavior on opacity { NumberAnimation { duration: 115 } }
                            }

                            ColumnLayout {
                                id: stashCursorListCol
                                z: 2; width: parent.width; spacing: 5

                                Repeater {
                                    model: Config ? Config.stashedFiles : []
                                    delegate: Rectangle {
                                        id: stashCursorRow
                                        Layout.fillWidth: true
                                        implicitHeight: 36
                                        radius: curScroll.isM3 ? 8 : 0
                                        color: Qt.rgba(1, 1, 1, 0.04)
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: {
                                                stashCursorHold.stop()
                                                stashCursorHoverWrap.hovY = stashCursorRow.y
                                                stashCursorHoverWrap.hovH = stashCursorRow.height
                                                stashCursorHoverWrap.isHovering = true
                                            }
                                            onExited: stashCursorHold.restart()
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: modelData.isDir ? "󰉋" : "󰀼"
                                                color: Config ? Config.m3Primary : "#a8c7fa"
                                                font.pixelSize: 14
                                            }

                                            Text {
                                                text: modelData.name
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.size + " • " + modelData.time
                                                color: "#888888"
                                                font.pixelSize: Config ? Config.fontSize - 2 : 9
                                            }

                                            StyledButton {
                                                text: "󰄬 Установить курсор"
                                                implicitHeight: 24
                                                isActive: true
                                                onClicked: {
                                                    curScroll.selectedArchivePath = modelData.path
                                                    Cursor.installCursor(modelData.path, curScroll.applyImmediately)
                                                }
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

                // КАРТОЧКА ЛОКАЛЬНОЙ УСТАНОВКИ ИЗ ФАЙЛА ИЛИ ПАПКИ
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colInst.implicitHeight + 24

                    ColumnLayout {
                        id: colInst
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: Config ? (Config.language, Config.trAuto("Установка из файла или папки")) : "Установка из файла или папки"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Сразу применять:"
                                color: "#bbbbbb"
                                font.pixelSize: Config.fontSize - 1
                            }

                            StyledSwitch {
                                checked: curScroll.applyImmediately
                                onToggled: curScroll.applyImmediately = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: curScroll.isM3 ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: pathInput.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1

                                TextInput {
                                    id: pathInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    selectByMouse: true
                                    clip: true
                                    text: curScroll.selectedArchivePath
                                    onTextEdited: curScroll.selectedArchivePath = text

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Сбросьте архив на верхнюю панель или выберите файл (.tar.xz, .tar.gz, .zip, .hlc)..."
                                        color: "#666666"
                                        font.pixelSize: Config.fontSize
                                        visible: !pathInput.text && !pathInput.activeFocus
                                    }
                                }
                            }

                            StyledButton {
                                text: "󰉋 Выбрать файл..."
                                onClicked: {
                                    var p = Cursor.browseCursorArchive()
                                    if (p !== "") {
                                        curScroll.selectedArchivePath = p
                                    }
                                }
                            }

                            StyledButton {
                                text: "󰄬 Установить"
                                isActive: true
                                onClicked: {
                                    Cursor.installCursor(curScroll.selectedArchivePath, curScroll.applyImmediately)
                                }
                            }
                        }
                    }
                }

                // КАРТОЧКА ОНЛАЙН-ПОИСКА КУРСОРОВ (Gnome-Look + GitHub)
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colOnline.implicitHeight + 24

                    ColumnLayout {
                        id: colOnline
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: "󰖟 Поиск курсоров по сайтам (Gnome-Look / GitHub)"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }

                        // Строка поиска и фильтров
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: curScroll.isM3 ? 8 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: onlineSearchInput.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.16)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Text {
                                        text: "󰍉"
                                        color: "#888888"
                                        font.pixelSize: Config.fontSize
                                    }

                                    TextInput {
                                        id: onlineSearchInput
                                        Layout.fillWidth: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        selectByMouse: true
                                        clip: true
                                        text: curScroll.searchQuery
                                        onTextEdited: curScroll.searchQuery = text
                                        onAccepted: Cursor.searchOnlineCursors(curScroll.searchQuery, curScroll.sourceCodes[curScroll.sourceFilterIdx])

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: "Поиск курсоров (например: Bibata, Catppuccin, macOS, Nord, Anime)..."
                                            color: "#666666"
                                            font.pixelSize: Config.fontSize
                                            visible: !onlineSearchInput.text && !onlineSearchInput.activeFocus
                                        }
                                    }
                                }
                            }

                            SegmentedButton {
                                options: ["Все", "Gnome-Look", "GitHub", "Топ"]
                                selectedIndex: curScroll.sourceFilterIdx
                                onSelected: (idx) => {
                                    curScroll.sourceFilterIdx = idx
                                    Cursor.searchOnlineCursors(curScroll.searchQuery, curScroll.sourceCodes[idx])
                                }
                            }

                            StyledButton {
                                text: Cursor.onlineLoading ? "󰑐 Поиск..." : "󰍉 Найти"
                                isActive: true
                                onClicked: Cursor.searchOnlineCursors(curScroll.searchQuery, curScroll.sourceCodes[curScroll.sourceFilterIdx])
                            }
                        }

                        // Индикатор загрузки
                        Rectangle {
                            visible: Cursor.onlineLoading
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: curScroll.isM3 ? 8 : 0
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Text {
                                anchors.centerIn: parent
                                text: "󰑐 Загрузка карточек курсоров с Gnome-Look и GitHub..."
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                            }
                        }

                        // Сетка карточек курсоров с сайтов
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 680 ? 3 : 2
                            columnSpacing: 10
                            rowSpacing: 10
                            visible: Cursor.onlineCursors.length > 0

                            Repeater {
                                model: Cursor.onlineCursors
                                delegate: Rectangle {
                                    id: onlineCard
                                    Layout.fillWidth: true
                                    implicitHeight: cardInnerCol.implicitHeight + 20
                                    radius: curScroll.isM3 ? 12 : 0
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Qt.rgba(1, 1, 1, 0.13)
                                    border.width: 1

                                    property int selectedVarIdx: 0
                                    readonly property var variantsList: modelData.variants ? modelData.variants : []
                                    readonly property bool isThisDownloading: Cursor.downloadingId === modelData.id

                                    ColumnLayout {
                                        id: cardInnerCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8

                                        // Превью-картинка с сайта
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 110
                                            radius: curScroll.isM3 ? 9 : 0
                                            color: Qt.rgba(0, 0, 0, 0.32)
                                            border.color: Qt.rgba(1, 1, 1, 0.10)
                                            border.width: 1
                                            clip: true

                                            Image {
                                                id: previewImg
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                source: modelData.preview || ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                cache: true
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: previewImg.status !== Image.Ready
                                                text: previewImg.status === Image.Loading ? "󰑐" : "󰇀"
                                                color: "#666666"
                                                font.pixelSize: 24
                                            }

                                            // Бейдж источника (Gnome-Look / GitHub)
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 6
                                                height: 18
                                                width: srcBadgeText.implicitWidth + 10
                                                radius: curScroll.isM3 ? 5 : 0
                                                color: Qt.rgba(0, 0, 0, 0.72)
                                                border.color: Qt.rgba(1, 1, 1, 0.18)
                                                border.width: 1

                                                Text {
                                                    id: srcBadgeText
                                                    anchors.centerIn: parent
                                                    text: modelData.source || "Web"
                                                    color: Config ? Config.m3Primary : "#ffffff"
                                                    font.pixelSize: Config.fontSize - 2
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        // Заголовок и автор
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: modelData.title || "Cursor Theme"
                                                color: "#ffffff"
                                                font.pixelSize: Config.fontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: "󰀄 " + (modelData.author || "author") + (modelData.downloads ? "  •  󰇚 " + modelData.downloads : "")
                                                color: "#888888"
                                                font.pixelSize: Config.fontSize - 2
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Выбор варианта (если в релизе несколько расцветок/архивов)
                                        StyledComboBox {
                                            visible: onlineCard.variantsList.length > 1
                                            Layout.fillWidth: true
                                            model: {
                                                var arr = []
                                                for (var i = 0; i < onlineCard.variantsList.length; ++i) {
                                                    arr.push(onlineCard.variantsList[i].name)
                                                }
                                                return arr
                                            }
                                            currentIndex: onlineCard.selectedVarIdx
                                            onActivated: (idx) => onlineCard.selectedVarIdx = idx
                                        }

                                        StyledButton {
                                            Layout.fillWidth: true
                                            allowFullWidth: true
                                            isActive: onlineCard.isThisDownloading
                                            text: onlineCard.isThisDownloading ? "󰑐 Скачивание..." : "󰇚 Скачать и установить"
                                            enabled: Cursor.downloadingId === "" && onlineCard.variantsList.length > 0
                                            onClicked: {
                                                var vIdx = Math.min(onlineCard.selectedVarIdx, onlineCard.variantsList.length - 1)
                                                var chosen = onlineCard.variantsList[vIdx]
                                                if (chosen && chosen.url) {
                                                    Cursor.downloadAndInstallCursor(modelData.id, chosen.url, chosen.name || "", curScroll.applyImmediately)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // КАРТОЧКА: Быстрая установка из Загрузок
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    visible: Cursor.downloadArchives.length > 0
                    implicitHeight: colDl.implicitHeight + 24

                    ColumnLayout {
                        id: colDl
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰉍 Архивы в папке «Загрузки»"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            StyledButton {
                                text: "󰑐 Обновить"
                                onClicked: Cursor.refreshDownloadArchives()
                            }
                        }

                        Repeater {
                            model: Cursor.downloadArchives
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: curScroll.isM3 ? 8 : 0
                                color: curScroll.selectedArchivePath === modelData.path
                                       ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.16) : Qt.rgba(1, 1, 1, 0.10))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: "󰀼"
                                        color: Config ? Config.m3Primary : "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                    }

                                    Text {
                                        text: modelData.name
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.size
                                        color: "#888888"
                                        font.pixelSize: Config.fontSize - 1
                                    }

                                    StyledButton {
                                        text: "󰄬 Установить"
                                        onClicked: {
                                            curScroll.selectedArchivePath = modelData.path
                                            Cursor.installCursor(modelData.path, curScroll.applyImmediately)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // КАРТОЧКА: Все установленные курсоры
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colAvail.implicitHeight + 24

                    ColumnLayout {
                        id: colAvail
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: "Установленные курсоры (" + Cursor.installedThemes.length + ")"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 620 ? 3 : 2
                            columnSpacing: 8
                            rowSpacing: 8

                            Repeater {
                                model: Cursor.installedThemes
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 42
                                    radius: curScroll.isM3 ? 9 : 0
                                    readonly property bool isActiveTheme: Cursor.theme === modelData
                                    color: isActiveTheme
                                           ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                                           : (themeCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                    border.color: isActiveTheme
                                                  ? (Config ? Config.m3Primary : "#ffffff")
                                                  : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: curScroll.isM3 ? 7 : 0
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                            border.width: 1

                                            Image {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 2
                                                width: 18
                                                height: 18
                                                source: "image://cursor/" + modelData
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                asynchronous: true
                                            }
                                        }

                                        Text {
                                            text: modelData
                                            color: "#ffffff"
                                            font.pixelSize: Config.fontSize
                                            font.bold: isActiveTheme
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            visible: isActiveTheme
                                            text: "󰄬"
                                            color: Config ? Config.m3Primary : "#ffffff"
                                            font.pixelSize: Config.fontSize + 1
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: themeCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Cursor.theme = modelData
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
