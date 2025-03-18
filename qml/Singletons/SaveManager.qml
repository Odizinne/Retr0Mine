pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

Item {
    id: saveManager
    property var manualSave: false
    property var savedData
    property int savedCentiseconds

    function extractAndApplyGridSize(saveData) {
        let data = JSON.parse(saveData)

        GameState.gridSizeX = data.gameState.gridSizeX
        GameState.gridSizeY = data.gameState.gridSizeY
        GameState.mineCount = data.gameState.mineCount
    }

    function loadGame(saveData) {
        try {
            let data = JSON.parse(saveData)
            if (!data.version || !data.version.startsWith("1.")) {
                console.error("Incompatible save version")
                return false
            }

            GameTimer.stop()
            const savedCentiseconds = data.gameState.centiseconds
            const gridSizeChanged = (GameState.gridSizeX !== data.gameState.gridSizeX ||
                                     GameState.gridSizeY !== data.gameState.gridSizeY)

            if (gridSizeChanged) {
                console.log("Grid dimensions changed, resetting cellsCreated counter")
                GridBridge.cellsCreated = 0
            }

            GameState.gridSizeX = data.gameState.gridSizeX
            GameState.gridSizeY = data.gameState.gridSizeY
            GameState.mineCount = data.gameState.mineCount
            GameState.mines = data.gameState.mines

            if (!GameLogic.initializeFromSave(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount, GameState.mines)) {
                console.error("Failed to initialize game logic from save")
                return false
            }

            GameState.numbers = data.gameState.numbers

            saveManager.savedData = data
            saveManager.savedCentiseconds = savedCentiseconds
            Qt.callLater(saveManager.finishLoading)

            return true

        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

    function finishLoading() {
        if (GridBridge.cellsCreated < GameState.gridSizeX * GameState.gridSizeY) {
            Qt.callLater(function() {
                saveManager.finishLoading()
            })
            return
        }

        const data = saveManager.savedData
        const savedCentiseconds = saveManager.savedCentiseconds

        if (!GameState.numbers || GameState.numbers !== data.gameState.numbers) {
            console.log("Restoring numbers in finishLoading")
            GameState.numbers = data.gameState.numbers
        }

        let foundDifficulty = GameState.difficultySettings.findIndex(setting =>
            setting.x === GameState.gridSizeX &&
            setting.y === GameState.gridSizeY &&
            setting.mines === GameState.mineCount
        )
        if (foundDifficulty === 0 || foundDifficulty === 1 ||
            foundDifficulty === 2 || foundDifficulty === 3) {
            GameSettings.difficulty = foundDifficulty
        } else {
            GameSettings.difficulty = 4
            GameSettings.customWidth = GameState.gridSizeX
            GameSettings.customHeight = GameState.gridSizeY
            GameSettings.customMines = GameState.mineCount
        }

        GameTimer.resumeFrom(savedCentiseconds)
        GameState.gameOver = data.gameState.gameOver
        GameState.gameStarted = data.gameState.gameStarted
        GameState.firstClickIndex = data.gameState.firstClickIndex
        GameState.currentHintCount = data.gameState.currentHintCount || 0

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            GridBridge.withCell(i, function(cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            })
        }

        data.gameState.revealedCells.forEach(index => {
            GridBridge.withCell(index, function(cell) {
                cell.revealed = true
            })
        })

        data.gameState.flaggedCells.forEach(index => {
            GridBridge.withCell(index, function(cell) {
                cell.flagged = true
            })
        })

        if (data.gameState.questionedCells) {
            data.gameState.questionedCells.forEach(index => {
                GridBridge.withCell(index, function(cell) {
                    cell.questioned = true
                })
            })
        }

        if (data.gameState.safeQuestionedCells) {
            data.gameState.safeQuestionedCells.forEach(index => {
                GridBridge.withCell(index, function(cell) {
                    cell.safeQuestioned = true
                })
            })
        }

        GameState.revealedCount = data.gameState.revealedCells.length
        GameState.flaggedCount = data.gameState.flaggedCells.length

        if (GameState.gameStarted && !GameState.gameOver) {
            GameTimer.start()
        }

        GameState.isManuallyLoaded = true
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
            const cell = GridBridge.getCell(i)
            if (!cell) continue

            if (cell.revealed) saveData.gameState.revealedCells.push(i)
            if (cell.flagged) saveData.gameState.flaggedCells.push(i)
            if (cell.questioned) saveData.gameState.questionedCells.push(i)
            if (cell.safeQuestioned) saveData.gameState.safeQuestionedCells.push(i)
        }

        GameCore.saveGameState(JSON.stringify(saveData), filename)
        SaveManager.manualSave = false
        SteamIntegration.difficulty = GameSettings.difficulty
    }
}
