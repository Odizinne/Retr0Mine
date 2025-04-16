pragma ComponentBehavior: Bound

import QtQuick.Controls.Universal
import Odizinne.Retr0Mine
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

Drawer {
    id: menuDrawer
    width: 220
    height: parent.height
    edge: Qt.LeftEdge

    T.Overlay.modal: Rectangle {
        color: menuDrawer.Universal.altMediumLowColor
    }

    T.Overlay.modeless: Rectangle {
        color: menuDrawer.Universal.baseLowColor
    }

    //background: Rectangle {
    //    color: Universal.background
    //    anchors.fill: parent
    //}

    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 2

            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Universal.accent

                Label {
                    anchors.centerIn: parent
                    text: qsTr("Menu")
                    font.pixelSize: 18
                    font.bold: true
                    color: Universal.foreground
                }
            }

            // Game section
            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Game")
                font.bold: true

                onClicked: gameSubmenu.visible = !gameSubmenu.visible
            }

            // Game submenu items
            Column {
                id: gameSubmenu
                Layout.fillWidth: true
                visible: false
                leftPadding: 20

                ItemDelegate {
                    width: parent.width - parent.leftPadding
                    text: qsTr("New game")
                    enabled: (!(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)) && (GameState.gameStarted || GameState.gameOver)

                    onClicked: {
                        GameState.difficultyChanged = false
                        GridBridge.initGame()
                        menuDrawer.close()
                    }
                }

                ItemDelegate {
                    width: parent.width - parent.leftPadding
                    text: qsTr("Save game")
                    enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame

                    onClicked: {
                        ComponentsContext.savePopupVisible = true
                        menuDrawer.close()
                    }
                }

                ItemDelegate {
                    width: parent.width - parent.leftPadding
                    text: qsTr("Load game")
                    enabled: !SteamIntegration.isInMultiplayerGame

                    onClicked: {
                        ComponentsContext.loadPopupVisible = true
                        menuDrawer.close()
                    }
                }

                ItemDelegate {
                    width: parent.width - parent.leftPadding
                    text: qsTr("Hint")
                    enabled: GameState.gameStarted && !GameState.gameOver

                    onClicked: {
                        GridBridge.requestHint()
                        menuDrawer.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Universal.accent
                opacity: 0.3
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Leaderboard")

                onClicked: {
                    ComponentsContext.leaderboardPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Multiplayer")
                enabled: SteamIntegration.initialized

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

                onClicked: {
                    ComponentsContext.settingsWindowVisible = true
                    menuDrawer.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Universal.accent
                opacity: 0.3
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Help")

                onClicked: {
                    ComponentsContext.rulesPopupVisible = true
                    menuDrawer.close()
                }
            }

            ItemDelegate {
                Layout.fillWidth: true
                text: qsTr("Exit")

                onClicked: Qt.quit()
            }

            // Space at the bottom for better scrolling
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
    }
}
