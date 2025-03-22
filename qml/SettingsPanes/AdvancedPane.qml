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

            NfComboBox {
                id: styleComboBox
                model: ["Fluent", "Universal"]
                Layout.rightMargin: 5
                currentIndex: GameSettings.themeIndex
                onActivated: {
                    if (currentIndex !== GameSettings.themeIndex) {
                        if (GameState.gameStarted && !GameState.gameOver) {
                            SaveManager.saveGame("internalGameState.json")
                        }
                        GameState.bypassAutoSave = true
                        GameCore.restartRetr0Mine(currentIndex)
                    }
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

            NfComboBox {
                id: colorSchemeComboBox
                model: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                Layout.rightMargin: 5
                currentIndex: GameSettings.colorSchemeIndex
                onActivated: {
                    if (GameSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(GameSettings.accentColorIndex)
                    }
                    GameSettings.colorSchemeIndex = currentIndex
                    GameCore.setThemeColorScheme(currentIndex)
                    if (GameSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(GameSettings.accentColorIndex)
                    }
                }
            }
        }

        RowLayout {
            enabled: Qt.platform.os === "windows"
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Accent color")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: accentColorComboBox
                model: [qsTr("System"), qsTr("Blue"), qsTr("Orange"), qsTr("Red"), qsTr("Green"), qsTr("Purple")]
                Layout.rightMargin: 5
                currentIndex: GameSettings.accentColorIndex
                onActivated: {
                    GameSettings.accentColorIndex = currentIndex
                    Qt.callLater(function() {
                        GameCore.setApplicationPalette(currentIndex)
                    })
                }
            }
        }
    }
}
