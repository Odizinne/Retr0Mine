pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

Frame {
    id: chatPanel
    property var chatMessages: []

    onVisibleChanged: {
        if (visible) {
            messageInput.forceActiveFocus();
        }
    }

    Connections {
        target: SteamIntegration

        // Track when the multiplayer status changes
        function onMultiplayerStatusChanged() {
            // If we're no longer in a multiplayer game, clear the chat history
            if (!SteamIntegration.isInMultiplayerGame) {
                console.log("Multiplayer session ended, clearing chat history")
                chatPanel.chatMessages = []
                // Force list update
                chatListView.model = null
                chatListView.model = chatPanel.chatMessages
                ComponentsContext.multiplayerChatVisible = false
            }
        }

        // Also monitor connected player changes
        function onConnectedPlayerChanged() {
            // If the connected player changes (new player or disconnection), clear the chat
            console.log("Connected player changed, clearing chat history")
            chatPanel.chatMessages = []
            // Force list update
            chatListView.model = null
            chatListView.model = chatPanel.chatMessages
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Chat messages area
        ScrollView {
            id: chatScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ListView {
                id: chatListView
                model: chatPanel.chatMessages
                spacing: 12
                width: parent.width

                onCountChanged: {
                    if (count > 0) {
                        positionViewAtEnd();
                    }
                }

                delegate: RowLayout {
                    id: msgContainer
                    width: chatListView.width
                    spacing: 8
                    required property var modelData

                    // Avatar image
                    Image {
                        Layout.alignment: Qt.AlignTop
                        Layout.leftMargin: 2
                        Layout.topMargin: 2
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        source: {
                            if (msgContainer.modelData.isBot) {
                                return "qrc:/images/bot_avatar.png"; // Bot icon
                            }
                            const isFromLocalPlayer = msgContainer.modelData.isLocalPlayer;
                            const name = isFromLocalPlayer ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName;
                            const avatarHandle = SteamIntegration.getAvatarHandleForPlayerName(name);
                            return avatarHandle > 0 ? SteamIntegration.getAvatarImageForHandle(avatarHandle) : "qrc:/icons/steam.png";
                        }
                        fillMode: Image.PreserveAspectCrop

                        Rectangle {
                            width: 26
                            height: 26
                            radius: GameCore.isFluent ? 5 : 0
                            anchors.centerIn: parent
                            opacity: 0.5
                            color: "transparent"
                            border.color: GameConstants.foregroundColor
                            border.width: 1
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: messageText.height + 12
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 1
                            spacing: 2

                            Label {
                                text: msgContainer.modelData.isBot ? msgContainer.modelData.botName :
                                      (msgContainer.modelData.isLocalPlayer ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName)
                                font.pixelSize: 13
                                font.bold: true
                                color: msgContainer.modelData.isBot ? GameConstants.accentColor : GameConstants.foregroundColor
                            }

                            Label {
                                id: messageText
                                text: msgContainer.modelData.message
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: GameConstants.foregroundColor
                                opacity: msgContainer.modelData.isBot ? 0.85 :
                                         (msgContainer.modelData.isLocalPlayer ? 0.5 : 0.8)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: messageInput
                Layout.fillWidth: true
                placeholderText: qsTr("Type a message...")
                selectByMouse: true
                font.pixelSize: 13
                enabled: SteamIntegration.isP2PConnected
                Keys.onReturnPressed: sendButton.clicked()
                Keys.onEnterPressed: sendButton.clicked()
            }

            NfButton {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                id: sendButton
                IconImage {
                    anchors.fill: parent
                    source: "qrc:/icons/send.png"
                    color: GameConstants.foregroundColor
                    sourceSize.height: 15
                    sourceSize.width: 15
                }
                enabled: messageInput.text.trim() !== "" && SteamIntegration.isP2PConnected
                onClicked: {
                    if (messageInput.text.trim() !== "") {
                        chatPanel.sendChatMessage(messageInput.text);
                        messageInput.text = "";
                    }
                }
            }
        }
    }

    function addMessage(message, isLocalPlayer) {
        chatMessages.push({
            message: message,
            isLocalPlayer: isLocalPlayer,
            timestamp: new Date()
        });
        // Force list update
        chatListView.model = null;
        chatListView.model = chatMessages;
    }

    function sendChatMessage(message) {
        if (!SteamIntegration.isInMultiplayerGame || !message) return;

        // Add message to local display
        addMessage(message, true);

        // Send message to remote player via SteamIntegration
        SteamIntegration.sendGameAction("chat", message);
    }

    function addBotMessage(message) {
        // First, filter out any existing bot messages
        chatMessages = chatMessages.filter(msg => !msg.isBot);

        // Then add the new bot message
        chatMessages.push({
            message: message,
            isLocalPlayer: false,
            isBot: true,
            botName: "Retr0Mine_Bot",
            timestamp: new Date()
        });

        // Force list update
        chatListView.model = null;
        chatListView.model = chatMessages;
        GameState.botMessageSent()
    }

    Connections {
        target: SteamIntegration

        function onGameActionReceived(actionType, parameter) {
            if (actionType === "chat" && typeof parameter === "string") {
                // Process incoming chat message
                chatPanel.addMessage(parameter, false);
            }
        }
    }
}
