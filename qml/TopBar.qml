import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Controls.impl
import Odizinne.Retr0Mine

ToolBar {
    id: control
    height: 40

    Connections {
        target: SteamIntegration
        function onGameActionReceived(actionType, parameter) {
            if (actionType === "chat" && typeof parameter === "string" && !ComponentsContext.multiplayerChatVisible) {
                if (!chatButton.hasNewMessages) {
                    AudioEngine.playMessage()
                }
                chatButton.hasNewMessages = true
            }
        }

        function onMultiplayerStatusChanged() {
            if (!SteamIntegration.isInMultiplayerGame) {
                chatButton.hasNewMessages = false
            }
        }
    }

    Connections {
        target: GameState
        function onBotMessageSent() {
            if (!ComponentsContext.multiplayerChatVisible) {
                if (!chatButton.hasNewMessages) {
                    AudioEngine.playMessage()
                }
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
            anchors.fill: parent // Add this to properly fill the parent item

            ToolButton {
                id: menuButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                text: "≡"
                font.pixelSize: 34

                onClicked: {
                    mainMenu.visible = !mainMenu.visible
                }
                MainMenu {
                    id: mainMenu
                }
            }

            ToolButton {
                id: signalButton
                visible: SteamIntegration.isP2PConnected
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                onClicked: GameState.nextClickIsSignal = !GameState.nextClickIsSignal

                IconImage {
                    anchors.fill: parent
                    source: "qrc:/icons/signal.png"
                    color: GameState.nextClickIsSignal ? Constants.accentColor : Constants.foregroundColor
                    sourceSize.height: 16
                    sourceSize.width: 16
                }

                ToolTip {
                    visible: signalButton.hovered
                    text: qsTr("Next click will signal the cell")
                    delay: 1000
                }
            }
        }
    }

    Item {
        visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.connectedPlayerName !== "" && !GameState.isGeneratingGrid
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: coopFriendLabel.width + coopAvatarImage.width + 8
        height: 40

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
                anchors.centerIn: parent
                color: "transparent"
                opacity: 1
                border.color: getPingColor(SteamIntegration.pingTime)
                border.width: Constants.isDarkMode ? 1 : 2

                function getPingColor(ping) {
                    if (ping === 0) return Constants.foregroundColor
                    if (ping <= 100) return "#28d13c"
                    if (ping <= 150) return "#a0d128"
                    if (ping <= 200) return "#d1a128"
                    if (ping <= 250) return "#d16c28"
                    return "#d12844"
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                ToolTip {
                    anchors.centerIn: parent
                    text: SteamIntegration.pingTime + " ms"
                    visible: mouseArea.containsMouse
                    delay: 1000
                }
            }
        }

        Label {
            id: coopFriendLabel
            anchors.left: coopAvatarImage.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: SteamIntegration.connectedPlayerName
            font.pixelSize: 14
            font.family: Constants.numberFont.name
        }
    }

    ProgressBar {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: GameState.isGeneratingGrid
        from: 0
        to: GameState.mineCount
        value: GameLogic.minesPlaced
        MouseArea {
            anchors.fill: parent
            onClicked: GridBridge.cancelGeneration()
        }
    }

    NfButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: timeLabel.implicitWidth + 20
        visible: UserSettings.displayTimer && !SteamIntegration.isInMultiplayerGame && !GameState.isGeneratingGrid
        enabled: GameState.gameStarted && !GameState.gameOver
        flat: true

        Label {
            id: timeLabel
            anchors.centerIn: parent
            font.family: Constants.numberFont.name
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 18
            text: GameTimer.displayTime
        }

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
            anchors.fill: parent // Add this to properly fill the parent item
            anchors.rightMargin: 0 // Ensures the layout properly aligns to the right edge

            ToolButton {
                id: mineButton
                Layout.preferredHeight: 40
                Layout.preferredWidth: mineCounter.implicitWidth + 20
                font.pixelSize: 18
                font.bold: true
                enabled: GameState.gameStarted && !GameState.gameOver
                highlighted: GameState.flaggedCount === GameState.mineCount
                onClicked: GridBridge.requestHint()

                RowLayout {
                    id: mineCounter
                    anchors.centerIn: parent
                    IconImage {
                        color: Constants.foregroundColor
                        source: "qrc:/icons/bomb.png"
                        opacity: enabled ? 1 : 0.5
                        sourceSize.height: 18
                        sourceSize.width: 18
                    }

                    Label {
                        text: ": " + (GameState.mineCount - GameState.flaggedCount)
                        font.pixelSize: 18
                        font.bold: true
                    }
                }
            }

            ToolButton {
                id: chatButton
                Layout.preferredHeight: 40
                visible: SteamIntegration.isP2PConnected || UserSettings.hintReasoningInChat
                Layout.preferredWidth: 40
                onClicked: ComponentsContext.multiplayerChatVisible = !ComponentsContext.multiplayerChatVisible
                highlighted: ComponentsContext.multiplayerChatVisible
                property bool hasNewMessages: false

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

                onHighlightedChanged: {
                    if (highlighted) {
                        hasNewMessages = false
                        opacity = 1
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: "qrc:/icons/chat.png"
                    color: chatButton.hasNewMessages ? Constants.accentColor : Constants.foregroundColor
                    sourceSize.height: 16
                    sourceSize.width: 16
                }
            }
        }
    }
}
