import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Window
import com.odizinne.minesweeper 1.0
import QtCore
import "."

ApplicationWindow {
    id: root
    visibility: ApplicationWindow.Hidden
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()
    title: "Retr0Mine"

    Settings {
        id: settings
        property int themeIndex: 0
        property int languageIndex: 0
        property int difficulty: 0
        property bool invertLRClick: false
        property bool autoreveal: false
        property bool enableQuestionMarks: true
        property bool loadLastGame: false
        property bool soundEffects: true
        property real volume: 1.0
        property int soundPackIndex: 2
        property bool animations: true
        property bool cellFrame: true
        property bool contrastFlag: false
        property int cellSize: 1
        property int customWidth: 8
        property int customHeight: 8
        property int customMines: 10
        property bool dimSatisfied: false
        property bool startFullScreen: root.isGamescope ? true : false
        property int fixedSeed: -1
        property bool displaySeedAtGameOver: false
        property int colorBlindness: 0
        property bool welcomeMessageShown: false
    }

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: StandardKey.Save
        enabled: root.gameStarted
        onActivated: saveWindow.visible = true
    }

    Shortcut {
        sequence: StandardKey.Open
        onActivated: loadWindow.visible = true
    }

    Shortcut {
        sequence: StandardKey.New
        onActivated: root.initGame()
    }

    Shortcut {
        sequence: "Ctrl+P"
        onActivated: !settingsWindow.visible ? settingsWindow.show() : settingsWindow.close()
    }

    Shortcut {
        sequence: "F11"
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
        onActivated: root.requestHint()
    }

    onClosing: {
        if (settings.loadLastGame && gameStarted && !gameOver) {
            saveGame("internalGameState.json")
        }
    }

    property var difficultySettings: [
        { text: qsTr("Easy"), x: 9, y: 9, mines: 10 },
        { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
        { text: qsTr("Hard"), x: 30, y: 16, mines: 99 },
        { text: "Retr0", x: 50, y: 32, mines: 320 },
        { text: qsTr("Custom"), x: settings.customWidth, y: settings.customHeight, mines: settings.customMines },
    ]

    property MinesweeperLogic gameLogic: MinesweeperLogic {}
    property bool isGamescope: gamescope
    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property bool isFusionTheme: fusion
    property bool isFluentWinUI3Theme: windows11
    property bool isUniversalTheme: windows10
    property bool darkMode: isDarkMode
    property int diffidx: settings.difficulty
    property bool gameOver: false
    property int revealedCount: 0
    property int flaggedCount: 0
    property int firstClickIndex: -1
    property bool gameStarted: false
    property int gridSizeX: 8
    property int gridSizeY: 8
    property int mineCount: 10
    property var mines: []
    property var numbers: []
    property int elapsedTime: 0
    property bool shouldUpdateSize: true
    property int cellSize: {
        switch (settings.cellSize) {
            case 0: return 35;
            case 1: return isGamescope ? 43 : 45;
            case 2: return 55;
            default: return isGamescope ? 43 : 45;
        }
    }
    property int cellSpacing: 2
    property int currentHintCount: 0
    property bool gridFullyInitialized: false
    property bool isManuallyLoaded: false

    function getInitialWidth() {
        return shouldUpdateSize ? Math.min((root.cellSize + root.cellSpacing) * gridSizeX + 24, Screen.desktopAvailableWidth * 0.9) : width
    }

    function getInitialHeight() {
        return shouldUpdateSize ? Math.min((root.cellSize + root.cellSpacing) * gridSizeY + 74, Screen.desktopAvailableHeight * 0.9) : height
    }

    onGridSizeXChanged: {
        if (!isMaximized && !isFullScreen && shouldUpdateSize) {
            minimumWidth = getInitialWidth()
            width = getInitialWidth()

            // 2px margin of error
            if (width + 2 >= Screen.desktopAvailableWidth * 0.9) {
                visibility = Window.Maximized
            }
        }
    }

    onGridSizeYChanged: {
        if (!isMaximized && !isFullScreen && shouldUpdateSize) {
            minimumHeight = getInitialHeight()
            height = getInitialHeight()

            // 2px margin of error
            if (height + 2 >= Screen.desktopAvailableHeight * 0.9) {
                visibility = Window.Maximized
            }
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

    function requestHint() {
        if (!gameStarted || gameOver) {
            return;
        }

        let revealed = [];
        let flagged = [];
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i);
            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }
        let mineCell = gameLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            let cell = grid.itemAtIndex(mineCell);
            cell.highlightHint();
        }
        currentHintCount++;
    }

    function saveGame(filename) {
        let saveData = {
            version: "1.0",
            timestamp: new Date().toISOString(),
            gameState: {
                gridSizeX: gridSizeX,
                gridSizeY: gridSizeY,
                mineCount: mineCount,
                mines: mines,
                numbers: numbers,
                revealedCells: [],
                flaggedCells: [],
                questionedCells: [],
                elapsedTime: elapsedTime,
                centiseconds: centisTimer.centiseconds,
                gameOver: gameOver,
                gameStarted: gameStarted,
                firstClickIndex: firstClickIndex,
                currentHintCount: currentHintCount,
                firstClickX: gameOverPopup.clickX,
                firstClickY: gameOverPopup.clickY,
                gameSeed: gameOverPopup.seed
            }
        }

        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell.revealed) saveData.gameState.revealedCells.push(i)
            if (cell.flagged) saveData.gameState.flaggedCells.push(i)
            if (cell.questioned) saveData.gameState.questionedCells.push(i)
        }

        mainWindow.saveGameState(JSON.stringify(saveData), filename)
    }

    function loadGame(saveData) {
        try {
            let data = JSON.parse(saveData)

            if (!data.version || !data.version.startsWith("1.")) {
                console.error("Incompatible save version")
                return false
            }

            gameTimer.stop()
            centisTimer.stop()

            gridSizeX = data.gameState.gridSizeX
            gridSizeY = data.gameState.gridSizeY
            mineCount = data.gameState.mineCount

            gameOverPopup.clickX = data.gameState.firstClickX
            gameOverPopup.clickY = data.gameState.firstClickY
            gameOverPopup.seed = data.gameState.gameSeed

            diffidx = root.difficultySettings.findIndex(diff =>
                diff.x === gridSizeX &&
                diff.y === gridSizeY &&
                diff.mines === mineCount
            )

            if (diffidx === -1) {
                diffidx = 0
                console.warn("No matching difficulty found, defaulting to Easy")
            }

            mines = data.gameState.mines
            numbers = data.gameState.numbers

            if (!gameLogic.initializeFromSave(gridSizeX, gridSizeY, mineCount, mines)) {
                console.error("Failed to initialize game logic from save")
                return false
            }

            root.elapsedTime = data.gameState.elapsedTime
            centisTimer.centiseconds = data.gameState.centiseconds
            root.gameOver = data.gameState.gameOver
            root.gameStarted = data.gameState.gameStarted
            root.firstClickIndex = data.gameState.firstClickIndex
            root.currentHintCount = data.gameState.currentHintCount || 0

            for (let i = 0; i < gridSizeX * gridSizeY; i++) {
                let cell = grid.itemAtIndex(i)
                if (cell) {
                    cell.revealed = false
                    cell.flagged = false
                    cell.questioned = false
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

            revealedCount = data.gameState.revealedCells.length
            flaggedCount = data.gameState.flaggedCells.length

            if (gameStarted && !gameOver) {
                gameTimer.start()
                centisTimer.start()
            }

            topBar.elapsedTimeLabelText = formatTime(elapsedTime)
            isManuallyLoaded = true

            return true
        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

    function formatTime(seconds) {
        let hours = Math.floor(seconds / 3600)
        let minutes = Math.floor((seconds % 3600) / 60)
        let remainingSeconds = seconds % 60

        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`
    }

    function formatLeaderboardTime(seconds, cs) {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const remainingSeconds = seconds % 60

        let timeString = ""

        timeString += hours.toString().padStart(2, '0') + ":"
        timeString += minutes.toString().padStart(2, '0') + ":"
        timeString += remainingSeconds.toString().padStart(2, '0')
        timeString += "." + cs.toString().padStart(2, '0')

        return timeString
    }

    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.elapsedTime++
            topBar.elapsedTimeLabelText = root.formatTime(root.elapsedTime)
        }
    }

    Timer {
        id: centisTimer
        interval: 10
        repeat: true
        running: gameTimer.running
        property int centiseconds: 0

        onTriggered: {
            centiseconds = (centiseconds + 1) % 100
        }
    }

    GameOverPopup {
        id: gameOverPopup
    }

    SettingsPage {
        id: settingsWindow
    }

    AboutPage {
        id: aboutPage
    }

    ErrorWindow {
        id: errorWindow
    }

    LoadWindow {
        id: loadWindow
    }

    SaveWindow {
        id: saveWindow
    }

    LeaderboardPage {
        id: leaderboardWindow
    }

    MediaPlayer {
        id: looseEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0: return "qrc:/sounds/pop/pop_bomb.wav"
            case 1: return "qrc:/sounds/w11/w11_bomb.wav"
            case 2: return "qrc:/sounds/kde-ocean/kde-ocean_bomb.wav"
            case 3: return "qrc:/sounds/floraphonic/floraphonic_bomb.wav"
            default: return "qrc:/sounds/floraphonic/floraphonic_bomb.wav"
            }
        }
        audioOutput: AudioOutput {
            volume: settings.volume
        }
    }

    MediaPlayer {
        id: clickEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0: return "qrc:/sounds/pop/pop_click.wav"
            case 1: return "qrc:/sounds/w11/w11_click.wav"
            case 2: return "qrc:/sounds/kde-ocean/kde-ocean_click.wav"
            case 3: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
            default: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
            }
        }
        audioOutput: AudioOutput {
            volume: settings.volume
        }
    }

    MediaPlayer {
        id: winEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0: return "qrc:/sounds/pop/pop_win.wav"
            case 1: return "qrc:/sounds/w11/w11_win.wav"
            case 2: return "qrc:/sounds/kde-ocean/kde-ocean_win.wav"
            case 3: return "qrc:/sounds/floraphonic/floraphonic_win.wav"
            default: return "qrc:/sounds/floraphonic/floraphonic_win.wav"
            }
        }
        audioOutput: AudioOutput {
            volume: settings.volume
        }
    }

    function compareTime(time1, time2) {
        if (!time1 || !time2) return true;

        const [t1, cs1] = time1.split('.');
        const [t2, cs2] = time2.split('.');

        const [h1, m1, s1] = t1.split(':').map(Number);
        const [h2, m2, s2] = t2.split(':').map(Number);

        // Convert everything to centiseconds for comparison
        const totalCs1 = ((h1 * 3600 + m1 * 60 + s1) * 100) + parseInt(cs1 || 0);
        const totalCs2 = ((h2 * 3600 + m2 * 60 + s2) * 100) + parseInt(cs2 || 0);

        return totalCs1 < totalCs2;
    }

    function playLoose() {
        if (!settings.soundEffects) return
        looseEffect.stop()
        looseEffect.play()
    }

    function playClick() {
        if (!settings.soundEffects) return
        if (gameOver) return
        clickEffect.stop()
        clickEffect.play()
    }

    function playWin() {
        if (!settings.soundEffects) return
        winEffect.stop()
        winEffect.play()
    }

    function revealConnectedCells(index) {
        if (!settings.autoreveal || !gameStarted || gameOver) return;
        let cell = grid.itemAtIndex(index);
        if (!cell.revealed || numbers[index] <= 0) return;

        let row = Math.floor(index / gridSizeX);
        let col = index % gridSizeX;
        let flaggedCount = 0;
        let adjacentCells = [];
        let hasQuestionMark = false;

        outerLoop: for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;
                let newRow = row + r;
                let newCol = col + c;
                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue;
                let currentPos = newRow * gridSizeX + newCol;
                let adjacentCell = grid.itemAtIndex(currentPos);

                if (adjacentCell.questioned) {
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

        if (!hasQuestionMark && flaggedCount === numbers[index] && adjacentCells.length > 0) {
            for (let adjacentPos of adjacentCells) {
                reveal(adjacentPos);
            }
            root.playClick()
        }
    }

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / gridSizeX);
        const col = firstClickIndex % gridSizeX;

        if (!gameLogic.initializeGame(gridSizeX, gridSizeY, mineCount)) {
            console.error("Failed to initialize game!");
            return false;
        }

        const seed = settings.fixedSeed && !isNaN(settings.fixedSeed)
            ? gameLogic.placeMines(col, row, settings.fixedSeed)
            : gameLogic.placeMines(col, row, -1);

        if (seed === -1) {
            console.error("Failed to place mines!");
            return false;
        } else {
            gameOverPopup.seed = seed
            gameOverPopup.clickX = col
            gameOverPopup.clickY = row

        }

        mines = gameLogic.getMines();
        numbers = gameLogic.getNumbers();

        return true;
    }

    function initGame() {
        mines = []
        numbers = []
        gameOver = false
        revealedCount = 0
        flaggedCount = 0
        firstClickIndex = -1
        gameStarted = false
        elapsedTime = 0
        currentHintCount = 0
        gameTimer.stop()
        centisTimer.stop()
        topBar.elapsedTimeLabelText = "00:00:00"
        isManuallyLoaded = false

        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.startFadeIn()
            }
        }
    }

    function reveal(index) {
       if (gameOver || grid.itemAtIndex(index).revealed || grid.itemAtIndex(index).flagged) return

       if (!gameStarted) {
           firstClickIndex = index
           if (!placeMines(index)) {
               reveal(index)
               return
           }
           gameStarted = true
           gameTimer.start()
           centisTimer.start()
       }

       let cellsToReveal = [index]
       let visited = new Set()

       while (cellsToReveal.length > 0) {
           let currentIndex = cellsToReveal.pop()
           if (visited.has(currentIndex)) continue

           visited.add(currentIndex)
           let cell = grid.itemAtIndex(currentIndex)

           if (cell.revealed || cell.flagged) continue

           cell.revealed = true
           revealedCount++

           if (mines.includes(currentIndex)) {
               cell.isBombClicked = true
               gameOver = true
               gameTimer.stop()
               centisTimer.stop()
               revealAllMines()
               playLoose()
               gameOverPopup.gameOverLabelText = "Game over"
               gameOverPopup.gameOverLabelColor = "#d12844"
               gameOverPopup.newRecordVisible = false
               gameOverPopup.visible = true
               return
           }

           if (numbers[currentIndex] === 0) {
               let row = Math.floor(currentIndex / gridSizeX)
               let col = currentIndex % gridSizeX

               for (let r = -1; r <= 1; r++) {
                   for (let c = -1; c <= 1; c++) {
                       if (r === 0 && c === 0) continue
                       let newRow = row + r
                       let newCol = col + c
                       if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue
                       cellsToReveal.push(newRow * gridSizeX + newCol)
                   }
               }
           }
       }

       checkWin()
    }

    function revealAllMines() {
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                if (mines.includes(i)) {
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
        if (gridSizeX === 9 && gridSizeY === 9 && mineCount === 10) {
            return 'easy';
        } else if (gridSizeX === 16 && gridSizeY === 16 && mineCount === 40) {
            return 'medium';
        } else if (gridSizeX === 30 && gridSizeY === 16 && mineCount === 99) {
            return 'hard';
        } else if (gridSizeX === 50 && gridSizeY === 32 && mineCount === 320) {
            return 'retr0';
        }
        return null;
    }

    function checkWin() {
        if (revealedCount === gridSizeX * gridSizeY - mineCount && !gameOver) {
            gameOver = true
            gameTimer.stop()
            centisTimer.stop()

            if (!isManuallyLoaded) {
                const formattedTime = formatTime(elapsedTime, centisTimer.centiseconds)

                let leaderboardData = mainWindow.loadGameState("leaderboard.json")
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
                    const formattedTime = formatLeaderboardTime(elapsedTime, centisTimer.centiseconds);

                    if (!leaderboard[timeField] || compareTime(formattedTime, leaderboard[timeField])) {
                        leaderboard[timeField] = formattedTime;
                        leaderboardWindow[timeField] = formattedTime;
                        gameOverPopup.newRecordVisible = true
                    } else {
                        gameOverPopup.newRecordVisible = false
                    }
                }

                mainWindow.saveLeaderboard(JSON.stringify(leaderboard))

                if (typeof steamIntegration !== "undefined") {
                    if (currentHintCount === 0 && settings.fixedSeed == -1) {
                        if (gridSizeX === 9 && gridSizeY === 9 && mineCount === 10) {
                            steamIntegration.unlockAchievement("ACH_NO_HINT_EASY")
                        } else if (gridSizeX === 16 && gridSizeY === 16 && mineCount === 40) {
                            steamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM")
                        } else if (gridSizeX === 30 && gridSizeY === 16 && mineCount === 99) {
                            steamIntegration.unlockAchievement("ACH_NO_HINT_HARD")
                        }
                    }

                    if (gridSizeX === 9 && gridSizeY === 9 && mineCount === 10 && elapsedTime < 15) {
                        steamIntegration.unlockAchievement("ACH_SPEED_DEMON")
                    }

                    if (gridSizeX === 9 && gridSizeY === 9 && mineCount === 10 && currentHintCount >= 20) {
                        steamIntegration.unlockAchievement("ACH_HINT_MASTER")
                    }
                }
            }

            gameOverPopup.gameOverLabelText = qsTr("Victory")
            gameOverPopup.gameOverLabelColor = "#28d13c"
            gameOverPopup.visible = true
            playWin()
        }
    }

    function toggleFlag(index) {
        if (gameOver) return
        let cell = grid.itemAtIndex(index)
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned) {
                cell.flagged = true
                cell.questioned = false
                flaggedCount++
            } else if (cell.flagged) {
                if (settings.enableQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = true
                    flaggedCount--
                } else {
                    cell.flagged = false
                    flaggedCount--
                }
            } else if (cell.questioned) {
                cell.questioned = false
            }
        }
    }

    function hasUnrevealedNeighbors(index) {
        // If the cell has no number (0), no need for satisfaction check
        if (numbers[index] === 0) {
            return false
        }

        let row = Math.floor(index / gridSizeX)
        let col = index % gridSizeX
        let flagCount = 0
        let unrevealedCount = 0

        // Count flagged and unrevealed neighbors
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue
                let newRow = row + r
                let newCol = col + c
                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                let adjacentCell = grid.itemAtIndex(newRow * gridSizeX + newCol)
                if (adjacentCell.flagged) {
                    flagCount++
                }
                if (!adjacentCell.revealed && !adjacentCell.flagged) {
                    unrevealedCount++
                }
            }
        }

        return unrevealedCount > 0 || flagCount !== numbers[index]
    }

    Component.onCompleted: {
        const difficultySet = root.difficultySettings[settings.difficulty]
        if (difficultySet) {
            root.gridSizeX = difficultySet.x
            root.gridSizeY = difficultySet.y
            root.mineCount = difficultySet.mines
        }

        let leaderboardData = mainWindow.loadLeaderboard()
        if (leaderboardData) {
            try {
                const leaderboard = JSON.parse(leaderboardData)
                leaderboardWindow.easyTime = leaderboard.easyTime || ""
                leaderboardWindow.mediumTime = leaderboard.mediumTime || ""
                leaderboardWindow.hardTime = leaderboard.hardTime || ""
                leaderboardWindow.retr0Time = leaderboard.retr0Time || ""
            } catch (e) {
                console.error("Failed to parse leaderboard data:", e)
            }
        }

        if (typeof Universal !== 'undefined') {
            Universal.theme = root.isGamescope && settings.themeIndex === 4 ? Universal.Dark : Universal.System
            Universal.accent = accentColor
        }
    }

    WelcomePage {
        id: welcomePopup
    }

    Timer {
        id: initialLoadTimer
        interval: 1
        repeat: false
        onTriggered: root.checkInitialGameState()
    }

    function checkInitialGameState() {
        if (!gridFullyInitialized) return

        let internalSaveData = mainWindow.loadGameState("internalGameState.json")
        if (internalSaveData) {
            if (loadGame(internalSaveData)) {
                mainWindow.deleteSaveFile("internalGameState.json")
                root.isManuallyLoaded = false
            } else {
                console.error("Failed to load internal game state")
                initGame()
            }
        } else {
            initGame()
        }

        welcomePopup.visible = !settings.welcomeMessageShown

        if (settings.startFullScreen) root.showFullScreen()
        else {
            if (width + 2 >= Screen.desktopAvailableWidth * 0.9) {
                root.showMaximized()
            }
            else {
                x = Screen.width / 2 - width / 2
                y = Screen.height / 2 - height / 2
                root.showNormal()
            }
        }
    }

    TopBar {
        id: topBar
    }

    property Component defaultVerticalScrollBar: ScrollBar {
        parent: scrollView
        x: parent.width - width + 12
        y: 0
        height: scrollView.height
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > scrollView.height ?
                ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }
    property Component defaultHorizontalScrollBar: ScrollBar {
        parent: scrollView
        x: 0
        y: parent.height - height + 12
        width: scrollView.width
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > scrollView.width ?
                ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        orientation: Qt.Horizontal
    }

    // Store the fluent scrollbar settings
    property Component fluentVerticalScrollBar: TempScrollBar {
        parent: scrollView
        x: parent.width - width + 12
        y: 0
        height: scrollView.height
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > scrollView.height ?
                ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    property Component fluentHorizontalScrollBar: TempScrollBar {
        parent: scrollView
        x: 0
        y: parent.height - height + 12
        width: scrollView.width
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > scrollView.width ?
                ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        orientation: Qt.Horizontal
    }

    ScrollView {
        id: scrollView
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

        ScrollBar.vertical: root.isFluentWinUI3Theme ? fluentVerticalScrollBar.createObject(scrollView)
                                              : defaultVerticalScrollBar.createObject(scrollView)

        ScrollBar.horizontal: root.isFluentWinUI3Theme ? fluentHorizontalScrollBar.createObject(scrollView)
                                                : defaultHorizontalScrollBar.createObject(scrollView)

        ColumnLayout {
            id: gameLayout
            width: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeX, scrollView.width)
            height: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeY, scrollView.height)
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.preferredWidth: (root.cellSize + root.cellSpacing) * root.gridSizeX
                Layout.preferredHeight: (root.cellSize + root.cellSpacing) * root.gridSizeY

                GridView {
                    id: grid
                    anchors.fill: parent
                    cellWidth: cellSize + cellSpacing
                    cellHeight: cellSize + cellSpacing
                    model: root.gridSizeX * root.gridSizeY
                    interactive: false
                    property bool initialAnimationPlayed: false
                    property int cellsCreated: 0

                    delegate: Item {
                        id: cellItem
                        width: cellSize
                        height: cellSize

                        property bool animatingReveal: false
                        property bool shouldBeFlat: false
                        property bool revealed: false
                        property bool flagged: false
                        property bool questioned: false
                        property bool isBombClicked: false

                        readonly property int row: Math.floor(index / root.gridSizeX)
                        readonly property int col: index % root.gridSizeX
                        readonly property int diagonalSum: row + col

                        opacity: 1

                        Component.onCompleted: {
                            grid.cellsCreated++

                            if (grid.cellsCreated === root.gridSizeX * root.gridSizeY) {
                                root.gridFullyInitialized = true
                                initialLoadTimer.start()
                            }

                            if (settings.animations && !grid.initialAnimationPlayed) {
                                opacity = 0
                                fadeTimer.start()
                                if (index === (root.gridSizeX * root.gridSizeY - 1)) {
                                    grid.initialAnimationPlayed = true
                                }
                            }
                        }

                        NumberAnimation {
                            id: hintRevealFadeIn
                            target: hintOverlay
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                        }

                        NumberAnimation {
                            id: hintRevealFadeOut
                            target: hintOverlay
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 200
                        }

                        SequentialAnimation {
                            id: hintAnimation
                            loops: 3
                            running: false
                            onStarted: hintRevealFadeIn.start()
                            onFinished: hintRevealFadeOut.start()

                            SequentialAnimation {
                                PropertyAnimation {
                                    target: cellButton
                                    property: "scale"
                                    to: 1.2
                                    duration: 300
                                    easing.type: Easing.InOutQuad
                                }
                                PropertyAnimation {
                                    target: cellButton
                                    property: "scale"
                                    to: 1.0
                                    duration: 300
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        function highlightHint() {
                            hintAnimation.start();
                        }

                        NumberAnimation {
                            id: fadeAnimation
                            target: cellItem
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                        }

                        NumberAnimation {
                            id: revealFadeAnimation
                            target: cellButton
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 200
                            easing.type: Easing.Linear
                            onStarted: animatingReveal = true
                            onFinished: {
                                animatingReveal = false
                                cellButton.flat = shouldBeFlat
                                cellButton.opacity = 1
                            }
                        }

                        Timer {
                            id: fadeTimer
                            interval: diagonalSum * 20
                            repeat: false
                            onTriggered: {
                                if (settings.animations) {
                                    fadeAnimation.start()
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: cellButton
                            border.width: 2
                            radius: {
                                if (isUniversalTheme) return 0
                                else if (isFluentWinUI3Theme) return 4
                                else if (isFusionTheme) return 3
                                else return 2
                            }
                            border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                            visible: {
                                if (cellItem.revealed && cellItem.isBombClicked && mines.includes(index))
                                    return true
                                if (cellItem.animatingReveal && settings.cellFrame)
                                    return true
                                return cellButton.flat && settings.cellFrame
                            }
                            color: {
                                if (cellItem.revealed && cellItem.isBombClicked && mines.includes(index))
                                    return accentColor
                                return "transparent"
                            }

                            Behavior on opacity {
                                enabled: settings.animations
                                NumberAnimation { duration: 200 }
                            }

                            opacity: {
                                if (!settings.dimSatisfied || !cellItem.revealed) return 1
                                if (cellItem.revealed && cellItem.isBombClicked && mines.includes(index)) return 1
                                return root.hasUnrevealedNeighbors(index) ? 1 : 0.5
                            }
                        }

                        Button {
                            id: cellButton
                            anchors.fill: parent
                            anchors.margins: cellSpacing / 2

                            Connections {
                                target: cellItem
                                function onRevealedChanged() {
                                    if (cellItem.revealed) {
                                        if (settings.animations) {
                                            shouldBeFlat = true
                                            revealFadeAnimation.start()
                                        } else {
                                            cellButton.flat = true
                                        }
                                    } else {
                                        shouldBeFlat = false
                                        cellButton.opacity = 1
                                        cellButton.flat = false
                                    }
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                source: darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
                                visible: cellItem.revealed && mines.includes(index)
                                sourceSize.width: cellItem.width / 2.1
                                sourceSize.height: cellItem.height / 2.1
                            }

                            Image {
                                anchors.centerIn: parent
                                source: darkMode ? "qrc:/icons/questionmark_light.png" : "qrc:/icons/questionmark_dark.png"
                                sourceSize.width: cellItem.width / 2.1
                                sourceSize.height: cellItem.height / 2.1
                                opacity: cellItem.questioned ? 1 : 0
                                scale: cellItem.questioned ? 1 : 1.3

                                Behavior on opacity {
                                    enabled: settings.animations
                                    OpacityAnimator {
                                        duration: 300
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Behavior on scale {
                                    enabled: settings.animations
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }

                            Image {
                                anchors.centerIn: parent
                                source: {
                                    if (settings.contrastFlag)
                                        return darkMode ? "qrc:/icons/flag.png" : "qrc:/icons/flag_dark.png"
                                    return flagIcon
                                }
                                sourceSize.width: cellItem.width / 2.1
                                sourceSize.height: cellItem.height / 2.1
                                opacity: cellItem.flagged ? 1 : 0
                                scale: cellItem.flagged ? 1 : 1.3

                                Behavior on opacity {
                                    enabled: settings.animations
                                    OpacityAnimator {
                                        duration: 300
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Behavior on scale {
                                    enabled: settings.animations
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }


                            Image {
                                id: hintOverlay
                                anchors.centerIn: parent
                                sourceSize.width: cellItem.width / 2.1
                                sourceSize.height: cellItem.height / 2.1
                                opacity: 0
                                visible: !cellItem.flagged && !cellItem.questioned && !cellItem.revealed
                                source: mines.includes(index) ?
                                            "qrc:/icons/warning.png" : "qrc:/icons/safe.png"
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (!gameStarted) {
                                        reveal(index);
                                        playClick();
                                    } else if (cellItem.revealed) {
                                        revealConnectedCells(index);
                                    } else {
                                        if (settings.invertLRClick) {
                                            if (mouse.button === Qt.RightButton && !cellItem.flagged && !cellItem.questioned) {
                                                reveal(index);
                                                playClick();
                                            } else if (mouse.button === Qt.LeftButton) {
                                                toggleFlag(index);
                                            }
                                        } else {
                                            if (mouse.button === Qt.LeftButton && !cellItem.flagged && !cellItem.questioned) {
                                                reveal(index);
                                                playClick();
                                            } else if (mouse.button === Qt.RightButton) {
                                                toggleFlag(index);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Number display
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!cellItem.revealed || cellItem.flagged) return ""
                                if (mines.includes(index)) return ""
                                return numbers[index] === undefined || numbers[index] === 0 ? "" : numbers[index];
                            }
                            font.pixelSize: cellSize * 0.60
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: {
                                if (!settings.dimSatisfied || !cellItem.revealed || numbers[index] === 0) return 1
                                return root.hasUnrevealedNeighbors(index) ? 1 : 0.25
                            }

                            Behavior on opacity {
                                enabled: settings.animations
                                NumberAnimation { duration: 200 }
                            }

                            color: {
                                if (!cellItem.revealed) return "black"
                                if (mines.includes(index)) return "transparent"

                                let palette = {}
                                switch (settings.colorBlindness) {
                                    case 1: // Deuteranopia
                                        palette = {
                                            1: "#377eb8",
                                            2: "#4daf4a",
                                            3: "#e41a1c",
                                            4: "#984ea3",
                                            5: "#ff7f00",
                                            6: "#a65628",
                                            7: "#f781bf",
                                            8: darkMode ? "white" : "black"
                                        }
                                        break
                                    case 2: // Protanopia
                                        palette = {
                                            1: "#66c2a5",
                                            2: "#fc8d62",
                                            3: "#8da0cb",
                                            4: "#e78ac3",
                                            5: "#a6d854",
                                            6: "#ffd92f",
                                            7: "#e5c494",
                                            8: darkMode ? "white" : "black"
                                        }
                                        break
                                    case 3: // Tritanopia
                                        palette = {
                                            1: "#e41a1c",
                                            2: "#377eb8",
                                            3: "#4daf4a",
                                            4: "#984ea3",
                                            5: "#ff7f00",
                                            6: "#f781bf",
                                            7: "#a65628",
                                            8: darkMode ? "white" : "black"
                                        }
                                        break
                                    default: // None
                                        palette = {
                                            1: "#069ecc",
                                            2: "#28d13c",
                                            3: "#d12844",
                                            4: "#9328d1",
                                            5: "#ebc034",
                                            6: "#34ebb1",
                                            7: "#eb8634",
                                            8: darkMode ? "white" : "black"
                                        }
                                }

                                return palette[numbers[index]] || "black"
                            }
                        }

                        function startFadeIn() {
                            if (!settings.animations) {
                                opacity = 1
                                return
                            }
                            grid.initialAnimationPlayed = false  // Reset the animation flag
                            opacity = 0
                            fadeTimer.restart()
                        }
                    }
                }
            }
        }
    }
}

