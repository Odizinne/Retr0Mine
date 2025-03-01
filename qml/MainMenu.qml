import QtQuick.Controls
import net.odizinne.retr0mine

Menu {
    topMargin: 60
    id: menu
    width: 150
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    MenuItem {
        text: qsTr("New game")
        onTriggered: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    MenuItem {
        text: qsTr("Save game")
        enabled: GameState.gameStarted && !GameState.gameOver
        onTriggered: ComponentsContext.savePopupVisible = true
    }

    MenuItem {
        id: loadMenu
        text: qsTr("Load game")
        onTriggered: ComponentsContext.loadPopupVisible = true
    }

    MenuItem {
        text: qsTr("Hint")
        enabled: GameState.gameStarted && !GameState.gameOver
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
        text: qsTr("About")
        height: !SteamIntegration.initialized ? implicitHeight : 0
        visible: height > 0
        onTriggered: ComponentsContext.aboutPopupVisible = true
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
