import QtQuick 2.15
import QtQuick.Controls.FluentWinUI3 2.15
import QtQuick.Layouts 1.15
import QtMultimedia

ApplicationWindow {
    id: root
    visible: true
    width: (cellSize + cellSpacing) * gridSizeX + 22
    height: (cellSize + cellSpacing) * gridSizeY + 60
    minimumWidth: (cellSize + cellSpacing) * gridSizeX + 22
    minimumHeight: (cellSize + cellSpacing) * gridSizeY + 60
    maximumWidth: (cellSize + cellSpacing) * gridSizeX + 22
    maximumHeight: (cellSize + cellSpacing) * gridSizeY + 60
    title: "Retr0Mine"

    property bool playSound: soundEffects
    property int difficulty: gameDifficulty
    property bool darkMode: isDarkMode
    property bool gameOver: false
    property int revealedCount: 0
    property int flaggedCount: 0
    property int firstClickIndex: -1
    property bool gameStarted: false
    property int gridSizeX: 8
    property int gridSizeY: 8
    property int mineCount: 10
    property var mines: []
    property var numbers: []
    property bool timerActive: false
    property int elapsedTime: 0
    property int cellSize: 30
    property int cellSpacing: 2


    function formatTime(seconds) {
        let hours = Math.floor(seconds / 3600)
        let minutes = Math.floor((seconds % 3600) / 60)
        let remainingSeconds = seconds % 60

        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`
    }


    Timer {
        id: gameTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.elapsedTime++
            elapsedTimeLabel.text = root.formatTime(root.elapsedTime)
        }
    }


    Popup {
        anchors.centerIn: parent
        id: gameOverWindow
        height: 100
        width: 250
        visible: false

        GridLayout {
            anchors.fill: parent
            columns: 2
            rowSpacing: 10
            Label {
                id: gameOverLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: "Game Over :("
                Layout.columnSpan: 2
                font.bold: true
                font.pixelSize: 16
            }

            Button {
                text: "Retry"
                onClicked: {
                    gameOverWindow.close()
                    root.initGame()
                }
            }

            Button {
                text: "Close"
                onClicked: {
                    gameOverWindow.close()
                }
            }
        }
    }

    ApplicationWindow {
        id: settingsPage
        title: "Settings"
        width: 300
        height: 370
        maximumWidth: 300
        maximumHeight: 370
        minimumWidth: 300
        minimumHeight: 370
        visible: false

        property int selectedGridSizeX: 8
        property int selectedGridSizeY: 8
        property int selectedMineCount: 10

        onVisibleChanged: {
            if (settingsPage.visible) {
                // Check if there is enough space on the right side
                if (root.x + root.width + settingsPage.width + 10 <= screen.width) {
                    // Position on the right side with a 10px margin
                    settingsPage.x = root.x + root.width + 10
                } else if (root.x - settingsPage.width - 10 >= 0) {
                    // If there is no space on the right, position on the left with a 10px margin
                    settingsPage.x = root.x - settingsPage.width - 10
                } else {
                    // If the root window is too close to the left edge, use a fallback
                    settingsPage.x = screen.width - settingsPage.width - 10
                }

                // Center vertically relative to the root window
                settingsPage.y = root.y + (root.height - settingsPage.height) / 2
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 10

            ButtonGroup {

                id: difficultyGroup
                onCheckedButtonChanged: {
                    if (checkedButton === easyButton) {
                        root.gridSizeX = 8
                        root.gridSizeY = 8
                        root.mineCount = 10
                        mainWindow.saveDifficulty(0)
                    } else if (checkedButton === mediumButton) {
                        root.gridSizeX = 16
                        root.gridSizeY = 16
                        root.mineCount = 40
                        mainWindow.saveDifficulty(1)
                    } else if (checkedButton === hardButton) {
                        root.gridSizeX = 32
                        root.gridSizeY = 16
                        root.mineCount = 99
                        mainWindow.saveDifficulty(2)
                    } else if (checkedButton === retroButton) {
                        root.gridSizeX = 100
                        root.gridSizeY = 100
                        root.mineCount = 2000
                        mainWindow.saveDifficulty(3)
                    } else if (checkedButton === debugButton) {
                        root.gridSizeX = 8
                        root.gridSizeY = 8
                        root.mineCount = 1
                        mainWindow.saveDifficulty(4)
                    }
                    initGame()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 5
            anchors.bottomMargin: 15
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 4

            Label {
                text: "Difficulty"
                font.bold: true
                font.pixelSize: 18
            }

            Rectangle {
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.darkMode ? Qt.rgba (1, 1, 1, 0.15) : Qt.rgba (0, 0, 0, 0.15)
            }

            RadioButton {
                id: easyButton
                text: "Easy (8×8, 10 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 0
            }

            RadioButton {
                id: mediumButton
                text: "Medium (16×16, 40 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 1
            }

            RadioButton {
                id: hardButton
                text: "Hard (32×16, 99 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 2
            }

            RadioButton {
                id: retroButton
                enabled: false
                text: "Retr0 (100×100, 2000 mines)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 3
            }

            RadioButton {
                id: debugButton
                enabled: false
                visible: false
                text: "Debug (8×8, 1 mine)"
                ButtonGroup.group: difficultyGroup
                checked: root.difficulty === 4
            }

            Item {
                Layout.preferredHeight: 5
            }

            Label {
                //Layout.topMargin: 10
                text: "Sound"
                font.bold: true
                font.pixelSize: 18
            }

            Rectangle {
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.darkMode ? Qt.rgba (1, 1, 1, 0.15) : Qt.rgba (0, 0, 0, 0.15)
            }

            Switch {
                text: "Play sound effects"
                checked: root.playSound
                onCheckedChanged: {
                    mainWindow.saveSoundSettings(checked);
                    root.playSound = checked
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                text: "Close"
                Layout.preferredWidth: 70
                Layout.alignment: Qt.AlignRight
                onClicked: settingsPage.close()
            }
        }
    }

    SoundEffect {
        id: looseEffect
        source: "qrc:/sounds/bomb.wav"
        volume: 1
    }

    SoundEffect {
        id: clickEffect
        source: "qrc:/sounds/click.wav"
        volume: 1
    }

    SoundEffect {
        id: winEffect
        source: "qrc:/sounds/win.wav"
        volume: 1
    }

    function playLoose() {
        if (!root.playSound) return
        looseEffect.play()
    }

    function playClick() {
        if (!root.playSound) return
        if (gameOver) return
        clickEffect.play()
    }

    function playWin() {
        if (!root.playSound) return
        winEffect.play()
    }

    function isValidMinePlacement(minePositions, index) {
        let row = Math.floor(index / gridSizeX)
        let col = index % gridSizeX

        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue

                let newRow = row + r
                let newCol = col + c
                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                let pos = newRow * gridSizeX + newCol
                let hasAdjacentMine = false

                for (let dr = -1; dr <= 1; dr++) {
                    for (let dc = -1; dc <= 1; dc++) {
                        if (dr === 0 && dc === 0) continue

                        let checkRow = newRow + dr
                        let checkCol = newCol + dc
                        if (checkRow < 0 || checkRow >= gridSizeY || checkCol < 0 || checkCol >= gridSizeX) continue

                        let checkPos = checkRow * gridSizeX + checkCol
                        if (minePositions.includes(checkPos)) {
                            hasAdjacentMine = true
                            break
                        }
                    }
                    if (hasAdjacentMine) break
                }

                if (!hasAdjacentMine && !minePositions.includes(pos)) {
                    return true
                }
            }
        }
        return false
    }

    function placeMines(firstClickIndex) {
        mines = []
        let attemptCount = 0
        const maxAttempts = 1000

        let firstClickRow = Math.floor(firstClickIndex / gridSizeX)
        let firstClickCol = firstClickIndex % gridSizeX

        // Create safe zone around first click
        let safeZone = []
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                let newRow = firstClickRow + r
                let newCol = firstClickCol + c
                if (newRow >= 0 && newRow < gridSizeY && newCol >= 0 && newCol < gridSizeX) {
                    safeZone.push(newRow * gridSizeX + newCol)
                }
            }
        }

        while (mines.length < mineCount && attemptCount < maxAttempts) {
            mines = []
            attemptCount++

            for (let i = 0; i < mineCount; i++) {
                let pos
                let attempts = 0
                do {
                    pos = Math.floor(Math.random() * (gridSizeX * gridSizeY))
                    attempts++
                } while ((safeZone.includes(pos) || mines.includes(pos))
                         && attempts < 100)

                if (attempts < 100) {
                    mines.push(pos)
                } else {
                    break
                }
            }
        }

        if (mines.length !== mineCount) {
            initGame()
            return false
        }

        calculateNumbers()
        return true
    }


    function calculateNumbers() {
        numbers = []
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            if (mines.includes(i)) {
                numbers[i] = -1
                continue
            }

            let count = 0
            let row = Math.floor(i / gridSizeX)
            let col = i % gridSizeX

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    if (r === 0 && c === 0) continue

                    let newRow = row + r
                    let newCol = col + c
                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                    let pos = newRow * gridSizeX + newCol
                    if (mines.includes(pos)) count++
                }
            }
            numbers[i] = count
        }
    }

    function initGame() {
        mines = []
        numbers = []
        gameOver = false
        revealedCount = 0
        flaggedCount = 0
        firstClickIndex = -1
        gameStarted = false
        elapsedTime = 0
        gameTimer.stop()
        elapsedTimeLabel.text = "00:00:00"

        // Reset all cells
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.revealed = false
                cell.flagged = false
            }
        }
    }

    function reveal(index) {
        if (gameOver) return
        if (grid.itemAtIndex(index).revealed || grid.itemAtIndex(index).flagged) return

        if (!gameStarted) {
            firstClickIndex = index
            if (!placeMines(index)) {
                reveal(index)
                return
            }
            gameStarted = true
            gameTimer.start()
        }

        let cell = grid.itemAtIndex(index)
        cell.revealed = true
        revealedCount++

        if (mines.includes(index)) {
            gameOver = true
            gameTimer.stop()
            revealAllMines()
            playLoose()
            gameOverLabel.text = "Game over :("
            gameOverLabel.color = "#d12844"
            gameOverWindow.visible = true
            return
        }

        if (numbers[index] === 0) {
            let row = Math.floor(index / gridSizeX)
            let col = index % gridSizeX

            for (let r = -1; r <= 1; r++) {
                for (let c = -1; c <= 1; c++) {
                    if (r === 0 && c === 0) continue

                    let newRow = row + r
                    let newCol = col + c
                    if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue

                    let pos = newRow * gridSizeX + newCol
                    reveal(pos)
                }
            }
        }

        checkWin()
    }

    function revealAllMines() {
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.flagged = false
                if (mines.includes(i)) {
                    cell.revealed = true
                }
            }
        }
    }


    function checkWin() {
        if (revealedCount === (gridSizeX * gridSizeY - mineCount)) {
            gameOver = true
            gameTimer.stop()
            gameOverLabel.text = "Victory :)"
            gameOverLabel.color = "#28d13c"
            gameOverWindow.visible = true
            playWin()
        }
    }

    function toggleFlag(index) {
        if (gameOver) return
        let cell = grid.itemAtIndex(index)
        if (!cell.revealed) {
            cell.flagged = !cell.flagged
            flaggedCount += cell.flagged ? 1 : -1
        }
    }

    Component.onCompleted: {
        initGame()
    }

    ColumnLayout {
        id:topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40
        spacing: 10

        RowLayout {
            Layout.fillHeight: true
            Layout.topMargin: 5
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: root.width

            Button {
                Layout.alignment: Qt.AlignLeft
                text: "Menu"
                Layout.preferredWidth: 70
                Layout.rightMargin: -25
                onClicked: menu.open()

                Menu {
                    id: menu
                    MenuItem {
                        text: "New game"
                        onTriggered: root.initGame()
                    }
                    MenuItem {
                        text: "Settings"
                        onTriggered: settingsPage.visible = true
                    }
                    MenuItem {
                        text: "Exit"
                        onTriggered: Qt.quit()
                    }
                }

            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                id: elapsedTimeLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: "HH:MM:SS"
                color: root.darkMode ? "white" : "black"
                font.pixelSize: 18
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignRight

                Image {
                    source: root.darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: ": " + (root.mineCount - root.flaggedCount)
                    color: root.darkMode ? "white" : "black"
                    font.pixelSize: 18
                }
            }
        }
    }

    ColumnLayout {
        id: gameLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: topBar.bottom
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: (root.cellSize + root.cellSpacing) * root.gridSizeX
            Layout.preferredHeight: (root.cellSize + root.cellSpacing) * root.gridSizeY
            Layout.margins: 10

            GridView {
                id: grid
                anchors.fill: parent
                cellWidth: root.cellSize + root.cellSpacing
                cellHeight: root.cellSize + root.cellSpacing
                model: root.gridSizeX * root.gridSizeY
                interactive: false

                delegate: Item {
                    id: cellItem
                    width: cellSize
                    height: cellSize

                    property bool revealed: false
                    property bool flagged: false

                    Button {
                        anchors.fill: parent
                        anchors.margins: cellSpacing / 2
                        flat: parent.revealed

                        Rectangle {
                            anchors.fill: parent
                            border.width: 2
                            radius: 4
                            border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                            visible: parent.flat
                            color: "transparent"
                        }

                        Image {
                            anchors.centerIn: parent
                            source: darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
                            visible: cellItem.revealed && mines.includes(index)
                            sourceSize.width: cellItem.width / 2
                            sourceSize.height: cellItem.height / 2
                        }

                        Image {
                            anchors.centerIn: parent
                            source: flagIcon
                            visible: cellItem.flagged
                            sourceSize.width: cellItem.width / 2
                            sourceSize.height: cellItem.height / 2
                        }

                        text: {
                            if (!parent.revealed || parent.flagged) return ""
                            if (mines.includes(index)) return ""
                            return numbers[index] === 0 ? "" : numbers[index]
                        }

                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: parent.width * 0.5
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: {
                                if (!parent.parent.revealed) return "black"
                                if (mines.includes(index)) return "transparent"
                                if (numbers[index] === 1) return "#069ecc"
                                if (numbers[index] === 2) return "#28d13c"
                                if (numbers[index] === 3) return "#d12844"
                                if (numbers[index] === 4) return "#9328d1"
                                if (numbers[index] === 5) return "#9328d1"
                                if (numbers[index] === 6) return "#9328d1"
                                if (numbers[index] === 7) return "#9328d1"
                                if (numbers[index] === 8) return "#9328d1"
                                return "black"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                           if (mouse.button === Qt.LeftButton && !parent.flagged) {
                                               reveal(index)
                                               playClick()
                                           } else if (mouse.button === Qt.RightButton) {
                                               toggleFlag(index)
                                           }
                                       }
                        }
                    }
                }
            }
        }
    }
}
