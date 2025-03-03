import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

RowLayout {
    id: control
    height: 40
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: 12
        leftMargin: 12
        rightMargin: 12
    }
    spacing: 0

    RowLayout {
        Layout.preferredWidth: parent.width / 3
        Layout.fillHeight: true

        Button {
            Layout.preferredHeight: 35
            text: "Menu"
            onClicked: {
                mainMenu.visible = !mainMenu.visible
            }
            MainMenu {
                id: mainMenu
            }
        }
    }

    RowLayout {
        Layout.preferredWidth: parent.width / 3
        Layout.fillHeight: true

        Label {
            id: elapsedTimeLabel
            text: GameTimer.displayTime
            visible: GameSettings.displayTimer && !SteamIntegration.isInMultiplayerGame
            font.pixelSize: 18
            font.family: GameConstants.numberFont.name
            Layout.alignment: Qt.AlignCenter

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
            id: coopFriendLabel
            text: qsTr("Coop: ") + SteamIntegration.connectedPlayerName
            visible: SteamIntegration.isInMultiplayerGame && SteamIntegration.connectedPlayerName !== ""
            font.pixelSize: 14
            font.family: GameConstants.numberFont.name
            Layout.alignment: Qt.AlignCenter
        }
    }

    RowLayout {
        Layout.preferredWidth: parent.width / 3
        Layout.fillHeight: true

        Button {
            Layout.preferredHeight: 35
            icon.source: "qrc:/icons/bomb.png"
            icon.color: GameConstants.foregroundColor
            text: ": " + (GameState.mineCount - GameState.flaggedCount)
            font.pixelSize: 18
            font.bold: true
            onClicked: GridBridge.requestHint()
            Layout.alignment: Qt.AlignRight
        }
    }
}
