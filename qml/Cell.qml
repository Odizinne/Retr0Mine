import QtQuick
import QtQuick.Controls.impl
import QtQuick.Controls
import net.odizinne.retr0mine 1.0

Item {
    id: cellItem
    width: GameState.cellSize
    height: GameState.cellSize
    row: Math.floor(index / GameState.gridSizeX)
    col: index % GameState.gridSizeX
    opacity: 1
    enabled: !(GridBridge.isProcessingNetworkAction && !SteamIntegration.isHost) && !GameState.isGeneratingGrid
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

    function highlightHint() {
        hintAnimation.start();
    }

    Component.onCompleted: {
        row = Math.floor(index / GameState.gridSizeX)
        col = index % GameState.gridSizeX
        diagonalSum = row + col

        GridBridge.cellsCreated++
        if (GridBridge.cellsCreated === GameState.gridSizeX * GameState.gridSizeY && !GameState.gridFullyInitialized) {
            GameState.gridFullyInitialized = true
            Qt.callLater(function() {
                ComponentsContext.allCellsReady()
            })
        }

        if (GameSettings.animations && !GridBridge.initialAnimationPlayed && !GameState.blockAnim && !GameState.difficultyChanged) {
            startGridResetAnimation()
        }
    }

    NumberAnimation {
        id: hintRevealFadeIn
        target: hintOverlay
        property: "opacity"
        from: 0
        to: 1
        duration: 200
    }

    NumberAnimation {
        id: hintRevealFadeOut
        target: hintOverlay
        property: "opacity"
        from: 1
        to: 0
        duration: 200
    }

    SequentialAnimation {
        id: hintAnimation
        loops: 3
        running: false
        onStarted: hintRevealFadeIn.start()
        onFinished: hintRevealFadeOut.start()

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
        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
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

    Button {
        id: cellButton
        anchors.fill: parent
        anchors.margins: GameState.cellSpacing / 2

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
                } else {
                    cellItem.shouldBeFlat = false
                    cellButton.opacity = 1
                    cellButton.flat = false
                }
            }
        }

        IconImage {
            anchors.centerIn: parent
            source: "qrc:/icons/bomb.png"
            color: GameConstants.foregroundColor
            visible: cellItem.revealed && GameState.mines.includes(cellItem.index)
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
        }

        IconImage {
            anchors.centerIn: parent
            source: "qrc:/icons/questionmark.png"
            color: GameConstants.foregroundColor
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
            opacity: cellItem.questioned ? 1 : 0
            scale: cellItem.questioned ? 1 : 1.3

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

        IconImage {
            anchors.centerIn: parent
            source: "qrc:/icons/questionmark.png"
            color: "green"
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
            opacity: cellItem.safeQuestioned ? 1 : 0
            scale: cellItem.safeQuestioned ? 1 : 1.3

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

        IconImage {
            anchors.centerIn: parent
            source: GameState.flagPath
            color: {
                if (GameSettings.contrastFlag) return GameConstants.foregroundColor
                else return GameConstants.accentColor
            }
            sourceSize.width: cellItem.width / 1.8
            sourceSize.height: cellItem.height / 1.8
            opacity: cellItem.flagged ? 1 : 0
            scale: cellItem.flagged ? 1 : 1.3

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

        Image {
            id: hintOverlay
            anchors.centerIn: parent
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
            opacity: 0
            visible: !cellItem.flagged && !cellItem.questioned && !cellItem.revealed
            source: GameState.mines.includes(cellItem.index) ? "qrc:/icons/warning.png" : "qrc:/icons/safe.png"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            function handleCellClick(mouse) {
                if (!GameState.gameStarted) {
                    GridBridge.reveal(cellItem.index);
                    return;
                }

                if (cellItem.revealed) {
                    GridBridge.revealConnectedCells(cellItem.index);
                    return;
                }

                const canReveal = !cellItem.flagged && !cellItem.questioned && !cellItem.safeQuestioned;
                const isRevealClick = GameSettings.invertLRClick ? mouse.button === Qt.RightButton : mouse.button === Qt.LeftButton;

                if (isRevealClick && canReveal) {
                    GridBridge.reveal(cellItem.index);
                } else if (!isRevealClick) {
                    GridBridge.toggleFlag(cellItem.index);
                }
            }

            onClicked: (mouse) => handleCellClick(mouse)
        }
    }

    Text {
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
    }

    function startGridResetAnimation() {
        if (!GameSettings.animations) {
            opacity = 1
            return
        }

        switch (GameSettings.gridResetAnimationIndex) {
        case 0: // Original diagonal animation
            GridBridge.initialAnimationPlayed = false
            opacity = 0
            fadeTimer.restart()
            break

        case 1: // New fade out -> fade in animation
            GridBridge.initialAnimationPlayed = false
            opacity = 0
            resetFadeOutAnimation.start()
            break

        case 2: // Spin animation
            GridBridge.initialAnimationPlayed = false
            opacity = 1
            resetSpinAnimation.start()
            break
        }
    }

    ParallelAnimation {
        id: resetSpinAnimation

        // Spin animation (full duration)
        NumberAnimation {
            target: cellItem
            property: "rotation"
            from: 0
            to: 360
            duration: 900
            easing.type: Easing.InOutQuad
        }

        // Scale animations in sequence
        SequentialAnimation {
            // Scale down for first 1/3
            NumberAnimation {
                target: cellItem
                property: "scale"
                from: 1.0
                to: 0.5
                duration: 300  // ~1/3 of 2000
                easing.type: Easing.InOutQuad
            }
            // Stay at 0.5 for middle 1/3
            PauseAnimation {
                duration: 300
            }
            // Scale up for last 1/3
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

    // First fade out
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

    // Then fade in
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
