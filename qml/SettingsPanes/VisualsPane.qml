pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Controls.impl
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ScrollingArea {
        anchors.fill: parent
        contentWidth: width - 12
        contentHeight: lyt.implicitHeight

        ColumnLayout {
            id: lyt
            spacing: GameConstants.settingsColumnSpacing
            anchors.fill: parent
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight

                Label {
                    text: qsTr("Animations")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: animationsSwitch.click()
                    }
                }
                NfSwitch {
                    id: animationsSwitch
                    checked: GameSettings.animations
                    onCheckedChanged: {
                        GameSettings.animations = checked
                        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                            let cell = GridBridge.grid.itemAtIndex(i) as Cell
                            if (cell) {
                                cell.opacity = 1
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight

                Label {
                    text: qsTr("Display timer")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: displayTimerSwitch.click()
                    }
                }
                NfSwitch {
                    id: displayTimerSwitch
                    checked: GameSettings.displayTimer
                    onCheckedChanged: GameSettings.displayTimer = checked
                }
            }

            RowLayout {
                enabled: !GameCore.gamescope
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Start in full screen")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: startFullScreenSwitch.click()
                    }
                }
                NfSwitch {
                    id: startFullScreenSwitch
                    checked: GameSettings.startFullScreen || GameCore.gamescope
                    onCheckedChanged: {
                        GameSettings.startFullScreen = checked
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Revealed cells frame")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: cellFrameSwitch.click()
                    }
                }
                NfSwitch {
                    id: cellFrameSwitch
                    checked: GameSettings.cellFrame
                    onCheckedChanged: {
                        GameSettings.cellFrame = checked
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Shake partially satisfied cells")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: shakeUnifinishedNumbersSwitch.click()
                    }
                }
                NfSwitch {
                    id: shakeUnifinishedNumbersSwitch
                    checked: GameSettings.shakeUnifinishedNumbers
                    onCheckedChanged: {
                        GameSettings.shakeUnifinishedNumbers = checked
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Dim satisfied cells")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: dimSatisfiedSwitch.click()
                    }
                }
                NfSwitch {
                    id: dimSatisfiedSwitch
                    checked: GameSettings.dimSatisfied
                    onCheckedChanged: {
                        GameSettings.dimSatisfied = checked
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                enabled: GameSettings.dimSatisfied
                Label {
                    text: qsTr("Dim level")
                    Layout.fillWidth: true
                }
                NfSlider {
                    id: dimmedOpacitySlider
                    from: 0.3
                    to: 0.8
                    value: GameSettings.satisfiedOpacity
                    onValueChanged: GameSettings.satisfiedOpacity = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Numbers font")
                    Layout.fillWidth: true
                }

                NfComboBox {
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
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
                Label {
                    text: qsTr("Grid reset animation")
                    Layout.fillWidth: true
                }
                NfComboBox {
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
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
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

                NfButton {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    checkable: true
                    checked: GameSettings.flagSkinIndex === 0 || !SteamIntegration.initialized
                    ButtonGroup.group: buttonGroup
                    Layout.alignment: Qt.AlignHCenter
                    onCheckedChanged: {
                        if (checked) GameSettings.flagSkinIndex = 0
                    }

                    IconImage {
                        source: "qrc:/icons/flag.png"
                        sourceSize.width: 20
                        sourceSize.height: 20
                        anchors.fill: parent
                    }
                }

                NfButton {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    enabled: GameState.flag1Unlocked
                    checkable: true
                    checked: GameState.flag1Unlocked && GameSettings.flagSkinIndex === 1
                    ButtonGroup.group: buttonGroup
                    Layout.alignment: Qt.AlignHCenter
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: qsTr("Unlock Trust Your Instincts achievement")
                    onCheckedChanged: {
                        if (checked) GameSettings.flagSkinIndex = 1
                    }

                    IconImage {
                        source: GameState.flag1Unlocked ? "qrc:/icons/flag1.png" : "qrc:/icons/locked.png"
                        sourceSize.width: 20
                        sourceSize.height: 20
                        anchors.fill: parent
                    }
                }

                NfButton {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    enabled: GameState.flag2Unlocked
                    checkable: true
                    checked: GameState.flag2Unlocked && GameSettings.flagSkinIndex === 2
                    ButtonGroup.group: buttonGroup
                    Layout.alignment: Qt.AlignHCenter
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: qsTr("Unlock Master Tactician achievement")
                    onCheckedChanged: {
                        if (checked) GameSettings.flagSkinIndex = 2
                    }

                    IconImage {
                        source: GameState.flag2Unlocked ? "qrc:/icons/flag2.png" : "qrc:/icons/locked.png"
                        sourceSize.width: 20
                        sourceSize.height: 20
                        anchors.fill: parent
                    }
                }

                NfButton {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    enabled: GameState.flag3Unlocked
                    checkable: true
                    checked: GameState.flag3Unlocked && GameSettings.flagSkinIndex === 3
                    ButtonGroup.group: buttonGroup
                    Layout.alignment: Qt.AlignHCenter
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: qsTr("Unlock Minefield Legend achievement")
                    onCheckedChanged: {
                        if (checked) GameSettings.flagSkinIndex = 3
                    }

                    IconImage {
                        source: GameState.flag3Unlocked ? "qrc:/icons/flag3.png" : "qrc:/icons/locked.png"
                        sourceSize.width: 20
                        sourceSize.height: 20
                        anchors.fill: parent
                    }
                }
            }
        }
    }
}
