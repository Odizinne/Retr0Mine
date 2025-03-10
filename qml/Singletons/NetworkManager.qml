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

    // Grid synchronization properties
    property var chunkedMines: []
    property int receivedChunks: 0
    property int expectedTotalChunks: 0

    // Player information
    property string hostName: SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName
    property string clientName: !SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName

    // Flag and synchronization properties
    property var flagCooldowns: ({})
    property int flagCooldownDuration: 1000
    property var flagOwners: ({})

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
                console.log("NetworkManager: Connection is unstable");
            } else if (state === SteamIntegration.Disconnected) {
                connectionIsHealthy = false;
                console.log("NetworkManager: Connection is disconnected");

                // Handle disconnection (specific game logic)
                if (preserveGameStateOnDisconnect && GameState.gameStarted && !GameState.gameOver) {
                    // Save the current game state for potential reconnection
                    lastKnownRevealedCount = GameState.revealedCount;
                    lastKnownFlaggedCount = GameState.flaggedCount;
                }
            } else if (state === SteamIntegration.Reconnecting) {
                connectionIsHealthy = false;
                isReconnecting = true;
                console.log("NetworkManager: Attempting to reconnect");
            }
        });

        // Handle reconnection results
        SteamIntegration.reconnectionSucceeded.connect(function() {
            isReconnecting = false;
            connectionIsHealthy = true;
            console.log("NetworkManager: Reconnection succeeded");

            // If we're the host, send updated game state to the client
            if (SteamIntegration.isHost && GameState.gameStarted) {
                sendMinesListToClient();
            }
        });

        SteamIntegration.reconnectionFailed.connect(function() {
            isReconnecting = false;
            connectionIsHealthy = false;
            console.log("NetworkManager: Reconnection failed");
        });

        // Monitor lobby readiness
        SteamIntegration.lobbyReadyChanged.connect(function() {
            if (SteamIntegration.isLobbyReady && SteamIntegration.isHost) {
                console.log("NetworkManager: Lobby ready, sending grid sync");
                syncGridSettingsToClient();
            }
        });
    }

    // Grid synchronization - Send grid settings from host to client
    function syncGridSettingsToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost || !connectionIsHealthy) {
            return;
        }

        console.log("NetworkManager: Syncing grid settings to client");

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

        console.log("Sending grid sync:", JSON.stringify(gridSyncData));
        SteamIntegration.sendGameState(gridSyncData);
    }

    // Array utility functions
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

    // Cell signaling (pinging) system
    function sendPing(cellIndex) {
        if (SteamIntegration.isInMultiplayerGame && connectionIsHealthy) {
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

    // Flag cooldown system
    function isCellInCooldown(index) {
        // If the cell is not in cooldown at all, return false
        if (flagCooldowns[index] === undefined) {
            return false;
        }

        // Check if the current player is the one who placed the flag
        const isPlayerHost = SteamIntegration.isHost;
        const isFlagOwnedByHost = flagOwners[index] === true;

        // The cooldown only applies to the player who didn't place the flag
        // If the flag was placed by host, client is in cooldown (and vice versa)
        return isPlayerHost !== isFlagOwnedByHost;
    }

    function startFlagCooldown(index, isHostOwner) {
        flagCooldowns[index] = true;
        // If isHostOwner is provided, use it; otherwise default to current player
        flagOwners[index] = isHostOwner !== undefined ? isHostOwner : SteamIntegration.isHost;

        // Only set inCooldown for the player who DIDN'T place the flag
        const isPlayerHost = SteamIntegration.isHost;
        const isFlagOwnedByHost = flagOwners[index];

        // If cooldown applies to current player (they didn't place the flag), mark the cell
        if (isPlayerHost !== isFlagOwnedByHost) {
            const cell = GridBridge.getCell(index);
            if (cell) {
                cell.inCooldown = true;
            }
        }

        // Create a timer to clear the cooldown after the duration
        const timerId = Qt.createQmlObject(
            `import QtQuick; Timer {
                interval: ${flagCooldownDuration};
                repeat: false;
                running: true;
                onTriggered: {
                    NetworkManager.clearFlagCooldown(${index});
                }
            }`,
            Qt.application,
            "cooldownTimer_" + index
        );

        // Send cooldown info to other player if in multiplayer
        if (SteamIntegration.isInMultiplayerGame && connectionIsHealthy) {
            // Send a different action type based on who placed the flag
            const actionType = flagOwners[index] ? "hostFlagCooldown" : "clientFlagCooldown";
            SteamIntegration.sendGameAction(actionType, index);
        }
    }

    function clearFlagCooldown(index) {
        delete flagCooldowns[index];
        delete flagOwners[index];

        // Notify cells to update their visual state
        const cell = GridBridge.getCell(index);
        if (cell) {
            cell.inCooldown = false;
        }
    }

    // Grid preparation for multiplayer
    function prepareMultiplayerGrid(gridX, gridY, mineCount) {
        console.log("Preparing multiplayer grid:", gridX, "x", gridY, "mines:", mineCount);

        // Only reset cellsCreated if grid dimensions have changed
        if (GameState.gridSizeX !== gridX || GameState.gridSizeY !== gridY) {
            console.log("Grid dimensions changed - resetting cellsCreated counter");
            GridBridge.cellsCreated = 0;
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
        if (!SteamIntegration.isHost && connectionIsHealthy) {
            SteamIntegration.sendGameAction("gridSyncAck", data.syncTimestamp || 0);

            // If grid dimensions are the same and cells are already created,
            // we can immediately notify that we're ready
            if (!gridNeedsRecreation && GridBridge.cellsCreated === (data.gridSizeX * data.gridSizeY)) {
                console.log("Grid already matches expected size, sending ready immediately");
                Qt.callLater(notifyGridReady);
            }
        }
    }

    function notifyGridReady() {
        if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && connectionIsHealthy) {
            console.log("Client notifying host that grid is ready");
            SteamIntegration.sendGameAction("gridReady", 0);
        }
    }

    function sendCellUpdateToClient(index, action) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost || !connectionIsHealthy) {
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
            console.log("Host notifying client about game reset");
            SteamIntegration.sendGameAction("resetGame", 0);
        }
    }

    // Network message handling - Mines list
    function sendMinesListToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost || !connectionIsHealthy) {
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
                totalChunks: 1,
                syncTimestamp: new Date().getTime()
            };

            SteamIntegration.sendGameState(minesData);
        } else {
            // For larger arrays, split into chunks
            const chunkSize = 50;  // Adjust chunk size as needed
            const totalChunks = Math.ceil(cleanMinesArray.length / chunkSize);
            const syncTimestamp = new Date().getTime();

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
                    isChunked: true,
                    syncTimestamp: syncTimestamp
                };

                console.log("Sending chunk", i+1, "of", totalChunks, "size:", chunkArray.length);
                SteamIntegration.sendGameState(chunkData);

                // Small delay between chunks to prevent network congestion
                Qt.callLater(() => {});
            }
        }
    }

    function applyMinesAndCalculateNumbers(minesData) {
        console.log("Applying mines data and calculating numbers");

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
            lastSyncError = "Error extracting mines: " + e.toString();
            syncErrorCount++;
            return false;
        }

        // One last attempt - try direct property access if we have nothing yet
        if (cleanMinesArray.length === 0 && minesData.mines) {
            console.log("Trying direct property access");
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
        if (success && SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && connectionIsHealthy) {
            // Mark that we have initialized mines
            minesInitialized = true;

            // Acknowledge to host that we're ready for actions
            console.log("Client sending readyForActions acknowledgment to host");
            SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0);

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

    function applyGameState(gameState) {
        console.log("Applying received game state");

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
            console.log("Received mines-only data - initializing board");
            processMinesData(gameState);
            return;
        }

        console.log("Received unexpected game state format");
        lastSyncError = "Unexpected game state format";
        syncErrorCount++;
        isProcessingNetworkAction = false;
    }

    function handleChunkedMinesData(gameState) {
        console.log("Received chunked mines data - chunk " + (gameState.chunkIndex + 1) + " of " + gameState.totalChunks);

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
        console.log("Chunk received, now have " + receivedChunks + " of " + expectedTotalChunks + " chunks");

        // Process complete chunk set
        if (receivedChunks === expectedTotalChunks) {
            console.log("All chunks received, processing " + chunkedMines.length + " mines");

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
                    console.log("Not all chunks received after timeout, requesting sync");
                    requestFullSync();
                }
            });
        }
    }

    function processMinesData(minesData) {
        const success = applyMinesAndCalculateNumbers(minesData);

        if (success) {
            minesInitialized = true;

            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && connectionIsHealthy) {
                console.log("Client sending readyForActions acknowledgment to host");
                SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0);

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
        } else if (syncErrorCount >= maxConsecutiveSyncErrors) {
            console.error("Too many consecutive sync errors, requesting full sync");
            requestFullSync();
        }
    }

    function requestFullSync() {
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost ||
            !connectionIsHealthy) {
            return;
        }

        console.log("Client requesting full sync from host");
        SteamIntegration.sendGameAction("requestSync", 0);

        // Reset sync error count after requesting a full sync
        syncErrorCount = 0;
    }

    function handleNetworkAction(actionType, parameter) {
        console.log("Received action:", actionType, "parameter:", parameter);

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
            console.log("Host received grid ready notification from client");
            clientGridReady = true;
            break;

        case "reveal":
            console.log("Host validating client reveal for cell:", cellIndex);
            GridBridge.performReveal(cellIndex);
            break;

        case "flag":
            console.log("Host processing flag action for cell:", cellIndex);

            if (flagCooldowns[cellIndex] !== undefined && flagOwners[cellIndex] === true) {
                console.log("Cell " + cellIndex + " is in cooldown for client, ignoring flag action");
                SteamIntegration.sendGameAction("flagRejected", cellIndex);
                return;
            }

            const flagRemoved = GridBridge.performToggleFlag(cellIndex);
            sendCellUpdateToClient(cellIndex, "flag");

            if (!flagRemoved) {
                startFlagCooldown(cellIndex, false);
            } else {
                clearFlagCooldown(cellIndex);
            }
            break;

        case "revealConnected":
            console.log("Host processing revealConnected action for cell:", cellIndex);
            GridBridge.performRevealConnectedCells(cellIndex);
            sendCellUpdateToClient(cellIndex, "revealConnected");
            break;

        case "requestSync":
            console.log("Client requested full sync, sending mines list");
            sendMinesListToClient();
            break;

        case "readyForActions":
            console.log("Host received client readiness confirmation");
            clientReadyForActions = true;

            if (pendingInitialActions.length > 0) {
                console.log("Sending", pendingInitialActions.length, "pending initial actions");
                pendingInitialActions.forEach(function(action) {
                    sendCellUpdateToClient(action.index, action.type);
                });
                pendingInitialActions = [];
            }
            break;

        case "requestMines":
            console.log("Client requested mines data, sending immediately");
            sendMinesListToClient();

            Qt.callLater(function() {
                console.log("Checking if client has processed mines");
                SteamIntegration.sendGameAction("minesReady", 0);
            });
            break;

        case "requestHint":
            console.log("Host processing hint request from client");
            GridBridge.processHintRequest();
            break;

        case "ping":
            console.log("Host received ping at cell:", cellIndex);
            showPingAtCell(cellIndex);
            break;

        case "gridResetAck":
            console.log("Host received grid reset acknowledgment from client");
            break;

        case "gridSyncAck":
            console.log("Host received grid sync acknowledgment from client");
            break;

        case "testConnection":
            console.log("Host received connection test request");
            SteamIntegration.sendGameAction("connectionTestResponse", cellIndex);
            break;

        default:
            console.log("Host received unknown action type:", actionType);
        }
    }

    function handleClientAction(actionType, cellIndex) {
        // Special handling for mines readiness check
        if (actionType === "minesReady") {
            if (minesInitialized) {
                console.log("Client confirms mines data is ready");
                // Send acknowledgment to host that we're ready for actions
                if (connectionIsHealthy) {
                    SteamIntegration.sendGameAction("readyForActions", 0);
                }
            } else {
                console.log("Client received mines readiness check but mines not initialized");
                // Request mines data directly with a slight delay to avoid request flooding
                if (connectionIsHealthy) {
                    Qt.callLater(function() {
                        SteamIntegration.sendGameAction("requestMines", 0);
                    });
                }
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
            // Buffer actions until mines data is received
            console.log("Buffering action until mines data is received:", actionType, cellIndex);

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
                if (pendingActions.length > 10 && connectionIsHealthy) {
                    console.log("Too many pending actions, requesting mines data again");
                    SteamIntegration.sendGameAction("requestMines", 0);

                    // Limit the buffer size to prevent memory issues
                    if (pendingActions.length > 50) {
                        console.log("Trimming pending actions buffer");
                        pendingActions = pendingActions.slice(-50);
                    }
                }
            }

            isProcessingNetworkAction = false;
            return;
        }

        // Process the action based on type
        switch(actionType) {
            case "finalReveal":
                console.log("Client processing final reveal action for cell:", cellIndex);
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
                console.log("Client processing reveal action for cell:", cellIndex);
                try {
                    GridBridge.performReveal(cellIndex);
                    allowClientReveal = true;
                } catch (e) {
                    console.error("Error processing reveal action:", e);
                }
                break;

            case "flag":
                console.log("Client processing flag action for cell:", cellIndex);
                try {
                    GridBridge.performToggleFlag(cellIndex);
                } catch (e) {
                    console.error("Error processing flag action:", e);
                }
                break;

            case "revealConnected":
                console.log("Client processing revealConnected action for cell:", cellIndex);
                try {
                    GridBridge.performRevealConnectedCells(cellIndex);
                } catch (e) {
                    console.error("Error processing revealConnected action:", e);
                }
                break;

            case "startGame":
                console.log("Client received start game command from host");
                ComponentsContext.multiplayerPopupVisible = false;
                break;

            case "gameOver":
                console.log("Client processing gameOver action, win status:", cellIndex);
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
                console.log("Client received game reset notification");
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
                console.log("Client received coop achievement unlock notification");
                if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                    const difficulty = GameState.getDifficultyLevel();
                    if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
                        SteamIntegration.unlockAchievement("ACH_WIN_COOP");
                    }
                }
                break;

            case "sendHint":
                console.log("Client received hint for cell:", cellIndex);
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
                console.log("Client received ping at cell:", cellIndex);
                showPingAtCell(cellIndex);
                isProcessingNetworkAction = false;
                break;

            case "hostFlagCooldown":
                console.log("Client received cooldown notification for host-owned flag:", cellIndex);
                // Host placed the flag, so client should see cooldown
                startFlagCooldown(cellIndex, true); // true = host owns it
                // Client should see the cooldown indicator
                GridBridge.withCell(cellIndex, function(cell) {
                    if (cell) {
                        cell.inCooldown = true;
                    }
                });
                isProcessingNetworkAction = false;
                break;

            case "clientFlagCooldown":
                console.log("Client received cooldown notification for client-owned flag:", cellIndex);
                // Client placed the flag, so client should NOT see cooldown
                startFlagCooldown(cellIndex, false); // false = client owns it
                // No visual indicator needed since client owns this flag
                isProcessingNetworkAction = false;
                break;

            case "flagRejected":
                console.log("Flag action rejected for cell:", cellIndex);
                // The cell was in cooldown, action was rejected
                isProcessingNetworkAction = false;
                // Show cooldown feedback on the cell
                GridBridge.withCell(cellIndex, function(cell) {
                    if (cell && cell.cooldownAnimation) {
                        cell.cooldownAnimation.start();
                    }
                });
                break;

            case "resetMultiplayerGrid":
                console.log("Client received grid reset command");
                ComponentsContext.multiplayerPopupVisible = true;
                minesInitialized = false;
                clientReadyForActions = false;
                clientGridReady = false;
                allowClientReveal = false;
                pendingActions = [];
                isProcessingNetworkAction = false;

                GameState.difficultyChanged = true;
                GridBridge.initGame();

                if (connectionIsHealthy) {
                    SteamIntegration.sendGameAction("gridResetAck", 0);
                }
                break;

            case "prepareDifficultyChange":
                console.log("Client preparing for difficulty change, new difficulty:", cellIndex);

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
                console.log("Client received connection test response");
                // This is just a ping-pong to test if the connection is alive
                break;

            default:
                console.log("Client received unknown action type:", actionType);
        }

        // Action finished processing
        isProcessingNetworkAction = false;
    }

    // Functions for coordinating multiplayer game actions
    function handleMultiplayerReveal(index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        // Both host and client process the reveal locally first
        const result = GridBridge.performReveal(index);

        if (SteamIntegration.isHost) {
            // Host: just send the result to client
            sendCellUpdateToClient(index, "reveal");
        } else {
            // Client: inform the host about the action (not waiting for permission)
            if (connectionIsHealthy) {
                SteamIntegration.sendGameAction("reveal", index);
            }
            // Important: we're no longer setting isProcessingNetworkAction to true
            // This allows the client to continue playing without waiting
        }

        return true; // Action handled by multiplayer
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
            // Client: send request to host and wait
            isProcessingNetworkAction = connectionIsHealthy;
            if (connectionIsHealthy) {
                SteamIntegration.sendGameAction("revealConnected", index);
            } else {
                // If connection is not healthy, just process locally
                GridBridge.performRevealConnectedCells(index);
            }
        }

        return true; // Action handled by multiplayer
    }

    function handleMultiplayerToggleFlag(index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false; // Not a multiplayer game
        }

        // Check if the cell is in cooldown for this player
        if (isCellInCooldown(index)) {
            console.log("Cell " + index + " is in cooldown for this player, ignoring flag action");

            // Show cooldown feedback on the cell
            GridBridge.withCell(index, function(cell) {
                if (cell.cooldownAnimation) {
                    cell.cooldownAnimation.start();
                }
            });

            return true; // Action handled (by rejecting it)
        }

        if (SteamIntegration.isHost) {
            // Host: process locally and send to client
            const flagRemoved = GridBridge.performToggleFlag(index);
            if (connectionIsHealthy) {
                sendCellUpdateToClient(index, "flag");
            }

            // Start cooldown after processing - this flag is owned by host
            if (!flagRemoved) {
                startFlagCooldown(index, true);
            } else {
                // Clear any existing cooldown data if the flag was completely removed
                clearFlagCooldown(index);
            }
        } else {
            // Client: send request to host and wait
            isProcessingNetworkAction = connectionIsHealthy;
            if (connectionIsHealthy) {
                SteamIntegration.sendGameAction("flag", index);
            } else {
                // If connection is not healthy, just process locally
                GridBridge.performToggleFlag(index);
            }
            // Cooldown will be started by host and sent back to client
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
            console.log("Client requesting hint from host");
            isProcessingNetworkAction = connectionIsHealthy;
            if (connectionIsHealthy) {
                SteamIntegration.sendGameAction("requestHint", 0);
            } else {
                // If connection is not healthy, just process locally
                GridBridge.processHintRequest();
            }
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
                console.log("Connection not healthy, attempting to reconnect");
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
                console.log("Checking if client has processed mines");
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
                if (connectionIsHealthy) {
                    SteamIntegration.sendGameAction("gameOver", 1);
                }
            });
        }

        // Handle achievement unlocking for multiplayer
        const difficulty = GameState.getDifficultyLevel();
        if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
            SteamIntegration.unlockAchievement("ACH_WIN_COOP");
            if (SteamIntegration.isHost && connectionIsHealthy) {
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
            if (connectionIsHealthy) {
                SteamIntegration.sendGameAction("gameOver", 0);
            }
        });

        return true;
    }

    function changeDifficulty(difficultyIndex) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return false;
        }

        // Check connection health before initializing
        if (!connectionIsHealthy) {
            console.log("Connection not healthy, attempting to reconnect");
            SteamIntegration.testConnection();
            return false;
        }

        console.log("Host initiating difficulty change to:", difficultyIndex);
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

        console.log("Host initiating multiplayer grid reset");
        ComponentsContext.multiplayerPopupVisible = true
        minesInitialized = false;
        clientReadyForActions = false;
        clientGridReady = false;
        pendingInitialActions = [];
        pendingActions = [];
        isProcessingNetworkAction = false;

        GameState.difficultyChanged = true;
        GridBridge.initGame();

        if (connectionIsHealthy) {
            SteamIntegration.sendGameAction("resetMultiplayerGrid", 0);
        }

        Qt.callLater(function() {
            syncGridSettingsToClient();
        });
    }
}
