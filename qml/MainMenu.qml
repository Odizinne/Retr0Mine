pragma ComponentBehavior: Bound

import QtQuick.Controls.Universal
import Odizinne.Retr0Mine
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

Drawer {
    id: menuDrawer
    width: 190
    height: parent.height
    edge: Qt.LeftEdge
    background: Rectangle {
        color: Constants.settingsPaneColor
    }

    T.Overlay.modal: Rectangle {
        color: menuDrawer.Universal.altMediumLowColor
    }

    T.Overlay.modeless: Rectangle {
        color: menuDrawer.Universal.baseLowColor
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 2

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("New game")
                enabled: (!(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)) && (GameState.gameStarted || GameState.gameOver)
                Layout.preferredHeight: 40
                onClicked: {
                    GameState.difficultyChanged = false
                    GridBridge.initGame()
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Save game")
                enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.savePopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Load game")
                enabled: !SteamIntegration.isInMultiplayerGame
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.loadPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Hint")
                enabled: GameState.gameStarted && !GameState.gameOver
                Layout.preferredHeight: 40
                onClicked: {
                    GridBridge.requestHint()
                    menuDrawer.close()
                }
            }

            ToolSeparator {
                orientation: Qt.Horizontal
                Layout.fillWidth: true
                Layout.topMargin: -10
                Layout.bottomMargin: -10
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Leaderboard")
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.leaderboardPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Multiplayer")
                enabled: SteamIntegration.initialized
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.privateSessionPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("About")

                onClicked: {
                    ComponentsContext.aboutPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Settings")
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.settingsWindowVisible = true
                    menuDrawer.close()
                }
            }

            ToolSeparator {
                orientation: Qt.Horizontal
                Layout.fillWidth: true
                Layout.topMargin: -10
                Layout.bottomMargin: -10
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Help")
                Layout.preferredHeight: 40
                onClicked: {
                    ComponentsContext.rulesPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Exit")
                Layout.preferredHeight: 40
                onClicked: Qt.quit()
            }
        }
    }
}
