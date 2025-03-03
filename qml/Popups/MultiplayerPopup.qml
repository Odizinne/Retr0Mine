pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
    id: multiplayerPopup
    width: 350
    height: 350
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose
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
            refreshFriendsList()
        }
    }

    function refreshFriendsList() {
        refreshing = true

        // Clear the list first to avoid duplicates
        friendsList.clear()

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

    Item {
        anchors.fill: parent
        visible: SteamIntegration.connectedPlayerName !== "" && !SteamIntegration.isP2PConnected
        ColumnLayout {
            anchors.centerIn: parent

            BusyIndicator {
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
            }

            Label {
                Layout.alignment: Qt.AlignCenter
                font.pixelSize: 14
                text: qsTr("Establishing connection with ") + SteamIntegration.connectedPlayerName
            }
        }
    }
    Label {
        text: qsTr("Ready")
        font.pixelSize: 16
        font.bold: true
        color: "#28d13c"
        anchors.centerIn: parent
        visible: SteamIntegration.connectedPlayerName !== "" && SteamIntegration.isP2PConnected
    }

    // Main content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            opacity: ((!SteamIntegration.isInMultiplayerGame || SteamIntegration.canInviteFriend) &&
                      SteamIntegration.connectedPlayerName === "") ? 1 : 0
            enabled: opacity === 1

            Label {
                text: "Friends"
                Layout.fillWidth: true
                font.pixelSize: 14
                font.bold: true
            }
            Button {
                text: "Refresh"
                Layout.alignment: Qt.AlignHCenter
                enabled: !multiplayerPopup.refreshing
                onClicked: multiplayerPopup.refreshFriendsList()
            }
        }

        Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: ((!SteamIntegration.isInMultiplayerGame || SteamIntegration.canInviteFriend) &&
                      SteamIntegration.connectedPlayerName === "") ? 1 : 0
            enabled: opacity === 1

            ColumnLayout {
                width: parent.width
                height: parent.height

                ListView {
                    id: friendsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: friendsList
                    clip: true
                    highlightMoveDuration: 0
                    currentIndex: 0

                    delegate: ItemDelegate {
                        id: delegate
                        width: friendsListView.width
                        required property string name
                        required property string steamId
                        required property int index

                        property bool inviteDisabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15

                            Label {
                                text: delegate.name
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "+"
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                enabled: SteamIntegration.canInviteFriend &&
                                         !SteamIntegration.isLobbyReady &&
                                         !delegate.inviteDisabled
                                onClicked: {
                                    // Disable all invite buttons
                                    for (var i = 0; i < friendsList.count; i++) {
                                        friendsListView.itemAtIndex(i).inviteDisabled = true;
                                    }

                                    // Invite the friend
                                    SteamIntegration.inviteFriend(delegate.steamId)

                                    // Re-enable buttons after 5 seconds
                                    inviteDisableTimer.restart();
                                }
                            }
                        }
                    }
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
                text: "Cancel"
                Layout.fillWidth: true
                //enabled: SteamIntegration.isInMultiplayerGame
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    ComponentsContext.multiplayerPopupVisible = false
                }
            }

            Button {
                text: "Start"
                Layout.fillWidth: true
                enabled: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isConnecting && SteamIntegration.isP2PConnected
                onClicked: ComponentsContext.multiplayerPopupVisible = false
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

    Timer {
        id: inviteDisableTimer
        interval: 5000
        onTriggered: {
            // Re-enable all invite buttons
            for (var i = 0; i < friendsList.count; i++) {
                friendsListView.itemAtIndex(i).inviteDisabled = false;
            }
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
