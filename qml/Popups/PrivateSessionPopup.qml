pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.Retr0Mine

AnimatedPopup {
    id: multiplayerPopup
    width: 350
    height: 350
    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.privateSessionPopupVisible
    property int buttonWidth: Math.max(cancelButton.width, startButton.width, closeButton.width)
    property bool refreshing: false

    onVisibleChanged: {
        if (visible) {
            searchField.text = ""
            refreshFriendsList()
            ComponentsContext.savePopupVisible = false
            ComponentsContext.loadPopupVisible = false
            ComponentsContext.leaderboardPopupVisible = false
            ComponentsContext.restorePopupVisible = false
            ComponentsContext.aboutPopupVisible = false
            ComponentsContext.rulesPopupVisible = false
            ComponentsContext.playerLeftPopupVisible = false
            GameState.displayPostGame = false
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                ComponentsContext.settingsWindowVisible = false
            }

            if (!SteamIntegration.isInMultiplayerGame) SteamIntegration.createLobby()
        }
    }

    function refreshFriendsList() {
        refreshing = true
        friendsList.clear()
        var friends = SteamIntegration.getOnlineFriends()

        friends.sort(function(a, b) {
            var nameA = a.split(":")[0].toLowerCase()
            var nameB = b.split(":")[0].toLowerCase()
            return nameA.localeCompare(nameB)
        })

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

    function filterFriendsList(query) {
        for (var i = 0; i < friendsList.count; i++) {
            var item = friendsListView.itemAtIndex(i)
            if (item) {
                var friendName = friendsList.get(i).name
                var visible = friendName.toLowerCase().includes(query.toLowerCase())
                item.height = visible ? 40 : 0
                item.visible = visible
            }
        }
    }

    ListModel {
        id: friendsList
    }

    Item {
        anchors.fill: parent
        visible: (SteamIntegration.connectedPlayerName !== "" &&
                  (!SteamIntegration.isP2PConnected || SteamIntegration.connectionState === SteamIntegration.Connecting)) ||
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
                text: (SteamIntegration.isP2PConnected && SteamIntegration.connectionState === SteamIntegration.Connected)
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
            text: qsTr("Press G or middle-click mouse while hovering a cell to signal it")
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            spacing: 10
            opacity: ((!SteamIntegration.isInMultiplayerGame || SteamIntegration.canInviteFriend) &&
                      SteamIntegration.connectedPlayerName === "") ? 1 : 0
            enabled: opacity === 1

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Filter...")
                selectByMouse: true
                font.pixelSize: 14
                onTextChanged: {
                    multiplayerPopup.filterFriendsList(text)
                }
            }
            NfButton {
                text: qsTr("Refresh")
                
                Layout.alignment: Qt.AlignHCenter
                enabled: !multiplayerPopup.refreshing
                onClicked: {
                    multiplayerPopup.refreshFriendsList()
                    searchField.text = ""
                }
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
                                mipmap: true
                                source: delegate.avatarHandle > 0 ?
                                        SteamIntegration.getAvatarImageForHandle(delegate.avatarHandle) :
                                        "qrc:/icons/steam.png"
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit

                                Rectangle {
                                    width: 26
                                    height: 26
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    opacity: 0.3
                                    border.color: GameConstants.foregroundColor
                                    border.width: GameConstants.isDarkMode ? 1 : 2
                                }
                            }

                            Label {
                                id: friendNameLabel
                                text: delegate.name
                                Layout.fillWidth: true
                            }

                            NfButton {
                                Layout.preferredWidth: height
                                
                                enabled: SteamIntegration.canInviteFriend &&
                                         !SteamIntegration.isLobbyReady &&
                                         !delegate.inviteDisabled
                                onClicked: {
                                    for (var i = 0; i < friendsList.count; i++) {
                                        friendsListView.itemAtIndex(i).inviteDisabled = true;
                                    }
                                    SteamIntegration.inviteFriend(delegate.steamId)
                                    inviteDisableTimer.invitedIndex = delegate.index;
                                    invitedPersonTimer.invitedIndex = delegate.index;
                                    inviteSentToolTip.opacity = 1
                                    inviteSentToolTipTimer.start()
                                    inviteDisableTimer.restart();
                                    invitedPersonTimer.restart();
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    source: "qrc:/icons/mail.png"
                                    color: GameConstants.foregroundColor
                                    opacity: parent.enabled? 1 : 0.5
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NfButton {
                id: startButton
                highlighted: enabled
                visible: !NetworkManager.mpPopupCloseButtonVisible && SteamIntegration.isHost
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Start")
                
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
                    ComponentsContext.privateSessionPopupVisible = false
                    NetworkManager.sessionRunning = true
                    NetworkManager.mpPopupCloseButtonVisible = true
                }
            }

            NfButton {
                id: closeButton
                visible: NetworkManager.mpPopupCloseButtonVisible || (!SteamIntegration.isHost && SteamIntegration.isP2PConnected && GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY))
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: ComponentsContext.privateSessionPopupVisible = false
            }

            NfButton {
                id: cancelButton
                Layout.preferredWidth: multiplayerPopup.buttonWidth
                text: qsTr("Quit session")
                
                Layout.fillWidth: true
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    NetworkManager.sessionRunning = false
                    ComponentsContext.privateSessionPopupVisible = false
                }
            }
        }
    }

    Timer {
        id: inviteDisableTimer
        interval: 5000
        property int invitedIndex: -1

        onTriggered: {
            for (var i = 0; i < friendsList.count; i++) {
                if (i !== invitedIndex) {
                    friendsListView.itemAtIndex(i).inviteDisabled = false;
                }
            }
        }
    }

    Timer {
        id: invitedPersonTimer
        interval: 10000
        property int invitedIndex: -1

        onTriggered: {
            if (invitedIndex >= 0 && invitedIndex < friendsList.count) {
                friendsListView.itemAtIndex(invitedIndex).inviteDisabled = false;
            }
        }
    }
}
