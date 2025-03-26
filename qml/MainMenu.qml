import QtQuick.Controls.Universal
import net.odizinne.retr0mine
import QtQuick

Menu {
    topMargin: 58
    id: menu
    width: 150
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 110 }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 110 }
    }
    CustomMenuItem {
        text: qsTr("New game")
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        onTriggered: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    CustomMenuItem {
        text: qsTr("Save game")
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.savePopupVisible = true
    }

    CustomMenuItem {
        text: qsTr("Load game")
        enabled: !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.loadPopupVisible = true
    }

    CustomMenuItem {
        text: qsTr("Hint")
        enabled: GameState.gameStarted && !GameState.gameOver
        onTriggered: GridBridge.requestHint()
    }

    MenuSeparator { }

    CustomMenuItem {
        text: qsTr("Leaderboard")
        onTriggered: ComponentsContext.leaderboardPopupVisible = true
    }

    CustomMenuItem {
        enabled: SteamIntegration.initialized
        text: qsTr("Multiplayer")
        onTriggered: ComponentsContext.privateSessionPopupVisible = true
    }

    CustomMenuItem {
        text: qsTr("About")
        onTriggered: ComponentsContext.aboutPopupVisible = true
    }

    CustomMenuItem {
        text: qsTr("Settings")
        onTriggered: ComponentsContext.settingsWindowVisible = true
    }

    MenuSeparator { }

    CustomMenuItem {
        text: qsTr("Help")
        onTriggered: ComponentsContext.rulesPopupVisible = true
    }

    CustomMenuItem {
        text: qsTr("Exit")
        onTriggered: Qt.quit()
    }
}
