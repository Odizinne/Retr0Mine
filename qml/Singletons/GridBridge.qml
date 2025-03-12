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

    function setChatReference(chatPanel) {
        chatReference = chatPanel;
    }

    // Helper function to safely get a cell
    function getCell(index) {
        if (!grid) return null;

        const loader = grid.itemAtIndex(index);
        if (!loader) return null;

        return loader.item;
    }

    // Helper function to safely perform an operation on a cell
    function withCell(index, operation) {
        const cell = getCell(index);
        if (cell) {
            operation(cell);

            return true;
        }
        return false;
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

        // Call the C++ method to cancel the generation thread
        GameLogic.cancelGeneration()

        // Disconnect all generation signals to prevent any late callbacks from affecting the game
        try {
            GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated)
        } catch (e) {
            // Signal may not be connected, ignore
        }

        // Reset game state
        GameState.gameStarted = false
        GameState.firstClickIndex = -1
        GameState.mines = []
        GameState.numbers = []
    }

    function requestHint() {
        if (!GameState.gameStarted || GameState.gameOver) {
            return;
        }

        // Check if we're in multiplayer
        if (NetworkManager.handleMultiplayerHintRequest()) {
            return; // Action handled by multiplayer
        }

        // Regular single-player hint processing
        processHintRequest();
    }

    function processHintRequest() {
        let revealed = [];
        let flagged = [];

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = getCell(i);
            if (!cell) continue;

            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }

        // Get the hint result using the new method
        const hintResult = GameLogic.findMineHintWithReasoning(revealed, flagged);

        // Extract values from the map
        const mineCell = hintResult.cell;
        const explanation = hintResult.explanation;

        console.log("Mine cell:", mineCell, "Explanation:", explanation);

        if (mineCell !== -1) {
            // In multiplayer host mode, we need to send this cell index to the client
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                console.log("Host sending hint to client for cell:", mineCell);
                SteamIntegration.sendGameAction("sendHint", mineCell);
            }

            withCell(mineCell, function(cell) {
                cell.highlightHint();
            });

            // Add a bot message with the explanation
            if (chatReference && explanation && typeof explanation === "string" && explanation.length > 0) {
                chatReference.addBotMessage(explanation);
            }
        }

        GameState.currentHintCount++;
    }

    function revealConnectedCells(index) {
        // Check if we're in multiplayer
        if (NetworkManager.handleMultiplayerRevealConnected(index)) {
            return; // Action handled by multiplayer
        }

        // Regular single-player reveal connected cells
        performRevealConnectedCells(index);
    }

    function performRevealConnectedCells(index) {
        if (!GameSettings.autoreveal || !GameState.gameStarted || GameState.gameOver) return;

        const cell = getCell(index);
        if (!cell || !cell.revealed || GameState.numbers[index] <= 0) return;

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

                if (newRow < 0 || newRow >= GameState.gridSizeY ||
                    newCol < 0 || newCol >= GameState.gridSizeX) continue;

                let currentPos = newRow * GameState.gridSizeX + newCol;
                const adjacentCell = getCell(currentPos);

                if (!adjacentCell) continue;

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

    function onBoardGenerated(success, usedSeed) {
        // Check if generation was cancelled
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
            // Store the used seed for display
            ComponentsContext.lastUsedSeed = usedSeed;

            GameState.mines = GameLogic.getMines()
            GameState.numbers = GameLogic.getNumbers()
            GameState.gameStarted = true
            GameState.isGeneratingGrid = false
            GameTimer.start()

            // Continue with the reveal operation
            let currentIndex = GameState.firstClickIndex;
            withCell(currentIndex, function(cell) {
                if (!cell.revealed) {
                    cell.revealed = true;
                    GameState.revealedCount++;

                    if (GameState.numbers[currentIndex] === 0) {
                        let row = Math.floor(currentIndex / GameState.gridSizeX);
                        let col = currentIndex % GameState.gridSizeX;

                        for (let r = -1; r <= 1; r++) {
                            for (let c = -1; c <= 1; c++) {
                                if (r === 0 && c === 0) continue;

                                let newRow = row + r;
                                let newCol = col + c;

                                if (newRow < 0 || newRow >= GameState.gridSizeY ||
                                    newCol < 0 || newCol >= GameState.gridSizeX) continue;

                                let adjacentIndex = newRow * GameState.gridSizeX + newCol;
                                withCell(adjacentIndex, function(adjacentCell) {
                                    if (adjacentCell.questioned) {
                                        adjacentCell.questioned = false;
                                    }
                                    if (adjacentCell.safeQuestioned) {
                                        adjacentCell.safeQuestioned = false;
                                    }
                                });

                                reveal(adjacentIndex);
                            }
                        }
                    }

                    checkWin();
                }
            });

            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                console.log("Host initializing multiplayer game after board generation");
                NetworkManager.initializeMultiplayerGame(currentIndex);
            }

            // Disconnect the signal
            GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated);
        } else {
            console.error("Failed to place mines, trying again...");
            if (generationAttempt < 100 && !generationCancelled) {
                generationAttempt++;

                // Disconnect before retrying to prevent multiple callbacks
                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated);

                if (!generationCancelled) {
                    // Reconnect and try again
                    GameLogic.boardGenerationCompleted.connect(onBoardGenerated);

                    let row = -1, col = -1;
                    if (GameSettings.safeFirstClick) {
                        row = Math.floor(GameState.firstClickIndex / GameState.gridSizeX);
                        col = GameState.firstClickIndex % GameState.gridSizeX;
                    }

                    // Try again asynchronously with the same seed
                    GameLogic.generateBoardAsync(col, row, GameSettings.customSeed);
                }
            } else {
                console.warn("Maximum attempts reached or generation cancelled");
                if (!generationCancelled) {
                    GameState.isGeneratingGrid = false;
                }
                // Disconnect the signal
                GameLogic.boardGenerationCompleted.disconnect(onBoardGenerated);
            }
        }
    }

    function generateField(index) {
        GameState.isGeneratingGrid = true;
        GameState.firstClickIndex = index;
        generationCancelled = false;  // Reset cancellation flag

        var row, col;
        if (GameSettings.safeFirstClick) {
            row = Math.floor(index / GameState.gridSizeX);
            col = index % GameState.gridSizeX;
        } else {
            row = -1;
            col = -1;
        }

        // Store first click coordinates for display
        ComponentsContext.lastFirstClickX = col >= 0 ? col.toString() : "";
        ComponentsContext.lastFirstClickY = row >= 0 ? row.toString() : "";

        if (!GameLogic.initializeGame(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount)) {
            console.error("Failed to initialize game");
            return false;
        }

        // Use our new async method instead of the synchronous one
        generationAttempt = 0;

        // Connect to the signal for this generation attempt
        GameLogic.boardGenerationCompleted.connect(onBoardGenerated);

        // Start the async generation with the seed from settings
        GameLogic.generateBoardAsync(col, row, GameSettings.customSeed);

        // Return true to indicate that generation has started, not completed
        return true;
    }

    function reveal(index) {
        // Check if we're in multiplayer
        registerPlayerAction()
        if (NetworkManager.handleMultiplayerReveal(index)) {
            return; // Action handled by multiplayer
        }

        // Regular single-player reveal
        performReveal(index);
    }

    function performReveal(index) {
        const initialCell = getCell(index);
        if (!initialCell || GameState.gameOver || initialCell.revealed || initialCell.flagged) return;

        if (!GameState.gameStarted) {
            // Start the async generation - the actual reveal happens after board is generated
            generateField(index);
            return;
        }

        // Continue with normal reveal logic for subsequent clicks
        let cellsToReveal = [index];
        let visited = new Set();

        while (cellsToReveal.length > 0) {
            let currentIndex = cellsToReveal.pop();
            if (visited.has(currentIndex)) continue;

            visited.add(currentIndex);
            const cell = getCell(currentIndex);

            if (!cell || cell.revealed || cell.flagged) continue;

            cell.revealed = true;
            GameState.revealedCount++;

            if (GameState.mines.includes(currentIndex)) {
                cell.isBombClicked = true;
                GameState.gameOver = true;
                GameState.gameWon = false;
                GameTimer.stop();
                revealAllMines();
                if (audioEngine) audioEngine.playLoose();
                GameState.displayPostGame = true;

                // In multiplayer, if we're the host, send game over notification to client
                if (NetworkManager.onGameLost(currentIndex)) {
                    // Handled by multiplayer
                }

                return;
            }

            const cellNumber = GameState.numbers[currentIndex];
            if (cellNumber === 0) {
                let row = Math.floor(currentIndex / GameState.gridSizeX);
                let col = currentIndex % GameState.gridSizeX;

                for (let r = -1; r <= 1; r++) {
                    for (let c = -1; c <= 1; c++) {
                        if (r === 0 && c === 0) continue;

                        let newRow = row + r;
                        let newCol = col + c;

                        if (newRow < 0 || newRow >= GameState.gridSizeY ||
                            newCol < 0 || newCol >= GameState.gridSizeX) continue;

                        let adjacentIndex = newRow * GameState.gridSizeX + newCol;

                        withCell(adjacentIndex, function(adjacentCell) {
                            if (adjacentCell.questioned) {
                                adjacentCell.questioned = false;
                            }
                            if (adjacentCell.safeQuestioned) {
                                adjacentCell.safeQuestioned = false;
                            }
                        });

                        cellsToReveal.push(adjacentIndex);
                    }
                }
            }
        }

        checkWin();
    }

    function initGame() {
        if (GameState.isGeneratingGrid) {
            // Cancel any ongoing generation
            cancelGeneration();
        }

        // Handle multiplayer networking logic
        if (SteamIntegration.isInMultiplayerGame) {
            NetworkManager.resetMultiplayerState();
        }

        // Call the shared implementation
        performInitGame();
    }

    function performInitGame() {
        GameState.blockAnim = false;
        GameState.mines = [];
        GameState.numbers = [];
        GameState.gameOver = false;
        GameState.revealedCount = 0;
        GameState.flaggedCount = 0;
        GameState.firstClickIndex = -1;
        GameState.gameStarted = false;
        GameState.currentHintCount = 0;
        GameTimer.reset();
        GameState.isManuallyLoaded = false;
        GameState.noAnimReset = true;

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            withCell(i, function(cell) {
                cell.revealed = false;
                cell.flagged = false;
                cell.questioned = false;
                cell.safeQuestioned = false;
                cell.isBombClicked = false;
            });
        }

        GameState.noAnimReset = false;
        if (GameSettings.animations && !GameState.difficultyChanged) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                withCell(i, function(cell) {
                    cell.startGridResetAnimation();
                });
            }
        }
    }

    function revealAllMines() {
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            withCell(i, function(cell) {
                if (GameState.mines.includes(i)) {
                    if (!cell.flagged) {
                        cell.questioned = false;
                        cell.revealed = true;
                    } else {
                        cell.revealed = false;
                    }
                } else {
                    if (cell.flagged) {
                        cell.flagged = false;
                    }
                }
            });
        }
    }

    function checkWin() {
        if (GameState.revealedCount === GameState.gridSizeX * GameState.gridSizeY - GameState.mineCount && !GameState.gameOver) {
            GameState.gameOver = true;
            GameState.gameWon = true;
            GameTimer.stop();

            // Handle multiplayer win
            if (NetworkManager.onGameWon()) {
                // Game win handled by multiplayer
                GameState.displayPostGame = true;
                if (audioEngine) audioEngine.playWin();
                return;
            }

            // Leaderboard updates for single player only
            let leaderboardData = GameCore.loadGameState("leaderboard.json");
            let leaderboard = {};

            if (leaderboardData) {
                try {
                    leaderboard = JSON.parse(leaderboardData);
                } catch (e) {
                    console.error("Failed to parse leaderboard data:", e);
                }
            }

            const difficulty = GameState.getDifficultyLevel();
            if (difficulty) {
                const timeField = difficulty + 'Time';
                const winsField = difficulty + 'Wins';
                const centisecondsField = difficulty + 'Centiseconds';
                const formattedTime = GameTimer.getDetailedTime();
                const centiseconds = GameTimer.centiseconds;

                if (!leaderboard[winsField]) {
                    leaderboard[winsField] = 0;
                }

                leaderboard[winsField]++;
                if (leaderboardWindow) {
                    leaderboardWindow[winsField] = leaderboard[winsField];
                }

                if (!leaderboard[centisecondsField] || centiseconds < leaderboard[centisecondsField]) {
                    leaderboard[timeField] = formattedTime;
                    leaderboard[centisecondsField] = centiseconds;
                    if (leaderboardWindow) {
                        leaderboardWindow[timeField] = formattedTime;
                    }
                    GameState.displayNewRecord = true;
                }
            }

            GameCore.saveLeaderboard(JSON.stringify(leaderboard));

            // Achievement updates for single player only
            if (!GameState.isManuallyLoaded) {
                if (SteamIntegration.initialized) {
                    const difficulty = GameState.getDifficultyLevel();

                    if (GameState.currentHintCount === 0) {
                        if (difficulty === 'easy') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_EASY")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_EASY");
                                GameState.notificationText = qsTr("New flag unlocked!");
                                GameState.displayNotification = true;
                                GameState.flag1Unlocked = true;
                            }
                        } else if (difficulty === 'medium') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_MEDIUM")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_MEDIUM");
                                GameState.notificationText = qsTr("New flag unlocked!");
                                GameState.displayNotification = true;
                                GameState.flag2Unlocked = true;
                            }
                        } else if (difficulty === 'hard') {
                            if (!SteamIntegration.isAchievementUnlocked("ACH_NO_HINT_HARD")) {
                                SteamIntegration.unlockAchievement("ACH_NO_HINT_HARD");
                                GameState.notificationText = qsTr("New flag unlocked!");
                                GameState.displayNotification = true;
                                GameState.flag3Unlocked = true;
                            }
                        }
                    }

                    if (difficulty === 'easy') {
                        if (Math.floor(GameTimer.centiseconds / 100) < 15 && !SteamIntegration.isAchievementUnlocked("ACH_SPEED_DEMON")) {
                            SteamIntegration.unlockAchievement("ACH_SPEED_DEMON");
                            GameState.notificationText = qsTr("New grid animation unlocked!");
                            GameState.displayNotification = true;
                            GameState.anim2Unlocked = true;
                        }
                        if (GameState.currentHintCount >= 20 && !SteamIntegration.isAchievementUnlocked("ACH_HINT_MASTER")) {
                            SteamIntegration.unlockAchievement("ACH_HINT_MASTER");
                            GameState.notificationText = qsTr("New grid animation unlocked!");
                            GameState.displayNotification = true;
                            GameState.anim1Unlocked = true;
                        }
                    }

                    SteamIntegration.incrementTotalWin();
                }
            }

            // Always display post-game UI for both single player and multiplayer
            GameState.displayPostGame = true;
            if (audioEngine) audioEngine.playWin();
        } else {
            if (audioEngine) audioEngine.playClick();
        }
    }

    function toggleFlag(index) {
        // Check if we're in multiplayer
        registerPlayerAction()
        if (NetworkManager.handleMultiplayerToggleFlag(index)) {
            return; // Action handled by multiplayer
        }

        // Regular single-player flag toggle (no cooldown needed)
        performToggleFlag(index);
    }

    function performToggleFlag(index) {
        if (GameState.gameOver) return false;

        let flagCompletelyRemoved = false;

        withCell(index, function(cell) {
            if (!cell.revealed) {
                if (SteamIntegration.isInMultiplayerGame) {
                    // Modified multiplayer flagging with question marks enabled
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        // Only place flag if we haven't reached max flags yet
                        if (GameState.flaggedCount < GameState.mineCount) {
                            cell.flagged = true;
                            cell.questioned = false;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount++;
                        } else {
                            // If max flags reached, go directly to question mark
                            cell.flagged = false;
                            cell.questioned = true;
                            cell.safeQuestioned = false;
                        }
                    } else if (cell.flagged) {
                        // Always enable question marks in multiplayer
                        cell.flagged = false;
                        cell.questioned = true;
                        cell.safeQuestioned = false;
                        GameState.flaggedCount--; // Decrement only when removing a flag
                    } else if (cell.questioned) {
                        cell.questioned = false;
                        flagCompletelyRemoved = true; // Flag cycle is complete
                    } else if (cell.safeQuestioned) {
                        // In multiplayer, always go from question mark back to empty (no safe question marks)
                        cell.safeQuestioned = false;
                        flagCompletelyRemoved = true; // Flag cycle is complete
                    }
                } else {
                    // Original single-player flagging logic
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        // Only place flag if we haven't reached max flags yet
                        if (GameState.flaggedCount < GameState.mineCount) {
                            cell.flagged = true;
                            cell.questioned = false;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount++;
                        } else if (GameSettings.enableQuestionMarks) {
                            // If max flags reached, go directly to question mark
                            cell.flagged = false;
                            cell.questioned = true;
                            cell.safeQuestioned = false;
                        } else if (GameSettings.enableSafeQuestionMarks) {
                            // If max flags reached, go directly to safe question mark
                            cell.flagged = false;
                            cell.questioned = false;
                            cell.safeQuestioned = true;
                        }
                        // If no question marks enabled and max flags reached, do nothing
                    } else if (cell.flagged) {
                        if (GameSettings.enableQuestionMarks) {
                            cell.flagged = false;
                            cell.questioned = true;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount--; // Decrement only when removing a flag
                        } else if (GameSettings.enableSafeQuestionMarks) {
                            cell.flagged = false;
                            cell.questioned = false;
                            cell.safeQuestioned = true;
                            GameState.flaggedCount--; // Decrement only when removing a flag
                        } else {
                            cell.flagged = false;
                            cell.questioned = false;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount--; // Decrement only when removing a flag
                            flagCompletelyRemoved = true; // Flag cycle is complete
                        }
                    } else if (cell.questioned) {
                        if (GameSettings.enableSafeQuestionMarks) {
                            cell.questioned = false;
                            cell.safeQuestioned = true;
                        } else {
                            cell.questioned = false;
                            flagCompletelyRemoved = true; // Flag cycle is complete
                        }
                    } else if (cell.safeQuestioned) {
                        cell.safeQuestioned = false;
                        flagCompletelyRemoved = true; // Flag cycle is complete
                    }
                }
            }
        });

        return flagCompletelyRemoved;
    }

    function hasUnrevealedNeighbors(index) {
        // If the cell has no number (0), no need for satisfaction check
        if (GameState.numbers[index] === 0) {
            return false;
        }

        let row = Math.floor(index / GameState.gridSizeX);
        let col = index % GameState.gridSizeX;
        let flagCount = 0;
        let unrevealedCount = 0;

        // Count flagged and unrevealed neighbors
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;

                let newRow = row + r;
                let newCol = col + c;

                if (newRow < 0 || newRow >= GameState.gridSizeY ||
                    newCol < 0 || newCol >= GameState.gridSizeX) continue;

                const adjacentCell = getCell(newRow * GameState.gridSizeX + newCol);
                if (!adjacentCell) continue;

                if (adjacentCell.flagged) {
                    flagCount++;
                }
                if (!adjacentCell.revealed && !adjacentCell.flagged) {
                    unrevealedCount++;
                }
            }
        }

        return unrevealedCount > 0 || flagCount !== GameState.numbers[index];
    }

    function getNeighborFlagCount(index) {
        // If the cell has no number, return 0
        if (GameState.numbers[index] === 0) {
            return 0;
        }

        let row = Math.floor(index / GameState.gridSizeX);
        let col = index % GameState.gridSizeX;
        let flagCount = 0;

        // Count flagged neighbors
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;

                let newRow = row + r;
                let newCol = col + c;

                if (newRow < 0 || newRow >= GameState.gridSizeY ||
                    newCol < 0 || newCol >= GameState.gridSizeX) continue;

                const adjacentCell = getCell(newRow * GameState.gridSizeX + newCol);
                if (!adjacentCell) continue;

                if (adjacentCell.flagged) {
                    flagCount++;
                }
            }
        }

        return flagCount;
    }

    Timer {
        id: idleTimer
        interval: 3000
        repeat: false
        onTriggered: {
            // Start shaking if appropriate
            GridBridge.playShakeAnimationIfNeeded()
        }
    }

    function registerPlayerAction() {
        // Reset the idle timer
        idleTimer.restart()
        // Cancel any active shake
        globalShakeActive = false
    }

    // Check if any cells need shaking and start the animation
    function playShakeAnimationIfNeeded() {
        // Check if any cells meet shake conditions
        let anyCellNeedsShake = false
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = getCell(i)
            if (cell && cell.shakeConditionsMet) {
                anyCellNeedsShake = true
                break
            }
        }

        if (anyCellNeedsShake && !GameState.gameOver && GameSettings.shakeUnifinishedNumbers) {
            // Start shake animation
            globalShakeActive = true

            // Set timer to end animation
            shakeTimer.restart()
        } else {
            // No cells need shaking, so check again after 3 seconds
            idleTimer.restart()
        }
    }

    // Timer to control shake animation duration
    Timer {
        id: shakeTimer
        interval: 1500 // Animation duration (matches 3 loops of your animation)
        repeat: false
        onTriggered: {
            // End shake animation
            GridBridge.globalShakeActive = false

            // Schedule next idle check
            idleTimer.restart()
        }
    }

    function addBotHint(message) {
        if (chatReference && typeof chatReference.addBotMessage === "function") {
            chatReference.addBotMessage(message);
        }
    }
}
