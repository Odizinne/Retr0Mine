pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ColumnLayout {
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        width: parent.width
        spacing: GameConstants.settingsColumnSpacing

        ButtonGroup {
            id: difficultyGroup
            exclusive: true
        }

        Repeater {
            model: GameState.difficultySettings
            RowLayout {
                id: difficultyRow
                Layout.fillWidth: true
                Layout.preferredHeight: GameConstants.settingsComponentsHeight
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

                NfRadioButton {
                    id: radioButton
                    Layout.preferredHeight: GameConstants.settingsComponentsHeight
                    Layout.preferredWidth: GameConstants.settingsComponentsHeight
                    Layout.alignment: Qt.AlignRight
                    ButtonGroup.group: difficultyGroup
                    checked: GameSettings.difficulty === parent.index
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
                        const difficultySet = GameState.difficultySettings[idx]
                        if (GameSettings.difficulty === idx) return

                        const dimensionsMatch = (
                            (idx !== 4 &&
                             GameSettings.difficulty === 4 &&
                             GameSettings.customWidth === difficultySet.x &&
                             GameSettings.customHeight === difficultySet.y) ||
                            (idx === 4 &&
                             GameSettings.difficulty !== 4 &&
                             GameSettings.customWidth === GameState.difficultySettings[GameSettings.difficulty].x &&
                             GameSettings.customHeight === GameState.difficultySettings[GameSettings.difficulty].y)
                        )

                        GameState.difficultyChanged = true

                        if (!dimensionsMatch) {
                            GridBridge.cellsCreated = 0
                        }

                        GameState.gridSizeX = difficultySet.x
                        GameState.gridSizeY = difficultySet.y
                        GameState.mineCount = difficultySet.mines
                        GridBridge.initGame()
                        GameSettings.difficulty = idx
                        SteamIntegration.difficulty = idx

                        /*==========================================
                         | bypass internalGameState loading        |
                         | if user manually change difficulty      |
                         | before initial game state check         |
                         ==========================================*/
                        GameState.ignoreInternalGameState = true

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
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Width:")
                Layout.fillWidth: true
            }

            NfSpinBox {
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
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Height:")
                Layout.fillWidth: true
            }
            NfSpinBox {
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
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Mines:")
                Layout.fillWidth: true
            }

            Label {
                id: densityLabel
                font.bold: true
                visible: enabled
                Layout.rightMargin: 5
                property real density: (minesSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1)
                text: {
                    return density + "%";
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

            InfoIcon {
                visible: densityLabel.density >= 25
                tooltipText: qsTr("Going above 25% may really slow down\nboard generation on large grids")
                Layout.rightMargin: 5
                Layout.leftMargin: 5
            }

            NfSpinBox {
                id: minesSpinBox
                Layout.rightMargin: 5
                from: 1
                to: Math.floor((widthSpinBox.value * heightSpinBox.value) * 0.3)
                editable: true
                value: GameSettings.customMines
                onValueChanged: GameSettings.customMines = value
            }
        }

        NfButton {
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

                /*==========================================
                 | bypass internalGameState loading        |
                 | if user manually change difficulty      |
                 | before initial game state check         |
                 ==========================================*/
                GameState.ignoreInternalGameState = true

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
