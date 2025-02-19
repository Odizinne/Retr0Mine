import QtQuick
import QtQuick.Controls.impl
import QtQuick.Controls

Item {
    id: cellItem
    required property var root
    required property var settings
    required property var colors
    required property var audioEngine
    required property int index
    required property var grid
    required property string numberFont

    property bool revealed: false
    property bool flagged: false
    property bool questioned: false
    property bool safeQuestioned: false
    property bool isBombClicked: false
    property bool animatingReveal: false
    property bool shouldBeFlat: false
    property int row: 0
    property int col: 0
    property int diagonalSum: row + col

    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }

    function highlightHint() {
        hintAnimation.start();
    }

    Component.onCompleted: {
        grid.cellsCreated++

        if (grid.cellsCreated === cellItem.root.gridSizeX * cellItem.root.gridSizeY) {
            cellItem.root.gridFullyInitialized = true
            cellItem.root.startInitialLoadTimer()
        }

        if (cellItem.settings.animations && !grid.initialAnimationPlayed && !cellItem.root.blockAnim) {
            startFadeIn()
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
            if (cellItem.settings.animations) {
                fadeAnimation.start()
            }
        }
    }

    Rectangle {
        anchors.fill: cellButton
        border.width: 2
        radius: cellItem.root.mainWindow.isFluent ? 4 : (cellItem.root.isUniversal ? 0 : 3)
        border.color: cellItem.colors.frameColor
        visible: {
            if (cellItem.revealed && cellItem.isBombClicked && cellItem.root.mines.includes(cellItem.index))
                return true
            if (cellItem.animatingReveal && cellItem.settings.cellFrame)
                return true
            return cellButton.flat && cellItem.settings.cellFrame
        }
        color: {
            if (cellItem.revealed && cellItem.isBombClicked && cellItem.root.mines.includes(cellItem.index))
                return sysPalette.accent
            return "transparent"
        }

        Behavior on opacity {
            enabled: cellItem.settings.animations
            NumberAnimation { duration: 200 }
        }

        opacity: {
            if (!cellItem.settings.dimSatisfied || !cellItem.revealed) return 1
            if (cellItem.revealed && cellItem.isBombClicked && cellItem.root.mines.includes(cellItem.index)) return 1
            return cellItem.root.hasUnrevealedNeighbors(cellItem.index) ? 1 : 0.5
        }
    }

    Button {
        id: cellButton
        anchors.fill: parent
        anchors.margins: cellItem.root.cellSpacing / 2

        Connections {
            target: cellItem
            function onRevealedChanged() {
                if (cellItem.revealed) {
                    if (cellItem.settings.animations) {
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
            color: cellItem.colors.foregroundColor
            visible: cellItem.revealed && cellItem.root.mines.includes(cellItem.index)
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
        }

        IconImage {
            anchors.centerIn: parent
            source: "qrc:/icons/questionmark.png"
            color: cellItem.colors.foregroundColor
            sourceSize.width: cellItem.width / 2.1
            sourceSize.height: cellItem.height / 2.1
            opacity: cellItem.questioned ? 1 : 0
            scale: cellItem.questioned ? 1 : 1.3

            Behavior on opacity {
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
                OpacityAnimator {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on scale {
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
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
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
                OpacityAnimator {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on scale {
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }
        }

        IconImage {
            anchors.centerIn: parent
            source: cellItem.root.flagPath
            color: {
                if (cellItem.settings.contrastFlag) return cellItem.colors.foregroundColor
                else return sysPalette.accent
            }
            sourceSize.width: cellItem.width / 1.8
            sourceSize.height: cellItem.height / 1.8
            opacity: cellItem.flagged ? 1 : 0
            scale: cellItem.flagged ? 1 : 1.3

            Behavior on opacity {
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
                OpacityAnimator {
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on scale {
                enabled: cellItem.settings.animations && !cellItem.root.noAnimReset
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
            source: cellItem.root.mines.includes(cellItem.index) ? "qrc:/icons/warning.png" : "qrc:/icons/safe.png"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                           if (!cellItem.root.gameStarted) {
                               cellItem.root.reveal(cellItem.index);
                           } else if (cellItem.revealed) {
                               cellItem.root.revealConnectedCells(cellItem.index);
                           } else {
                               if (cellItem.settings.invertLRClick) {
                                   if (mouse.button === Qt.RightButton && !cellItem.flagged && !cellItem.questioned && !cellItem.safeQuestioned) {
                                       cellItem.root.reveal(cellItem.index);
                                   } else if (mouse.button === Qt.LeftButton) {
                                       cellItem.root.toggleFlag(cellItem.index);
                                   }
                               } else {
                                   if (mouse.button === Qt.LeftButton && !cellItem.flagged && !cellItem.questioned && !cellItem.safeQuestioned) {
                                       cellItem.root.reveal(cellItem.index);
                                   } else if (mouse.button === Qt.RightButton) {
                                       cellItem.root.toggleFlag(cellItem.index);
                                   }
                               }
                           }
                       }
        }
    }

    Text {
        anchors.centerIn: parent
        text: {
            if (!cellItem.revealed || cellItem.flagged) return ""
            if (cellItem.root.mines.includes(cellItem.index)) return ""
            return cellItem.root.numbers[cellItem.index] === undefined || cellItem.root.numbers[cellItem.index] === 0 ? "" : cellItem.root.numbers[cellItem.index];
        }
        font.family: cellItem.numberFont
        font.pixelSize: cellItem.root.cellSize * 0.60
        //font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: {
            if (!cellItem.settings.dimSatisfied || !cellItem.revealed || cellItem.root.numbers[cellItem.index] === 0) return 1
            return cellItem.root.hasUnrevealedNeighbors(cellItem.index) ? 1 : 0.25
        }

        Behavior on opacity {
            enabled: cellItem.settings.animations
            NumberAnimation { duration: 200 }
        }

        color: {
            if (!cellItem.revealed) return "black"
            if (cellItem.root.mines.includes(cellItem.index)) return "transparent"

            let palette = {}
            switch (cellItem.settings.colorBlindness) {
            case 1: // Deuteranopia
                palette = {
                    1: "#377eb8",
                    2: "#4daf4a",
                    3: "#e41a1c",
                    4: "#984ea3",
                    5: "#ff7f00",
                    6: "#a65628",
                    7: "#f781bf",
                    8: cellItem.colors.foregroundColor
                }
                break
            case 2: // Protanopia
                palette = {
                    1: "#66c2a5",
                    2: "#fc8d62",
                    3: "#8da0cb",
                    4: "#e78ac3",
                    5: "#a6d854",
                    6: "#ffd92f",
                    7: "#e5c494",
                    8: cellItem.colors.foregroundColor
                }
                break
            case 3: // Tritanopia
                palette = {
                    1: "#e41a1c",
                    2: "#377eb8",
                    3: "#4daf4a",
                    4: "#984ea3",
                    5: "#ff7f00",
                    6: "#f781bf",
                    7: "#a65628",
                    8: cellItem.colors.foregroundColor
                }
                break
            default: // None
                palette = {
                    1: "#069ecc",
                    2: "#28d13c",
                    3: "#d12844",
                    4: "#9328d1",
                    5: "#ebc034",
                    6: "#34ebb1",
                    7: "#eb8634",
                    8: cellItem.colors.foregroundColor
                }
            }

            return palette[cellItem.root.numbers[cellItem.index]] || "black"
        }
    }

    function startFadeIn() {
        if (!cellItem.settings.animations) {
            opacity = 1
            return
        }

        if (!cellItem.root.isSteamEnabled) {
            grid.initialAnimationPlayed = false
            opacity = 0
            fadeTimer.restart()
            return
        }

        switch (cellItem.settings.gridResetAnimationIndex) {
        case 0: // Original diagonal animation
            grid.initialAnimationPlayed = false
            opacity = 0
            fadeTimer.restart()
            break

        case 1: // New fade out -> fade in animation
            grid.initialAnimationPlayed = false
            opacity = 0
            resetFadeOutAnimation.start()
            break

        case 2: // Spin animation
            grid.initialAnimationPlayed = false
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
