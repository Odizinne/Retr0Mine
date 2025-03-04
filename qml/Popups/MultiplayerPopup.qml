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

    onVisibleChanged: {
        if (visible) {
            refreshFriendsList()

            ComponentsContext.savePopupVisible = false
            ComponentsContext.loadPopupVisible = false
            ComponentsContext.leaderboardPopupVisible = false
            ComponentsContext.restorePopupVisible = false
            ComponentsContext.aboutPopupVisible = false
            ComponentsContext.rulesPopupVisible = false
            ComponentsContext.settingsWindowVisible = false
            GameState.displayPostGame = false
        }
    }

    function refreshFriendsList() {
        refreshing = true
        friendsList.clear()
        var friends = SteamIntegration.getOnlineFriends()

        for (var i = 0; i < friends.length; i++) {
            var parts = friends[i].split(":")
            var name = parts[0]
            var steamId = parts[1]
            var avatarHandle = parseInt(parts[2])

            friendsList.append({
                name: name,
                steamId: steamId,
                avatarHandle: avatarHandle
            })
        }
        refreshing = false
    }

    ListModel {
        id: friendsList
    }

    Item {
        anchors.fill: parent
        visible: (SteamIntegration.connectedPlayerName !== "" && !SteamIntegration.isP2PConnected) ||
                 (SteamIntegration.isHost && SteamIntegration.isP2PConnected && !GridBridge.clientGridReady)

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
                text: SteamIntegration.isP2PConnected
                      ? SteamIntegration.connectedPlayerName + qsTr(" is generating grid...")
                      : qsTr("Establishing connection with ") + SteamIntegration.connectedPlayerName + "..."
            }
        }
    }

    Label {
        text: GridBridge.sessionRunning ? qsTr("Session in progress") : (SteamIntegration.isHost ? qsTr("Ready") : (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) ? qsTr("Creating cells...") : qsTr("Waiting for host")))
        font.pixelSize: 16
        font.bold: true
        color: "#28d13c"
        anchors.centerIn: parent
        visible: SteamIntegration.connectedPlayerName !== "" &&
                 SteamIntegration.isP2PConnected &&
                 (SteamIntegration.isHost ? GridBridge.clientGridReady : true)
    }

    ToolTip {
        id: inviteSentToolTip
        visible: true
        x: (parent.width - width) / 2
        y: 20
        opacity: 0
        contentItem: Label {
            text: qsTr("Invite sent")
            color: "#28d13c"
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
                text: qsTr("Friends")
                Layout.fillWidth: true
                font.pixelSize: 14
                font.bold: true
            }
            Button {
                text: qsTr("Refresh")
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
                        required property string avatarHandle
                        required property int index
                        property bool inviteDisabled: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            spacing: 10

                            Image {
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: 24
                                source: delegate.avatarHandle > 0 ?
                                        SteamIntegration.getAvatarImageForHandle(delegate.avatarHandle) :
                                        "qrc:/icons/steam.png"
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
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
                visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost && !GridBridge.mpPopupCloseButtonVisible
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Start")
                Layout.fillWidth: true
                // Add the clientGridReady check to the enabled condition
                enabled: SteamIntegration.isInMultiplayerGame &&
                         !SteamIntegration.isConnecting &&
                         SteamIntegration.isP2PConnected &&
                         GridBridge.clientGridReady &&
                         !GridBridge.sessionRunning
                onClicked: {
                    if (SteamIntegration.isHost) {
                        SteamIntegration.sendGameAction("startGame", 0)
                    }
                    ComponentsContext.multiplayerPopupVisible = false
                    GridBridge.sessionRunning = true
                    GridBridge.mpPopupCloseButtonVisible = true
                }
            }

            Button {
                id: closeButton
                visible: GridBridge.mpPopupCloseButtonVisible
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: ComponentsContext.multiplayerPopupVisible = false
            }

            Button {
                id: cancelButton
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Quit session")
                Layout.fillWidth: true
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    GridBridge.sessionRunning = false
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
