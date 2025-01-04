import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    visible: true
    width: Math.min((cellSize + cellSpacing) * gridSizeX + 22, Screen.width * 1)
    height: Math.min((cellSize + cellSpacing) * gridSizeY + 72, Screen.height * 1)
    minimumWidth: Math.min((cellSize + cellSpacing) * gridSizeX + 22, Screen.width * 1)
    minimumHeight: Math.min((cellSize + cellSpacing) * gridSizeY + 72, Screen.height * 1)
    title: "Retr0Mine"

    function printGrid() {
        console.log("Current Grid State (8x8, 10 mines):");
        console.log("M = Mine, F = Flagged, ? = Question Mark");
        console.log("R = Revealed (with number), . = Hidden");
        console.log(""); // Empty line for readability

        let output = "";
        for (let row = 0; row < 8; row++) {
            for (let col = 0; col < 8; col++) {
                let index = row * 8 + col;
                let cell = grid.itemAtIndex(index);
                if (cell.revealed) {
                    if (mines.includes(index)) {
                        output += "M ";
                    } else {
                        output += (numbers[index] === 0 ? "R " : numbers[index] + " ");
                    }
                } else if (cell.flagged) {
                    output += "F ";
                } else if (cell.questioned) {
                    output += "? ";
                } else {
                    output += ". ";
                }
            }
            output += "\n";
        }

        // Print mine positions (for debugging)
        console.log(output);
        console.log("\nMine positions:", mines.sort((a, b) => a - b).join(", "));

        // Print revealed count and flagged count
        console.log(`Revealed cells: ${revealedCount}`);
        console.log(`Flagged cells: ${flaggedCount}`);
        console.log(`Game started: ${gameStarted}`);
        console.log(`Game over: ${gameOver}`);
    }

    onVisibleChanged: {
        if (Universal !== undefined) {
            Universal.theme = Universal.System
            Universal.accent = accentColor
        }
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
        sequence: StandardKey.New
        onActivated: root.initGame()
    }

    Shortcut {
        sequence: StandardKey.Print
        onActivated: !settingsPage.visible ? settingsPage.show() : settingsPage.close()
    }

    property bool isLinux: linux
    property bool isWindows11: windows11
    property bool isWindows10: windows10
    property bool enableAnimations: animations
    property bool revealConnected: revealConnectedCell
    property bool invertLRClick: invertClick
    property bool enableQuestionMarks: true
    property bool playSound: soundEffects
    property int difficulty: gameDifficulty
    property bool darkMode: isDarkMode
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
    property int cellSize: 35
    property int cellSpacing: 2
    property string savePath: {
        if (Qt.platform.os === "windows")
            return mainWindow.getWindowsPath() + "/Retr0Mine"
        return mainWindow.getLinuxPath() + "/Retr0Mine"
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

            elapsedTimeLabel.text = formatTime(elapsedTime)
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
            elapsedTimeLabel.text = root.formatTime(root.elapsedTime)
        }
    }

    Popup {
        anchors.centerIn: parent
        id: gameOverWindow
        height: 100
        width: 250
        visible: false

        GridLayout {
            anchors.fill: parent
            columns: 2
            rowSpacing: 10
            Label {
                id: gameOverLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: "Game Over :("
                Layout.columnSpan: 2
                font.bold: true
                font.pixelSize: 16
            }

            Button {
                text: "Retry"
                Layout.fillWidth: true
                onClicked: {
                    gameOverWindow.close()
                    root.initGame()
                }
            }

            Button {
                text: "Close"
                Layout.fillWidth: true
                onClicked: {
                    gameOverWindow.close()
                }
            }
        }
    }

    ApplicationWindow {
        id: settingsPage
        title: "Settings"
        width: 300
        height: settingsLayout.implicitHeight + 30
        maximumWidth: 300
        maximumHeight: settingsLayout.implicitHeight + 30
        minimumWidth: 300
        minimumHeight: settingsLayout.implicitHeight + 30
        visible: false

        property int selectedGridSizeX: 8
        property int selectedGridSizeY: 8
        property int selectedMineCount: 10

        onVisibleChanged: {
            if (settingsPage.visible) {
                // Check if there is enough space on the right side
                if (root.x + root.width + settingsPage.width + 10 <= screen.width) {
                    // Position on the right side with a 10px margin
                    settingsPage.x = root.x + root.width + 20
                } else if (root.x - settingsPage.width - 10 >= 0) {
                    // If there is no space on the right, position on the left with a 10px margin
                    settingsPage.x = root.x - settingsPage.width - 20
                } else {
                    // If the root window is too close to the left edge, use a fallback
                    settingsPage.x = screen.width - settingsPage.width - 20
                }

                // Center vertically relative to the root window
                settingsPage.y = root.y + (root.height - settingsPage.height) / 2
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 10

            ButtonGroup {

                id: difficultyGroup
                onCheckedButtonChanged: {
                    if (checkedButton === easyButton) {
                        root.gridSizeX = 8
                        root.gridSizeY = 8
                        root.mineCount = 10
                        mainWindow.saveDifficulty(0)
                    } else if (checkedButton === mediumButton) {
                        root.gridSizeX = 16
                        root.gridSizeY = 16
                        root.mineCount = 40
                        mainWindow.saveDifficulty(1)
                    } else if (checkedButton === hardButton) {
                        root.gridSizeX = 32
                        root.gridSizeY = 16
                        root.mineCount = 99
                        mainWindow.saveDifficulty(2)
                    } else if (checkedButton === retroButton) {
                        root.gridSizeX = 50
                        root.gridSizeY = 30
                        root.mineCount = 300
                        mainWindow.saveDifficulty(3)
                    } else if (checkedButton === retroPlusButton) {
                        root.gridSizeX = 100
                        root.gridSizeY = 100
                        root.mineCount = 2000
                        mainWindow.saveDifficulty(4)
                    } else if (checkedButton === debugButton) {
                        root.gridSizeX = 10
                        root.gridSizeY = 10
                        root.mineCount = 50
                        mainWindow.saveDifficulty(5)
                    }
                    root.width = root.minimumWidth
                    root.height = root.minimumHeight
                    initGame()
                }
            }
        }

        ColumnLayout {
            id: settingsLayout
            anchors.fill: parent
            anchors.topMargin: 5
            anchors.bottomMargin: 15
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 4

            Label {
                text: "Difficulty"
                font.bold: true
                font.pixelSize: 18
            }

            MenuSeparator {
                Layout.fillWidth: true
            }

            RadioButton {
                id: easyButton
                text: "Easy (8×8, 10 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 0
            }

            RadioButton {
                id: mediumButton
                text: "Medium (16×16, 40 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 1
            }

            RadioButton {
                id: hardButton
                text: "Hard (32×16, 99 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 2
            }

            RadioButton {
                id: retroButton
                enabled: true
                text: "Retr0 (50×32, 320 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 3
            }

            RadioButton {
                id: retroPlusButton
                enabled: false
                visible: false
                text: "Retr0+ (100x100, 2000 mines (Lag))"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 4
            }

            RadioButton {
                id: debugButton
                enabled: false
                visible: false
                text: "debug (10x10, 91 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 5
            }

            Item {
                Layout.preferredHeight: 5
            }

            Label {
                text: "Sound"
                font.bold: true
                font.pixelSize: 18
            }

            MenuSeparator {
                Layout.fillWidth: true
            }

            Switch {
                text: "Play sound effects"
                checked: root.playSound
                onCheckedChanged: {
                    mainWindow.saveSoundSettings(checked);
                    root.playSound = checked
                }
            }

            Item {
                Layout.preferredHeight: 5
            }

            Label {
                text: "Visuals"
                font.bold: true
                font.pixelSize: 18
            }

            MenuSeparator {
                Layout.fillWidth: true
            }

            Switch {
                text: "Enable animations"
                checked: root.enableAnimations
                onCheckedChanged: {
                    mainWindow.saveVisualSettings(checked);
                    root.enableAnimations = checked
                    for (let i = 0; i < root.gridSizeX * root.gridSizeY; i++) {
                        let cell = grid.itemAtIndex(i)
                        if (cell) {
                            cell.opacity = 1
                        }
                    }
                }
            }

            Item {
                Layout.preferredHeight: 5
            }

            Label {
                text: "Controls"
                font.bold: true
                font.pixelSize: 18
            }

            MenuSeparator {
                Layout.fillWidth: true
            }

            Switch {
                text: "Invert left and right click"
                id: invert
                checked: root.invertLRClick
                onCheckedChanged: {
                    mainWindow.saveControlsSettings(invert.checked, autoreveal.checked);
                    root.invertLRClick = checked
                }
            }

            Switch {
                id: autoreveal
                text: "Quick reveal connected cells"
                checked: root.revealConnected
                onCheckedChanged: {
                    mainWindow.saveControlsSettings(invert.checked, autoreveal.checked);
                    root.revealConnected = checked
                }
            }

            Switch {
                id: questionMarks
                text: "Enable question marks"
                checked: root.enableQuestionMarks
                onCheckedChanged: {
                    mainWindow.saveControlsSettings(invert.checked, autoreveal.checked, questionMarks.checked);
                    root.enableQuestionMarks = checked

                    // Clear all question marks when disabled
                    if (!checked) {
                        for (let i = 0; i < root.gridSizeX * root.gridSizeY; i++) {
                            let cell = grid.itemAtIndex(i)
                            if (cell && cell.questioned) {
                                cell.questioned = false
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                text: "Close"
                Layout.preferredWidth: 70
                Layout.alignment: Qt.AlignRight
                onClicked: settingsPage.close()
            }
        }
    }

    SoundEffect {
        id: looseEffect
        source: "qrc:/sounds/bomb.wav"
        volume: 1
    }

    SoundEffect {
        id: clickEffect
        source: "qrc:/sounds/click.wav"
        volume: 1
    }

    SoundEffect {
        id: winEffect
        source: "qrc:/sounds/win.wav"
        volume: 1
    }

    function playLoose() {
        if (!root.playSound) return
        looseEffect.play()
    }

    function playClick() {
        if (!root.playSound) return
        if (gameOver) return
        clickEffect.play()
    }

    function playWin() {
        if (!root.playSound) return
        winEffect.play()
    }

    function revealConnectedCells(index) {
        if (!root.revealConnected || !gameStarted || gameOver) return;

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

    function testSolvability(testMines, firstClickIndex) {
        const revealed = new Set();
        const flagged = new Set();
        let changed = true;

        // Calculate numbers for the test configuration
        let testNumbers = calculateNumbersForValidation(testMines, gridSizeX, gridSizeY);

        // Start with first click and its surroundings
        revealCell(firstClickIndex);

        // Keep applying logical rules until no more progress can be made
        while (changed) {
            changed = false;
            for (let i = 0; i < gridSizeX * gridSizeY; i++) {
                if (!revealed.has(i) && !flagged.has(i) && !testMines.includes(i)) {
                    if (canDeduce(i, revealed, testMines, testNumbers)) {
                        revealCell(i);
                        changed = true;
                    }
                }
            }
        }

        // Count solvable cells
        let solvableCells = 0;
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            if (!testMines.includes(i) && revealed.has(i)) {
                solvableCells++;
            }
        }

        // Calculate solvability percentage
        let totalNonMineCells = gridSizeX * gridSizeY - testMines.length;
        let percentage = (solvableCells / totalNonMineCells) * 100;

        return {
            solvableCells: solvableCells,
            percentage: percentage
        };

        // Helper function for the test
        function revealCell(pos) {
            if (!revealed.has(pos) && !testMines.includes(pos)) {
                revealed.add(pos);
                changed = true;

                if (testNumbers[pos] === 0) {
                    let row = Math.floor(pos / gridSizeX);
                    let col = pos % gridSizeX;

                    for (let r = -1; r <= 1; r++) {
                        for (let c = -1; c <= 1; c++) {
                            if (r === 0 && c === 0) continue;

                            let newRow = row + r;
                            let newCol = col + c;
                            if (newRow >= 0 && newRow < gridSizeY &&
                                newCol >= 0 && newCol < gridSizeX) {
                                let newPos = newRow * gridSizeX + newCol;
                                if (!revealed.has(newPos)) {
                                    revealCell(newPos);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function canDeduce(pos, revealed, mines, numbers) {
        let row = Math.floor(pos / gridSizeX);
        let col = pos % gridSizeX;

        // Check all revealed neighbors
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;

                let checkRow = row + r;
                let checkCol = col + c;
                if (checkRow < 0 || checkRow >= gridSizeY ||
                    checkCol < 0 || checkCol >= gridSizeX) continue;

                let checkPos = checkRow * gridSizeX + checkCol;
                if (revealed.has(checkPos)) {
                    let surroundingMines = 0;
                    let hiddenCells = [];

                    // Count surrounding mines and hidden cells
                    for (let dr = -1; dr <= 1; dr++) {
                        for (let dc = -1; dc <= 1; dc++) {
                            if (dr === 0 && dc === 0) continue;

                            let adjacentRow = checkRow + dr;
                            let adjacentCol = checkCol + dc;
                            if (adjacentRow < 0 || adjacentRow >= gridSizeY ||
                                adjacentCol < 0 || adjacentCol >= gridSizeX) continue;

                            let adjacentPos = adjacentRow * gridSizeX + adjacentCol;

                            if (mines.includes(adjacentPos)) {
                                surroundingMines++;
                            } else if (!revealed.has(adjacentPos)) {
                                hiddenCells.push(adjacentPos);
                            }
                        }
                    }

                    // If all mines are found, remaining cells are safe
                    if (numbers[checkPos] === surroundingMines &&
                        hiddenCells.includes(pos)) {
                        return true;
                    }

                    // If remaining hidden cells equal remaining mines, all are mines
                    let remainingMines = numbers[checkPos] - surroundingMines;
                    if (remainingMines === hiddenCells.length &&
                        hiddenCells.includes(pos)) {
                        return mines.includes(pos);
                    }
                }
            }
        }

        return false;
    }

    function placeMines(firstClickIndex) {
        const maxAttempts = 1;
        let attempt = 0;
        //console.log("Starting mine placement...");

        console.log("Starting mine placement...");
        //console.log(`Grid size: ${gridSizeX}x${gridSizeY}, Mines: ${mineCount}`);
        //console.log(`First click index: ${firstClickIndex}`);

        while (attempt < maxAttempts) {
            attempt++;
            //console.log(`\nAttempt ${attempt}/${maxAttempts}`);

            let currentMines = [];
            let firstClickRow = Math.floor(firstClickIndex / gridSizeX);
            let firstClickCol = firstClickIndex % gridSizeX;

            // Create safe zone around first click
            let safeZone = [];
            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    let newRow = firstClickRow + r;
                    let newCol = firstClickCol + c;
                    if (newRow >= 0 && newRow < gridSizeY && newCol >= 0 && newCol < gridSizeX) {
                        safeZone.push(newRow * gridSizeX + newCol);
                    }
                }
            }

            // Place mines randomly
            while (currentMines.length < mineCount) {
                let pos = Math.floor(Math.random() * (gridSizeX * gridSizeY));
                if (!safeZone.includes(pos) && !currentMines.includes(pos)) {
                    currentMines.push(pos);
                }
            }

            // Test configuration solvability
            let solvabilityResult = testSolvability(currentMines, firstClickIndex);
            //console.log(`Solvability test results:`);
            //console.log(`- Fully solvable cells: ${solvabilityResult.solvableCells}`);
            //console.log(`- Total non-mine cells: ${gridSizeX * gridSizeY - mineCount}`);
            console.log(`- Solvability percentage: ${solvabilityResult.percentage.toFixed(2)}%`);

            if (solvabilityResult.percentage === 100) {
                console.log("Found perfect configuration!");
                //console.log(`Total attempts needed: ${attempt}`);
                mines = currentMines;
                calculateNumbers();
                return true;
            }

            // If not 100% solvable and attempts remain, continue trying
            if (attempt < maxAttempts) {
                console.log("Configuration not perfectly solvable, trying again...");
            }
        }

        return false;
    }

    function calculateNumbers() {
        numbers = []
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            if (mines.includes(i)) {
                numbers[i] = -1
                continue
            }

            let count = 0
            let row = Math.floor(i / gridSizeX)
            let col = i % gridSizeX

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    if (r === 0 && c === 0) continue

                    let newRow = row + r
                    let newCol = col + c
                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                    let pos = newRow * gridSizeX + newCol
                    if (mines.includes(pos)) count++
                }
            }
            numbers[i] = count
        }
    }

    function calculateNumbersForValidation(mines, gridSizeX, gridSizeY) {
        let numbers = [];
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            if (mines.includes(i)) {
                numbers[i] = -1;
                continue;
            }

            let count = 0;
            let row = Math.floor(i / gridSizeX);
            let col = i % gridSizeX;

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    if (r === 0 && c === 0) continue;

                    let newRow = row + r;
                    let newCol = col + c;
                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue;

                    let pos = newRow * gridSizeX + newCol;
                    if (mines.includes(pos)) count++;
                }
            }
            numbers[i] = count;
        }
        return numbers;
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
        gameTimer.stop()
        elapsedTimeLabel.text = "00:00:00"

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
            gameOver = true
            gameTimer.stop()
            revealAllMines()
            playLoose()
            gameOverLabel.text = "Game over :("
            gameOverLabel.color = "#d12844"
            gameOverWindow.visible = true
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
        //printGrid()
        checkWin()
    }

    function revealAllMines() {
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.flagged = false
                if (mines.includes(i)) {
                    cell.revealed = true
                }
            }
        }
    }

    function checkWin() {
        if (revealedCount === gridSizeX * gridSizeY - mineCount && !gameOver) {
            gameOver = true
            gameTimer.stop()
            gameOverLabel.text = "Victory :)"
            gameOverLabel.color = "#28d13c"
            gameOverWindow.visible = true
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
                if (enableQuestionMarks) {
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
        initGame()
    }

    RowLayout {
        id:topBar
        height: 40
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Button {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            onClicked: menu.open()

            Image {
                anchors.centerIn: parent
                source: root.darkMode ? "qrc:/icons/menu_light.png" : "qrc:/icons/menu_dark.png"
                height: 16
                width: 16
            }

            Menu {
                id: menu
                width: 150
                MenuItem {
                    text: "New game"
                    onTriggered: root.initGame()
                }

                MenuSeparator { }

                MenuItem {
                    text: "Save game"
                    enabled: root.gameStarted
                    onTriggered: saveWindow.visible = true
                }
                Menu {
                    id: loadMenu
                    title: "Load game"

                    Instantiator {
                        id: menuInstantiator
                        model: []

                        MenuItem {
                            text: modelData
                            onTriggered: {
                                let saveData = mainWindow.loadGameState(text)
                                if (saveData) {
                                    if (!loadGame(saveData)) {
                                        errorWindow.visible = true
                                    }
                                }
                            }
                        }

                        onObjectAdded: (index, object) => loadMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => loadMenu.removeItem(object)
                    }

                    MenuSeparator { }

                    MenuItem {
                        text: "Open save folder"
                        onTriggered: mainWindow.openSaveFolder()
                    }

                    onAboutToShow: {
                        let saves = mainWindow.getSaveFiles()
                        if (saves.length === 0) {
                            menuInstantiator.model = ["No saves found"]
                            menuInstantiator.objectAt(0).enabled = false
                        } else {
                            menuInstantiator.model = saves
                        }
                    }
                }

                MenuSeparator { }

                MenuItem {
                    text: "Settings"
                    onTriggered: settingsPage.visible = true
                }
                MenuItem {
                    text: "Exit"
                    onTriggered: Qt.quit()
                }
            }

            ApplicationWindow {
                id: saveWindow
                title: "Save Game"
                width: 300
                height: 150
                minimumWidth: 300
                minimumHeight: 150
                flags: Qt.Dialog

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    TextField {
                        id: saveNameField
                        placeholderText: "Enter save file name"
                        Layout.fillWidth: true
                        onTextChanged: {
                            // Check for invalid characters: \ / : * ? " < > |
                            let hasInvalidChars = /[\\/:*?"<>|]/.test(text)
                            invalidCharsLabel.visible = hasInvalidChars
                            spaceFiller.visible = !hasInvalidChars
                            saveButton.enabled = text.trim() !== "" && !hasInvalidChars
                        }
                    }

                    Label {
                        id: invalidCharsLabel
                        text: "Filename cannot contain: \\ / : * ? \" < > |"
                        color: "#f7c220"
                        visible: true
                        Layout.preferredHeight: 12
                        Layout.leftMargin: 3
                        font.pointSize: 10
                        Layout.fillWidth: true
                    }

                    Item {
                        id: spaceFiller
                        Layout.preferredHeight: 12
                        visible: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: 10

                        Button {
                            text: "Cancel"
                            onClicked: saveWindow.close()
                        }

                        Button {
                            id: saveButton
                            text: "Save"
                            enabled: false
                            onClicked: {
                                if (saveNameField.text.trim()) {
                                    saveGame(saveNameField.text.trim() + ".json")
                                    saveWindow.close()
                                }
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        saveNameField.text = ""
                        invalidCharsLabel.visible = false
                        spaceFiller.visible = true
                    }
                }
            }

            ApplicationWindow {
                id: errorWindow
                title: "Error"
                width: 300
                height: 150
                minimumWidth: 300
                minimumHeight: 150
                flags: Qt.Dialog

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Label {
                        text: "Failed to load save file. The file might be corrupted or incompatible."
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "OK"
                        Layout.alignment: Qt.AlignRight
                        onClicked: errorWindow.close()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            id: elapsedTimeLabel
            text: "HH:MM:SS"
            color: root.darkMode ? "white" : "black"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 13
        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.rightMargin: 2
            Layout.alignment: Qt.AlignRight

            Image {
                source: root.darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }

            Text {
                text: ": " + (root.mineCount - root.flaggedCount)
                color: root.darkMode ? "white" : "black"
                font.pixelSize: 18
                font.bold: true
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: topBar.bottom
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        contentWidth: gameLayout.implicitWidth
        contentHeight: gameLayout.implicitHeight



        ColumnLayout {
            id: gameLayout
            width: Math.max(scrollView.width, (root.cellSize + root.cellSpacing) * root.gridSizeX + 20)
            height: Math.max(scrollView.height, (root.cellSize + root.cellSpacing) * root.gridSizeY + 20)

            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: (root.cellSize + root.cellSpacing) * root.gridSizeX
                Layout.preferredHeight: (root.cellSize + root.cellSpacing) * root.gridSizeY
                Layout.margins: 10

                GridView {
                    id: grid
                    anchors.fill: parent
                    cellWidth: root.cellSize + root.cellSpacing
                    cellHeight: root.cellSize + root.cellSpacing
                    model: root.gridSizeX * root.gridSizeY
                    interactive: false

                    delegate: Item {
                        id: cellItem
                        width: cellSize
                        height: cellSize

                        property bool revealed: false
                        property bool flagged: false
                        property bool questioned: false

                        // Calculate diagonal distance for animation delay
                        readonly property int row: Math.floor(index / root.gridSizeX)
                        readonly property int col: index % root.gridSizeX
                        readonly property int diagonalSum: row + col

                        // Initial state: invisible
                        opacity: enableAnimations ? 0 : 1

                        // Animation for fade in
                        NumberAnimation {
                            id: fadeAnimation
                            target: cellItem
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 150
                        }

                        // Timer to trigger the fade in with diagonal delay
                        Timer {
                            id: fadeTimer
                            interval: diagonalSum * 20
                            repeat: false
                            onTriggered: {
                                if (enableAnimations) fadeAnimation.start()
                            }
                        }

                        // Start initial animation
                        Component.onCompleted: {
                            if (enableAnimations) fadeTimer.start()
                        }

                        Button {
                            anchors.fill: parent
                            anchors.margins: cellSpacing / 2
                            flat: parent.revealed

                            Rectangle {
                                anchors.fill: parent
                                border.width: 2
                                radius: {
                                    if (isWindows10) return 0
                                    else if (isWindows11) return 4
                                    else if (isLinux) return 3
                                    else return 2
                                }
                                border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                                visible: parent.flat
                                color: "transparent"
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
                                source: flagIcon
                                visible: cellItem.flagged
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            text: {
                                if (!parent.revealed || parent.flagged) return ""
                                if (mines.includes(index)) return ""
                                return numbers[index] === 0 ? "" : numbers[index]
                            }

                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: parent.width * 0.65
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                color: {
                                    if (!parent.parent.revealed) return "black"
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

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                               if (cellItem.revealed) {
                                                   // If cell is revealed, both left and right click will trigger chord
                                                   revealConnectedCells(index);
                                               } else {
                                                   // If cell is not revealed, follow normal click behavior
                                                   if (root.invertLRClick) {
                                                       // Swap left and right click actions
                                                       if (mouse.button === Qt.RightButton && !cellItem.flagged && !cellItem.questioned) {
                                                           reveal(index);
                                                           playClick();
                                                       } else if (mouse.button === Qt.LeftButton) {
                                                           toggleFlag(index);
                                                       }
                                                   } else {
                                                       // Default behavior
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

                        // Function to trigger fade in animation
                        function startFadeIn() {
                            if (!enableAnimations) {
                                opacity = 1
                                return
                            }
                            opacity = 0
                            fadeTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
