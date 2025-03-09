import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    id: control
    anchors.centerIn: parent
    height: lyt.implicitHeight + 30
    width: lyt.implicitWidth + 30
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.coopModeChooserPopupVisible
    property int buttonWidth: Math.max(privButton.implicitWidth + 20, matchButton.implicitWidth + 20, closeButton.implicitWidth + 20, quitButton.implicitWidth + 20)
    ColumnLayout {
        anchors.fill: parent
        id: lyt
        spacing: 20

        Label {
            text: "Retr0Mine Coop"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignCenter
        }

        Label {
            text: qsTr("You're already in a coop game")
            Layout.alignment: Qt.AlignCenter
            visible: SteamIntegration.isInMultiplayerGame
        }

        RowLayout {
            spacing: 15
            Button {
                id: privButton
                visible: !SteamIntegration.isInMultiplayerGame
                text: qsTr("Private game")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                onClicked: {
                    ComponentsContext.coopModeChooserPopupVisible = false
                    ComponentsContext.multiplayerPopupVisible = true
                }
            }

            Button {
                id: matchButton
                visible: !SteamIntegration.isInMultiplayerGame
                text: qsTr("Matchmaking")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                enabled: false
                onClicked: ComponentsContext.coopModeChooserPopupVisible = false
            }

            Button {
                id: closeButton
                visible: SteamIntegration.isInMultiplayerGame
                text: qsTr("Close")
                Layout.preferredWidth: control.buttonWidth
                onClicked: ComponentsContext.coopModeChooserPopupVisible = false
            }

            Button {
                id: quitButton
                visible: SteamIntegration.isInMultiplayerGame
                text: qsTr("Quit session")
                Layout.preferredWidth: control.buttonWidth
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    NetworkManager.sessionRunning = false
                    ComponentsContext.coopModeChooserPopupVisible = false
                }
            }
        }
    }
}
