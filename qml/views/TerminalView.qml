import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: root
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property var st: (Config && Config.terminalState) ? Config.terminalState : ({})
    readonly property var pal: st.palette ? st.palette : ({
        bg: "#0e1015", fg: "#e6e8ee", cont: "#181b24", high: "#252936",
        pri: Config ? Config.m3Primary.toString() : "#a8c7fa",
        sec: "#bec6dc", ter: "#debcdf", ok: "#69f0ae", err: "#ff6b6b"
    })
    readonly property color livePri: (root.dynamicTheme && Config) ? Config.m3Primary : (pal.pri || "#a8c7fa")
    readonly property color liveSec: (root.dynamicTheme && Config) ? Config.m3SecondaryColor : (pal.sec || "#bec6dc")
    readonly property color liveTer: (root.dynamicTheme && Config) ? Config.m3TertiaryColor : (pal.ter || "#debcdf")
    readonly property color liveBg: (root.dynamicTheme && Config) ? Config.m3Surface : (pal.bg || "#0e1015")
    readonly property color liveCont: (root.dynamicTheme && Config) ? Config.m3SurfaceContainer : (pal.cont || "#181b24")
    readonly property color liveHigh: (root.dynamicTheme && Config) ? Config.m3SurfaceContainerHigh : (pal.high || "#252936")
    readonly property color prevOsBg: root.tideStyle === "Lean" ? "transparent" : Qt.rgba(liveHigh.r * 0.85 + livePri.r * 0.15, liveHigh.g * 0.85 + livePri.g * 0.15, liveHigh.b * 0.85 + livePri.b * 0.15, 1.0)
    readonly property color prevPwdBg: root.tideStyle === "Lean" ? "transparent" : (root.tideStyle === "Classic" ? liveCont : livePri)
    readonly property color prevGitBg: root.tideStyle === "Lean" ? "transparent" : Qt.rgba(liveCont.r * 0.9 + livePri.r * 0.1, liveCont.g * 0.9 + livePri.g * 0.1, liveCont.b * 0.9 + livePri.b * 0.1, 1.0)

    readonly property bool tideEnabled: st.tideEnabled !== undefined ? Boolean(st.tideEnabled) : true
    readonly property string tideStyle: st.tideStyle || "Rainbow"
    readonly property string tideHeight: st.tideHeight || "Two lines"
    readonly property string tideSeparators: st.tideSeparators || "Round"
    readonly property string tideHeads: st.tideHeads || "Round"
    readonly property string tideTails: st.tideTails || "Round"
    readonly property string tideConnection: st.tideConnection || "Dotted"
    readonly property bool tideFrame: Boolean(st.tideFrame)
    readonly property string tideSpacing: st.tideSpacing || "Compact"
    readonly property string tideTime: st.tideTime || "24-hour format"
    readonly property string tideIcons: st.tideIcons || "Many icons"
    readonly property bool tideTransient: Boolean(st.tideTransient)
    readonly property string tideChar: st.tideChar || "❯"
    readonly property bool dynamicTheme: st.dynamicTheme !== undefined ? Boolean(st.dynamicTheme) : true
    readonly property int themePreset: st.themePreset !== undefined ? Number(st.themePreset) : 0
    readonly property string fontFamily: st.fontFamily || "JetBrainsMono Nerd Font"
    readonly property int fontSize: st.fontSize !== undefined ? Number(st.fontSize) : 11
    readonly property int paddingWidth: st.paddingWidth !== undefined ? Number(st.paddingWidth) : 12
    readonly property real bgOpacity: st.bgOpacity !== undefined ? Number(st.bgOpacity) : 0.92
    readonly property string cursorShape: st.cursorShape || "beam"
    readonly property int cursorTrail: st.cursorTrail !== undefined ? Number(st.cursorTrail) : 2

    function patch(obj) {
        if (Config) Config.applyTerminalPatch(obj)
    }

    Component.onCompleted: {
        if (Config) Config.refreshTerminalState()
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Item {
            width: scroll.availableWidth
            implicitHeight: mainCol.implicitHeight + 48

            ColumnLayout {
                id: mainCol
                width: Math.min(parent.width - 48, 920)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 20
                spacing: 14

                // Заголовок и быстрые действия
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "󰆍  Кастомизация терминала (Kitty & Fish Tide v6)"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 4
                            font.bold: true
                        }
                        Text {
                            text: "Настройка шрифта, плагина IlanCosman/tide@v6 и динамической цветовой темы"
                            color: "#888888"
                            font.pixelSize: Config.fontSize
                        }
                    }

                    StyledButton {
                        text: "󰑐 Обновить"
                        onClicked: if (Config) Config.refreshTerminalState()
                    }

                    StyledButton {
                        text: "󰆍 Открыть терминал"
                        isActive: true
                        onClicked: if (Config) Config.openTestTerminal()
                    }
                }

                // 1. ЖИВОЕ ГРАФИЧЕСКОЕ ПРЕВЬЮ ТЕРМИНАЛА И ПРОМПТА TIDE
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: previewInnerCol.implicitHeight + 28

                    ColumnLayout {
                        id: previewInnerCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Предпросмотр промпта и шрифта в реальном времени"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize + 1
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.fontFamily + " • " + root.fontSize + " pt • " + (root.tideEnabled ? ("Tide v6 (" + root.tideStyle + ")") : "CachyOS стандартный")
                                color: Config ? Config.m3Primary : "#a8c7fa"
                                font.pixelSize: Config.fontSize - 1
                                font.bold: true
                            }
                        }

                        Rectangle {
                            id: termSimBox
                            Layout.fillWidth: true
                            implicitHeight: termSimContent.implicitHeight + Math.min(28, root.paddingWidth) * 2
                            radius: root.isM3 ? 12 : 0
                            color: Qt.rgba(root.liveBg.r, root.liveBg.g, root.liveBg.b, Math.max(0.55, root.bgOpacity))
                            border.width: 1.5
                            border.color: root.livePri

                            ColumnLayout {
                                id: termSimContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Math.min(28, Math.max(10, root.paddingWidth))
                                anchors.rightMargin: Math.min(28, Math.max(10, root.paddingWidth))
                                spacing: root.tideSpacing === "Sparse" ? 10 : 4

                                // Верхняя строка промпта (Tide включен — 1-в-1 как в терминале)
                                RowLayout {
                                    visible: root.tideEnabled
                                    Layout.fillWidth: true
                                    spacing: 0

                                    readonly property int segH: root.fontSize + 9
                                    readonly property int segR: (root.tideStyle !== "Lean" && root.tideHeads === "Round") ? Math.round(segH / 2) : 0
                                    readonly property color osBg: root.tideStyle === "Lean" ? "transparent" : root.pal.high
                                    readonly property color pwdBg: root.tideStyle === "Lean" ? "transparent" : (root.tideStyle === "Classic" ? root.pal.cont : root.pal.pri)
                                    readonly property color gitBg: root.tideStyle === "Lean" ? "transparent" : root.pal.cont

                                    Text {
                                        visible: root.tideHeight === "Two lines" && root.tideFrame
                                        text: "╭─"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 1
                                        color: root.prevOsBg
                                    }

                                    // Левый каскад капсул (os -> pwd -> git) без артефактов высоты шрифта
                                    Item {
                                        implicitWidth: leftCapsRow.implicitWidth
                                        implicitHeight: parent.segH

                                        Row {
                                            id: leftCapsRow
                                            height: parent.height
                                            spacing: 0

                                            // 1. Сегмент ОС (CachyOS ) — сверху (z: 3), выпуклый правый край заходит на PWD
                                            Rectangle {
                                                z: 3
                                                visible: root.tideIcons === "Many icons"
                                                height: parent.height
                                                width: osSegTxt.implicitWidth + 16
                                                radius: (root.tideStyle !== "Lean" && (root.tideTails === "Round" || root.tideHeads === "Round")) ? height / 2 : 0
                                                color: root.prevOsBg
                                                Text {
                                                    id: osSegTxt
                                                    anchors.centerIn: parent
                                                    text: ""
                                                    font.family: root.fontFamily
                                                    font.pixelSize: root.fontSize + 1
                                                    color: root.livePri
                                                }
                                            }

                                            // 2. Сегмент папки ( ~) — под правым краем ОС (z: 2), выпуклый правый край заходит на Git
                                            Item {
                                                z: 2
                                                height: parent.height
                                                readonly property int overlapLeft: (root.tideIcons === "Many icons" && root.tideStyle !== "Lean") ? Math.round(height / 2) : 0
                                                width: pwdSegTxt.implicitWidth + 18

                                                Rectangle {
                                                    x: -parent.overlapLeft
                                                    width: parent.width + parent.overlapLeft
                                                    height: parent.height
                                                    radius: (root.tideStyle !== "Lean" && root.tideHeads === "Round") ? height / 2 : 0
                                                    color: root.prevPwdBg

                                                    Text {
                                                        id: pwdSegTxt
                                                        x: parent.parent.overlapLeft + 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: (root.tideIcons === "Many icons" ? " " : "") + "~"
                                                        font.family: root.fontFamily
                                                        font.pixelSize: root.fontSize
                                                        font.bold: true
                                                        color: root.tideStyle === "Rainbow" ? "#0b0d12" : root.pal.pri
                                                    }
                                                }
                                            }

                                            // 3. Сегмент Git ( main +1) — под правым краем PWD (z: 1)
                                            Item {
                                                z: 1
                                                height: parent.height
                                                readonly property int overlapLeft: root.tideStyle !== "Lean" ? Math.round(height / 2) : 0
                                                width: gitSegTxt.implicitWidth + 18

                                                Rectangle {
                                                    x: -parent.overlapLeft
                                                    width: parent.width + parent.overlapLeft
                                                    height: parent.height
                                                    radius: (root.tideStyle !== "Lean" && root.tideHeads === "Round") ? height / 2 : 0
                                                    color: root.prevGitBg

                                                    Text {
                                                        id: gitSegTxt
                                                        x: parent.parent.overlapLeft + 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: (root.tideIcons === "Many icons" ? " " : "") + "main +1"
                                                        font.family: root.fontFamily
                                                        font.pixelSize: root.fontSize
                                                        font.bold: true
                                                        color: root.pal.ok || "#69f0ae"
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Однострочный ввод (если One line)
                                    RowLayout {
                                        visible: root.tideHeight === "One line"
                                        spacing: 6
                                        Layout.leftMargin: 8
                                        Text {
                                            text: root.tideChar
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize + 1
                                            font.bold: true
                                            color: root.livePri
                                        }
                                        Text {
                                            text: "cmake --build build -j$(nproc)"
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                            color: root.pal.fg
                                        }
                                        Rectangle {
                                            width: root.cursorShape === "beam" ? 2 : 8
                                            height: root.cursorShape === "underline" ? 2 : (root.fontSize + 2)
                                            color: root.livePri
                                        }
                                    }

                                    // Линия соединения между левой и правой частью
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 6
                                        Layout.rightMargin: 6
                                        clip: true
                                        text: (root.tideHeight === "Two lines" && root.tideConnection !== "Disconnected")
                                              ? (root.tideConnection === "Dotted" ? "············································································" : "────────────────────────────────────────────────────────────────────────────")
                                              : ""
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        color: root.prevOsBg
                                        elide: Text.ElideRight
                                    }

                                    // Правый сегмент: время (показывается только если включено)
                                    Rectangle {
                                        visible: root.tideTime !== "No"
                                        height: parent.segH
                                        implicitWidth: timeSegTxt.implicitWidth + 16
                                        radius: (root.tideStyle !== "Lean" && (root.tideHeads === "Round" || root.tideTails === "Round")) ? height / 2 : 0
                                        color: root.tideStyle === "Lean" ? "transparent" : root.pal.high
                                        Text {
                                            id: timeSegTxt
                                            anchors.centerIn: parent
                                            text: root.tideTime === "12-hour format" ? "11:24:00 PM" : "23:24:00"
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize - 1
                                            color: root.liveSec
                                        }
                                    }

                                    Text {
                                        visible: root.tideHeight === "Two lines" && root.tideFrame
                                        text: "─╮"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 1
                                        color: root.prevOsBg
                                    }
                                }

                                // Вторая строка промпта Tide (если Two lines)
                                RowLayout {
                                    visible: root.tideEnabled && root.tideHeight === "Two lines"
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        visible: root.tideFrame
                                        text: "╰─"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 1
                                        color: root.prevOsBg
                                    }
                                    Text {
                                        text: root.tideChar
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 1
                                        font.bold: true
                                        color: root.livePri
                                    }
                                    Text {
                                        text: "git status"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        color: root.pal.fg
                                    }
                                    Rectangle {
                                        width: root.cursorShape === "beam" ? 2 : 8
                                        height: root.cursorShape === "underline" ? 2 : (root.fontSize + 2)
                                        color: root.livePri
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        visible: root.tideFrame
                                        text: "─╯"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize + 1
                                        color: root.prevOsBg
                                    }
                                }

                                // Стандартный промпт CachyOS (если Tide выключен)
                                ColumnLayout {
                                    visible: !root.tideEnabled
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "[0.002s] --> [0]"
                                        font.family: root.fontFamily
                                        font.pixelSize: root.fontSize
                                        color: root.liveSec
                                    }
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "whrr@cachyos-x8664:~/hysett (main)$"
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                            font.bold: true
                                            color: root.livePri
                                        }
                                        Text {
                                            text: "fastfetch"
                                            font.family: root.fontFamily
                                            font.pixelSize: root.fontSize
                                            color: root.pal.fg
                                        }
                                        Rectangle {
                                            width: root.cursorShape === "beam" ? 2 : 8
                                            height: root.cursorShape === "underline" ? 2 : (root.fontSize + 2)
                                            color: root.livePri
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. ШРИФТ И ВНЕШНИЙ ВИД ТЕРМИНАЛА KITTY
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: kittyCol.implicitHeight + 28

                    ColumnLayout {
                        id: kittyCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        Text {
                            text: "󰛖  Шрифт и параметры окна терминала (Kitty)"
                            color: "#ffffff"
                            font.pixelSize: Config.fontSize + 1
                            font.bold: true
                        }

                        // Шрифт из выпадающего списка
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Шрифт терминала:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            Item { Layout.fillWidth: true }
                            StyledComboBox {
                                id: fontCombo
                                Layout.preferredWidth: 320
                                model: (Config && Config.terminalFonts && Config.terminalFonts.length > 0)
                                       ? Config.terminalFonts
                                       : ["JetBrainsMono Nerd Font", "MesloLGS Nerd Font", "FiraCode Nerd Font", "Hack Nerd Font", "Monospace"]
                                currentIndex: {
                                    var m = fontCombo.model
                                    if (!m) return 0
                                    for (var i = 0; i < m.length; ++i) {
                                        if (m[i] === root.fontFamily) return i
                                    }
                                    return 0
                                }
                                onActivated: (idx) => {
                                    var chosen = fontCombo.model[idx]
                                    if (chosen && chosen !== root.fontFamily) {
                                        root.patch({ fontFamily: chosen })
                                    }
                                }
                            }
                        }

                        // Размер шрифта
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Размер шрифта:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            StyledSlider {
                                id: fontSzSlider
                                Layout.fillWidth: true
                                from: 8; to: 24; stepSize: 1
                                Binding on value {
                                    when: !fontSzSlider.pressed
                                    value: root.fontSize
                                }
                                onMoved: root.patch({ fontSize: Math.round(value) })
                            }
                            Text {
                                text: (fontSzSlider.pressed ? Math.round(fontSzSlider.value) : root.fontSize) + " pt"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 48
                                horizontalAlignment: Text.AlignRight
                            }
                            StyledButton {
                                text: "↺"
                                implicitWidth: 22
                                onClicked: root.patch({ fontSize: 11 })
                            }
                        }

                        // Внутренний отступ окна
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Внутренний отступ окна:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            StyledSlider {
                                id: padSlider
                                Layout.fillWidth: true
                                from: 0; to: 40; stepSize: 1
                                Binding on value {
                                    when: !padSlider.pressed
                                    value: root.paddingWidth
                                }
                                onMoved: root.patch({ paddingWidth: Math.round(value) })
                            }
                            Text {
                                text: (padSlider.pressed ? Math.round(padSlider.value) : root.paddingWidth) + " px"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 48
                                horizontalAlignment: Text.AlignRight
                            }
                            StyledButton {
                                text: "↺"
                                implicitWidth: 22
                                onClicked: root.patch({ paddingWidth: 12 })
                            }
                        }

                        // Прозрачность фона терминала
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Непрозрачность фона Kitty:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            StyledSlider {
                                id: bgOpSlider
                                Layout.fillWidth: true
                                from: 0.20; to: 1.00; stepSize: 0.02
                                Binding on value {
                                    when: !bgOpSlider.pressed
                                    value: root.bgOpacity
                                }
                                onMoved: root.patch({ bgOpacity: Number(value.toFixed(2)) })
                            }
                            Text {
                                text: Math.round((bgOpSlider.pressed ? bgOpSlider.value : root.bgOpacity) * 100) + "%"
                                color: "#ffffff"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 48
                                horizontalAlignment: Text.AlignRight
                            }
                            StyledButton {
                                text: "↺"
                                implicitWidth: 22
                                onClicked: root.patch({ bgOpacity: 0.92 })
                            }
                        }

                        // Форма курсора и шлейф
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Форма курсора:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            Item { Layout.fillWidth: true }
                            SegmentedButton {
                                options: ["Линия (Beam)", "Блок (Block)", "Подчерк (Underline)"]
                                selectedIndex: root.cursorShape === "block" ? 1 : (root.cursorShape === "underline" ? 2 : 0)
                                onSelected: (idx) => root.patch({ cursorShape: ["beam", "block", "underline"][idx] })
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Анимация шлейфа курсора:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            Item { Layout.fillWidth: true }
                            SegmentedButton {
                                options: ["Выкл", "Быстрый", "Плавный шлейф"]
                                selectedIndex: root.cursorTrail <= 0 ? 0 : (root.cursorTrail === 1 ? 1 : 2)
                                onSelected: (idx) => root.patch({ cursorTrail: [0, 1, 2][idx] })
                            }
                        }
                    }
                }

                // 3. ДИНАМИЧЕСКАЯ СМЕНА ТЕМЫ (ПАЛИТРА ИЗ ОБОЕВ И ПРЕСЕТЫ)
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: themeCol.implicitHeight + 28

                    ColumnLayout {
                        id: themeCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "󰏘  Динамическая смена темы (Kitty + Tide)"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 1
                                    font.bold: true
                                }
                                Text {
                                    text: "Автоматическая перекраска фона, текста и сегментов Tide при смене обоев или акцента"
                                    color: "#888888"
                                    font.pixelSize: Config.fontSize - 1
                                }
                            }
                            StyledSwitch {
                                checked: root.dynamicTheme
                                onToggled: root.patch({ dynamicTheme: checked, themePreset: checked ? 0 : (root.themePreset === 0 ? 1 : root.themePreset) })
                            }
                        }

                        RowLayout {
                            visible: !root.dynamicTheme
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: "Фиксированный пресет темы:"
                                color: "#cccccc"
                                font.pixelSize: Config.fontSize
                                Layout.preferredWidth: 220
                            }
                            Item { Layout.fillWidth: true }
                            StyledComboBox {
                                Layout.preferredWidth: 280
                                model: [
                                    "Авто (Палитра HySett)",
                                    "Catppuccin Mocha",
                                    "Tokyo Night",
                                    "Gruvbox Dark",
                                    "Nord",
                                    "Dracula",
                                    "Cyberpunk Neon"
                                ]
                                currentIndex: Math.max(0, Math.min(6, root.themePreset))
                                onActivated: (idx) => root.patch({ themePreset: idx, dynamicTheme: idx === 0 })
                            }
                        }
                    }
                }

                // 4. ПЛАГИН FISH: ILANCOSMAN/TIDE@V6
                GlassPanel {
                    objectName: "atmoObstacle"
                    Layout.fillWidth: true
                    implicitHeight: tideCol.implicitHeight + 28
                    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

                    ColumnLayout {
                        id: tideCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "󰈺  Плагин командной строки IlanCosman/tide@v6"
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize + 1
                                    font.bold: true
                                }
                                Text {
                                    text: root.tideEnabled
                                          ? "Активен промпт Tide v6 (перекрывает стандартный промпт CachyOS)"
                                          : "Tide отключен — используется стандартный промпт CachyOS"
                                    color: root.tideEnabled ? (Config ? Config.m3Primary : "#69f0ae") : "#888888"
                                    font.pixelSize: Config.fontSize - 1
                                }
                            }

                            StyledButton {
                                text: "󰑐 Переустановить Tide v6"
                                onClicked: if (Config) Config.reinstallTidePlugin()
                            }

                            StyledSwitch {
                                checked: root.tideEnabled
                                onToggled: root.patch({ tideEnabled: checked })
                            }
                        }

                        ColumnLayout {
                            visible: root.tideEnabled
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            // Стиль промпта
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Стиль промпта Tide:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Rainbow (Цветные плашки)", "Classic (Классика)", "Lean (Минимализм)"]
                                    selectedIndex: root.tideStyle === "Classic" ? 1 : (root.tideStyle === "Lean" ? 2 : 0)
                                    onSelected: (idx) => root.patch({ tideStyle: ["Rainbow", "Classic", "Lean"][idx] })
                                }
                            }

                            // Высота (1 или 2 строки)
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Высота промпта:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Две строки (Two lines)", "Одна строка (One line)"]
                                    selectedIndex: root.tideHeight === "One line" ? 1 : 0
                                    onSelected: (idx) => root.patch({ tideHeight: idx === 1 ? "One line" : "Two lines" })
                                }
                            }

                            // Форма наконечников и разделителей (для Rainbow / Classic)
                            RowLayout {
                                visible: root.tideStyle !== "Lean"
                                Layout.fillWidth: true
                                Text {
                                    text: "Форма краёв сегментов:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Круглые ", "Острые ", "Скошенные "]
                                    selectedIndex: root.tideHeads === "Sharp" ? 1 : (root.tideHeads === "Slanted" ? 2 : 0)
                                    onSelected: (idx) => {
                                        var shape = ["Round", "Sharp", "Slanted"][idx]
                                        var sep = ["Round", "Angled", "Slanted"][idx]
                                        root.patch({ tideHeads: shape, tideTails: shape, tideSeparators: sep })
                                    }
                                }
                            }

                            // Линия соединения (для Two lines)
                            RowLayout {
                                visible: root.tideHeight === "Two lines"
                                Layout.fillWidth: true
                                Text {
                                    text: "Линия между краями:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Точки (···)", "Сплошная (───)", "Без линии"]
                                    selectedIndex: root.tideConnection === "Solid" ? 1 : (root.tideConnection === "Disconnected" ? 2 : 0)
                                    onSelected: (idx) => root.patch({ tideConnection: ["Dotted", "Solid", "Disconnected"][idx] })
                                }
                            }

                            // Боковая рамка (╭─ / ╰─)
                            RowLayout {
                                visible: root.tideHeight === "Two lines" && root.tideStyle !== "Lean"
                                Layout.fillWidth: true
                                Text {
                                    text: "Боковая рамка (╭─ и ╰─):"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: root.tideFrame
                                    onToggled: root.patch({ tideFrame: checked })
                                }
                            }

                            // Формат времени
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Отображение времени справа:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["24 часа", "12 часов", "Выкл"]
                                    selectedIndex: root.tideTime === "12-hour format" ? 1 : (root.tideTime === "No" ? 2 : 0)
                                    onSelected: (idx) => root.patch({ tideTime: ["24-hour format", "12-hour format", "No"][idx] })
                                }
                            }

                            // Иконки
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Иконки и логотип ОС:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Много иконок + лого ОС", "Минимум иконок"]
                                    selectedIndex: root.tideIcons === "Few icons" ? 1 : 0
                                    onSelected: (idx) => root.patch({ tideIcons: idx === 1 ? "Few icons" : "Many icons" })
                                }
                            }

                            // Интервал между командами
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Интервал между командами:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    options: ["Компактный", "Пустая строка перед промптом"]
                                    selectedIndex: root.tideSpacing === "Sparse" ? 1 : 0
                                    onSelected: (idx) => root.patch({ tideSpacing: idx === 1 ? "Sparse" : "Compact" })
                                }
                            }

                            // Символ ввода
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Символ приглашения ввода:"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.preferredWidth: 220
                                }
                                Item { Layout.fillWidth: true }
                                SegmentedButton {
                                    readonly property var chars: ["❯", "➜", "λ", "$", "󰄾", "▶"]
                                    options: chars
                                    selectedIndex: {
                                        var idx = chars.indexOf(root.tideChar)
                                        return idx >= 0 ? idx : 0
                                    }
                                    onSelected: (idx) => root.patch({ tideChar: ["❯", "➜", "λ", "$", "󰄾", "▶"][idx] })
                                }
                            }

                            // Transient prompt
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Сворачивать выполненные строки к символу ❯ (Transient):"
                                    color: "#cccccc"
                                    font.pixelSize: Config.fontSize
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: root.tideTransient
                                    onToggled: root.patch({ tideTransient: checked })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
