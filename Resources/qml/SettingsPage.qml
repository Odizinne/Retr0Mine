pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: settingsPage
    title: qsTr("Settings")
    required property var root
    required property var settings
    width: settingsPage.root.isGamescope ? height * 1.6 : 600
    height: 480
    minimumWidth: settingsPage.root.isGamescope ? height * 1.6 : 600
    minimumHeight: 480
    maximumWidth: settingsPage.root.isGamescope ? height * 1.6 : 600
    maximumHeight: 480
    visible: false
    flags: Qt.Dialog
    onVisibleChanged: {
        if (settingsPage.visible) {
            if (root.x + settingsPage.root.width + settingsPage.width + 10 <= screen.width) {
                settingsPage.x = settingsPage.root.x + settingsPage.root.width + 20
            } else if (root.x - settingsPage.width - 10 >= 0) {
                settingsPage.x = settingsPage.root.x - settingsPage.width - 20
            } else {
                settingsPage.x = screen.width - settingsPage.width - 20
            }
            settingsPage.y = settingsPage.root.y + (root.height - settingsPage.height) / 2
        }
    }

    BusyIndicator {
        // stupid, but allow continuous engine update
        // without too much hassle (needed for steam overlay)
        opacity: 0
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
                        settingsPage.settings.welcomeMessageShown = false
                        mainWindow.restartRetr0Mine()
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
                    delegate: SidebarDelegate {
                        width: parent.width
                        height: 40
                        required property var modelData
                        required property int index
                        icon.source: modelData.icon
                        icon.color: settingsPage.root.darkMode ? "white" : "dark"

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
                    visible: settingsPage.root.isGamescope || false
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

        SidebarSeparator {
            Layout.fillHeight: true
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

                    DifficultyLayout {
                        width: parent.width

                        ButtonGroup {
                            id: difficultyGroup
                            exclusive: true
                            onCheckedButtonChanged: {
                                if (checkedButton && (checkedButton.userInteractionChecked)) {
                                    const idx = checkedButton.difficultyIndex
                                    const difficultySet = settingsPage.root.difficultySettings[idx]

                                    settingsPage.root.gridSizeX = difficultySet.x
                                    settingsPage.root.gridSizeY = difficultySet.y
                                    settingsPage.root.mineCount = difficultySet.mines
                                    settingsPage.root.initGame()
                                    settingsPage.settings.difficulty = idx
                                    settingsPage.root.diffidx = idx
                                }
                            }
                        }

                        Repeater {
                            model: settingsPage.root.difficultySettings
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
                                                radioButton.userInteractionChecked = true
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
                                    property bool userInteractionChecked: false
                                    property int difficultyIndex: difficultyRow.index
                                    Layout.preferredWidth: height
                                    Layout.alignment: Qt.AlignRight
                                    ButtonGroup.group: difficultyGroup
                                    Binding {
                                        target: radioButton
                                        property: "checked"
                                        value: settingsPage.root.diffidx === index
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
                            enabled: settingsPage.root.diffidx === 4
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
                                value: settingsPage.settings.customWidth
                                onValueChanged: settingsPage.settings.customWidth = value
                            }
                        }

                        RowLayout {
                            enabled: settingsPage.root.diffidx === 4
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
                                value: settingsPage.settings.customHeight
                                onValueChanged: settingsPage.settings.customHeight = value
                            }
                        }

                        RowLayout {
                            enabled: settingsPage.root.diffidx === 4
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
                                value: settingsPage.settings.customMines
                                onValueChanged: settingsPage.settings.customMines = value
                            }
                        }

                        Button {
                            enabled: settingsPage.root.diffidx === 4
                            text: qsTr("Apply")
                            Layout.alignment: Qt.AlignRight
                            onClicked: {
                                settingsPage.root.gridSizeX = settingsPage.settings.customWidth
                                settingsPage.root.gridSizeY = settingsPage.settings.customHeight
                                settingsPage.root.mineCount = settingsPage.settings.customMines
                                settingsPage.root.initGame()
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
                                checked: settingsPage.settings.invertLRClick
                                onCheckedChanged: {
                                    settingsPage.settings.invertLRClick = checked
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
                                checked: settingsPage.settings.autoreveal
                                onCheckedChanged: {
                                    settingsPage.settings.autoreveal = checked
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
                                checked: settingsPage.settings.enableQuestionMarks
                                onCheckedChanged: {
                                    settingsPage.settings.enableQuestionMarks = checked
                                    if (!checked) {
                                        for (let i = 0; i < settingsPage.root.gridSizeX * settingsPage.root.gridSizeY; i++) {
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
                                text: qsTr("Enable green question marks")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: safeQuestionMarksSwitch.checked = !safeQuestionMarksSwitch.checked
                                }
                            }
                            Switch {
                                id: safeQuestionMarksSwitch
                                checked: settingsPage.settings.enableSafeQuestionMarks
                                onCheckedChanged: {
                                    settingsPage.settings.enableSafeQuestionMarks = checked
                                    if (!checked) {
                                        for (let i = 0; i < settingsPage.root.gridSizeX * settingsPage.root.gridSizeY; i++) {
                                            let cell = grid.itemAtIndex(i)
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
                                checked: settingsPage.settings.loadLastGame
                                onCheckedChanged: {
                                    settingsPage.settings.loadLastGame = checked
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
                                checked: settingsPage.settings.animations
                                onCheckedChanged: {
                                    settingsPage.settings.animations = checked
                                    for (let i = 0; i < settingsPage.root.gridSizeX * settingsPage.root.gridSizeY; i++) {
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
                                checked: settingsPage.settings.cellFrame
                                onCheckedChanged: {
                                    settingsPage.settings.cellFrame = checked
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
                                checked: settingsPage.settings.dimSatisfied
                                onCheckedChanged: {
                                    settingsPage.settings.dimSatisfied = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                enabled: !settingsPage.root.isGamescope
                                text: qsTr("Start in full screen")
                                Layout.fillWidth: true
                                MouseArea {
                                    enabled: !settingsPage.root.isGamescope
                                    anchors.fill: parent
                                    onClicked: startFullScreenSwitch.checked = !startFullScreenSwitch.checked
                                }
                            }
                            Switch {
                                id: startFullScreenSwitch
                                enabled: !settingsPage.root.isGamescope
                                checked: settingsPage.settings.startFullScreen || settingsPage.root.isGamescope
                                onCheckedChanged: {
                                    settingsPage.settings.startFullScreen = checked
                                }
                            }
                        }

                        RowLayout {
                            visible: settingsPage.root.isSteamEnabled
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
                                    checked: settingsPage.settings.flagSkinIndex === 0 || !settingsPage.root.isSteamEnabled
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    onCheckedChanged: {
                                        if (checked) settingsPage.settings.flagSkinIndex = 0
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: settingsPage.root.flag1Unlocked
                                    checkable: true
                                    checked: settingsPage.root.flag1Unlocked && settingsPage.settings.flagSkinIndex === 1
                                    icon.source: settingsPage.root.flag1Unlocked ? "qrc:/icons/flag1.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Trust Your Instincts achievement")
                                    onCheckedChanged: {
                                        if (checked) settingsPage.settings.flagSkinIndex = 1
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: settingsPage.root.flag2Unlocked
                                    checkable: true
                                    checked: settingsPage.root.flag1Unlocked && settingsPage.settings.flagSkinIndex === 2
                                    icon.source: settingsPage.root.flag2Unlocked ? "qrc:/icons/flag2.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Master Tactician achievement")
                                    onCheckedChanged: {
                                        if (checked) settingsPage.settings.flagSkinIndex = 2
                                    }
                                }
                            }

                            ColumnLayout {
                                Button {
                                    Layout.preferredWidth: 45
                                    Layout.preferredHeight: 45
                                    enabled: settingsPage.root.flag3Unlocked
                                    checkable: true
                                    checked: settingsPage.root.flag1Unlocked && settingsPage.settings.flagSkinIndex === 3
                                    icon.source: settingsPage.root.flag3Unlocked ? "qrc:/icons/flag3.png" : "qrc:/icons/locked.png"
                                    icon.width: 35
                                    icon.height: 35
                                    ButtonGroup.group: buttonGroup
                                    Layout.alignment: Qt.AlignHCenter
                                    ToolTip.visible: hovered && !enabled
                                    ToolTip.text: qsTr("Unlock Minefield Legend achievement")
                                    onCheckedChanged: {
                                        if (checked) settingsPage.settings.flagSkinIndex = 3
                                    }
                                }
                            }
                        }

                        RowLayout {
                            visible: settingsPage.root.isSteamEnabled
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Grid reset animation")
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                id: gridResetAnimationComboBox
                                model: ListModel {
                                    id: animationModel
                                    ListElement { text: qsTr("Wave"); enabled: true }
                                    ListElement { text: qsTr("Fade"); enabled: false }
                                    ListElement { text: qsTr("Spin"); enabled: false }
                                }

                                Component.onCompleted: {
                                    animationModel.setProperty(1, "enabled", settingsPage.root.anim1Unlocked)
                                    animationModel.setProperty(2, "enabled", settingsPage.root.anim2Unlocked)
                                }

                                Connections {
                                    target: settingsPage.root
                                    function onAnim1UnlockedChanged() {
                                        animationModel.setProperty(1, "enabled", settingsPage.root.anim1Unlocked)
                                    }
                                    function onAnim2UnlockedChanged() {
                                        animationModel.setProperty(2, "enabled", settingsPage.root.anim2Unlocked)
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
                                currentIndex: settingsPage.settings.gridResetAnimationIndex
                                onActivated: {
                                    settingsPage.settings.gridResetAnimationIndex = currentIndex
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
                                checked: settingsPage.settings.soundEffects
                                onCheckedChanged: {
                                    settingsPage.settings.soundEffects = checked
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
                                value: settingsPage.settings.volume
                                onValueChanged: {
                                    settingsPage.settings.volume = value
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
                                currentIndex: settingsPage.settings.soundPackIndex
                                onActivated: {
                                    settingsPage.settings.soundPackIndex = currentIndex
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
                                        color: sysPalette.highlight
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
                                currentIndex: settingsPage.settings.colorBlindness
                                onActivated: {
                                    settingsPage.settings.colorBlindness = currentIndex
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
                                    switch(settingsPage.settings.cellSize) {
                                    case 0: return 0;
                                    case 1: return 1;
                                    case 2: return 2;
                                    default: return 0;
                                    }
                                }

                                onActivated: {
                                    settingsPage.settings.cellSize = currentIndex
                                    if (!isMaximized && !isFullScreen) {
                                        settingsPage.root.minimumWidth = getInitialWidth()
                                        settingsPage.root.minimumHeight = getInitialHeight()
                                        settingsPage.root.width = settingsPage.root.minimumWidth
                                        settingsPage.root.height = settingsPage.root.minimumHeight
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
                                checked: settingsPage.settings.contrastFlag
                                onCheckedChanged: {
                                    settingsPage.settings.contrastFlag = checked
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
                                currentIndex: settingsPage.settings.languageIndex
                                onActivated: {
                                    previousLanguageIndex = currentIndex
                                    settingsPage.settings.languageIndex = currentIndex
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
                                text: qsTr("Advanced generation algorithm")
                                Layout.fillWidth: true
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: advGenAlgoSwitch.checked = !advGenAlgoSwitch.checked
                                }
                            }

                            InfoIcon {
                                tooltipText: qsTr("Enabled: Generates more chaotic grids\nDisabled: Generates more predictable grids")
                            }

                            Switch {
                                id: advGenAlgoSwitch
                                checked: settingsPage.settings.advGenAlgo
                                onCheckedChanged: {
                                    settingsPage.settings.advGenAlgo = checked
                                    if (checked) {
                                        settingsPage.settings.displaySeedAtGameOver = false
                                    }
                                }
                                Component.onCompleted: {
                                    if (checked && settingsPage.settings.displaySeedAtGameOver) {
                                        settingsPage.settings.displaySeedAtGameOver = false
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            enabled: !advGenAlgoSwitch.checked

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
                                checked: settingsPage.settings.displaySeedAtGameOver
                                onCheckedChanged: {
                                    settingsPage.settings.displaySeedAtGameOver = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            enabled: !advGenAlgoSwitch.checked

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
                                text: settingsPage.settings.fixedSeed >= 0 ? settingsPage.settings.fixedSeed.toString() : ""
                                onTextChanged: {
                                    settingsPage.settings.fixedSeed = text.length > 0 ? parseInt(text) : -1
                                }
                            }
                        }

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
                                model: {
                                    var themes = ["Fluent", "Universal", "Fusion"]
                                    return themes
                                }
                                Layout.rightMargin: 5
                                currentIndex: settingsPage.settings.themeIndex
                                onActivated: {
                                    if (settingsPage.root.gameStarted && !settingsPage.root.gameOver) {
                                        settingsPage.root.saveGame("internalGameState.json")
                                    }
                                    settingsPage.root.mainWindow.restartRetr0Mine(currentIndex)
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
                                model: {
                                    var colorSchemes = [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                                    return colorSchemes
                                }
                                Layout.rightMargin: 5

                                currentIndex: settingsPage.settings.colorSchemeIndex
                                onActivated: {
                                    settingsPage.settings.colorSchemeIndex = currentIndex
                                    settingsPage.root.mainWindow.setThemeColorScheme(currentIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
