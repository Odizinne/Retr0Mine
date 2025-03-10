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
                model: ["Fluent", "Universal"]
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

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Custom seed")
                Layout.fillWidth: true
            }

            TextField {
                id: digitField
                Layout.preferredWidth: colorSchemeComboBox.width * 2
                Layout.rightMargin: 5
                maximumLength: 10
                placeholderText: qsTr("Empty for random")
                inputMethodHints: Qt.ImhDigitsOnly
                text: GameSettings.customSeed === -1 ? "" : GameSettings.customSeed.toString()
                validator: RegularExpressionValidator {
                    regularExpression: /^\d{0,10}$/
                }
                onTextChanged: {
                    if (text === "") {
                        GameSettings.customSeed = -1
                    } else if (text.length > 0) {
                        GameSettings.customSeed = parseInt(text)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                id: seedLabel
                text: qsTr("Last used seed")
                Layout.fillWidth: true
            }

            TextEdit {
                text: ComponentsContext.lastUsedSeed
                color: "#f6ae57"
                font: seedLabel.font
                readOnly: true
                selectByMouse: true
                Layout.rightMargin: 5
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("First click coordinates")
                Layout.fillWidth: true
            }

            Label {
                visible: ComponentsContext.lastFirstClickX !== "" && ComponentsContext.lastFirstClickY !== ""
                text: "X:"
            }

            Label {
                text: ComponentsContext.lastFirstClickX
                color: "#f6ae57"
            }

            Label {
                visible: ComponentsContext.lastFirstClickX !== "" && ComponentsContext.lastFirstClickY !== ""
                text: "Y:"
            }

            Label {
                text: ComponentsContext.lastFirstClickY
                color: "#f6ae57"
                Layout.rightMargin: 5
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Test code"
                Layout.preferredWidth: colorSchemeComboBox.width
            }

            TextField {
                Layout.rightMargin: 5
                onAccepted: {
                    if (text === "matchmaking") {
                        ComponentsContext.testingMatchmaking = true
                        text = ""
                    }
                }
            }
        }
    }
}
