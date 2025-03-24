pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

Frame {
    id: chatPanel
    property ListModel chatMessages: ListModel {}

    onVisibleChanged: {
        if (visible) {
            messageInput.forceActiveFocus();
        }
    }

    Connections {
        target: SteamIntegration

        function onMultiplayerStatusChanged() {
            if (!SteamIntegration.isInMultiplayerGame) {
                chatPanel.chatMessages.clear();
                ComponentsContext.multiplayerChatVisible = false;
            }
        }

        function onConnectedPlayerChanged() {
            chatPanel.chatMessages.clear();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: chatScrollView.height

            ScrollBar {
                id: defaultVerticalScrollBar
                enabled: chatScrollView.enabled
                opacity: chatScrollView.opacity
                orientation: Qt.Vertical
                anchors.right: chatScrollView.right
                anchors.top: chatScrollView.top
                anchors.bottom: chatScrollView.bottom
                visible: policy === ScrollBar.AlwaysOn
                active: true
                policy: (chatScrollView.contentHeight > chatScrollView.height) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            }

            ScrollView {
                id: chatScrollView
                anchors.fill: parent
                clip: true
                ScrollBar.vertical: defaultVerticalScrollBar
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ListView {
                    id: chatListView
                    model: chatPanel.chatMessages
                    spacing: 0
                    width: parent.contentWidth
                    onCountChanged: {
                        if (count > 0) {
                            Qt.callLater(function() {
                                chatListView.positionViewAtEnd();
                            });
                        }
                    }
                    delegate: RowLayout {
                        id: msgContainer
                        width: chatPanel.visible ? chatListView.width - 12 : 0
                        spacing: 8
                        required property var modelData

                        Image {
                            Layout.alignment: Qt.AlignTop
                            Layout.leftMargin: 2
                            Layout.topMargin: 2
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            source: {
                                if (msgContainer.modelData.isBot) {
                                    return "qrc:/images/bot_avatar.png";
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
                                anchors.centerIn: parent
                                opacity: 0.5
                                color: "transparent"
                                border.color: GameConstants.foregroundColor
                                border.width: 1
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: messageText.height + 36
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

                                Item {
                                    Layout.preferredHeight: 36
                                }
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
                enabled: SteamIntegration.isP2PConnected && ComponentsContext.multiplayerChatVisible
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
        chatMessages.append({
            message: message,
            isLocalPlayer: isLocalPlayer,
            timestamp: new Date(),
            isBot: false
        });
    }

    function sendChatMessage(message) {
        if (!SteamIntegration.isInMultiplayerGame || !message) return;

        addMessage(message, true);
        SteamIntegration.sendGameAction("chat", message);
    }

    function addBotMessage(message) {
        for (let i = chatMessages.count - 1; i >= 0; i--) {
            if (chatMessages.get(i).isBot) {
                chatMessages.remove(i);
            }
        }

        chatMessages.append({
            message: message,
            isLocalPlayer: false,
            isBot: true,
            botName: "Retr0Mine_Bot",
            timestamp: new Date()
        });

        GameState.botMessageSent();
    }

    Connections {
        target: SteamIntegration

        function onGameActionReceived(actionType, parameter) {
            if (actionType === "chat" && typeof parameter === "string") {
                chatPanel.addMessage(parameter, false);
            }
        }
    }
}
