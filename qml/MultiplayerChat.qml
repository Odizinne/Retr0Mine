import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Item {
    id: chatPanel

    // Chat model to store messages
    property var chatMessages: []

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.05)
        border.color: Qt.rgba(0, 0, 0, 0.1)
        border.width: 1
        radius: GameSettings.themeIndex === 0 ? 5 : 0
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
                model: chatMessages
                spacing: 8
                width: parent.width

                // Auto-scroll to bottom when new messages arrive
                onCountChanged: {
                    if (count > 0) {
                        positionViewAtEnd();
                    }
                }

                delegate: RowLayout {
                    width: chatListView.width
                    spacing: 8

                    // Avatar image
                    Image {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        source: {
                            const isFromLocalPlayer = modelData.isLocalPlayer;
                            const name = isFromLocalPlayer ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName;
                            const avatarHandle = SteamIntegration.getAvatarHandleForPlayerName(name);
                            return avatarHandle > 0 ? SteamIntegration.getAvatarImageForHandle(avatarHandle) : "qrc:/icons/steam.png";
                        }
                        fillMode: Image.PreserveAspectCrop

                        Rectangle {
                            width: 26
                            height: 26
                            radius: GameSettings.themeIndex === 0 ? 5 : 0
                            anchors.centerIn: parent
                            color: "transparent"
                            opacity: 0.5
                            border.color: GameConstants.foregroundColor
                            border.width: 1
                        }
                    }

                    // Message bubble
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: messageText.height + 12
                        color: modelData.isLocalPlayer ? Qt.rgba(0.9, 0.9, 0.95, 0.8) : Qt.rgba(0.85, 0.85, 0.9, 0.8)
                        radius: GameSettings.themeIndex === 0 ? 8 : 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            Label {
                                text: modelData.isLocalPlayer ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName
                                font.pixelSize: 11
                                font.bold: true
                                color: GameConstants.foregroundColor
                                opacity: 0.7
                            }

                            Label {
                                id: messageText
                                text: modelData.message
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: GameConstants.foregroundColor
                            }
                        }
                    }
                }
            }
        }

        // Message input area
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: messageInput
                Layout.fillWidth: true
                placeholderText: "Type a message..."
                selectByMouse: true
                font.pixelSize: 13

                Keys.onReturnPressed: sendButton.clicked()
                Keys.onEnterPressed: sendButton.clicked()
            }

            Button {
                id: sendButton
                text: "Send"
                enabled: messageInput.text.trim() !== ""

                onClicked: {
                    if (messageInput.text.trim() !== "") {
                        sendChatMessage(messageInput.text);
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

    Connections {
        target: SteamIntegration

        function onGameActionReceived(actionType, parameter) {
            if (actionType === "chat" && typeof parameter === "string") {
                // Process incoming chat message
                addMessage(parameter, false);
            }
        }
    }
}
