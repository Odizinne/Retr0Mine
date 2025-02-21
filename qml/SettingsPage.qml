pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    required property var grid
    required property var root
    readonly property int baseWidth: 600
    readonly property int baseHeight: 480

    width: MainWindow.gamescope ? 1280 : baseWidth
    height: MainWindow.gamescope ? 800 : baseHeight
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    visible: false
    flags: Qt.Dialog
    onVisibleChanged: {
        if (control.visible) {
            if (control.root.x + control.root.width + control.width + 10 <= Screen.width) {
                control.x = control.root.x + control.root.width + 20
            } else if (control.root.x - control.width - 10 >= 0) {
                control.x = control.root.x - control.width - 20
            } else {
                control.x = Screen.width - control.width - 20
            }
            control.y = control.root.y + (root.height - control.height) / 2
        }
    }

    BusyIndicator {
        // stupid, but allow continuous engine update
        // without too much hassle (needed for steam overlay)
        opacity: 0
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: {
            control.close()
        }
    }

    Popup {
        anchors.centerIn: parent
        id: restoreDefaultsPopup
        visible: false
        modal: true
        property int buttonWidth: Math.max(restoreButton.implicitWidth, cancelButton.implicitWidth)

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
                    id: restoreButton
                    text: qsTr("Restore")
                    Layout.preferredWidth: restoreDefaultsPopup.buttonWidth
                    Layout.fillWidth: true
                    onClicked: {
                        Retr0MineSettings.welcomeMessageShown = false
                        MainWindow.restartRetr0Mine()
                    }
                }

                Button {
                    id: cancelButton
                    text: qsTr("Cancel")
                    Layout.preferredWidth: restoreDefaultsPopup.buttonWidth
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
                    delegate: ItemDelegate {
                        width: parent.width
                        height: 40
                        required property var modelData
                        required property int index
                        icon.source: modelData.icon
                        icon.color: Colors.foregroundColor
                        text: MainWindow.isFluent ? "  " + modelData.text : modelData.text
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
                                    case 7: stackView.push(advancedPaneComponent); break;
                                }
                            }
                        }
                    }
                }

                Button {
                    text: qsTr("Close")
                    visible: MainWindow.gamescope || false
                    onClicked: control.close()
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
                if (MainWindow.isUniversal) return -15
                else return -10
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
                        width: parent.width
                        spacing: MainWindow.isFluent ? 15 : 20

                        ButtonGroup {
                            id: difficultyGroup
                            exclusive: true
                        }

                        Repeater {
                            model: GameState.difficultySettings
                            RowLayout {
                                id: difficultyRow
                                Layout.fillWidth: true
                                required property var modelData
                                required property int index

                                Label {
                                    text: difficultyRow.modelData.text
                                    Layout.fillWidth: true
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                radioButton.click()
                                            }
                                        }
                                    }
                                }

                                InfoIcon {
                                    visible: difficultyRow.index !== 4
                                    tooltipText: `${difficultyRow.modelData.x}×${difficultyRow.modelData.y}, ${difficultyRow.modelData.mines} mines`
                                }

                                RadioButton {
                                    id: radioButton
                                    Layout.preferredWidth: height
                                    Layout.alignment: Qt.AlignRight
                                    ButtonGroup.group: difficultyGroup
                                    checked: Retr0MineSettings.difficulty === parent.index
                                    onClicked: {
                                        const idx = difficultyGroup.buttons.indexOf(this)
                                        const difficultySet = GameState.difficultySettings[idx]
                                        GameState.gridSizeX = difficultySet.x
                                        GameState.gridSizeY = difficultySet.y
                                        GameState.mineCount = difficultySet.mines
                                        control.root.initGame()
                                        Retr0MineSettings.difficulty = idx
                                    }
                                }
                            }
                        }

                        RowLayout {
                            enabled: Retr0MineSettings.difficulty === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Width:")
                                Layout.fillWidth: true
                            }

                            SpinBox {
                                id: widthSpinBox
                                Layout.rightMargin: 5
                                from: 8
                                to: 50
                                editable: true
                                value: Retr0MineSettings.customWidth
                                onValueChanged: Retr0MineSettings.customWidth = value
                            }
                        }

                        RowLayout {
                            enabled: Retr0MineSettings.difficulty === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Height:")
                                Layout.fillWidth: true
                            }
                            SpinBox {
                                id: heightSpinBox
                                Layout.rightMargin: 5
                                from: 8
                                to: 50
                                editable: true
                                value: Retr0MineSettings.customHeight
                                onValueChanged: Retr0MineSettings.customHeight = value
                            }
                        }

                        RowLayout {
                            enabled: Retr0MineSettings.difficulty === 4
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Mines:")
                                Layout.fillWidth: true
                            }
                            SpinBox {
                                id: minesSpinBox
                                Layout.rightMargin: 5
                                from: 1
                                to: Math.floor((widthSpinBox.value * heightSpinBox.value) / 4)
                                editable: true
                                value: Retr0MineSettings.customMines
                                onValueChanged: Retr0MineSettings.customMines = value
                            }
                        }

                        Button {
                            enabled: Retr0MineSettings.difficulty === 4
                            Layout.rightMargin: 5
                            text: qsTr("Apply")
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                GameState.gridSizeX = Retr0MineSettings.customWidth
                                GameState.gridSizeY = Retr0MineSettings.customHeight
                                GameState.mineCount = Retr0MineSettings.customMines
                                control.root.initGame()
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
                                checked: Retr0MineSettings.invertLRClick
                                onCheckedChanged: {
                                    Retr0MineSettings.invertLRClick = checked
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
                                checked: Retr0MineSettings.autoreveal
                                onCheckedChanged: {
                                    Retr0MineSettings.autoreveal = checked
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
                                checked: Retr0MineSettings.enableQuestionMarks
                                onCheckedChanged: {
                                    Retr0MineSettings.enableQuestionMarks = checked
                                    if (!checked) {
                                        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                                            let cell = control.grid.itemAtIndex(i) as Cell
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
                                text: qsTr("Enable green question marks")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: safeQuestionMarksSwitch.checked = !safeQuestionMarksSwitch.checked
                                }
                            }
                            Switch {
                                id: safeQuestionMarksSwitch
                                checked: Retr0MineSettings.enableSafeQuestionMarks
                                onCheckedChanged: {
                                    Retr0MineSettings.enableSafeQuestionMarks = checked
                                    if (!checked) {
                                        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                                            let cell = control.grid.itemAtIndex(i) as Cell
                                            if (cell && cell.safeQuestioned) {
                                                cell.safeQuestioned = false
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
                                checked: Retr0MineSettings.loadLastGame
                                onCheckedChanged: {
                                    Retr0MineSettings.loadLastGame = checked
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
                                checked: Retr0MineSettings.animations
                                onCheckedChanged: {
                                    Retr0MineSettings.animations = checked
                                    for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                                        let cell = control.grid.itemAtIndex(i) as Cell
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
                                checked: Retr0MineSettings.cellFrame
                                onCheckedChanged: {
                                    Retr0MineSettings.cellFrame = checked
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
                                checked: Retr0MineSettings.dimSatisfied
                                onCheckedChanged: {
                                    Retr0MineSettings.dimSatisfied = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                enabled: !MainWindow.gamescope
                                text: qsTr("Start in full screen")
                                Layout.fillWidth: true
                                MouseArea {
                                    enabled: !MainWindow.gamescope
                                    anchors.fill: parent
                                    onClicked: startFullScreenSwitch.checked = !startFullScreenSwitch.checked
                                }
                            }
                            Switch {
                                id: startFullScreenSwitch
                                enabled: !MainWindow.gamescope
                                checked: Retr0MineSettings.startFullScreen || MainWindow.gamescope
                                onCheckedChanged: {
                                    Retr0MineSettings.startFullScreen = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Numbers font")
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: colorSchemeComboBox
                                model: ["Fira Sans", "Noto Serif", "Space Mono", "Orbitron", "Pixelify"]
                                Layout.rightMargin: 5
                                currentIndex: Retr0MineSettings.fontIndex
                                onActivated: {
                                    Retr0MineSettings.fontIndex = currentIndex
                                }
                            }
                        }

                        RowLayout {
                            visible: SteamIntegration.initialized
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Grid reset animation")
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                id: gridResetAnimationComboBox
                                Layout.rightMargin: 5
                                model: ListModel {
                                    id: animationModel
                                    ListElement { text: qsTr("Wave"); enabled: true }
                                    ListElement { text: qsTr("Fade"); enabled: false }
                                    ListElement { text: qsTr("Spin"); enabled: false }
                                }

                                Component.onCompleted: {
                                    animationModel.setProperty(1, "enabled", GameState.anim1Unlocked)
                                    animationModel.setProperty(2, "enabled", GameState.anim2Unlocked)
                                }

                                Connections {
                                    target: GameState
                                    function onAnim1UnlockedChanged() {
                                        animationModel.setProperty(1, "enabled", GameState.anim1Unlocked)
                                    }
                                    function onAnim2UnlockedChanged() {
                                        animationModel.setProperty(2, "enabled", GameState.anim2Unlocked)
                                    }
                                }

                                displayText: model.get(currentIndex).text
                                delegate: ItemDelegate {
                                    required property var model
                                    required property int index
                                    width: parent.width
                                    text: model.text
                                    enabled: model.enabled
                                    highlighted: gridResetAnimationComboBox.highlightedIndex === index
                                    icon.source: enabled ? "" : "qrc:/icons/locked.png"
                                    ToolTip.visible: !enabled && hovered
                                    ToolTip.text: qsTr("Unlocked with a secret achievement")
                                    ToolTip.delay: 1000
                                }
                                currentIndex: Retr0MineSettings.gridResetAnimationIndex
                                onActivated: {
                                    Retr0MineSettings.gridResetAnimationIndex = currentIndex
                                }
                            }
                        }

                        RowLayout {
                            visible: SteamIntegration.initialized
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
                                    checked: Retr0MineSettings.flagSkinIndex === 0 || !SteamIntegration.initialized
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    onCheckedChanged: {
                                        if (checked) Retr0MineSettings.flagSkinIndex = 0
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: GameState.flag1Unlocked
                                    checkable: true
                                    checked: GameState.flag1Unlocked && Retr0MineSettings.flagSkinIndex === 1
                                    icon.source: GameState.flag1Unlocked ? "qrc:/icons/flag1.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Trust Your Instincts achievement")
                                    onCheckedChanged: {
                                        if (checked) Retr0MineSettings.flagSkinIndex = 1
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: GameState.flag2Unlocked
                                    checkable: true
                                    checked: GameState.flag2Unlocked && Retr0MineSettings.flagSkinIndex === 2
                                    icon.source: GameState.flag2Unlocked ? "qrc:/icons/flag2.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Master Tactician achievement")
                                    onCheckedChanged: {
                                        if (checked) Retr0MineSettings.flagSkinIndex = 2
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: GameState.flag3Unlocked
                                    checkable: true
                                    checked: GameState.flag3Unlocked && Retr0MineSettings.flagSkinIndex === 3
                                    icon.source: GameState.flag3Unlocked ? "qrc:/icons/flag3.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Minefield Legend achievement")
                                    onCheckedChanged: {
                                        if (checked) Retr0MineSettings.flagSkinIndex = 3
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
                                checked: Retr0MineSettings.soundEffects
                                onCheckedChanged: {
                                    Retr0MineSettings.soundEffects = checked
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
                                value: Retr0MineSettings.volume
                                onValueChanged: {
                                    Retr0MineSettings.volume = value
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
                                Layout.rightMargin: 5
                                model: ["Pop", "Windows", "KDE", "Floraphonic"]
                                currentIndex: Retr0MineSettings.soundPackIndex
                                onActivated: {
                                    Retr0MineSettings.soundPackIndex = currentIndex
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
                                    title: qsTr("Leaderboard")
                                    shortcut: "Ctrl + L"
                                }
                                ListElement {
                                    title: qsTr("Quit")
                                    shortcut: "Ctrl + Q"
                                }
                            }

                            delegate: Frame {
                                id: shortcutLine
                                required property var model
                                width: ListView.view.width - 20

                                SystemPalette {
                                    id: sysPalette
                                    colorGroup: SystemPalette.Active
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: shortcutLine.model.title
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: sysPalette.accent
                                        text: shortcutLine.model.shortcut
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
                                currentIndex: Retr0MineSettings.colorBlindness
                                onActivated: {
                                    Retr0MineSettings.colorBlindness = currentIndex
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
                                    switch(Retr0MineSettings.cellSize) {
                                        case 0: return 0;
                                        case 1: return 1;
                                        case 2: return 2;
                                        default: return 0;
                                    }
                                }

                                onActivated: {
                                    Retr0MineSettings.cellSize = currentIndex
                                    if (!control.root.isMaximized && !control.root.isFullScreen) {
                                        control.root.minimumWidth = control.root.getInitialWidth()
                                        control.root.minimumHeight = control.root.getInitialHeight()
                                        control.root.width = control.root.minimumWidth
                                        control.root.height = control.root.minimumHeight
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
                                checked: Retr0MineSettings.contrastFlag
                                onCheckedChanged: {
                                    Retr0MineSettings.contrastFlag = checked
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
                                currentIndex: Retr0MineSettings.languageIndex
                                onActivated: {
                                    previousLanguageIndex = currentIndex
                                    Retr0MineSettings.languageIndex = currentIndex
                                    MainWindow.setLanguage(currentIndex)
                                    currentIndex = previousLanguageIndex
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: advancedPaneComponent
                Pane {
                    id: advancedPane
                    ColumnLayout {
                        spacing: 26
                        width: parent.width

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Style")
                                Layout.fillWidth: true
                            }

                            InfoIcon {
                                tooltipText: qsTr("Application will restart on change\nCurrent game will be saved and restored")
                                Layout.rightMargin: 5
                            }

                            ComboBox {
                                id: styleComboBox
                                model: ["Fluent", "Universal", "Fusion"]
                                Layout.rightMargin: 5
                                currentIndex: Retr0MineSettings.themeIndex
                                onActivated: {
                                    if (GameState.gameStarted && !GameState.gameOver) {
                                        control.root.saveGame("internalGameState.json")
                                    }
                                    MainWindow.restartRetr0Mine(currentIndex)
                                }
                            }
                        }

                        RowLayout {
                            enabled: Qt.platform.os === "windows"
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Color scheme")
                                Layout.fillWidth: true
                            }

                            ComboBox {
                                id: colorSchemeComboBox
                                model: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                                Layout.rightMargin: 5

                                currentIndex: Retr0MineSettings.colorSchemeIndex
                                onActivated: {
                                    Retr0MineSettings.colorSchemeIndex = currentIndex
                                    MainWindow.setThemeColorScheme(currentIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
