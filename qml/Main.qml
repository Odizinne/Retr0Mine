pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: root
    visible: true
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()

    Connections {
        target: GameState

        function onGridSizeChanged() {
            if (root.visibility === Window.Windowed) {
                root.width = root.getInitialWidth()
                root.height = root.getInitialHeight()
                root.minimumWidth = root.width
                root.minimumHeight = root.height

                // Auto-maximize if window would be too large
                if (root.width >= Screen.desktopAvailableWidth * 0.9 ||
                    root.height >= Screen.desktopAvailableHeight * 0.9) {
                    root.visibility = Window.Maximized
                }
            }
        }

        function onCellSizeChanged() {
            onGridSizeChanged()
        }
    }

    onClosing: {
        if (Retr0MineSettings.loadLastGame && GameState.gameStarted && !GameState.gameOver) {
            SaveManager.saveGame("internalGameState.json")
        }
    }

    onVisibilityChanged: function(visibility) {
        if (visibility === Window.Windowed) {
            width = getInitialWidth()
            height = getInitialHeight()
            minimumWidth = width
            minimumHeight = height

            // Center window if it would be too large
            if (height >= Screen.desktopAvailableHeight * 0.9 ||
                width >= Screen.desktopAvailableWidth * 0.9) {
                x = Screen.width / 2 - width / 2
                y = Screen.height / 2 - height / 2
            }
        }
    }

    Component.onCompleted: {
        const difficultySet = GameState.difficultySettings[Retr0MineSettings.difficulty]
        GameState.gridSizeX = difficultySet.x
        GameState.gridSizeY = difficultySet.y
        GameState.mineCount = difficultySet.mines

        let leaderboardData = MainWindow.loadLeaderboard()
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

        if (typeof Universal !== undefined) {
            Universal.theme = MainWindow.gamescope ? Universal.Dark : Universal.System
            Universal.accent = Colors.accentColor
        }
    }

    BusyIndicator {
        opacity: 0
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
        onActivated: saveWindow.visible = true
    }

    Shortcut {
        sequence: StandardKey.Open
        autoRepeat: false
        onActivated: loadWindow.visible = true
    }

    Shortcut {
        sequence: StandardKey.New
        autoRepeat: false
        onActivated: grid.initGame()
    }

    Shortcut {
        sequence: "Ctrl+P"
        autoRepeat: false
        onActivated: !settingsWindow.visible ? settingsWindow.show() : settingsWindow.close()
    }

    Shortcut {
        sequence: "Ctrl+L"
        autoRepeat: false
        onActivated: leaderboardWindow.visible = true
    }

    Shortcut {
        sequence: "F11"
        autoRepeat: false
        onActivated: {
            if (root.visibility === 5) {
                root.visibility = ApplicationWindow.Windowed;
            } else {
                root.visibility = 5;
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+H"
        autoRepeat: false
        onActivated: grid.requestHint()
    }

    Loader {
        id: welcomeLoader
        anchors.fill: parent
        active: MainWindow.showWelcome
        sourceComponent: Component {
            WelcomePage {
            }
        }
    }

    Loader {
        id: aboutLoader
        anchors.fill: parent
        active: !SteamIntegration.initialized
        sourceComponent: Component {
            AboutPage {
            }
        }
    }

    FontLoader {
        id: numberFont
        source: switch (Retr0MineSettings.fontIndex) {
            case 0:
                "qrc:/fonts/FiraSans-SemiBold.ttf"
                break
            case 1:
                "qrc:/fonts/NotoSerif-Regular.ttf"
                break
            case 2:
                "qrc:/fonts/SpaceMono-Regular.ttf"
                break
            case 3:
                "qrc:/fonts/Orbitron-Regular.ttf"
                break
            case 4:
                "qrc:/fonts/PixelifySans-Regular.ttf"
                break
            default:
                "qrc:/fonts/FiraSans-Bold.ttf"
        }
    }

    AudioEffectsEngine {
        id: audioEngine
    }

    GameOverPopup {
        id: gameOverPopup
        root: root
        grid: grid
        numberFont: numberFont
    }

    SettingsPage {
        id: settingsWindow
        root: root
        grid: grid
        rootWidth: root.width
        rootHeight: root.height
        rootX: root.x
        rootY: root.y
    }

    ErrorWindow {
        id: errorWindow
    }

    LoadWindow {
        id: loadWindow
        errorWindow: errorWindow
    }

    SaveWindow {
        id: saveWindow
    }

    LeaderboardPage {
        id: leaderboardWindow
    }

    TopBar {
        id: topBar
        root: root
        grid: grid
        saveWindow: saveWindow
        loadWindow: loadWindow
        settingsWindow: settingsWindow
        leaderboardWindow: leaderboardWindow
        aboutLoader: aboutLoader
    }

    ScrollView {
        id: gameArea
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
        contentWidth: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX, gameArea.width)
        contentHeight: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY, gameArea.height)

        ScrollBar {
            id: defaultVerticalScrollBar
            parent: gameArea
            orientation: Qt.Vertical
            x: parent.width - width
            y: 0
            height: gameArea.height
            visible: policy === ScrollBar.AlwaysOn && !MainWindow.isFluent
            active: !MainWindow.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > gameArea.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        ScrollBar {
            id: defaultHorizontalScrollBar
            parent: gameArea
            orientation: Qt.Horizontal
            x: 0
            y: parent.height - height
            width: gameArea.width
            visible: policy === ScrollBar.AlwaysOn && !MainWindow.isFluent
            active: !MainWindow.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > gameArea.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentVerticalScrollBar
            parent: gameArea
            orientation: Qt.Vertical
            x: parent.width - width
            y: 0
            height: gameArea.height
            visible: policy === ScrollBar.AlwaysOn && MainWindow.isFluent
            active: MainWindow.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > gameArea.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentHorizontalScrollBar
            parent: gameArea
            orientation: Qt.Horizontal
            x: 0
            y: parent.height - height
            width: gameArea.width
            visible: policy === ScrollBar.AlwaysOn && MainWindow.isFluent
            active: MainWindow.isFluent
            policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > gameArea.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        ScrollBar.vertical: MainWindow.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
        ScrollBar.horizontal: MainWindow.isFluent ? fluentHorizontalScrollBar : defaultHorizontalScrollBar

        Item {
            anchors.centerIn: parent
            width: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX, gameArea.width)
            height: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY, gameArea.height)

            GameGrid {
                id: grid
                audioEngine: audioEngine
                leaderboardWindow: leaderboardWindow
                gameOverPopup: gameOverPopup
                Component.onCompleted: SaveManager.setGrid(grid)
                delegate: Cell {
                    id: cellItem
                    width: GameState.cellSize
                    height: GameState.cellSize
                    root: root
                    grid: grid
                    numberFont: numberFont.name
                    row: Math.floor(index / GameState.gridSizeX)
                    col: index % GameState.gridSizeX
                    opacity: 1
                }
            }
        }
    }

    Timer {
        id: initialLoadTimer
        interval: 1
        repeat: false
        onTriggered: root.checkInitialGameState()
    }

    function startInitialLoadTimer() {
        initialLoadTimer.start()
    }

    function checkInitialGameState() {
        if (!GameState.gridFullyInitialized) return

        let internalSaveData = MainWindow.loadGameState("internalGameState.json")
        if (internalSaveData) {
            if (SaveManager.loadGame(internalSaveData)) {
                MainWindow.deleteSaveFile("internalGameState.json")
                GameState.isManuallyLoaded = false
            } else {
                console.error("Failed to load internal game state")
                grid.initGame()
            }
        } else {
            grid.initGame()
        }

        if (Retr0MineSettings.startFullScreen || MainWindow.gamescope) {
            root.visibility = 5
        }
    }

    function getInitialWidth() {
        return visibility === Window.Windowed ?
            Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX + 24,
                    Screen.desktopAvailableWidth * 0.9) :
            width
    }

    function getInitialHeight() {
        return visibility === Window.Windowed ?
            Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY + 74,
                    Screen.desktopAvailableHeight * 0.9) :
            height
    }
}

