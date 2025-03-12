pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

QtObject {
    id: autoplayManager

    property bool autoPlayRunning: false
    property Timer autoPlayTimer: Timer {
        interval: 1
        repeat: false
        onTriggered: autoplayManager.performNextAutoplayAction()
    }

    property Timer restartGameTimer: Timer {
        interval: 500
        repeat: false
        onTriggered: {
            console.log("Autoplay: Restarting game");
            // Reset the game state
            GameState.displayPostGame = false;
            GridBridge.initGame();

            autoplayManager.gameStatePoller.restart();
            autoplayManager.autoPlayTimer.interval = 800;
            autoplayManager.autoPlayTimer.start();
        }
    }

    // Set up polling to check game state
    property Timer gameStatePoller: Timer {
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            if (GameState.gameOver && autoplayManager.autoPlayRunning) {
                console.log("Autoplay: Game over detected, restarting soon");
                // Pause polling while restarting
                stop();
                // Schedule restart
                autoplayManager.restartGameTimer.start();
            }
        }
    }

    property Timer gridReadyTimer: Timer {
        interval: 200
        repeat: true
        running: false
        onTriggered: {
            if (GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY)) {
                console.log("Autoplay: Grid is ready, starting play");
                stop();
                autoplayManager.performNextAutoplayAction();
            }
        }
    }

    function startAutoPlay() {
        if (autoPlayRunning) return;
        autoPlayRunning = true;
        console.log("Autoplay: Started");

        if (GameState.gameOver) {
            console.log("Autoplay: Game was over, restarting");
            GameState.displayPostGame = false;
            GridBridge.initGame();
            gridReadyTimer.start();
        } else {
            performNextAutoplayAction();
        }

        gameStatePoller.start();
    }

    function stopAutoPlay() {
        if (!autoPlayRunning) return;
        autoPlayRunning = false;
        console.log("Autoplay: Stopped");

        autoPlayTimer.stop();
        restartGameTimer.stop();
        gameStatePoller.stop();
        gridReadyTimer.stop();
    }

    function performNextAutoplayAction() {
        if (!autoPlayRunning) return;

        if (GameState.gameOver) {
            console.log("Autoplay: Game is over, waiting for restart");
            return;
        }

        if (!GameState.gameStarted) {
            const totalCells = GameState.gridSizeX * GameState.gridSizeY;
            const randomIndex = Math.floor(Math.random() * totalCells);

            console.log("Autoplay: Revealing initial random cell:", randomIndex);
            GridBridge.reveal(randomIndex);

            autoPlayTimer.interval = 1000;
            autoPlayTimer.start();
            return;
        }

        const revealed = [];
        const flagged = [];

        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
            const cell = GridBridge.getCell(i);
            if (!cell) continue;

            if (cell.revealed) revealed.push(i);
            if (cell.flagged) flagged.push(i);
        }

        const hintCell = GameLogic.findMineHint(revealed, flagged);

        if (hintCell !== -1) {
            const isMine = GameState.mines.includes(hintCell);

            const cell = GridBridge.getCell(hintCell);
            if (cell) {
                if (isMine) {
                    console.log("Autoplay: Flagging mine at:", hintCell);
                    GridBridge.toggleFlag(hintCell);
                } else {
                    console.log("Autoplay: Revealing safe cell at:", hintCell);
                    GridBridge.reveal(hintCell);
                }
            }

            autoPlayTimer.interval = 1;
            autoPlayTimer.start();
        } else {
            console.log("Autoplay: No hint available, waiting for game over");
            autoPlayTimer.interval = 500;
            autoPlayTimer.start();
        }
    }
}
