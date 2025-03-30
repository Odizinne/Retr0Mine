pragma Singleton
import QtQuick
import Odizinne.Retr0Mine
QtObject {
    id: steamInput
    signal requestSignal()
    Component.onCompleted: {
        SteamIntegration.newGameActionTriggered.connect(startNewGame);
        SteamIntegration.loadGameActionTriggered.connect(loadGame);
        SteamIntegration.saveGameActionTriggered.connect(saveGame);
        SteamIntegration.showLeaderboardActionTriggered.connect(showLeaderboard);
        SteamIntegration.toggleSettingsActionTriggered.connect(toggleSettings);
        SteamIntegration.zoomInActionTriggered.connect(zoomIn);
        SteamIntegration.zoomOutActionTriggered.connect(zoomOut);
        SteamIntegration.signalCellActionTriggered.connect(signalCell);
        SteamIntegration.requestHintActionTriggered.connect(requestHint);
    }
    function startNewGame() {
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }
    function loadGame() {
        if (!SteamIntegration.isInMultiplayerGame) {
            ComponentsContext.loadPopupVisible = !ComponentsContext.loadPopupVisible
        }
    }
    function saveGame() {
        if (GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame) {
            ComponentsContext.savePopupVisible = !ComponentsContext.savePopupVisible
        }
    }
    function showLeaderboard() {
        ComponentsContext.leaderboardPopupVisible = true
    }
    function zoomIn() {
        if (UserSettings.gridScale < 2) {
            UserSettings.gridScale = Math.min(2, UserSettings.gridScale + 0.1);
        }
    }
    function zoomOut() {
        if (UserSettings.gridScale > 1) {
            UserSettings.gridScale = Math.max(1, UserSettings.gridScale - 0.1);
        }
    }
    function toggleSettings() {
        ComponentsContext.settingsWindowVisible = !ComponentsContext.settingsWindowVisible
    }
    function signalCell() {
        requestSignal()
    }
    function requestHint() {
        GridBridge.requestHint()
    }
}
