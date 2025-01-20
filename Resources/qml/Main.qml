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
    visible: true
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()
    title: "Retr0Mine"

    MouseArea {
        anchors.fill: parent
        enabled: root.selectedCell !== -1
        onPressed: {
            if (mouse.button === Qt.LeftButton || mouse.button === Qt.RightButton) {
                root.selectedCell = -1
            }
        }
        z: 999
        propagateComposedEvents: true
    }


    onVisibleChanged: {
        if (Universal !== undefined) {
            Universal.theme = root.isGamescope ? Universal.Dark : Universal.System
            Universal.accent = accentColor
        }
    }

    Shortcut {
       sequences: [StandardKey.MoveToNextChar, "D"]
       onActivated: root.moveSelection("right")
    }

    Shortcut {
       sequences: [StandardKey.MoveToPreviousChar, "A"]
       onActivated: root.moveSelection("left")
    }

    Shortcut {
       sequences: [StandardKey.MoveToNextLine, "S"]
       onActivated: root.moveSelection("down")
    }

    Shortcut {
       sequences: [StandardKey.MoveToPreviousLine, "W"]
       onActivated: root.moveSelection("up")
    }

    Shortcut {
        sequences: ["Return", "Q"]
        onActivated: {
            if (root.hasSelection) {
                if (grid.itemAtIndex(root.selectedCell).revealed) {
                    revealConnectedCells(root.selectedCell)
                } else {
                    root.reveal(root.selectedCell)
                    root.playClick()
                }
            }
        }
    }

    Shortcut {
       sequence: "Space"
       onActivated: {
           if (grid.itemAtIndex(root.selectedCell).revealed) {
               revealConnectedCells(root.selectedCell)
            }

            if (root.hasSelection) {
                root.toggleFlag(root.selectedCell)
            }
       }
    }

    function moveSelection(direction) {
        if (!hasSelection) {
            selectedCell = 0
            return
        }

        let row = Math.floor(selectedCell / gridSizeX)
        let col = selectedCell % gridSizeX

        switch (direction) {
            case "right":
                if (col < gridSizeX - 1) selectedCell++
                break
            case "left":
                if (col > 0) selectedCell--
                break
            case "down":
                if (row < gridSizeY - 1) selectedCell += gridSizeX
                break
            case "up":
                if (row > 0) selectedCell -= gridSizeX
                break
        }
        console.log("selectedCell:", selectedCell, "hasSelection:", hasSelection)

    }

    Settings {
        id: settings
        property int themeIndex: root.isGamescope ? 4 : 0
        property int colorScheme: 0
        property int languageIndex: 0
        property int difficulty: 0
        property bool invertLRClick: false
        property bool autoreveal: false
        property bool enableQuestionMarks: true
        property bool loadLastGame: false
        property bool soundEffects: true
        property real volume: 1.0
        property int soundPackIndex: 0
        property bool animations: true
        property bool cellFrame: true
        property bool contrastFlag: false
        property int cellSize: 1
    }

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: StandardKey.Save
        enabled: root.gameStarted
        onActivated: saveWindow.show()
    }

    Shortcut {
        sequence: StandardKey.Open
        onActivated: loadWindow.show()
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
                root.visibility = ApplicationWindow.AutomaticVisibility;
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
            console.log("autosave")
        }
    }

    property var difficultySettings: [
        { text: qsTr("Easy"), x: 9, y: 9, mines: 10 },
        { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
        { text: qsTr("Hard"), x: 30, y: 16, mines: 99 },
        { text: "Retr0", x: 50, y: 32, mines: 320 }
    ]

    property int selectedCell: -1  // Track currently selected cell
    property bool hasSelection: selectedCell !== -1
    property MinesweeperLogic gameLogic: MinesweeperLogic {}
    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property bool isFusionTheme: fusion
    property bool isFluentWinUI3Theme: windows11
    property bool isUniversalTheme: windows10
    property bool darkMode: isDarkMode
    property string operatingSystem: currentOS
    property bool isGamescope: gamescope
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
    property bool timerActive: false
    property int elapsedTime: 0
    property bool shouldUpdateSize: true
    property int cellSize: loadedCellSize
    property int cellSpacing: 2
    property int currentHintCount: 0

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

            // Add 2px margin of error
            if (width + 2 >= Screen.desktopAvailableWidth * 0.9) {
                visibility = Window.Maximized
            }
        }
    }

    onGridSizeYChanged: {
        if (!isMaximized && !isFullScreen && shouldUpdateSize) {
            minimumHeight = getInitialHeight()
            height = getInitialHeight()

            // Add 2px margin of error
            if (height + 2 >= Screen.desktopAvailableHeight * 0.9) {
                visibility = Window.Maximized
            }
        }
    }

    onVisibilityChanged: {
        const wasMaximized = isMaximized
        isMaximized = visibility === Window.Maximized
        isFullScreen = visibility === Window.FullScreen
        shouldUpdateSize = !isMaximized && !isFullScreen

        if (wasMaximized && visibility === Window.Windowed) {
            shouldUpdateSize = true
            minimumWidth = getInitialWidth()
            minimumHeight = getInitialHeight()
            width = minimumWidth
            height = minimumHeight

            if (height >= Screen.desktopAvailableHeight * 0.9 || width >= Screen.desktopAvailableWidth * 0.9) {
                // Center the window
                x = Screen.width / 2 - width / 2
                y = Screen.height / 2 - height / 2
            }
        }
    }

    function handleVisibilityChange(newVisibility) {
        console.log("pass")
        const wasMaximized = isMaximized
        isMaximized = newVisibility === Window.Maximized
        isFullScreen = newVisibility === Window.FullScreen
        shouldUpdateSize = !isMaximized && !isFullScreen

        if (wasMaximized && newVisibility === Window.Windowed) {
            shouldUpdateSize = true
            minimumWidth = getInitialWidth()
            minimumHeight = getInitialHeight()
            width = minimumWidth
            height = minimumHeight
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
                gameOver: gameOver,
                gameStarted: gameStarted,
                firstClickIndex: firstClickIndex
            }
        }

        // Collect revealed, flagged, and questioned cells
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

            // Verify version compatibility
            if (!data.version || !data.version.startsWith("1.")) {
                console.error("Incompatible save version")
                return false
            }

            // Reset game state
            gameTimer.stop()

            // Load grid configuration
            gridSizeX = data.gameState.gridSizeX
            gridSizeY = data.gameState.gridSizeY
            mineCount = data.gameState.mineCount

            // Load game progress
            mines = data.gameState.mines
            numbers = data.gameState.numbers

            if (!gameLogic.initializeFromSave(gridSizeX, gridSizeY, mineCount, mines)) {
                console.error("Failed to initialize game logic from save")
                return false
            }

            elapsedTime = data.gameState.elapsedTime
            gameOver = data.gameState.gameOver
            gameStarted = data.gameState.gameStarted
            firstClickIndex = data.gameState.firstClickIndex

            // Reset all cells first
            for (let i = 0; i < gridSizeX * gridSizeY; i++) {
                let cell = grid.itemAtIndex(i)
                if (cell) {
                    cell.revealed = false
                    cell.flagged = false
                    cell.questioned = false
                }
            }

            // Apply revealed, flagged, and questioned states
            data.gameState.revealedCells.forEach(index => {
                                                     let cell = grid.itemAtIndex(index)
                                                     if (cell) cell.revealed = true
                                                 })

            data.gameState.flaggedCells.forEach(index => {
                                                    let cell = grid.itemAtIndex(index)
                                                    if (cell) cell.flagged = true
                                                })

            // Handle questioned cells if they exist in the save data
            if (data.gameState.questionedCells) {
                data.gameState.questionedCells.forEach(index => {
                                                           let cell = grid.itemAtIndex(index)
                                                           if (cell) cell.questioned = true
                                                       })
            }

            // Update counters
            revealedCount = data.gameState.revealedCells.length
            flaggedCount = data.gameState.flaggedCells.length

            // Resume timer if game was in progress
            if (gameStarted && !gameOver) {
                gameTimer.start()
            }

            topBar.elapsedTimeLabelText = formatTime(elapsedTime)
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

    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.elapsedTime++
            topBar.elapsedTimeLabelText = root.formatTime(root.elapsedTime)
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


    SoundEffect {
        id: looseEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0:
                return "qrc:/sounds/pop/pop_bomb.wav"
            case 1:
                return "qrc:/sounds/w11/w11_bomb.wav"
            case 2:
                return "qrc:/sounds/kde-ocean/kde-ocean_bomb.wav"
            default:
                return "qrc:/sounds/pop/pop_bomb.wav"
            }
        }
        volume: settings.volume
    }

    SoundEffect {
        id: clickEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0:
                return "qrc:/sounds/pop/pop_click.wav"
            case 1:
                return "qrc:/sounds/w11/w11_click.wav"
            case 2:
                return "qrc:/sounds/kde-ocean/kde-ocean_click.wav"
            default:
                return "qrc:/sounds/pop/pop_click.wav"
            }
        }
        volume: settings.volume
    }

    SoundEffect {
        id: winEffect
        source: {
            switch (settings.soundPackIndex) {
            case 0:
                return "qrc:/sounds/pop/pop_win.wav"
            case 1:
                return "qrc:/sounds/w11/w11_win.wav"
            case 2:
                return "qrc:/sounds/kde-ocean/kde-ocean_win.wav"
            default:
                return "qrc:/sounds/pop/pop_win.wav"
            }
        }
        volume: settings.volume
    }

    function playLoose() {
        if (!settings.soundEffects) return
        looseEffect.play()
    }

    function playClick() {
        if (!settings.soundEffects) return
        if (gameOver) return
        clickEffect.play()
    }

    function playWin() {
        if (!settings.soundEffects) return
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

        // Check adjacent cells for flags and collect non-flagged cells
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;

                let newRow = row + r;
                let newCol = col + c;
                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue;

                let pos = newRow * gridSizeX + newCol;
                let adjacentCell = grid.itemAtIndex(pos);

                if (adjacentCell.flagged) {
                    flaggedCount++;
                } else if (!adjacentCell.revealed) {
                    // Remove question mark if present
                    if (adjacentCell.questioned) {
                        adjacentCell.questioned = false;
                    }
                    adjacentCells.push(pos);
                }
            }
        }

        // If the number of flags matches the cell's number, reveal adjacent non-flagged cells
        if (flaggedCount === numbers[index] && adjacentCells.length > 0) {
            for (let pos of adjacentCells) {
                reveal(pos);
            }
            root.playClick()
        }
    }

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / gridSizeX);
        const col = firstClickIndex % gridSizeX;
        console.log("QML: Placing mines, first click at:", col, row);

        // Initialize the game with current settings
        if (!gameLogic.initializeGame(gridSizeX, gridSizeY, mineCount)) {
            console.error("Failed to initialize game!");
            return false;
        }

        // Place mines using C++ backend
        const success = gameLogic.placeMines(col, row);
        if (!success) {
            console.error("Failed to place mines!");
            return false;
        }

        // Get mines and numbers from C++ backend
        mines = gameLogic.getMines();
        numbers = gameLogic.getNumbers();

        console.log("QML: Mines placed:", mines.length);
        console.log("QML: Numbers array size:", numbers.length);

        return true;
    }

    function initGame() {
        selectedCell = -1
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
        topBar.elapsedTimeLabelText = "00:00:00"

        // Reset all cells and trigger new animations
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
        if (gameOver) return
        if (grid.itemAtIndex(index).revealed || grid.itemAtIndex(index).flagged) return

        if (!gameStarted) {
            firstClickIndex = index
            if (!placeMines(index)) {
                reveal(index)
                return
            }
            gameStarted = true
            gameTimer.start()
        }

        let cell = grid.itemAtIndex(index)
        cell.revealed = true
        revealedCount++

        if (mines.includes(index)) {
            cell.isBombClicked = true
            gameOver = true
            gameTimer.stop()
            revealAllMines()
            playLoose()
            gameOverPopup.gameOverLabelText = "Game over :("
            gameOverPopup.gameOverLabelColor = "#d12844"
            gameOverPopup.visible = true
            return
        }

        if (numbers[index] === 0) {
            let row = Math.floor(index / gridSizeX)
            let col = index % gridSizeX

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    if (r === 0 && c === 0) continue

                    let newRow = row + r
                    let newCol = col + c
                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                    let pos = newRow * gridSizeX + newCol
                    reveal(pos)
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
                    // Keep flag if it was correctly placed on a mine
                    if (!cell.flagged) {
                        //cell.flagged = false
                        cell.revealed = true
                    } else {
                        cell.revealed = false
                    }
                } else {
                    // Remove flag if it was not on a mine
                    if (cell.flagged) {
                        cell.flagged = false
                        // You could potentially add a visual indicator of incorrect flag here
                    }
                }
            }
        }
    }

    function checkWin() {
        if (revealedCount === gridSizeX * gridSizeY - mineCount && !gameOver) {
            gameOver = true
            gameTimer.stop()

            // Check if Steam integration is available before using it
            if (typeof steamIntegration !== "undefined") {
                // No-hint achievements
                if (currentHintCount === 0) {
                    if (settings.difficulty === 0) {
                        steamIntegration.unlockAchievement("ACH_NO_HINT_EASY")
                    } else if (settings.difficulty === 1) {
                        steamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM")
                    } else if (settings.difficulty === 2) {
                        steamIntegration.unlockAchievement("ACH_NO_HINT_HARD")
                    }
                }
                // Speed Demon achievement
                if (settings.difficulty === 0 && elapsedTime < 15) {
                    steamIntegration.unlockAchievement("ACH_SPEED_DEMON")
                }
                // "Was it really needed?" achievement
                if (settings.difficulty === 0 && currentHintCount >= 20) {
                    steamIntegration.unlockAchievement("ACH_HINT_MASTER")
                }
            }

            gameOverPopup.gameOverLabelText = qsTr("Victory :)")
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
                // Empty -> Flag
                cell.flagged = true
                cell.questioned = false
                flaggedCount++
            } else if (cell.flagged) {
                if (settings.enableQuestionMarks) {
                    // Flag -> Question (only if question marks are enabled)
                    cell.flagged = false
                    cell.questioned = true
                    flaggedCount--
                } else {
                    // Flag -> Empty (if question marks are disabled)
                    cell.flagged = false
                    flaggedCount--
                }
            } else if (cell.questioned) {
                // Question -> Empty
                cell.questioned = false
            }
        }
    }

    Component.onCompleted: {
        // Set initial grid size based on difficulty
        const difficultySet = root.difficultySettings[settings.difficulty]
        if (difficultySet) {
            root.gridSizeX = difficultySet.x
            root.gridSizeY = difficultySet.y
            root.mineCount = difficultySet.mines
        }

        // Check for internal save state
        let internalSaveData = mainWindow.loadGameState("internalGameState.json")
        if (internalSaveData) {
            // Load the game state
            if (loadGame(internalSaveData)) {
                // Delete the internal save file after successful load
                mainWindow.deleteSaveFile("internalGameState.json")
            } else {
                console.error("Failed to load internal game state")
                initGame()
            }
        } else {
            initGame()
        }
    }

    TopBar {
        id: topBar
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
        clip: true

        ScrollBar.vertical.policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > scrollView.height ?
                                       ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

        ScrollBar.horizontal.policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > scrollView.width ?
                                         ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

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

                        Rectangle {
                            id: selectionRect
                            anchors.centerIn: parent
                            height: root.cellSize
                            width: root.cellSize
                            color: "transparent"
                            anchors.margins: -1
                            border.width: 3
                            border.color: index === root.selectedCell ? accentColor : "transparent"
                            visible: opacity > 0
                            opacity: index === root.selectedCell ? 1 : 0
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

                            // Remove Component.onCompleted
                            running: false  // Make sure animation doesn't start automatically

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

                        Component.onCompleted: {
                            // Only play initial animation once and only for the first creation
                            if (settings.animations && !grid.initialAnimationPlayed) {
                                opacity = 0
                                fadeTimer.start()
                                // Mark initial animation as played after the last cell is created
                                if (index === (root.gridSizeX * root.gridSizeY - 1)) {
                                    grid.initialAnimationPlayed = true
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
                        }

                        // The button for background and interactions
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
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            Image {
                                anchors.centerIn: parent
                                source: darkMode ? "qrc:/icons/questionmark_light.png" : "qrc:/icons/questionmark_dark.png"
                                visible: cellItem.questioned
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            Image {
                                anchors.centerIn: parent
                                source: {
                                    if(settings.contrastFlag)
                                        return darkMode ? "qrc:/icons/flag.png" : "qrc:/icons/flag_dark.png"
                                    return flagIcon
                                }
                                visible: cellItem.flagged
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            Image {
                                id: hintOverlay
                                anchors.centerIn: parent
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                                opacity: 0
                                visible: !cellItem.flagged && !cellItem.questioned && !cellItem.revealed
                                source: mines.includes(index) ?
                                            "qrc:/icons/warning.png" : "qrc:/icons/safe.png"
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                               if (cellItem.revealed) {
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
                            font.pixelSize: cellSize * 0.65
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: {
                                if (!cellItem.revealed) return "black"
                                if (mines.includes(index)) return "transparent"
                                if (numbers[index] === 1) return "#069ecc"
                                if (numbers[index] === 2) return "#28d13c"
                                if (numbers[index] === 3) return "#d12844"
                                if (numbers[index] === 4) return "#9328d1"
                                if (numbers[index] === 5) return "#ebc034"
                                if (numbers[index] === 6) return "#34ebb1"
                                if (numbers[index] === 7) return "#eb8634"
                                if (numbers[index] === 8 && darkMode) return "white"
                                if (numbers[index] === 8 && !darkMode) return "black"
                                return "black"
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

