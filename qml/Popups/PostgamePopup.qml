import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

AnimatedPopup {
    id: control
    visible: GameState.displayPostGame
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 300
    property int buttonWidth: Math.max(retryButton.implicitWidth, closeButton.implicitWidth) + 20

    onVisibleChanged: {
        if (visible) {
            whoTriggeredLabel.text = getRandomMineTriggeredPhrase(GameState.bombClickedBy)
        }
    }

    function getRandomMineTriggeredPhrase(playerName) {
        const boldPlayerName = "<b>" + playerName + "</b>";
        const phrases = [
                          qsTr("%1 triggered a mine").arg(boldPlayerName),
                          qsTr("%1 found a mine the hard way").arg(boldPlayerName),
                          qsTr("It was certainly not %1's fault...").arg(boldPlayerName),
                          qsTr("A mine caught %1 by surprise").arg(boldPlayerName),
                          qsTr("%1 has discoverd how to lose the game").arg(boldPlayerName),
                          qsTr("%1 has decided to play by its own rules").arg(boldPlayerName),
                          qsTr("A mine unfortunately slipped below %1 cursor").arg(boldPlayerName),
                          qsTr("I saw %1 entering the vent").arg(boldPlayerName)
                      ];
        return phrases[Math.floor(Math.random() * phrases.length)];
    }

    Shortcut {
        sequence: "Return"
        enabled: control.visible && retryButton.visible
        onActivated: retryButton.clicked()
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: closeButton.clicked()
    }

    ColumnLayout {
        id: lyt
        anchors.fill: parent
        spacing: 15

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: (SteamIntegration.isInMultiplayerGame && GameState.gameWon)
                  ? GameState.postgameText + " - " + GameTimer.displayTime
                  : GameState.postgameText;

            color: GameState.postgameColor
            font.family: GameConstants.numberFont.name
            font.pixelSize: 16
        }

        Label {
            id: notificationLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: GameState.notificationText
            visible: GameState.displayNotification
            font.pixelSize: 13
            font.bold: true
            color: "#28d13c"
        }

        Label {
            id: whoTriggeredLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: 200
            text: control.getRandomMineTriggeredPhrase(GameState.bombClickedBy)
            visible: SteamIntegration.isInMultiplayerGame && !GameState.gameWon
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            textFormat: Text.RichText
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            visible: SteamIntegration.isInMultiplayerGame && GameState.gameWon
            Layout.fillWidth: true
            spacing: 0

            Label {
                text: qsTr("Revealed cells:")
                font.bold: true
                Layout.fillWidth: true
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                text: qsTr("First click excluded")
                color: "#f6ae57"
                font.pixelSize: 11
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Frame {
            visible: SteamIntegration.isInMultiplayerGame && GameState.gameWon
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 10
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        font.bold: true
                        text: NetworkManager.hostName
                    }
                    Label {
                        text: {
                            const total = GameState.hostRevealed + GameState.clientRevealed;
                            const percentage = total > 0 ? Math.round((GameState.hostRevealed / total) * 100) : 0;
                            return GameState.hostRevealed + " (" + percentage + "%)";
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        font.bold: true
                        text: NetworkManager.clientName
                    }
                    Label {
                        text: {
                            const total = GameState.hostRevealed + GameState.clientRevealed;
                            const percentage = total > 0 ? Math.round((GameState.clientRevealed / total) * 100) : 0;
                            return GameState.clientRevealed + " (" + percentage + "%)";
                        }
                    }
                }


                ToolSeparator {
                    orientation: Qt.Horizontal
                    Layout.topMargin: -5
                    Layout.bottomMargin: -5
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        id: hostCatchPhrase
                        Layout.fillWidth: true
                        visible: SteamIntegration.isInMultiplayerGame && GameState.gameWon
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        textFormat: Text.RichText

                        text: {
                            const hostPercentage = GameState.hostRevealed + GameState.clientRevealed > 0
                                                 ? Math.round((GameState.hostRevealed / (GameState.hostRevealed + GameState.clientRevealed)) * 100)
                                                 : 0;
                            const clientPercentage = GameState.hostRevealed + GameState.clientRevealed > 0
                                                   ? Math.round((GameState.clientRevealed / (GameState.hostRevealed + GameState.clientRevealed)) * 100)
                                                   : 0;

                            if (hostPercentage >= clientPercentage) {
                                return lyt.getWinnerCatchPhrase(NetworkManager.hostName);
                            } else {
                                return lyt.getLoserCatchPhrase(NetworkManager.hostName);
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        id: clientCatchPhrase
                        Layout.fillWidth: true
                        //Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        visible: SteamIntegration.isInMultiplayerGame && GameState.gameWon
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        textFormat: Text.RichText
                        //horizontalAlignment: Text.AlignHCenter

                        text: {
                            const hostPercentage = GameState.hostRevealed + GameState.clientRevealed > 0
                                                 ? Math.round((GameState.hostRevealed / (GameState.hostRevealed + GameState.clientRevealed)) * 100)
                                                 : 0;
                            const clientPercentage = GameState.hostRevealed + GameState.clientRevealed > 0
                                                   ? Math.round((GameState.clientRevealed / (GameState.hostRevealed + GameState.clientRevealed)) * 100)
                                                   : 0;

                            if (clientPercentage > hostPercentage) {
                                return lyt.getWinnerCatchPhrase(NetworkManager.clientName);
                            } else {
                                return lyt.getLoserCatchPhrase(NetworkManager.clientName);
                            }
                        }
                    }
                }
            }
        }
        function getWinnerCatchPhrase(playerName) {
            const boldPlayerName = "<b><font color='#28d13c'>" + playerName + "</font></b>";
            const phrases = [
                              qsTr("%1 is the true minesweeper pro").arg(boldPlayerName),
                              qsTr("%1 carried the team to victory").arg(boldPlayerName),
                              qsTr("%1 has lightning-fast reflexes").arg(boldPlayerName),
                              qsTr("%1 deserves all the credit").arg(boldPlayerName),
                              qsTr("%1 has the fastest mouse").arg(boldPlayerName),
                              qsTr("%1 should consider going pro").arg(boldPlayerName)
                          ];
            return phrases[Math.floor(Math.random() * phrases.length)];
        }

        function getLoserCatchPhrase(playerName) {
            const boldPlayerName = "<b><font color='#f6ae57'>" + playerName + "</font></b>";
            const phrases = [
                              qsTr("%1 was a bit sleepy today").arg(boldPlayerName),
                              qsTr("%1 provided moral support").arg(boldPlayerName),
                              qsTr("%1 was the cautious one").arg(boldPlayerName),
                              qsTr("%1 will do better next time").arg(boldPlayerName),
                              qsTr("%1 was busy planning the strategy").arg(boldPlayerName),
                              qsTr("%1 was just warming up").arg(boldPlayerName)
                          ];
            return phrases[Math.floor(Math.random() * phrases.length)];
        }



        Label {
            id: recordLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("New record saved")
            visible: GameState.displayNewRecord
            font.pixelSize: 13
        }

        Label {
            id: clientWaitingLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("Waiting for host to start new game...")
            visible: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost
            font.pixelSize: 13
            font.italic: true
        }

        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            NfButton {
                id: retryButton
                text: qsTr("Retry")
                Layout.fillWidth: true
                Layout.preferredWidth: control.buttonWidth
                visible: !SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost
                onClicked: {
                    GameState.difficultyChanged = false
                    GridBridge.initGame()
                    GameState.displayNewRecord = false
                    GameState.displayNotification = false
                    GameState.displayPostGame = false
                }
            }

            NfButton {
                id: closeButton
                text: qsTr("Close")
                Layout.fillWidth: true
                Layout.preferredWidth: control.buttonWidth
                onClicked: {
                    GameState.difficultyChanged = false
                    GameState.displayNewRecord = false
                    GameState.displayNotification = false
                    GameState.displayPostGame = false
                }
            }
        }
    }
}
