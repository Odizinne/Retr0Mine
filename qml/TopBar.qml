import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

Item {
    id: control
    height: 35
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: 12
        leftMargin: 13
        rightMargin: 15
    }

    Connections {
        target: SteamIntegration
        function onGameActionReceived(actionType, parameter) {
            if (actionType === "chat" && typeof parameter === "string" && !ComponentsContext.multiplayerChatVisible) {
                // If we receive a chat message and the chat panel is not visible, mark as having new messages
                chatButton.hasNewMessages = true
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: leftLayout.implicitWidth

        RowLayout {
            id: leftLayout
            Button {
                id: menuButton

                Layout.preferredHeight: 35
                text: "Menu"
                onClicked: {
                    mainMenu.visible = !mainMenu.visible
                }
                MainMenu {
                    id: mainMenu
                }
            }

            Button {
                id: signalButton
                visible: SteamIntegration.isP2PConnected
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                onClicked: GameState.nextClickIsSignal = !GameState.nextClickIsSignal

                IconImage {
                    anchors.fill: parent
                    source: "qrc:/icons/signal.png"
                    color: GameState.nextClickIsSignal ? GameConstants.accentColor : GameConstants.foregroundColor
                    sourceSize.height: 16
                    sourceSize.width: 16
                }

                ToolTip {
                    visible: mouseArea.containsMouse
                    text: qsTr("Next click will signal the cell")
                    delay: 1000
                }
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    Item {
        visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.connectedPlayerName !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: coopFriendLabel.width + coopAvatarImage.width + 8
        height: 35

        Image {
            id: coopAvatarImage
            width: 24
            height: 24
            sourceSize.width: 24
            sourceSize.height: 24
            mipmap: true
            source: {
                if (SteamIntegration.initialized && SteamIntegration.connectedPlayerName !== "") {
                    var avatarHandle = SteamIntegration.getAvatarHandleForPlayerName(SteamIntegration.connectedPlayerName)
                    return avatarHandle > 0 ? SteamIntegration.getAvatarImageForHandle(avatarHandle) : "qrc:/icons/steam.png"
                }
                return "qrc:/icons/steam.png"
            }
            fillMode: Image.PreserveAspectCrop
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 26
                height: 26
                radius: GameSettings.themeIndex === 0 ? 5 : 0
                anchors.centerIn: parent
                color: "transparent"
                opacity: 0.5
                border.color: GameConstants.foregroundColor
                border.width: Application.styleHints.colorScheme == Qt.Dark ? 1 : 2
            }
        }

        Label {
            id: coopFriendLabel
            anchors.left: coopAvatarImage.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: SteamIntegration.connectedPlayerName
            font.pixelSize: 14
            font.family: GameConstants.numberFont.name
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        id: elapsedTimeLabel
        text: GameTimer.displayTime
        visible: GameSettings.displayTimer && !SteamIntegration.isInMultiplayerGame
        font.pixelSize: 18
        font.family: GameConstants.numberFont.name

        ToolTip {
            visible: timeMouseArea.containsMouse
            delay: 500
            text: qsTr("Click to pause")
        }

        MouseArea {
            id: timeMouseArea
            enabled: GameState.gameStarted && !GameState.gameOver
            anchors.fill: parent
            onClicked: GameState.paused = true
            hoverEnabled: true
        }
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: rightLayout.implicitWidth
        RowLayout {
            id: rightLayout

            Button {
                Layout.preferredHeight: 35
                icon.source: "qrc:/icons/bomb.png"
                icon.color: GameConstants.foregroundColor
                text: ": " + (GameState.mineCount - GameState.flaggedCount)
                font.pixelSize: 18
                font.bold: true
                highlighted: GameState.flaggedCount === GameState.mineCount
                onClicked: GridBridge.requestHint()
            }

            Button {
                id: chatButton
                visible: SteamIntegration.isP2PConnected
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                onClicked: ComponentsContext.multiplayerChatVisible = !ComponentsContext.multiplayerChatVisible
                highlighted: ComponentsContext.multiplayerChatVisible

                // Add property to track if there are new messages
                property bool hasNewMessages: false

                // Animation for notification effect
                SequentialAnimation {
                    id: notificationAnimation
                    running: chatButton.hasNewMessages && !ComponentsContext.multiplayerChatVisible
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: chatButton
                        property: "opacity"
                        from: 1.0
                        to: 0.3
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: chatButton
                        property: "opacity"
                        from: 0.3
                        to: 1.0
                        duration: 800
                        easing.type: Easing.InOutQuad
                    }
                }

                // Reset new messages flag when chat is opened
                onHighlightedChanged: {
                    if (highlighted) {
                        hasNewMessages = false
                        opacity = 1
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: "qrc:/icons/chat.png"
                    color: chatButton.hasNewMessages ? GameConstants.accentColor : GameConstants.foregroundColor
                    sourceSize.height: 16
                    sourceSize.width: 16
                }
            }
        }
    }
}
