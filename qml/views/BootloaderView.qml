import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

Item {
    id: bootRoot
    readonly property bool isM3: Theme && Theme.isRounded
    property bool showLegacyDrives: false
    property bool pwdModalOpen: false
    property var pendingActionFn: null
    property int draggingRow: -1

    function isLegacyDummy(title) {
        var t = String(title || "").toLowerCase().trim()
        return t === "hard drive" || t === "cd/dvd drive" || t === "usb hdd" || t === "usb fdd" || t === "network" || t === "uefi: built-in efi shell"
    }

    function runWithAdminAuth(fn) {
        if (Config && Config.hasBootAdminPassword()) {
            fn()
        } else {
            bootRoot.pendingActionFn = fn
            pwdInput.text = ""
            bootRoot.pwdModalOpen = true
            Qt.callLater(() => pwdInput.forceActiveFocus())
        }
    }

    function rebuildEfiModel() {
        if (bootRoot.draggingRow >= 0) return
        efiListModel.clear()
        var raw = Config ? Config.bootloaderEfiEntries : []
        for (var i = 0; i < raw.length; ++i) {
            var it = raw[i]
            if (bootRoot.showLegacyDrives || !bootRoot.isLegacyDummy(it.title)) {
                efiListModel.append({
                    num: String(it.num || ""),
                    title: String(it.title || ""),
                    is_first: (efiListModel.count === 0)
                })
            }
        }
    }

    onShowLegacyDrivesChanged: rebuildEfiModel()

    Connections {
        target: Config
        function onBootloaderChanged() {
            bootRoot.rebuildEfiModel()
            if (Config && Config.bootloaderAuthError) {
                bootRoot.pwdModalOpen = true
                Qt.callLater(() => pwdInput.forceActiveFocus())
            }
        }
    }

    Component.onCompleted: {
        if (Config) Config.refreshBootloaderState()
        rebuildEfiModel()
    }
    onVisibleChanged: {
        if (!visible) bootRoot.pwdModalOpen = false
        if (visible && Config) Config.refreshBootloaderState()
    }

    ListModel {
        id: efiListModel
    }

    // Обертка для шейдерного размытия при открытии внутреннего окна пароля
    Item {
        id: bootBlurTarget
        anchors.fill: parent
        layer.enabled: bootRoot.pwdModalOpen && (!Config || Config.dialogBlur > 0.01)
        layer.smooth: true
        layer.effect: ShaderEffect {
            property var source: bootBlurTarget
            property vector2d u_resolution: Qt.vector2d(Math.max(1, bootBlurTarget.width), Math.max(1, bootBlurTarget.height))
            property real u_blur: Config ? Config.dialogBlur : 0.65
            fragmentShader: "qrc:/shaders/qml/shaders/dialog_blur.frag.qsb"
        }

        ScrollView {
            id: bootScroll
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true

            Item {
                width: bootScroll.availableWidth
                implicitHeight: bootCol.implicitHeight + 44

                ColumnLayout {
                    id: bootCol
                    width: Math.min(parent.width - 48, 860)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󰍛  Загрузчик системы и автовыбор ОС"
                            color: "#ffffff"
                            font.pixelSize: Config ? Config.fontSize + 3 : 14
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        StyledButton {
                            text: "󰑐 Обновить"
                            onClicked: if (Config) Config.refreshBootloaderState()
                        }
                    }

                    // 1. КАРТОЧКА ПАРАМЕТРОВ ВРЕМЕНИ И АВТОВЫБОРА
                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: cfgCol.implicitHeight + 28

                        ColumnLayout {
                            id: cfgCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle {
                                    width: 9; height: 9; radius: 4.5
                                    color: "#69f0ae"
                                }
                                Text {
                                    text: Config ? Config.bootloaderStatus : "Загрузчик"
                                    color: Config ? Config.m3Primary : "#a8c7fa"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    text: "Время ожидания перед автовыбором:"
                                    color: "#cccccc"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    Layout.preferredWidth: 250
                                }
                                StyledSlider {
                                    id: toSlider
                                    Layout.fillWidth: true
                                    from: 0; to: 30; stepSize: 1
                                    value: Config ? Config.bootloaderTimeout : 5
                                    onPressedChanged: {
                                        if (!pressed && Config) {
                                            var v = Math.round(value)
                                            bootRoot.runWithAdminAuth(function() {
                                                Config.applyBootloaderSettings(v, Config.bootloaderSavedDefault, Config.bootloaderEditor)
                                            })
                                        }
                                    }
                                }
                                Text {
                                    text: Math.round(toSlider.value) + " сек"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    font.bold: true
                                    Layout.preferredWidth: 64
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Запоминать последнюю выбранную вручную ОС (@saved):"
                                    color: "#cccccc"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Config ? Config.bootloaderSavedDefault : false
                                    onToggled: {
                                        var c = checked
                                        bootRoot.runWithAdminAuth(function() {
                                            if (Config) Config.applyBootloaderSettings(Config.bootloaderTimeout, c, Config.bootloaderEditor)
                                        })
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Открыть настройки BIOS / UEFI при следующей обычной перезагрузке:"
                                    color: "#cccccc"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Config ? Config.bootloaderFwNext : false
                                    onToggled: {
                                        var c = checked
                                        bootRoot.runWithAdminAuth(function() {
                                            if (Config) Config.setFirmwareNextBoot(c)
                                        })
                                    }
                                }
                            }

                            RowLayout {
                                visible: !Config || Config.bootloaderType === "systemd-boot"
                                Layout.fillWidth: true
                                Text {
                                    text: "Разрешить редактирование параметров ядра в меню загрузки (клавиша E):"
                                    color: "#cccccc"
                                    font.pixelSize: Config ? Config.fontSize : 11
                                    Layout.fillWidth: true
                                }
                                StyledSwitch {
                                    checked: Config ? Config.bootloaderEditor : true
                                    onToggled: {
                                        var c = checked
                                        bootRoot.runWithAdminAuth(function() {
                                            if (Config) Config.applyBootloaderSettings(Config.bootloaderTimeout, Config.bootloaderSavedDefault, c)
                                        })
                                    }
                                }
                            }
                        }
                    }

                    // 2. КАРТОЧКА ЗАГРУЗОЧНЫХ ЗАПИСЕЙ (ЕСЛИ SYSTEMD-BOOT / GRUB / LIMINE)
                    GlassPanel {
                        visible: Config && Config.bootloaderEntries.length > 0
                        Layout.fillWidth: true
                        implicitHeight: entriesCol.implicitHeight + 28

                        ColumnLayout {
                            id: entriesCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                text: "󰌽  Загрузочные записи (" + (Config ? Config.bootloaderEntries.length : 0) + ")"
                                color: "#ffffff"
                                font.pixelSize: Config ? Config.fontSize + 1 : 12
                                font.bold: true
                            }

                            Item {
                                id: entriesListBox
                                Layout.fillWidth: true
                                implicitHeight: entriesInnerCol.implicitHeight
                                property bool isHovering: false
                                property real hovY: 0
                                property real hovH: 48

                                Timer {
                                    id: entriesHoverHold
                                    interval: 45
                                    onTriggered: entriesListBox.isHovering = false
                                }

                                Rectangle {
                                    z: 1
                                    opacity: entriesListBox.isHovering ? 1.0 : 0.0
                                    x: 0; y: entriesListBox.hovY
                                    width: entriesListBox.width; height: entriesListBox.hovH
                                    radius: bootRoot.isM3 ? 10 : 0
                                    color: bootRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.14)
                                           : Qt.rgba(1, 1, 1, 0.10)
                                    border.width: 1
                                    border.color: bootRoot.isM3 && Config
                                                  ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, 0.42)
                                                  : Qt.rgba(1, 1, 1, 0.24)
                                    Behavior on y { NumberAnimation { duration: 185; easing.type: Easing.OutQuint } }
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                ColumnLayout {
                                    id: entriesInnerCol
                                    z: 2; width: parent.width; spacing: 6

                                    Repeater {
                                        model: Config ? Config.bootloaderEntries : []
                                        delegate: Rectangle {
                                            id: entryRowRect
                                            Layout.fillWidth: true; implicitHeight: 48
                                            radius: bootRoot.isM3 ? 10 : 0
                                            color: modelData.is_default
                                                   ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.16)
                                                   : Qt.rgba(1, 1, 1, 0.04)
                                            border.color: modelData.is_default ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                                                onEntered: {
                                                    entriesHoverHold.stop()
                                                    entriesListBox.hovY = entryRowRect.y
                                                    entriesListBox.hovH = entryRowRect.height
                                                    entriesListBox.isHovering = true
                                                }
                                                onExited: entriesHoverHold.restart()
                                            }

                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 10
                                                Item {
                                                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                                    readonly property bool isCachy: String(modelData.title).toLowerCase().indexOf("cachy") !== -1
                                                    Image {
                                                        visible: parent.isCachy
                                                        anchors.centerIn: parent
                                                        width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                                                        source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                                                    }
                                                    Text {
                                                        visible: !parent.isCachy
                                                        anchors.centerIn: parent
                                                        text: String(modelData.title).toLowerCase().indexOf("windows") !== -1 ? "󰍲" : "󰌽"
                                                        color: modelData.is_default ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                        font.pixelSize: 17
                                                    }
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 2
                                                    Text {
                                                        text: modelData.title
                                                        color: "#ffffff"; font.pixelSize: Config ? Config.fontSize : 11; font.bold: true
                                                        elide: Text.ElideRight; Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: (modelData.version && modelData.version.length > 0 ? ("Ядро / Версия: " + modelData.version + "  •  ") : "") + "ID: " + modelData.id
                                                        color: "#888888"; font.pixelSize: Config ? Config.fontSize - 2 : 9
                                                        elide: Text.ElideRight; Layout.fillWidth: true
                                                    }
                                                }
                                                StyledButton {
                                                    visible: !modelData.is_default
                                                    text: "󰄬 По умолчанию"
                                                    implicitHeight: 24
                                                    onClicked: {
                                                        var eid = modelData.id
                                                        bootRoot.runWithAdminAuth(function() { if (Config) Config.setDefaultBootEntry(eid) })
                                                    }
                                                }
                                                StyledButton {
                                                    text: "󰜉 Загрузить сейчас"
                                                    implicitHeight: 24
                                                                                                        onClicked: {
                                                        var eid = modelData.id
                                                        bootRoot.runWithAdminAuth(function() { if (Config) Config.bootEntryOneshot(eid, true) })
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. КАРТОЧКА ПОРЯДКА ЗАГРУЗКИ BIOS / UEFI (ПЕРЕТАСКИВАНИЕ ЗАЖАТИЕМ МЫШИ) + BIOS И ФЛЕШКА ВНИЗУ
                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: efiCol.implicitHeight + 28

                        ColumnLayout {
                            id: efiCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "󰍛  Порядок загрузки BIOS / UEFI • Зажмите строку для перетаскивания (" + efiListModel.count + ")"
                                    color: "#ffffff"
                                    font.pixelSize: Config ? Config.fontSize + 1 : 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                StyledButton {
                                    text: bootRoot.showLegacyDrives ? "󰈉 Скрыть пустые диски" : "󰈈 Показать все"
                                    implicitHeight: 22
                                    onClicked: bootRoot.showLegacyDrives = !bootRoot.showLegacyDrives
                                }
                            }

                            Item {
                                id: efiListWrap
                                Layout.fillWidth: true
                                implicitHeight: Math.max(46, efiListModel.count * 50 - 6)
                                property bool isHovering: false
                                property int lastHoveredRow: 0

                                Timer {
                                    id: efiHoverHold
                                    interval: 45
                                    onTriggered: if (bootRoot.draggingRow < 0) efiListWrap.isHovering = false
                                }

                                Rectangle {
                                    z: 1
                                    visible: efiListModel.count > 0
                                    opacity: (efiListWrap.isHovering || bootRoot.draggingRow >= 0) ? 1.0 : 0.0
                                    x: 0
                                    y: (bootRoot.draggingRow >= 0 ? bootRoot.draggingRow : efiListWrap.lastHoveredRow) * 50
                                    width: efiListWrap.width
                                    height: 44
                                    radius: bootRoot.isM3 ? 10 : 0
                                    color: bootRoot.isM3 && Config
                                           ? Qt.rgba(Config.m3Primary.r, Config.m3Primary.g, Config.m3Primary.b, bootRoot.draggingRow >= 0 ? 0.26 : 0.14)
                                           : Qt.rgba(1, 1, 1, bootRoot.draggingRow >= 0 ? 0.18 : 0.10)
                                    border.width: 0
                                    Behavior on y { NumberAnimation { duration: 175; easing.type: Easing.OutQuint } }
                                    Behavior on opacity { NumberAnimation { duration: 115 } }
                                }

                                ListView {
                                    id: efiListView
                                    z: 2
                                    anchors.fill: parent
                                    interactive: false
                                    spacing: 6
                                    model: efiListModel

                                    move: Transition {
                                        NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuint }
                                    }
                                    moveDisplaced: Transition {
                                        NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutQuint }
                                    }

                                    delegate: Rectangle {
                                        id: efiRowRect
                                        width: efiListView.width
                                        height: 44
                                        z: isBeingDragged ? 20 : 1
                                        scale: 1.0
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                        readonly property bool isBeingDragged: bootRoot.draggingRow === index
                                        readonly property bool isTopItem: index === 0
                                        radius: bootRoot.isM3 ? 10 : 0
                                        color: isTopItem
                                               ? Qt.rgba(Config ? Config.m3Primary.r : 0.6, Config ? Config.m3Primary.g : 0.8, Config ? Config.m3Primary.b : 1.0, 0.12)
                                               : Qt.rgba(1, 1, 1, 0.04)
                                        border.color: (isTopItem || isBeingDragged) ? (Config ? Config.m3Primary : "#a8c7fa") : Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1

                                        MouseArea {
                                            id: rowDragMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            preventStealing: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            property bool orderChangedDuringDrag: false

                                            onEntered: {
                                                efiHoverHold.stop()
                                                efiListWrap.lastHoveredRow = index
                                                efiListWrap.isHovering = true
                                            }
                                            onExited: efiHoverHold.restart()

                                            onPressed: (mouse) => {
                                                efiHoverHold.stop()
                                                orderChangedDuringDrag = false
                                                bootRoot.draggingRow = index
                                                efiListWrap.lastHoveredRow = index
                                                efiListWrap.isHovering = true
                                            }
                                            onPositionChanged: (mouse) => {
                                                if (!pressed) return
                                                var posInList = rowDragMa.mapToItem(efiListView, 0, mouse.y).y
                                                var targetIdx = Math.max(0, Math.min(efiListModel.count - 1, Math.floor(posInList / 50)))
                                                if (targetIdx !== index) {
                                                    efiListModel.move(index, targetIdx, 1)
                                                    bootRoot.draggingRow = targetIdx
                                                    efiListWrap.lastHoveredRow = targetIdx
                                                    orderChangedDuringDrag = true
                                                }
                                            }
                                            onReleased: {
                                                bootRoot.draggingRow = -1
                                                if (orderChangedDuringDrag && Config) {
                                                    var nums = []
                                                    for (var i = 0; i < efiListModel.count; ++i) {
                                                        nums.push(efiListModel.get(i).num)
                                                    }
                                                    var joined = nums.join(",")
                                                    bootRoot.runWithAdminAuth(function() {
                                                        Config.reorderEfiBootEntries(joined)
                                                    })
                                                }
                                            }
                                            onCanceled: {
                                                bootRoot.draggingRow = -1
                                            }
                                        }

                                        RowLayout {
                                            z: 5
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text {
                                                text: "󰍜"
                                                color: efiRowRect.isTopItem ? "#69f0ae" : "#888888"
                                                font.pixelSize: 14
                                            }

                                            Item {
                                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                                readonly property bool isCachy: String(model.title).toLowerCase().indexOf("cachy") !== -1
                                                Image {
                                                    visible: parent.isCachy
                                                    anchors.centerIn: parent
                                                    width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                                                    source: "file:///home/whrr/.config/hypr/scripts/cachyos_logo.svg"
                                                }
                                                Text {
                                                    visible: !parent.isCachy
                                                    anchors.centerIn: parent
                                                    text: String(model.title).toLowerCase().indexOf("windows") !== -1 ? "󰍲" : "󰌽"
                                                    color: efiRowRect.isTopItem ? "#69f0ae" : (Config ? Config.m3Primary : "#a8c7fa")
                                                    font.pixelSize: 16
                                                }
                                            }

                                            Text {
                                                text: "Boot" + model.num
                                                color: efiRowRect.isTopItem ? "#69f0ae" : "#aaaaaa"
                                                font.family: "monospace"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: true
                                            }

                                            Text {
                                                text: model.title
                                                color: "#ffffff"
                                                font.pixelSize: Config ? Config.fontSize : 11
                                                font.bold: efiRowRect.isTopItem
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            StyledButton {
                                                text: "󰜉 Загрузить сейчас"
                                                implicitHeight: 24
                                                                                                onClicked: {
                                                    var bnum = model.num
                                                    bootRoot.runWithAdminAuth(function() {
                                                        if (Config) Config.bootEfiNext(bnum, true)
                                                    })
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                implicitHeight: 32
                                text: "󰍛  Перезагрузиться в BIOS"
                                onClicked: {
                                    bootRoot.runWithAdminAuth(function() {
                                        if (Config) Config.rebootToFirmware()
                                    })
                                }
                            }

                            StyledButton {
                                Layout.fillWidth: true
                                allowFullWidth: true
                                implicitHeight: 32
                                text: (Config && Config.bootloaderUsbName.length > 0)
                                      ? ("󰕓  Загрузиться с загрузочной флешки (" + Config.bootloaderUsbName + ")")
                                      : "󰕓  Загрузиться с загрузочной флешки"
                                onClicked: {
                                    bootRoot.runWithAdminAuth(function() {
                                        if (Config) Config.bootFromUsbDrive()
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // ВНУТРЕННЕЕ МОДАЛЬНОЕ ОКНО ПОДТВЕРЖДЕНИЯ ПАРОЛЯ HYSETT
    // =========================================================================
    Rectangle {
        visible: bootRoot.pwdModalOpen
        anchors.fill: parent
        z: 500
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: {
                bootRoot.pwdModalOpen = false
                if (Config) Config.refreshBootloaderState()
            }
        }

        GlassPanel {
            anchors.centerIn: parent
            width: 370
            implicitHeight: pwdModalCol.implicitHeight + 32
            radius: bootRoot.isM3 ? 16 : 0

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: pwdModalCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰌾  Подтверждение доступа"
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 2 : 13
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: "󰅖"
                        isIconOnly: true
                        implicitWidth: 24; implicitHeight: 24
                        onClicked: {
                            bootRoot.pwdModalOpen = false
                            if (Config) Config.refreshBootloaderState()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: (Config && Config.bootloaderAuthError)
                          ? "Неверный пароль! Введите пароль пользователя для изменения параметров загрузчика:"
                          : "Введите пароль пользователя для сохранения настроек загрузчика (запрашивается 1 раз за сеанс):"
                    color: (Config && Config.bootloaderAuthError) ? "#ff6b6b" : "#cccccc"
                    font.pixelSize: Config ? Config.fontSize : 11
                }

                TextField {
                    id: pwdInput
                    Layout.fillWidth: true
                    implicitHeight: 32
                    leftPadding: 12; rightPadding: 12
                    echoMode: TextInput.Password
                    color: "#ffffff"
                    font.pixelSize: Config ? Config.fontSize : 11
                    placeholderText: "Пароль администратора (sudo)..."
                    placeholderTextColor: "#777777"
                    onAccepted: confirmPwdBtn.clicked()
                    Keys.onEscapePressed: {
                        bootRoot.pwdModalOpen = false
                        if (Config) Config.refreshBootloaderState()
                    }
                    background: Rectangle {
                        radius: bootRoot.isM3 ? 8 : 0
                        color: bootRoot.isM3 && Config ? Config.m3SurfaceContainerHigh : Qt.rgba(1, 1, 1, 0.08)
                        border.color: (Config && Config.bootloaderAuthError) ? "#ff6b6b" : (Config ? Config.m3Primary : "#ffffff")
                        border.width: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    StyledButton {
                        text: "Отмена"
                        implicitHeight: 28
                        onClicked: {
                            bootRoot.pwdModalOpen = false
                            if (Config) Config.refreshBootloaderState()
                        }
                    }
                    StyledButton {
                        id: confirmPwdBtn
                        text: "󰄬 Подтвердить"
                        isActive: true
                        implicitHeight: 28
                        enabled: pwdInput.text.length > 0
                        onClicked: {
                            if (!Config || pwdInput.text.length === 0) return
                            Config.setBootAdminPassword(pwdInput.text)
                            bootRoot.pwdModalOpen = false
                            if (bootRoot.pendingActionFn) {
                                var fn = bootRoot.pendingActionFn
                                bootRoot.pendingActionFn = null
                                fn()
                            }
                        }
                    }
                }
            }
        }
    }
}
