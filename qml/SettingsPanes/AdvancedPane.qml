import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        spacing: GameConstants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            enabled: !SteamIntegration.isInMultiplayerGame
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Style")
                Layout.fillWidth: true
            }

            InfoIcon {
                tooltipText: qsTr("Application will restart on change\nCurrent game will be saved and restored")
                Layout.rightMargin: 5
            }

            ComboBox {
                id: styleComboBox
                model: ["Fluent", "Universal", "Fusion"]
                Layout.rightMargin: 5
                currentIndex: GameSettings.themeIndex
                onActivated: {
                    if (GameState.gameStarted && !GameState.gameOver) {
                        SaveManager.saveGame("internalGameState.json")
                    }
                    GameState.bypassAutoSave = true
                    GameCore.restartRetr0Mine(currentIndex)
                }
            }
        }

        RowLayout {
            enabled: Qt.platform.os === "windows"
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Color scheme")
                Layout.fillWidth: true
            }

            ComboBox {
                id: colorSchemeComboBox
                model: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                Layout.rightMargin: 5

                currentIndex: GameSettings.colorSchemeIndex
                onActivated: {
                    GameSettings.colorSchemeIndex = currentIndex
                    GameCore.setThemeColorScheme(currentIndex)
                }
            }
        }
    }
}
