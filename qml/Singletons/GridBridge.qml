pragma Singleton
import QtQuick

QtObject {
    property var grid: null
    property var audioEngine: null
    property var leaderboardWindow: null
    property int generationAttempt
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0

    function setGrid(gridReference) {
        grid = gridReference
    }

    function setAudioEngine(audioEngineReference) {
        audioEngine = audioEngineReference
    }

    function setLeaderboardWindow(leaderboardWindowReference) {
        leaderboardWindow = leaderboardWindowReference
    }

    function requestHint() {
        if (!GameState.gameStarted || GameState.gameOver) {
            return;
        }

        let revealed = [];
        let flagged = [];
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i);
            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }
        let mineCell = GameLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            let cell = grid.itemAtIndex(mineCell);
            cell.highlightHint()
        }
        GameState.currentHintCount++;
    }

    function revealConnectedCells(index) {
        if (!GameSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return;
        let cell = grid.itemAtIndex(index);
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
                let adjacentCell = grid.itemAtIndex(currentPos);

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

    function generateField(index) {
        GameState.isGeneratingGrid = true
        GameState.firstClickIndex = index

        var row, col;
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

        // Use our new async method instead of the synchronous one
        generationAttempt = 0

        // Connect to the signal for this generation attempt
        function onBoardGenerated(success) {
            if (success) {
                GameState.mines = GameLogic.getMines()
                GameState.numbers = GameLogic.getNumbers()
                GameState.gameStarted = true
                GameState.isGeneratingGrid = false
                GameTimer.start()

                // Continue with the reveal operation
                let currentIndex = GameState.firstClickIndex
                let cell = grid.itemAtIndex(currentIndex)
                if (cell && !cell.revealed) {
                    cell.revealed = true
                    GameState.revealedCount++

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
                                let adjacentCell = grid.itemAtIndex(adjacentIndex)
                                if (adjacentCell.questioned) {
                                    adjacentCell.questioned = false
                                }
                                if (adjacentCell.safeQuestioned) {
                                    adjacentCell.safeQuestioned = false
                                }
                                reveal(adjacentIndex)
                            }
                        }
                    }

                    checkWin()
                }

                // Disconnect the signal
                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
            } else {
                console.error("Failed to place mines, trying again...")
                if (generationAttempt < 100) {
                    generationAttempt++

                    // Disconnect before retrying
                    GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)

                    // Try again asynchronously
                    GameLogic.generateBoardAsync(col, row)
                } else {
                    console.warn("Maximum attempts reached")
                    GameState.isGeneratingGrid = false
                    // Disconnect the signal
                    GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
                }
            }
        }

        // Connect to the signal
        GameLogic.boardGenerationCompleted.connect(onBoardGenerated)

        // Start the async generation
        GameLogic.generateBoardAsync(col, row)

        // Return true to indicate that generation has started, not completed
        return true
    }

    function reveal(index) {
        let initialCell = grid.itemAtIndex(index)
        if (GameState.gameOver || initialCell.revealed || initialCell.flagged) return

        if (!GameState.gameStarted) {
            // Start the async generation - the actual reveal happens after board is generated
            generateField(index)
            return
        }

        // Continue with normal reveal logic for subsequent clicks
        let cellsToReveal = [index]
        let visited = new Set()
        while (cellsToReveal.length > 0) {
            let currentIndex = cellsToReveal.pop()
            if (visited.has(currentIndex)) continue

            visited.add(currentIndex)
            let cell = grid.itemAtIndex(currentIndex)

            if (cell.revealed || cell.flagged) continue

            cell.revealed = true
            GameState.revealedCount++

            if (GameState.mines.includes(currentIndex)) {
                cell.isBombClicked = true
                GameState.gameOver = true
                GameState.gameWon = false
                GameTimer.stop()
                revealAllMines()
                audioEngine.playLoose()
                GameState.displayPostGame = true
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
                        let adjacentCell = grid.itemAtIndex(adjacentIndex)
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

    function initGame() {
        if (GameState.isGeneratingGrid) return
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
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            }
        }
        GameState.noAnimReset = false

        if (GameSettings.animations) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                let cell = grid.itemAtIndex(i)
                if (cell) {
                    cell.startGridResetAnimation()
                }
            }
        }
    }

    function revealAllMines() {
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
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

    function checkWin() {
        if (GameState.revealedCount === GameState.gridSizeX * GameState.gridSizeY - GameState.mineCount && !GameState.gameOver) {
            GameState.gameOver = true
            GameState.gameWon = true
            GameTimer.stop()

            let leaderboardData = GameCore.loadGameState("leaderboard.json")
            let leaderboard = {}

            if (leaderboardData) {
                try {
                    leaderboard = JSON.parse(leaderboardData)
                } catch (e) {
                    console.error("Failed to parse leaderboard data:", e)
                }
            }

            const difficulty = GameState.getDifficultyLevel();
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
                    GameState.displayNewRecord = true
                }
            }

            GameCore.saveLeaderboard(JSON.stringify(leaderboard))

            if (!GameState.isManuallyLoaded) {
                if (SteamIntegration.initialized) {
                    const difficulty = GameState.getDifficultyLevel();

                    if (GameState.currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true;
                                GameState.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true;
                                GameState.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                GameState.notificationText = qsTr("New flag unlocked!")
                                GameState.displayNotification = true;
                                GameState.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(GameTimer.centiseconds / 100) < 15 && !SteamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            SteamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            GameState.notificationText = qsTr("New grid animation unlocked!")
                            GameState.displayNotification = true
                            GameState.anim2Unlocked = true
                        }
                        if (GameState.currentHintCount >= 20 && !SteamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            SteamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            GameState.notificationText = qsTr("New grid animation unlocked!")
                            GameState.displayNotification = true
                            GameState.anim1Unlocked = true
                        }
                    }

                    SteamIntegration.incrementTotalWin();
                }
            }

            GameState.displayPostGame = true
            audioEngine.playWin()
        } else {
            audioEngine.playClick()
        }
    }

    function toggleFlag(index) {
        if (GameState.gameOver) return
        let cell = grid.itemAtIndex(index)
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                cell.flagged = true
                cell.questioned = false
                cell.safeQuestioned = false
                GameState.flaggedCount++
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
                }
            } else if (cell.questioned) {
                if (GameSettings.enableSafeQuestionMarks) {
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

                let adjacentCell = grid.itemAtIndex(newRow * GameState.gridSizeX + newCol)
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
