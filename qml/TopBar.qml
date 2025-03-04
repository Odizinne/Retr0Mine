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

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        id: coopFriendLabel
        text: qsTr("Coop: ") + SteamIntegration.connectedPlayerName
        visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.connectedPlayerName !== ""
        font.pixelSize: 14
        font.family: GameConstants.numberFont.name
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
        onClicked: GridBridge.requestHint()
    }
}

