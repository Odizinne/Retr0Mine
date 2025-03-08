pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
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
                        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                            NetworkManager.resetMultiplayerGrid()
                        }
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

            Label {
                id: densityLabel
                font.bold: true
                text: {
                    const density = (minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1);
                    return density + "%";
                }
                color: {
                    const density = minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100;
                    if (density <= 15) return "green";
                    else if (density <= 18) return "yellow";
                    else if (density <= 22) return "orange";
                    else return "red";
                }

                Connections {
                    target: minesSpinBox
                    function onValueChanged() { densityLabel.text = Qt.binding(function() { return (minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1) + "%"; }); }
                }
                Connections {
                    target: widthSpinBox
                    function onValueChanged() { densityLabel.text = Qt.binding(function() { return (minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1) + "%"; }); }
                }
                Connections {
                    target: heightSpinBox
                    function onValueChanged() { densityLabel.text = Qt.binding(function() { return (minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1) + "%"; }); }
                }
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
            property int previousCustomWidth: 0
            property int previousCustomHeight: 0
            onClicked: {
                if (previousCustomWidth !== GameSettings.customWidth || previousCustomHeight !== GameSettings.customHeight) {
                    GridBridge.cellsCreated = 0
                }

                GameState.gridSizeX = GameSettings.customWidth
                GameState.gridSizeY = GameSettings.customHeight
                GameState.mineCount = GameSettings.customMines

                previousCustomWidth = GameSettings.customWidth
                previousCustomHeight = GameSettings.customHeight
                GridBridge.initGame()

                if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                    NetworkManager.resetMultiplayerGrid()
                }
            }

            Component.onCompleted: {
                previousCustomWidth = GameSettings.customWidth
                previousCustomHeight = GameSettings.customHeight
            }
        }
    }
}
