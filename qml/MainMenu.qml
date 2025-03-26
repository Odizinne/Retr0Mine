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
    MenuItem {
        height: implicitHeight - 6
        text: qsTr("New game")
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        onTriggered: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Save game")
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.savePopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Load game")
        enabled: !SteamIntegration.isInMultiplayerGame
        onTriggered: ComponentsContext.loadPopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Hint")
        enabled: GameState.gameStarted && !GameState.gameOver
        onTriggered: GridBridge.requestHint()
    }

    MenuSeparator { }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Leaderboard")
        onTriggered: ComponentsContext.leaderboardPopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        enabled: SteamIntegration.initialized
        text: qsTr("Multiplayer")
        onTriggered: ComponentsContext.privateSessionPopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("About")
        onTriggered: ComponentsContext.aboutPopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Settings")
        onTriggered: ComponentsContext.settingsWindowVisible = true
    }

    MenuSeparator { }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Help")
        onTriggered: ComponentsContext.rulesPopupVisible = true
    }

    MenuItem {
        height: implicitHeight - 6
        text: qsTr("Exit")
        onTriggered: Qt.quit()
    }
}
