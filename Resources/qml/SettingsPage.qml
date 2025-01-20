import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: settingsPage
    title: qsTr("Settings")
    width: 560
    height: 420
    minimumWidth: 560
    minimumHeight: 420
    maximumWidth: 560
    maximumHeight: 420
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

    Shortcut {
        sequence: "Esc"
        enabled: settingsPage.visible
        onActivated: {
            settingsPage.close()
        }
    }

    Popup {
        anchors.centerIn: parent
        id: restoreDefaultsPopup
        height: 120
        width: 320
        visible: false

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        GridLayout {
            id: restoreDefaultLayout
            anchors.fill: parent
            columns: 2
            rowSpacing: 10

            Label {
                id: restoreDefaultsLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: qsTr("Restore all settings to default?\nApplication needs to be restarted")
                Layout.columnSpan: 2
                font.bold: true
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                text: qsTr("Restore")
                Layout.fillWidth: true
                onClicked: {
                    settings.themeIndex = 0
                    settings.colorScheme = 0
                    settings.languageIndex = 0
                    settings.difficulty = 0
                    settings.invertLRClick = false
                    settings.autoreveal = false
                    settings.enableQuestionMarks = true
                    settings.loadLastGame = false
                    settings.soundEffects = true
                    settings.volume = 1.0
                    settings.soundPackIndex = 0
                    settings.animations = true
                    settings.cellFrame = true
                    settings.contrastFlag = false
                    settings.cellSize = 1

                    mainWindow.restartRetr0Mine()
                }
            }

            Button {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                onClicked: {
                    restoreDefaultsPopup.close()
                }
            }
        }
    }

    Popup {
        anchors.centerIn: parent
        id: restartWindow
        height: 130
        width: 300
        visible: false

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200  // Duration in milliseconds
                easing.type: Easing.InOutQuad
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        GridLayout {
            anchors.fill: parent
            columns: 2
            rowSpacing: 10
            Label {
                id: restartLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: qsTr("Application needs to be restarted\nYour current game will be saved")
                Layout.columnSpan: 2
                font.bold: true
                font.pixelSize: 16
            }

            Button {
                text: qsTr("Restart")
                Layout.fillWidth: true
                Layout.preferredWidth: 80
                onClicked: {
                    // Save game state if there's an active game
                    if (root.gameStarted && !root.gameOver) {
                        saveGame("internalGameState.json")
                    }
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
                            text: qsTr("Gameplay"),
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
                                case 1: stackView.push(gameplayPaneComponent); break;
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
                    id: resetDefaultSettingsButton
                    Layout.fillWidth: true
                    Layout.bottomMargin: 15
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 30
                    text: qsTr("Restore defaults")
                    highlighted: true
                    onClicked: {
                        restoreDefaultsPopup.open()
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

                    ColumnLayout {
                        anchors.topMargin: !isFluentWinUI3Theme ? 10 : 0
                        spacing: isFluentWinUI3Theme ? 10 : 20
                        width: parent.width

                        ButtonGroup {
                            id: difficultyGroup
                            exclusive: true
                            onCheckedButtonChanged: {
                                if (checkedButton && (checkedButton.userInteractionChecked || checkedButton.activeFocus)) {
                                    const idx = checkedButton.difficultyIndex
                                    const difficultySet = root.difficultySettings[idx]

                                    root.gridSizeX = difficultySet.x
                                    root.gridSizeY = difficultySet.y
                                    root.mineCount = difficultySet.mines
                                    initGame()
                                    settings.difficulty = idx
                                }
                            }
                        }

                        Repeater {
                            model: root.difficultySettings
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
                                    checked: settings.difficulty === index

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
                id: gameplayPaneComponent
                Pane {
                    id: gameplayPane
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
                                checked: settings.invertLRClick
                                onCheckedChanged: {
                                    settings.invertLRClick = checked
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
                                checked: settings.autoreveal
                                onCheckedChanged: {
                                    settings.autoreveal = checked
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
                                    onClicked: questionMarksSwitch.checked = !questionMarksSwitch.checked
                                }
                            }
                            Switch {
                                id: questionMarksSwitch
                                checked: settings.enableQuestionMarks
                                onCheckedChanged: {
                                    settings.enableQuestionMarks = checked
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

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Load last game on start")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: loadLastGameSwitch.checked = !loadLastGameSwitch.checked
                                }
                            }
                            Switch {
                                id: loadLastGameSwitch
                                checked: settings.loadLastGame
                                onCheckedChanged: {
                                    settings.loadLastGame = checked
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
                                checked: settings.animations
                                onCheckedChanged: {
                                    settings.animations = checked
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
                                checked: settings.cellFrame
                                onCheckedChanged: {
                                    settings.cellFrame = checked
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
                                checked: settings.contrastFlag
                                onCheckedChanged: {
                                    settings.contrastFlag = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Cell size")
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                id: cellSizeComboBox
                                model: [qsTr("Small"), qsTr("Normal"), qsTr("Large"), qsTr("Extra Large")]
                                Layout.rightMargin: 5
                                Layout.preferredWidth: {
                                    if (isUniversalTheme) return cellSizeComboBox.implicitWidth + 5
                                    return cellSizeComboBox.implicitWidth
                                }
                                currentIndex: {
                                    switch(settings.cellSize) {
                                    case 0: return 0;
                                    case 1: return 1;
                                    case 2: return 2;
                                    case 3: return 3;
                                    default: return 1;  // Default to Normal
                                    }
                                }

                                onActivated: {
                                    switch(cellSizeComboBox.currentIndex) {
                                    case 0: root.cellSize = 25; break;
                                    case 1: root.cellSize = 35; break;
                                    case 2: root.cellSize = 45; break;
                                    case 3: root.cellSize = 55; break;
                                    }
                                    if (!isMaximized && !isFullScreen) {
                                        root.minimumWidth = getInitialWidth()
                                        root.minimumHeight = getInitialHeight()
                                        root.width = root.minimumWidth
                                        root.height = root.minimumHeight
                                    }
                                    settings.cellSize = currentIndex
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Style")
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: styleComboBox
                                model: {
                                    let themes = [qsTr("System"), "Windows 10", "Windows 11", "Fusion"]
                                    if (root.isGamescope) {
                                        themes.push("Deck Dark")
                                    }
                                    return themes
                                }
                                Layout.rightMargin: 5
                                Layout.preferredWidth: {
                                    if (isUniversalTheme) return styleComboBox.implicitWidth + 5
                                    return styleComboBox.implicitWidth
                                }

                                property int previousIndex: settings.themeIndex

                                currentIndex: settings.themeIndex
                                onActivated: function(index) {
                                    if (currentIndex !== previousIndex) {  // Check if index actually changed
                                        settings.themeIndex = currentIndex
                                        restartWindow.visible = true
                                        previousIndex = currentIndex  // Update the previous index
                                    }
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
                                enabled: root.operatingSystem !== "unknown"
                                model: [qsTr("System"), qsTr("Light"), qsTr("Dark")]
                                Layout.rightMargin: 5
                                Layout.preferredWidth: {
                                    if (isUniversalTheme) return themeComboBox.implicitWidth + 5
                                    return themeComboBox.implicitWidth
                                }
                                currentIndex: settings.colorScheme
                                onActivated: {
                                    settings.colorScheme = currentIndex
                                    mainWindow.setColorScheme(currentIndex)
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
                                checked: settings.soundEffects
                                onCheckedChanged: {
                                    settings.soundEffects = checked
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
                                value: settings.volume
                                onValueChanged: {
                                    settings.volume = value
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Soundpack")
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                id: soundpackComboBox
                                model: ["Pop", "Windows", "KDE"]
                                currentIndex: settings.soundPackIndex
                                onActivated: {
                                    settings.soundPackIndex = currentIndex
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
                    ScrollView {
                        anchors.fill: parent
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                        ListView {
                            anchors.fill: parent
                            spacing: 16
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            model: ListModel {
                                ListElement {
                                    title: qsTr("Fullscreen")
                                    shortcut: "F11"
                                }
                                ListElement {
                                    title: qsTr("New game")
                                    shortcut: "Ctrl + N"
                                }
                                ListElement {
                                    title: qsTr("Save game")
                                    shortcut: "Ctrl + S"
                                }
                                ListElement {
                                    title: qsTr("Open settings")
                                    shortcut: "Ctrl + P"
                                }
                                ListElement {
                                    title: qsTr("Hint")
                                    shortcut: "Ctrl + H"
                                }
                                ListElement {
                                    title: qsTr("Quit")
                                    shortcut: "Ctrl + Q"
                                }
                                ListElement {
                                    title: qsTr("Cell selection")
                                    shortcut: "WASD or Arrows"
                                }
                                ListElement {
                                    title: qsTr("Reveal, replay")
                                    shortcut: "Enter or Q"
                                }
                                ListElement {
                                    title: qsTr("Flag / close")
                                    shortcut: "Space"
                                }
                            }

                            delegate: Frame {
                                width: ListView.view.width - 20

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: title
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: accentColor
                                        text: shortcut
                                        font.bold: true
                                    }
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
                                model: [qsTr("System"),
                                    "English",        // English
                                    "Français",       // French
                                    "Deutsch",        // German
                                    "Español",        // Spanish
                                    "Italiano",       // Italian
                                    "日本語",         // Japanese
                                    "简体中文",       // Chinese Simplified
                                    "繁體中文",       // Chinese Traditional
                                    "한국어",         // Korean
                                    "Русский"         // Russian
                                ]
                                property int previousLanguageIndex: currentIndex
                                Layout.rightMargin: 5
                                currentIndex: settings.languageIndex
                                Layout.preferredWidth: {
                                    if (isUniversalTheme) return languageComboBox.implicitWidth + 5
                                    return languageComboBox.implicitWidth
                                }

                                onActivated: {
                                    previousLanguageIndex = currentIndex
                                    settings.languageIndex = currentIndex
                                    mainWindow.setLanguage(currentIndex)
                                    currentIndex = previousLanguageIndex
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}