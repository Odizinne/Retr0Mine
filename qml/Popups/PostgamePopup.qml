import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
    anchors.centerIn: parent
    id: control
    visible: GameState.displayPostGame
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 300
    property int buttonWidth: Math.max(retryButton.implicitWidth, closeButton.implicitWidth)

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
            id: recordLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("New record saved")
            visible: GameState.displayNewRecord
            Layout.columnSpan: 2
            font.pixelSize: 13
        }

        // If multiplayer client, show waiting message
        Label {
            id: clientWaitingLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("Waiting for host to start new game...")
            visible: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost
            Layout.columnSpan: 2
            font.pixelSize: 13
            font.italic: true
        }

        Button {
            id: retryButton
            text: qsTr("Retry")
            Layout.fillWidth: true
            Layout.preferredWidth: control.buttonWidth
            // Hide the retry button for multiplayer clients
            visible: !SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost
            onClicked: {
                GameState.difficultyChanged = false
                GridBridge.initGame()
                GameState.displayNewRecord = false
                GameState.displayNotification = false
                GameState.displayPostGame = false
            }
        }

        Button {
            id: closeButton
            text: qsTr("Close")
            Layout.fillWidth: true
            // If no retry button (client), expand this button to full width
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
