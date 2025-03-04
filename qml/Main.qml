pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import net.odizinne.retr0mine 1.0

ApplicationWindow {
    id: root
    visibility: ApplicationWindow.Hidden
    property bool isSaving: false
    property bool isClosing: false
    property Timer starterTimer: Timer {
        interval: 0
        repeat: false
        onTriggered: {
            // Check for pending invites only once at startup
            if (SteamIntegration.initialized) {
                SteamIntegration.checkForPendingInvites()
            }
        }
    }

    onClosing: function(close) {
        if (isClosing) {
            close.accepted = true
            return
        }

        var bypassSaving
        if (SteamIntegration.isInMultiplayerGame) {
            // Pass true to indicate we're shutting down
            GameState.bypassAutoSave = true
            SteamIntegration.cleanupMultiplayerSession(true)
        }

        if (GameSettings.loadLastGame && GameState.gameStarted && !GameState.gameOver && !GameState.bypassAutoSave) {
            close.accepted = false
            if (!isSaving) {
                isClosing = true
                isSaving = true
                SaveManager.saveGame("internalGameState.json")
            }
        } else {
            close.accepted = true
        }
    }

    Connections {
        target: SteamIntegration

        function onGameStateReceived(gameState) {
            // Check if this is a grid sync packet
            if (gameState.gridSync) {
                console.log("Received grid sync game state");
                NetworkManager.handleMultiplayerGridSync(gameState);
            }
        }

        function onLobbyReadyChanged() {
            if (SteamIntegration.isLobbyReady) {
                console.log("Lobby ready, initializing multiplayer game");

                if (SteamIntegration.isHost) {
                    // Get current host's difficulty settings
                    const difficultySet = GameState.difficultySettings[GameSettings.difficulty];

                    // Prepare grid sync data packet
                    const gridSyncData = {
                        gridSync: true,
                        gridSizeX: difficultySet.x,
                        gridSizeY: difficultySet.y,
                        mineCount: difficultySet.mines
                    };

                    console.log("Sending grid sync:", JSON.stringify(gridSyncData));
                    SteamIntegration.sendGameState(gridSyncData);
                } else {
                    // Client will wait for grid sync from host
                    console.log("Client waiting for grid sync");
                }
            }
        }

        function onConnectionSucceeded() {
            // Only show popup when joining as client (not as host)
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                ComponentsContext.multiplayerPopupVisible = true
            }
        }

        // Handle multiplayer status changes
        function onIsInMultiplayerGameChanged() {
            if (SteamIntegration.isInMultiplayerGame) {
                console.log("Entered multiplayer mode as",
                    SteamIntegration.isHost ? "host" : "client");

                // Reset any in-progress game if joining a multiplayer session
                NetworkManager.allowClientReveal = false;
                GridBridge.initGame();
            } else {
                console.log("Left multiplayer mode");

                if (NetworkManager.isProcessingNetworkAction) {
                    NetworkManager.isProcessingNetworkAction = false;
                }
                NetworkManager.sessionRunning = false;
                NetworkManager.mpPopupCloseButtonVisible = false;
                GridBridge.initGame();
            }
        }

        // Additional event to handle connection events
        function onConnectedPlayerChanged() {
            if (SteamIntegration.connectedPlayerName) {
                console.log("Player connected:", SteamIntegration.connectedPlayerName);
            } else if (SteamIntegration.isInMultiplayerGame) {
                NetworkManager.sessionRunning = false;
                NetworkManager.mpPopupCloseButtonVisible = false;
                console.log("Player disconnected");
            }
        }

        // Track connection failures
        function onConnectionFailed(reason) {
            console.error("Connection failed:", reason);
        }
    }

    Connections {
        target: ComponentsContext
        function onAllCellsReady() {

            // If in multiplayer as client, notify host that grid is ready
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                // Only send if the cell count matches expected grid size
                if (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) {
                    NetworkManager.notifyGridReady();
                }
            }

            // Continue with normal game initialization for single player
            if (!SteamIntegration.isInMultiplayerGame && GameState.firstRun) {
                GameState.firstRun = false
                root.checkInitialGameState();
            }
        }
    }

    Connections {
        target: GameState
        function onGridSizeXChanged() {
            if (root.visibility === ApplicationWindow.Windowed) {
                root.minimumWidth = root.getIdealWidth()
                root.width = root.minimumWidth
            }
        }
        function onGridSizeYChanged() {
            if (root.visibility === ApplicationWindow.Windowed) {
                root.minimumHeight = root.getIdealHeight()
                root.height = root.minimumHeight
            }
        }
        function onCellSizeChanged() {
            onGridSizeXChanged()
            onGridSizeYChanged()
        }
    }

    Connections {
        target: GameCore
        enabled: !SaveManager.manualSave
        function onSaveCompleted(success) {
            root.isSaving = false
            Qt.quit()
        }
    }

    onVisibilityChanged: function(visibility) {
        if (visibility === ApplicationWindow.Windowed) {
            minimumWidth = getIdealWidth()
            minimumHeight = getIdealHeight()
            width = minimumWidth
            height = minimumHeight

            if (height >= Screen.desktopAvailableHeight * 0.9 ||
                    width >= Screen.desktopAvailableWidth * 0.9) {
                x = Screen.width / 2 - width / 2
                y = Screen.height / 2 - height / 2
            }
        }
    }

    Component.onCompleted: {
        const difficultySet = GameState.difficultySettings[GameSettings.difficulty]
        GameState.gridSizeX = difficultySet.x
        GameState.gridSizeY = difficultySet.y
        GameState.mineCount = difficultySet.mines

        let leaderboardData = GameCore.loadLeaderboard()
        if (leaderboardData) {
            try {
                const leaderboard = JSON.parse(leaderboardData)
                leaderboardWindow.easyTime = leaderboard.easyTime || ""
                leaderboardWindow.mediumTime = leaderboard.mediumTime || ""
                leaderboardWindow.hardTime = leaderboard.hardTime || ""
                leaderboardWindow.retr0Time = leaderboard.retr0Time || ""
                leaderboardWindow.easyWins = leaderboard.easyWins || 0
                leaderboardWindow.mediumWins = leaderboard.mediumWins || 0
                leaderboardWindow.hardWins = leaderboard.hardWins || 0
                leaderboardWindow.retr0Wins = leaderboard.retr0Wins || 0
            } catch (e) {
                console.error("Failed to parse leaderboard data:", e)
            }
        }

        if (typeof Universal !== "undefined") {
            Universal.theme = GameCore.gamescope ? Universal.Dark : Universal.System
            Universal.accent = GameConstants.accentColor
        }

        if (GameSettings.startFullScreen || GameCore.gamescope) {
            root.visibility = ApplicationWindow.FullScreen
        } else {
            root.visibility = ApplicationWindow.Windowed
        }

        root.width = getIdealWidth()
        root.minimumWidth = getIdealWidth()
        root.height = getIdealHeight()
        root.minimumHeight = getIdealHeight()
    }

    GridLoadingIndicator {
        anchors.fill: gameView
    }

    MouseArea {
        // Normalize cursor shape in gamescope
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        propagateComposedEvents: true
        visible: GameCore.gamescope
        z: -1
        onPressed: function(mouse) { mouse.accepted = false; }
        onReleased: function(mouse) { mouse.accepted = false; }
        onClicked: function(mouse) { mouse.accepted = false; }
    }

    Shortcut {
        sequence: "Ctrl+Q"
        autoRepeat: false
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: StandardKey.Save
        enabled: GameState.gameStarted && !GameState.gameOver && !SteamIntegration.isInMultiplayerGame
        autoRepeat: false
        onActivated: ComponentsContext.savePopupVisible = true
    }

    Shortcut {
        sequence: StandardKey.Open
        enabled: !SteamIntegration.isInMultiplayerGame
        autoRepeat: false
        onActivated: ComponentsContext.loadPopupVisible = true
    }

    Shortcut {
        sequence: StandardKey.New
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        autoRepeat: false
        onActivated: {
            GameState.difficultyChanged = false
            GridBridge.initGame()
        }
    }

    Shortcut {
        sequence: "Ctrl+P"
        autoRepeat: false
        onActivated: {
            if (ComponentsContext.settingsWindowVisible) {
                // close is needed for proper DWM next opening animation
                settingsWindow.close()
                ComponentsContext.settingsWindowVisible = false
            } else {
                ComponentsContext.settingsWindowVisible = true
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+L"
        autoRepeat: false
        onActivated: ComponentsContext.leaderboardPopupVisible = true
    }

    Shortcut {
        sequence: "F11"
        autoRepeat: false
        onActivated: {
            if (root.visibility === ApplicationWindow.FullScreen) {
                root.visibility = ApplicationWindow.Windowed;
            } else {
                root.visibility = ApplicationWindow.FullScreen;
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+H"
        autoRepeat: false
        onActivated: GridBridge.requestHint()
    }

    Loader {
        anchors.fill: parent
        active: GameCore.showWelcome
        sourceComponent: Component {
            WelcomePopup {
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: true
        sourceComponent: SteamIntegration.initialized ? multiplayerPopupComponent : aboutPopupComponent

        Component {
            id: multiplayerPopupComponent
            MultiplayerPopup { }
        }

        Component {
            id: aboutPopupComponent
            AboutPopup { }
        }
    }

    RulesPopup { }
    GenerationPopup { }

    PostgamePopup { }

    SettingsWindow {
        id: settingsWindow
    }

    LoadPopup { }

    SavePopup { }

    PausePopup { }

    MultiplayerPopup { }
    LeaderboardPopup {
        id: leaderboardWindow
        Component.onCompleted: GridBridge.setLeaderboardWindow(leaderboardWindow)
    }

    BusyIndicator {
        opacity: 0
        // continous window update (steam overlay)
    }

    TopBar {
        id: topBar
    }

    GameView {
        id: gameView
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: topBar.bottom
            topMargin: 10
            leftMargin: 12
            rightMargin: 12
            bottomMargin: 12
        }
        contentWidth: gridContainer.width
        contentHeight: gridContainer.height
        clip: true
        enabled: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)
        opacity: (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) && !GameState.paused) ? 1 : 0

        Behavior on opacity {
            enabled: GameSettings.animations && (gameView.opacity === 0 || GameState.paused || gameView.opacity === 1)
            NumberAnimation {
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            id: gridContainer
            anchors.centerIn: parent
            width: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX, gameView.width)
            height: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY, gameView.height)

            GameGrid {
                id: grid
                Component.onCompleted: {
                    GridBridge.setGrid(grid)
                }
                enabled: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && !NetworkManager.allowClientReveal ? false : true
                delegate: Loader {
                    id: cellLoader
                    asynchronous: true
                    required property int index
                    sourceComponent: Cell {
                        index: cellLoader.index
                    }
                }
            }
        }
    }

    function checkInitialGameState() {
        let internalSaveData = GameCore.loadGameState("internalGameState.json")
        if (internalSaveData) {
            if (SaveManager.loadGame(internalSaveData)) {
                GameCore.deleteSaveFile("internalGameState.json")
                GameState.isManuallyLoaded = false
            } else {
                console.error("Failed to load internal game state")
                GridBridge.initGame()
            }
        } else {
            GridBridge.initGame()
        }
        starterTimer.start()
    }

    function getIdealWidth() {
        if (root.visibility === ApplicationWindow.Windowed) {
            return Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX + 24,
                            Screen.desktopAvailableWidth * 0.9)
        }
    }

    function getIdealHeight() {
        if (root.visibility === ApplicationWindow.Windowed) {
            return Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY + 69,
                            Screen.desktopAvailableHeight * 0.9)
        }
    }
}

