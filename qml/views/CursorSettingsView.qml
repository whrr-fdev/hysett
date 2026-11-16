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

    Item {
        width: curScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

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
                    options: ["󰇀 Настройки", "󰉍 Установка курсора"]
                    selectedIndex: curScroll.currentTab
                    onSelected: (idx) => {
                        curScroll.currentTab = idx
                        if (idx === 1) Cursor.refreshDownloadArchives()
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
                                text: "󰉍 Установить новый"
                                onClicked: {
                                    curScroll.currentTab = 1
                                    Cursor.refreshDownloadArchives()
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: (Theme && Theme.isRounded) ? 10 : 0
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
                                    radius: (Theme && Theme.isRounded) ? 8 : 0
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

            // ===================== ВКЛАДКА 1: УСТАНОВКА КУРСОРА =====================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: curScroll.currentTab === 1

                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colInst.implicitHeight + 24

                    ColumnLayout {
                        id: colInst
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: Config ? (Config.language, Config.trAuto("Установка курсора из файла или папки")) : "Установка курсора из файла или папки"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }

                        Text {
                            text: "Выберите скачанный архив (.tar.xz, .tar.gz, .tar.zst, .zip, .hlc) или папку с темой курсора — он распакуется в ~/.local/share/icons и сразу появится в списке доступных."
                            color: "#aaaaaa"
                            font.pixelSize: Config.fontSize - 1
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Поле выбора файла и кнопки
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                radius: (Theme && Theme.isRounded) ? 8 : 0
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
                                        text: "Путь к архиву или папке с курсором..."
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
                                isAccent: true
                                onClicked: {
                                    Cursor.installCursor(curScroll.selectedArchivePath, curScroll.applyImmediately)
                                }
                            }
                        }

                        // Зона перетаскивания (Drag & Drop)
                        Rectangle {
                            id: dropBox
                            Layout.fillWidth: true
                            implicitHeight: 62
                            radius: (Theme && Theme.isRounded) ? 10 : 0
                            color: cursorDropArea.containsDrag
                                   ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.12))
                                   : Qt.rgba(1, 1, 1, 0.03)
                            border.color: cursorDropArea.containsDrag
                                          ? (Config ? Config.m3Primary : "#ffffff")
                                          : Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: cursorDropArea.containsDrag ? "󰇀 Отпустите файл для установки курсора" : "󰉍 Перетащите сюда архив или папку с курсором"
                                    color: cursorDropArea.containsDrag ? "#ffffff" : "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    font.bold: cursorDropArea.containsDrag
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Поддерживаются .tar.xz, .tar.gz, .tar.bz2, .tar.zst, .zip, .hlc и папки"
                                    color: "#777777"
                                    font.pixelSize: Config.fontSize - 2
                                }
                            }

                            DropArea {
                                id: cursorDropArea
                                anchors.fill: parent
                                onDropped: (drop) => {
                                    if (drop.hasUrls && drop.urls.length > 0) {
                                        curScroll.selectedArchivePath = drop.urls[0].toString()
                                        Cursor.installCursor(curScroll.selectedArchivePath, curScroll.applyImmediately)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Сразу применять курсор после установки:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.fillWidth: true
                            }
                            StyledSwitch {
                                checked: curScroll.applyImmediately
                                onToggled: curScroll.applyImmediately = checked
                            }
                        }

                        // Статус установки
                        Rectangle {
                            visible: Cursor.installStatus !== ""
                            Layout.fillWidth: true
                            implicitHeight: statusRow.implicitHeight + 14
                            radius: (Theme && Theme.isRounded) ? 8 : 0
                            color: Cursor.installSuccess ? Qt.rgba(0.18, 0.75, 0.42, 0.16) : Qt.rgba(0.92, 0.28, 0.28, 0.16)
                            border.color: Cursor.installSuccess ? Qt.rgba(0.25, 0.88, 0.52, 0.45) : Qt.rgba(0.95, 0.35, 0.35, 0.45)
                            border.width: 1

                            RowLayout {
                                id: statusRow
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 8

                                Text {
                                    text: Cursor.installSuccess ? "󰄬" : "󰅙"
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
                    }
                }

                // КАРТОЧКА: Быстрая установка из Загрузок
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
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

                        Text {
                            visible: Cursor.downloadArchives.length === 0
                            text: "В папке ~/Downloads не найдено архивов (.tar.xz, .tar.gz, .zip, .hlc)"
                            color: "#888888"
                            font.pixelSize: Config.fontSize - 1
                        }

                        Repeater {
                            model: Cursor.downloadArchives
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: (Theme && Theme.isRounded) ? 8 : 0
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
                            text: "Доступные курсоры (" + Cursor.installedThemes.length + ")"
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
                                    radius: (Theme && Theme.isRounded) ? 9 : 0
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
                                            radius: (Theme && Theme.isRounded) ? 7 : 0
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
