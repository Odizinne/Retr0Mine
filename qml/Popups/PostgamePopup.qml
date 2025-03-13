import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
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
            qsTr("A mine caught %1 by surprise").arg(boldPlayerName)
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

    GridLayout {
        id: lyt
        anchors.fill: parent
        columns: 2
        rowSpacing: 15

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: GameState.postgameText
            color: GameState.postgameColor
            Layout.columnSpan: 2
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
            Layout.columnSpan: 2
            color: "#28d13c"
        }

        Label {
            id: whoTriggeredLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: 200
            text: control.getRandomMineTriggeredPhrase(GameState.bombClickedBy)
            visible: SteamIntegration.isInMultiplayerGame && !GameState.gameWon
            Layout.columnSpan: 2
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            textFormat: Text.RichText
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            id: recordLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("New record saved")
            visible: GameState.displayNewRecord
            Layout.columnSpan: 2
            font.pixelSize: 13
        }

        Label {
            id: clientWaitingLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("Waiting for host to start new game...")
            visible: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost
            Layout.columnSpan: 2
            font.pixelSize: 13
            font.italic: true
        }

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
            Layout.columnSpan: retryButton.visible ? 1 : 2
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
