pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Window
import net.odizinne.retr0mine 1.0
import QtQuick.Effects

ApplicationWindow {
    id: root
    visibility: ApplicationWindow.Hidden
    Universal.theme: GameConstants.universalTheme
    Universal.accent: GameConstants.accentColor
    property int currentTheme: Universal.theme
    property bool isSaving: false
    property bool isClosing: false
    property var startTime: null

    onCurrentThemeChanged: {
        if (currentTheme === Universal.Light) {
            GameConstants.isDarkMode = false
        } else {
            GameConstants.isDarkMode = true
        }
    }

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
                inviteToast.showInvite(name, connectData);
            }
        }

        function onGameStateReceived(gameState) {
            if (gameState.gridSync) {
                NetworkManager.handleMultiplayerGridSync(gameState);
            }
        }

        function onLobbyReadyChanged() {
            if (SteamIntegration.isLobbyReady) {
                if (SteamIntegration.isHost) {
                    const difficultySet = GameState.difficultySettings[GameSettings.difficulty];

                    const gridSyncData = {
                        gridSync: true,
                        gridSizeX: difficultySet.x,
                        gridSizeY: difficultySet.y,
                        mineCount: difficultySet.mines
                    };

                    SteamIntegration.sendGameState(gridSyncData);
                }
            }
        }

        function onConnectionSucceeded() {
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                ComponentsContext.privateSessionPopupVisible = true
            }
        }

        function onIsInMultiplayerGameChanged() {
            if (SteamIntegration.isInMultiplayerGame) {
                NetworkManager.allowClientReveal = false;
                GridBridge.initGame();
            } else {
                if (NetworkManager.isProcessingNetworkAction) {
                    NetworkManager.isProcessingNetworkAction = false;
                }
                NetworkManager.sessionRunning = false;
                NetworkManager.mpPopupCloseButtonVisible = false;
                ComponentsContext.privateSessionPopupVisible = false;
            }
        }

        function onConnectedPlayerChanged() {
            if (SteamIntegration.connectedPlayerName) {
            } else if (SteamIntegration.isInMultiplayerGame) {
                NetworkManager.sessionRunning = false;
                NetworkManager.mpPopupCloseButtonVisible = false;
            }
        }

        function onConnectionFailed(reason) {
            ComponentsContext.mpErrorReason = reason;
            ComponentsContext.multiplayerErrorPopupVisible = true;
        }

        function onNotifyConnectionLost(message) {
            playerLeftPopup.playerName = message
            ComponentsContext.playerLeftPopupVisible = true
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

    Connections {
        target: NetworkManager

        function onClientGridReadyChanged() {
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                if (!NetworkManager.clientGridReady) {
                    ComponentsContext.privateSessionPopupVisible = true;
                }
            }
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
        startTime = new Date()

        let internalSaveData = GameCore.loadGameState("internalGameState.json")
        if (internalSaveData) {
            SaveManager.extractAndApplyGridSize(internalSaveData)
        } else {
            const difficultySet = GameState.difficultySettings[GameSettings.difficulty]
            GameState.gridSizeX = difficultySet.x
            GameState.gridSizeY = difficultySet.y
            GameState.mineCount = difficultySet.mines
        }

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

        if (currentTheme === Universal.Light) {
            GameConstants.isDarkMode = false
        } else {
            GameConstants.isDarkMode = true
        }

        //root.Universal.theme = GameConstants.universalTheme
        GameCore.setApplicationPalette(GameSettings.accentColorIndex)


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
        /*==========================================
         | Normalize cursor shape in gamescope     |
         ==========================================*/
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
                /*==========================================
                 | close is needed for proper DWM          |
                 | next opening animation                  |
                 ==========================================*/
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
        active: !GameSettings.welcomeMessageShown
        sourceComponent: Component {
            WelcomePopup {
                anchors.centerIn: parent
                visible: true
            }
        }
    }

    InviteReceivedPopup {
        id: inviteToast
        x: 13
        y: 35 + 23
        z: 1000
    }

    BusyIndicator {
        opacity: 0
        /*==========================================
         | continous window update                 |
         | needed for steam overlay                |
         ==========================================*/
    }

    SettingsWindow {
        id: settingsWindow
    }

    Item {
        anchors.fill: parent

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

        MultiplayerChat {
            id: rightPanel
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
                topMargin: 10
                rightMargin: 12
                bottomMargin: 12
            }
            width: 300
            visible: ComponentsContext.multiplayerChatVisible
            Component.onCompleted: {
                GridBridge.setChatReference(this);
            }
        }

        Timer {
            id: zoomingResetTimer
            interval: 150
            onTriggered: GameState.isZooming = false
        }

        MouseArea {
            id: zoomHandler
            anchors.fill: gameView
            z: gameView.z + 1
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            hoverEnabled: false

            onWheel: function(wheel) {
                if (wheel.modifiers & Qt.ControlModifier) {
                    if (wheel.angleDelta.y > 0) {
                        if (GameSettings.gridScale < 2) {
                            GameState.isZooming = true;
                            GameSettings.gridScale = Math.min(2, GameSettings.gridScale + 0.1);
                            zoomingResetTimer.restart();
                        }
                    }
                    else if (wheel.angleDelta.y < 0) {
                        if (GameSettings.gridScale > 1) {
                            GameState.isZooming = true;
                            GameSettings.gridScale = Math.max(1, GameSettings.gridScale - 0.1);
                            zoomingResetTimer.restart();
                        }
                    }
                    wheel.accepted = true;
                } else {
                    wheel.accepted = false;
                }
            }
        }

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
            layer.enabled: GameState.paused
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: GameState.paused ? 1 : 0
                blurMultiplier: 0.3
            }
            contentWidth: gridContainer.width
            contentHeight: gridContainer.height
            clip: true
            enabled: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) &&
                     !(SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost && !NetworkManager.clientGridReady)
            opacity: (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) ? 1 : 0
            ScrollBar.vertical: defaultVerticalScrollBar
            ScrollBar.horizontal: defaultHorizontalScrollBar
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
                scale: GameSettings.gridScale
                width: Math.max(((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX) * scale, gameView.width)
                height: Math.max(((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY) * scale, gameView.height)

                Behavior on scale {
                    enabled: GameState.isZooming
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }

                GameGrid {
                    id: grid
                    Component.onCompleted: {
                        GridBridge.setGrid(grid)
                    }
                    delegate: Loader {
                        id: cellLoader
                        asynchronous: true
                        required property int index

                        readonly property int row: Math.floor(index / GameState.gridSizeX)
                        readonly property int col: index % GameState.gridSizeX
                        readonly property real cellSize: GameState.cellSize + GameState.cellSpacing
                        readonly property real xPos: col * cellSize
                        readonly property real yPos: row * cellSize

                        readonly property bool isInViewport: {
                            let viewportLeft = gameView.contentX / gridContainer.scale
                            let viewportTop = gameView.contentY / gridContainer.scale
                            let viewportRight = viewportLeft + (gameView.width / gridContainer.scale)
                            let viewportBottom = viewportTop + (gameView.height / gridContainer.scale)

                            let margin = 3 * cellSize
                            viewportLeft -= margin
                            viewportTop -= margin
                            viewportRight += margin
                            viewportBottom += margin

                            return (xPos + cellSize > viewportLeft &&
                                    xPos < viewportRight &&
                                    yPos + cellSize > viewportTop &&
                                    yPos < viewportBottom)
                        }

                        visible: isInViewport
                        sourceComponent: Cell {
                            index: cellLoader.index
                        }
                    }
                }
            }

            MultiplayerErrorPopup {
                anchors.centerIn: gameView
            }

            RulesPopup {
                anchors.centerIn: gameView
            }

            GenerationPopup {
                anchors.centerIn: gameView
            }

            PostgamePopup {
                anchors.centerIn: gameView
            }

            LoadPopup {
                anchors.centerIn: gameView
            }

            SavePopup {
                anchors.centerIn: gameView
            }

            PausePopup {
                anchors.centerIn: gameView
            }

            PrivateSessionPopup {
                anchors.centerIn: gameView
            }

            AboutPopup {
                anchors.centerIn: gameView
            }

            PlayerLeftPopup {
                id: playerLeftPopup
                anchors.centerIn: gameView
            }

            LeaderboardPopup {
                id: leaderboardWindow
                anchors.centerIn: gameView
                Component.onCompleted: GridBridge.setLeaderboardWindow(leaderboardWindow)
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
            visible: policy === ScrollBar.AlwaysOn
            active: true
            policy: ((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY) * gridContainer.scale > gameView.height ?
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
            visible: policy === ScrollBar.AlwaysOn
            active: true
            policy: ((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX) * gridContainer.scale > gameView.width ?
                        ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        GridLoadingIndicator {
            anchors.fill: gameView
        }
    }

    function checkInitialGameState() {
        const endTime = new Date()
        const elapsedMs = endTime - startTime
        const seconds = Math.floor(elapsedMs / 1000)
        const centiseconds = Math.floor((elapsedMs % 1000) / 10)
        const formattedTime = seconds.toString().padStart(2, '0') + ":" +
                            centiseconds.toString().padStart(2, '0')

        console.log("Grid initialization performed in: " + formattedTime)



        let internalSaveData = GameCore.loadGameState("internalGameState.json")
        if (GameState.ignoreInternalGameState) {
            /*==========================================
             | bypass internalGameState loading        |
             | f user manually change difficulty       |
             | before initial game state check         |
             ==========================================*/
            GameCore.deleteSaveFile("internalGameState.json")
            internalSaveData = null
        }

        if (internalSaveData) {
            if (SaveManager.loadGame(internalSaveData)) {
                GameCore.deleteSaveFile("internalGameState.json")
                GameState.isManuallyLoaded = false
            } else {
                GameCore.deleteSaveFile("internalGameState.json")
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
            if (ComponentsContext.multiplayerChatVisible) {
                baseWidth += rightPanel.width + 12
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

