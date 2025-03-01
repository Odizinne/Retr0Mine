pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        width: parent.width
        spacing: GameCore.isFluent ? 10 : 20

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
                        if (GameSettings.difficulty === idx) return
                        GameState.difficultyChanged = true
                        GridBridge.cellsCreated = 0
                        GameState.gridSizeX = difficultySet.x
                        GameState.gridSizeY = difficultySet.y
                        GameState.mineCount = difficultySet.mines
                        GridBridge.initGame()
                        GameSettings.difficulty = idx
                        SteamIntegration.difficulty = idx
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
                GridBridge.initGame()
            }
        }
    }
}
