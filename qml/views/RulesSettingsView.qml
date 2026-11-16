import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: rScroll
    contentWidth: availableWidth
    clip: true

    readonly property bool isM3: Theme && Theme.isRounded
    property string searchQuery: ""
    property int filterMode: 0 // 0=Все, 1=Окна, 2=Слои

    readonly property var filteredRules: {
        var all = Rules ? Rules.rules : []
        var q = rScroll.searchQuery.trim().toLowerCase()
        var out = []
        for (var i = 0; i < all.length; ++i) {
            var r = all[i]
            if (rScroll.filterMode === 1 && r.ruleType !== "window") continue
            if (rScroll.filterMode === 2 && r.ruleType !== "layer") continue
            if (q.length > 0) {
                var hay = ((r.name || "") + " " + (r.className || "") + " " + (r.titleMatch || "") + " " + (r.namespaceMatch || "") + " " + (r.rawCode || "")).toLowerCase()
                if (hay.indexOf(q) === -1) continue
            }
            out.push(r)
        }
        return out
    }

    Item {
        width: rScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 40

        ColumnLayout {
            id: contentCol
            width: Math.min(parent.width - 48, 880)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 10

            // Шапка
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: (Config ? (Config.language, Config.trAuto("Правила окон и слоёв")) : "Правила окон и слоёв") + " • " + rScroll.filteredRules.length
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }

                SegmentedButton {
                    options: ["Все", "󰖲 Окна", "󰜬 Слои"]
                    selectedIndex: rScroll.filterMode
                    onSelected: (idx) => rScroll.filterMode = idx
                }

                StyledButton {
                    text: "󰑐 Обновить"
                    onClicked: if (Rules) Rules.reload()
                }
            }

            // Поиск по правилам
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: rScroll.isM3 ? 9 : 0
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: ruleSearchInput.activeFocus ? (Config ? Config.m3Primary : "#ffffff") : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰍉"
                        color: "#888888"
                        font.pixelSize: Config.fontSize
                    }

                    TextInput {
                        id: ruleSearchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: Config.fontSize
                        selectByMouse: true
                        clip: true
                        onTextChanged: rScroll.searchQuery = text

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Поиск по классу, имени, размеру или свойству (например: ayugram, btop, 1000, blur)..."
                            color: "#666666"
                            font.pixelSize: Config.fontSize
                            visible: !ruleSearchInput.text && !ruleSearchInput.activeFocus
                        }
                    }
                }
            }

            Repeater {
                model: rScroll.filteredRules

                GlassPanel {
                    id: ruleCard
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: colR.implicitHeight + 22
                    opacity: modelData.enabled ? 1.0 : 0.62

                    property bool showCode: false
                    readonly property bool hasGeometry: (modelData.sizeW !== "" && modelData.sizeH !== "") || modelData.center || modelData.movePos !== ""

                    ColumnLayout {
                        id: colR
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // ВЕРХНЯЯ СТРОКА: Иконка, Имя правила, Тип, Мини-схема окна, Код, Тумблер, Удаление
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Иконка класса / правила
                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                Layout.alignment: Qt.AlignVCenter
                                radius: rScroll.isM3 ? 9 : 0
                                color: modelData.enabled
                                       ? (rScroll.isM3 && Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.10))
                                       : Qt.rgba(1, 1, 1, 0.04)
                                border.color: modelData.enabled && Config
                                              ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.40)
                                              : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.ruleType === "layer" ? "󰜬" : "󰖲"
                                    color: modelData.enabled ? (Config ? Config.m3Primary : "#ffffff") : "#777777"
                                    font.pixelSize: 16
                                }
                            }

                            // Заголовок и строка номеров строк в hyprland.lua
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.displayTitle
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize + 1
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: typeTagTxt.implicitWidth + 10
                                        Layout.preferredHeight: 18
                                        radius: rScroll.isM3 ? 5 : 0
                                        color: modelData.ruleType === "layer"
                                               ? Qt.rgba(0.68, 0.52, 0.98, 0.18)
                                               : Qt.rgba(0.38, 0.72, 0.98, 0.18)
                                        border.width: 1
                                        border.color: modelData.ruleType === "layer"
                                                      ? Qt.rgba(0.68, 0.52, 0.98, 0.42)
                                                      : Qt.rgba(0.38, 0.72, 0.98, 0.42)

                                        Text {
                                            id: typeTagTxt
                                            anchors.centerIn: parent
                                            text: modelData.ruleType === "layer" ? "СЛОЙ" : "ОКНО"
                                            color: modelData.ruleType === "layer" ? "#d8b4fe" : "#93c5fd"
                                            font.pixelSize: Config.fontSize - 3
                                            font.bold: true
                                        }
                                    }

                                    Text {
                                        text: "стр. " + modelData.startLine + "–" + modelData.endLine
                                        color: "#666666"
                                        font.pixelSize: Config.fontSize - 2
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                // Условия совпадения (Match: class, title, namespace)
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: modelData.matchBadges
                                        delegate: Rectangle {
                                            width: matchRow.implicitWidth + 12
                                            height: 20
                                            radius: rScroll.isM3 ? 6 : 0
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.14)

                                            RowLayout {
                                                id: matchRow
                                                anchors.centerIn: parent
                                                spacing: 5

                                                Text {
                                                    text: modelData.icon
                                                    color: Config ? Config.m3Primary : "#a8c7fa"
                                                    font.pixelSize: Config.fontSize - 1
                                                }

                                                Text {
                                                    text: modelData.label
                                                    color: "#dddddd"
                                                    font.pixelSize: Config.fontSize - 1
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Визуальная мини-схема геометрии окна относительно монитора 1920x1080
                            Rectangle {
                                visible: ruleCard.hasGeometry && modelData.ruleType === "window"
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 32
                                Layout.alignment: Qt.AlignVCenter
                                radius: rScroll.isM3 ? 5 : 0
                                color: Qt.rgba(0, 0, 0, 0.38)
                                border.color: Qt.rgba(1, 1, 1, 0.20)
                                border.width: 1
                                clip: true

                                readonly property real wRatio: {
                                    var w = parseInt(modelData.sizeW) || 640
                                    return Math.max(0.16, Math.min(0.96, w / 1920.0))
                                }
                                readonly property real hRatio: {
                                    var h = parseInt(modelData.sizeH) || 420
                                    return Math.max(0.18, Math.min(0.94, h / 1080.0))
                                }
                                readonly property real xRatio: {
                                    if (modelData.movePos !== "") {
                                        var parts = String(modelData.movePos).trim().split(/\s+/)
                                        var mx = parseInt(parts[0])
                                        if (!isNaN(mx)) return Math.max(0.02, Math.min(0.96 - wRatio, mx / 1920.0))
                                    }
                                    return (1.0 - wRatio) * 0.5
                                }
                                readonly property real yRatio: {
                                    if (modelData.movePos !== "") {
                                        var parts = String(modelData.movePos).trim().split(/\s+/)
                                        if (parts.length > 1) {
                                            if (parts[1].indexOf("monitor_h") !== -1) return 0.94 - hRatio
                                            var my = parseInt(parts[1])
                                            if (!isNaN(my)) return Math.max(0.04, Math.min(0.94 - hRatio, my / 1080.0))
                                        }
                                    }
                                    return (1.0 - hRatio) * 0.5
                                }

                                Rectangle {
                                    x: Math.round(parent.width * parent.xRatio)
                                    y: Math.round(parent.height * parent.yRatio)
                                    width: Math.max(8, Math.round(parent.width * parent.wRatio))
                                    height: Math.max(6, Math.round(parent.height * parent.hRatio))
                                    radius: rScroll.isM3 ? 2 : 0
                                    color: Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.42) : Qt.rgba(1, 1, 1, 0.35)
                                    border.color: Config ? Config.m3Primary : "#ffffff"
                                    border.width: 1
                                }
                            }

                            StyledButton {
                                text: "󰅴"
                                isIconOnly: true
                                isActive: ruleCard.showCode
                                implicitWidth: 28
                                implicitHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: ruleCard.showCode = !ruleCard.showCode
                            }

                            StyledSwitch {
                                Layout.alignment: Qt.AlignVCenter
                                checked: modelData.enabled
                                onToggled: Rules.toggleRule(modelData.index, checked)
                            }

                            StyledButton {
                                text: "󰅖"
                                isIconOnly: true
                                implicitWidth: 26
                                implicitHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: Rules.deleteRule(modelData.index)
                            }
                        }

                        // СТРОКА СВОЙСТВ И ПАРАМЕТРОВ ПРАВИЛА (Размер, Позиция, Плавающее, Центр, Стол, Эффекты)
                        Flow {
                            visible: modelData.propBadges && modelData.propBadges.length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 44
                            spacing: 6

                            Repeater {
                                model: modelData.propBadges
                                delegate: Rectangle {
                                    width: propBadgeRow.implicitWidth + 14
                                    height: 22
                                    radius: rScroll.isM3 ? 6 : 0
                                    color: modelData.kind === "size"
                                           ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.14))
                                           : (modelData.kind === "flag"
                                              ? Qt.rgba(0.95, 0.45, 0.45, 0.14)
                                              : Qt.rgba(1, 1, 1, 0.05))
                                    border.width: 1
                                    border.color: modelData.kind === "size"
                                                  ? (Config ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.48) : Qt.rgba(1, 1, 1, 0.30))
                                                  : (modelData.kind === "flag"
                                                     ? Qt.rgba(0.95, 0.45, 0.45, 0.38)
                                                     : Qt.rgba(1, 1, 1, 0.12))

                                    RowLayout {
                                        id: propBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: modelData.icon
                                            color: modelData.kind === "size"
                                                   ? (Config ? Config.m3Primary : "#ffffff")
                                                   : (modelData.kind === "flag" ? "#fca5a5" : "#bbbbbb")
                                            font.pixelSize: Config.fontSize - 1
                                        }

                                        Text {
                                            text: modelData.label
                                            color: modelData.kind === "size" ? "#ffffff" : "#d4d4d8"
                                            font.pixelSize: Config.fontSize - 1
                                            font.bold: modelData.kind === "size"
                                        }
                                    }
                                }
                            }
                        }

                        // Раскрывающийся блок исходного Lua-кода правила
                        Rectangle {
                            visible: ruleCard.showCode
                            Layout.fillWidth: true
                            Layout.leftMargin: 44
                            implicitHeight: codeTxt.implicitHeight + 16
                            radius: rScroll.isM3 ? 8 : 0
                            color: Qt.rgba(0, 0, 0, 0.36)
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1

                            TextEdit {
                                id: codeTxt
                                anchors.fill: parent
                                anchors.margins: 8
                                text: modelData.rawCode || ""
                                color: "#d4d4d8"
                                font.family: "monospace"
                                font.pixelSize: Config.fontSize - 1
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
