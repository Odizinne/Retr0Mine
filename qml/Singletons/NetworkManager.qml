pragma Singleton
import QtQuick
import Odizinne.Retr0Mine

QtObject {
    id: networkManager

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
    property var chunkedMines: []
    property int receivedChunks: 0
    property int expectedTotalChunks: 0
    property string hostName: SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName
    property string clientName: !SteamIntegration.isHost ? SteamIntegration.playerName : SteamIntegration.connectedPlayerName
    property bool isReconnecting: false
    property bool preserveGameStateOnDisconnect: true
    property int lastKnownRevealedCount: 0
    property int lastKnownFlaggedCount: 0
    property var lastSyncError: null
    property int syncErrorCount: 0
    property int maxConsecutiveSyncErrors: 3
    property bool connectionIsHealthy: SteamIntegration.connectionState === SteamIntegration.Connected
    property var cellOwnership: ({})

    Component.onCompleted: {
        SteamIntegration.gameActionReceived.connect(handleNetworkAction)
        SteamIntegration.gameStateReceived.connect(applyGameState)

        SteamIntegration.multiplayerStatusChanged.connect(function() {
            if (!SteamIntegration.isInMultiplayerGame) {
                clientGridReady = false
                resetMultiplayerState()
            }
        })

        SteamIntegration.connectionStateChanged.connect(function(state) {
            if (state === SteamIntegration.Connected) {
                connectionIsHealthy = true
            } else if (state === SteamIntegration.Unstable) {
                connectionIsHealthy = false
            } else if (state === SteamIntegration.Disconnected) {
                connectionIsHealthy = false

                if (preserveGameStateOnDisconnect && GameState.gameStarted && !GameState.gameOver) {
                    lastKnownRevealedCount = GameState.revealedCount
                    lastKnownFlaggedCount = GameState.flaggedCount
                }
            } else if (state === SteamIntegration.Reconnecting) {
                connectionIsHealthy = false
                isReconnecting = true
            }
        })

        SteamIntegration.reconnectionSucceeded.connect(function() {
            isReconnecting = false
            connectionIsHealthy = true

            if (SteamIntegration.isHost && GameState.gameStarted) {
                sendMinesListToClient()
            }
        })

        SteamIntegration.reconnectionFailed.connect(function() {
            isReconnecting = false
            connectionIsHealthy = false
        })

        SteamIntegration.lobbyReadyChanged.connect(function() {
            if (SteamIntegration.isLobbyReady && SteamIntegration.isHost) {
                syncGridSettingsToClient()
            }
        })
    }

    function syncGridSettingsToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return
        }

        const difficultySet = GameState.difficultySettings[UserSettings.difficulty]
        const gridSyncData = {
            gridSync: true,
            gridSizeX: difficultySet.x,
            gridSizeY: difficultySet.y,
            mineCount: difficultySet.mines,
            syncTimestamp: new Date().getTime()
        }

        SteamIntegration.sendGameState(gridSyncData)
    }

    function convertObjectToArray(obj, name) {
        let resultArray = []
        if (Array.isArray(obj)) {
            resultArray = Array.from(obj)
        } else if (typeof obj === 'object' && obj !== null) {
            for (let prop in obj) {
                if (!isNaN(parseInt(prop))) {
                    resultArray.push(parseInt(obj[prop]))
                }
            }
        } else {
            console.error(name + " is empty or invalid")
        }
        return resultArray
    }

    function safeArrayIncludes(array, value) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return array && array.includes(value)
        }

        return Array.isArray(array) && array !== null && array.includes(value)
    }

    function safeArrayGet(array, index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return array && array[index]
        }

        return Array.isArray(array) && array !== null && index >= 0 && index < array.length ? array[index] : undefined
    }

    function sendPing(cellIndex) {
        if (SteamIntegration.isInMultiplayerGame) {
            SteamIntegration.sendGameAction("ping", cellIndex)
        }

        showPingAtCell(cellIndex)
    }

    function showPingAtCell(cellIndex) {
        if (cellIndex < 0 || cellIndex >= GameState.gridSizeX * GameState.gridSizeY) {
            console.error("Invalid cell index for ping:", cellIndex)
            return
        }

        const cell = GridBridge.getCell(cellIndex)
        if (!cell) {
            console.error("Cannot find cell for ping:", cellIndex)
            return
        }

        const pingComponent = Qt.createComponent("../SignalIndicator.qml")
        if (pingComponent.status === Component.Ready) {
            const pingObject = pingComponent.createObject(cell, {
                                                              "anchors.centerIn": cell
                                                          })

            const pingTimer = Qt.createQmlObject(
                                'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                                cell, "pingTimer")

            pingTimer.triggered.connect(function() {
                pingObject.destroy()
                pingTimer.destroy()
            })
        } else {
            console.error("Error creating ping indicator:", pingComponent.errorString())
        }
    }

    function prepareMultiplayerGrid(gridX, gridY, mineCount) {
        if (GameState.gridSizeX !== gridX || GameState.gridSizeY !== gridY) {
            GridBridge.cellsCreated = 0
        }

        GameState.gridSizeX = gridX
        GameState.gridSizeY = gridY
        GameState.mineCount = mineCount

        GameState.difficultyChanged = true
    }

    function handleMultiplayerGridSync(data) {
        let gridNeedsRecreation = (GameState.gridSizeX !== data.gridSizeX ||
                                   GameState.gridSizeY !== data.gridSizeY)

        prepareMultiplayerGrid(
                    data.gridSizeX,
                    data.gridSizeY,
                    data.mineCount
                    )

        let matchedDifficulty = -1

        for (let i = 0; i < 4; i++) {
            const diffSet = GameState.difficultySettings[i]
            if (diffSet.x === data.gridSizeX &&
                    diffSet.y === data.gridSizeY &&
                    diffSet.mines === data.mineCount) {
                matchedDifficulty = i
                break
            }
        }

        if (matchedDifficulty >= 0) {
            UserSettings.difficulty = matchedDifficulty
        } else {
            UserSettings.customWidth = data.gridSizeX
            UserSettings.customHeight = data.gridSizeY
            UserSettings.customMines = data.mineCount
            UserSettings.difficulty = 4
        }

        if (!SteamIntegration.isHost) {
            SteamIntegration.sendGameAction("gridSyncAck", data.syncTimestamp || 0)

            if (!gridNeedsRecreation && GridBridge.cellsCreated === (data.gridSizeX * data.gridSizeY)) {
                Qt.callLater(notifyGridReady)
            }
        }
    }

    function notifyGridReady() {
        if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            SteamIntegration.sendGameAction("gridReady", 0)
        }
    }

    function sendCellUpdateToClient(index, action) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return
        }

        if (!clientReadyForActions && action === "reveal") {
            pendingInitialActions.push({type: action, index: index})
            return
        }

        SteamIntegration.sendGameAction(action, index)
    }

    function resetMultiplayerState() {
        minesInitialized = false
        clientReadyForActions = false
        pendingInitialActions = []
        pendingActions = []
        isProcessingNetworkAction = false
        isReconnecting = false
        syncErrorCount = 0
        lastSyncError = null
        cellOwnership = ([])

        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost &&
                SteamIntegration.connectionState === SteamIntegration.Connected) {
            SteamIntegration.sendGameAction("resetGame", 0)
        }
    }

    function sendMinesListToClient() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return
        }

        if (!GameState.mines || GameState.mines.length === 0) {
            console.error("Cannot send empty mines list")
            return
        }

        const cleanMinesArray = GameState.mines.map(pos => Number(pos))

        if (cleanMinesArray.length <= 100) {
            const minesData = {
                gridSizeX: Number(GameState.gridSizeX),
                gridSizeY: Number(GameState.gridSizeY),
                mineCount: Number(GameState.mineCount),
                mines: cleanMinesArray,
                chunkIndex: 0,
                totalChunks: 1,
                syncTimestamp: new Date().getTime()
            }

            SteamIntegration.sendGameState(minesData)
        } else {
            const chunkSize = 50
            const totalChunks = Math.ceil(cleanMinesArray.length / chunkSize)
            const syncTimestamp = new Date().getTime()

            for (let i = 0; i < totalChunks; i++) {
                const startIndex = i * chunkSize
                const endIndex = Math.min(startIndex + chunkSize, cleanMinesArray.length)
                const chunkArray = cleanMinesArray.slice(startIndex, endIndex)

                const chunkData = {
                    gridSizeX: Number(GameState.gridSizeX),
                    gridSizeY: Number(GameState.gridSizeY),
                    mineCount: Number(GameState.mineCount),
                    mines: chunkArray,
                    chunkIndex: i,
                    totalChunks: totalChunks,
                    isChunked: true,
                    syncTimestamp: syncTimestamp
                }

                SteamIntegration.sendGameState(chunkData)

                Qt.callLater(() => {})
            }
        }
    }

    function applyMinesAndCalculateNumbers(minesData) {
        if (!minesData || !minesData.mines) {
            console.error("Received invalid mines data")
            lastSyncError = "Invalid mines data"
            syncErrorCount++
            return false
        }

        if (GameState.gridSizeX !== minesData.gridSizeX ||
                GameState.gridSizeY !== minesData.gridSizeY) {
            GameState.gridSizeX = Number(minesData.gridSizeX)
            GameState.gridSizeY = Number(minesData.gridSizeY)
        }

        let cleanMinesArray = []

        try {
            if (Array.isArray(minesData.mines)) {
                cleanMinesArray = minesData.mines.map(Number)
            } else if (typeof minesData.mines === 'string') {
                const parsed = JSON.parse(minesData.mines)
                if (Array.isArray(parsed)) {
                    cleanMinesArray = parsed.map(Number)
                }
            } else if (typeof minesData.mines === 'object' && minesData.mines !== null) {
                if (minesData.mines.hasOwnProperty('length') && typeof minesData.mines.length === 'number') {
                    for (let i = 0; i < minesData.mines.length; i++) {
                        if (minesData.mines[i] !== undefined) {
                            cleanMinesArray.push(Number(minesData.mines[i]))
                        }
                    }
                } else {
                    for (let key in minesData.mines) {
                        if (minesData.mines.hasOwnProperty(key) && !isNaN(Number(minesData.mines[key]))) {
                            cleanMinesArray.push(Number(minesData.mines[key]))
                        }
                    }
                }
            }
        } catch (e) {
            console.error("Error extracting mines:", e)
            lastSyncError = "Error extracting mines: " + e.toString()
            syncErrorCount++
            return false
        }

        if (cleanMinesArray.length === 0 && minesData.mines) {
            try {
                for (let i = 0; i < 1000; i++) {
                    if (minesData.mines[i] !== undefined) {
                        cleanMinesArray.push(Number(minesData.mines[i]))
                    }
                }
            } catch (e) {
                console.error("Error in direct property access:", e)
            }
        }

        if (cleanMinesArray.length === 0) {
            console.error("Failed to extract any valid mine positions")
            lastSyncError = "No valid mine positions extracted"
            syncErrorCount++
            return false
        }

        if (cleanMinesArray.length !== Number(minesData.mineCount)) {
            console.warn("Extracted mine count", cleanMinesArray.length,
                         "doesn't match expected mine count", minesData.mineCount)
        }

        GameState.mineCount = Number(minesData.mineCount) || cleanMinesArray.length
        GameState.mines = cleanMinesArray

        try {
            const calculatedNumbers = GameLogic.calculateNumbersFromMines(
                                        Number(GameState.gridSizeX),
                                        Number(GameState.gridSizeY),
                                        cleanMinesArray
                                        )

            if (calculatedNumbers && calculatedNumbers.length === GameState.gridSizeX * GameState.gridSizeY) {
                GameState.numbers = calculatedNumbers
            } else {
                console.error("Invalid numbers calculated, expected length:",
                              GameState.gridSizeX * GameState.gridSizeY,
                              "got:", calculatedNumbers ? calculatedNumbers.length : 0)
                lastSyncError = "Invalid numbers calculated"
                syncErrorCount++
                return false
            }
        } catch (e) {
            console.error("Error calculating numbers:", e)
            lastSyncError = "Error calculating numbers: " + e.toString()
            syncErrorCount++
            return false
        }

        GameState.gameStarted = true

        syncErrorCount = 0
        lastSyncError = null

        const success = true

        if (success && SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
            minesInitialized = true

            SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0)

            if (pendingActions.length > 0) {
                Qt.callLater(function() {
                    pendingActions.forEach(function(action) {
                        handleNetworkAction(action.type, action.index)
                    })
                    pendingActions = []
                })
            }
        }

        return success
    }

    function applyGameState(gameState) {
        if (!gameState) {
            console.error("Received invalid game state")
            lastSyncError = "Received invalid game state"
            syncErrorCount++
            isProcessingNetworkAction = false
            return
        }

        if (gameState.action === "gameStats" && gameState.stats) {
            if (!SteamIntegration.isHost) {
                GameState.hostRevealed = gameState.stats.hostRevealed || 0
                GameState.clientRevealed = gameState.stats.clientRevealed || 0
                GameState.firstClickRevealed = gameState.stats.firstClickRevealed || 0

                if (gameState.stats.bombClickedBy) {
                    GameState.bombClickedBy = gameState.stats.bombClickedBy
                }
            }
            return
        }

        if (gameState.gridSync) {
            handleMultiplayerGridSync(gameState)
            return
        }

        if (gameState.isChunked) {
            handleChunkedMinesData(gameState)
            return
        }

        if (gameState.mines && !gameState.revealedCells && !gameState.numbers) {
            processMinesData(gameState)
            return
        }

        lastSyncError = "Unexpected game state format"
        syncErrorCount++
        isProcessingNetworkAction = false
    }

    function handleChunkedMinesData(gameState) {
        if (gameState.chunkIndex === 0) {
            chunkedMines = []
            receivedChunks = 0
            expectedTotalChunks = gameState.totalChunks

            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop()
                networkManager.chunkResendTimer.destroy()
                networkManager.chunkResendTimer = null
            }
        }

        try {
            if (Array.isArray(gameState.mines)) {
                chunkedMines = chunkedMines.concat(gameState.mines.map(Number))
            } else if (typeof gameState.mines === 'object' && gameState.mines !== null) {
                for (let prop in gameState.mines) {
                    if (!isNaN(parseInt(prop))) {
                        chunkedMines.push(Number(gameState.mines[prop]))
                    }
                }
            }
        } catch (e) {
            console.error("Error processing chunk:", e)
        }

        receivedChunks++

        if (receivedChunks === expectedTotalChunks) {
            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop()
                networkManager.chunkResendTimer.destroy()
                networkManager.chunkResendTimer = null
            }

            const completeData = {
                gridSizeX: Number(gameState.gridSizeX),
                gridSizeY: Number(gameState.gridSizeY),
                mineCount: Number(gameState.mineCount),
                mines: chunkedMines,
                syncTimestamp: gameState.syncTimestamp
            }

            processMinesData(completeData)
        }
        else if (receivedChunks < expectedTotalChunks) {
            if (networkManager.chunkResendTimer) {
                networkManager.chunkResendTimer.stop()
                networkManager.chunkResendTimer.destroy()
                networkManager.chunkResendTimer = null
            }

            networkManager.chunkResendTimer = Qt.createQmlObject(
                        'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                        Qt.application, "chunkResendTimer")

            networkManager.chunkResendTimer.triggered.connect(function() {
                if (receivedChunks < expectedTotalChunks) {
                    requestFullSync()
                }
            })
        }
    }

    function processMinesData(minesData) {
        const success = applyMinesAndCalculateNumbers(minesData)

        if (success) {
            minesInitialized = true

            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                SteamIntegration.sendGameAction("readyForActions", minesData.syncTimestamp || 0)

                if (pendingActions.length > 0) {
                    Qt.callLater(function() {
                        pendingActions.forEach(function(action) {
                            handleNetworkAction(action.type, action.index)
                        })
                        pendingActions = []
                    })
                }
            }
        } else if (syncErrorCount >= maxConsecutiveSyncErrors) {
            console.error("Too many consecutive sync errors, requesting full sync")
            requestFullSync()
        }
    }

    function requestFullSync() {
        if (!SteamIntegration.isInMultiplayerGame || SteamIntegration.isHost) {
            return
        }

        SteamIntegration.sendGameAction("requestSync", 0)
        syncErrorCount = 0
    }

    function handleNetworkAction(actionType, parameter) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return
        }

        if (actionType === "chat") {
            return
        }

        if (SteamIntegration.isHost) {
            handleHostAction(actionType, parameter)
        } else {
            handleClientAction(actionType, parameter)
        }
    }

    function handleHostAction(actionType, cellIndex) {
        switch(actionType) {
        case "gridReady":
            clientGridReady = true
            break

        case "reveal":
            handleMultiplayerReveal(cellIndex, NetworkManager.clientName)
            break

        case "flag":
            handleMultiplayerToggleFlag(cellIndex, true)
            break

        case "revealConnected":
            GridBridge.performRevealConnectedCells(cellIndex, NetworkManager.clientName)
            break

        case "requestSync":
            sendMinesListToClient()
            break

        case "readyForActions":
            clientReadyForActions = true

            if (pendingInitialActions.length > 0) {
                pendingInitialActions.forEach(function(action) {
                    sendCellUpdateToClient(action.index, action.type)
                })
                pendingInitialActions = []
            }
            break

        case "requestMines":
            sendMinesListToClient()

            Qt.callLater(function() {
                SteamIntegration.sendGameAction("minesReady", 0)
            })
            break

        case "requestHint":
            GridBridge.processHintRequest()
            break

        case "ping":
            showPingAtCell(cellIndex)
            break

        case "gridResetAck":
            break

        case "gridSyncAck":
            break

        case "testConnection":
            SteamIntegration.sendGameAction("connectionTestResponse", cellIndex)
            break

        default:
            console.error("Host received unknown action type:", actionType)
        }
    }

    function handleClientAction(actionType, cellIndex) {
        if (actionType === "minesReady") {
            if (minesInitialized) {
                SteamIntegration.sendGameAction("readyForActions", 0)
            } else {
                Qt.callLater(function() {
                    SteamIntegration.sendGameAction("requestMines", 0)
                })
            }
            return
        }

        let criticalActions = [
                "gameOver", "startGame", "resetMultiplayerGrid",
                "prepareDifficultyChange", "connectionTestResponse", "ping"
            ]

        if (!minesInitialized && !criticalActions.includes(actionType)) {
            let isDuplicate = false
            for (let i = 0; i < pendingActions.length; i++) {
                if (pendingActions[i].type === actionType && pendingActions[i].index === cellIndex) {
                    isDuplicate = true
                    break
                }
            }

            if (!isDuplicate) {
                pendingActions.push({type: actionType, index: cellIndex, timestamp: Date.now()})

                if (pendingActions.length > 10) {
                    console.error("Too many pending actions, requesting mines data again")
                    SteamIntegration.sendGameAction("requestMines", 0)

                    if (pendingActions.length > 50) {
                        pendingActions = pendingActions.slice(-50)
                    }
                }
            }

            isProcessingNetworkAction = false
            return
        }

        switch(actionType) {
        case "flagDenied":
            isProcessingNetworkAction = false
            break

        case "finalReveal":
            GridBridge.withCell(cellIndex, function(cell) {
                if (!cell.revealed) {
                    cell.revealed = true
                    cell.shouldBeFlat = true
                    if (cell.button) {
                        cell.button.flat = true
                        cell.button.opacity = 1
                    }

                    if (NetworkManager.safeArrayIncludes(GameState.mines, cellIndex)) {
                        cell.isBombClicked = true
                    }

                    GameState.revealedCount++
                }
            })
            break

        case "reveal":
            try {
                GridBridge.performReveal(cellIndex, NetworkManager.hostName)
                allowClientReveal = true
                if (!GameTimer.isRunning) {
                    GameTimer.start()
                }
            } catch (e) {
                console.error("Error processing reveal action:", e)
            }
            break

        case "flag":
            try {
                GridBridge.performToggleFlag(cellIndex)
            } catch (e) {
                console.error("Error processing flag action:", e)
            }
            break

        case "revealConnected":
            try {
                GridBridge.performRevealConnectedCells(cellIndex, NetworkManager.hostName)
            } catch (e) {
                console.error("Error processing revealConnected action:", e)
            }
            break

        case "approveReveal":
            GridBridge.performReveal(cellIndex, NetworkManager.clientName)
            break

        case "startGame":
            ComponentsContext.privateSessionPopupVisible = false
            break

        case "gameOver":
            GameState.gameOver = true
            GameState.gameWon = cellIndex === 1
            GameTimer.stop()

            if (GameState.gameWon) {
                AudioEngine.playWin()
                if (UserSettings.rumble) {
                    SteamIntegration.triggerRumble(1, 1, 0.5)
                }
            } else {
                AudioEngine.playLoose()
                if (UserSettings.rumble) {
                    SteamIntegration.triggerRumble(1, 1, 0.5)
                }

                GridBridge.revealAllMines()
            }

            GameState.displayPostGame = true
            break

        case "resetGame":
            GameState.displayPostGame = false
            GameState.difficultyChanged = false

            minesInitialized = false
            allowClientReveal = false
            pendingActions = []
            isProcessingNetworkAction = false
            cellOwnership = ([])

            try {
                GridBridge.performInitGame()
            } catch (e) {
                console.error("Error resetting game:", e)
                GridBridge.initGame()
            }
            break

        case "unlockCoopAchievement":
            if (SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost) {
                const difficulty = GameState.getDifficultyLevel()
                if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
                    SteamIntegration.unlockAchievement("ACH_WIN_COOP")
                }
            }
            break

        case "sendHint":
            try {
                const hintData = JSON.parse(cellIndex)

                if (hintData && hintData.cell !== undefined) {
                    GridBridge.withCell(hintData.cell, function(cell) {
                        if (cell && typeof cell.highlightHint === 'function') {
                            cell.highlightHint()
                        } else {
                            console.warn("Cannot highlight hint for cell", hintData.cell)
                        }
                    })

                    if (hintData.explanation) {
                        GridBridge.botMessageSent(hintData.explanation)
                    }
                }
            } catch (e) {
                GridBridge.withCell(cellIndex, function(cell) {
                    if (cell && typeof cell.highlightHint === 'function') {
                        cell.highlightHint()
                    } else {
                        console.warn("Cannot highlight hint for cell", cellIndex)
                    }
                })
            }
            GameState.currentHintCount++
            isProcessingNetworkAction = false
            break

        case "ping":
            showPingAtCell(cellIndex)
            isProcessingNetworkAction = false
            break

        case "resetMultiplayerGrid":
            //ComponentsContext.privateSessionPopupVisible = true
            minesInitialized = false
            clientReadyForActions = false
            clientGridReady = false
            allowClientReveal = false
            pendingActions = []
            isProcessingNetworkAction = false
            cellOwnership = ([])

            GameState.difficultyChanged = true
            GridBridge.initGame()

            SteamIntegration.sendGameAction("gridResetAck", 0)
            break

        case "prepareDifficultyChange":
            if (cellIndex >= 0 && cellIndex < GameState.difficultySettings.length) {
                UserSettings.difficulty = cellIndex

                const difficultySet = GameState.difficultySettings[cellIndex]
                GameState.gridSizeX = difficultySet.x
                GameState.gridSizeY = difficultySet.y
                GameState.mineCount = difficultySet.mines
                GameState.difficultyChanged = true
                GridBridge.cellsCreated = 0

                minesInitialized = false
                clientReadyForActions = false
                clientGridReady = false
                sessionRunning = false
                pendingActions = []
                isProcessingNetworkAction = false
                cellOwnership = ([])

                GridBridge.initGame()
            } else {
                console.error("Received invalid difficulty index:", cellIndex)
            }
            break

        case "connectionTestResponse":
            break

        case "bombClickedBy":
            GameState.bombClickedBy = cellIndex
            isProcessingNetworkAction = false
            break

        default:
            console.error("Client received unknown action type:", actionType)
        }

        isProcessingNetworkAction = false
    }

    function handleMultiplayerReveal(index, playerIdentifier) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false
        }

        if (SteamIntegration.isHost) {
            const cell = GridBridge.getCell(index)
            if (!cell || cell.revealed || cell.flagged) {
                return true
            }

            GridBridge.performReveal(index, playerIdentifier || NetworkManager.hostName)
            if (playerIdentifier === SteamIntegration.playerName) {
                SteamIntegration.sendGameAction("reveal", index)
            } else {
                SteamIntegration.sendGameAction("approveReveal", index)
            }

        } else {
            SteamIntegration.sendGameAction("reveal", index)
        }

        return true
    }

    function handleMultiplayerRevealConnected(index) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false
        }

        if (SteamIntegration.isHost) {
            GridBridge.performRevealConnectedCells(index, NetworkManager.hostName)
            sendCellUpdateToClient(index, "revealConnected")
        } else {
            SteamIntegration.sendGameAction("revealConnected", index)
            GridBridge.performRevealConnectedCells(index, NetworkManager.clientName)
        }

        return true
    }

    function handleMultiplayerToggleFlag(index, isClientRequest = false) {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false
        }

        if (SteamIntegration.isHost) {
            if (checkCellOwnership(index, isClientRequest)) {
                GridBridge.performToggleFlag(index)
                sendCellUpdateToClient(index, "flag")
            } else if (isClientRequest) {
                SteamIntegration.sendGameAction("flagDenied", index)
            }
        } else {
            SteamIntegration.sendGameAction("flag", index)
        }

        return true
    }

    function handleMultiplayerHintRequest() {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false
        }

        if (SteamIntegration.isHost) {
            GridBridge.processHintRequest()
        } else {
            SteamIntegration.sendGameAction("requestHint", 0)
        }

        return true
    }

    function initializeMultiplayerGame(firstClickIndex) {
        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
            clientReadyForActions = false
            pendingInitialActions = []

            if (!connectionIsHealthy) {
                SteamIntegration.testConnection()

                const initGameTimer = Qt.createQmlObject(
                                        'import QtQuick; Timer { interval: 3000; running: true; repeat: false; }',
                                        Qt.application, "initGameTimer")

                initGameTimer.triggered.connect(function() {
                    if (connectionIsHealthy) {
                        sendMinesListToClient()
                        if (firstClickIndex !== undefined) {
                            pendingInitialActions.push({type: "reveal", index: firstClickIndex})
                        }

                        Qt.callLater(function() {
                            SteamIntegration.sendGameAction("minesReady", 0)
                        })
                    }

                    initGameTimer.destroy()
                })

                return true
            }

            minesInitialized = true
            sendMinesListToClient()

            if (firstClickIndex !== undefined) {
                pendingInitialActions.push({type: "reveal", index: firstClickIndex})
            }

            Qt.callLater(function() {
                SteamIntegration.sendGameAction("minesReady", 0)
            })

            return true
        }

        return false
    }

    function onFirstReveal(index) {
        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
            pendingInitialActions.push({type: "reveal", index: index})
            return true
        }

        return false
    }

    function onGameWon() {
        if (!SteamIntegration.isInMultiplayerGame) {
            return false
        }

        if (SteamIntegration.isHost) {
            for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                const cell = GridBridge.getCell(i)
                if (cell && cell.revealed && !GameState.mines.includes(i)) {
                    sendCellUpdateToClient(i, "finalReveal")
                }
            }

            const gameStats = {
                hostRevealed: GameState.hostRevealed,
                clientRevealed: GameState.clientRevealed,
                firstClickRevealed: GameState.firstClickRevealed
            }

            Qt.callLater(function() {
                SteamIntegration.sendGameAction("gameOver", 1)

                SteamIntegration.sendGameState({
                                                   action: "gameStats",
                                                   stats: gameStats
                                               })
            })
        }

        const difficulty = GameState.getDifficultyLevel()
        if (difficulty === "medium" || difficulty === "hard" || difficulty === "retr0") {
            SteamIntegration.unlockAchievement("ACH_WIN_COOP")
            if (SteamIntegration.isHost) {
                SteamIntegration.sendGameAction("unlockCoopAchievement", 0)
            }
        }

        return true
    }

    function onGameLost(lastClickedIndex) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return false
        }

        sendCellUpdateToClient(lastClickedIndex, "finalReveal")

        Qt.callLater(function() {
            SteamIntegration.sendGameAction("bombClickedBy", GameState.bombClickedBy || "unknown")

            Qt.callLater(function() {
                SteamIntegration.sendGameAction("gameOver", 0)
            })
        })

        return true
    }

    function changeDifficulty(difficultyIndex) {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return false
        }

        UserSettings.difficulty = difficultyIndex
        const difficultySet = GameState.difficultySettings[difficultyIndex]
        SteamIntegration.sendGameAction("prepareDifficultyChange", difficultyIndex)

        Qt.callLater(function() {
            sessionRunning = false
            minesInitialized = false
            clientReadyForActions = false
            clientGridReady = false
            pendingInitialActions = []
            pendingActions = []

            GameState.gridSizeX = difficultySet.x
            GameState.gridSizeY = difficultySet.y
            GameState.mineCount = difficultySet.mines
            GridBridge.initGame()

            syncGridSettingsToClient()
        })

        return true
    }

    function resetMultiplayerGrid() {
        if (!SteamIntegration.isInMultiplayerGame || !SteamIntegration.isHost) {
            return
        }

        //ComponentsContext.privateSessionPopupVisible = true
        minesInitialized = false
        clientReadyForActions = false
        clientGridReady = false
        pendingInitialActions = []
        pendingActions = []
        isProcessingNetworkAction = false
        cellOwnership = ([])

        GameState.difficultyChanged = true
        GridBridge.initGame()

        SteamIntegration.sendGameAction("resetMultiplayerGrid", 0)

        Qt.callLater(function() {
            syncGridSettingsToClient()
        })
    }

    function checkCellOwnership(cellIndex, isClientRequest) {
        const player = isClientRequest ? "client" : "host"
        const currentTime = new Date().getTime()
        const ownershipData = cellOwnership[cellIndex]

        if (!ownershipData) {
            setCellOwnership(cellIndex, player)
            return true
        }

        if (currentTime - ownershipData.timestamp > 1000) {
            setCellOwnership(cellIndex, player)
            return true
        }

        if (ownershipData.owner === player) {
            setCellOwnership(cellIndex, player)
            return true
        }

        return false
    }

    function setCellOwnership(cellIndex, player) {
        cellOwnership[cellIndex] = {
            owner: player,
            timestamp: new Date().getTime()
        }
    }
}

