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

    Component.onCompleted: {
        // Connect to SteamIntegration signals for multiplayer
        SteamIntegration.gameActionReceived.connect(handleNetworkAction);
        SteamIntegration.gameStateReceived.connect(applyGameState);
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
        // Disable hints in multiplayer
        if (SteamIntegration.isInMultiplayerGame) {
            console.log("Hints are disabled in multiplayer mode");
            return;
        }

        if (!GameState.gameStarted || GameState.gameOver) {
            return;
        }

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
                // We're host: process locally and then sync
                performRevealConnectedCells(index);
                sendGridStateToClient();
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

    // Callback function for board generation
    // Defined at the object level to be easily disconnected later
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

            // In multiplayer, if we're the host, send updated state to client
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                sendGridStateToClient();
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
                // We're host: process locally and then sync
                performReveal(index);
                sendGridStateToClient();
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

            // Disable leaderboard updates in multiplayer
            if (!SteamIntegration.isInMultiplayerGame) {
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
            }

            GameState.displayPostGame = true;
            if (audioEngine) audioEngine.playWin();

            // In multiplayer, if we're the host, send updated state to client
            if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                sendGridStateToClient();
            }
        } else {
            if (audioEngine) audioEngine.playClick();
        }
    }

    function toggleFlag(index) {
        // Check if we're in multiplayer
        if (SteamIntegration.isInMultiplayerGame) {
            if (SteamIntegration.isHost) {
                // We're host: process locally and then sync
                performToggleFlag(index);
                sendGridStateToClient();
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

    // Process game actions received from network
    function handleNetworkAction(actionType, cellIndex) {
        console.log("Received action:", actionType, "for cell:", cellIndex);

        if (!SteamIntegration.isHost) {
            console.warn("Client received action request but is not host!");
            return;
        }

        if (actionType === "reveal") {
            performReveal(cellIndex);
        } else if (actionType === "flag") {
            performToggleFlag(cellIndex);
        } else if (actionType === "revealConnected") {
            performRevealConnectedCells(cellIndex);
        }

        // Send updated state back to client
        sendGridStateToClient();
    }

    // Called when the host needs to send current grid state to client
    function sendGridStateToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            console.log("Not sending grid state: not in multiplayer or not host");
            return;
        }

        console.log("Sending grid state to client");

        // Build a state object with all necessary grid information
        var gameState = {
            gridSizeX: GameState.gridSizeX,
            gridSizeY: GameState.gridSizeY,
            mineCount: GameState.mineCount,
            // More robust array conversion
            mines: (function() {
                if (!GameState.mines) return [];
                if (Array.isArray(GameState.mines)) return Array.from(GameState.mines);
                // Try to convert object to array
                let result = [];
                for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                    if (GameState.mines[i] !== undefined) result.push(i);
                }
                return result;
            })(),
            numbers: (function() {
                if (!GameState.numbers) return [];
                if (Array.isArray(GameState.numbers)) return Array.from(GameState.numbers);
                // Try to convert object to array
                let result = [];
                for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                    result[i] = GameState.numbers[i] || 0;
                }
                return result;
            })(),
            revealedCells: [],
            flaggedCells: [],
            questionedCells: [],
            safeQuestionedCells: [],
            gameOver: GameState.gameOver,
            gameWon: GameState.gameWon,
            revealedCount: GameState.revealedCount,
            flaggedCount: GameState.flaggedCount,
            gameStarted: GameState.gameStarted
        };

        // Collect current cell states
        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = getCell(i);
            if (!cell) continue;

            if (cell.revealed) gameState.revealedCells.push(i);
            if (cell.flagged) gameState.flaggedCells.push(i);
            if (cell.questioned) gameState.questionedCells.push(i);
            if (cell.safeQuestioned) gameState.safeQuestionedCells.push(i);
        }

        console.log("SENDING STATE: Mines array type:", typeof GameState.mines);
        console.log("SENDING STATE: Mines array isArray:", Array.isArray(GameState.mines));
        console.log("SENDING STATE: Mines array length:", GameState.mines ? GameState.mines.length : "N/A");
        console.log("SENDING STATE: Numbers array type:", typeof GameState.numbers);
        console.log("SENDING STATE: Numbers array isArray:", Array.isArray(GameState.numbers));
        console.log("SENDING STATE: Numbers array length:", GameState.numbers ? GameState.numbers.length : "N/A");

        // Send the state
        SteamIntegration.sendGameState(gameState);
    }

    // Called when the client receives a game state update from host
    function applyGameState(gameState) {
        console.log("Applying received game state");

        console.log("RECEIVING STATE: Mines array type:", typeof gameState.mines);
        console.log("RECEIVING STATE: Mines array isArray:", Array.isArray(gameState.mines));
        console.log("RECEIVING STATE: Mines array length:", gameState.mines ? gameState.mines.length : "N/A");
        console.log("RECEIVING STATE: Numbers array type:", typeof gameState.numbers);
        console.log("RECEIVING STATE: Numbers array isArray:", Array.isArray(gameState.numbers));
        console.log("RECEIVING STATE: Numbers array length:", gameState.numbers ? gameState.numbers.length : "N/A");

        // First check if we received valid data
        if (!gameState) {
            console.error("Received invalid game state");
            isProcessingNetworkAction = false;
            return;
        }

        // Check if grid dimensions match
        if (GameState.gridSizeX !== gameState.gridSizeX ||
            GameState.gridSizeY !== gameState.gridSizeY) {
            console.log("Grid size changed:", gameState.gridSizeX, "x", gameState.gridSizeY);

            // Grid size changed, need to resize
            GameState.gridSizeX = gameState.gridSizeX;
            GameState.gridSizeY = gameState.gridSizeY;

            // We need to wait for the grid to be recreated
            // This is handled in Main.qml via the grid size change signals
            return;
        }

        // Better deserialization
        if (gameState.mines) {
            if (Array.isArray(gameState.mines)) {
                console.log("Updating mines array as array, length:", gameState.mines.length);
                GameState.mines = Array.from(gameState.mines); // Ensure proper array conversion
            } else {
                console.log("Received mines as object, converting");
                // Try to convert from object
                let minesArray = [];
                for (let prop in gameState.mines) {
                    if (!isNaN(parseInt(prop))) {
                        minesArray.push(parseInt(gameState.mines[prop]));
                    }
                }
                GameState.mines = minesArray;
            }
            console.log("Final mines array length:", GameState.mines.length);
        } else {
            console.error("Received no mines data");
            GameState.mines = [];
        }

        if (Array.isArray(gameState.numbers)) {
            console.log("Updating numbers array, length:", gameState.numbers.length);
            GameState.numbers = gameState.numbers.slice(); // Create a copy of the array
        } else {
            console.error("Received invalid numbers array");
            GameState.numbers = [];
        }

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

        // Apply cell states from received data
        if (Array.isArray(gameState.revealedCells)) {
            gameState.revealedCells.forEach(index => {
                withCell(index, function(cell) {
                    cell.revealed = true;
                });
            });
        }

        if (Array.isArray(gameState.flaggedCells)) {
            gameState.flaggedCells.forEach(index => {
                withCell(index, function(cell) {
                    cell.flagged = true;
                });
            });
        }

        if (Array.isArray(gameState.questionedCells)) {
            gameState.questionedCells.forEach(index => {
                withCell(index, function(cell) {
                    cell.questioned = true;
                });
            });
        }

        if (Array.isArray(gameState.safeQuestionedCells)) {
            gameState.safeQuestionedCells.forEach(index => {
                withCell(index, function(cell) {
                    cell.safeQuestioned = true;
                });
            });
        }

        // Update game state
        GameState.gameOver = gameState.gameOver || false;
        GameState.gameWon = gameState.gameWon || false;
        GameState.revealedCount = gameState.revealedCount || 0;
        GameState.flaggedCount = gameState.flaggedCount || 0;

        // Finish processing
        isProcessingNetworkAction = false;

        console.log("Game state applied successfully");

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
}
