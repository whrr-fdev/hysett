import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import HySett
import "../components"

ScrollView {
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: parent.width
        anchors.margins: 24
        spacing: 20

        Text {
            text: Config ? (Config.language, Config.trAuto("Настройки окна и эффектов (Liquid Glass)")) : "Настройки окна и эффектов (Liquid Glass)"
            color: "#ffffff"
            font.pixelSize: 18
            font.bold: true
        }

        // Карточка: Эффекты стекла окна
        GlassPanel {
            objectName: "atmoObstacle"
            Layout.fillWidth: true
            implicitHeight: col1.implicitHeight + 32
            tintColor: Qt.rgba(1, 1, 1, 0.03)

            ColumnLayout {
                id: col1
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                RowLayout {
                    Text { text: Config ? (Config.language, Config.trAuto("Интенсивность блюра фона")) : "Интенсивность блюра фона"; color: "#cccccc"; Layout.fillWidth: true }
                    StyledSlider {
                        from: 0.1
                        to: 1.0
                        value: Theme.windowBlur
                        onMoved: Theme.windowBlur = value
                    }
                }

                RowLayout {
                    Text { text: Config ? (Config.language, Config.trAuto("Преломление (Liquid Refraction)")) : "Преломление (Liquid Refraction)"; color: "#cccccc"; Layout.fillWidth: true }
                    StyledSlider {
                        from: 0.0
                        to: 1.0
                        value: Theme.glassRefraction
                        onMoved: Theme.glassRefraction = value
                    }
                }

                RowLayout {
                    Text { text: Config ? (Config.language, Config.trAuto("Режим скругления (Синхронизация по SUPER+SHIFT+R)")) : "Режим скругления (Синхронизация по SUPER+SHIFT+R)"; color: "#cccccc"; Layout.fillWidth: true }
                    StyledSwitch {
                        checked: Theme.isRounded
                        onToggled: Theme.toggleThemeState()
                    }
                }
            }
        }
    }
}
