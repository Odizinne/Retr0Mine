pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    required property var grid
    readonly property int baseWidth: 600
    readonly property int baseHeight: 480
    required property int rootWidth
    required property int rootHeight
    required property int rootX
    required property int rootY

    width: GameCore.gamescope ? 1280 : baseWidth
    height: GameCore.gamescope ? 800 : baseHeight
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    visible: false
    flags: Qt.Dialog
    onVisibleChanged: {
        if (control.visible) {
            if (control.rootX + control.rootWidth + control.width + 10 <= Screen.width) {
                control.x = control.rootX + control.rootWidth + 20
            } else if (control.rootX - control.width - 10 >= 0) {
                control.x = control.rootX - control.width - 20
            } else {
                control.x = Screen.width - control.width - 20
            }
            control.y = control.rootY + (control.rootHeight - control.height) / 2
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
                        GameState.bypassAutoSave = true
                        GameCore.resetRetr0Mine()
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
                        icon.color: GameConstants.foregroundColor
                        text: GameCore.isFluent ? "  " + modelData.text : modelData.text
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
                    visible: GameCore.gamescope || false
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
                if (GameCore.isUniversal) return -15
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
                        spacing: GameCore.isFluent ? 15 : 20

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
                                    checked: GameSettings.difficulty === parent.index
                                    onClicked: {
                                        const idx = difficultyGroup.buttons.indexOf(this)
                                        const difficultySet = GameState.difficultySettings[idx]
                                        GameState.gridSizeX = difficultySet.x
                                        GameState.gridSizeY = difficultySet.y
                                        GameState.mineCount = difficultySet.mines
                                        control.grid.initGame()
                                        GameSettings.difficulty = idx
                                    }
                                }
                            }
                        }

                        RowLayout {
                            enabled: GameSettings.difficulty === 4
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
                                value: GameSettings.customWidth
                                onValueChanged: GameSettings.customWidth = value
                            }
                        }

                        RowLayout {
                            enabled: GameSettings.difficulty === 4
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
                                value: GameSettings.customHeight
                                onValueChanged: GameSettings.customHeight = value
                            }
                        }

                        RowLayout {
                            enabled: GameSettings.difficulty === 4
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
                                value: GameSettings.customMines
                                onValueChanged: GameSettings.customMines = value
                            }
                        }

                        Button {
                            enabled: GameSettings.difficulty === 4
                            Layout.rightMargin: 5
                            text: qsTr("Apply")
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                GameState.gridSizeX = GameSettings.customWidth
                                GameState.gridSizeY = GameSettings.customHeight
                                GameState.mineCount = GameSettings.customMines
                                control.grid.initGame()
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
                                    onClicked: invertLRSwitch.click()
                                }
                            }
                            Switch {
                                id: invertLRSwitch
                                checked: GameSettings.invertLRClick
                                onCheckedChanged: {
                                    GameSettings.invertLRClick = checked
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
                                    onClicked: autorevealSwitch.click()
                                }
                            }
                            Switch {
                                id: autorevealSwitch
                                checked: GameSettings.autoreveal
                                onCheckedChanged: {
                                    GameSettings.autoreveal = checked
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
                                    onClicked: questionMarksSwitch.click()
                                }
                            }
                            Switch {
                                id: questionMarksSwitch
                                checked: GameSettings.enableQuestionMarks
                                onCheckedChanged: {
                                    GameSettings.enableQuestionMarks = checked
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
                                    onClicked: safeQuestionMarksSwitch.click()
                                }
                            }
                            Switch {
                                id: safeQuestionMarksSwitch
                                checked: GameSettings.enableSafeQuestionMarks
                                onCheckedChanged: {
                                    GameSettings.enableSafeQuestionMarks = checked
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
                                    onClicked: loadLastGameSwitch.click()
                                }
                            }
                            Switch {
                                id: loadLastGameSwitch
                                checked: GameSettings.loadLastGame
                                onCheckedChanged: {
                                    GameSettings.loadLastGame = checked
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
                                    onClicked: animationsSwitch.click()
                                }
                            }
                            Switch {
                                id: animationsSwitch
                                checked: GameSettings.animations
                                onCheckedChanged: {
                                    GameSettings.animations = checked
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
                                    onClicked: cellFrameSwitch.click()
                                }
                            }
                            Switch {
                                id: cellFrameSwitch
                                checked: GameSettings.cellFrame
                                onCheckedChanged: {
                                    GameSettings.cellFrame = checked
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
                                    onClicked: dimSatisfiedSwitch.click()
                                }
                            }
                            Switch {
                                id: dimSatisfiedSwitch
                                checked: GameSettings.dimSatisfied
                                onCheckedChanged: {
                                    GameSettings.dimSatisfied = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            enabled: GameSettings.dimSatisfied
                            Label {
                                text: qsTr("Dim level")
                                Layout.fillWidth: true
                            }
                            Slider {
                                id: dimmedOpacitySlider
                                from: 0.3
                                to: 0.8
                                value: GameSettings.satisfiedOpacity
                                onValueChanged: GameSettings.satisfiedOpacity = value
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                enabled: !GameCore.gamescope
                                text: qsTr("Start in full screen")
                                Layout.fillWidth: true
                                MouseArea {
                                    enabled: !GameCore.gamescope
                                    anchors.fill: parent
                                    onClicked: startFullScreenSwitch.click()
                                }
                            }
                            Switch {
                                id: startFullScreenSwitch
                                enabled: !GameCore.gamescope
                                checked: GameSettings.startFullScreen || GameCore.gamescope
                                onCheckedChanged: {
                                    GameSettings.startFullScreen = checked
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
                                currentIndex: GameSettings.fontIndex
                                onActivated: {
                                    GameSettings.fontIndex = currentIndex
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
                                currentIndex: GameSettings.gridResetAnimationIndex
                                onActivated: {
                                    GameSettings.gridResetAnimationIndex = currentIndex
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

                            Button {
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 45
                                checkable: true
                                icon.source: "qrc:/icons/flag.png"
                                checked: GameSettings.flagSkinIndex === 0 || !SteamIntegration.initialized
                                icon.width: 35
                                icon.height: 35
                                ButtonGroup.group: buttonGroup
                                Layout.alignment: Qt.AlignHCenter
                                onCheckedChanged: {
                                    if (checked) GameSettings.flagSkinIndex = 0
                                }
                            }

                            Button {
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 45
                                enabled: GameState.flag1Unlocked
                                checkable: true
                                checked: GameState.flag1Unlocked && GameSettings.flagSkinIndex === 1
                                icon.source: GameState.flag1Unlocked ? "qrc:/icons/flag1.png" : "qrc:/icons/locked.png"
                                icon.width: 35
                                icon.height: 35
                                ButtonGroup.group: buttonGroup
                                Layout.alignment: Qt.AlignHCenter
                                ToolTip.visible: hovered && !enabled
                                ToolTip.text: qsTr("Unlock Trust Your Instincts achievement")
                                onCheckedChanged: {
                                    if (checked) GameSettings.flagSkinIndex = 1
                                }
                            }

                            Button {
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 45
                                enabled: GameState.flag2Unlocked
                                checkable: true
                                checked: GameState.flag2Unlocked && GameSettings.flagSkinIndex === 2
                                icon.source: GameState.flag2Unlocked ? "qrc:/icons/flag2.png" : "qrc:/icons/locked.png"
                                icon.width: 35
                                icon.height: 35
                                ButtonGroup.group: buttonGroup
                                Layout.alignment: Qt.AlignHCenter
                                ToolTip.visible: hovered && !enabled
                                ToolTip.text: qsTr("Unlock Master Tactician achievement")
                                onCheckedChanged: {
                                    if (checked) GameSettings.flagSkinIndex = 2
                                }
                            }

                            Button {
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 45
                                enabled: GameState.flag3Unlocked
                                checkable: true
                                checked: GameState.flag3Unlocked && GameSettings.flagSkinIndex === 3
                                icon.source: GameState.flag3Unlocked ? "qrc:/icons/flag3.png" : "qrc:/icons/locked.png"
                                icon.width: 35
                                icon.height: 35
                                ButtonGroup.group: buttonGroup
                                Layout.alignment: Qt.AlignHCenter
                                ToolTip.visible: hovered && !enabled
                                ToolTip.text: qsTr("Unlock Minefield Legend achievement")
                                onCheckedChanged: {
                                    if (checked) GameSettings.flagSkinIndex = 3
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
                                    onClicked: soundEffectSwitch.click()
                                }
                            }
                            Switch {
                                id: soundEffectSwitch
                                checked: GameSettings.soundEffects
                                onCheckedChanged: {
                                    GameSettings.soundEffects = checked
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
                                value: GameSettings.volume
                                onValueChanged: {
                                    GameSettings.volume = value
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
                                currentIndex: GameSettings.soundPackIndex
                                onActivated: {
                                    GameSettings.soundPackIndex = currentIndex
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
                                width: ListView.view.width -5

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: shortcutLine.model.title
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        color: GameConstants.accentColor
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
                                currentIndex: GameSettings.colorBlindness
                                onActivated: {
                                    GameSettings.colorBlindness = currentIndex
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
                                model: [qsTr("Small"), qsTr("Normal"), qsTr("Large")]
                                Layout.rightMargin: 5
                                currentIndex: {
                                    switch(GameSettings.cellSize) {
                                        case 0: return 0;
                                        case 1: return 1;
                                        case 2: return 2;
                                        default: return 0;
                                    }
                                }

                                onActivated: {
                                    GameSettings.cellSize = currentIndex
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
                                    onClicked: highContrastFlagSwitch.click()
                                }
                            }
                            Switch {
                                id: highContrastFlagSwitch
                                checked: GameSettings.contrastFlag
                                onCheckedChanged: {
                                    GameSettings.contrastFlag = checked
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
                                currentIndex: GameSettings.languageIndex
                                onActivated: {
                                    previousLanguageIndex = currentIndex
                                    GameSettings.languageIndex = currentIndex
                                    GameCore.setLanguage(currentIndex)
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
                                currentIndex: GameSettings.themeIndex
                                onActivated: {
                                    if (GameState.gameStarted && !GameState.gameOver) {
                                        SaveManager.saveGame("internalGameState.json")
                                    }
                                    GameState.bypassAutoSave = true
                                    GameCore.restartRetr0Mine(currentIndex)
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

                                currentIndex: GameSettings.colorSchemeIndex
                                onActivated: {
                                    GameSettings.colorSchemeIndex = currentIndex
                                    GameCore.setThemeColorScheme(currentIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
