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

    Connections {
        target: ComponentsContext
        function onAllCellsReady() {
            root.checkInitialGameState()
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

        visibility = ApplicationWindow.Windowed
    }

    BusyIndicator {
        // stupid, but allow continuous engine update
        // without too much hassle (needed for steam overlay)
        opacity: 0
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
        enabled: GameState.gameStarted && !GameState.gameOver
        autoRepeat: false
        onActivated: ComponentsContext.savePopupVisible = true
    }

    Shortcut {
        sequence: StandardKey.Open
        autoRepeat: false
        onActivated: ComponentsContext.loadPopupVisible = true
    }

    Shortcut {
        sequence: StandardKey.New
        autoRepeat: false
        onActivated: GridBridge.initGame()
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
        id: welcomeLoader
        anchors.fill: parent
        active: GameCore.showWelcome
        sourceComponent: Component {
            WelcomePopup {
            }
        }
    }

    Loader {
        id: aboutLoader
        anchors.fill: parent
        active: !SteamIntegration.initialized
        sourceComponent: Component {
            AboutPopup {
            }
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

    LeaderboardPopup {
        id: leaderboardWindow
        Component.onCompleted: GridBridge.setLeaderboardWindow(leaderboardWindow)
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

        Item {
            id: gridContainer
            anchors.centerIn: parent
            width: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX, gameView.width)
            height: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY, gameView.height)

            GameGrid {
                id: grid
                Component.onCompleted: {
                    GridBridge.setGrid(grid)
                    SaveManager.setGrid(grid)
                }
                delegate: Loader {
                    id: cellLoader
                    asynchronous: true
                    required property int index
                    sourceComponent: Cell {
                        index: cellLoader.index  // Pass it to the Cell
                    }
                }
            }
        }
    }

    function checkInitialGameState() {
        if (!GameState.gridFullyInitialized) return

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

    function getIdealWidth() {
        if (root.visibility === ApplicationWindow.Windowed) {
            return Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX + 24,
                            Screen.desktopAvailableWidth * 0.9)
        }
    }

    function getIdealHeight() {
        if (root.visibility === ApplicationWindow.Windowed) {
            return Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY + 74,
                            Screen.desktopAvailableHeight * 0.9)
        }
    }
}

