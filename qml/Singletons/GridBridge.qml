pragma Singleton
import QtQuick
import Odizinne.Retr0Mine

Item {
    property var grid: null
    property int generationAttempt
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    property bool generationCancelled: false
    property bool idleShakeScheduled: false
    property bool globalShakeActive: false

    signal botMessageSent(string explanation)
    signal leaderboardUpdated(string timeField, string timeValue, int winsField, int winsValue)

    function getCellForCallback(index) {
        return getCell(index)
    }

    function getCell(index) {
        if (!grid) return null

        const loader = grid.itemAtIndex(index)
        if (!loader) return null

        return loader.item
    }

    function withCell(index, operation) {
        const cell = getCell(index)
        if (cell) {
            operation(cell)

            return true
        }
        return false
    }

    function setGrid(gridReference) {
        grid = gridReference
    }

    function cancelGeneration() {
        generationCancelled = true
        GameState.isGeneratingGrid = false

        GameLogic.cancelGeneration()

        try {
            GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
        } catch (e) {
            // Signal may not be connected, ignore
        }

        GameState.gameStarted = false
        GameState.firstClickIndex = -1
        GameState.mines = []
        GameState.numbers = []
    }

    function requestHint() {
        if (!GameState.gameStarted || GameState.gameOver) {
            return
        }

        if (NetworkManager.handleMultiplayerHintRequest()) {
            return
        }

        processHintRequest()
    }

    function processHintRequest() {
        let revealed = []
        let flagged = []

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = getCell(i)
            if (!cell) continue

            if (cell.revealed) revealed.push(i)
            if (cell.flagged) flagged.push(i)
        }

        const hintResult = GameLogic.findMineHintWithReasoning(revealed, flagged)
        const mineCell = hintResult.cell
        const explanation = hintResult.explanation


        if (mineCell !== -1) {
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {

                const hintData = {
                    cell: mineCell,
                    explanation: explanation
                }

                SteamIntegration.sendGameAction("sendHint", JSON.stringify(hintData))
            }

            withCell(mineCell, function(cell) {
                cell.highlightHint()
            })

            if (UserSettings.hintReasoningInChat && explanation && typeof explanation === "string" && explanation.length > 0) {
                botMessageSent(explanation)
            }
        }

        GameState.currentHintCount++
    }

    function revealConnectedCells(index) {
        if (NetworkManager.handleMultiplayerRevealConnected(index)) {
            return
        }

        performRevealConnectedCells(index)
    }

    function performRevealConnectedCells(index, playerIdentifier) {
        if (!UserSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return

        const cell = getCell(index)
        if (!cell || !cell.revealed || GameState.numbers[index] <= 0) return

        var cellsToReveal = getAdjacentCellsToReveal(
            index,
            GameState.gridSizeX,
            GameState.gridSizeY,
            GameState.numbers,
            getCellForCallback
        )

        for (let i = 0; i < cellsToReveal.length; i++) {
            performReveal(cellsToReveal[i], playerIdentifier)
        }
    }

    function onBoardGenerated(success) {
        if (generationCancelled) {
            generationCancelled = false
            try {
                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
            } catch (e) {
                // Signal was already disconnected, ignore
            }
            return
        }

        if (success) {
            GameState.mines = GameLogic.getMines()
            GameState.numbers = GameLogic.getNumbers()
            GameState.gameStarted = true
            GameState.isGeneratingGrid = false
            GameTimer.start()

            let currentIndex = GameState.firstClickIndex

            performReveal(currentIndex, "firstClick")

            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                NetworkManager.initializeMultiplayerGame(currentIndex)
            }

            GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
        } else {
            console.error("Failed to place mines, trying again...")
            if (generationAttempt < 100 && !generationCancelled) {
                generationAttempt++

                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)

                if (!generationCancelled) {
                    GameLogic.boardGenerationCompleted.connect(onBoardGenerated)

                    let row = -1, col = -1
                    if (UserSettings.safeFirstClick) {
                        row = Math.floor(GameState.firstClickIndex / GameState.gridSizeX)
                        col = GameState.firstClickIndex % GameState.gridSizeX
                    }

                    GameLogic.generateBoardAsync(col, row)
                }
            } else {
                console.warn("Maximum attempts reached or generation cancelled")
                if (!generationCancelled) {
                    GameState.isGeneratingGrid = false
                }
                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
            }
        }
    }

    function generateField(index) {
        GameState.isGeneratingGrid = true
        GameState.firstClickIndex = index
        generationCancelled = false

        var row, col
        if (UserSettings.safeFirstClick) {
            row = Math.floor(index / GameState.gridSizeX)
            col = index % GameState.gridSizeX
        } else {
            row = -1
            col = -1
        }

        if (!GameLogic.initializeGame(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount)) {
            console.error("Failed to initialize game")
            return false
        }

        generationAttempt = 0
        GameLogic.boardGenerationCompleted.connect(onBoardGenerated)
        GameLogic.generateBoardAsync(col, row)

        return true
    }

    function reveal(index, playerIdentifier) {
        registerPlayerAction()

        if (NetworkManager.handleMultiplayerReveal(index, playerIdentifier)) {
            return
        }

        performReveal(index, playerIdentifier)
    }

    function performReveal(index, playerIdentifier) {
        const initialCell = getCell(index)
        if (!initialCell || GameState.gameOver || initialCell.revealed || initialCell.flagged) return

        if (!GameState.gameStarted) {
            generateField(index)
            return
        }

        var cellsToReveal = performFloodFillReveal(
            index,
            GameState.gridSizeX,
            GameState.gridSizeY,
            GameState.mines,
            GameState.numbers,
            getCellForCallback
        )

        const mineSet = new Set(GameState.mines)
        let cellsRevealed = 0

        for (let i = 0; i < cellsToReveal.length; i++) {
            let currentIndex = cellsToReveal[i]
            const cell = getCell(currentIndex)

            if (!cell || cell.revealed || cell.flagged) continue

            cell.revealed = true
            cellsRevealed++

            if (mineSet.has(currentIndex)) {
                cell.isBombClicked = true
                GameState.gameOver = true
                GameState.gameWon = false
                GameState.bombClickedBy = playerIdentifier || SteamIntegration.playerName

                GameState.revealedCount += cellsRevealed

                attributeRevealedCells(cellsRevealed, playerIdentifier)
                GameTimer.stop()
                revealAllMines()
                AudioEngine.playLoose()
                GameState.displayPostGame = true

                if (NetworkManager.onGameLost(currentIndex)) {
                    // Handled by multiplayer
                }

                return
            }

            if (cell.questioned) {
                cell.questioned = false
            }
            if (cell.safeQuestioned) {
                cell.safeQuestioned = false
            }
        }

        GameState.revealedCount += cellsRevealed

        attributeRevealedCells(cellsRevealed, playerIdentifier)
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            checkWin()
        }
        if (!GameState.gameOver) {
            if (SteamIntegration.isInMultiplayerGame) {
                if (playerIdentifier !== SteamIntegration.playerName && playerIdentifier !== "firstClick") {
                    AudioEngine.playRemoteClick()
                } else {
                    AudioEngine.playClick()
                }
            } else {
                AudioEngine.playClick()
            }
        }
    }

    function attributeRevealedCells(count, playerIdentifier) {
        if (playerIdentifier === "firstClick") {
            GameState.firstClickRevealed += count
        } else if (playerIdentifier === NetworkManager.hostName) {
            GameState.hostRevealed += count
        } else if (playerIdentifier === NetworkManager.clientName) {
            GameState.clientRevealed += count
        }
    }

    function initGame() {
        if (GameState.isGeneratingGrid) {
            cancelGeneration()
        }

        if (SteamIntegration.isInMultiplayerGame) {
            NetworkManager.resetMultiplayerState()
        }

        performInitGame()
    }

    function performInitGame() {
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

        GameState.hostRevealed = 0
        GameState.clientRevealed = 0
        GameState.firstClickRevealed = 0

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            withCell(i, function(cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
                cell.isBombClicked = false
                cell.localPlayerOwns = false
            })
        }

        GameState.noAnimReset = false
        if (UserSettings.animations && !GameState.difficultyChanged) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                withCell(i, function(cell) {
                    cell.startGridResetAnimation()
                })
            }
        }
    }

    function revealAllMines() {
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            withCell(i, function(cell) {
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
            })
        }
    }

    function checkWin() {
        if (GameState.revealedCount === GameState.gridSizeX * GameState.gridSizeY - GameState.mineCount && !GameState.gameOver) {
            GameState.gameOver = true
            GameState.gameWon = true
            GameTimer.stop()

            if (NetworkManager.onGameWon()) {
                GameState.displayPostGame = true
                AudioEngine.playWin()
                return
            }

            let leaderboardData = GameCore.loadGameState("leaderboard.json")
            let leaderboard = {}

            if (leaderboardData) {
                try {
                    leaderboard = JSON.parse(leaderboardData)
                } catch (e) {
                    console.error("Failed to parse leaderboard data:", e)
                }
            }

            const difficulty = GameState.getDifficultyLevel()
            if (difficulty) {
                const timeField = difficulty + 'Time'
                const winsField = difficulty + 'Wins'
                const centisecondsField = difficulty + 'Centiseconds'
                const formattedTime = GameTimer.getDetailedTime()
                const centiseconds = GameTimer.centiseconds

                if (!leaderboard[winsField]) {
                    leaderboard[winsField] = 0
                }

                leaderboard[winsField]++

                leaderboardUpdated(timeField, leaderboard[timeField], winsField, leaderboard[winsField])

                if (!leaderboard[centisecondsField] || centiseconds < leaderboard[centisecondsField]) {
                    leaderboard[timeField] = formattedTime
                    leaderboard[centisecondsField] = centiseconds

                    leaderboardUpdated(timeField, formattedTime, winsField, leaderboard[winsField])

                    GameState.displayNewRecord = true
                }
            }

            GameCore.saveLeaderboard(JSON.stringify(leaderboard))

            if (!GameState.isManuallyLoaded) {
                if (SteamIntegration.initialized) {
                    const difficulty = GameState.getDifficultyLevel()

                    if (GameState.currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_EASY")
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true
                                GameState.flag1Unlocked = true
                            }
                        } else if (difficulty === 'medium') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM")
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true
                                GameState.flag2Unlocked = true
                            }
                        } else if (difficulty === 'hard') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_HARD")
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true
                                GameState.flag3Unlocked = true
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(GameTimer.centiseconds / 100) < 15 && !SteamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            SteamIntegration.unlockAchievement("ACH_SPEED_DEMON")
                            GameState.notificationText = qsTr("New grid animation unlocked!")
                            GameState.displayNotification = true
                            GameState.anim2Unlocked = true
                        }
                        if (GameState.currentHintCount >= 20 && !SteamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            SteamIntegration.unlockAchievement("ACH_HINT_MASTER")
                            GameState.notificationText = qsTr("New grid animation unlocked!")
                            GameState.displayNotification = true
                            GameState.anim1Unlocked = true
                        }
                    }

                    SteamIntegration.incrementTotalWin()
                }
            }

            GameState.displayPostGame = true
            AudioEngine.playWin()
        }
    }

    function toggleFlag(index) {
        registerPlayerAction()
        if (NetworkManager.handleMultiplayerToggleFlag(index)) {
            return
        }

        performToggleFlag(index)
    }

    function performToggleFlag(index) {
        if (GameState.gameOver) return false

        let flagCompletelyRemoved = false

        withCell(index, function(cell) {
            if (!cell.revealed) {
                if (SteamIntegration.isInMultiplayerGame) {
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        if (GameState.flaggedCount < GameState.mineCount) {
                            cell.flagged = true
                            cell.questioned = false
                            cell.safeQuestioned = false
                            GameState.flaggedCount++
                        } else {
                            cell.flagged = false
                            cell.questioned = true
                            cell.safeQuestioned = false
                        }
                    } else if (cell.flagged) {
                        cell.flagged = false
                        cell.questioned = true
                        cell.safeQuestioned = false
                        GameState.flaggedCount--
                    } else if (cell.questioned) {
                        cell.questioned = false
                        flagCompletelyRemoved = true
                    } else if (cell.safeQuestioned) {
                        cell.safeQuestioned = false
                        flagCompletelyRemoved = true
                    }
                } else {
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        if (GameState.flaggedCount < GameState.mineCount) {
                            cell.flagged = true
                            cell.questioned = false
                            cell.safeQuestioned = false
                            GameState.flaggedCount++
                        } else if (UserSettings.enableQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = true
                            cell.safeQuestioned = false
                        } else if (UserSettings.enableSafeQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = false
                            cell.safeQuestioned = true
                        }
                    } else if (cell.flagged) {
                        if (UserSettings.enableQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = true
                            cell.safeQuestioned = false
                            GameState.flaggedCount--
                        } else if (UserSettings.enableSafeQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = false
                            cell.safeQuestioned = true
                            GameState.flaggedCount--
                        } else {
                            cell.flagged = false
                            cell.questioned = false
                            cell.safeQuestioned = false
                            GameState.flaggedCount--
                            flagCompletelyRemoved = true
                        }
                    } else if (cell.questioned) {
                        if (UserSettings.enableSafeQuestionMarks) {
                            cell.questioned = false
                            cell.safeQuestioned = true
                        } else {
                            cell.questioned = false
                            flagCompletelyRemoved = true
                        }
                    } else if (cell.safeQuestioned) {
                        cell.safeQuestioned = false
                        flagCompletelyRemoved = true
                    }
                }
            }
        })

        return flagCompletelyRemoved
    }

    function hasUnrevealedNeighbors(index) {
        if (GameState.numbers[index] === 0) {
            return false
        }

        return checkUnrevealedNeighbors(
            index,
            GameState.gridSizeX,
            GameState.gridSizeY,
            GameState.numbers,
            getCellForCallback
        )
    }

    function getNeighborFlagCount(index) {
        if (GameState.numbers[index] === 0) {
            return 0
        }

        return countNeighborFlags(
            index,
            GameState.gridSizeX,
            GameState.gridSizeY,
            getCellForCallback
        )
    }

    Timer {
        id: idleTimer
        interval: 3000
        repeat: false
        onTriggered: {
            GridBridge.playShakeAnimationIfNeeded()
        }
    }

    function registerPlayerAction() {
        idleTimer.restart()
        globalShakeActive = false
    }

    function playShakeAnimationIfNeeded() {
        let anyCellNeedsShake = false
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = getCell(i)
            if (cell && cell.shakeConditionsMet) {
                anyCellNeedsShake = true
                break
            }
        }

        if (anyCellNeedsShake && !GameState.gameOver && UserSettings.shakeUnifinishedNumbers) {
            globalShakeActive = true

            shakeTimer.restart()
        } else {
            idleTimer.restart()
        }
    }

    Timer {
        id: shakeTimer
        interval: 1500
        onTriggered: {
            GridBridge.globalShakeActive = false

            idleTimer.restart()
        }
    }

    function performFloodFillReveal(index, gridSizeX, gridSizeY, mines, numbers, getCellCallback) {
        let cellsToReveal = []

        if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || typeof getCellCallback !== 'function') {
            console.warn("Invalid parameters in performFloodFillReveal")
            return cellsToReveal
        }

        const cell = getCellCallback(index)
        if (!cell) return cellsToReveal
        if (cell.revealed || cell.flagged) return cellsToReveal

        cellsToReveal.push(index)

        if (mines.includes(index)) return cellsToReveal

        const cellNumber = numbers[index] || 0
        if (cellNumber > 0) return cellsToReveal

        let cellsToProcess = [index]
        let visited = new Set([index])

        while (cellsToProcess.length > 0) {
            const currentIndex = cellsToProcess.shift()
            const row = Math.floor(currentIndex / gridSizeX)
            const col = currentIndex % gridSizeX

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    const newRow = row + r
                    const newCol = col + c

                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                        continue
                    }

                    const adjacentIndex = newRow * gridSizeX + newCol
                    if (visited.has(adjacentIndex)) continue

                    visited.add(adjacentIndex)

                    const adjacentCell = getCellCallback(adjacentIndex)
                    if (!adjacentCell) continue
                    if (adjacentCell.flagged) continue

                    if (!adjacentCell.revealed) {
                        cellsToReveal.push(adjacentIndex)

                        const adjacentNumber = numbers[adjacentIndex] || 0
                        if (adjacentNumber === 0) {
                            cellsToProcess.push(adjacentIndex)
                        }
                    }
                }
            }
        }

        return cellsToReveal
    }

    // Get cells to reveal when clicking on a numbered cell
    function getAdjacentCellsToReveal(index, gridSizeX, gridSizeY, numbers, getCellCallback) {
        let cellsToReveal = []

        if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || typeof getCellCallback !== 'function') {
            console.warn("Invalid parameters in getAdjacentCellsToReveal")
            return cellsToReveal
        }

        const cell = getCellCallback(index)
        if (!cell || !cell.revealed) return cellsToReveal

        const cellNumber = numbers[index] || 0
        if (cellNumber <= 0) return cellsToReveal

        const row = Math.floor(index / gridSizeX)
        const col = index % gridSizeX
        let flaggedCount = 0
        let adjacentUnrevealed = []
        let hasQuestionMark = false

        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue

                const newRow = row + r
                const newCol = col + c

                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                    continue
                }

                const adjacentIndex = newRow * gridSizeX + newCol
                const adjacentCell = getCellCallback(adjacentIndex)
                if (!adjacentCell) continue

                if (adjacentCell.questioned || adjacentCell.safeQuestioned) {
                    hasQuestionMark = true
                    break
                }

                if (adjacentCell.flagged) {
                    flaggedCount++
                } else if (!adjacentCell.revealed) {
                    adjacentUnrevealed.push(adjacentIndex)
                }
            }

            if (hasQuestionMark) break
        }

        if (!hasQuestionMark && flaggedCount === cellNumber && adjacentUnrevealed.length > 0) {
            return adjacentUnrevealed
        }

        return cellsToReveal
    }

    // Check if a cell has unrevealed neighbors
    function checkUnrevealedNeighbors(index, gridSizeX, gridSizeY, numbers, getCellCallback) {
        if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || typeof getCellCallback !== 'function') {
            return false
        }

        const cellNumber = numbers[index] || 0
        if (cellNumber === 0) return false

        const row = Math.floor(index / gridSizeX)
        const col = index % gridSizeX
        let flagCount = 0
        let hasUnrevealed = false

        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue

                const newRow = row + r
                const newCol = col + c

                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                    continue
                }

                const adjacentIndex = newRow * gridSizeX + newCol
                const adjacentCell = getCellCallback(adjacentIndex)
                if (!adjacentCell) continue

                if (adjacentCell.flagged) {
                    flagCount++
                }

                if (!adjacentCell.revealed && !adjacentCell.flagged) {
                    hasUnrevealed = true
                }
            }
        }

        return hasUnrevealed || flagCount !== cellNumber
    }

    // Count number of flagged neighbors
    function countNeighborFlags(index, gridSizeX, gridSizeY, getCellCallback) {
        if (index < 0 || gridSizeX <= 0 || gridSizeY <= 0 || typeof getCellCallback !== 'function') {
            return 0
        }

        const row = Math.floor(index / gridSizeX)
        const col = index % gridSizeX
        let flagCount = 0

        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue

                const newRow = row + r
                const newCol = col + c

                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) {
                    continue
                }

                const adjacentIndex = newRow * gridSizeX + newCol
                const adjacentCell = getCellCallback(adjacentIndex)
                if (!adjacentCell) continue

                if (adjacentCell.flagged) {
                    flagCount++
                }
            }
        }

        return flagCount
    }
}
