pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    id: control
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.matchmakingPopupVisible

    onVisibleChanged: {
        if (visible) {
            SteamIntegration.refreshQueueCounts()
        }
    }

    ColumnLayout {
        id: lyt
        anchors.fill: parent
        spacing: 15
        Label {
            text: "Matchmaking"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignCenter
        }

        Label {
            text: qsTr("Select a difficulty:")
            visible: !SteamIntegration.isInMatchmaking && !SteamIntegration.isInMultiplayerGame
            Layout.alignment: Qt.AlignCenter
            font.pixelSize: 15
        }

        ButtonGroup {
            id: difficultyGroup
            exclusive: true
        }

        Frame {
            visible: !SteamIntegration.isInMatchmaking && !SteamIntegration.isInMultiplayerGame
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent

                property var difficultyData: [
                    { name: "Easy", queueCount: SteamIntegration.easyQueueCount, index: 0 },
                    { name: "Medium", queueCount: SteamIntegration.mediumQueueCount, index: 1 },
                    { name: "Hard", queueCount: SteamIntegration.hardQueueCount, index: 2 },
                    { name: "Retr0", queueCount: SteamIntegration.retr0QueueCount, index: 3 }
                ]

                Repeater {
                    model: parent.difficultyData

                    RowLayout {
                        id: difficultyRow
                        Layout.fillWidth: true
                        required property var modelData

                        Label {
                            text: qsTr(difficultyRow.modelData.name)
                            Layout.fillWidth: true
                            MouseArea {
                                anchors.fill: parent
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        radioButton.click()
                                    }
                                }
                            }
                        }

                        Label {
                            text: difficultyRow.modelData.queueCount + qsTr(" players")
                        }

                        RadioButton {
                            id: radioButton
                            ButtonGroup.group: difficultyGroup
                            Layout.preferredHeight: GameConstants.settingsComponentsHeight
                            Layout.preferredWidth: GameConstants.settingsComponentsHeight
                            onClicked: {
                                const idx = difficultyRow.modelData.index
                                const difficultySet = GameState.difficultySettings[idx]
                                if (GameSettings.difficulty === idx) return
                                GameState.difficultyChanged = true
                                GridBridge.cellsCreated = 0
                                GameState.gridSizeX = difficultySet.x
                                GameState.gridSizeY = difficultySet.y
                                GameState.mineCount = difficultySet.mines
                                GridBridge.initGame()
                                GameSettings.difficulty = idx
                                SteamIntegration.difficulty = idx
                                SteamIntegration.selectedMatchmakingDifficulty = idx
                            }
                        }
                    }
                }
            }
        }

        BusyIndicator {
            visible: SteamIntegration.isInMatchmaking
            Layout.fillWidth: true
        }

        Label {
            visible: SteamIntegration.isInMatchmaking && !SteamIntegration.p2pInitialized
            text: qsTr("Searching for players...")
            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Connecting to ") + SteamIntegration.connectedPlayerName
            visible: SteamIntegration.isInMultiplayerGame && !SteamIntegration.p2pInitialized
        }

        Label {
            text: qsTr("Connecting to ") + SteamIntegration.connectedPlayerName
            visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.p2pInitialized

        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            spacing: 15

            Button {
                text: qsTr("Search")
                visible: !SteamIntegration.isInMatchmaking && !SteamIntegration.isInMultiplayerGame
                onClicked: {
                    SteamIntegration.enterMatchmaking(SteamIntegration.selectedMatchmakingDifficulty)
                }
            }

            Button {
                text: qsTr("Close")
                visible: !SteamIntegration.isInMatchmaking && SteamIntegration.isInMultiplayerGame
                onClicked: ComponentsContext.matchmakingPopupVisible = false
            }

            Button {
                text: qsTr("Cancel")
                onClicked: {
                    ComponentsContext.matchmakingPopupVisible = false
                    if (SteamIntegration.isInMatchmaking) {
                        SteamIntegration.leaveMatchmaking()
                    }
                }
            }
        }
    }
}
