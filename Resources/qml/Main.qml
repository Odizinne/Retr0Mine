import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia
import QtQuick.Window 2.15
import com.odizinne.minesweeper 1.0

ApplicationWindow {
    id: root
    visible: true
    width: getInitialWidth()
    height: getInitialHeight()
    minimumWidth: getInitialWidth()
    minimumHeight: getInitialHeight()
    title: "Retr0Mine"

    Connections {
        target: mainWindow
        function onLanguageChanged() {
            // Force a retranslation of the UI
            root.update()  // or whatever your root item id is
        }
    }
    onVisibleChanged: {
        if (Universal !== undefined) {
            Universal.theme = Universal.System
            Universal.accent = accentColor
        }
    }

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: Qt.quit()
    }

    Shortcut {
        sequence: StandardKey.Save
        enabled: root.gameStarted
        onActivated: saveWindow.show()
    }

    Shortcut {
        sequence: StandardKey.New
        onActivated: root.initGame()
    }

    Shortcut {
        sequence: StandardKey.Print
        onActivated: !settingsPage.visible ? settingsPage.show() : settingsPage.close()
    }

    Shortcut {
        sequence: "F11"
        onActivated: {
            if (root.visibility === 5) {
                root.visibility = ApplicationWindow.AutomaticVisibility;
            } else {
                root.visibility = 5;
            }
        }
    }

    property MinesweeperLogic gameLogic: MinesweeperLogic {}
    property int language: languageIndex
    property int theme: themeIndex
    property bool isMaximized: visibility === 4
    property bool isFullScreen: visibility === 5
    property bool isFusionTheme: fusion
    property bool isFluentWinUI3Theme: windows11
    property bool isUniversalTheme: windows10
    property bool enableAnimations: animations
    property bool revealConnected: revealConnectedCell
    property bool invertLRClick: invertClick
    property bool highContrastFlag: contrastFlag
    property bool cellFrame: showCellFrame
    property bool enableQuestionMarks: questionMarks
    property bool playSound: soundEffects
    property real soundVolume: volume
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
    property bool shouldUpdateSize: true
    property int cellSize: 35
    property int cellSpacing: 2

    function getInitialWidth() {
        return shouldUpdateSize ? Math.min((cellSize + cellSpacing) * gridSizeX + 24, Screen.width * 1) : width
    }

    function getInitialHeight() {
        return shouldUpdateSize ? Math.min((cellSize + cellSpacing) * gridSizeY + 74, Screen.height * 1) : height
    }

    onGridSizeXChanged: {
        if (!isMaximized && !isFullScreen && shouldUpdateSize) {
            minimumWidth = getInitialWidth()
            width = getInitialWidth()
        }
    }

    onGridSizeYChanged: {
        if (!isMaximized && !isFullScreen && shouldUpdateSize) {
            minimumHeight = getInitialHeight()
            height = getInitialHeight()
        }
    }

    onVisibilityChanged: {
        const wasMaximized = isMaximized
        isMaximized = visibility === Window.Maximized
        isFullScreen = visibility === Window.FullScreen
        shouldUpdateSize = !isMaximized && !isFullScreen

        if (wasMaximized && visibility === Window.Windowed) {
            shouldUpdateSize = true
            minimumWidth = getInitialWidth()
            minimumHeight = getInitialHeight()
            width = minimumWidth
            height = minimumHeight
        }
    }

    function handleVisibilityChange(newVisibility) {
        const wasMaximized = isMaximized
        isMaximized = newVisibility === Window.Maximized
        isFullScreen = newVisibility === Window.FullScreen
        shouldUpdateSize = !isMaximized && !isFullScreen

        if (wasMaximized && newVisibility === Window.Windowed) {
            shouldUpdateSize = true
            minimumWidth = getInitialWidth()
            minimumHeight = getInitialHeight()
            width = minimumWidth
            height = minimumHeight
        }
    }

    function saveGame(filename) {
        let saveData = {
            version: "1.0",
            timestamp: new Date().toISOString(),
            gameState: {
                gridSizeX: gridSizeX,
                gridSizeY: gridSizeY,
                mineCount: mineCount,
                mines: mines,
                numbers: numbers,
                revealedCells: [],
                flaggedCells: [],
                questionedCells: [],
                elapsedTime: elapsedTime,
                gameOver: gameOver,
                gameStarted: gameStarted,
                firstClickIndex: firstClickIndex
            }
        }

        // Collect revealed, flagged, and questioned cells
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell.revealed) saveData.gameState.revealedCells.push(i)
            if (cell.flagged) saveData.gameState.flaggedCells.push(i)
            if (cell.questioned) saveData.gameState.questionedCells.push(i)
        }

        mainWindow.saveGameState(JSON.stringify(saveData), filename)
    }

    function loadGame(saveData) {
        try {
            let data = JSON.parse(saveData)

            // Verify version compatibility
            if (!data.version || !data.version.startsWith("1.")) {
                console.error("Incompatible save version")
                return false
            }

            // Reset game state
            gameTimer.stop()

            // Load grid configuration
            gridSizeX = data.gameState.gridSizeX
            gridSizeY = data.gameState.gridSizeY
            mineCount = data.gameState.mineCount

            // Load game progress
            mines = data.gameState.mines
            numbers = data.gameState.numbers
            elapsedTime = data.gameState.elapsedTime
            gameOver = data.gameState.gameOver
            gameStarted = data.gameState.gameStarted
            firstClickIndex = data.gameState.firstClickIndex

            // Reset all cells first
            for (let i = 0; i < gridSizeX * gridSizeY; i++) {
                let cell = grid.itemAtIndex(i)
                if (cell) {
                    cell.revealed = false
                    cell.flagged = false
                    cell.questioned = false
                }
            }

            // Apply revealed, flagged, and questioned states
            data.gameState.revealedCells.forEach(index => {
                                                     let cell = grid.itemAtIndex(index)
                                                     if (cell) cell.revealed = true
                                                 })

            data.gameState.flaggedCells.forEach(index => {
                                                    let cell = grid.itemAtIndex(index)
                                                    if (cell) cell.flagged = true
                                                })

            // Handle questioned cells if they exist in the save data
            if (data.gameState.questionedCells) {
                data.gameState.questionedCells.forEach(index => {
                                                           let cell = grid.itemAtIndex(index)
                                                           if (cell) cell.questioned = true
                                                       })
            }

            // Update counters
            revealedCount = data.gameState.revealedCells.length
            flaggedCount = data.gameState.flaggedCells.length

            // Resume timer if game was in progress
            if (gameStarted && !gameOver) {
                gameTimer.start()
            }

            elapsedTimeLabel.text = formatTime(elapsedTime)
            return true
        } catch (e) {
            console.error("Error loading save:", e)
            return false
        }
    }

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
                text: qsTr("Retry")
                Layout.fillWidth: true
                onClicked: {
                    gameOverWindow.close()
                    root.initGame()
                }
            }

            Button {
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: {
                    gameOverWindow.close()
                }
            }
        }
    }

    ApplicationWindow {
        id: aboutPage
        width: 180
        height: 230
        minimumWidth: width
        minimumHeight: height
        maximumWidth: width
        maximumHeight: height
        title: qsTr("About")
        flags: Qt.Dialog

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/icons/icon.png"
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Retr0Mine"
                font.pixelSize: 24
                font.bold: true
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("by Odizinne")
                font.pixelSize: 14
            }

            Item {
                Layout.fillHeight: true
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Check on Github"
                highlighted: true
                onClicked: Qt.openUrlExternally("https://github.com/odizinne/Retr0Mine")
            }
        }
    }

    ApplicationWindow {
        id: settingsPage
        title: qsTr("Settings")
        width: 520
        height: 400
        minimumWidth: 520
        minimumHeight: 400
        maximumWidth: 520
        maximumHeight: 400
        visible: false
        flags: Qt.Dialog
        onVisibleChanged: {
            if (settingsPage.visible) {
                if (root.x + root.width + settingsPage.width + 10 <= screen.width) {
                    settingsPage.x = root.x + root.width + 20
                } else if (root.x - settingsPage.width - 10 >= 0) {
                    settingsPage.x = root.x - settingsPage.width - 20
                } else {
                    settingsPage.x = screen.width - settingsPage.width - 20
                }
                settingsPage.y = root.y + (root.height - settingsPage.height) / 2
            }
        }

        Popup {
            anchors.centerIn: parent
            id: restartWindow
            height: 100
            width: 300
            visible: false

            GridLayout {
                anchors.fill: parent
                columns: 2
                rowSpacing: 10
                Label {
                    id: restartLabel
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text: qsTr("Application needs to be restarted")
                    Layout.columnSpan: 2
                    font.bold: true
                    font.pixelSize: 16
                }

                Button {
                    text: qsTr("Restart")
                    Layout.fillWidth: true
                    Layout.preferredWidth: 80
                    onClicked: {
                        mainWindow.restartRetr0Mine()
                    }
                }

                Button {
                    text: qsTr("Later")
                    Layout.fillWidth: true
                    Layout.preferredWidth: 80
                    onClicked: {
                        restartWindow.visible = false
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Pane {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                padding: 0
                z: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.rightMargin: 10
                    spacing: 10

                    ListView {
                        id: sidebarList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10
                        model: [
                            {
                                text: qsTr("Difficulty"),
                                iconDark: "qrc:/icons/difficulty_dark.png",
                                iconLight: "qrc:/icons/difficulty_light.png"
                            },
                            {
                                text: qsTr("Controls"),
                                iconDark: "qrc:/icons/controls_dark.png",
                                iconLight: "qrc:/icons/controls_light.png"
                            },
                            {
                                text: qsTr("Visuals"),
                                iconDark: "qrc:/icons/visuals_dark.png",
                                iconLight: "qrc:/icons/visuals_light.png"
                            },
                            {
                                text: qsTr("Sound"),
                                iconDark: "qrc:/icons/audio_dark.png",
                                iconLight: "qrc:/icons/audio_light.png"
                            },
                            {
                                text: qsTr("Shortcuts"),
                                iconDark: "qrc:/icons/keyboard_dark.png",
                                iconLight: "qrc:/icons/keyboard_light.png"
                            },
                            {
                                text: qsTr("Language"),
                                iconDark: "qrc:/icons/language_dark.png",
                                iconLight: "qrc:/icons/language_light.png"
                            }
                        ]
                        currentIndex: 0
                        delegate: ItemDelegate {
                            width: parent.width
                            height: 40
                            highlighted: ListView.isCurrentItem
                            contentItem: RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Image {
                                    source: darkMode ? modelData.iconLight : modelData.iconDark
                                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                }
                                Label {
                                    text: modelData.text
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                                }
                            }
                            onClicked: {
                                if (sidebarList.currentIndex !== index) {
                                    sidebarList.currentIndex = index
                                    switch(index) {
                                    case 0: stackView.push(difficultyPaneComponent); break;
                                    case 1: stackView.push(controlsPaneComponent); break;
                                    case 2: stackView.push(visualsPaneComponent); break;
                                    case 3: stackView.push(soundPaneComponent); break;
                                    case 4: stackView.push(shortcutsPaneComponent); break;
                                    case 5: stackView.push(languagePaneComponent); break;
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        id: closeSettingsButton
                        Layout.fillWidth: true
                        Layout.bottomMargin: 15
                        Layout.leftMargin: 15
                        Layout.rightMargin: 15
                        Layout.preferredHeight: 30
                        text: qsTr("Close settings")
                        highlighted: true
                        onClicked: {
                            settingsPage.close()
                        }
                    }
                }
            }

            ToolSeparator {
                Layout.fillHeight: true
                Layout.leftMargin: {
                    if (isFluentWinUI3Theme) return -10
                    return 0
                }

                z: 2
            }

            StackView {
                id: stackView
                Layout.fillWidth: true
                Layout.fillHeight: true
                initialItem: difficultyPaneComponent

                Component {
                    id: difficultyPaneComponent

                    Pane {
                        id: difficultyPane

                        property var difficultySettings: [
                            { text: qsTr("Easy"), x: 8, y: 8, mines: 10 },
                            { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
                            { text: qsTr("Hard"), x: 32, y: 16, mines: 99 },
                            { text: "Retr0", x: 50, y: 32, mines: 320 }
                        ]

                        Component.onCompleted: {
                            const initialSettings = difficultySettings[root.difficulty]
                            if (initialSettings) {
                                root.gridSizeX = initialSettings.x
                                root.gridSizeY = initialSettings.y
                                root.mineCount = initialSettings.mines
                            }
                        }

                        ColumnLayout {
                            anchors.topMargin: index === 0 && !isFluentWinUI3Theme ? 10 : 0
                            spacing: isFluentWinUI3Theme ? 10 : 26
                            width: parent.width

                            ButtonGroup {
                                id: difficultyGroup
                                exclusive: true
                                onCheckedButtonChanged: {
                                    if (checkedButton && (checkedButton.userInteractionChecked || checkedButton.activeFocus)) {
                                        const idx = checkedButton.difficultyIndex
                                        const settings = difficultyPane.difficultySettings[idx]

                                        root.gridSizeX = settings.x
                                        root.gridSizeY = settings.y
                                        root.mineCount = settings.mines
                                        mainWindow.saveDifficulty(idx)
                                        initGame()
                                        root.difficulty = idx
                                    }
                                }
                            }

                            Repeater {
                                model: difficultySettings

                                RowLayout {
                                    Layout.fillWidth: true

                                    Label {
                                        text: modelData.text
                                        Layout.fillWidth: true
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: if (mouse.button === Qt.LeftButton) {
                                                           radioButton.userInteractionChecked = true
                                                       }
                                        }
                                    }

                                    Label {
                                        text: `${modelData.x}×${modelData.y}, ${modelData.mines} mines`
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: if (mouse.button === Qt.LeftButton) {
                                                           radioButton.userInteractionChecked = true
                                                       }
                                        }
                                    }

                                    RadioButton {
                                        id: radioButton
                                        property bool userInteractionChecked: false
                                        property int difficultyIndex: index
                                        Layout.preferredWidth: height
                                        Layout.alignment: Qt.AlignRight
                                        ButtonGroup.group: difficultyGroup

                                        Component.onCompleted: {
                                            checked = root.difficulty === index
                                        }

                                        onCheckedChanged: {
                                            if (checked && !userInteractionChecked) {
                                                const settings = difficultyPane.difficultySettings[difficultyIndex]
                                                root.gridSizeX = settings.x
                                                root.gridSizeY = settings.y
                                                root.mineCount = settings.mines
                                            }
                                        }

                                        onUserInteractionCheckedChanged: {
                                            if (userInteractionChecked) {
                                                checked = true
                                                userInteractionChecked = false
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: if (mouse.button === Qt.LeftButton) {
                                                           parent.userInteractionChecked = true
                                                       }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Component {
                    id: controlsPaneComponent
                    Pane {
                        id: controlsPane
                        ColumnLayout {
                            spacing: 26
                            width: parent.width

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: {
                                    if (isFluentWinUI3Theme) return 10
                                    return 0
                                }

                                Label {
                                    text: qsTr("Invert left and right click")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: invert.checked = !invert.checked
                                    }
                                }
                                Switch {
                                    id: invert
                                    checked: root.invertLRClick
                                    onCheckedChanged: {
                                        mainWindow.saveControlsSettings(invert.checked, autoreveal.checked, questionMarks.checked)
                                        root.invertLRClick = checked
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Quick reveal connected cells")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: autoreveal.checked = !autoreveal.checked
                                    }
                                }
                                Switch {
                                    id: autoreveal
                                    checked: root.revealConnected
                                    onCheckedChanged: {
                                        mainWindow.saveControlsSettings(invert.checked, autoreveal.checked, questionMarks.checked)
                                        root.revealConnected = checked
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Enable question marks")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: questionMarks.checked = !questionMarks.checked
                                    }
                                }
                                Switch {
                                    id: questionMarks
                                    checked: root.enableQuestionMarks
                                    onCheckedChanged: {
                                        mainWindow.saveControlsSettings(invert.checked, autoreveal.checked, questionMarks.checked)
                                        root.enableQuestionMarks = checked
                                        if (!checked) {
                                            for (let i = 0; i < root.gridSizeX * root.gridSizeY; i++) {
                                                let cell = grid.itemAtIndex(i)
                                                if (cell && cell.questioned) {
                                                    cell.questioned = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: visualsPaneComponent
                    Pane {
                        id: visualsPane
                        ColumnLayout {
                            spacing: 26
                            width: parent.width

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: {
                                    if (isFluentWinUI3Theme) return 10
                                    return 0
                                }
                                Label {
                                    text: qsTr("Animations")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: animationsSettings.checked = !animationsSettings.checked
                                    }
                                }
                                Switch {
                                    id: animationsSettings
                                    checked: root.enableAnimations
                                    onCheckedChanged: {
                                        mainWindow.saveVisualSettings(animationsSettings.checked, cellFrameSettings.checked, highContrastFlagSwitch.checked)
                                        root.enableAnimations = checked
                                        for (let i = 0; i < root.gridSizeX * root.gridSizeY; i++) {
                                            let cell = grid.itemAtIndex(i)
                                            if (cell) {
                                                cell.opacity = 1
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Revealed cells frame")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: cellFrameSettings.checked = !cellFrameSettings.checked
                                    }
                                }
                                Switch {
                                    id: cellFrameSettings
                                    checked: root.cellFrame
                                    onCheckedChanged: {
                                        mainWindow.saveVisualSettings(animationsSettings.checked, cellFrameSettings.checked, highContrastFlagSwitch.checked)
                                        root.cellFrame = checked
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("High contrast flags")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: highContrastFlagSwitch.checked = !highContrastFlagSwitch.checked
                                    }
                                }
                                Switch {
                                    id: highContrastFlagSwitch
                                    checked: root.highContrastFlag
                                    onCheckedChanged: {
                                        mainWindow.saveVisualSettings(animationsSettings.checked, cellFrameSettings.checked, highContrastFlagSwitch.checked)
                                        root.highContrastFlag = checked
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Theme")
                                    Layout.fillWidth: true
                                }

                                ComboBox {
                                    id: themeComboBox
                                    model: [qsTr("System"), "Windows 10", "Windows 11", "Fusion"]
                                    Layout.rightMargin: 5
                                    Layout.preferredWidth: {
                                        if (isUniversalTheme) return themeComboBox.implicitWidth + 5
                                        return themeComboBox.implicitWidth
                                    }

                                    property int previousIndex: theme

                                    currentIndex: theme
                                    onActivated: function(index) {
                                        if (currentIndex !== previousIndex) {  // Check if index actually changed
                                            mainWindow.saveThemeSettings(currentIndex)
                                            restartWindow.visible = true
                                            previousIndex = currentIndex  // Update the previous index
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: soundPaneComponent
                    Pane {
                        id: soundPane
                        ColumnLayout {
                            spacing: 26
                            width: parent.width

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: {
                                    if (isFluentWinUI3Theme) return 10
                                    return 0
                                }
                                Label {
                                    text: qsTr("Sound effects")
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: soundSwitch.checked = !soundSwitch.checked
                                    }
                                }
                                Switch {
                                    id: soundEffectSwitch
                                    checked: root.playSound
                                    onCheckedChanged: {
                                        mainWindow.saveSoundSettings(soundEffectSwitch.checked, soundVolumeSlider.value)
                                        root.playSound = checked
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Volume")
                                    Layout.fillWidth: true
                                }
                                Slider {
                                    id: soundVolumeSlider
                                    from: 0
                                    to: 1
                                    value: soundVolume
                                    onValueChanged: {
                                        mainWindow.saveSoundSettings(soundEffectSwitch.checked, value)
                                        root.soundVolume = value
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: shortcutsPaneComponent
                    Pane {
                        id: shortcutsPane
                        ColumnLayout {
                            spacing: 16
                            width: parent.width


                            Frame {
                                Layout.fillWidth: true
                                RowLayout {
                                    anchors.fill: parent
                                    Layout.topMargin: {
                                        if (isFluentWinUI3Theme) return 10
                                        return 0
                                    }
                                    Label {
                                        text: qsTr("Fullscreen")
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: "F11"
                                        font.bold: true
                                    }
                                }
                            }
                            Frame {
                                Layout.fillWidth: true
                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("New game")
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: "Ctrl + N"
                                        font.bold: true
                                    }
                                }
                            }
                            Frame {
                                Layout.fillWidth: true
                                RowLayout {
                                    anchors.fill: parent
                                    Layout.fillWidth: true
                                    Label {
                                        text: qsTr("Save game")
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: "Ctrl + S"
                                        font.bold: true
                                    }
                                }
                            }
                            Frame {
                                Layout.fillWidth: true
                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("Open settings")
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: "Ctrl + P"
                                        font.bold: true
                                    }
                                }
                            }
                            Frame {
                                Layout.fillWidth: true
                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("Quit")
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: "Ctrl + Q"
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: languagePaneComponent
                    Pane {
                        id: languagePane
                        ColumnLayout {
                            spacing: 16
                            width: parent.width

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: {
                                    if (isFluentWinUI3Theme) return 10
                                    return 0
                                }
                                Label {
                                    text: qsTr("Language")
                                    Layout.fillWidth: true
                                }

                                ComboBox {
                                    id: languageComboBox
                                    model: [qsTr("System"), "English", "Français"]
                                    Layout.rightMargin: 5
                                    currentIndex: root.language
                                    Layout.preferredWidth: {
                                        if (isUniversalTheme) return languageComboBox.implicitWidth + 5
                                        return languageComboBox.implicitWidth
                                    }

                                    onCurrentIndexChanged: {
                                        mainWindow.saveLanguageSettings(currentIndex)
                                        mainWindow.setLanguage(currentIndex)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    SoundEffect {
        id: looseEffect
        source: "qrc:/sounds/bomb.wav"
        volume: root.soundVolume
    }

    SoundEffect {
        id: clickEffect
        source: "qrc:/sounds/click.wav"
        volume: root.soundVolume
    }

    SoundEffect {
        id: winEffect
        source: "qrc:/sounds/win.wav"
        volume: root.soundVolume
    }

    function playLoose() {
        if (!root.playSound) return
        looseEffect.play()
        console.log(root.soundVolume)
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

    function revealConnectedCells(index) {
        if (!root.revealConnected || !gameStarted || gameOver) return;

        let cell = grid.itemAtIndex(index);
        if (!cell.revealed || numbers[index] <= 0) return;

        let row = Math.floor(index / gridSizeX);
        let col = index % gridSizeX;
        let flaggedCount = 0;
        let adjacentCells = [];

        // Check adjacent cells for flags and collect non-flagged cells
        for (let r = -1; r <= 1; r++) {
            for (let c = -1; c <= 1; c++) {
                if (r === 0 && c === 0) continue;

                let newRow = row + r;
                let newCol = col + c;
                if (newRow < 0 || newRow >= gridSizeY || newCol < 0 || newCol >= gridSizeX) continue;

                let pos = newRow * gridSizeX + newCol;
                let adjacentCell = grid.itemAtIndex(pos);

                if (adjacentCell.flagged) {
                    flaggedCount++;
                } else if (!adjacentCell.revealed) {
                    // Remove question mark if present
                    if (adjacentCell.questioned) {
                        adjacentCell.questioned = false;
                    }
                    adjacentCells.push(pos);
                }
            }
        }

        // If the number of flags matches the cell's number, reveal adjacent non-flagged cells
        if (flaggedCount === numbers[index] && adjacentCells.length > 0) {
            for (let pos of adjacentCells) {
                reveal(pos);
            }
            root.playClick()
        }
    }

    function placeMines(firstClickIndex) {
        const row = Math.floor(firstClickIndex / gridSizeX);
        const col = firstClickIndex % gridSizeX;

        // Initialize the game with current settings
        gameLogic.initializeGame(gridSizeX, gridSizeY, mineCount);

        // Place mines using C++ backend
        const success = gameLogic.placeMines(col, row);

        // Get mines and numbers from C++ backend
        mines = gameLogic.getMines();
        numbers = gameLogic.getNumbers();

        return true;
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

        // Reset all cells and trigger new animations
        for (let i = 0; i < gridSizeX * gridSizeY; i++) {
            let cell = grid.itemAtIndex(i)
            if (cell) {
                cell.revealed = false
                cell.flagged = false
                cell.questioned = false
                cell.startFadeIn()
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
            cell.isBombClicked = true
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
                if (mines.includes(i)) {
                    // Keep flag if it was correctly placed on a mine
                    if (!cell.flagged) {
                        //cell.flagged = false
                        cell.revealed = true
                    } else {
                        cell.revealed = false
                    }
                } else {
                    // Remove flag if it was not on a mine
                    if (cell.flagged) {
                        cell.flagged = false
                        // You could potentially add a visual indicator of incorrect flag here
                    }
                }
            }
        }
    }

    function checkWin() {
        if (revealedCount === gridSizeX * gridSizeY - mineCount && !gameOver) {
            gameOver = true
            gameTimer.stop()
            gameOverLabel.text = qsTr("Victory :)")
            gameOverLabel.color = "#28d13c"
            gameOverWindow.visible = true
            playWin()
        }
    }

    function toggleFlag(index) {
        if (gameOver) return
        let cell = grid.itemAtIndex(index)
        if (!cell.revealed) {
            if (!cell.flagged && !cell.questioned) {
                // Empty -> Flag
                cell.flagged = true
                cell.questioned = false
                flaggedCount++
            } else if (cell.flagged) {
                if (enableQuestionMarks) {
                    // Flag -> Question (only if question marks are enabled)
                    cell.flagged = false
                    cell.questioned = true
                    flaggedCount--
                } else {
                    // Flag -> Empty (if question marks are disabled)
                    cell.flagged = false
                    flaggedCount--
                }
            } else if (cell.questioned) {
                // Question -> Empty
                cell.questioned = false
            }
        }
    }

    Component.onCompleted: {
        initGame()
    }

    RowLayout {
        id:topBar
        height: 40
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Button {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            onClicked: {
                menu.visible ? menu.close() : menu.open()
            }
            Image {
                anchors.centerIn: parent
                source: root.darkMode ? "qrc:/icons/menu_light.png" : "qrc:/icons/menu_dark.png"
                height: 16
                width: 16
            }

            Menu {
                topMargin: 60
                id: menu
                width: 150
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                MenuItem {
                    text: qsTr("New game")
                    onTriggered: root.initGame()
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Save game")
                    enabled: root.gameStarted
                    onTriggered: saveWindow.visible = true
                }
                Menu {
                    id: loadMenu
                    title: qsTr("Load game")

                    Instantiator {
                        id: menuInstantiator
                        model: []

                        MenuItem {
                            text: modelData
                            onTriggered: {
                                let saveData = mainWindow.loadGameState(text)
                                if (saveData) {
                                    if (!loadGame(saveData)) {
                                        errorWindow.visible = true
                                    }
                                }
                            }
                        }

                        onObjectAdded: (index, object) => loadMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => loadMenu.removeItem(object)
                    }

                    MenuSeparator { }

                    MenuItem {
                        text: qsTr("Open save folder")
                        onTriggered: mainWindow.openSaveFolder()
                    }

                    onAboutToShow: {
                        let saves = mainWindow.getSaveFiles()
                        if (saves.length === 0) {
                            menuInstantiator.model = [qsTr("Empty")]
                            menuInstantiator.objectAt(0).enabled = false
                        } else {
                            menuInstantiator.model = saves
                        }
                    }
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Settings")
                    onTriggered: settingsPage.visible = true
                }

                MenuItem {
                    text: qsTr("About")
                    onTriggered: aboutPage.visible = true
                }

                MenuItem {
                    text: qsTr("Exit")
                    onTriggered: Qt.quit()
                }
            }

            ApplicationWindow {
                id: saveWindow
                title: qsTr("Save Game")
                width: 300
                height: 130
                minimumWidth: 300
                minimumHeight: 130
                maximumWidth: 300
                maximumHeight: 130
                flags: Qt.Dialog
                Shortcut {
                    sequence: "Esc"
                    onActivated: {
                        saveWindow.close()
                    }
                }

                Keys.onEscapePressed: saveWindow.close()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    TextField {
                       id: saveNameField
                       placeholderText: qsTr("Enter save file name")
                       Layout.fillWidth: true
                       onTextChanged: {
                           let hasInvalidChars = /[\\/:*?"<>|]/.test(text)
                           errorLabel.text = hasInvalidChars ? qsTr("Filename cannot contain:") + " \\ / : * ? \" < > |" : ""
                           saveButton.enabled = text.trim() !== "" && !hasInvalidChars
                       }
                       Keys.onReturnPressed: {
                           if (saveButton.enabled) {
                               saveButton.clicked()
                           }
                       }
                    }
                    Label {
                       id: errorLabel
                       color: "#f7c220"
                       Layout.leftMargin: 3
                       font.pointSize: 10
                       Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: 10

                        Button {
                            id: cancelButton
                            text: qsTr("Cancel")
                            Layout.preferredWidth: Math.max(cancelButton.implicitWidth, saveButton.implicitWidth)
                            onClicked: saveWindow.close()
                        }

                        Button {
                            id: saveButton
                            text: qsTr("Save")
                            Layout.preferredWidth: Math.max(cancelButton.implicitWidth, saveButton.implicitWidth)
                            enabled: false
                            onClicked: {
                                if (saveNameField.text.trim()) {
                                    saveGame(saveNameField.text.trim() + ".json")
                                    saveWindow.close()
                                }
                            }
                        }
                    }
                }

                onVisibleChanged: {
                    if (visible) {
                        saveNameField.text = ""
                        saveNameField.forceActiveFocus()
                    }
                }
            }

            ApplicationWindow {
                id: errorWindow
                title: qsTr("Error")
                width: 300
                height: 150
                minimumWidth: 300
                minimumHeight: 150
                flags: Qt.Dialog

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Label {
                        text: qsTr("Failed to load save file. The file might be corrupted or incompatible.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Button {
                        text: qsTr("OK")
                        Layout.alignment: Qt.AlignRight
                        onClicked: errorWindow.close()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            id: elapsedTimeLabel
            text: "HH:MM:SS"
            color: root.darkMode ? "white" : "black"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.leftMargin: 13

        }

        Item {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.rightMargin: 2
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

            Image {
                source: root.darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }

            Text {
                text: ": " + (root.mineCount - root.flaggedCount)
                color: root.darkMode ? "white" : "black"
                font.pixelSize: 18
                font.bold: true
            }
        }
    }

    ScrollView {
        id: scrollView
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: topBar.bottom
            topMargin: 10
            leftMargin: 12
            rightMargin: 12
            bottomMargin: 12
        }
        clip: true

        ColumnLayout {
            id: gameLayout
            width: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeX, scrollView.width)
            height: Math.max((root.cellSize + root.cellSpacing) * root.gridSizeY, scrollView.height)
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.preferredWidth: (root.cellSize + root.cellSpacing) * root.gridSizeX
                Layout.preferredHeight: (root.cellSize + root.cellSpacing) * root.gridSizeY

                GridView {
                    id: grid
                    anchors.fill: parent
                    cellWidth: cellSize + cellSpacing
                    cellHeight: cellSize + cellSpacing
                    model: root.gridSizeX * root.gridSizeY
                    interactive: false
                    property bool initialAnimationPlayed: false

                    delegate: Item {
                        id: cellItem
                        width: cellSize
                        height: cellSize

                        property bool animatingReveal: false
                        property bool shouldBeFlat: false
                        property bool revealed: false
                        property bool flagged: false
                        property bool questioned: false
                        property bool isBombClicked: false

                        readonly property int row: Math.floor(index / root.gridSizeX)
                        readonly property int col: index % root.gridSizeX
                        readonly property int diagonalSum: row + col

                        opacity: 1

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
                            onStarted: animatingReveal = true
                            onFinished: {
                                animatingReveal = false
                                cellButton.flat = shouldBeFlat
                                cellButton.opacity = 1
                            }
                        }

                        Timer {
                            id: fadeTimer
                            interval: diagonalSum * 20
                            repeat: false
                            onTriggered: {
                                if (enableAnimations) {
                                    fadeAnimation.start()
                                }
                            }
                        }

                        Component.onCompleted: {
                            // Only play initial animation once and only for the first creation
                            if (enableAnimations && !grid.initialAnimationPlayed) {
                                opacity = 0
                                fadeTimer.start()
                                // Mark initial animation as played after the last cell is created
                                if (index === (root.gridSizeX * root.gridSizeY - 1)) {
                                    grid.initialAnimationPlayed = true
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: cellButton
                            border.width: 2
                            radius: {
                                if (isUniversalTheme) return 0
                                else if (isFluentWinUI3Theme) return 4
                                else if (isFusionTheme) return 3
                                else return 2
                            }
                            border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                            visible: {
                                if (cellItem.revealed && cellItem.isBombClicked && mines.includes(index))
                                    return true
                                if (cellItem.animatingReveal && cellFrame)
                                    return true
                                return cellButton.flat && cellFrame
                            }
                            color: {
                                if (cellItem.revealed && cellItem.isBombClicked && mines.includes(index))
                                    return accentColor
                                return "transparent"
                            }
                        }

                        // The button for background and interactions
                        Button {
                            id: cellButton
                            anchors.fill: parent
                            anchors.margins: cellSpacing / 2

                            Connections {
                                target: cellItem
                                function onRevealedChanged() {
                                    if (cellItem.revealed) {
                                        if (enableAnimations) {
                                            shouldBeFlat = true
                                            revealFadeAnimation.start()
                                        } else {
                                            cellButton.flat = true
                                        }
                                    } else {
                                        shouldBeFlat = false
                                        cellButton.opacity = 1
                                        cellButton.flat = false
                                    }
                                }
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
                                source: darkMode ? "qrc:/icons/questionmark_light.png" : "qrc:/icons/questionmark_dark.png"
                                visible: cellItem.questioned
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            Image {
                                anchors.centerIn: parent
                                source: {
                                    if(highContrastFlag)
                                        return darkMode ? "qrc:/icons/flag.png" : "qrc:/icons/flag_dark.png"
                                    return flagIcon
                                }
                                visible: cellItem.flagged
                                sourceSize.width: cellItem.width / 2
                                sourceSize.height: cellItem.height / 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                               if (cellItem.revealed) {
                                                   revealConnectedCells(index);
                                               } else {
                                                   if (root.invertLRClick) {
                                                       if (mouse.button === Qt.RightButton && !cellItem.flagged && !cellItem.questioned) {
                                                           reveal(index);
                                                           playClick();
                                                       } else if (mouse.button === Qt.LeftButton) {
                                                           toggleFlag(index);
                                                       }
                                                   } else {
                                                       if (mouse.button === Qt.LeftButton && !cellItem.flagged && !cellItem.questioned) {
                                                           reveal(index);
                                                           playClick();
                                                       } else if (mouse.button === Qt.RightButton) {
                                                           toggleFlag(index);
                                                       }
                                                   }
                                               }
                                           }
                            }
                        }

                        // Number display
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!cellItem.revealed || cellItem.flagged) return ""
                                if (mines.includes(index)) return ""
                                return numbers[index] === 0 ? "" : numbers[index]
                            }
                            font.pixelSize: cellSize * 0.65
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: {
                                if (!cellItem.revealed) return "black"
                                if (mines.includes(index)) return "transparent"
                                if (numbers[index] === 1) return "#069ecc"
                                if (numbers[index] === 2) return "#28d13c"
                                if (numbers[index] === 3) return "#d12844"
                                if (numbers[index] === 4) return "#9328d1"
                                if (numbers[index] === 5) return "#ebc034"
                                if (numbers[index] === 6) return "#34ebb1"
                                if (numbers[index] === 7) return "#eb8634"
                                if (numbers[index] === 8 && darkMode) return "white"
                                if (numbers[index] === 8 && !darkMode) return "black"
                                return "black"
                            }
                        }

                        function startFadeIn() {
                            if (!enableAnimations) {
                                opacity = 1
                                return
                            }
                            grid.initialAnimationPlayed = false  // Reset the animation flag
                            opacity = 0
                            fadeTimer.restart()
                        }
                    }
                }
            }
        }
    }
}

