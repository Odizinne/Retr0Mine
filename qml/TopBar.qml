import QtQuick
import QtQuick.Controls
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

    Button {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        height: 35
        text: "Menu"
        onClicked: {
            mainMenu.visible = !mainMenu.visible
        }
        MainMenu {
            id: mainMenu
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
                border.color: GameConstants.foregroundColor
                border.width: 1
                opacity: 0.3
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

    Button {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        height: 35
        icon.source: "qrc:/icons/bomb.png"
        icon.color: GameConstants.foregroundColor
        text: ": " + (GameState.mineCount - GameState.flaggedCount)
        font.pixelSize: 18
        font.bold: true
        highlighted: GameState.flaggedCount === GameState.mineCount
        onClicked: GridBridge.requestHint()
    }
}

