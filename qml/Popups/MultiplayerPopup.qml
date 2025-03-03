pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
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
    property int buttonWidth: Math.max(hostButton.width, cancelButton.width, startButton.width)
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
            spacing: 15

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
        text: SteamIntegration.isHost ? qsTr("Ready") : qsTr("Waiting for host")
        font.pixelSize: 16
        font.bold: true
        color: "#28d13c"
        anchors.centerIn: parent
        visible: SteamIntegration.connectedPlayerName !== "" && SteamIntegration.isP2PConnected
    }

    ToolTip {
        id: inviteSentToolTip
        visible: true
        x: (parent.width - width) / 2
        y: 20
        opacity: 0
        contentItem: Label {
            text: qsTr("Invite sent")
            color: "#28d13c" // Green color
            font.pixelSize: 14
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Timer {
            id: inviteSentToolTipTimer
            interval: 3000
            onTriggered: {
                inviteSentToolTip.opacity = 0
            }
        }
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

                    delegate: Item {
                        id: delegate
                        width: friendsListView.width
                        height: 40
                        required property string name
                        required property string steamId
                        required property int index
                        property bool inviteDisabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            spacing: 10
                            IconImage {
                                source: "qrc:/icons/steam.png"
                                color: GameConstants.foregroundColor
                                sourceSize.height: 14
                                sourceSize.width: 14
                                Layout.preferredHeight: 14
                                Layout.preferredWidth: 14
                                Layout.topMargin: 2
                            }

                            Label {
                                id: friendNameLabel
                                text: delegate.name
                                Layout.fillWidth: true
                            }

                            Button {
                                Layout.preferredWidth: height
                                enabled: SteamIntegration.canInviteFriend &&
                                         !SteamIntegration.isLobbyReady &&
                                         !delegate.inviteDisabled
                                onClicked: {
                                    for (var i = 0; i < friendsList.count; i++) {
                                        friendsListView.itemAtIndex(i).inviteDisabled = true;
                                    }
                                    SteamIntegration.inviteFriend(delegate.steamId)
                                    inviteSentToolTip.opacity = 1
                                    inviteSentToolTipTimer.start()
                                    inviteDisableTimer.restart();
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    source: "qrc:/icons/mail.png"
                                    color: parent.enabled ? GameConstants.foregroundColor : "grey"
                                    sourceSize.height: 16
                                    sourceSize.width: 16
                                    Layout.preferredHeight: 16
                                    Layout.preferredWidth: 16
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
                id: hostButton
                visible: !SteamIntegration.isInMultiplayerGame
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Host")
                Layout.fillWidth: true
                enabled: !SteamIntegration.isInMultiplayerGame && !SteamIntegration.isConnecting
                onClicked: SteamIntegration.createLobby()
            }

            Button {
                id: startButton
                highlighted: enabled
                visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Start")
                Layout.fillWidth: true
                enabled: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isConnecting && SteamIntegration.isP2PConnected
                onClicked: {
                    if (SteamIntegration.isHost) {
                        SteamIntegration.sendGameAction("startGame", 0)
                    }
                    ComponentsContext.multiplayerPopupVisible = false
                }
            }

            Button {
                id: cancelButton
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Cancel")
                Layout.fillWidth: true
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    ComponentsContext.multiplayerPopupVisible = false
                }
            }
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
}
