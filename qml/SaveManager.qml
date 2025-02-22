pragma Singleton
import QtQuick

Item {
    id: saveManager
    property var grid: null

    function setGrid(gridReference) {
        grid = gridReference
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
        onTriggered: saveManager.finishLoading()
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
}
