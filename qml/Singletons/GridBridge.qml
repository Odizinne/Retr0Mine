pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

Item {
    property var grid: null
    property var audioEngine: null
    property var leaderboardWindow: null
    property var chatReference: null
    property int generationAttempt
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    property bool generationCancelled: false
    property bool idleShakeScheduled: false
    property bool globalShakeActive: false

    property GridBridgeHelper helper: GridBridgeHelper

    function getCellForCallback(index) {
        return getCell(index)
    }

    function setChatReference(chatPanel) {
        chatReference = chatPanel
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

    function setAudioEngine(audioEngineReference) {
        audioEngine = audioEngineReference
    }

    function setLeaderboardWindow(leaderboardWindowReference) {
        leaderboardWindow = leaderboardWindowReference
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

            if (GameSettings.hintReasoningInChat && chatReference && explanation && typeof explanation === "string" && explanation.length > 0) {
                chatReference.addBotMessage(explanation)
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
        if (!GameSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return

        const cell = getCell(index)
        if (!cell || !cell.revealed || GameState.numbers[index] <= 0) return

        var cellsToReveal = helper.getAdjacentCellsToReveal(
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
                    if (GameSettings.safeFirstClick) {
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
        if (GameSettings.safeFirstClick) {
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

        var cellsToReveal = helper.performFloodFillReveal(
            index,
            GameState.gridSizeX,
            GameState.gridSizeY,
            GameState.mines,
            GameState.numbers,
            getCellForCallback
        )

        let cellsRevealed = 0

        for (let i = 0; i < cellsToReveal.length; i++) {
            let currentIndex = cellsToReveal[i]
            const cell = getCell(currentIndex)

            if (!cell || cell.revealed || cell.flagged) continue

            cell.revealed = true
            GameState.revealedCount++
            cellsRevealed++

            if (GameState.mines.includes(currentIndex)) {
                cell.isBombClicked = true
                GameState.gameOver = true
                GameState.gameWon = false
                GameState.bombClickedBy = playerIdentifier || SteamIntegration.playerName

                attributeRevealedCells(cellsRevealed, playerIdentifier)

                GameTimer.stop()
                revealAllMines()
                audioEngine.playLoose()
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

        attributeRevealedCells(cellsRevealed, playerIdentifier)
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            checkWin()
        }
        if (!GameState.gameOver) {
            if (SteamIntegration.isInMultiplayerGame) {
                if (playerIdentifier !== SteamIntegration.playerName && playerIdentifier !== "firstClick") {
                    audioEngine.playRemoteClick()
                } else {
                    audioEngine.playClick()
                }
            } else {
                audioEngine.playClick()
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
        if (GameSettings.animations && !GameState.difficultyChanged) {
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
                audioEngine.playWin()
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
                if (leaderboardWindow) {
                    leaderboardWindow[winsField] = leaderboard[winsField]
                }

                if (!leaderboard[centisecondsField] || centiseconds < leaderboard[centisecondsField]) {
                    leaderboard[timeField] = formattedTime
                    leaderboard[centisecondsField] = centiseconds
                    if (leaderboardWindow) {
                        leaderboardWindow[timeField] = formattedTime
                    }
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
            audioEngine.playWin()
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
                        } else if (GameSettings.enableQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = true
                            cell.safeQuestioned = false
                        } else if (GameSettings.enableSafeQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = false
                            cell.safeQuestioned = true
                        }
                    } else if (cell.flagged) {
                        if (GameSettings.enableQuestionMarks) {
                            cell.flagged = false
                            cell.questioned = true
                            cell.safeQuestioned = false
                            GameState.flaggedCount--
                        } else if (GameSettings.enableSafeQuestionMarks) {
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
                        if (GameSettings.enableSafeQuestionMarks) {
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

        return helper.hasUnrevealedNeighbors(
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

        return helper.getNeighborFlagCount(
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

        if (anyCellNeedsShake && !GameState.gameOver && GameSettings.shakeUnifinishedNumbers) {
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

    function addBotHint(message) {
        if (chatReference && typeof chatReference.addBotMessage === "function") {
            chatReference.addBotMessage(message)
        }
    }
}
