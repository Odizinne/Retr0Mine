pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: root
    visibility: ApplicationWindow.Hidden
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()

    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property bool shouldUpdateSize: true

    Connections {
        target: GameState
        function onGridSizeChanged() {
            if (!root.isMaximized && !root.isFullScreen && root.shouldUpdateSize) {
                root.minimumWidth = root.getInitialWidth()
                root.width = root.getInitialWidth()

                root.minimumHeight = root.getInitialHeight()
                root.height = root.getInitialHeight()

                // 2px margin of error
                if (root.width + 2 >= Screen.desktopAvailableWidth * 0.9 ||
                    root.height + 2 >= Screen.desktopAvailableHeight * 0.9) {
                    root.visibility = Window.Maximized
                }
            }
        }
    }

    onClosing: {
        if (Retr0MineSettings.loadLastGame && GameState.gameStarted && !GameState.gameOver) {
            saveGame("internalGameState.json")
        }
    }

    onVisibilityChanged: function(visibility) {
        const wasMaximized = isMaximized
        const wasFullScreen = isFullScreen
        isMaximized = visibility === Window.Maximized
        isFullScreen = visibility === Window.FullScreen
        shouldUpdateSize = !isMaximized && !isFullScreen
        if (wasMaximized || wasFullScreen && visibility === Window.Windowed) {
            shouldUpdateSize = true
            minimumWidth = getInitialWidth()
            minimumHeight = getInitialHeight()
            width = minimumWidth
            height = minimumHeight
            if (height >= Screen.desktopAvailableHeight * 0.9 || width >= Screen.desktopAvailableWidth * 0.9) {
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
            Universal.accent = sysPalette.accent
        }
    }

    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
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
        onActivated: root.initGame()
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
        onActivated: root.requestHint()
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
        numberFont: numberFont
    }

    SettingsPage {
        id: settingsWindow
        root: root
        grid: grid
    }

    ErrorWindow {
        id: errorWindow
    }

    LoadWindow {
        id: loadWindow
        root: root
        errorWindow: errorWindow
    }

    SaveWindow {
        id: saveWindow
        root: root
    }

    LeaderboardPage {
        id: leaderboardWindow
    }

    TopBar {
        id: topBar
        root: root
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

            GridView {
                id: grid
                anchors.centerIn: parent
                cellWidth: GameState.cellSize + GameState.cellSpacing
                cellHeight: GameState.cellSize + GameState.cellSpacing
                width: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX
                height: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY
                model: GameState.gridSizeX * GameState.gridSizeY
                interactive: false
                property bool initialAnimationPlayed: false
                property int cellsCreated: 0

                delegate: Cell {
                    id: cellItem
                    width: GameState.cellSize
                    height: GameState.cellSize
                    root: root
                    audioEngine: audioEngine
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
            if (loadGame(internalSaveData)) {
                MainWindow.deleteSaveFile("internalGameState.json")
                root.isManuallyLoaded = false
            } else {
                console.error("Failed to load internal game state")
                initGame()
            }
        } else {
            initGame()
        }
        root.visibility = ApplicationWindow.Windowed

        if (Retr0MineSettings.startFullScreen || MainWindow.gamescope) {
            root.visibility = 5
        }
    }

    function getInitialWidth() {
        return shouldUpdateSize ? Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX + 24, Screen.desktopAvailableWidth * 0.9) : root.width
    }

    function getInitialHeight() {
        return shouldUpdateSize ? Math.min((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY + 74, Screen.desktopAvailableHeight * 0.9) : root.height
    }

    function requestHint() {
        if (!GameState.gameStarted || GameState.gameOver) {
            return;
        }

        let revealed = [];
        let flagged = [];
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell;
            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }
        let mineCell = MinesweeperLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            let cell = grid.itemAtIndex(mineCell) as Cell;
            cell.highlightHint()
        }
        GameState.currentHintCount++;
    }

    function saveGame(filename) {
        let saveData = {
            version: "1.0",
            timestamp: new Date().toISOString(),
            gameState: {
                gridSizeX: GameState.gridSizeX,
                gridSizeY: GameState.gridSizeY,
                mineCount: GameState.mineCount,
                mines: GameState.mines,
                numbers: GameState.numbers,
                revealedCells: [],
                flaggedCells: [],
                questionedCells: [],
                safeQuestionedCells: [],
                centiseconds: GameTimer.centiseconds,
                gameOver: GameState.gameOver,
                gameStarted: GameState.gameStarted,
                firstClickIndex: GameState.firstClickIndex,
                currentHintCount: GameState.currentHintCount,
            }
        }

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
            if (cell.revealed) saveData.gameState.revealedCells.push(i)
            if (cell.flagged) saveData.gameState.flaggedCells.push(i)
            if (cell.questioned) saveData.gameState.questionedCells.push(i)
            if (cell.safeQuestioned) saveData.gameState.safeQuestionedCells.push(i)
        }

        MainWindow.saveGameState(JSON.stringify(saveData), filename)
    }

    Timer {
        id: loadingTimer
        interval: 100
        repeat: false
        onTriggered: root.finishLoading()
        property var savedData
        property int savedCentiseconds
    }

    function loadGame(saveData) {
        try {
            let data = JSON.parse(saveData)
            if (!data.version || !data.version.startsWith("1.")) {
                console.error("Incompatible save version")
                return false
            }
            GameTimer.stop()
            // Get the saved time first
            const savedCentiseconds = data.gameState.centiseconds
            // Rest of your loading logic
            GameState.gridSizeX = data.gameState.gridSizeX
            GameState.gridSizeY = data.gameState.gridSizeY
            GameState.mineCount = data.gameState.mineCount
            GameState.mines = data.gameState.mines
            GameState.numbers = data.gameState.numbers

            if (!MinesweeperLogic.initializeFromSave(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount, GameState.mines)) {
                console.error("Failed to initialize game logic from save")
                return false
            }

            // Store the data for use after the timer
            loadingTimer.savedData = data
            loadingTimer.savedCentiseconds = savedCentiseconds
            loadingTimer.start()
            return true

        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

    function finishLoading() {
        const data = loadingTimer.savedData
        const savedCentiseconds = loadingTimer.savedCentiseconds

        let foundDifficulty = GameState.difficultySettings.findIndex(setting =>
            setting.x === GameState.gridSizeX &&
            setting.y === GameState.gridSizeY &&
            setting.mines === GameState.mineCount
        )
        if (foundDifficulty === 0 || foundDifficulty === 1 ||
            foundDifficulty === 2 || foundDifficulty === 3) {
            Retr0MineSettings.difficulty = foundDifficulty
        } else {
            Retr0MineSettings.difficulty = 4
            Retr0MineSettings.customWidth = GameState.gridSizeX
            Retr0MineSettings.customHeight = GameState.gridSizeY
            Retr0MineSettings.customMines = GameState.mineCount
        }
        GameTimer.resumeFrom(savedCentiseconds)
        GameState.gameOver = data.gameState.gameOver
        GameState.gameStarted = data.gameState.gameStarted
        GameState.firstClickIndex = data.gameState.firstClickIndex
        GameState.currentHintCount = data.gameState.currentHintCount || 0

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            }
        }

        data.gameState.revealedCells.forEach(index => {
            let cell = grid.itemAtIndex(index)
            if (cell) cell.revealed = true
        })

        data.gameState.flaggedCells.forEach(index => {
            let cell = grid.itemAtIndex(index)
            if (cell) cell.flagged = true
        })

        if (data.gameState.questionedCells) {
            data.gameState.questionedCells.forEach(index => {
                let cell = grid.itemAtIndex(index)
                if (cell) cell.questioned = true
            })
        }

        if (data.gameState.safeQuestionedCells) {
            data.gameState.safeQuestionedCells.forEach(index => {
                let cell = grid.itemAtIndex(index)
                if (cell) cell.safeQuestioned = true
            })
        }

        GameState.revealedCount = data.gameState.revealedCells.length
        GameState.flaggedCount = data.gameState.flaggedCells.length

        if (GameState.gameStarted && !GameState.gameOver) {
            GameTimer.start()
        }

        GameState.isManuallyLoaded = true
    }

    function revealConnectedCells(index) {
        if (!Retr0MineSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return;
        let cell = grid.itemAtIndex(index) as Cell;
        if (!cell.revealed || GameState.numbers[index] <= 0) return;

        let row = Math.floor(index / GameState.gridSizeX);
        let col = index % GameState.gridSizeX;
        let flaggedCount = 0;
        let adjacentCells = [];
        let hasQuestionMark = false;

        outerLoop: for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;
                let newRow = row + r;
                let newCol = col + c;
                if (newRow < 0 || newRow >= GameState.gridSizeY || newCol < 0 || newCol >= GameState.gridSizeX) continue;
                let currentPos = newRow * GameState.gridSizeX + newCol;
                let adjacentCell = grid.itemAtIndex(currentPos) as Cell;

                if (adjacentCell.questioned || adjacentCell.safeQuestioned) {
                    hasQuestionMark = true;
                    break outerLoop;
                }
                if (adjacentCell.flagged) {
                    flaggedCount++;
                } else if (!adjacentCell.revealed) {
                    adjacentCells.push(currentPos);
                }
            }
        }

        if (!hasQuestionMark && flaggedCount === GameState.numbers[index] && adjacentCells.length > 0) {
            for (let adjacentPos of adjacentCells) {
                reveal(adjacentPos);
            }
        }
    }

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / GameState.gridSizeX);
        const col = firstClickIndex % GameState.gridSizeX;

        if (!MinesweeperLogic.initializeGame(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount)) {
            console.error("Failed to initialize game!");
            return false;
        }

        const result = MinesweeperLogic.placeLogicalMines(col, row);
        if (!result) {
            console.error("Failed to place mines!");
            return false;
        }

        GameState.mines = MinesweeperLogic.getMines();
        GameState.numbers = MinesweeperLogic.getNumbers();
        return true;
    }

    function initGame() {
        GameState.blockAnim = false
        GameState.mines = []
        GameState.numbers = []
        GameState.gameOver = false
        GameState.revealedCount = 0
        GameState.flaggedCount = 0
        GameState.firstClickIndex = -1
        GameState.gameStarted = false
        GameState.currentHintCount = 0
        GameTimer.reset()
        GameState.isManuallyLoaded = false

        GameState.noAnimReset = true
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            }
        }
        GameState.noAnimReset = false

        if (Retr0MineSettings.animations) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                let cell = grid.itemAtIndex(i) as Cell
                if (cell) {
                    cell.startFadeIn()
                }
            }
        }
    }

    function reveal(index) {
        let initialCell = grid.itemAtIndex(index) as Cell
        if (GameState.gameOver || initialCell.revealed || initialCell.flagged) return

        if (!GameState.gameStarted) {
            GameState.firstClickIndex = index
            if (!placeMines(index)) {
                reveal(index)
                return
            }
            GameState.gameStarted = true
            GameTimer.start()
        }

        let cellsToReveal = [index]
        let visited = new Set()

        while (cellsToReveal.length > 0) {
            let currentIndex = cellsToReveal.pop()
            if (visited.has(currentIndex)) continue

            visited.add(currentIndex)
            let cell = grid.itemAtIndex(currentIndex) as Cell

            if (cell.revealed || cell.flagged) continue

            cell.revealed = true
            GameState.revealedCount++

            if (GameState.mines.includes(currentIndex)) {
                cell.isBombClicked = true
                GameState.gameOver = true
                GameTimer.stop()
                revealAllMines()
                audioEngine.playLoose()
                gameOverPopup.gameOverLabelText = "Game over"
                gameOverPopup.gameOverLabelColor = "#d12844"
                gameOverPopup.newRecordVisible = false
                gameOverPopup.visible = true
                return
            }

            if (GameState.numbers[currentIndex] === 0) {
                let row = Math.floor(currentIndex / GameState.gridSizeX)
                let col = currentIndex % GameState.gridSizeX
                for (let r = -1; r <= 1; r++) {
                    for (let c = -1; c <= 1; c++) {
                        if (r === 0 && c === 0) continue
                        let newRow = row + r
                        let newCol = col + c
                        if (newRow < 0 || newRow >= GameState.gridSizeY || newCol < 0 || newCol >= GameState.gridSizeX) continue
                        let adjacentIndex = newRow * GameState.gridSizeX + newCol
                        let adjacentCell = grid.itemAtIndex(adjacentIndex) as Cell
                        if (adjacentCell.questioned) {
                            adjacentCell.questioned = false
                        }
                        if (adjacentCell.safeQuestioned) {
                            adjacentCell.safeQuestioned = false
                        }
                        cellsToReveal.push(adjacentIndex)
                    }
                }
            }
        }

        checkWin()
    }

    function revealAllMines() {
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
            if (cell) {
                if (GameState.mines.includes(i)) {
                    if (!cell.flagged) {
                        cell.questioned = false
                        cell.revealed = true
                    } else {
                        cell.revealed = false
                    }
                } else {
                    if (cell.flagged) {
                        cell.flagged = false
                    }
                }
            }
        }
    }

    function getDifficultyLevel() {
        if (GameState.gridSizeX === 9 && GameState.gridSizeY === 9 && GameState.mineCount === 10) {
            return 'easy';
        } else if (GameState.gridSizeX === 16 && GameState.gridSizeY === 16 && GameState.mineCount === 40) {
            return 'medium';
        } else if (GameState.gridSizeX === 30 && GameState.gridSizeY === 16 && GameState.mineCount === 99) {
            return 'hard';
        } else if (GameState.gridSizeX === 50 && GameState.gridSizeY === 32 && GameState.mineCount === 320) {
            return 'retr0';
        }
        return null;
    }

    function checkWin() {
        if (GameState.revealedCount === GameState.gridSizeX * GameState.gridSizeY - GameState.mineCount && !GameState.gameOver) {
            GameState.gameOver = true
            GameTimer.stop()

            let leaderboardData = MainWindow.loadGameState("leaderboard.json")
            let leaderboard = {}

            if (leaderboardData) {
                try {
                    leaderboard = JSON.parse(leaderboardData)
                } catch (e) {
                    console.error("Failed to parse leaderboard data:", e)
                }
            }

            const difficulty = getDifficultyLevel();
            if (difficulty) {
                const timeField = difficulty + 'Time';
                const winsField = difficulty + 'Wins';
                const centisecondsField = difficulty + 'Centiseconds';
                const formattedTime = GameTimer.getDetailedTime()
                const centiseconds = GameTimer.centiseconds

                if (!leaderboard[winsField]) {
                    leaderboard[winsField] = 0;
                }

                leaderboard[winsField]++;
                leaderboardWindow[winsField] = leaderboard[winsField];

                if (!leaderboard[centisecondsField] || centiseconds < leaderboard[centisecondsField]) {
                    leaderboard[timeField] = formattedTime;
                    leaderboard[centisecondsField] = centiseconds;
                    leaderboardWindow[timeField] = formattedTime;
                    gameOverPopup.newRecordVisible = true
                } else {
                    gameOverPopup.newRecordVisible = false
                }
            }

            MainWindow.saveLeaderboard(JSON.stringify(leaderboard))

            if (!GameState.isManuallyLoaded) {
                if (SteamIntegration.initialized) {
                    const difficulty = getDifficultyLevel();

                    if (GameState.currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(GameTimer.centiseconds / 100) < 15 && !SteamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            SteamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            GameState.anim2Unlocked = true
                        }
                        if (GameState.currentHintCount >= 20 && !SteamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            SteamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            GameState.anim1Unlocked = true
                        }
                    }

                    SteamIntegration.incrementTotalWin();
                }
            }

            gameOverPopup.gameOverLabelText = qsTr("Victory")
            gameOverPopup.gameOverLabelColor = "#28d13c"
            gameOverPopup.visible = true
            audioEngine.playWin()
        } else {
            audioEngine.playClick()
        }
    }

    function toggleFlag(index) {
        if (GameState.gameOver) return
        let cell = grid.itemAtIndex(index) as Cell
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                cell.flagged = true
                cell.questioned = false
                cell.safeQuestioned = false
                GameState.flaggedCount++
            } else if (cell.flagged) {
                if (Retr0MineSettings.enableQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = true
                    cell.safeQuestioned = false
                    GameState.flaggedCount--
                } else if (Retr0MineSettings.enableSafeQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = false
                    cell.safeQuestioned = true
                    GameState.flaggedCount--
                } else {
                    cell.flagged = false
                    cell.questioned = false
                    cell.safeQuestioned = false
                    GameState.flaggedCount--
                }
            } else if (cell.questioned) {
                if (Retr0MineSettings.enableSafeQuestionMarks) {
                    cell.questioned = false
                    cell.safeQuestioned = true
                } else {
                    cell.questioned = false
                }
            } else if (cell.safeQuestioned) {
                cell.safeQuestioned = false
            }
        }
    }

    function hasUnrevealedNeighbors(index) {
        // If the cell has no number (0), no need for satisfaction check
        if (GameState.numbers[index] === 0) {
            return false
        }

        let row = Math.floor(index / GameState.gridSizeX)
        let col = index % GameState.gridSizeX
        let flagCount = 0
        let unrevealedCount = 0

        // Count flagged and unrevealed neighbors
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue
                let newRow = row + r
                let newCol = col + c
                if (newRow < 0 || newRow >= GameState.gridSizeY || newCol < 0 || newCol >= GameState.gridSizeX) continue

                let adjacentCell = grid.itemAtIndex(newRow * GameState.gridSizeX + newCol) as Cell
                if (adjacentCell.flagged) {
                    flagCount++
                }
                if (!adjacentCell.revealed && !adjacentCell.flagged) {
                    unrevealedCount++
                }
            }
        }

        return unrevealedCount > 0 || flagCount !== GameState.numbers[index]
    }
}

