import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
    id: multiplayerPopup
    width: 400
    height: 500
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    anchors.centerIn: parent
    visible: ComponentsContext.multiplayerPopupVisible

    property bool refreshing: false

    // Close function
    function close() {
        ComponentsContext.multiplayerPopupVisible = false
    }

    // Refresh the friends list when popup is opened
    onVisibleChanged: {
        if (visible) {
            friendsList.clear()
            refreshFriendsList()
        }
    }

    function refreshFriendsList() {
        refreshing = true
        // Get online friends from SteamIntegration
        var friends = SteamIntegration.getOnlineFriends()

        for (var i = 0; i < friends.length; i++) {
            var parts = friends[i].split(":")
            var name = parts[0]
            var steamId = parts[1]
            friendsList.append({ name: name, steamId: steamId })
        }
        refreshing = false
    }

    // Data model for friends list
    ListModel {
        id: friendsList
    }

    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Title
        Label {
            text: "Multiplayer"
            font.bold: true
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }

        // Status information
        GroupBox {
            title: "Status"
            Layout.fillWidth: true

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 5
                width: parent.width

                Label { text: "Multiplayer Active:" }
                Label {
                    text: SteamIntegration.isInMultiplayerGame ? "Yes" : "No"
                    color: SteamIntegration.isInMultiplayerGame ? "green" : "red"
                }

                Label { text: "Role:" }
                Label {
                    text: SteamIntegration.isHost ? "Host" : "Client"
                    visible: SteamIntegration.isInMultiplayerGame
                }

                Label { text: "Connected Player:" }
                Label {
                    text: SteamIntegration.connectedPlayerName ? SteamIntegration.connectedPlayerName : "None"
                    color: SteamIntegration.connectedPlayerName ? "green" : "gray"
                }

                Label { text: "Lobby Ready:" }
                Label {
                    text: SteamIntegration.isLobbyReady ? "Yes" : "No"
                    color: SteamIntegration.isLobbyReady ? "green" : "red"
                    visible: SteamIntegration.isInMultiplayerGame
                }

                Label { text: "Connection Status:" }
                Label {
                    text: SteamIntegration.isConnecting ? "Connecting..." : "Idle"
                    color: SteamIntegration.isConnecting ? "orange" : "black"
                }
            }
        }

        // Friends list (only visible when host or not in a game)
        GroupBox {
            title: "Friends"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !SteamIntegration.isInMultiplayerGame || SteamIntegration.canInviteFriend

            ColumnLayout {
                width: parent.width
                height: parent.height

                ListView {
                    id: friendsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: friendsList
                    clip: true

                    delegate: ItemDelegate {
                        width: friendsListView.width

                        RowLayout {
                            //width: parent.width
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 5

                            Label {
                                text: model.name
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Invite"
                                enabled: SteamIntegration.canInviteFriend
                                onClicked: {
                                    SteamIntegration.inviteFriend(model.steamId)
                                }
                            }
                        }
                    }
                }

                Button {
                    text: "Refresh Friends List"
                    Layout.alignment: Qt.AlignHCenter
                    enabled: !multiplayerPopup.refreshing
                    onClicked: multiplayerPopup.refreshFriendsList()
                }
            }
        }

        // Action buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Create Lobby"
                Layout.fillWidth: true
                enabled: !SteamIntegration.isInMultiplayerGame && !SteamIntegration.isConnecting
                onClicked: SteamIntegration.createLobby()
            }

            Button {
                text: "Leave Lobby"
                Layout.fillWidth: true
                enabled: SteamIntegration.isInMultiplayerGame
                onClicked: SteamIntegration.leaveLobby()
            }
        }
    }

    // Connection status notifications
    Connections {
        target: SteamIntegration

        function onConnectionFailed(reason) {
            multiplayerPopup.showNotification("Connection failed: " + reason, "red")
        }

        function onConnectionSucceeded() {
            multiplayerPopup.showNotification("Connected successfully!", "green")
        }

        function onConnectedPlayerChanged() {
            if (SteamIntegration.connectedPlayerName) {
                multiplayerPopup.showNotification("Player connected: " + SteamIntegration.connectedPlayerName, "green")
            }
        }
    }

    // Notification area
    Rectangle {
        id: statusNotification
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: notificationText.width + 20
        height: notificationText.height + 10
        color: "green"
        radius: 5
        visible: false

        property string notificationText: ""

        Text {
            id: notificationText
            anchors.centerIn: parent
            text: statusNotification.notificationText
            color: "white"
        }

        Timer {
            id: statusNotificationTimer
            interval: 3000
            onTriggered: statusNotification.visible = false
        }
    }

    // Function to show notifications
    function showNotification(text, color) {
        statusNotification.notificationText = text
        statusNotification.color = color
        statusNotification.visible = true
        statusNotificationTimer.restart()
    }
}
