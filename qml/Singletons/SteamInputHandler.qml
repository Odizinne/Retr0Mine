pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

QtObject {
    id: steamInput

    signal requestSignal()
    Component.onCompleted: {
        SteamIntegration.newGameActionTriggered.connect(startNewGame);
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

    function zoomIn() {
        if (GameSettings.gridScale < 2) {
            GameSettings.gridScale = Math.min(2, GameSettings.gridScale + 0.1);
        }
    }

    function zoomOut() {
        if (GameSettings.gridScale > 1) {
            GameSettings.gridScale = Math.max(1, GameSettings.gridScale - 0.1);
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
