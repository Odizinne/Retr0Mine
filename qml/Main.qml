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

    required property var mainWindow
    required property var steamIntegration
    required property var gameLogic
    required property var gameTimer

    property var difficultySettings: [
        { text: qsTr("Easy"), x: 9, y: 9, mines: 10 },
        { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
        { text: qsTr("Hard"), x: 30, y: 16, mines: 99 },
        { text: "Retr0", x: 50, y: 32, mines: 320 },
        { text: qsTr("Custom"), x: Retr0MineSettings.customWidth, y: Retr0MineSettings.customHeight, mines: Retr0MineSettings.customMines },
    ]
    property bool isSteamEnabled: mainWindow.steamEnabled
    property bool flag1Unlocked: mainWindow.unlockedFlag1
    property bool flag2Unlocked: mainWindow.unlockedFlag2
    property bool flag3Unlocked: mainWindow.unlockedFlag3
    property bool anim1Unlocked: mainWindow.unlockedAnim1
    property bool anim2Unlocked: mainWindow.unlockedAnim2
    property string flagPath: {
        if (root.isSteamEnabled && Retr0MineSettings.flagSkinIndex === 1) return "qrc:/icons/flag1.png"
        if (root.isSteamEnabled && Retr0MineSettings.flagSkinIndex === 2) return "qrc:/icons/flag2.png"
        if (root.isSteamEnabled && Retr0MineSettings.flagSkinIndex === 3) return "qrc:/icons/flag3.png"
        else return "qrc:/icons/flag.png"
    }
    property bool isGamescope: mainWindow.gamescope
    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property int diffidx: 0
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
    property bool shouldUpdateSize: true
    property int cellSize: {
        switch (Retr0MineSettings.cellSize) {
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

    onClosing: {
        if (Retr0MineSettings.loadLastGame && gameStarted && !gameOver) {
            saveGame("internalGameState.json")
        }
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

    Component.onCompleted: {
        const difficultySet = root.difficultySettings[Retr0MineSettings.difficulty]
        root.gridSizeX = difficultySet.x
        root.gridSizeY = difficultySet.y
        root.mineCount = difficultySet.mines
        root.diffidx = Retr0MineSettings.difficulty

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

        if (typeof Universal !== undefined) {
            Universal.theme = root.isGamescope ? Universal.Dark : Universal.System
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
        enabled: root.gameStarted && !root.gameOver
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
        active: root.mainWindow.showWelcome
        sourceComponent: Component {
            WelcomePage {
                root: root
                colors: colors
            }
        }
    }

    Loader {
        id: aboutLoader
        anchors.fill: parent
        active: !root.isSteamEnabled
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

    Colors {
        id: colors
        root: root
    }

    //Retr0MineSettings {
    //    id: settings
    //    startFullScreen: root.isGamescope ? true : false
    //}

    AudioEffectsEngine {
        id: audioEngine
        root: root
    }

    GameOverPopup {
        id: gameOverPopup
        root: root
        numberFont: numberFont
    }

    SettingsPage {
        id: settingsWindow
        root: root
        colors: colors
        grid: grid
    }

    ErrorWindow {
        id: errorWindow
    }

    LoadWindow {
        id: loadWindow
        root: root
        colors: colors
        errorWindow: errorWindow
    }

    SaveWindow {
        id: saveWindow
        root: root
    }

    LeaderboardPage {
        id: leaderboardWindow
        root: root
        colors: colors
    }

    TopBar {
        id: topBar
        root: root
        saveWindow: saveWindow
        loadWindow: loadWindow
        settingsWindow: settingsWindow
        leaderboardWindow: leaderboardWindow
        aboutLoader: aboutLoader
        colors: colors
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
        contentWidth: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeX, gameArea.width)
        contentHeight: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeY, gameArea.height)

        ScrollBar {
            id: defaultVerticalScrollBar
            parent: gameArea
            orientation: Qt.Vertical
            x: parent.width - width
            y: 0
            height: gameArea.height
            visible: policy === ScrollBar.AlwaysOn && !root.mainWindow.isFluent
            active: !root.mainWindow.isFluent
            policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > gameArea.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        ScrollBar {
            id: defaultHorizontalScrollBar
            parent: gameArea
            orientation: Qt.Horizontal
            x: 0
            y: parent.height - height
            width: gameArea.width
            visible: policy === ScrollBar.AlwaysOn && !root.mainWindow.isFluent
            active: !root.mainWindow.isFluent
            policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > gameArea.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentVerticalScrollBar
            parent: gameArea
            orientation: Qt.Vertical
            x: parent.width - width
            y: 0
            height: gameArea.height
            visible: policy === ScrollBar.AlwaysOn && root.mainWindow.isFluent
            active: root.mainWindow.isFluent
            policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > gameArea.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        TempScrollBar {
            id: fluentHorizontalScrollBar
            parent: gameArea
            orientation: Qt.Horizontal
            x: 0
            y: parent.height - height
            width: gameArea.width
            visible: policy === ScrollBar.AlwaysOn && root.mainWindow.isFluent
            active: root.mainWindow.isFluent
            policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > gameArea.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }

        ScrollBar.vertical: root.mainWindow.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
        ScrollBar.horizontal: root.mainWindow.isFluent ? fluentHorizontalScrollBar : defaultHorizontalScrollBar

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
                    colors: colors
                    audioEngine: audioEngine
                    grid: grid
                    numberFont: numberFont.name
                    row: Math.floor(index / root.gridSizeX)
                    col: index % root.gridSizeX
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
        root.visibility = ApplicationWindow.Windowed

        if (Retr0MineSettings.startFullScreen || root.isGamescope) {
            root.visibility = 5
        }
    }

    function getInitialWidth() {
        return shouldUpdateSize ? Math.min((root.cellSize + root.cellSpacing) * gridSizeX + 24, Screen.desktopAvailableWidth * 0.9) : width
    }

    function getInitialHeight() {
        return shouldUpdateSize ? Math.min((root.cellSize + root.cellSpacing) * gridSizeY + 74, Screen.desktopAvailableHeight * 0.9) : height
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
            const savedCentiseconds = data.gameState.centiseconds

            // Rest of your loading logic
            gridSizeX = data.gameState.gridSizeX
            gridSizeY = data.gameState.gridSizeY
            mineCount = data.gameState.mineCount
            gameOverPopup.clickX = data.gameState.firstClickX
            gameOverPopup.clickY = data.gameState.firstClickY
            gameOverPopup.seed = data.gameState.gameSeed
            diffidx = root.difficultyRetr0MineSettings.findIndex(diff =>
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

            isManuallyLoaded = true
            return true
        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

    function revealConnectedCells(index) {
        if (!Retr0MineSettings.autoreveal || !gameStarted || gameOver) return;
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
        }
    }

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / gridSizeX);
        const col = firstClickIndex % gridSizeX;

        if (!gameLogic.initializeGame(gridSizeX, gridSizeY, mineCount)) {
            console.error("Failed to initialize game!");
            return false;
        }

        const result = gameLogic.placeLogicalMines(col, row);
        if (!result) {
            console.error("Failed to place mines!");
            return false;
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

        if (Retr0MineSettings.animations) {
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
                audioEngine.playLoose()
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
                const winsField = difficulty + 'Wins';
                const centisecondsField = difficulty + 'Centiseconds';
                const formattedTime = gameTimer.getDetailedTime()
                const centiseconds = gameTimer.centiseconds

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

            mainWindow.saveLeaderboard(JSON.stringify(leaderboard))

            if (!isManuallyLoaded) {
                if (root.isSteamEnabled) {
                    const difficulty = getDifficultyLevel();

                    if (currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                root.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                root.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!steamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                steamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                root.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(gameTimer.centiseconds / 100) < 15 && !steamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            steamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            root.anim2Unlocked = true
                        }
                        if (currentHintCount >= 20 && !steamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            steamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            root.anim1Unlocked = true
                        }
                    }

                    steamIntegration.incrementTotalWin();
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
        if (gameOver) return
        let cell = grid.itemAtIndex(index) as Cell
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                cell.flagged = true
                cell.questioned = false
                cell.safeQuestioned = false
                flaggedCount++
            } else if (cell.flagged) {
                if (Retr0MineSettings.enableQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = true
                    cell.safeQuestioned = false
                    flaggedCount--
                } else if (Retr0MineSettings.enableSafeQuestionMarks) {
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

                let adjacentCell = grid.itemAtIndex(newRow * gridSizeX + newCol) as Cell
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
}

