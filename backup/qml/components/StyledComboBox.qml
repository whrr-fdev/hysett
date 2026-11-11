import QtQuick
import QtQuick.Controls
import HySett

ComboBox {
    id: control
    implicitHeight: 26
    readonly property bool isM3: Theme && Theme.isRounded
    readonly property real ctrlRad: isM3 ? (Config ? Math.min(12, Config.m3ControlRadius) : 8) : 0

    contentItem: Text {
        leftPadding: 10
        rightPadding: control.indicator.width + 10
        text: Config ? (Config.language, Config.trAuto(control.displayText)) : control.displayText
        font.pixelSize: Config ? Config.fontSize : 11
        color: "#ffffff"
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 10
        y: control.topPadding + (control.availableHeight - height) / 2
        text: "▾"
        font.pixelSize: 11
        color: control.hovered || control.popup.visible ? (control.isM3 && Config ? Config.m3Primary : "#ffffff") : "#999999"
        rotation: control.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    background: GlassPanel {
        radius: control.ctrlRad
        tintColor: control.hovered || control.popup.visible
                   ? (control.isM3 && Config ? Qt.rgba(Config.m3SecondaryContainer.r, Config.m3SecondaryContainer.g, Config.m3SecondaryContainer.b, 0.55) : Qt.rgba(1, 1, 1, 0.10))
                   : (control.isM3 && Config ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.42) : Qt.rgba(1, 1, 1, 0.06))

        Rectangle {
            anchors.fill: parent
            radius: control.ctrlRad
            color: "transparent"
            border.color: control.popup.visible
                          ? (control.isM3 && Config ? Config.m3Primary : "#ffffff")
                          : (control.hovered ? Qt.rgba(1, 1, 1, 0.42) : (control.isM3 && Config ? Qt.rgba(Config.m3Outline.r, Config.m3Outline.g, Config.m3Outline.b, Config.m3OutlineOpacity) : Qt.rgba(1, 1, 1, 0.16)))
            border.width: control.isM3 && Config ? Config.m3OutlineWidth : 1
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }
    }

    popup: Popup {
        id: comboPopup
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(260, listView.contentHeight + 10)
        padding: 5
        transformOrigin: Item.Top

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 160; easing.type: Easing.OutBack }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 110 }
                NumberAnimation { property: "scale"; from: 1.0; to: 0.96; duration: 110 }
            }
        }

        contentItem: Item {
            implicitHeight: listView.contentHeight

            Rectangle {
                id: popupHoverPill
                x: 0
                width: listView.width
                height: 26
                radius: control.isM3 ? Math.max(4, control.ctrlRad - 2) : 0
                color: control.isM3 && Config ? Config.m3Primary : "#ffffff"
                opacity: control.highlightedIndex >= 0 ? 1.0 : 0.0
                y: Math.max(0, control.highlightedIndex * 28 - listView.contentY)
                Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 2
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }

        background: Rectangle {
            radius: control.isM3 ? (control.ctrlRad + 2) : 0
            color: control.isM3 && Config
                   ? Qt.rgba(Config.m3SurfaceContainerHigh.r, Config.m3SurfaceContainerHigh.g, Config.m3SurfaceContainerHigh.b, 0.95)
                   : Qt.rgba(0.05, 0.05, 0.07, 0.90)
            border.color: control.isM3 && Config ? Config.m3Primary : Qt.rgba(1, 1, 1, 0.25)
            border.width: 1
        }
    }

    delegate: ItemDelegate {
        id: dlgt
        width: control.width - 10
        implicitHeight: 26
        highlighted: control.highlightedIndex === index
        property bool isCurrent: control.currentIndex === index

        contentItem: Row {
            spacing: 6
            leftPadding: dlgt.highlighted ? 10 : 6
            Behavior on leftPadding { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

            Text {
                text: dlgt.isCurrent ? "●" : ""
                visible: dlgt.isCurrent
                color: dlgt.highlighted ? (control.isM3 && Config ? Config.accentTextColor : "#000000") : (control.isM3 && Config ? Config.m3Primary : "#ffffff")
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: Config ? (Config.language, Config.trAuto(modelData)) : modelData
                color: dlgt.highlighted ? (control.isM3 && Config ? Config.accentTextColor : "#000000") : (dlgt.isCurrent ? "#ffffff" : "#cccccc")
                font.pixelSize: Config ? Config.fontSize : 11
                font.bold: dlgt.isCurrent || dlgt.highlighted
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 90 } }
            }
        }

        background: Rectangle {
            radius: control.isM3 ? Math.max(4, control.ctrlRad - 2) : 0
            color: (!dlgt.highlighted && dlgt.isCurrent)
                   ? (control.isM3 && Config ? Qt.rgba(Config.m3PrimaryContainer.r, Config.m3PrimaryContainer.g, Config.m3PrimaryContainer.b, 0.45) : Qt.rgba(1, 1, 1, 0.08))
                   : "transparent"
        }
    }
}
