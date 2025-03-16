import QtQuick.Controls
import net.odizinne.retr0mine

Menu {
    topMargin: 58
    id: menu
    width: 150
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("New game")
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        onTriggered: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Save game")
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.savePopupVisible = true
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Load game")
        enabled: !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.loadPopupVisible = true
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Hint")
        enabled: GameState.gameStarted && !GameState.gameOver
        onTriggered: GridBridge.requestHint()
    }

    MenuSeparator { }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Settings")
        onTriggered: ComponentsContext.settingsWindowVisible = true
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Leaderboard")
        onTriggered: ComponentsContext.leaderboardPopupVisible = true
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: SteamIntegration.initialized ? qsTr("Coop (Beta)") : qsTr("About")
        onTriggered: {
            SteamIntegration.initialized ? ComponentsContext.privateSessionPopupVisible = true : ComponentsContext.aboutPopupVisible = true
        }
    }

    MenuSeparator { }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Help")
        onTriggered: ComponentsContext.rulesPopupVisible = true
    }

    MenuItem {
        height: GameCore.isFluent ? implicitHeight - 2 : implicitHeight - 6
        text: qsTr("Exit")
        onTriggered: Qt.quit()
    }
}
