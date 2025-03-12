pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

QtObject {
    id: networkManager

    // Session and connection state properties
    property bool isProcessingNetworkAction: false
    property var pendingActions: []
    property bool minesInitialized: false
    property bool clientReadyForActions: false
    property var pendingInitialActions: []
    property bool clientGridReady: false
    property bool sessionRunning: false
    property bool mpPopupCloseButtonVisible: false
    property bool allowClientReveal: false
    property var chunkResendTimer: null

    // Grid synchronization properties
    property var chunkedMines: []
    property int receivedChunks: 0
    property int expectedTotalChunks: 0

    // Player information
    property string hostName: SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName
    property string clientName: !SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName

    // Reconnection properties
    property bool isReconnecting: false
    property bool preserveGameStateOnDisconnect: true
    property int lastKnownRevealedCount: 0
    property int lastKnownFlaggedCount: 0

    // Error handling
    property var lastSyncError: null
    property int syncErrorCount: 0
    property int maxConsecutiveSyncErrors: 3

    // Connection monitoring
    property bool connectionIsHealthy: SteamIntegration.connectionState === SteamIntegration.Connected

    // Initialize the network manager
    Component.onCompleted: {
        // Connect to Steam integration signals
        SteamIntegration.gameActionReceived.connect(handleNetworkAction);
        SteamIntegration.gameStateReceived.connect(applyGameState);

        // Monitor multiplayer status changes
        SteamIntegration.multiplayerStatusChanged.connect(function() {
            if (!SteamIntegration.isInMultiplayerGame) {
                clientGridReady = false;
                resetMultiplayerState();
            }
        });

        // Monitor connection state changes
        SteamIntegration.connectionStateChanged.connect(function(state) {
            if (state === SteamIntegration.Connected) {
                connectionIsHealthy = true;
            } else if (state === SteamIntegration.Unstable) {
                connectionIsHealthy = false;
            } else if (state === SteamIntegration.Disconnected) {
                connectionIsHealthy = false;

                // Handle disconnection (specific game logic)
                if (preserveGameStateOnDisconnect && GameState.gameStarted && !GameState.gameOver) {
                    // Save the current game state for potential reconnection
                    lastKnownRevealedCount = GameState.revealedCount;
                    lastKnownFlaggedCount = GameState.flaggedCount;
                }
            } else if (state === SteamIntegration.Reconnecting) {
                connectionIsHealthy = false;
                isReconnecting = true;
            }
        });

        // Handle reconnection results
        SteamIntegration.reconnectionSucceeded.connect(function() {
            isReconnecting = false;
            connectionIsHealthy = true;

            // If we're the host, send updated game state to the client
            if (SteamIntegration.isHost && GameState.gameStarted) {
                sendMinesListToClient();
            }
        });

        SteamIntegration.reconnectionFailed.connect(function() {
            isReconnecting = false;
            connectionIsHealthy = false;
        });

        // Monitor lobby readiness
        SteamIntegration.lobbyReadyChanged.connect(function() {
            if (SteamIntegration.isLobbyReady && SteamIntegration.isHost) {
                syncGridSettingsToClient();
            }
        });
    }

    // Grid synchronization - Send grid settings from host to client
    function syncGridSettingsToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return;
        }

        // Get current host's difficulty settings
        const difficultySet = GameState.difficultySettings[GameSettings.difficulty];

        // Prepare grid sync data packet
        const gridSyncData = {
            gridSync: true,
            gridSizeX: difficultySet.x,
            gridSizeY: difficultySet.y,
            mineCount: difficultySet.mines,
            syncTimestamp: new Date().getTime() // Add timestamp for sync tracking
        };

        SteamIntegration.sendGameState(gridSyncData);
    }

    // Array utility functions
    function convertObjectToArray(obj, name) {
        let resultArray = [];
        if (Array.isArray(obj)) {
            resultArray = Array.from(obj);
        } else if (typeof obj === 'object' && obj !== null) {
            // Convert object to array
            for (let prop in obj) {
                if (!isNaN(parseInt(prop))) {
                    resultArray.push(parseInt(obj[prop]));
                }
            }
        } else {
            console.error(name + " is empty or invalid");
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

    // Cell signaling (pinging) system
    function sendPing(cellIndex) {
        if (SteamIntegration.isInMultiplayerGame) {
            SteamIntegration.sendGameAction("ping", cellIndex);
        }

        showPingAtCell(cellIndex);
    }

    function showPingAtCell(cellIndex) {
        if (cellIndex < 0 || cellIndex >= GameState.gridSizeX * GameState.gridSizeY) {
            console.error("Invalid cell index for ping:", cellIndex);
            return;
        }

        const cell = GridBridge.getCell(cellIndex);
        if (!cell) {
            console.error("Cannot find cell for ping:", cellIndex);
            return;
        }

        // Create ping indicator dynamically
        const pingComponent = Qt.createComponent("../SignalIndicator.qml");
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

    // Grid preparation for multiplayer
    function prepareMultiplayerGrid(gridX, gridY, mineCount) {
        // Only reset cellsCreated if grid dimensions have changed
        if (GameState.gridSizeX !== gridX || GameState.gridSizeY !== gridY) {
            GridBridge.cellsCreated = 0;
        }

        // Update grid dimensions and mine count
        GameState.gridSizeX = gridX;
        GameState.gridSizeY = gridY;
        GameState.mineCount = mineCount;

        // Mark this as a multiplayer game setup
        GameState.difficultyChanged = true;
    }

    function handleMultiplayerGridSync(data) {
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
            GameSettings.difficulty = matchedDifficulty;
        } else {
            // No match, update custom settings
            GameSettings.customWidth = data.gridSizeX;
            GameSettings.customHeight = data.gridSizeY;
            GameSettings.customMines = data.mineCount;
            GameSettings.difficulty = 4; // Custom difficulty index
        }

        // Send acknowledgment back to host
        if (!SteamIntegration.isHost) {
            SteamIntegration.sendGameAction("gridSyncAck", data.syncTimestamp || 0);

            // If grid dimensions are the same and cells are already created,
            // we can immediately notify that we're ready
            if (!gridNeedsRecreation && GridBridge.cellsCreated === (data.gridSizeX * data.gridSizeY)) {
                Qt.callLater(notifyGridReady);
            }
        }
    }

    function notifyGridReady() {
        if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            SteamIntegration.sendGameAction("gridReady", 0);
        }
    }

    function sendCellUpdateToClient(index, action) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return;
        }

        // If client isn't ready yet, queue initial actions
        if (!clientReadyForActions && action === "reveal") {
            pendingInitialActions.push({type: action, index: index});
            return;
        }

        SteamIntegration.sendGameAction(action, index);
    }

    function resetMultiplayerState() {
        // Reset multiplayer flags
        minesInitialized = false;
        clientReadyForActions = false;
        pendingInitialActions = [];
        pendingActions = [];
        isProcessingNetworkAction = false;
        isReconnecting = false;
        syncErrorCount = 0;
        lastSyncError = null;

        // If we're the host and connected, notify clients about the reset
        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost &&
            SteamIntegration.connectionState === SteamIntegration.Connected) {
            SteamIntegration.sendGameAction("resetGame", 0);
        }
    }

    // Network message handling - Mines list
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
            const minesData = {
                gridSizeX: Number(GameState.gridSizeX),
                gridSizeY: Number(GameState.gridSizeY),
                mineCount: Number(GameState.mineCount),
                mines: cleanMinesArray,
                chunkIndex: 0,
                totalChunks: 1,
                syncTimestamp: new Date().getTime()
            };

            SteamIntegration.sendGameState(minesData);
        } else {
            // For larger arrays, split into chunks
            const chunkSize = 50;  // Adjust chunk size as needed
            const totalChunks = Math.ceil(cleanMinesArray.length / chunkSize);
            const syncTimestamp = new Date().getTime();

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
                    isChunked: true,
                    syncTimestamp: syncTimestamp
                };

                SteamIntegration.sendGameState(chunkData);

                // Small delay between chunks to prevent network congestion
                Qt.callLater(() => {});
            }
        }
    }

    function applyMinesAndCalculateNumbers(minesData) {
        // First check if we received valid data
        if (!minesData || !minesData.mines) {
            console.error("Received invalid mines data");
            lastSyncError = "Invalid mines data";
            syncErrorCount++;
            return false;
        }

        // Update grid dimensions if needed
        if (GameState.gridSizeX !== minesData.gridSizeX ||
                GameState.gridSizeY !== minesData.gridSizeY) {
            GameState.gridSizeX = Number(minesData.gridSizeX);
            GameState.gridSizeY = Number(minesData.gridSizeY);
        }

        // IMPORTANT: Extract mines with more robust methods
        let cleanMinesArray = [];

        // More robust extraction method
        try {
            if (Array.isArray(minesData.mines)) {
                cleanMinesArray = minesData.mines.map(Number);
            } else if (typeof minesData.mines === 'string') {
                // Try to parse if it's a JSON string
                const parsed = JSON.parse(minesData.mines);
                if (Array.isArray(parsed)) {
                    cleanMinesArray = parsed.map(Number);
                }
            } else if (typeof minesData.mines === 'object' && minesData.mines !== null) {
                // Check if it's an array-like object with numeric keys and a 'length' property
                if (minesData.mines.hasOwnProperty('length') && typeof minesData.mines.length === 'number') {
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
            lastSyncError = "Error extracting mines: " + e.toString();
            syncErrorCount++;
            return false;
        }

        // One last attempt - try direct property access if we have nothing yet
        if (cleanMinesArray.length === 0 && minesData.mines) {
            try {
                // Check if mines has a property "0", "1", etc. (array-like object)
                for (let i = 0; i < 1000; i++) { // Try up to 1000 potential mines
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
            lastSyncError = "No valid mine positions extracted";
            syncErrorCount++;
            return false;
        }

        // Validate the number of mines
        if (cleanMinesArray.length !== Number(minesData.mineCount)) {
            console.warn("Extracted mine count", cleanMinesArray.length,
                        "doesn't match expected mine count", minesData.mineCount);
            // But continue anyway, using the mines we found
        }

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
            } else {
                console.error("Invalid numbers calculated, expected length:",
                              GameState.gridSizeX * GameState.gridSizeY,
                              "got:", calculatedNumbers ? calculatedNumbers.length : 0);
                lastSyncError = "Invalid numbers calculated";
                syncErrorCount++;
                return false;
            }
        } catch (e) {
            console.error("Error calculating numbers:", e);
            lastSyncError = "Error calculating numbers: " + e.toString();
            syncErrorCount++;
            return false;
        }

        // Mark game as started
        GameState.gameStarted = true;

        // Reset sync error counter on success
        syncErrorCount = 0;
        lastSyncError = null;

        // Indicate success
        const success = true;

        // If successful, and we're a client, send acknowledgment to host
        if (success && SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            // Mark that we have initialized mines
            minesInitialized = true;

            // Acknowledge to host that we're ready for actions
            SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0);

            // Process any pending actions
            if (pendingActions.length > 0) {
                // Use setTimeout to process after current function finishes
                Qt.callLater(function() {
                    pendingActions.forEach(function(action) {
                        handleNetworkAction(action.type, action.index);
                    });
                    pendingActions = [];
                });
            }
        }

        return success;
    }

    function applyGameState(gameState) {
        if (!gameState) {
            console.error("Received invalid game state");
            lastSyncError = "Received invalid game state";
            syncErrorCount++;
            isProcessingNetworkAction = false;
            return;
        }

        if (gameState.gridSync) {
            handleMultiplayerGridSync(gameState);
            return;
        }

        if (gameState.isChunked) {
            handleChunkedMinesData(gameState);
            return;
        }

        if (gameState.mines && !gameState.revealedCells && !gameState.numbers) {
            processMinesData(gameState);
            return;
        }

        lastSyncError = "Unexpected game state format";
        syncErrorCount++;
        isProcessingNetworkAction = false;
    }

    function handleChunkedMinesData(gameState) {
        // Reset the chunk processing state if this is the first chunk
        if (gameState.chunkIndex === 0) {
            chunkedMines = [];
            receivedChunks = 0;
            expectedTotalChunks = gameState.totalChunks;

            // Also clear any previous resend timer
            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop();
                networkManager.chunkResendTimer.destroy();
                networkManager.chunkResendTimer = null;
            }
        }

        // More robust extraction of mines from the chunk
        try {
            if (Array.isArray(gameState.mines)) {
                chunkedMines = chunkedMines.concat(gameState.mines.map(Number));
            } else if (typeof gameState.mines === 'object' && gameState.mines !== null) {
                for (let prop in gameState.mines) {
                    if (!isNaN(parseInt(prop))) {
                        chunkedMines.push(Number(gameState.mines[prop]));
                    }
                }
            }
        } catch (e) {
            console.error("Error processing chunk:", e);
        }

        receivedChunks++;

        // Process complete chunk set
        if (receivedChunks === expectedTotalChunks) {
            // Cancel any pending resend timer
            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop();
                networkManager.chunkResendTimer.destroy();
                networkManager.chunkResendTimer = null;
            }

            const completeData = {
                gridSizeX: Number(gameState.gridSizeX),
                gridSizeY: Number(gameState.gridSizeY),
                mineCount: Number(gameState.mineCount),
                mines: chunkedMines,
                syncTimestamp: gameState.syncTimestamp
            };

            processMinesData(completeData);
        }
        // Set up chunk completion timeout - more aggressive with shorter timeout
        else if (receivedChunks < expectedTotalChunks) {
            // Cancel any existing resend timer
            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop();
                networkManager.chunkResendTimer.destroy();
                networkManager.chunkResendTimer = null;
            }

            // Create a timer to check if we've received all chunks
            networkManager.chunkResendTimer = Qt.createQmlObject(
                'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                Qt.application, "chunkResendTimer");

            networkManager.chunkResendTimer.triggered.connect(function() {
                if (receivedChunks < expectedTotalChunks) {
                    requestFullSync();
                }
            });
        }
    }

    function processMinesData(minesData) {
        const success = applyMinesAndCalculateNumbers(minesData);

        if (success) {
            minesInitialized = true;

            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0);

                if (pendingActions.length > 0) {
                    Qt.callLater(function() {
                        pendingActions.forEach(function(action) {
                            handleNetworkAction(action.type, action.index);
                        });
                        pendingActions = [];
                    });
                }
            }
        } else if (syncErrorCount >= maxConsecutiveSyncErrors) {
            console.error("Too many consecutive sync errors, requesting full sync");
            requestFullSync();
        }
    }

    function requestFullSync() {
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            return;
        }

        SteamIntegration.sendGameAction("requestSync", 0);
        // Reset sync error count after requesting a full sync
        syncErrorCount = 0;
    }

    function handleNetworkAction(actionType, parameter) {
        // Don't process network actions if we're not in multiplayer
        if (!SteamIntegration.isInMultiplayerGame) {
            return;
        }

        // Skip chat messages here (they're handled elsewhere)
        if (actionType === "chat") {
            return;
        }

        if (SteamIntegration.isHost) {
            handleHostAction(actionType, parameter);
        } else {
            handleClientAction(actionType, parameter);
        }
    }

    function handleHostAction(actionType, cellIndex) {
        switch(actionType) {
        case "gridReady":
            clientGridReady = true;
            break;

        case "reveal":
            GridBridge.performReveal(cellIndex);
            break;

        case "flag":
            handleMultiplayerToggleFlag(cellIndex, true); // true means client request
            break;

        case "revealConnected":
            GridBridge.performRevealConnectedCells(cellIndex);
            //sendCellUpdateToClient(cellIndex, "revealConnected");
            break;

        case "requestSync":
            sendMinesListToClient();
            break;

        case "readyForActions":
            clientReadyForActions = true;

            if (pendingInitialActions.length > 0) {
                pendingInitialActions.forEach(function(action) {
                    sendCellUpdateToClient(action.index, action.type);
                });
                pendingInitialActions = [];
            }
            break;

        case "requestMines":
            sendMinesListToClient();

            Qt.callLater(function() {
                SteamIntegration.sendGameAction("minesReady", 0);
            });
            break;

        case "requestHint":
            GridBridge.processHintRequest();
            break;

        case "ping":
            showPingAtCell(cellIndex);
            break;

        case "gridResetAck":
            break;

        case "gridSyncAck":
            break;

        case "testConnection":
            SteamIntegration.sendGameAction("connectionTestResponse", cellIndex);
            break;

        default:
            console.error("Host received unknown action type:", actionType);
        }
    }

    function handleClientAction(actionType, cellIndex) {
        // Special handling for mines readiness check
        if (actionType === "minesReady") {
            if (minesInitialized) {
                // Send acknowledgment to host that we're ready for actions
                SteamIntegration.sendGameAction("readyForActions", 0);
            } else {
                // Request mines data directly with a slight delay to avoid request flooding
                Qt.callLater(function() {
                    SteamIntegration.sendGameAction("requestMines", 0);
                });
            }
            return;
        }

        // For certain critical actions, we always process them even if mines aren't initialized
        let criticalActions = [
            "gameOver", "startGame", "resetMultiplayerGrid",
            "prepareDifficultyChange", "connectionTestResponse"
        ];

        // When mines aren't initialized yet, buffer most actions
        if (!minesInitialized && !criticalActions.includes(actionType)) {
            // Check if we already have this action buffered (avoid duplicates)
            let isDuplicate = false;
            for (let i = 0; i < pendingActions.length; i++) {
                if (pendingActions[i].type === actionType && pendingActions[i].index === cellIndex) {
                    isDuplicate = true;
                    break;
                }
            }

            if (!isDuplicate) {
                pendingActions.push({type: actionType, index: cellIndex, timestamp: Date.now()});

                // If we have too many pending actions, request mines data again
                if (pendingActions.length > 10) {
                    console.error("Too many pending actions, requesting mines data again");
                    SteamIntegration.sendGameAction("requestMines", 0);

                    // Limit the buffer size to prevent memory issues
                    if (pendingActions.length > 50) {
                        pendingActions = pendingActions.slice(-50);
                    }
                }
            }

            isProcessingNetworkAction = false;
            return;
        }

        // Process the action based on type
        switch(actionType) {
            case "flagDenied":
                // Host rejected our flag toggle because the cell is currently owned by the host
                console.log("Flag toggle denied on cell " + cellIndex);
                isProcessingNetworkAction = false;
                break;

            case "finalReveal":
                // For final reveals, we need to force reveal the cell
                GridBridge.withCell(cellIndex, function(cell) {
                    if (!cell.revealed) {
                        cell.revealed = true;
                        // Force the button to be flat without animation
                        cell.shouldBeFlat = true;
                        if (cell.button) {
                            cell.button.flat = true;
                            cell.button.opacity = 1;
                        }

                        // Update the bomb state if needed
                        if (NetworkManager.safeArrayIncludes(GameState.mines, cellIndex)) {
                            cell.isBombClicked = true;
                        }

                        GameState.revealedCount++;
                    }
                });
                break;

            case "reveal":
                try {
                    GridBridge.performReveal(cellIndex);
                    allowClientReveal = true;
                } catch (e) {
                    console.error("Error processing reveal action:", e);
                }
                break;

            case "flag":
                try {
                    GridBridge.performToggleFlag(cellIndex);
                } catch (e) {
                    console.error("Error processing flag action:", e);
                }
                break;

            case "revealConnected":
                try {
                    GridBridge.performRevealConnectedCells(cellIndex);
                } catch (e) {
                    console.error("Error processing revealConnected action:", e);
                }
                break;

            case "approveReveal":
                // Client processes the reveal and cascade locally
                allowClientReveal = true;
                GridBridge.performReveal(cellIndex);
                break;

            case "startGame":
                ComponentsContext.multiplayerPopupVisible = false;
                break;

            case "gameOver":
                // Handle game over state
                GameState.gameOver = true;
                GameState.gameWon = cellIndex === 1; // 1 for win, 0 for loss
                GameTimer.stop();

                if (GameState.gameWon) {
                    if (GridBridge.audioEngine) GridBridge.audioEngine.playWin();
                } else {
                    if (GridBridge.audioEngine) GridBridge.audioEngine.playLoose();
                    GridBridge.revealAllMines();
                }

                GameState.displayPostGame = true;
                break;

            case "resetGame":
                GameState.displayPostGame = false;
                GameState.difficultyChanged = false;

                // Reset client-side state
                minesInitialized = false;
                allowClientReveal = false;
                pendingActions = [];
                isProcessingNetworkAction = false;

                // Use the shared initialization code
                try {
                    GridBridge.performInitGame();
                } catch (e) {
                    console.error("Error resetting game:", e);
                    GridBridge.initGame(); // Fallback to standard init
                }
                break;

            case "unlockCoopAchievement":
                if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                    const difficulty = GameState.getDifficultyLevel();
                    if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
                        SteamIntegration.unlockAchievement("ACH_WIN_COOP");
                    }
                }
                break;

            case "sendHint":
                GridBridge.withCell(cellIndex, function(cell) {
                    if (cell && typeof cell.highlightHint === 'function') {
                        cell.highlightHint();
                    } else {
                        console.warn("Cannot highlight hint for cell", cellIndex);
                    }
                });
                GameState.currentHintCount++;
                isProcessingNetworkAction = false;
                break;

            case "ping":
                showPingAtCell(cellIndex);
                isProcessingNetworkAction = false;
                break;

            case "resetMultiplayerGrid":
                ComponentsContext.multiplayerPopupVisible = true;
                minesInitialized = false;
                clientReadyForActions = false;
                clientGridReady = false;
                allowClientReveal = false;
                pendingActions = [];
                isProcessingNetworkAction = false;

                GameState.difficultyChanged = true;
                GridBridge.initGame();

                SteamIntegration.sendGameAction("gridResetAck", 0);
                break;

            case "prepareDifficultyChange":
                // Validate difficulty index
                if (cellIndex >= 0 && cellIndex < GameState.difficultySettings.length) {
                    GameSettings.difficulty = cellIndex;

                    const difficultySet = GameState.difficultySettings[cellIndex];
                    GameState.gridSizeX = difficultySet.x;
                    GameState.gridSizeY = difficultySet.y;
                    GameState.mineCount = difficultySet.mines;
                    GameState.difficultyChanged = true;
                    GridBridge.cellsCreated = 0;

                    minesInitialized = false;
                    clientReadyForActions = false;
                    clientGridReady = false;
                    sessionRunning = false;
                    pendingActions = [];
                    isProcessingNetworkAction = false;

                    GridBridge.initGame();
                } else {
                    console.error("Received invalid difficulty index:", cellIndex);
                }
                break;

            case "connectionTestResponse":
                // This is just a ping-pong to test if the connection is alive
                break;

            default:
                console.error("Client received unknown action type:", actionType);
        }

        // Action finished processing
        isProcessingNetworkAction = false;
    }

    function handleMultiplayerReveal(index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        if (SteamIntegration.isHost) {
            // Host: check if valid reveal
            const cell = GridBridge.getCell(index);
            if (!cell || cell.revealed || cell.flagged) {
                // Invalid reveal
                return true;
            }

            // Process reveal locally
            GridBridge.performReveal(index);

            // Send approval to client (instead of reveal)
            SteamIntegration.sendGameAction("approveReveal", index);
        } else {
            // Client: send request to host
            SteamIntegration.sendGameAction("reveal", index);
        }

        return true;
    }

    function handleMultiplayerRevealConnected(index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        if (SteamIntegration.isHost) {
            // Host: process locally and send to client
            GridBridge.performRevealConnectedCells(index);
            sendCellUpdateToClient(index, "revealConnected");
        } else {
            // Client: ONLY send request to host and wait for response
            SteamIntegration.sendGameAction("revealConnected", index);
            GridBridge.performRevealConnectedCells(index);
        }

        return true; // Action handled by multiplayer
    }

    function handleMultiplayerToggleFlag(index, isClientRequest = false) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        if (SteamIntegration.isHost) {
            // Check ownership for both host and client requests
            if (checkCellOwnership(index, isClientRequest)) {
                GridBridge.performToggleFlag(index);
                sendCellUpdateToClient(index, "flag");
            } else if (isClientRequest) {
                // If it's a client request and was denied, we could send a denial
                SteamIntegration.sendGameAction("flagDenied", index);
            }
        } else {
            // Client: ONLY send request to host and wait for response
            SteamIntegration.sendGameAction("flag", index);
        }

        return true; // Action handled by multiplayer
    }

    function handleMultiplayerHintRequest() {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        if (SteamIntegration.isHost) {
            // Host: process hint locally
            GridBridge.processHintRequest();
        } else {
            // Client: send request to host
            SteamIntegration.sendGameAction("requestHint", 0);
        }

        return true; // Action handled by multiplayer
    }

    function initializeMultiplayerGame(firstClickIndex) {
        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
            // Reset ready flag when starting new game
            clientReadyForActions = false;
            pendingInitialActions = [];

            // Check connection health before initializing
            if (!connectionIsHealthy) {
                SteamIntegration.testConnection();

                // Use a timer to wait for potential reconnection
                const initGameTimer = Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                    Qt.application, "initGameTimer");

                initGameTimer.triggered.connect(function() {
                    // Try again if the connection is now healthy
                    if (connectionIsHealthy) {
                        sendMinesListToClient();
                        if (firstClickIndex !== undefined) {
                            pendingInitialActions.push({type: "reveal", index: firstClickIndex});
                        }

                        // Check if client has processed mines
                        Qt.callLater(function() {
                            SteamIntegration.sendGameAction("minesReady", 0);
                        });
                    }

                    initGameTimer.destroy();
                });

                return true;
            }

            // Send mines list first
            minesInitialized = true;
            sendMinesListToClient();

            // Store the initial reveal action instead of sending immediately
            if (firstClickIndex !== undefined) {
                pendingInitialActions.push({type: "reveal", index: firstClickIndex});
            }

            // Start checking if client has processed mines
            Qt.callLater(function() {
                SteamIntegration.sendGameAction("minesReady", 0);
            });

            return true;
        }

        return false;
    }

    function onFirstReveal(index) {
        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
            // Store the initial reveal action instead of sending immediately
            pendingInitialActions.push({type: "reveal", index: index});
            return true;
        }

        return false;
    }

    function onGameWon() {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false;
        }

        // If we're the host, make sure to sync final cell state BEFORE sending game over
        if (SteamIntegration.isHost) {
            // Ensure all revealed cells are properly synchronized first
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                const cell = GridBridge.getCell(i);
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

        // Handle achievement unlocking for multiplayer
        const difficulty = GameState.getDifficultyLevel();
        if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
            SteamIntegration.unlockAchievement("ACH_WIN_COOP");
            if (SteamIntegration.isHost) {
                SteamIntegration.sendGameAction("unlockCoopAchievement", 0);
            }
        }

        return true;
    }

    function onGameLost(lastClickedIndex) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return false;
        }

        // Make sure we send the final cell state before game over
        sendCellUpdateToClient(lastClickedIndex, "finalReveal");

        // Wait a moment to ensure cell updates are processed before game over
        Qt.callLater(function() {
            // Send game over message with loss status (0 = loss)
            SteamIntegration.sendGameAction("gameOver", 0);
        });

        return true;
    }

    function changeDifficulty(difficultyIndex) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return false;
        }

        GameSettings.difficulty = difficultyIndex;
        const difficultySet = GameState.difficultySettings[difficultyIndex];
        SteamIntegration.sendGameAction("prepareDifficultyChange", difficultyIndex);

        Qt.callLater(function() {
            sessionRunning = false;
            minesInitialized = false;
            clientReadyForActions = false;
            clientGridReady = false;
            pendingInitialActions = [];
            pendingActions = [];

            GameState.gridSizeX = difficultySet.x;
            GameState.gridSizeY = difficultySet.y;
            GameState.mineCount = difficultySet.mines;
            GridBridge.initGame();

            syncGridSettingsToClient();
        });

        return true;
    }

    function resetMultiplayerGrid() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return;
        }

        ComponentsContext.multiplayerPopupVisible = true
        minesInitialized = false;
        clientReadyForActions = false;
        clientGridReady = false;
        pendingInitialActions = [];
        pendingActions = [];
        isProcessingNetworkAction = false;

        GameState.difficultyChanged = true;
        GridBridge.initGame();

        SteamIntegration.sendGameAction("resetMultiplayerGrid", 0);

        Qt.callLater(function() {
            syncGridSettingsToClient();
        });
    }

    property var cellOwnership: ({})
    function checkCellOwnership(cellIndex, isClientRequest) {
        const player = isClientRequest ? "client" : "host";
        const currentTime = new Date().getTime();
        const ownershipData = cellOwnership[cellIndex];

        // If cell is not owned, allow the action and set ownership
        if (!ownershipData) {
            setCellOwnership(cellIndex, player);
            return true;
        }

        // If ownership has expired (more than 1 second), allow the action and set new ownership
        if (currentTime - ownershipData.timestamp > 1000) {
            setCellOwnership(cellIndex, player);
            return true;
        }

        // If cell is owned by the requesting player, allow the action and reset timer
        if (ownershipData.owner === player) {
            setCellOwnership(cellIndex, player); // Reset the timer
            return true;
        }

        // Otherwise, the cell is owned by the other player and within the time limit
        console.log("Cell " + cellIndex + " is owned by " + ownershipData.owner + ", denying access to " + player);
        return false;
    }

    function setCellOwnership(cellIndex, player) {
        cellOwnership[cellIndex] = {
            owner: player,
            timestamp: new Date().getTime()
        };
    }
}
