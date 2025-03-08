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

    onClosing: function(close) {
        if (isClosing) {
            close.accepted = true
            return
        }
        if (SteamIntegration.isInMultiplayerGame) {
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

        function onInviteReceived(name, connectData) {
            if (GameSettings.mpShowInviteNotificationInGame) {
                inviteToast.friendName = name
                inviteToast.connectData = connectData
                inviteToast.visible = true
            }
        }

        function onGameStateReceived(gameState) {
            if (gameState.gridSync) {
                console.log("Received grid sync game state");
                NetworkManager.handleMultiplayerGridSync(gameState);
            }
        }

        function onLobbyReadyChanged() {
            if (SteamIntegration.isLobbyReady) {
                console.log("Lobby ready, initializing multiplayer game");

                if (SteamIntegration.isHost) {
                    const difficultySet = GameState.difficultySettings[GameSettings.difficulty];

                    const gridSyncData = {
                        gridSync: true,
                        gridSizeX: difficultySet.x,
                        gridSizeY: difficultySet.y,
                        mineCount: difficultySet.mines
                    };

                    console.log("Sending grid sync:", JSON.stringify(gridSyncData));
                    SteamIntegration.sendGameState(gridSyncData);
                } else {
                    console.log("Client waiting for grid sync");
                }
            }
        }

        function onConnectionSucceeded() {
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                ComponentsContext.multiplayerPopupVisible = true
            }
        }

        function onIsInMultiplayerGameChanged() {
            if (SteamIntegration.isInMultiplayerGame) {
                console.log("Entered multiplayer mode as",
                            SteamIntegration.isHost ? "host" : "client");

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

        function onConnectedPlayerChanged() {
            if (SteamIntegration.connectedPlayerName) {
                console.log("Player connected:", SteamIntegration.connectedPlayerName);
            } else if (SteamIntegration.isInMultiplayerGame) {
                NetworkManager.sessionRunning = false;
                NetworkManager.mpPopupCloseButtonVisible = false;
                console.log("Player disconnected");
            }
        }

        function onConnectionFailed(reason) {
            ComponentsContext.mpErrorReason = reason;
            ComponentsContext.multiplayerErrorPopupVisible = true;
        }
    }

    Connections {
        target: ComponentsContext
        function onAllCellsReady() {

            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                if (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) {
                    NetworkManager.notifyGridReady();
                }
            }

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
        target: ComponentsContext
        function onMultiplayerChatVisibleChanged() {
            if (root.visibility === ApplicationWindow.Windowed) {
                root.minimumWidth = root.getIdealWidth()
                root.width = root.minimumWidth
            }
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

    MultiplayerErrorPopup { }

    RulesPopup { }

    GenerationPopup { }

    PostgamePopup { }

    LoadPopup { }

    SavePopup { }

    PausePopup { }

    MultiplayerPopup { }

    LeaderboardPopup {
        id: leaderboardWindow
        Component.onCompleted: GridBridge.setLeaderboardWindow(leaderboardWindow)
    }

    InviteReceivedPopup {
        id: inviteToast
        x: 13
        y: 35 + 23
        z: 1000
    }

    BusyIndicator {
        opacity: 0
        // continous window update (steam overlay)
    }

    SettingsWindow {
        id: settingsWindow
    }

    Item {

        // Main layout container (adjust width/height as needed)
        anchors.fill: parent

        // Top bar spanning full width
        TopBar {
            id: topBar
            anchors {
                left: parent.left
                right: rightPanel.visible ? rightPanel.left : parent.right
                top: parent.top
                topMargin: 12
                leftMargin: 13
                rightMargin: 15
            }
        }

        // Right side panel (new)
        MultiplayerChat {  // Or your custom Item component
            id: rightPanel
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
                topMargin: 10
                rightMargin: 12
                bottomMargin: 12
            }
            width: 300  // Adjust width as needed
            // For visualization
            visible: ComponentsContext.multiplayerChatVisible
            // Your right panel content here
        }

        // Game view - now anchored to rightPanel instead of parent.right
        Flickable {
            id: gameView
            anchors {
                left: parent.left
                right: rightPanel.visible ? rightPanel.left : parent.right
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
            ScrollBar.vertical: GameCore.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
            ScrollBar.horizontal: GameCore.isFluent ? fluentHorizontalScrollBar : defaultHorizontalScrollBar
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

        ScrollBar {
            id: defaultVerticalScrollBar
            enabled: gameView.enabled
            opacity: gameView.opacity
            orientation: Qt.Vertical
            anchors.right: gameView.right
            anchors.rightMargin: -12
            anchors.top: gameView.top
            anchors.bottom: gameView.bottom
            visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
            active: !GameCore.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > gameView.height ?
                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        ScrollBar {
            id: defaultHorizontalScrollBar
            enabled: gameView.enabled
            opacity: gameView.opacity
            orientation: Qt.Horizontal
            anchors.left: gameView.left
            anchors.right: gameView.right
            anchors.bottom: gameView.bottom
            anchors.bottomMargin: -12
            visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
            active: !GameCore.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > gameView.width ?
                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentVerticalScrollBar
            enabled: gameView.enabled
            opacity: gameView.opacity
            orientation: Qt.Vertical
            anchors.right: gameView.right
            anchors.rightMargin: -12
            anchors.top: gameView.top
            anchors.bottom: gameView.bottom
            visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
            active: GameCore.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > gameView.height ?
                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentHorizontalScrollBar
            enabled: gameView.enabled
            opacity: gameView.opacity
            orientation: Qt.Horizontal
            anchors.left: gameView.left
            anchors.right: gameView.right
            anchors.bottom: gameView.bottom
            anchors.bottomMargin: -12
            visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
            active: GameCore.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > gameView.width ?
                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        GridLoadingIndicator {
            anchors.fill: gameView
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
        if (SteamIntegration.initialized) {
            SteamIntegration.checkForPendingInvites()
        }
    }

    function getIdealWidth() {
        if (root.visibility === ApplicationWindow.Windowed) {
            let baseWidth = (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX + 24

            // Add chat panel width if visible
            if (ComponentsContext.multiplayerChatVisible) {
                baseWidth += rightPanel.width + 12 // Adding the panel width plus margin
            }

            return Math.min(baseWidth, Screen.desktopAvailableWidth * 0.9)
        }
    }

    function getIdealHeight() {
        if (root.visibility === ApplicationWindow.Windowed) {
            return Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY + 69,
                            Screen.desktopAvailableHeight * 0.9)
        }
    }
}

