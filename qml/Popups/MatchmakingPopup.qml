import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    id: control
    modal: true
    closePolicy: Popup.NoAutoClose
    width: lyt.implicitWidth + 20

    onVisibleChanged: {
        if (visible) {
            SteamIntegration.refreshQueueCounts()
        }
    }

    ColumnLayout {
        id: lyt
        anchors.fill: parent
        Label {
            text: "Matchmaking"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignCenter
        }

        Label {
            text: qsTr("Select a difficulty:")
            Layout.alignment: Qt.AlignCenter
        }

        ButtonGroup {
            id: difficultyGroup
            exclusive: true
        }

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: SteamIntegration.easyQueueCount + qsTr(" players")
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Easy")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                easyButton.click()
                            }
                        }
                    }
                }

                RadioButton {
                    id: easyButton
                    ButtonGroup.group: difficultyGroup
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
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
                        SteamIntegration.selectedMatchmakingDifficulty = 0
                    }
                }
            }
        }

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: SteamIntegration.mediumQueueCount + qsTr(" players")

            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Medium")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                mediumButton.click()
                            }
                        }
                    }

                }

                RadioButton {
                    id: mediumButton
                    ButtonGroup.group: difficultyGroup
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
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
                        SteamIntegration.selectedMatchmakingDifficulty = 1
                    }
                }
            }
        }

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: SteamIntegration.hardQueueCount + qsTr(" players")

            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Hard")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                hardButton.click()
                            }
                        }
                    }

                }

                RadioButton {
                    id: hardButton
                    ButtonGroup.group: difficultyGroup
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
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
                        SteamIntegration.selectedMatchmakingDifficulty = 2
                    }
                }
            }
        }

        ColumnLayout {
            Label {
                Layout.fillWidth: true
                text: SteamIntegration.retr0QueueCount + qsTr(" players")

            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: qsTr("Retr0")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                retr0Button.click()
                            }
                        }
                    }
                }

                RadioButton {
                    id: retr0Button
                    ButtonGroup.group: difficultyGroup
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
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
                        SteamIntegration.selectedMatchmakingDifficulty = 3
                    }
                }
            }
        }

        Button {
            text: qsTr("Search")
            visible: !SteamIntegration.isInMatchmaking
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                SteamIntegration.enterMatchmaking(SteamIntegration.selectedMatchmakingDifficulty)
            }
        }

        Button {
            text: qsTr("Cancel")
            visible: SteamIntegration.isInMatchmaking
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                SteamIntegration.leaveMatchmaking()
            }
        }
    }
}
