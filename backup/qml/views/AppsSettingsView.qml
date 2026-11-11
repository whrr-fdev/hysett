import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    id: appScroll
    contentWidth: availableWidth
    clip: true

    property string selectedCat: "Все"
    property int selectedIdx: 0
    property string searchQuery: ""
    property int kbIndex: 0

    // Состояние контекстного меню и модального окна действий с пакетами
    property var ctxApp: null
    property var uninstallInfo: null
    property string modalAction: "uninstall" // "uninstall" | "install"
    property string modalPkgName: ""
    property string modalPkgRepo: ""
    property string modalPkgVersion: ""
    property string modalFlatpakId: ""
    property string modalDesktopPath: ""
    property string modalAppName: ""
    property string modalAppIcon: "application-x-executable"

    function isEn() {
        return Config && Config.language === "en"
    }

    function openAppContextMenu(appData, globalX, globalY) {
        ctxApp = appData
        var menuW = 240
        var menuH = 186
        ctxPopup.x = Math.max(8, Math.min(globalX, appScroll.width - menuW - 12))
        ctxPopup.y = Math.max(8, Math.min(globalY, appScroll.height - menuH - 12))
        ctxPopup.open()
    }

    function openUninstallDialog(appData) {
        ctxApp = appData
        Apps.resetPkgActionState()
        pwdInput.text = ""
        uninstallInfo = Apps.getAppUninstallInfo(appData.desktopPath || "", appData.exec || "")
        modalAction = "uninstall"
        modalAppName = appData.name || ""
        modalAppIcon = appData.icon || "application-x-executable"
        modalDesktopPath = appData.desktopPath || ""
        modalPkgName = uninstallInfo ? (uninstallInfo.packageName || "") : ""
        modalPkgVersion = uninstallInfo ? (uninstallInfo.packageVersion || "") : ""
        modalPkgRepo = "system"
        modalFlatpakId = uninstallInfo ? (uninstallInfo.flatpakId || "") : ""
        pkgActionPopup.open()
        Qt.callLater(() => pwdInput.forceActiveFocus())
    }

    function openPackageModal(pkgData, act) {
        ctxApp = null
        uninstallInfo = null
        Apps.resetPkgActionState()
        pwdInput.text = ""
        modalAction = act
        modalAppName = pkgData.name || ""
        modalAppIcon = "application-x-executable"
        modalDesktopPath = ""
        modalPkgName = pkgData.name || ""
        modalPkgVersion = pkgData.version || ""
        modalPkgRepo = pkgData.repo || "extra"
        modalFlatpakId = ""
        pkgActionPopup.open()
        Qt.callLater(() => pwdInput.forceActiveFocus())
    }

    function submitModalAction() {
        if (Apps.isPkgActionRunning) return
        var needsPwd = (modalPkgName.length > 0 || modalFlatpakId.length > 0)
        if (needsPwd && pwdInput.text.length === 0) {
            pwdInput.forceActiveFocus()
            return
        }
        Apps.executePackageAction(
            modalAction,
            modalPkgName,
            modalPkgRepo,
            modalFlatpakId,
            modalDesktopPath,
            pwdInput.text
        )
    }

    Connections {
        target: Apps
        function onPkgActionStateChanged() {
            if (Apps.pkgActionFinished && Apps.pkgActionSuccess) {
                autoCloseModalTimer.restart()
            }
        }
    }

    Timer {
        id: autoCloseModalTimer
        interval: 900
        repeat: false
        onTriggered: {
            pkgActionPopup.close()
            pwdInput.text = ""
        }
    }

    Timer {
        id: pkgSearchDebounce
        interval: 280
        repeat: false
        onTriggered: {
            if (appScroll.selectedCat === "Пакеты" && searchField.text.trim().length >= 2) {
                Apps.searchPackages(searchField.text.trim())
            }
        }
    }

    function focusSearchInput() {
        searchField.forceActiveFocus()
        focusRetryTimer.restart()
    }

    function visibleCards() {
        var arr = []
        for (var i = 0; i < appsRepeater.count; ++i) {
            var it = appsRepeater.itemAt(i)
            if (it && it.visible) arr.push(it)
        }
        return arr
    }

    function selectByKb(newIdx) {
        var vis = visibleCards()
        if (vis.length === 0) {
            appsGridWrapper.hoveredAppObj = null
            return
        }
        kbIndex = Math.max(0, Math.min(vis.length - 1, newIdx))
        var target = vis[kbIndex]
        appsGridWrapper.lastHoveredAppObj = target
        appsGridWrapper.hoveredAppObj = target

        var cardTop = appsGridOuter.y + target.y
        var cardBot = cardTop + target.height + 24
        var flk = appScroll.contentItem
        if (flk) {
            if (cardTop < flk.contentY + 40) flk.contentY = Math.max(0, cardTop - 40)
            else if (cardBot > flk.contentY + appScroll.height) flk.contentY = cardBot - appScroll.height
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 45
        repeat: false
        onTriggered: {
            if (appScroll.visible) {
                searchField.forceActiveFocus()
                appScroll.selectByKb(0)
            }
        }
    }

    onVisibleChanged: if (visible) focusSearchInput()
    Component.onCompleted: if (visible) focusSearchInput()

    ParallelAnimation {
        id: appsGridSlideAnim
        NumberAnimation { id: gridSlideX; target: appsGridWrapper; property: "x"; to: 0; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: appsGridWrapper; property: "opacity"; from: 0.15; to: 1.0; duration: 200 }
    }

    // ───────────────────────── Выпадающее ПКМ-меню (Чёрное + Блюр) ─────────────────────────
    Popup {
        id: ctxPopup
        parent: appScroll
        width: 240
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 110; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.92; to: 1.0; duration: 130; easing.type: Easing.OutBack }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 90 }
        }

        background: Item {
            id: ctxBgRoot
            property real rad: (Theme && Theme.isRounded) ? 7 : 0

            // Реальный блюр области под меню через понижение разрешения + билинейную фильтрацию
            Item {
                anchors.fill: parent
                clip: true
                ShaderEffectSource {
                    id: ctxBlurSource
                    anchors.fill: parent
                    sourceItem: pageContentRoot
                    sourceRect: Qt.rect(
                        ctxPopup.x,
                        ctxPopup.y + (appScroll.contentItem ? appScroll.contentItem.contentY : 0),
                        ctxBgRoot.width,
                        ctxBgRoot.height
                    )
                    textureSize: Qt.size(Math.max(1, Math.round(ctxBgRoot.width / 6)), Math.max(1, Math.round(ctxBgRoot.height / 6)))
                    smooth: true
                    live: ctxPopup.visible
                }
            }

            GlassPanel {
                anchors.fill: parent
                radius: ctxBgRoot.rad
                tintColor: Qt.rgba(0.02, 0.02, 0.02, 0.90)
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.20)
                    border.width: 1
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 4
                spacing: 8
                Image {
                    source: appScroll.ctxApp ? ("image://appicon/" + appScroll.ctxApp.icon) : ""
                    sourceSize.width: 18; sourceSize.height: 18
                    Layout.preferredWidth: 18; Layout.preferredHeight: 18
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    text: appScroll.ctxApp ? appScroll.ctxApp.name : ""
                    color: "#ffffff"
                    font.pixelSize: Config ? Config.fontSize - 1 : 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.10)
                Layout.bottomMargin: 2
            }

            Repeater {
                model: [
                    {
                        icon: "🚀",
                        label: appScroll.isEn() ? "Launch application" : "Запустить",
                        action: "launch",
                        danger: false
                    },
                    {
                        icon: "󰆏",
                        label: appScroll.isEn() ? "Copy Exec command" : "Скопировать команду",
                        action: "copy_exec",
                        danger: false
                    },
                    {
                        icon: "󰉋",
                        label: appScroll.isEn() ? "Open shortcut folder" : "Открыть папку ярлыка",
                        action: "open_folder",
                        danger: false
                    },
                    {
                        icon: "󰈉",
                        label: appScroll.isEn() ? "Hide from launcher" : "Скрыть из списка",
                        action: "hide",
                        danger: false
                    },
                    {
                        icon: "󰩺",
                        label: appScroll.isEn() ? "Uninstall / Delete..." : "Удалить приложение...",
                        action: "uninstall",
                        danger: true
                    }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: (Theme && Theme.isRounded) ? 4 : 0
                    color: rowMouse.containsMouse
                           ? (modelData.danger ? Qt.rgba(1.0, 0.25, 0.25, 0.22) : Qt.rgba(1, 1, 1, 0.12))
                           : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: modelData.icon
                            color: modelData.danger ? "#ff6b6b" : "#dddddd"
                            font.pixelSize: Config ? Config.fontSize : 13
                            Layout.preferredWidth: 18
                        }
                        Text {
                            text: modelData.label
                            color: modelData.danger ? "#ff6b6b" : (rowMouse.containsMouse ? "#ffffff" : "#cccccc")
                            font.pixelSize: Config ? Config.fontSize - 1 : 12
                            font.bold: modelData.danger
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var app = appScroll.ctxApp
                            ctxPopup.close()
                            if (!app) return
                            if (modelData.action === "launch") {
                                Apps.launchApp(app.exec)
                            } else if (modelData.action === "copy_exec") {
                                Apps.copyPath(app.exec)
                            } else if (modelData.action === "open_folder") {
                                Apps.openContainingFolder(app.desktopPath || "")
                            } else if (modelData.action === "hide") {
                                Apps.removeOrHideShortcut(app.desktopPath || "")
                            } else if (modelData.action === "uninstall") {
                                appScroll.openUninstallDialog(app)
                            }
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── Модальное окно удаления / установки (Чёрное + Блюр + Пароль) ─────────────────────────
    Popup {
        id: pkgActionPopup
        parent: appScroll
        anchors.centerIn: parent
        width: Math.min(appScroll.width - 40, 450)
        padding: 16
        modal: true
        focus: true
        closePolicy: Apps.isPkgActionRunning ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

        Overlay.modal: Item {
            // Размытие всего фона страницы под модальным окном
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: pageContentRoot
                sourceRect: Qt.rect(
                    0,
                    appScroll.contentItem ? appScroll.contentItem.contentY : 0,
                    appScroll.width,
                    appScroll.height
                )
                textureSize: Qt.size(Math.max(1, Math.round(appScroll.width / 7)), Math.max(1, Math.round(appScroll.height / 7)))
                smooth: true
                live: pkgActionPopup.visible
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.68)
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 140 }
                NumberAnimation { property: "scale"; from: 0.93; to: 1.0; duration: 160; easing.type: Easing.OutBack }
            }
        }

        background: GlassPanel {
            radius: (Theme && Theme.isRounded) ? 8 : 0
            tintColor: Qt.rgba(0.02, 0.02, 0.02, 0.93)
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: appScroll.modalAction === "install"
                              ? Qt.rgba(0.35, 0.85, 1.0, 0.42)
                              : Qt.rgba(1.0, 0.35, 0.35, 0.38)
                border.width: 1
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Image {
                    source: "image://appicon/" + appScroll.modalAppIcon
                    sourceSize.width: 32; sourceSize.height: 32
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    fillMode: Image.PreserveAspectFit
                }
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: appScroll.modalAppName
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize + 2 : 15
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: appScroll.modalAction === "install"
                              ? (appScroll.isEn() ? "Package installation" : "Установка пакета в систему")
                              : (appScroll.isEn() ? "Application removal" : "Удаление приложения")
                        color: "#888888"
                        font.pixelSize: Config ? Config.fontSize - 2 : 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.10)
            }

            // Информация о пакете
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoCol.implicitHeight + 16
                radius: (Theme && Theme.isRounded) ? 5 : 0
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: "#dddddd"
                        font.pixelSize: Config ? Config.fontSize - 1 : 12
                        text: {
                            if (appScroll.modalPkgName.length > 0) {
                                var prefix = (appScroll.modalPkgRepo === "aur") ? "󰣇 AUR (yay): " : "󰣇 Pacman: "
                                return prefix + appScroll.modalPkgName + (appScroll.modalPkgVersion.length > 0 ? (" " + appScroll.modalPkgVersion) : "")
                            }
                            if (appScroll.modalFlatpakId.length > 0) {
                                return "󰏖 Flatpak: " + appScroll.modalFlatpakId
                            }
                            return appScroll.isEn() ? "󰈔 Local shortcut (.desktop)" : "󰈔 Пользовательский ярлык (.desktop)"
                        }
                    }

                    Text {
                        visible: appScroll.modalDesktopPath.length > 0
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        color: "#777777"
                        font.pixelSize: Config ? Config.fontSize - 2 : 11
                        text: appScroll.modalDesktopPath
                    }
                }
            }

            // Поле ввода пароля sudo (показывается, если действие с пакетом pacman/AUR/flatpak)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: appScroll.modalPkgName.length > 0 || appScroll.modalFlatpakId.length > 0

                Text {
                    text: appScroll.isEn() ? "🔑 Enter sudo password:" : "🔑 Пароль администратора (sudo):"
                    color: "#cccccc"
                    font.pixelSize: Config ? Config.fontSize - 1 : 12
                }

                TextField {
                    id: pwdInput
                    Layout.fillWidth: true
                    implicitHeight: 30
                    echoMode: TextInput.Password
                    placeholderText: appScroll.isEn() ? "Password..." : "Введите пароль и нажмите Enter..."
                    color: "#ffffff"
                    font.pixelSize: Config ? Config.fontSize : 13
                    enabled: !Apps.isPkgActionRunning
                    Keys.onReturnPressed: appScroll.submitModalAction()
                    Keys.onEnterPressed: appScroll.submitModalAction()

                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: Qt.rgba(0, 0, 0, 0.65)
                        border.color: pwdInput.activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.22)
                        border.width: 1
                    }
                }
            }

            // Статус выполнения (прогресс / ошибка / успех)
            Text {
                visible: Apps.pkgActionStatus.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Apps.pkgActionStatus
                color: Apps.pkgActionFinished
                       ? (Apps.pkgActionSuccess ? "#4ade80" : "#ff6b6b")
                       : "#eab308"
                font.pixelSize: Config ? Config.fontSize - 1 : 12
                font.bold: true
            }

            // Кнопки действий
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    id: btnConfirmPkg
                    visible: appScroll.modalPkgName.length > 0 || appScroll.modalFlatpakId.length > 0
                    enabled: !Apps.isPkgActionRunning
                    Layout.fillWidth: true
                    implicitHeight: 32
                    flat: true
                    onClicked: appScroll.submitModalAction()
                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: appScroll.modalAction === "install"
                               ? (btnConfirmPkg.hovered ? Qt.rgba(0.20, 0.65, 0.95, 0.38) : Qt.rgba(0.20, 0.65, 0.95, 0.22))
                               : (btnConfirmPkg.hovered ? Qt.rgba(0.95, 0.22, 0.22, 0.38) : Qt.rgba(0.95, 0.22, 0.22, 0.22))
                        border.color: appScroll.modalAction === "install" ? "#38bdf8" : "#ff5555"
                        border.width: 1
                    }
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: appScroll.modalAction === "install" ? "#7dd3fc" : "#ff8888"
                        font.bold: true
                        font.pixelSize: Config ? Config.fontSize - 1 : 12
                        text: {
                            if (Apps.isPkgActionRunning) {
                                return appScroll.isEn() ? "⏳ Processing..." : "⏳ Выполняется..."
                            }
                            if (appScroll.modalAction === "install") {
                                return (appScroll.isEn() ? "󰇚 Install package (" : "󰇚 Установить пакет (") + appScroll.modalPkgName + ")"
                            }
                            if (appScroll.modalPkgName.length > 0) {
                                return (appScroll.isEn() ? "󰩺 Uninstall package (" : "󰩺 Удалить пакет (pacman -Rns ") + appScroll.modalPkgName + ")"
                            }
                            return (appScroll.isEn() ? "󰩺 Uninstall Flatpak (" : "󰩺 Удалить Flatpak (") + appScroll.modalFlatpakId + ")"
                        }
                    }
                }

                // Кнопка удаления/скрытия только ярлыка (при удалении приложения из лаунчера)
                Button {
                    id: btnRemoveShortcut
                    visible: appScroll.modalAction === "uninstall" && appScroll.modalDesktopPath.length > 0
                    enabled: !Apps.isPkgActionRunning
                    Layout.fillWidth: true
                    implicitHeight: 30
                    flat: true
                    onClicked: {
                        pkgActionPopup.close()
                        Apps.removeOrHideShortcut(appScroll.modalDesktopPath)
                    }
                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: btnRemoveShortcut.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        border.width: 1
                    }
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: Config ? Config.fontSize - 1 : 12
                        text: {
                            var inf = appScroll.uninstallInfo
                            if (inf && inf.isLocal && !inf.hasSystemCounterpart) {
                                return appScroll.isEn() ? "󰆴 Delete .desktop shortcut file" : "󰆴 Удалить файл ярлыка (.desktop)"
                            }
                            return appScroll.isEn() ? "󰈉 Hide shortcut from launcher (no password)" : "󰈉 Скрыть только ярлык (без пароля)"
                        }
                    }
                }

                Button {
                    id: btnCancelUninstall
                    enabled: !Apps.isPkgActionRunning
                    Layout.fillWidth: true
                    implicitHeight: 28
                    flat: true
                    onClicked: pkgActionPopup.close()
                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: btnCancelUninstall.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: "#999999"
                        font.pixelSize: Config ? Config.fontSize - 1 : 12
                        text: appScroll.isEn() ? "Close" : "Закрыть"
                    }
                }
            }
        }
    }

    Item {
        id: pageContentRoot
        width: appScroll.availableWidth
        implicitHeight: appCol.implicitHeight + 40

        ColumnLayout {
            id: appCol
            width: Math.min(parent.width - 48, 960)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2

                Text {
                    text: Config ? (Config.language, Config.trAuto("Приложения системы")) : "Приложения системы"
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize + 3
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    id: restoreHiddenBtn
                    visible: Apps && Apps.hiddenCount > 0 && appScroll.selectedCat === "Скрытые"
                    flat: true
                    implicitHeight: 24
                    implicitWidth: restoreTxt.implicitWidth + 16
                    onClicked: Apps.restoreHiddenShortcuts()
                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 4 : 0
                        color: restoreHiddenBtn.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1
                    }
                    contentItem: Text {
                        id: restoreTxt
                        anchors.centerIn: parent
                        color: "#cccccc"
                        font.pixelSize: Config.fontSize - 2
                        text: (appScroll.isEn() ? "󰜉   Restore all (" : "󰜉   Восстановить все (") + (Apps ? Apps.hiddenCount : 0) + ")"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: searchField
                    placeholderText: appScroll.selectedCat === "Пакеты"
                                     ? (appScroll.isEn() ? "Search packages in Pacman & AUR (yay)..." : "Поиск пакетов в Pacman и AUR (yay)...")
                                     : (Config ? (Config.language, Config.trAuto("Поиск приложений...")) : "Поиск приложений...")
                    color: "#ffffff"
                    font.pixelSize: Config.fontSize
                    implicitHeight: 28
                    Layout.fillWidth: true
                    background: GlassPanel {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        tintColor: Qt.rgba(1, 1, 1, Math.max(0.03, Config ? Config.cardOpacity * 0.15 : 0.05))
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.color: searchField.activeFocus ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }
                    }
                    onTextChanged: {
                        searchQuery = text.toLowerCase()
                        if (appScroll.selectedCat === "Пакеты") {
                            if (text.trim().length >= 2) pkgSearchDebounce.restart()
                            else Apps.clearPackageSearch()
                        } else {
                            Qt.callLater(() => appScroll.selectByKb(0))
                        }
                    }
                    Keys.onDownPressed: (event) => {
                        var step = searchQuery.length > 0 ? 1 : 2
                        appScroll.selectByKb(appScroll.kbIndex + step)
                        event.accepted = true
                    }
                    Keys.onUpPressed: (event) => {
                        var step = searchQuery.length > 0 ? 1 : 2
                        appScroll.selectByKb(appScroll.kbIndex - step)
                        event.accepted = true
                    }
                    Keys.onRightPressed: (event) => {
                        if (searchQuery.length === 0) {
                            appScroll.selectByKb(appScroll.kbIndex + 1)
                            event.accepted = true
                        }
                    }
                    Keys.onLeftPressed: (event) => {
                        if (searchQuery.length === 0) {
                            appScroll.selectByKb(appScroll.kbIndex - 1)
                            event.accepted = true
                        }
                    }
                    Keys.onReturnPressed: (event) => {
                        if (appScroll.selectedCat === "Пакеты") {
                            Apps.searchPackages(searchField.text.trim())
                            event.accepted = true
                            return
                        }
                        var vis = appScroll.visibleCards()
                        if (vis.length > 0 && appScroll.kbIndex < vis.length) vis[appScroll.kbIndex].clicked()
                        event.accepted = true
                    }
                    Keys.onEnterPressed: (event) => {
                        if (appScroll.selectedCat === "Пакеты") {
                            Apps.searchPackages(searchField.text.trim())
                            event.accepted = true
                            return
                        }
                        var vis = appScroll.visibleCards()
                        if (vis.length > 0 && appScroll.kbIndex < vis.length) vis[appScroll.kbIndex].clicked()
                        event.accepted = true
                    }
                }

                // Быстрая кнопка поиска в Pacman/AUR, если введён запрос в обычной вкладке
                Button {
                    id: quickPkgBtn
                    visible: appScroll.selectedCat !== "Пакеты" && searchField.text.trim().length >= 2
                    flat: true
                    implicitHeight: 28
                    implicitWidth: quickPkgTxt.implicitWidth + 18
                    onClicked: {
                        appScroll.selectedIdx = 10
                        appScroll.selectedCat = "Пакеты"
                        Apps.searchPackages(searchField.text.trim())
                    }
                    background: Rectangle {
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: quickPkgBtn.hovered ? Qt.rgba(0.25, 0.70, 1.0, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(0.35, 0.80, 1.0, 0.40)
                        border.width: 1
                    }
                    contentItem: Text {
                        id: quickPkgTxt
                        anchors.centerIn: parent
                        color: "#7dd3fc"
                        font.pixelSize: Config.fontSize - 1
                        text: appScroll.isEn() ? "󰣇   Find in Pacman/AUR" : "󰣇   Искать в Pacman/AUR"
                    }
                }
            }

            Item {
                id: catBar
                Layout.fillWidth: true
                implicitHeight: 28

                property Item activeTabObj: catRep.itemAt(selectedIdx)
                property Item hoveredTabObj: null
                property Item lastHoveredTabObj: null

                Rectangle {
                    id: hoverPill
                    y: 2; height: 24
                    radius: (Theme && Theme.isRounded) ? 4 : 0
                    color: Qt.rgba(1, 1, 1, 0.10)
                    x: catBar.lastHoveredTabObj ? catBar.lastHoveredTabObj.x : 0
                    width: catBar.lastHoveredTabObj ? catBar.lastHoveredTabObj.width : 44
                    opacity: catBar.hoveredTabObj && catBar.hoveredTabObj !== catBar.activeTabObj ? 1.0 : 0.0
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }

                Rectangle {
                    id: sliderPill
                    y: 2; height: 24
                    radius: (Theme && Theme.isRounded) ? 4 : 0
                    color: "#ffffff"
                    x: catBar.activeTabObj ? catBar.activeTabObj.x : 0
                    width: catBar.activeTabObj ? catBar.activeTabObj.width : 44
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }

                Row {
                    id: catRow
                    y: 2; spacing: 4
                    Repeater {
                        id: catRep
                        model: ["Все", "Интернет", "Документы", "Разработка", "Мультимедиа", "Графика", "Система", "Игры", "Утилиты", "Скрытые", "Пакеты"]
                        Item {
                            id: tabItem
                            objectName: "atmoObstacle"
                            width: cText.implicitWidth + 16; height: 24
                            Rectangle {
                                anchors.fill: parent
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: selectedIdx === index ? 0 : 1
                            }
                            Text {
                                id: cText
                                anchors.centerIn: parent
                                text: {
                                    if (modelData === "Скрытые") {
                                        var hc = Apps ? Apps.hiddenCount : 0
                                        var base = appScroll.isEn() ? "󰈉   Hidden" : "󰈉   Скрытые"
                                        return hc > 0 ? (base + " (" + hc + ")") : base
                                    }
                                    if (modelData === "Пакеты") {
                                        return appScroll.isEn() ? "󰣇   Pacman / AUR" : "󰣇   Пакеты"
                                    }
                                    return Config ? (Config.language, Config.trAuto(modelData)) : modelData
                                }
                                color: selectedIdx === index ? "#000000" : (cMouse.containsMouse ? "#ffffff" : "#aaaaaa")
                                font.pixelSize: Config.fontSize - 1
                            }
                            MouseArea {
                                id: cMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (containsMouse) { catBar.lastHoveredTabObj = tabItem; catBar.hoveredTabObj = tabItem }
                                    else if (catBar.hoveredTabObj === tabItem) catBar.hoveredTabObj = null
                                }
                                onClicked: {
                                    if (selectedIdx === index) return
                                    var dir = index > selectedIdx ? 1 : -1
                                    selectedIdx = index; selectedCat = modelData
                                    appsGridSlideAnim.stop(); gridSlideX.from = dir * 140; appsGridSlideAnim.start()
                                    if (modelData === "Пакеты" && searchField.text.trim().length >= 2) {
                                        Apps.searchPackages(searchField.text.trim())
                                    } else {
                                        Qt.callLater(() => appScroll.selectByKb(0))
                                    }
                                    searchField.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── РЕЖИМ 1: ВКЛАДКА «ПАКЕТЫ (PACMAN / AUR)» ───────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: appScroll.selectedCat === "Пакеты"

                Text {
                    visible: Apps.isSearchingPackages
                    text: appScroll.isEn() ? "⏳ Searching in Pacman & AUR..." : "⏳ Поиск пакетов в Pacman и AUR..."
                    color: "#aaaaaa"
                    font.pixelSize: Config.fontSize
                    Layout.topMargin: 8
                }

                Text {
                    visible: !Apps.isSearchingPackages && Apps.packageResults.length === 0
                    text: searchField.text.trim().length < 2
                          ? (appScroll.isEn() ? "Type at least 2 characters above to search packages in Pacman & AUR (yay)." : "Введите минимум 2 символа в поле поиска выше для поиска по базе Pacman и AUR (yay).")
                          : (appScroll.isEn() ? "No packages found." : "Пакеты по запросу не найдены.")
                    color: "#888888"
                    font.pixelSize: Config.fontSize
                    Layout.topMargin: 8
                }

                Repeater {
                    model: appScroll.selectedCat === "Пакеты" ? Apps.packageResults : []

                    GlassPanel {
                        id: pkgCard
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08, Config ? Config.cardBgColor.g : 0.08, Config ? Config.cardBgColor.b : 0.10, Math.max(0.02, Config ? Config.cardOpacity : 0.10))

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            // Бейдж репозитория (core / extra / multilib / aur)
                            Rectangle {
                                implicitWidth: repoTxt.implicitWidth + 12
                                implicitHeight: 22
                                radius: (Theme && Theme.isRounded) ? 4 : 0
                                color: modelData.repo === "aur"
                                       ? Qt.rgba(0.95, 0.55, 0.15, 0.20)
                                       : Qt.rgba(0.20, 0.70, 1.0, 0.18)
                                border.color: modelData.repo === "aur" ? "#f59e0b" : "#38bdf8"
                                border.width: 1

                                Text {
                                    id: repoTxt
                                    anchors.centerIn: parent
                                    text: modelData.repo.toUpperCase()
                                    color: modelData.repo === "aur" ? "#fbbf24" : "#7dd3fc"
                                    font.pixelSize: Config.fontSize - 2
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: modelData.name
                                        color: "#ffffff"
                                        font.pixelSize: Config.fontSize
                                        font.bold: true
                                    }
                                    Text {
                                        text: modelData.version
                                        color: "#888888"
                                        font.pixelSize: Config.fontSize - 2
                                    }
                                    Rectangle {
                                        visible: modelData.installed
                                        implicitWidth: instTxt.implicitWidth + 10
                                        implicitHeight: 16
                                        radius: 3
                                        color: Qt.rgba(0.20, 0.85, 0.45, 0.18)
                                        border.color: "#4ade80"
                                        border.width: 1
                                        Text {
                                            id: instTxt
                                            anchors.centerIn: parent
                                            text: appScroll.isEn() ? "Installed" : "Установлен"
                                            color: "#4ade80"
                                            font.pixelSize: Config.fontSize - 3
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.description
                                    color: "#999999"
                                    font.pixelSize: Config.fontSize - 2
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                id: pkgActBtn
                                flat: true
                                implicitHeight: 28
                                implicitWidth: pkgActTxt.implicitWidth + 20
                                onClicked: appScroll.openPackageModal(modelData, modelData.installed ? "uninstall" : "install")
                                background: Rectangle {
                                    radius: (Theme && Theme.isRounded) ? 4 : 0
                                    color: modelData.installed
                                           ? (pkgActBtn.hovered ? Qt.rgba(0.95, 0.25, 0.25, 0.30) : Qt.rgba(0.95, 0.25, 0.25, 0.15))
                                           : (pkgActBtn.hovered ? Qt.rgba(0.20, 0.70, 1.0, 0.32) : Qt.rgba(0.20, 0.70, 1.0, 0.16))
                                    border.color: modelData.installed ? "#ff6b6b" : "#38bdf8"
                                    border.width: 1
                                }
                                contentItem: Text {
                                    id: pkgActTxt
                                    anchors.centerIn: parent
                                    color: modelData.installed ? "#ff8888" : "#7dd3fc"
                                    font.pixelSize: Config.fontSize - 1
                                    font.bold: true
                                    text: modelData.installed
                                          ? (appScroll.isEn() ? "󰩺   Remove" : "󰩺   Удалить")
                                          : (appScroll.isEn() ? "󰇚   Install" : "󰇚   Установить")
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── РЕЖИМ 2: ВКЛАДКА «СКРЫТЫЕ ПРИЛОЖЕНИЯ» ───────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: appScroll.selectedCat === "Скрытые"

                Text {
                    visible: Apps.hiddenApps.length === 0
                    text: appScroll.isEn() ? "No hidden applications." : "Список скрытых приложений пуст."
                    color: "#888888"
                    font.pixelSize: Config.fontSize
                    Layout.topMargin: 8
                }

                Repeater {
                    model: appScroll.selectedCat === "Скрытые" ? Apps.hiddenApps : []

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08, Config ? Config.cardBgColor.g : 0.08, Config ? Config.cardBgColor.b : 0.10, Math.max(0.02, Config ? Config.cardOpacity : 0.10))

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Image {
                                source: "image://appicon/" + modelData.icon
                                sourceSize.width: 24; sourceSize.height: 24
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                fillMode: Image.PreserveAspectFit
                            }

                            ColumnLayout {
                                spacing: 1
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.desktopPath
                                    color: "#777777"
                                    font.pixelSize: Config.fontSize - 2
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            Button {
                                id: unhideBtn
                                flat: true
                                implicitHeight: 26
                                implicitWidth: unhideTxt.implicitWidth + 18
                                onClicked: Apps.unhideShortcut(modelData.desktopPath)
                                background: Rectangle {
                                    radius: (Theme && Theme.isRounded) ? 4 : 0
                                    color: unhideBtn.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Qt.rgba(1, 1, 1, 0.25)
                                    border.width: 1
                                }
                                contentItem: Text {
                                    id: unhideTxt
                                    anchors.centerIn: parent
                                    color: "#ffffff"
                                    font.pixelSize: Config.fontSize - 1
                                    text: appScroll.isEn() ? "󰜉   Restore" : "󰜉   Вернуть в список"
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────── РЕЖИМ 3: СЕТКА УСТАНОВЛЕННЫХ ПРИЛОЖЕНИЙ ───────────────
            Item {
                id: appsGridOuter
                visible: appScroll.selectedCat !== "Пакеты" && appScroll.selectedCat !== "Скрытые"
                Layout.fillWidth: true
                implicitHeight: appsGrid.implicitHeight

                Item {
                    id: appsGridWrapper
                    width: parent.width
                    height: appsGrid.implicitHeight

                    property Item hoveredAppObj: null
                    property Item lastHoveredAppObj: null

                    Rectangle {
                        id: appHoverPill
                        x: appsGridWrapper.lastHoveredAppObj ? appsGridWrapper.lastHoveredAppObj.x : 0
                        y: appsGridWrapper.lastHoveredAppObj ? appsGridWrapper.lastHoveredAppObj.y : 0
                        width: appsGridWrapper.lastHoveredAppObj ? appsGridWrapper.lastHoveredAppObj.width : 240
                        height: appsGridWrapper.lastHoveredAppObj ? appsGridWrapper.lastHoveredAppObj.height : 46
                        radius: (Theme && Theme.isRounded) ? 5 : 0
                        color: Qt.rgba(1, 1, 1, 0.09)
                        border.color: Qt.rgba(1, 1, 1, 0.42)
                        border.width: 1
                        opacity: appsGridWrapper.hoveredAppObj ? 1.0 : 0.0
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                    }

                    GridLayout {
                        id: appsGrid
                        width: parent.width
                        columns: searchQuery.length > 0 ? 1 : 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            id: appsRepeater
                            model: Apps.apps

                            Button {
                                id: appCardBtn
                                visible: {
                                    if (selectedCat === "Пакеты" || selectedCat === "Скрытые") return false
                                    var q = searchQuery
                                    var nameMatch = modelData.name.toLowerCase().indexOf(q) !== -1
                                    var commentMatch = modelData.comment.toLowerCase().indexOf(q) !== -1
                                    if (q.length > 0 && !nameMatch && !commentMatch) return false
                                    if (selectedCat === "Все") return true
                                    var cats = modelData.categories || []
                                    var catStr = cats.join(";").toLowerCase()
                                    if (selectedCat === "Интернет") return catStr.indexOf("network") !== -1 || catStr.indexOf("webbrowser") !== -1
                                    if (selectedCat === "Документы") return catStr.indexOf("office") !== -1
                                    if (selectedCat === "Разработка") return catStr.indexOf("development") !== -1
                                    if (selectedCat === "Мультимедиа") return catStr.indexOf("audio") !== -1 || catStr.indexOf("video") !== -1
                                    if (selectedCat === "Графика") return catStr.indexOf("graphics") !== -1
                                    if (selectedCat === "Система") return catStr.indexOf("system") !== -1 || catStr.indexOf("settings") !== -1
                                    if (selectedCat === "Игры") return catStr.indexOf("game") !== -1
                                    if (selectedCat === "Утилиты") return catStr.indexOf("utility") !== -1
                                    return true
                                }

                                Layout.fillWidth: true
                                Layout.preferredWidth: searchQuery.length > 0 ? appsGrid.width : (appsGrid.width - appsGrid.columnSpacing) / 2
                                implicitHeight: 46
                                flat: true

                                onHoveredChanged: {
                                    if (hovered) {
                                        appsGridWrapper.lastHoveredAppObj = appCardBtn
                                        appsGridWrapper.hoveredAppObj = appCardBtn
                                        var vis = appScroll.visibleCards()
                                        var idx = vis.indexOf(appCardBtn)
                                        if (idx !== -1) appScroll.kbIndex = idx
                                    }
                                }

                                onClicked: Apps.launchApp(modelData.exec)

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            mouse.accepted = true
                                            var pt = appCardBtn.mapToItem(appScroll, mouse.x, mouse.y)
                                            appScroll.openAppContextMenu(modelData, pt.x, pt.y)
                                        }
                                    }
                                }

                                background: GlassPanel {
                                    radius: (Theme && Theme.isRounded) ? 5 : 0
                                    tintColor: Qt.rgba(Config ? Config.cardBgColor.r : 0.08, Config ? Config.cardBgColor.g : 0.08, Config ? Config.cardBgColor.b : 0.10, Math.max(0.02, Config ? Config.cardOpacity : 0.10))
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent; anchors.margins: 6; spacing: 8
                                    Image {
                                        source: "image://appicon/" + modelData.icon
                                        sourceSize.width: 24; sourceSize.height: 24; cache: true
                                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                        Layout.alignment: Qt.AlignVCenter; Layout.bottomMargin: 3
                                        fillMode: Image.PreserveAspectFit; smooth: true
                                    }
                                    ColumnLayout {
                                        spacing: 1; Layout.fillWidth: true
                                        Text { text: modelData.name; color: "#ffffff"; font.pixelSize: Config.fontSize; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: modelData.comment; color: appCardBtn.hovered ? "#aaaaaa" : "#777777"; font.pixelSize: Config.fontSize - 2; elide: Text.ElideRight; Layout.fillWidth: true }
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
