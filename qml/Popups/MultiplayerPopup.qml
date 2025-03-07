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
            GameState.displayPostGame = false
            if ( SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                ComponentsContext.settingsWindowVisible = false
            }
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
                 (SteamIntegration.isHost && SteamIntegration.isP2PConnected && !NetworkManager.clientGridReady)

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

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        Label {
            id: statusLabel
            text: NetworkManager.sessionRunning ? qsTr("Session in progress") : (SteamIntegration.isHost ? qsTr("Ready") : (GridBridge.cellsCreated !== (GameState.gridSizeX * GameState.gridSizeY) ? qsTr("Creating cells...") : qsTr("Waiting for host")))
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignCenter
            visible: SteamIntegration.connectedPlayerName !== "" &&
                     SteamIntegration.isP2PConnected &&
                     (SteamIntegration.isHost ? NetworkManager.clientGridReady : true)
        }

        ProgressBar {
            from: 0
            id: cellProgressBar
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignCenter
            to: GameState.gridSizeX * GameState.gridSizeY
            value: GridBridge.cellsCreated
            opacity: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && ((GameState.gridSizeX * GameState.gridSizeY) !== GridBridge.cellsCreated) ? 1 : 0
        }

        Label {
            text: qsTr("Press G while hovering a cell to signal it")
            Layout.preferredWidth: 300
            wrapMode: Text.WordWrap
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            opacity: statusLabel.visible || cellProgressBar.opacity === 1 ? 0.7 : 0 || (SteamIntegration.isP2PConnected && NetworkManager.clientGridReady)
        }
    }



    ToolTip {
        id: inviteSentToolTip
        visible: true
        x: (parent.width - width) / 2
        y: 10
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
                focusPolicy: Qt.NoFocus
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
                                focusPolicy: Qt.NoFocus
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
                focusPolicy: Qt.NoFocus
            }

            Button {
                id: startButton
                highlighted: enabled
                visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost && !NetworkManager.mpPopupCloseButtonVisible
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Start")
                focusPolicy: Qt.NoFocus
                Layout.fillWidth: true
                enabled: SteamIntegration.isInMultiplayerGame &&
                         !SteamIntegration.isConnecting &&
                         SteamIntegration.isP2PConnected &&
                         NetworkManager.clientGridReady &&
                         !NetworkManager.sessionRunning
                onClicked: {
                    if (SteamIntegration.isHost) {
                        SteamIntegration.sendGameAction("startGame", 0)
                    }
                    ComponentsContext.multiplayerPopupVisible = false
                    NetworkManager.sessionRunning = true
                    NetworkManager.mpPopupCloseButtonVisible = true
                }
            }

            Button {
                id: closeButton
                visible: NetworkManager.mpPopupCloseButtonVisible || (!SteamIntegration.isHost && SteamIntegration.isP2PConnected && GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY))
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: ComponentsContext.multiplayerPopupVisible = false
            }

            Button {
                id: cancelButton
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Quit session")
                focusPolicy: Qt.NoFocus
                Layout.fillWidth: true
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    NetworkManager.sessionRunning = false
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
