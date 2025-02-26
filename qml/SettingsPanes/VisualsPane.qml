pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    id: pane
    required property var control
    ColumnLayout {
        spacing: 20
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
                        let cell = pane.control.grid.itemAtIndex(i) as Cell
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
                text: qsTr("Display timer")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: displayTimerSwitch.click()
                }
            }
            Switch {
                id: displayTimerSwitch
                checked: GameSettings.displayTimer
                onCheckedChanged: GameSettings.displayTimer = checked
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
            Layout.rightMargin: 5

            ButtonGroup {
                id: buttonGroup
                exclusive: true
            }

            Label {
                text: qsTr("Flag")
                Layout.fillWidth: true
            }

            Button {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
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
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
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
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
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
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
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
