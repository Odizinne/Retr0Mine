pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQuick.Window
import QtCore
import "."

MainWindow {
    id: root
    visible: true
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()
    title: "Retr0Mine"

    BusyIndicator {
        // stupid, but allow continuous engine update without too much hassle (needed for steam overlay)
        opacity: 0
    }

    Settings {
        id: settings
        property int themeIndex: 0
        property int languageIndex: 0
        property int difficulty: 0
        property bool invertLRClick: false
        property bool autoreveal: false
        property bool enableQuestionMarks: true
        property bool enableSafeQuestionMarks: true
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
        property int flagSkinIndex: 0
        property bool advGenAlgo: true
        property int colorSchemeIndex: 0
        property int gridResetAnimationIndex: 0
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
        sequence: "Ctrl+L"
        onActivated: leaderboardWindow.visible = true
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

    required property var mainWindow
    required property var steamIntegration
    required property var gameLogic
    required property var gameTimer
    property bool flag1Unlocked: mainWindow.unlockedFlag1
    property bool flag2Unlocked: mainWindow.unlockedFlag2
    property bool flag3Unlocked: mainWindow.unlockedFlag3
    property bool anim1Unlocked: mainWindow.unlockedAnim1
    property bool anim2Unlocked: mainWindow.unlockedAnim2
    property string flagPath: {
        if (typeof steamIntegration !== "undefined" && settings.flagSkinIndex === 1) return "qrc:/icons/flag1.png"
        if (typeof steamIntegration !== "undefined" && settings.flagSkinIndex === 2) return "qrc:/icons/flag2.png"
        if (typeof steamIntegration !== "undefined" && settings.flagSkinIndex === 3) return "qrc:/icons/flag3.png"
        else return "qrc:/icons/flag.png"
    }
    property bool isGamescope: mainWindow.gamescope
    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property bool darkMode: mainWindow.isDarkMode
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
    property bool noAnimReset: false
    property bool blockAnim: true

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
            let cell = grid.itemAtIndex(i) as Cell;
            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }
        let mineCell = gameLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            let cell = grid.itemAtIndex(mineCell) as Cell;
            cell.highlightHint()
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
                safeQuestionedCells: [],
                centiseconds: gameTimer.centiseconds,
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
            let cell = grid.itemAtIndex(i) as Cell
            if (cell.revealed) saveData.gameState.revealedCells.push(i)
            if (cell.flagged) saveData.gameState.flaggedCells.push(i)
            if (cell.questioned) saveData.gameState.questionedCells.push(i)
            if (cell.safeQuestioned) saveData.gameState.safeQuestionedCells.push(i)
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

            // Get the saved time first
            const savedCentiseconds = data.gameState.centiseconds || (data.gameState.elapsedTime * 100)

            // Rest of your loading logic
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

            // Use resumeFrom instead of directly setting centiseconds
            gameTimer.resumeFrom(savedCentiseconds)

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

            revealedCount = data.gameState.revealedCells.length
            flaggedCount = data.gameState.flaggedCells.length

            if (gameStarted && !gameOver) {
                gameTimer.start()
            }

            topBar.elapsedTimeLabelText = formatTime(Math.floor(gameTimer.centiseconds / 100))
            isManuallyLoaded = true
            return true
        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

    function formatTime(seconds, includeCentis = false) {
        const totalMinutes = Math.floor(seconds / 60)
        const remainingSeconds = seconds % 60
        const baseTime = `${totalMinutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`

        if (includeCentis) {
            const cs = gameTimer.centiseconds % 100
            return `${baseTime}.${cs.toString().padStart(2, '0')}`
        }

        return baseTime
    }
    WelcomePage {
        id: welcomePopup
        root: root
        settings: settings
    }

    GameOverPopup {
        id: gameOverPopup
        root: root
        settings: settings
    }

    SettingsPage {
        id: settingsWindow
        root: root
        settings: settings
    }

    AboutPage {
        id: aboutPage
    }

    ErrorWindow {
        id: errorWindow
    }

    LoadWindow {
        id: loadWindow
        root: root
    }

    SaveWindow {
        id: saveWindow
        root: root
    }

    LeaderboardPage {
        id: leaderboardWindow
        root: root
    }

    SoundEffect {
        id: clickEffect0
        source: {
            switch (settings.soundPackIndex) {
                case 0: return "qrc:/sounds/pop/pop_click.wav"
                case 1: return "qrc:/sounds/w11/w11_click.wav"
                case 2: return "qrc:/sounds/kde-ocean/kde-ocean_click.wav"
                case 3: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
                default: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
            }
        }
    }

    SoundEffect {
        id: clickEffect1
        source: {
            switch (settings.soundPackIndex) {
                case 0: return "qrc:/sounds/pop/pop_click.wav"
                case 1: return "qrc:/sounds/w11/w11_click.wav"
                case 2: return "qrc:/sounds/kde-ocean/kde-ocean_click.wav"
                case 3: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
                default: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
            }
        }
    }

    SoundEffect {
        id: clickEffect2
        source: {
            switch (settings.soundPackIndex) {
                case 0: return "qrc:/sounds/pop/pop_click.wav"
                case 1: return "qrc:/sounds/w11/w11_click.wav"
                case 2: return "qrc:/sounds/kde-ocean/kde-ocean_click.wav"
                case 3: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
                default: return "qrc:/sounds/floraphonic/floraphonic_click.wav"
            }
        }
    }

    SoundEffect {
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
    }

    SoundEffect {
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
    }

    function compareTime(time1, time2) {
        if (!time1 || !time2) return true;
        const [t1, cs1] = time1.split('.');
        const [t2, cs2] = time2.split('.');
        const [m1, s1] = t1.split(':').map(Number);
        const [m2, s2] = t2.split(':').map(Number);
        // Convert everything to centiseconds for comparison
        const totalCs1 = (m1 * 60 + s1) * 100 + parseInt(cs1 || 0);
        const totalCs2 = (m2 * 60 + s2) * 100 + parseInt(cs2 || 0);
        return totalCs1 < totalCs2;
    }

    function playClick() {
        if (!settings.soundEffects || gameOver) return;

        if (!clickEffect0.playing) {
            clickEffect0.play();
        } else if (!clickEffect1.playing) {
            clickEffect1.play();
        } else if (!clickEffect2.playing) {
            clickEffect2.play();
        }
    }

    function playLoose() {
        if (settings.soundEffects) looseEffect.play()
    }

    function playWin() {
        if (settings.soundEffects) winEffect.play()
    }

    function revealConnectedCells(index) {
        if (!settings.autoreveal || !gameStarted || gameOver) return;
        let cell = grid.itemAtIndex(index) as Cell;
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

        if (settings.advGenAlgo) {
            console.log("Using new algo")
            const result = gameLogic.placeLogicalMines(col, row);
            if (result === -1) {
                console.error("Failed to place mines!");
                return false;
            }
        } else {
            console.log("Using old algo")
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
        }

        mines = gameLogic.getMines();
        numbers = gameLogic.getNumbers();
        return true;
    }

    function initGame() {
        blockAnim = false
        mines = []
        numbers = []
        gameOver = false
        revealedCount = 0
        flaggedCount = 0
        firstClickIndex = -1
        gameStarted = false
        currentHintCount = 0
        gameTimer.reset()
        topBar.elapsedTimeLabelText = "00:00"
        isManuallyLoaded = false

        root.noAnimReset = true
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            }
        }
        root.noAnimReset = false

        if (settings.animations) {
            for (let i = 0; i < gridSizeX * gridSizeY; i++) {
                let cell = grid.itemAtIndex(i) as Cell
                if (cell) {
                    cell.startFadeIn()
                }
            }
        }
    }

    function reveal(index) {
        let initialCell = grid.itemAtIndex(index) as Cell
        if (gameOver || initialCell.revealed || initialCell.flagged) return

        if (!gameStarted) {
            firstClickIndex = index
            if (!placeMines(index)) {
                reveal(index)
                return
            }
            gameStarted = true
            gameTimer.start()
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
            revealedCount++

            if (mines.includes(currentIndex)) {
                cell.isBombClicked = true
                gameOver = true
                gameTimer.stop()
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
                        let adjacentIndex = newRow * gridSizeX + newCol
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
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
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

            const formattedTime = formatTime(Math.floor(gameTimer.centiseconds / 100), true)
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
                const winsField = difficulty + 'Wins'; // New field for tracking wins
                const formattedTime = formatTime(Math.floor(gameTimer.centiseconds / 100), true)

                if (!leaderboard[winsField]) {
                    leaderboard[winsField] = 0;
                }

                leaderboard[winsField]++;
                leaderboardWindow[winsField] = leaderboard[winsField];

                console.log(formattedTime, leaderboard[timeField])

                if (!leaderboard[timeField] || compareTime(formattedTime, leaderboard[timeField])) {
                    console.log("pass")
                    leaderboard[timeField] = formattedTime;
                    leaderboardWindow[timeField] = formattedTime;
                    gameOverPopup.newRecordVisible = true
                } else {
                    gameOverPopup.newRecordVisible = false
                }
            }

            mainWindow.saveLeaderboard(JSON.stringify(leaderboard))

            if (!isManuallyLoaded) {
                if (typeof steamIntegration !== "undefined") {
                    const difficulty = getDifficultyLevel();

                    if (currentHintCount === 0 && settings.fixedSeed == -1) {
                        if (difficulty === 'easy') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                flagToast.notificationText = qsTr("New flag unlocked!")
                                flagToast.visible = true;
                                root.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                flagToast.notificationText = qsTr("New flag unlocked!")
                                flagToast.visible = true;
                                root.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                flagToast.notificationText = qsTr("New flag unlocked!")
                                flagToast.visible = true;
                                root.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(gameTimer.centiseconds / 100) < 15 && !steamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            steamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            flagToast.notificationText = qsTr("New grid animation unlocked!")
                            flagToast.visible = true
                            root.anim2Unlocked = true
                        }
                        if (currentHintCount >= 20 && !steamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            steamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            flagToast.notificationText = qsTr("New grid animation unlocked!")
                            flagToast.visible = true
                            root.anim1Unlocked = true
                        }
                    }

                    steamIntegration.incrementTotalWin();
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
        let cell = grid.itemAtIndex(index) as Cell
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                cell.flagged = true
                cell.questioned = false
                cell.safeQuestioned = false
                flaggedCount++
            } else if (cell.flagged) {
                if (settings.enableQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = true
                    cell.safeQuestioned = false
                    flaggedCount--
                } else if (settings.enableSafeQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = false
                    cell.safeQuestioned = true
                    flaggedCount--
                } else {
                    cell.flagged = false
                    cell.questioned = false
                    cell.safeQuestioned = false
                    flaggedCount--
                }
            } else if (cell.questioned) {
                if (settings.enableSafeQuestionMarks) {
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

        if (settings.startFullScreen || root.isGamescope) {
            root.visibility = 5
        }
    }

    FlagToast {
        id: flagToast
    }

    TopBar {
        id: topBar
        root: root
        settings: settings
        saveWindow: saveWindow
        loadWindow: loadWindow
        settingsWindow: settingsWindow
        leaderboardWindow: leaderboardWindow
        aboutPage: aboutPage
    }

    GameArea {
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
        contentWidth: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeX, gameArea.width)
        contentHeight: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeY, gameArea.height)

        Item {
            anchors.centerIn: parent
            width: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeX, gameArea.width)
            height: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeY, gameArea.height)

            GridView {
                id: grid
                anchors.centerIn: parent
                cellWidth: root.cellSize + root.cellSpacing
                cellHeight: root.cellSize + root.cellSpacing
                width: (root.cellSize + root.cellSpacing) * root.gridSizeX
                height: (root.cellSize + root.cellSpacing) * root.gridSizeY
                model: root.gridSizeX * root.gridSizeY
                interactive: false
                property bool initialAnimationPlayed: false
                property int cellsCreated: 0

                delegate: Cell {
                    id: cellItem
                    width: root.cellSize
                    height: root.cellSize
                    root: root
                    settings: settings
                    grid: grid
                    row: Math.floor(index / root.gridSizeX)
                    col: index % root.gridSizeX
                    opacity: 1
                }
            }
        }
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
                leaderboardWindow.easyWins = leaderboard.easyWins || 0
                leaderboardWindow.mediumWins = leaderboard.mediumWins || 0
                leaderboardWindow.hardWins = leaderboard.hardWins || 0
                leaderboardWindow.retr0Wins = leaderboard.retr0Wins || 0
            } catch (e) {
                console.error("Failed to parse leaderboard data:", e)
            }
        }
        welcomePopup.visible = mainWindow.showWelcome

        gameTimer.centisecondsChanged.connect(function() {
        topBar.elapsedTimeLabelText = root.formatTime(Math.floor(gameTimer.centiseconds / 100))
        })
    }
}

