import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: bScroll
    contentWidth: availableWidth
    clip: true

    property int filterMode: 0 // 0 = Все, 1 = Команды, 2 = Lua-функции
    property string searchQuery: ""

    Item {
        width: bScroll.availableWidth
        implicitHeight: bCol.implicitHeight + 44

        ColumnLayout {
            id: bCol
            width: Math.min(parent.width - 48, 920)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "⌨  Бинды клавиш и Lua-функции (hyprland.lua)"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }
                SegmentedButton {
                    options: ["Все", "Команды", "Lua-функции"]
                    selectedIndex: bScroll.filterMode
                    onSelected: (idx) => bScroll.filterMode = idx
                }
            }

            // Поиск + Добавление нового бинда
            GlassPanel {
                objectName: "atmoObstacle"
                Layout.fillWidth: true
                implicitHeight: topCtrlCol.implicitHeight + 18

                ColumnLayout {
                    id: topCtrlCol
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: filterField
                            placeholderText: "󰍉 Поиск по клавишам, команде или коду функции..."
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 26
                            Layout.fillWidth: true
                            onTextChanged: bScroll.searchQuery = text.toLowerCase()
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                            }
                        }

                        StyledButton {
                            text: "󰑐 Перечитать файл"
                            onClicked: Binds.reload()
                        }
                    }

                    RowLayout {
                        id: addRow
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: newKey
                            placeholderText: "SUPER + Q"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 26
                            Layout.preferredWidth: 145
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                            }
                        }

                        TextField {
                            id: newCmd
                            placeholderText: "Команда или function() ... end"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize
                            implicitHeight: 26
                            Layout.fillWidth: true
                            background: Rectangle {
                                radius: (Theme && Theme.isRounded) ? 6 : 0
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                            }
                        }

                        StyledButton {
                            text: "+ Добавить"
                            onClicked: {
                                if (newKey.text.trim().length > 0 && newCmd.text.trim().length > 0) {
                                    var isFn = newCmd.text.trim().indexOf("function") === 0 || newCmd.text.trim().indexOf("hl.dsp.") === 0
                                    Binds.addItem(newKey.text, newCmd.text, isFn)
                                    newKey.text = ""
                                    newCmd.text = ""
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: Binds.items

                GlassPanel {
                    id: bindCard
                    objectName: "atmoObstacle"
                    property bool expanded: false
                    readonly property bool isFn: modelData.isFunc === true
                    readonly property bool isMulti: modelData.isMultiline === true
                    readonly property bool matchesFilter: {
                        if (bScroll.filterMode === 1 && isFn) return false
                        if (bScroll.filterMode === 2 && !isFn) return false
                        if (bScroll.searchQuery.length > 0) {
                            var q = bScroll.searchQuery
                            var k = (modelData.keys || "").toLowerCase()
                            var c = (modelData.cmd || "").toLowerCase()
                            var d = (modelData.description || "").toLowerCase()
                            if (k.indexOf(q) === -1 && c.indexOf(q) === -1 && d.indexOf(q) === -1) return false
                        }
                        return true
                    }

                    visible: matchesFilter
                    Layout.fillWidth: true
                    implicitHeight: matchesFilter ? (cardCol.implicitHeight + 14) : 0

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 6

                        // Подпись из комментария над биндом (если есть)
                        RowLayout {
                            Layout.fillWidth: true
                            visible: (modelData.description && modelData.description.length > 0) || bindCard.isMulti
                            spacing: 8

                            Rectangle {
                                visible: bindCard.isFn
                                height: 18
                                width: fnBadgeTxt.implicitWidth + 12
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: bindCard.isMulti
                                       ? ((Theme && Theme.isRounded && Config) ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.22) : Qt.rgba(0.4, 0.85, 1.0, 0.18))
                                       : Qt.rgba(1, 1, 1, 0.09)
                                Text {
                                    id: fnBadgeTxt
                                    anchors.centerIn: parent
                                    text: bindCard.isMulti ? "LUA ФУНКЦИЯ" : "ДИСПЕТЧЕР"
                                    color: bindCard.isMulti ? ((Theme && Theme.isRounded && Config) ? Config.m3Primary : "#69f0ae") : "#cccccc"
                                    font.pixelSize: Config.fontSize - 3
                                    font.bold: true
                                }
                            }

                            Text {
                                text: modelData.description || ""
                                color: "#aaaaaa"
                                font.pixelSize: Config.fontSize - 1
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            id: itemRow
                            Layout.fillWidth: true
                            spacing: 8

                            StyledSwitch {
                                checked: modelData.enabled
                                onToggled: Binds.toggleItem(index, checked)
                            }

                            TextField {
                                id: keyField
                                text: modelData.keys
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                font.bold: true
                                implicitHeight: 24
                                Layout.preferredWidth: 165
                                background: Rectangle {
                                    radius: (Theme && Theme.isRounded) ? 5 : 0
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.10)
                                }
                            }

                            // Однострочное поле (для обычных команд или свернутого превью функции)
                            TextField {
                                id: singleCmdField
                                visible: !bindCard.isMulti || !bindCard.expanded
                                readOnly: bindCard.isMulti
                                text: bindCard.isMulti ? modelData.cmd.replace(/\n/g, "  ↵  ") : modelData.cmd
                                color: bindCard.isMulti ? "#bbbbbb" : "#ffffff"
                                font.pixelSize: Config.fontSize
                                font.family: bindCard.isFn ? "monospace" : Font.family
                                implicitHeight: 24
                                Layout.fillWidth: true
                                background: Rectangle {
                                    radius: (Theme && Theme.isRounded) ? 5 : 0
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                }
                                MouseArea {
                                    enabled: bindCard.isMulti
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bindCard.expanded = !bindCard.expanded
                                }
                            }

                            Item {
                                visible: bindCard.isMulti && bindCard.expanded
                                Layout.fillWidth: true
                                height: 1
                            }

                            StyledButton {
                                visible: bindCard.isMulti
                                text: bindCard.expanded ? "󰅀 Свернуть" : "󰅂 Код"
                                onClicked: bindCard.expanded = !bindCard.expanded
                            }

                            StyledButton {
                                text: "󰆓"
                                implicitWidth: 26
                                onClicked: {
                                    var codeToSave = bindCard.isMulti ? multiCodeArea.text : singleCmdField.text
                                    Binds.updateItem(index, modelData.enabled, keyField.text, codeToSave)
                                }
                            }

                            StyledButton {
                                text: "󰆴"
                                implicitWidth: 26
                                onClicked: Binds.deleteItem(index)
                            }
                        }

                        // Многострочный редактор кода для больших Lua-функций
                        Rectangle {
                            visible: bindCard.isMulti && bindCard.expanded
                            Layout.fillWidth: true
                            implicitHeight: Math.min(320, Math.max(120, multiCodeArea.contentHeight + 20))
                            radius: (Theme && Theme.isRounded) ? 6 : 0
                            color: Qt.rgba(0.04, 0.05, 0.07, 0.78)
                            border.width: 1
                            border.color: (Theme && Theme.isRounded && Config)
                                          ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.45)
                                          : Qt.rgba(1, 1, 1, 0.22)

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true

                                TextArea {
                                    id: multiCodeArea
                                    text: modelData.cmd
                                    color: "#e8eef5"
                                    font.family: "monospace"
                                    font.pixelSize: Config.fontSize - 1
                                    selectByMouse: true
                                    wrapMode: TextEdit.NoWrap
                                    background: null
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
