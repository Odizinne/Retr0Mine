import QtQuick.Controls
import net.odizinne.retr0mine

Menu {
    topMargin: 60
    id: menu
    width: 150
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    MenuItem {
        text: qsTr("New game")
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        onTriggered: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    MenuItem {
        text: qsTr("Save game")
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.savePopupVisible = true
    }

    MenuItem {
        id: loadMenu
        text: qsTr("Load game")
        enabled: !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.loadPopupVisible = true
    }

    MenuItem {
        text: qsTr("Hint")
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        onTriggered: GridBridge.requestHint()
    }

    MenuSeparator { }

    MenuItem {
        text: qsTr("Settings")
        onTriggered: ComponentsContext.settingsWindowVisible = true
    }

    MenuItem {
        text: qsTr("Leaderboard")
        onTriggered: ComponentsContext.leaderboardPopupVisible = true
    }

    MenuItem {
        text: SteamIntegration.initialized ? qsTr("Coop (beta)") : qsTr("About")
        onTriggered: SteamIntegration.initialized ? ComponentsContext.multiplayerPopupVisible = true : ComponentsContext.aboutPopupVisible = true
    }

    MenuItem {
        text: qsTr("Help")
        onTriggered: ComponentsContext.rulesPopupVisible = true
    }

    MenuSeparator { }

    MenuItem {
        text: qsTr("Exit")
        onTriggered: Qt.quit()
    }
}
