import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: settingsPage
    title: qsTr("Settings")
    width: root.isGamescope ? height * 1.6 : 600
    height: 480
    minimumWidth: root.isGamescope ? height * 1.6 : 600
    minimumHeight: 480
    maximumWidth: root.isGamescope ? height * 1.6 : 600
    maximumHeight: 480
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
        visible: false
        modal: true

        ColumnLayout {
            id: restoreDefaultLayout
            anchors.fill: parent
            spacing: 15

            Label {
                id: restoreDefaultsLabel
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                text: qsTr("Restore all settings to default?")
                Layout.columnSpan: 2
                font.bold: true
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                spacing: 10

                Button {
                    text: qsTr("Restore")
                    Layout.fillWidth: true
                    onClicked: {
                        settings.welcomeMessageShown = false
                        mainWindow.restartRetr0Mine()
                    }
                }

                Button {
                    text: qsTr("Cancel")
                    Layout.fillWidth: true
                    onClicked: restoreDefaultsPopup.visible = false
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
                    interactive: false
                    model: [
                        {
                            text: qsTr("Difficulty"),
                            icon: "qrc:/icons/difficulty.png",
                        },
                        {
                            text: qsTr("Gameplay"),
                            icon: "qrc:/icons/controls.png",
                        },
                        {
                            text: qsTr("Visuals"),
                            icon: "qrc:/icons/visuals.png",
                        },
                        {
                            text: qsTr("Sound"),
                            icon: "qrc:/icons/audio.png",
                        },
                        {
                            text: qsTr("Shortcuts"),
                            icon: "qrc:/icons/keyboard.png",
                        },
                        {
                            text: qsTr("Accessibility"),
                            icon: "qrc:/icons/accessibility.png",
                        },
                        {
                            text: qsTr("Language"),
                            icon: "qrc:/icons/language.png",
                        },
                        {
                            text: qsTr("Advanced"),
                            icon: "qrc:/icons/debug.png",
                        }
                    ]
                    currentIndex: 0
                    delegate: SidebarDelegate {
                        width: parent.width
                        height: 40
                        icon.source: modelData.icon
                        icon.color: root.darkMode ? "white" : "dark"

                        highlighted: ListView.isCurrentItem
                        onClicked: {
                            if (sidebarList.currentIndex !== index) {
                                sidebarList.currentIndex = index
                                switch(index) {
                                case 0: stackView.push(difficultyPaneComponent); break;
                                case 1: stackView.push(gameplayPaneComponent); break;
                                case 2: stackView.push(visualsPaneComponent); break;
                                case 3: stackView.push(soundPaneComponent); break;
                                case 4: stackView.push(shortcutsPaneComponent); break;
                                case 5: stackView.push(accessibilityPaneComponent); break;
                                case 6: stackView.push(languagePaneComponent); break;
                                case 7: stackView.push(debugPaneComponent); break;
                                }
                            }
                        }
                    }
                }

                Button {
                    text: qsTr("Close")
                    visible: root.isGamescope || false
                    onClicked: settingsPage.close()
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 30
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
                return -20
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
                        spacing: root.isFluentWinUI3Theme ? 15 : 20
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
                                    root.diffidx = idx
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
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                radioButton.userInteractionChecked = true
                                            }
                                        }
                                    }
                                }

                                Label {
                                    text: `${modelData.x}×${modelData.y}, ${modelData.mines} mines`
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                radioButton.userInteractionChecked = true
                                            }
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
                                    Binding {
                                        target: radioButton
                                        property: "checked"
                                        value: root.diffidx === index
                                    }
                                    onUserInteractionCheckedChanged: {
                                        if (userInteractionChecked) {
                                            checked = true
                                            userInteractionChecked = false
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                parent.userInteractionChecked = true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            enabled: root.diffidx === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Width:")
                                Layout.fillWidth: true
                            }

                            SpinBox {
                                id: widthSpinBox
                                from: 8
                                to: 50
                                editable: true
                                value: settings.customWidth
                                onValueChanged: settings.customWidth = value
                            }
                        }

                        RowLayout {
                            enabled: root.diffidx === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Height:")
                                Layout.fillWidth: true
                            }
                            SpinBox {
                                id: heightSpinBox
                                from: 8
                                to: 50
                                editable: true
                                value: settings.customHeight
                                onValueChanged: settings.customHeight = value
                            }
                        }

                        RowLayout {
                            enabled: root.diffidx === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Mines:")
                                Layout.fillWidth: true
                            }
                            SpinBox {
                                id: minesSpinBox
                                from: 1
                                to: Math.floor((widthSpinBox.value * heightSpinBox.value) / 5)
                                editable: true
                                value: settings.customMines
                                onValueChanged: settings.customMines = value
                            }
                        }

                        Button {
                            enabled: root.diffidx === 4
                            text: qsTr("Apply")
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                root.gridSizeX = settings.customWidth
                                root.gridSizeY = settings.customHeight
                                root.mineCount = settings.customMines
                                root.initGame()
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
                                text: qsTr("Dim satisfied cells")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: dimSatisfiedSwitch.checked = !dimSatisfiedSwitch.checked
                                }
                            }
                            Switch {
                                id: dimSatisfiedSwitch
                                checked: settings.dimSatisfied
                                onCheckedChanged: {
                                    settings.dimSatisfied = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                enabled: !root.isGamescope
                                text: qsTr("Start in full screen")
                                Layout.fillWidth: true
                                MouseArea {
                                    enabled: !root.isGamescope
                                    anchors.fill: parent
                                    onClicked: startFullScreenSwitch.checked = !startFullScreenSwitch.checked
                                }
                            }
                            Switch {
                                id: startFullScreenSwitch
                                enabled: !root.isGamescope
                                checked: settings.startFullScreen || root.isGamescope
                                onCheckedChanged: {
                                    settings.startFullScreen = checked
                                }
                            }
                        }

                        RowLayout {
                            visible: typeof steamIntegration !== "undefined"
                            spacing: 10

                            ButtonGroup {
                                id: buttonGroup
                                exclusive: true
                            }

                            Label {
                                text: qsTr("Flag")
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    checkable: true
                                    icon.source: "qrc:/icons/flag.png"
                                    checked: settings.flagSkinIndex === 0 || typeof steamIntegration === "undefined"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    onCheckedChanged: {
                                        if (checked) settings.flagSkinIndex = 0
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: typeof steamIntegration !== "undefined" && root.flag1Unlocked
                                    checkable: true
                                    checked: typeof steamIntegration !== "undefined" && root.flag1Unlocked && settings.flagSkinIndex === 1
                                    icon.source: typeof steamIntegration !== "undefined" && root.flag1Unlocked ? "qrc:/icons/flag1.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Trust Your Instincts achievement")
                                    onCheckedChanged: {
                                        if (checked) settings.flagSkinIndex = 1
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: typeof steamIntegration !== "undefined" && root.flag2Unlocked
                                    checkable: true
                                    checked: typeof steamIntegration !== "undefined" && root.flag1Unlocked && settings.flagSkinIndex === 2
                                    icon.source: typeof steamIntegration !== "undefined" && root.flag2Unlocked ? "qrc:/icons/flag2.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Master Tactician achievement")
                                    onCheckedChanged: {
                                        if (checked) settings.flagSkinIndex = 2
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: typeof steamIntegration !== "undefined" && root.flag3Unlocked
                                    checkable: true
                                    checked: typeof steamIntegration !== "undefined" && root.flag1Unlocked && settings.flagSkinIndex === 3
                                    icon.source: typeof steamIntegration !== "undefined" && root.flag3Unlocked ? "qrc:/icons/flag3.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Minefield Legend achievement")
                                    onCheckedChanged: {
                                        if (checked) settings.flagSkinIndex = 3
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

                            Label {
                                text: qsTr("Sound effects")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: soundEffectSwitch.checked = !soundEffectSwitch.checked
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
                                model: ["Pop", "Windows", "KDE", "Floraphonic"]
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
                id: accessibilityPaneComponent
                Pane {
                    id: accessibilityPane
                    ColumnLayout {
                        spacing: 26
                        width: parent.width

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Color correction")
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: colorComboBox
                                model: [qsTr("None"),
                                    qsTr("Deuteranopia"),
                                    qsTr("Protanopia"),
                                    qsTr("Tritanopia")
                                ]
                                Layout.rightMargin: 5
                                currentIndex: settings.colorBlindness
                                onActivated: {
                                    settings.colorBlindness = currentIndex
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
                                model: [qsTr("Normal"), qsTr("Large"), qsTr("Extra Large")]
                                Layout.rightMargin: 5
                                currentIndex: {
                                    switch(settings.cellSize) {
                                    case 0: return 0;
                                    case 1: return 1;
                                    case 2: return 2;
                                    default: return 0;
                                    }
                                }

                                onActivated: {
                                    settings.cellSize = currentIndex
                                    if (!isMaximized && !isFullScreen) {
                                        root.minimumWidth = getInitialWidth()
                                        root.minimumHeight = getInitialHeight()
                                        root.width = root.minimumWidth
                                        root.height = root.minimumHeight
                                    }
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
                    }
                }
            }

            Component {
                id: languagePaneComponent
                Pane {
                    id: languagePane
                    ColumnLayout {
                        spacing: 26
                        width: parent.width

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Language")
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: languageComboBox
                                model: [qsTr("System"),
                                    "English",
                                    "Français"
                                ]
                                property int previousLanguageIndex: currentIndex
                                Layout.rightMargin: 5
                                currentIndex: settings.languageIndex
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

            Component {
                id: debugPaneComponent
                Pane {
                    id: debugPane
                    ColumnLayout {
                        spacing: 26
                        width: parent.width

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: qsTr("Show seed at game over")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: printSeedSwitch.checked = !printSeedSwitch.checked
                                }
                            }
                            Switch {
                                id: printSeedSwitch
                                checked: settings.displaySeedAtGameOver
                                onCheckedChanged: {
                                    settings.displaySeedAtGameOver = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20

                            Label {
                                text: qsTr("Fixed seed")
                            }

                            TextField {
                                id: seedField
                                placeholderText: qsTr("Numbers only")
                                maximumLength: 10
                                Layout.fillWidth: true
                                validator: RegularExpressionValidator { regularExpression: /^[0-9]*$/ }
                                inputMethodHints: Qt.ImhDigitsOnly
                                text: settings.fixedSeed >= 0 ? settings.fixedSeed.toString() : ""
                                onTextChanged: {
                                    settings.fixedSeed = text.length > 0 ? parseInt(text) : -1
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
                                    var themes = ["Fluent", "Universal", "Fusion"]
                                    if (root.isGamescope) {
                                        themes.push(qsTr("Oled Dark"))
                                    }
                                    return themes
                                }
                                Layout.rightMargin: 5

                                property int previousIndex: settings.themeIndex

                                currentIndex: settings.themeIndex
                                onActivated: function(index) {
                                    if (currentIndex !== previousIndex) {
                                        settings.themeIndex = currentIndex
                                        //restartWindow.visible = true
                                        previousIndex = currentIndex
                                        if (root.gameStarted && !root.gameOver) {
                                            saveGame("internalGameState.json")
                                        }
                                        mainWindow.restartRetr0Mine()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
