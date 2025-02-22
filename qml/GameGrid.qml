import QtQuick

GridView {
    id: grid
    anchors.centerIn: parent
    cellWidth: GameState.cellSize + GameState.cellSpacing
    cellHeight: GameState.cellSize + GameState.cellSpacing
    width: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX
    height: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY
    model: GameState.gridSizeX * GameState.gridSizeY
    interactive: false
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    required property var leaderboardWindow
    required property var gameOverPopup
    required property var audioEngine

    function requestHint() {
        if (!GameState.gameStarted || GameState.gameOver) {
            return;
        }

        let revealed = [];
        let flagged = [];
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell;
            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }
        let mineCell = MinesweeperLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            let cell = grid.itemAtIndex(mineCell) as Cell;
            cell.highlightHint()
        }
        GameState.currentHintCount++;
    }

    function revealConnectedCells(index) {
        if (!Retr0MineSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return;
        let cell = grid.itemAtIndex(index) as Cell;
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

        if (!hasQuestionMark && flaggedCount === GameState.numbers[index] && adjacentCells.length > 0) {
            for (let adjacentPos of adjacentCells) {
                reveal(adjacentPos);
            }
        }
    }

    function reveal(index) {
        let initialCell = grid.itemAtIndex(index) as Cell
        if (GameState.gameOver || initialCell.revealed || initialCell.flagged) return

        if (!GameState.gameStarted) {
            GameState.firstClickIndex = index
            if (!placeMines(index)) {
                reveal(index)
                return
            }
            GameState.gameStarted = true
            GameTimer.start()
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
            GameState.revealedCount++

            if (GameState.mines.includes(currentIndex)) {
                cell.isBombClicked = true
                GameState.gameOver = true
                GameTimer.stop()
                revealAllMines()
                audioEngine.playLoose()
                gameOverPopup.gameOverLabelText = "Game over"
                gameOverPopup.gameOverLabelColor = "#d12844"
                gameOverPopup.newRecordVisible = false
                gameOverPopup.visible = true
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

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / GameState.gridSizeX);
        const col = firstClickIndex % GameState.gridSizeX;

        if (!MinesweeperLogic.initializeGame(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount)) {
            console.error("Failed to initialize game!");
            return false;
        }

        const result = MinesweeperLogic.placeLogicalMines(col, row);
        if (!result) {
            console.error("Failed to place mines!");
            return false;
        }

        GameState.mines = MinesweeperLogic.getMines();
        GameState.numbers = MinesweeperLogic.getNumbers();
        return true;
    }

    function initGame() {
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
            let cell = grid.itemAtIndex(i) as Cell
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.safeQuestioned = false
            }
        }
        GameState.noAnimReset = false

        if (Retr0MineSettings.animations) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                let cell = grid.itemAtIndex(i) as Cell
                if (cell) {
                    cell.startGridResetAnimation()
                }
            }
        }
    }

    function revealAllMines() {
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            let cell = grid.itemAtIndex(i) as Cell
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
            GameTimer.stop()

            let leaderboardData = MainWindow.loadGameState("leaderboard.json")
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
                    gameOverPopup.newRecordVisible = true
                } else {
                    gameOverPopup.newRecordVisible = false
                }
            }

            MainWindow.saveLeaderboard(JSON.stringify(leaderboard))

            if (!GameState.isManuallyLoaded) {
                if (SteamIntegration.initialized) {
                    const difficulty = GameState.getDifficultyLevel();

                    if (GameState.currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                gameOverPopup.notificationText = qsTr("New flag unlocked!")
                                gameOverPopup.notificationVisible = true;
                                GameState.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(GameTimer.centiseconds / 100) < 15 && !SteamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            SteamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            GameState.anim2Unlocked = true
                        }
                        if (GameState.currentHintCount >= 20 && !SteamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            SteamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            gameOverPopup.notificationText = qsTr("New grid animation unlocked!")
                            gameOverPopup.notificationVisible = true
                            GameState.anim1Unlocked = true
                        }
                    }

                    SteamIntegration.incrementTotalWin();
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
        if (GameState.gameOver) return
        let cell = grid.itemAtIndex(index) as Cell
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                cell.flagged = true
                cell.questioned = false
                cell.safeQuestioned = false
                GameState.flaggedCount++
            } else if (cell.flagged) {
                if (Retr0MineSettings.enableQuestionMarks) {
                    cell.flagged = false
                    cell.questioned = true
                    cell.safeQuestioned = false
                    GameState.flaggedCount--
                } else if (Retr0MineSettings.enableSafeQuestionMarks) {
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

                let adjacentCell = grid.itemAtIndex(newRow * GameState.gridSizeX + newCol) as Cell
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
