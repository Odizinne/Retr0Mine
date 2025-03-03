pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

QtObject {
    property var grid: null
    property var audioEngine: null
    property var leaderboardWindow: null
    property int generationAttempt
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    property bool generationCancelled: false

    // New multiplayer properties
    property bool isProcessingNetworkAction: false
    property var pendingActions: []
    property bool minesInitialized: false
    property bool clientReadyForActions: false  // Tracks if client is ready to receive actions
    property var pendingInitialActions: []      // Stores initial actions that came with board generation
    property bool p2pConnected: false
    property bool clientGridReady: false
    property bool sessionRunning: false
    property bool mpPopupCloseButtonVisible: false
    property bool allowClientReveal: false
    property var chunkedMines: []
    property int receivedChunks: 0
    property int expectedTotalChunks: 0

    Component.onCompleted: {
        // Connect to SteamIntegration signals for multiplayer
        SteamIntegration.gameActionReceived.connect(handleNetworkAction);
        SteamIntegration.gameStateReceived.connect(applyGameState);

        // Reset clientGridReady when player leaves multiplayer
        SteamIntegration.multiplayerStatusChanged.connect(function() {
            if (!SteamIntegration.isInMultiplayerGame) {
                clientGridReady = false;
            }
        });
    }

    // Utility function to convert object arrays to proper arrays
    function convertObjectToArray(obj, name) {
        let resultArray = [];
        if (Array.isArray(obj)) {
            resultArray = Array.from(obj);
            console.log("Processing " + name + " as array, length:", resultArray.length);
        } else if (typeof obj === 'object' && obj !== null) {
            // Convert object to array
            console.log("Processing " + name + " as object");
            for (let prop in obj) {
                if (!isNaN(parseInt(prop))) {
                    resultArray.push(parseInt(obj[prop]));
                }
            }
            console.log("Converted " + name + " to array, length:", resultArray.length);
        } else {
            console.log(name + " is empty or invalid");
        }
        return resultArray;
    }

    function safeArrayIncludes(array, value) {
        // For single player, just use the normal includes
        if (!SteamIntegration.isInMultiplayerGame) {
            return array && array.includes(value);
        }

        // For multiplayer, do the more careful check
        return Array.isArray(array) && array !== null && array.includes(value);
    }

    function safeArrayGet(array, index) {
        // For single player, just access directly
        if (!SteamIntegration.isInMultiplayerGame) {
            return array && array[index];
        }

        // For multiplayer, do the more careful check
        return Array.isArray(array) && array !== null && index >= 0 && index < array.length ? array[index] : undefined;
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

            // For multiplayer client, force update the visual state
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                if (cell.revealed && cell.button && !cell.button.flat) {
                    // Force the button to be flat if the cell is revealed
                    cell.button.flat = true;
                    cell.button.opacity = 1;
                }
            }

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
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                // Host processes hint locally
                processHintRequest();
            } else {
                // Client sends request to host
                console.log("Client requesting hint from host");
                isProcessingNetworkAction = true;
                SteamIntegration.sendGameAction("requestHint", 0);
                // The response will come back through handleNetworkAction
            }
            return;
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

        let mineCell = GameLogic.findMineHint(revealed, flagged);
        if (mineCell !== -1) {
            // In multiplayer host mode, we need to send this cell index to the client
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                console.log("Host sending hint to client for cell:", mineCell);
                SteamIntegration.sendGameAction("sendHint", mineCell);
            }

            withCell(mineCell, function(cell) {
                cell.highlightHint();
            });
        }

        GameState.currentHintCount++;
    }

    function revealConnectedCells(index) {
        // Check if we're in multiplayer
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                // We're host: process locally and then send only the cell update
                performRevealConnectedCells(index);
                sendCellUpdateToClient(index, "revealConnected");
            } else {
                // We're client: send request to host and wait
                isProcessingNetworkAction = true;
                SteamIntegration.sendGameAction("revealConnected", index);
                // The grid will update when we get a response
            }
            return;
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

    function onBoardGenerated(success) {
        // Check if generation was cancelled
        if (generationCancelled) {
            generationCancelled = false
            // Disconnect the signal if still connected
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
                // Reset ready flag when starting new game
                clientReadyForActions = false;
                pendingInitialActions = [];

                // Send mines list first
                minesInitialized = true;
                sendMinesListToClient();

                // Store the initial reveal action instead of sending immediately
                pendingInitialActions.push({type: "reveal", index: currentIndex});

                // Start checking if client has processed mines
                Qt.callLater(function() {
                    console.log("Checking if client has processed mines");
                    SteamIntegration.sendGameAction("minesReady", 0);
                });
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

                    // Try again asynchronously
                    GameLogic.generateBoardAsync(col, row);
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

        if (!GameLogic.initializeGame(GameState.gridSizeX, GameState.gridSizeY, GameState.mineCount)) {
            console.error("Failed to initialize game");
            return false;
        }

        // Use our new async method instead of the synchronous one
        generationAttempt = 0;

        // Connect to the signal for this generation attempt
        GameLogic.boardGenerationCompleted.connect(onBoardGenerated);

        // Start the async generation
        GameLogic.generateBoardAsync(col, row);

        // Return true to indicate that generation has started, not completed
        return true;
    }

    function reveal(index) {
        // Check if we're in multiplayer
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                // We're host: process locally and then send only the cell update
                performReveal(index);
                // Note: performReveal can reveal multiple cells for 0-tiles
                // We'll handle that by tracking the revealed cells

                // For simplicity, instead of tracking all revealed cells in performReveal,
                // we'll just send the initial index as "reveal" action
                // The host has already processed the full chain reveal
                // The client will handle the chain reveal when it gets this action
                sendCellUpdateToClient(index, "reveal");
            } else {
                // We're client: send request to host and wait
                isProcessingNetworkAction = true;
                SteamIntegration.sendGameAction("reveal", index);
                // The grid will update when we get a response
            }
            return;
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
                if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                    // Make sure we send the final cell state before game over
                    sendCellUpdateToClient(currentIndex, "finalReveal");

                    // Wait a moment to ensure cell updates are processed before game over
                    Qt.callLater(function() {
                        // Send game over message with loss status (0 = loss)
                        SteamIntegration.sendGameAction("gameOver", 0);
                    });
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

        // Reset multiplayer state and notify client if we're the host
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                console.log("Host notifying client about game reset");
                SteamIntegration.sendGameAction("resetGame", 0);
            }

            // Reset multiplayer flags
            minesInitialized = false;
            clientReadyForActions = false;
            //clientGridReady = false;  // Reset the grid ready flag
            pendingInitialActions = [];
            pendingActions = [];
            isProcessingNetworkAction = false;
        }

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
            });
        }

        GameState.noAnimReset = false;
        if (GameSettings.animations) {
            if (GameState.difficultyChanged) {
                return
            }
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

            // In multiplayer mode, we need special handling
            if (SteamIntegration.isInMultiplayerGame) {
                // If we're the host, make sure to sync final cell state BEFORE sending game over
                if (SteamIntegration.isHost) {
                    // Ensure all revealed cells are properly synchronized first
                    for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                        const cell = getCell(i);
                        if (cell && cell.revealed && !GameState.mines.includes(i)) {
                            // Force send all revealed cells to ensure client has latest state
                            sendCellUpdateToClient(i, "finalReveal");
                        }
                    }

                    // Wait a moment to ensure cell updates are processed before game over
                    Qt.callLater(function() {
                        // Send game over message with win status (1 = win)
                        SteamIntegration.sendGameAction("gameOver", 1);
                    });
                }

                // For both host and client, we need to display the game over UI
                GameState.displayPostGame = true;
                if (audioEngine) audioEngine.playWin();

                // Handle achievement unlocking for multiplayer
                const difficulty = GameState.getDifficultyLevel();
                if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
                    SteamIntegration.unlockAchievement("ACH_WIN_COOP");
                    if (SteamIntegration.isHost) {
                        SteamIntegration.sendGameAction("unlockCoopAchievement", 0);
                    }
                }

                return;  // Exit early for multiplayer
            }

            // Skip ALL leaderboard and achievement updates in multiplayer
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
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                // We're host: process locally and then send only the cell update
                performToggleFlag(index);
                sendCellUpdateToClient(index, "flag");
            } else {
                // We're client: send request to host and wait
                isProcessingNetworkAction = true;
                SteamIntegration.sendGameAction("flag", index);
                // The grid will update when we get a response
            }
            return;
        }

        // Regular single-player flag toggle
        performToggleFlag(index);
    }

    function performToggleFlag(index) {
        if (GameState.gameOver) return;

        withCell(index, function(cell) {
            if (!cell.revealed) {
                if (SteamIntegration.isInMultiplayerGame) {
                    // Modified multiplayer flagging with question marks enabled
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        cell.flagged = true;
                        cell.questioned = false;
                        cell.safeQuestioned = false;
                        GameState.flaggedCount++;
                    } else if (cell.flagged) {
                        // Always enable question marks in multiplayer
                        cell.flagged = false;
                        cell.questioned = true;
                        cell.safeQuestioned = false;
                        GameState.flaggedCount--;
                    } else if (cell.questioned) {
                        cell.questioned = false;
                    } else if (cell.safeQuestioned) {
                        // In multiplayer, always go from question mark back to empty (no safe question marks)
                        cell.safeQuestioned = false;
                    }
                } else {
                    // Original single-player flagging logic
                    if (!cell.flagged && !cell.questioned && !cell.safeQuestioned) {
                        cell.flagged = true;
                        cell.questioned = false;
                        cell.safeQuestioned = false;
                        GameState.flaggedCount++;
                    } else if (cell.flagged) {
                        if (GameSettings.enableQuestionMarks) {
                            cell.flagged = false;
                            cell.questioned = true;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount--;
                        } else if (GameSettings.enableSafeQuestionMarks) {
                            cell.flagged = false;
                            cell.questioned = false;
                            cell.safeQuestioned = true;
                            GameState.flaggedCount--;
                        } else {
                            cell.flagged = false;
                            cell.questioned = false;
                            cell.safeQuestioned = false;
                            GameState.flaggedCount--;
                        }
                    } else if (cell.questioned) {
                        if (GameSettings.enableSafeQuestionMarks) {
                            cell.questioned = false;
                            cell.safeQuestioned = true;
                        } else {
                            cell.questioned = false;
                        }
                    } else if (cell.safeQuestioned) {
                        cell.safeQuestioned = false;
                    }
                }
            }
        });
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

    // ---- MULTIPLAYER METHODS ----

    function sendMinesListToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return;
        }

        if (!GameState.mines || GameState.mines.length === 0) {
            console.error("Cannot send empty mines list");
            return;
        }

        // Create a clean array of mine positions
        const cleanMinesArray = GameState.mines.map(pos => Number(pos));

        // If mines array is small enough, send it as one packet
        if (cleanMinesArray.length <= 100) {  // Adjust this threshold as needed
            console.log("Sending mines list as single packet, count:", cleanMinesArray.length);

            const minesData = {
                gridSizeX: Number(GameState.gridSizeX),
                gridSizeY: Number(GameState.gridSizeY),
                mineCount: Number(GameState.mineCount),
                mines: cleanMinesArray,
                chunkIndex: 0,
                totalChunks: 1
            };

            SteamIntegration.sendGameState(minesData);
        } else {
            // For larger arrays, split into chunks
            const chunkSize = 50;  // Adjust chunk size as needed
            const totalChunks = Math.ceil(cleanMinesArray.length / chunkSize);

            console.log("Sending mines list in", totalChunks, "chunks, total mines:", cleanMinesArray.length);

            for (let i = 0; i < totalChunks; i++) {
                const startIndex = i * chunkSize;
                const endIndex = Math.min(startIndex + chunkSize, cleanMinesArray.length);
                const chunkArray = cleanMinesArray.slice(startIndex, endIndex);

                const chunkData = {
                    gridSizeX: Number(GameState.gridSizeX),
                    gridSizeY: Number(GameState.gridSizeY),
                    mineCount: Number(GameState.mineCount),
                    mines: chunkArray,
                    chunkIndex: i,
                    totalChunks: totalChunks,
                    isChunked: true
                };

                console.log("Sending chunk", i+1, "of", totalChunks, "size:", chunkArray.length);
                SteamIntegration.sendGameState(chunkData);

                // Small delay between chunks to prevent network congestion
                Qt.callLater(() => {});
            }
        }
    }

    function sendCellUpdateToClient(index, action) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return;
        }

        // If client isn't ready yet, queue initial actions
        if (!clientReadyForActions && action === "reveal") {
            console.log("Client not ready, queuing action:", action, index);
            pendingInitialActions.push({type: action, index: index});
            return;
        }

        console.log("Sending cell update:", index, action);
        SteamIntegration.sendGameAction(action, index);
    }

    function applyMinesAndCalculateNumbers(minesData) {
        console.log("Applying mines data and calculating numbers");

        // First check if we received valid data
        if (!minesData || !minesData.mines) {
            console.error("Received invalid mines data");
            return false;
        }

        // Update grid dimensions if needed
        if (GameState.gridSizeX !== minesData.gridSizeX ||
            GameState.gridSizeY !== minesData.gridSizeY) {
            console.log("Grid size changed:", minesData.gridSizeX, "x", minesData.gridSizeY);
            GameState.gridSizeX = Number(minesData.gridSizeX);
            GameState.gridSizeY = Number(minesData.gridSizeY);
        }

        // IMPORTANT: Extract mines with more robust methods
        let cleanMinesArray = [];

        console.log("Raw mines data:", JSON.stringify(minesData.mines));
        console.log("mines data type:", typeof minesData.mines);

        // More robust extraction method
        try {
            if (Array.isArray(minesData.mines)) {
                console.log("mines is a proper Array with length:", minesData.mines.length);
                cleanMinesArray = minesData.mines.map(Number);
            } else if (typeof minesData.mines === 'string') {
                // Try to parse if it's a JSON string
                console.log("mines is a string, trying to parse");
                const parsed = JSON.parse(minesData.mines);
                if (Array.isArray(parsed)) {
                    cleanMinesArray = parsed.map(Number);
                }
            } else if (typeof minesData.mines === 'object' && minesData.mines !== null) {
                console.log("mines is an object with keys:", Object.keys(minesData.mines));

                // Check if it's an array-like object with numeric keys and a 'length' property
                if (minesData.mines.hasOwnProperty('length') && typeof minesData.mines.length === 'number') {
                    console.log("mines has length property:", minesData.mines.length);
                    // Convert array-like object to array
                    for (let i = 0; i < minesData.mines.length; i++) {
                        if (minesData.mines[i] !== undefined) {
                            cleanMinesArray.push(Number(minesData.mines[i]));
                        }
                    }
                } else {
                    // Try to extract values from object properties
                    for (let key in minesData.mines) {
                        if (minesData.mines.hasOwnProperty(key) && !isNaN(Number(minesData.mines[key]))) {
                            cleanMinesArray.push(Number(minesData.mines[key]));
                        }
                    }
                }
            }
        } catch (e) {
            console.error("Error extracting mines:", e);
        }

        // One last attempt - try direct property access if we have nothing yet
        if (cleanMinesArray.length === 0 && minesData.mines) {
            console.log("Trying direct property access");
            try {
                // Check if mines has a property "0", "1", etc. (array-like object)
                for (let i = 0; i < 100; i++) { // Try up to 100 potential mines
                    if (minesData.mines[i] !== undefined) {
                        cleanMinesArray.push(Number(minesData.mines[i]));
                    }
                }
            } catch (e) {
                console.error("Error in direct property access:", e);
            }
        }

        if (cleanMinesArray.length === 0) {
            console.error("Failed to extract any valid mine positions");
            return false;
        }

        console.log("Extracted clean mines array, length:", cleanMinesArray.length);
        console.log("Mine positions:", cleanMinesArray);

        // CRITICAL: Update the game state with our clean array
        GameState.mineCount = Number(minesData.mineCount) || cleanMinesArray.length;
        GameState.mines = cleanMinesArray;

        // Calculate numbers using our clean mines array
        try {
            // Make sure we pass a proper QVector<int> to the C++ method
            const calculatedNumbers = GameLogic.calculateNumbersFromMines(
                Number(GameState.gridSizeX),
                Number(GameState.gridSizeY),
                cleanMinesArray
            );

            // Verify the numbers
            if (calculatedNumbers && calculatedNumbers.length === GameState.gridSizeX * GameState.gridSizeY) {
                GameState.numbers = calculatedNumbers;
                console.log("Numbers calculated successfully, length:", calculatedNumbers.length);
            } else {
                console.error("Invalid numbers calculated, expected length:",
                             GameState.gridSizeX * GameState.gridSizeY,
                             "got:", calculatedNumbers ? calculatedNumbers.length : 0);
                return false;
            }
        } catch (e) {
            console.error("Error calculating numbers:", e);
            return false;
        }

        // Mark game as started
        GameState.gameStarted = true;

        // Indicate success
        const success = true;

        // If successful, and we're a client, send acknowledgment to host
        if (success && SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            // Mark that we have initialized mines
            minesInitialized = true;

            // Acknowledge to host that we're ready for actions
            console.log("Client sending readyForActions acknowledgment to host");
            SteamIntegration.sendGameAction("readyForActions", 0);

            // Process any pending actions
            if (pendingActions.length > 0) {
                console.log("Processing", pendingActions.length, "buffered actions");
                // Use setTimeout to process after current function finishes
                Qt.callLater(function() {
                    pendingActions.forEach(function(action) {
                        console.log("Processing buffered action:", action.type, action.index);
                        handleNetworkAction(action.type, action.index);
                    });
                    pendingActions = [];
                });
            }
        }

        return success;
    }

    // Process game actions received from network
    function handleNetworkAction(actionType, cellIndex) {
        console.log("Received action:", actionType, "for cell:", cellIndex);

        if (SteamIntegration.isHost) {
            // Host receives action from client
            if (actionType === "gridReady") {
                console.log("Host received grid ready notification from client");
                clientGridReady = true;
                // No need to send response, just update the flag
                return;
            } else if (actionType === "reveal") {
                console.log("Host processing reveal action for cell:", cellIndex);
                performReveal(cellIndex);
                // Send individual cell update back to client
                sendCellUpdateToClient(cellIndex, "reveal");
            } else if (actionType === "flag") {
                console.log("Host processing flag action for cell:", cellIndex);
                performToggleFlag(cellIndex);
                sendCellUpdateToClient(cellIndex, "flag");
            } else if (actionType === "revealConnected") {
                console.log("Host processing revealConnected action for cell:", cellIndex);
                performRevealConnectedCells(cellIndex);
                sendCellUpdateToClient(cellIndex, "revealConnected");
            } else if (actionType === "requestSync") {
                console.log("Client requested full sync, sending mines list");
                sendMinesListToClient();
            } else if (actionType === "readyForActions") {
                console.log("Host received client readiness confirmation");
                clientReadyForActions = true;

                // Now we can send any pending initial actions
                if (pendingInitialActions.length > 0) {
                    console.log("Sending", pendingInitialActions.length, "pending initial actions");
                    pendingInitialActions.forEach(function(action) {
                        sendCellUpdateToClient(action.index, action.type);
                    });
                    pendingInitialActions = [];
                }
            } else if (actionType === "requestMines") {
                console.log("Client requested mines data, sending immediately");
                sendMinesListToClient();

                // After a moment, check if client has processed mines
                Qt.callLater(function() {
                    console.log("Checking if client has processed mines");
                    SteamIntegration.sendGameAction("minesReady", 0);
                });
            } else if (actionType === "requestHint") {
                console.log("Host processing hint request from client");
                processHintRequest();
                // The actual hint cell is sent back in processHintRequest
            } // For the host case in handleNetworkAction (around line 4016)
            // Add this after the requestHint case:
            else if (actionType === "ping") {
                console.log("Host received ping at cell:", cellIndex);
                // Just show the ping locally and relay back to other clients if needed
                showPingAtCell(cellIndex);
            }
        } else {
            // Client receives action from host
            if (actionType === "minesReady") {
                // Check if we already have mines data
                if (minesInitialized) {
                    console.log("Client confirms mines data is ready");
                    // Send acknowledgment to host that we're ready for actions
                    SteamIntegration.sendGameAction("readyForActions", 0);
                } else {
                    console.log("Client received mines readiness check but mines not initialized");
                    // Request mines data directly
                    SteamIntegration.sendGameAction("requestMines", 0);
                }
                return;
            }

            if (!minesInitialized && actionType !== "gameOver" && actionType !== "startGame") {
                // Buffer actions until mines data is received
                console.log("Buffering action until mines data is received:", actionType, cellIndex);
                pendingActions.push({type: actionType, index: cellIndex});
                isProcessingNetworkAction = false;
                return;
            }

            if (actionType === "finalReveal") {
                console.log("Client processing final reveal action for cell:", cellIndex);
                // For final reveals, we need to force reveal the cell
                withCell(cellIndex, function(cell) {
                    if (!cell.revealed) {
                        cell.revealed = true;
                        // Force the button to be flat without animation
                        cell.shouldBeFlat = true;
                        if (cell.button) {
                            cell.button.flat = true;
                            cell.button.opacity = 1;
                        }

                        // Update the bomb state if needed
                        if (GameState.mines.includes(cellIndex)) {
                            cell.isBombClicked = true;
                        }

                        GameState.revealedCount++;
                    }
                });
            } else if (actionType === "reveal") {
                console.log("Client processing reveal action for cell:", cellIndex);
                performReveal(cellIndex);
                allowClientReveal = true
            } else if (actionType === "flag") {
                console.log("Client processing flag action for cell:", cellIndex);
                performToggleFlag(cellIndex);
            } else if (actionType === "revealConnected") {
                console.log("Client processing revealConnected action for cell:", cellIndex);
                performRevealConnectedCells(cellIndex);
            } else if (actionType === "startGame") {
                console.log("Client received start game command from host")
                ComponentsContext.multiplayerPopupVisible = false
            } else if (actionType === "gameOver") {
                console.log("Client processing gameOver action, win status:", cellIndex);
                // Handle game over state
                GameState.gameOver = true;
                GameState.gameWon = cellIndex === 1; // 1 for win, 0 for loss
                GameTimer.stop();

                if (GameState.gameWon) {
                    if (audioEngine) audioEngine.playWin();
                } else {
                    if (audioEngine) audioEngine.playLoose();
                    revealAllMines();
                }

                GameState.displayPostGame = true;
            } else if (actionType === "resetGame") {
                console.log("Client received game reset notification");

                // Reset client-side state
                minesInitialized = false;
                allowClientReveal = false;
                pendingActions = [];
                isProcessingNetworkAction = false;
                GameState.mines = [];
                GameState.numbers = [];
                GameState.gameOver = false;
                GameState.gameStarted = false;
                GameState.revealedCount = 0;
                GameState.flaggedCount = 0;

                // Reset all grid cells
                for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                    withCell(i, function(cell) {
                        cell.revealed = false;
                        cell.flagged = false;
                        cell.questioned = false;
                        cell.safeQuestioned = false;
                    });
                }

                // Start grid reset animation if enabled
                if (GameSettings.animations && !GameState.difficultyChanged) {
                    for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                        withCell(i, function(cell) {
                            cell.startGridResetAnimation();
                        });
                    }
                }
                GameState.displayPostGame = false
                // Request sync from host
                Qt.callLater(function() {
                    requestFullSync();
                });
            } else if (actionType === "unlockCoopAchievement") {
                console.log("Client received coop achievement unlock notification");
                if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                    const difficulty = GameState.getDifficultyLevel();
                    if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
                        SteamIntegration.unlockAchievement("ACH_WIN_COOP");
                    }
                }
            } else if (actionType === "sendHint") {
                console.log("Client received hint for cell:", cellIndex);
                withCell(cellIndex, function(cell) {
                    cell.highlightHint();
                });
                GameState.currentHintCount++;
                isProcessingNetworkAction = false;
            } else if (actionType === "ping") {
                console.log("Client received ping at cell:", cellIndex);
                showPingAtCell(cellIndex);
                isProcessingNetworkAction = false;
            }

            // Action finished processing
            isProcessingNetworkAction = false;
        }
    }

    // Then replace the current applyGameState function with this:
    function applyGameState(gameState) {
        console.log("Applying received game state");

        // First check if we received valid data
        if (!gameState) {
            console.error("Received invalid game state");
            isProcessingNetworkAction = false;
            return;
        }

        // Check if this is a chunked mines data packet
        if (gameState.isChunked) {
            console.log("Received chunked mines data - chunk " + (gameState.chunkIndex + 1) + " of " + gameState.totalChunks);

            // If this is the first chunk, reset our arrays and counters
            if (gameState.chunkIndex === 0) {
                chunkedMines = [];
                receivedChunks = 0;
                expectedTotalChunks = gameState.totalChunks;
            }

            // Add this chunk's mines to our array
            if (Array.isArray(gameState.mines)) {
                chunkedMines = chunkedMines.concat(gameState.mines.map(Number));
            } else if (typeof gameState.mines === 'object' && gameState.mines !== null) {
                // Handle object-style array if needed
                for (let prop in gameState.mines) {
                    if (!isNaN(parseInt(prop))) {
                        chunkedMines.push(Number(gameState.mines[prop]));
                    }
                }
            }

            receivedChunks++;
            console.log("Chunk received, now have " + receivedChunks + " of " + expectedTotalChunks + " chunks");

            // If we've received all expected chunks, process the complete mines data
            if (receivedChunks === expectedTotalChunks) {
                console.log("All chunks received, processing " + chunkedMines.length + " mines");

                // Create a complete mines data object
                const completeData = {
                    gridSizeX: Number(gameState.gridSizeX),
                    gridSizeY: Number(gameState.gridSizeY),
                    mineCount: Number(gameState.mineCount),
                    mines: chunkedMines
                };

                // Process the complete mines data
                const success = applyMinesAndCalculateNumbers(completeData);

                if (success) {
                    // Mark that we have initialized mines
                    minesInitialized = true;

                    // Send acknowledgment to host that we're ready for actions
                    console.log("Client sending readyForActions acknowledgment to host");
                    SteamIntegration.sendGameAction("readyForActions", 0);

                    // Process any pending actions
                    if (pendingActions.length > 0) {
                        console.log("Processing", pendingActions.length, "buffered actions");
                        Qt.callLater(function() {
                            pendingActions.forEach(function(action) {
                                console.log("Processing buffered action:", action.type, action.index);
                                handleNetworkAction(action.type, action.index);
                            });
                            pendingActions = [];
                        });
                    }
                }
            }
            return;
        }

        // Check if this is a mines-only packet (initial board setup)
        if (gameState.mines && !gameState.revealedCells && !gameState.numbers) {
            console.log("Received mines-only data - initializing board");

            // Process mines and calculate numbers locally
            const success = applyMinesAndCalculateNumbers(gameState);

            if (success) {
                // Mark that we have initialized mines
                minesInitialized = true;

                // Acknowledge to host that we're ready for actions
                console.log("Client sending readyForActions acknowledgment to host");
                SteamIntegration.sendGameAction("readyForActions", 0);

                // Process any pending actions
                if (pendingActions.length > 0) {
                    console.log("Processing", pendingActions.length, "buffered actions");
                    // Use setTimeout to process after current function finishes
                    Qt.callLater(function() {
                        pendingActions.forEach(function(action) {
                            console.log("Processing buffered action:", action.type, action.index);
                            handleNetworkAction(action.type, action.index);
                        });
                        pendingActions = [];
                    });
                }
            }
            return;
        }

        // If it's a full game state (for backward compatibility or initial sync)
        if (gameState.mines && gameState.numbers) {
            console.log("Received full game state");

            // Check if grid dimensions match
            if (GameState.gridSizeX !== gameState.gridSizeX ||
                GameState.gridSizeY !== gameState.gridSizeY) {
                console.log("Grid size changed:", gameState.gridSizeX, "x", gameState.gridSizeY);

                // Update grid dimensions
                GameState.gridSizeX = gameState.gridSizeX;
                GameState.gridSizeY = gameState.gridSizeY;
                GameState.mineCount = gameState.mineCount || 0;

                // Update difficulty setting to match the new dimensions
                let matchedDifficulty = -1;

                // Check against standard difficulty settings
                for (let i = 0; i < 4; i++) {
                    const diffSet = GameState.difficultySettings[i];
                    if (diffSet.x === GameState.gridSizeX &&
                        diffSet.y === GameState.gridSizeY &&
                        diffSet.mines === GameState.mineCount) {
                        matchedDifficulty = i;
                        break;
                    }
                }

                if (matchedDifficulty >= 0) {
                    // Standard difficulty found
                    console.log("Setting difficulty to match received dimensions:", matchedDifficulty);
                    GameSettings.difficulty = matchedDifficulty;
                } else {
                    // No match, update custom settings
                    console.log("Setting custom difficulty for received dimensions");
                    GameSettings.customWidth = GameState.gridSizeX;
                    GameSettings.customHeight = GameState.gridSizeY;
                    GameSettings.customMines = GameState.mineCount;
                    GameSettings.difficulty = 4; // Custom difficulty index
                }

                // We need to wait for the grid to be recreated
                // This is handled in Main.qml via the grid size change signals
                return;
            }

            // Process mines array
            let minesArray = convertObjectToArray(gameState.mines, "mines");
            GameState.mines = minesArray;
            console.log("Mines array length:", GameState.mines.length);

            // Process numbers array
            let numbersArray = convertObjectToArray(gameState.numbers, "numbers");
            GameState.numbers = numbersArray;
            console.log("Numbers array length:", GameState.numbers.length);

            // Update other game state
            GameState.mineCount = gameState.mineCount || 0;
            GameState.gameStarted = gameState.gameStarted || false;

            // Reset all cells first
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                withCell(i, function(cell) {
                    cell.revealed = false;
                    cell.flagged = false;
                    cell.questioned = false;
                    cell.safeQuestioned = false;
                });
            }

            // Process cell states
            let revealedCellsArray = convertObjectToArray(gameState.revealedCells, "revealedCells");
            let flaggedCellsArray = convertObjectToArray(gameState.flaggedCells, "flaggedCells");
            let questionedCellsArray = convertObjectToArray(gameState.questionedCells, "questionedCells");
            let safeQuestionedCellsArray = convertObjectToArray(gameState.safeQuestionedCells, "safeQuestionedCells");

            // Apply revealed cells
            console.log("Applying", revealedCellsArray.length, "revealed cells");
            revealedCellsArray.forEach(index => {
                withCell(index, function(cell) {
                    // Skip animation for client
                    if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                        // For client, we need to set both the revealed flag and directly update the button
                        cell.revealed = true;
                        cell.shouldBeFlat = true;

                        // Force buttons to be flat without animation
                        try {
                            cell.button.flat = true;
                            cell.button.opacity = 1;
                        } catch (e) {
                            console.error("Error setting button flat:", e);
                        }
                    } else {
                        cell.revealed = true;
                    }
                });
            });

            // Apply flagged cells
            flaggedCellsArray.forEach(index => {
                withCell(index, function(cell) {
                    cell.flagged = true;
                });
            });

            // Apply questioned cells
            questionedCellsArray.forEach(index => {
                withCell(index, function(cell) {
                    cell.questioned = true;
                });
            });

            // Apply safe questioned cells
            safeQuestionedCellsArray.forEach(index => {
                withCell(index, function(cell) {
                    cell.safeQuestioned = true;
                });
            });

            // Update game state
            GameState.gameOver = gameState.gameOver || false;
            GameState.gameWon = gameState.gameWon || false;
            GameState.revealedCount = gameState.revealedCount || 0;
            GameState.flaggedCount = gameState.flaggedCount || 0;

            // Update display for game over
            if (GameState.gameOver) {
                GameState.displayPostGame = true;
                if (GameState.gameWon) {
                    if (audioEngine) audioEngine.playWin();
                } else {
                    if (audioEngine) audioEngine.playLoose();
                }
            }
        }

        // Finish processing
        isProcessingNetworkAction = false;
        console.log("Game state applied successfully");
    }

    // Legacy method for backward compatibility
    function sendGridStateToClient() {
        console.log("Legacy sendGridStateToClient called - using optimized approach instead");
        // Note: This method is left here for backward compatibility, but now
        // we use the more targeted approaches above
    }

    function requestFullSync() {
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            return; // Only clients should request sync
        }

        console.log("Client requesting full sync from host");
        SteamIntegration.sendGameAction("requestSync", 0);
    }

    // Add this call at the end of performReveal on the client side if it detects an issue
    function verifyClientState() {
        // Only run on clients
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            return true;
        }

        // Check if we have valid mine and number data
        if (!GameState.mines || GameState.mines.length === 0 ||
            !GameState.numbers || GameState.numbers.length === 0 ||
            GameState.mines.length > GameState.gridSizeX * GameState.gridSizeY) {
            console.error("Client has invalid game state - requesting sync");
            requestFullSync();
            return false;
        }

        return true;
    }

    function prepareMultiplayerGrid(gridX, gridY, mineCount) {
        console.log("Preparing multiplayer grid:", gridX, "x", gridY, "mines:", mineCount);

        // Only reset cellsCreated if grid dimensions have changed
        if (GameState.gridSizeX !== gridX || GameState.gridSizeY !== gridY) {
            console.log("Grid dimensions changed - resetting cellsCreated counter");
            cellsCreated = 0;
        } else {
            console.log("Grid dimensions unchanged - keeping existing cells");
        }

        // Update grid dimensions and mine count
        GameState.gridSizeX = gridX;
        GameState.gridSizeY = gridY;
        GameState.mineCount = mineCount;

        // Mark this as a multiplayer game setup
        GameState.difficultyChanged = true;
    }

    function handleMultiplayerGridSync(data) {
        console.log("Received multiplayer grid sync data:", JSON.stringify(data));

        // Check if we need to resize the grid
        let gridNeedsRecreation = (GameState.gridSizeX !== data.gridSizeX ||
                                  GameState.gridSizeY !== data.gridSizeY);

        // Prepare the grid with received parameters
        prepareMultiplayerGrid(
            data.gridSizeX,
            data.gridSizeY,
            data.mineCount
        );

        // Update difficulty setting to match the new dimensions
        let matchedDifficulty = -1;

        // Check against standard difficulty settings
        for (let i = 0; i < 4; i++) {
            const diffSet = GameState.difficultySettings[i];
            if (diffSet.x === data.gridSizeX &&
                diffSet.y === data.gridSizeY &&
                diffSet.mines === data.mineCount) {
                matchedDifficulty = i;
                break;
            }
        }

        if (matchedDifficulty >= 0) {
            // Standard difficulty found
            console.log("Setting difficulty to match received dimensions:", matchedDifficulty);
            GameSettings.difficulty = matchedDifficulty;
        } else {
            // No match, update custom settings
            console.log("Setting custom difficulty for received dimensions");
            GameSettings.customWidth = data.gridSizeX;
            GameSettings.customHeight = data.gridSizeY;
            GameSettings.customMines = data.mineCount;
            GameSettings.difficulty = 4; // Custom difficulty index
        }

        // Send acknowledgment back to host
        if (!SteamIntegration.isHost) {
            SteamIntegration.sendGameAction("gridSyncAck", 0);

            // If grid dimensions are the same and cells are already created,
            // we can immediately notify that we're ready
            if (!gridNeedsRecreation && GridBridge.cellsCreated === (data.gridSizeX * data.gridSizeY)) {
                console.log("Grid already matches expected size, sending ready immediately");
                Qt.callLater(notifyGridReady);
            }
        }
    }

    function notifyGridReady() {
        if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            console.log("Client notifying host that grid is ready");
            SteamIntegration.sendGameAction("gridReady", 0);
        }
    }

    function sendPing(cellIndex) {
        if (!GameState.gameStarted) {
            return;
        }

        if (SteamIntegration.isInMultiplayerGame) {
            console.log("Sending ping for cell:", cellIndex);
            SteamIntegration.sendGameAction("ping", cellIndex);
        }

        showPingAtCell(cellIndex);
    }

    function showPingAtCell(cellIndex) {
        if (cellIndex < 0 || cellIndex >= GameState.gridSizeX * GameState.gridSizeY) {
            console.error("Invalid cell index for ping:", cellIndex);
            return;
        }

        const cell = getCell(cellIndex);
        if (!cell) {
            console.error("Cannot find cell for ping:", cellIndex);
            return;
        }

        // Create ping indicator dynamically
        const pingComponent = Qt.createComponent("../PingIndicator.qml");
        if (pingComponent.status === Component.Ready) {
            const pingObject = pingComponent.createObject(cell, {
                "anchors.centerIn": cell
            });

            // Auto-destroy after animation completes (3s total duration of animation)
            const pingTimer = Qt.createQmlObject(
                'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                cell, "pingTimer");

            pingTimer.triggered.connect(function() {
                pingObject.destroy();
                pingTimer.destroy();
            });
        } else {
            console.error("Error creating ping indicator:", pingComponent.errorString());
        }
    }
}
