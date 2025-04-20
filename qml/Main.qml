pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Window
import Odizinne.Retr0Mine
import QtQuick.Effects

ApplicationWindow {
    id: root
    visibility: ApplicationWindow.Hidden
    Universal.theme: Constants.universalTheme
    Universal.accent: Constants.accentColor
    property int currentTheme: Universal.theme
    property bool isSaving: false
    property bool isClosing: false
    property var startTime: null

    header: TopBar {}

    onCurrentThemeChanged: {
        if (currentTheme === Universal.Light) {
            Constants.isDarkMode = false
            if (UserSettings.customTitlebar) GameCore.setTitlebarColor(1)
        } else {
            Constants.isDarkMode = true
            if (UserSettings.customTitlebar) GameCore.setTitlebarColor(0)
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
        if (UserSettings.loadLastGame && GameState.gameStarted && !GameState.gameOver && !GameState.bypassAutoSave) {
            close.accepted = false
            if (!isSaving) {
                isClosing = true
                isSaving = true
                SaveManager.saveGame("internalGameState.json")
            }
        } else {
            Qt.quit()
        }
    }

    Connections {
        target: CellRadialHelper
        function onLongPressDetected(cellIndex, globalX, globalY, isFlagged, isQuestioned, isRevealed) {
            var localPos = gameView.mapFromGlobal(globalX, globalY)

            radialMenu.cellIndex = cellIndex
            radialMenu.isFlagged = isFlagged
            radialMenu.isQuestioned = isQuestioned
            radialMenu.isRevealed = isRevealed

            radialMenu.x = localPos.x - radialMenu.width/2
            radialMenu.y = localPos.y - radialMenu.height/2

            radialMenu.open()
        }
    }

    RadialMenu {
        id: radialMenu
        parent: gameView
        visible: false
    }

    Connections {
        target: SteamIntegration

        function onInviteReceived(name, connectData) {
            if (UserSettings.mpShowInviteNotificationInGame) {
                inviteToast.showInvite(name, connectData)
                root.alert(0)
            }
        }

        function onGameStateReceived(gameState) {
            if (gameState.gridSync) {
                NetworkManager.handleMultiplayerGridSync(gameState)
            }
        }

        function onLobbyReadyChanged() {
            if (SteamIntegration.isLobbyReady) {
                if (SteamIntegration.isHost) {
                    const difficultySet = GameState.difficultySettings[UserSettings.difficulty]

                    const gridSyncData = {
                        gridSync: true,
                        gridSizeX: difficultySet.x,
                        gridSizeY: difficultySet.y,
                        mineCount: difficultySet.mines
                    }

                    SteamIntegration.sendGameState(gridSyncData)
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
                NetworkManager.allowClientReveal = false
                GridBridge.initGame()
            } else {
                if (NetworkManager.isProcessingNetworkAction) {
                    NetworkManager.isProcessingNetworkAction = false
                }
                NetworkManager.sessionRunning = false
                NetworkManager.mpPopupCloseButtonVisible = false
                ComponentsContext.privateSessionPopupVisible = false
            }
        }

        function onConnectedPlayerChanged() {
            if (SteamIntegration.connectedPlayerName) {
            } else if (SteamIntegration.isInMultiplayerGame) {
                NetworkManager.sessionRunning = false
                NetworkManager.mpPopupCloseButtonVisible = false
            }
        }

        function onConnectionFailed(reason) {
            ComponentsContext.mpErrorReason = reason
            ComponentsContext.multiplayerErrorPopupVisible = true
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
                    NetworkManager.notifyGridReady()
                }
            }

            if (!SteamIntegration.isInMultiplayerGame && GameState.firstRun) {
                GameState.firstRun = false
                root.checkInitialGameState()
            }
        }
    }

    Connections {
        target: GridBridge
        function onCellsCreatedChanged() {
            if (GridBridge.cellsCreated === 0) {
                if (root.startTime === null) {
                    root.startTime = new Date()
                    LogManager.info("Starting grid creation...")
                }
            } else if (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) {
                if (root.startTime) {
                    const endTime = new Date()
                    const timeDiff = endTime - root.startTime
                    const seconds = Math.floor(timeDiff / 1000)
                    const centiseconds = Math.floor((timeDiff % 1000) / 10)

                    LogManager.info(`Grid created in ${seconds}.${centiseconds.toString().padStart(2, '0')} seconds ` +
                                    `(${GameState.gridSizeX}x${GameState.gridSizeY}, ${GridBridge.cellsCreated} cells)`)

                    root.startTime = null
                    if (UserSettings.rumble) {
                        SteamIntegration.triggerRumble(0.8, 0.8, 0.3)
                    }
                }
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
        target: UserSettings
        function onCellSpacingChanged() {
            if (root.visibility === ApplicationWindow.Windowed) {
                root.minimumWidth = root.getIdealWidth()
                root.minimumHeight = root.getIdealHeight()
                root.width = root.minimumWidth
                root.height = root.minimumHeight
            }
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
                    ComponentsContext.privateSessionPopupVisible = true
                }
            }
        }
    }

    onVisibilityChanged: {
        if (visibility === ApplicationWindow.Windowed) setWindowInitialSizeAndPos()
    }

    Component.onCompleted: {
        LogManager.info("Application started")
        LogManager.info("Steam initialized: " + SteamIntegration.initialized)

        root.startTime = new Date()
        LogManager.info("Starting initial grid creation...")

        let internalSaveData = GameCore.loadGameState("internalGameState.json")
        if (internalSaveData) {
            SaveManager.extractAndApplyGridSize(internalSaveData)
        } else {
            const difficultySet = GameState.difficultySettings[UserSettings.difficulty]
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
                LogManager.error("Failed to parse leaderboard data: " + e.toString())
            }
        }

        if (currentTheme === Universal.Light) {
            Constants.isDarkMode = false
            if (UserSettings.customTitlebar) GameCore.setTitlebarColor(1)
        } else {
            Constants.isDarkMode = true
            if (UserSettings.customTitlebar) GameCore.setTitlebarColor(0)
        }

        GameCore.setApplicationPalette(UserSettings.accentColorIndex)

        if (UserSettings.startFullScreen || GameCore.gamescope) {
            visibility = ApplicationWindow.FullScreen
        } else {
            visibility = ApplicationWindow.Windowed
        }

        centerWindowToScreen()

        AudioEngine.playSilent()
    }

    Shortcut {
        sequence: "Ctrl+Q"
        autoRepeat: false
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: "Ctrl+D"
        autoRepeat: false
        onActivated: ComponentsContext.logWindowVisible = !ComponentsContext.logWindowVisible
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
        enabled: (!(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)) && (GameState.gameStarted || GameState.gameOver)
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
                root.visibility = ApplicationWindow.Windowed
            } else {
                root.visibility = ApplicationWindow.FullScreen
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
        active: !UserSettings.firstRunCompleted
        sourceComponent: Component {
            WelcomePopup {
                anchors.centerIn: parent
                visible: true
            }
        }
    }

    MainMenu {
        id: mainMenu
    }

    InviteReceivedPopup {
        id: inviteToast
        x: 13
        y: 35 + 23
        z: 1000
    }

    BusyIndicator {
        /*==========================================
         | continous window update                 |
         | needed for steam overlay                |
         ==========================================*/
        opacity: 0
        visible: SteamIntegration.initialized && !GameCore.gamescope
    }

    SettingsWindow {
        id: settingsWindow
    }

    LogWindow {
        id: logWindow
    }

    Item {
        anchors.fill: parent
        anchors.bottomMargin: 12

        Item {
            id: contentArea
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                topMargin: 12
            }

            Flickable {
                id: gameView
                anchors {
                    left: parent.left
                    right: multiplayerChat.visible ? multiplayerChat.left : parent.right
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 12
                    rightMargin: multiplayerChat.visible ? 12 : 12
                }
                layer.enabled: UserSettings.blur && (GameState.paused || ComponentsContext.mainMenuVisible)
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: UserSettings.blur && (GameState.paused || ComponentsContext.mainMenuVisible) ? 1 : 0
                    blurMultiplier: 0.3
                }
                contentWidth: gridContainer.width - (UserSettings.cellSpacing * 2)
                contentHeight: gridContainer.height - (UserSettings.cellSpacing * 2)
                clip: true
                enabled: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) &&
                         !(SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost && !NetworkManager.clientGridReady)
                opacity: (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) ? 1 : 0
                ScrollBar.vertical: defaultVerticalScrollBar
                ScrollBar.horizontal: defaultHorizontalScrollBar
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                Behavior on opacity {
                    enabled: UserSettings.animations && (gameView.opacity === 0 || GameState.paused || gameView.opacity === 1)
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
                Item {
                    id: gridContainer
                    anchors.centerIn: parent
                    scale: UserSettings.gridScale
                    width: Math.max(grid.width * scale, gameView.width)
                    height: Math.max(grid.height * scale, gameView.height)

                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }

                    GameGrid {
                        id: grid
                        visible: UserSettings.firstRunCompleted
                        anchors.centerIn: parent
                        width: GameState.cellSize * GameState.gridSizeX
                        height: GameState.cellSize * GameState.gridSizeY
                        Component.onCompleted: {
                            GridBridge.setGrid(grid)
                        }
                        delegate: Loader {
                            id: cellLoader
                            asynchronous: true
                            required property int index
                            readonly property int row: Math.floor(index / GameState.gridSizeX)
                            readonly property int col: index % GameState.gridSizeX
                            readonly property real cellSize: GameState.cellSize
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
                                id: cell
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
                }
            }

            MultiplayerChat {
                id: multiplayerChat
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    rightMargin: 12
                }
                width: 300
                visible: ComponentsContext.multiplayerChatVisible
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
                policy: {
                    return gameView.contentHeight * gridContainer.scale > gameView.height &&
                           gameView.contentHeight > gameView.height ?
                           ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }
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
                policy: {
                    return gameView.contentWidth * gridContainer.scale > gameView.width &&
                           gameView.contentWidth > gameView.width ?
                           ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }
            }

            GridLoadingIndicator {
                anchors.fill: gameView
            }
        }
    }

    function checkInitialGameState() {
        let internalSaveData = GameCore.loadGameState("internalGameState.json")
        if (GameState.ignoreInternalGameState) {
            /*==========================================
             | bypass internalGameState loading        |
             | if user manually change difficulty      |
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
        /*==========================================
         | 24 = main item left + right margin      |
         | 300 = multiplayer chat width            |
         | 12 = multiplayer chat margin            |
         ==========================================*/
        if (visibility === ApplicationWindow.Windowed) {
            let baseWidth = (GameState.cellSize * GameState.gridSizeX) - (UserSettings.cellSpacing * 2) + 24
            if (ComponentsContext.multiplayerChatVisible) {
                baseWidth += 300 + 12
            }
            let availableWidth = GameCore.getCurrentMonitorAvailableWidth(root)

            return Math.min(baseWidth, availableWidth * 0.9)
        }
    }

    function getIdealHeight() {
        /*==========================================
         | 24 = main item top + bottom margin      |
         | 40 = topBar height                      |
         ==========================================*/
        if (visibility === ApplicationWindow.Windowed) {
            // Removed the TopBar height (35) and its margin (12) from the calculation
            let baseHeight = (GameState.cellSize * GameState.gridSizeY) - (UserSettings.cellSpacing * 2) + 24 + 40
            let availableHeight = GameCore.getCurrentMonitorAvailableHeight(root)
            return Math.min(baseHeight, availableHeight * 0.9)
        }
    }

    function setWindowInitialSizeAndPos() {
        if (visibility === ApplicationWindow.Windowed) {
            minimumWidth = getIdealWidth()
            minimumHeight = getIdealHeight()
            width = minimumWidth
            height = minimumHeight
        }
    }

    function centerWindowToScreen() {
        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2
    }
}
