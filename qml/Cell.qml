pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

Item {
    id: cellItem
    width: GameState.cellSize
    height: GameState.cellSize
    row: Math.floor(index / GameState.gridSizeX)
    col: index % GameState.gridSizeX
    opacity: 1
    property alias button: cellButton
    required property int index

    property bool revealed: false
    property bool flagged: false
    property bool questioned: false
    property bool safeQuestioned: false
    property bool isBombClicked: false
    property bool animatingReveal: false
    property bool shouldBeFlat: false
    property int row
    property int col
    property int diagonalSum
    property bool inCooldown: false
    property bool localPlayerOwns: false
    property bool shakeConditionsMet: false

    // Animation state tracking
    property bool animatingFlag: false
    property bool animatingQuestion: false
    property bool animatingSafeQuestion: false

    Connections {
        target: GameState
        function onGameOverChanged() {
            pingCooldown.stop()
        }
    }

    function highlightHint() {
        hintAnimation.start();
    }

    function updateShakeState() {
        if (!GameSettings.shakeUnifinishedNumbers) {
            shakeConditionsMet = false;
            return;
        }

        let shouldShakeNew = false;

        if (cellItem.revealed && !GameState.mines.includes(cellItem.index)) {
            const numValue = GameState.numbers && GameState.numbers[cellItem.index];
            if (numValue > 0) {
                const flaggedNeighbors = GridBridge.getNeighborFlagCount(cellItem.index);

                let hasUnrevealed = false;
                let row = Math.floor(cellItem.index / GameState.gridSizeX);
                let col = cellItem.index % GameState.gridSizeX;

                for (let r = -1; r <= 1; r++) {
                    for (let c = -1; c <= 1; c++) {
                        if (r === 0 && c === 0) continue;

                        let newRow = row + r;
                        let newCol = col + c;

                        if (newRow < 0 || newRow >= GameState.gridSizeY ||
                            newCol < 0 || newCol >= GameState.gridSizeX) continue;

                        const adjacentIndex = newRow * GameState.gridSizeX + newCol;
                        const adjacentCell = GridBridge.getCell(adjacentIndex);

                        if (adjacentCell && !adjacentCell.revealed && !adjacentCell.flagged) {
                            hasUnrevealed = true;
                            break;
                        }
                    }
                    if (hasUnrevealed) break;
                }

                shouldShakeNew = (flaggedNeighbors === numValue && hasUnrevealed);
            }
        }

        shakeConditionsMet = shouldShakeNew;
    }

    onFlaggedChanged: {
        if (flagged) {
            animatingFlag = true;
            flagAnimTimer.restart();
        } else {
            if (GameSettings.animations) {
                flagRemovalTimer.start();
            } else {
                localPlayerOwns = false;
                animatingFlag = false;
            }
        }
        Qt.callLater(updateShakeState);
    }

    onQuestionedChanged: {
        if (questioned) {
            animatingQuestion = true;
            questionAnimTimer.restart();
        } else if (GameSettings.animations) {
            questionFadeOutTimer.restart();
        } else {
            animatingQuestion = false;
        }
    }

    onSafeQuestionedChanged: {
        if (safeQuestioned) {
            animatingSafeQuestion = true;
            safeQuestionAnimTimer.restart();
        } else if (GameSettings.animations) {
            safeQuestionFadeOutTimer.restart();
        } else {
            animatingSafeQuestion = false;
        }
    }

    // Animation timers
    Timer {
        id: flagAnimTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!cellItem.flagged) {
                cellItem.animatingFlag = false;
            }
        }
    }

    Timer {
        id: flagRemovalTimer
        interval: 350
        repeat: false
        onTriggered: {
            cellItem.localPlayerOwns = false;
            cellItem.animatingFlag = false;
        }
    }

    Timer {
        id: questionAnimTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!cellItem.questioned) {
                cellItem.animatingQuestion = false;
            }
        }
    }

    Timer {
        id: questionFadeOutTimer
        interval: 350
        repeat: false
        onTriggered: {
            cellItem.animatingQuestion = false;
        }
    }

    Timer {
        id: safeQuestionAnimTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!cellItem.safeQuestioned) {
                cellItem.animatingSafeQuestion = false;
            }
        }
    }

    Timer {
        id: safeQuestionFadeOutTimer
        interval: 350
        repeat: false
        onTriggered: {
            cellItem.animatingSafeQuestion = false;
        }
    }

    Connections {
        target: GameState
        function onFlaggedCountChanged() {
            cellItem.updateShakeState();
        }
        function onGameStartedChanged() {
            cellItem.updateShakeState();
        }
        function onRevealedCountChanged() {
            cellItem.updateShakeState();
        }
    }

    Component.onCompleted: {
        row = Math.floor(index / GameState.gridSizeX)
        col = index % GameState.gridSizeX
        diagonalSum = row + col

        GridBridge.cellsCreated++
        if (GridBridge.cellsCreated === GameState.gridSizeX * GameState.gridSizeY) {
            Qt.callLater(function() {
                ComponentsContext.allCellsReady()
            })
        }

        if (GameSettings.animations && !GridBridge.initialAnimationPlayed && !GameState.blockAnim && !GameState.difficultyChanged) {
            startGridResetAnimation()
        }

        Qt.callLater(updateShakeState);
    }

    // Hint animation handling
    Timer {
        id: hintFadeOutTimer
        interval: 250
        onTriggered: {
            hintLoader.active = false;
        }
    }

    NumberAnimation {
        id: hintRevealFadeIn
        target: hintLoader.item
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    NumberAnimation {
        id: hintRevealFadeOut
        target: hintLoader.item
        property: "opacity"
        from: 1
        to: 0
        duration: 200
    }

    SequentialAnimation {
        id: hintAnimation
        loops: 3
        running: false
        onStarted: {
            hintLoader.active = true;
            hintRevealFadeIn.start()
        }
        onFinished: {
            hintRevealFadeOut.start();
            hintFadeOutTimer.start();
        }

        SequentialAnimation {
            PropertyAnimation {
                target: cellButton
                property: "scale"
                to: 1.2
                duration: 300
                easing.type: Easing.InOutQuad
            }
            PropertyAnimation {
                target: cellButton
                property: "scale"
                to: 1.0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
    }

    NumberAnimation {
        id: fadeAnimation
        target: cellItem
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    NumberAnimation {
        id: revealFadeAnimation
        target: cellButton
        property: "opacity"
        from: 1
        to: 0
        duration: 200
        easing.type: Easing.Linear
        onStarted: cellItem.animatingReveal = true
        onFinished: {
            cellItem.animatingReveal = false
            cellButton.flat = cellItem.shouldBeFlat
            cellButton.opacity = 1
        }
    }

    Timer {
        id: fadeTimer
        interval: cellItem.diagonalSum * 20
        repeat: false
        onTriggered: {
            if (GameSettings.animations) {
                fadeAnimation.start()
            }
        }
    }

    Rectangle {
        anchors.fill: cellButton
        border.width: 2
        radius: GameCore.isFluent ? 4 : 0
        border.color: GameConstants.frameColor
        visible: {
            if (cellItem.revealed && cellItem.isBombClicked && GameState.mines.includes(cellItem.index))
                return true
            if (cellItem.animatingReveal && GameSettings.cellFrame)
                return true
            return cellButton.flat && GameSettings.cellFrame
        }
        color: {
            if (cellItem.revealed && cellItem.isBombClicked && GameState.mines.includes(cellItem.index))
                return GameConstants.accentColor
            return "transparent"
        }

        Behavior on opacity {
            enabled: GameSettings.animations
            NumberAnimation { duration: 200 }
        }

        opacity: {
            if (!GameSettings.dimSatisfied || !cellItem.revealed) return 1
            if (cellItem.revealed && cellItem.isBombClicked && GameState.mines.includes(cellItem.index)) return 1
            return GridBridge.hasUnrevealedNeighbors(cellItem.index) ? 1 : GameSettings.satisfiedOpacity
        }
    }

    NfButton {
        id: cellButton
        anchors.fill: parent
        anchors.margins: GameState.cellSpacing / 2
        enabled: SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost && !NetworkManager.allowClientReveal ? false : true
        Connections {
            target: cellItem
            function onRevealedChanged() {
                if (cellItem.revealed) {
                    if (GameSettings.animations) {
                        cellItem.shouldBeFlat = true
                        revealFadeAnimation.start()
                    } else {
                        cellButton.flat = true
                    }
                    cellItem.updateShakeState()
                } else {
                    cellItem.shouldBeFlat = false
                    cellButton.opacity = 1
                    cellButton.flat = false
                }
            }
        }

        Loader {
            id: bombLoader
            anchors.centerIn: parent
            active: cellItem.revealed && GameState.mines.includes(cellItem.index)
            sourceComponent: IconImage {
                source: "qrc:/icons/bomb.png"
                color: GameConstants.foregroundColor
                width: cellItem.width / 2.1
                height: cellItem.height / 2.1
                sourceSize.width: (cellItem.width / 2.1) * 2
                sourceSize.height: (cellItem.height / 2.1) * 2
                mipmap: false
            }
        }

        Loader {
            id: flagLoader
            anchors.centerIn: parent
            active: cellItem.flagged || cellItem.animatingFlag
            sourceComponent: IconImage {
                id: flagImage
                source: GameState.flagPath
                color: {
                    if (SteamIntegration.isInMultiplayerGame && GameSettings.mpPlayerColoredFlags) {
                        if (cellItem.localPlayerOwns) {
                            return SteamIntegration.isHost ? GameConstants.localFlagColor : GameConstants.remoteFlagColor
                        } else {
                            return SteamIntegration.isHost ? GameConstants.remoteFlagColor : GameConstants.localFlagColor
                        }
                    } else {
                        if (GameSettings.contrastFlag) return GameConstants.foregroundColor
                        else return GameConstants.accentColor
                    }
                }
                width: cellItem.width / 1.8
                height: cellItem.height / 1.8
                sourceSize.width: (cellItem.width / 1.8) * 2
                sourceSize.height: (cellItem.height / 1.8) * 2
                opacity: 0
                scale: 1.3
                mipmap: false
                Component.onCompleted: {
                    opacity = Qt.binding(function() { return cellItem.flagged ? 1 : 0; })
                    scale = Qt.binding(function() { return cellItem.flagged ? 1 : 1.3; })
                }

                Behavior on opacity {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    OpacityAnimator {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        Loader {
            id: questionLoader
            anchors.centerIn: parent
            active: cellItem.questioned || cellItem.animatingQuestion
            sourceComponent: IconImage {
                id: questionImage
                source: "qrc:/icons/questionmark.png"
                color: GameConstants.foregroundColor
                width: cellItem.width / 2.1
                height: cellItem.height / 2.1
                sourceSize.width: (cellItem.width / 2.1) * 2
                sourceSize.height: (cellItem.height / 2.1) * 2
                opacity: 0
                scale: 1.3
                mipmap: false
                Component.onCompleted: {
                    opacity = Qt.binding(function() { return cellItem.questioned ? 1 : 0; })
                    scale = Qt.binding(function() { return cellItem.questioned ? 1 : 1.3; })
                }

                Behavior on opacity {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    OpacityAnimator {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        Loader {
            id: safeQuestionLoader
            anchors.centerIn: parent
            active: cellItem.safeQuestioned || cellItem.animatingSafeQuestion
            sourceComponent: IconImage {
                id: safeQuestionImage
                source: "qrc:/icons/questionmark.png"
                color: "green"
                width: cellItem.width / 2.1
                height: cellItem.height / 2.1
                sourceSize.width: (cellItem.width / 2.1) * 2
                sourceSize.height: (cellItem.height / 2.1) * 2
                opacity: 0
                scale: 1.3
                mipmap: false
                Component.onCompleted: {
                    // Create new bindings that match the original ones
                    opacity = Qt.binding(function() { return cellItem.safeQuestioned ? 1 : 0; })
                    scale = Qt.binding(function() { return cellItem.safeQuestioned ? 1 : 1.3; })
                }

                Behavior on opacity {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    OpacityAnimator {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on scale {
                    enabled: GameSettings.animations && !GameState.noAnimReset
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                    }
                }
            }
        }

        Loader {
            id: hintLoader
            anchors.centerIn: parent
            active: false
            sourceComponent: Image {
                width: cellItem.width / 2.1
                height: cellItem.height / 2.1
                sourceSize.width: (cellItem.width / 2.1) * 2
                sourceSize.height: (cellItem.height / 2.1) * 2
                mipmap: false
                opacity: 0
                visible: !cellItem.flagged && !cellItem.questioned && !cellItem.revealed
                source: GameState.mines.includes(cellItem.index) ? "qrc:/icons/warning.png" : "qrc:/icons/safe.png"
            }
        }

        MouseArea {
            id: cellMouseArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            enabled: !GameState.isGeneratingGrid
            hoverEnabled: true
            property bool isHovered: false

            function handleCellClick(mouse) {
                if (mouse.button === Qt.MiddleButton && !pingCooldown.running) {
                    NetworkManager.sendPing(cellItem.index)
                    pingCooldown.start()
                    return
                }

                if (GameState.nextClickIsSignal) {
                    GameState.nextClickIsSignal = false
                    NetworkManager.sendPing(cellItem.index)
                    pingCooldown.start()
                    return;
                }

                GridBridge.registerPlayerAction()

                const isRevealClick = GameSettings.invertLRClick ? mouse.button === Qt.RightButton : mouse.button === Qt.LeftButton;
                const isFlagClick = !isRevealClick;

                if (cellItem.inCooldown && isFlagClick) {
                    return;
                }

                if (isFlagClick && !cellItem.flagged && !cellItem.questioned) {
                    cellItem.localPlayerOwns = true;
                }

                if (!GameState.gameStarted) {
                    GridBridge.reveal(cellItem.index, "firstClick");
                    return;
                }

                if (cellItem.revealed) {
                    GridBridge.revealConnectedCells(cellItem.index, SteamIntegration.playerName);
                    return;
                }

                const canReveal = !cellItem.flagged && !cellItem.questioned && !cellItem.safeQuestioned;

                if (isRevealClick && canReveal) {
                    GridBridge.reveal(cellItem.index, SteamIntegration.playerName);
                } else if (isFlagClick) {
                    GridBridge.toggleFlag(cellItem.index);
                }
            }

            onEntered: {
                isHovered = true
            }

            onExited: {
                isHovered = false
            }

            onClicked: (mouse) => handleCellClick(mouse)
        }

        Shortcut {
            sequence: "G"
            autoRepeat: false
            enabled: cellMouseArea.isHovered && !pingCooldown.running
            onActivated: {
                NetworkManager.sendPing(cellItem.index)
                pingCooldown.start()
            }
        }

        Timer {
            id: pingCooldown
            interval: 500
            repeat: false
        }
    }

    Text {
        id: cellText
        anchors.centerIn: parent
        text: {
            if (!cellItem.revealed || cellItem.flagged) return ""
            if (GameState.mines && GameState.mines.includes(cellItem.index)) return ""
            const num = GameState.numbers && GameState.numbers[cellItem.index]
            return num === undefined || num === 0 ? "" : num
        }
        font.family: GameConstants.numberFont.name
        font.pixelSize: GameState.cellSize * 0.60
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        opacity: {
            if (!GameSettings.dimSatisfied || !cellItem.revealed) return 1
            const num = GameState.numbers && GameState.numbers[cellItem.index]
            if (num === 0) return 1
            return GridBridge.hasUnrevealedNeighbors(cellItem.index) ? 1 : GameSettings.satisfiedOpacity - 0.25
        }

        Behavior on opacity {
            enabled: GameSettings.animations
            NumberAnimation { duration: 200 }
        }

        color: GameConstants.getNumberColor(
                   cellItem.revealed,
                   GameState.mines && GameState.mines.includes(cellItem.index),
                   cellItem.index,
                   GameState.numbers && GameState.numbers[cellItem.index]
                   )

        SequentialAnimation {
            id: shakeAnimation
            running: cellItem.shakeConditionsMet && GridBridge.globalShakeActive && GameSettings.shakeUnifinishedNumbers
            loops: 3
            alwaysRunToEnd: true

            NumberAnimation {
                target: cellText
                property: "anchors.horizontalCenterOffset"
                from: 0
                to: -2
                duration: 50
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: cellText
                property: "anchors.horizontalCenterOffset"
                from: -2
                to: 2
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: cellText
                property: "anchors.horizontalCenterOffset"
                from: 2
                to: -2
                duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: cellText
                property: "anchors.horizontalCenterOffset"
                from: -2
                to: 0
                duration: 50
                easing.type: Easing.InOutQuad
            }
        }
    }

    function startGridResetAnimation() {
        if (!GameSettings.animations) {
            opacity = 1
            return
        }

        switch (GameSettings.gridResetAnimationIndex) {
        case 0:
            GridBridge.initialAnimationPlayed = false
            opacity = 0
            fadeTimer.restart()
            break

        case 1:
            GridBridge.initialAnimationPlayed = false
            opacity = 0
            resetFadeOutAnimation.start()
            break

        case 2:
            GridBridge.initialAnimationPlayed = false
            opacity = 1
            resetSpinAnimation.start()
            break
        }
    }

    ParallelAnimation {
        id: resetSpinAnimation

        NumberAnimation {
            target: cellItem
            property: "rotation"
            from: 0
            to: 360
            duration: 900
            easing.type: Easing.InOutQuad
        }

        SequentialAnimation {
            NumberAnimation {
                target: cellItem
                property: "scale"
                from: 1.0
                to: 0.5
                duration: 300
                easing.type: Easing.InOutQuad
            }
            PauseAnimation {
                duration: 300
            }
            NumberAnimation {
                target: cellItem
                property: "scale"
                from: 0.5
                to: 1.0
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }
    }

    NumberAnimation {
        id: resetFadeOutAnimation
        target: cellItem
        property: "opacity"
        from: 1
        to: 0
        duration: 300
        easing.type: Easing.InOutQuad
        onFinished: resetFadeInAnimation.start()
    }

    NumberAnimation {
        id: resetFadeInAnimation
        target: cellItem
        property: "opacity"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.OutQuad
    }
}
