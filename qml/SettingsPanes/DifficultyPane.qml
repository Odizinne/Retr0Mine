pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ColumnLayout {
        enabled: !(SteamIntegration.isInMultiplayerGame && !SteamIntegration.isHost)
        width: parent.width
        spacing: Constants.settingsColumnSpacing

        ButtonGroup {
            id: difficultyGroup
            exclusive: true
        }

        Repeater {
            model: GameState.difficultySettings
            RowLayout {
                id: difficultyRow
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight
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
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    Layout.preferredWidth: Constants.settingsComponentsHeight
                    Layout.alignment: Qt.AlignRight
                    ButtonGroup.group: difficultyGroup
                    checked: UserSettings.difficulty === parent.index
                    onClicked: {
                        const idx = difficultyGroup.buttons.indexOf(this)
                        const difficultySet = GameState.difficultySettings[idx]
                        if (UserSettings.difficulty === idx) return

                        const dimensionsMatch = (
                            (idx !== 4 &&
                             UserSettings.difficulty === 4 &&
                             UserSettings.customWidth === difficultySet.x &&
                             UserSettings.customHeight === difficultySet.y) ||
                            (idx === 4 &&
                             UserSettings.difficulty !== 4 &&
                             UserSettings.customWidth === GameState.difficultySettings[UserSettings.difficulty].x &&
                             UserSettings.customHeight === GameState.difficultySettings[UserSettings.difficulty].y)
                        )

                        GameState.difficultyChanged = true

                        if (!dimensionsMatch) {
                            GridBridge.cellsCreated = 0
                        }

                        GameState.gridSizeX = difficultySet.x
                        GameState.gridSizeY = difficultySet.y
                        GameState.mineCount = difficultySet.mines
                        GridBridge.initGame()
                        UserSettings.difficulty = idx
                        SteamIntegration.difficulty = idx

                        GameState.ignoreInternalGameState = true

                        if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                            NetworkManager.resetMultiplayerGrid()
                        }
                    }
                }
            }
        }

        RowLayout {
            enabled: UserSettings.difficulty === 4
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

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
                value: UserSettings.customWidth
                onValueChanged: UserSettings.customWidth = value
            }
        }

        RowLayout {
            enabled: UserSettings.difficulty === 4
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

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
                value: UserSettings.customHeight
                onValueChanged: UserSettings.customHeight = value
            }
        }

        RowLayout {
            enabled: UserSettings.difficulty === 4
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Mines:")
                Layout.fillWidth: true
            }

            RowLayout {
                visible: !UserSettings.mineDensity
                Layout.alignment: Qt.AlignRight

                Label {
                    id: countDensityLabel
                    font.bold: true
                    Layout.rightMargin: 5
                    property real density: (countSpinBox.value / (widthSpinBox.value * heightSpinBox.value) * 100).toFixed(1)
                    text: density + "%"
                }

                InfoIcon {
                    visible: countDensityLabel.density >= 25
                    tooltipText: qsTr("Going above 25% may really slow down\nboard generation on large grids")
                    Layout.rightMargin: 5
                    Layout.leftMargin: 5
                }

                NfButton {
                    Layout.preferredWidth: height
                    text: "%"
                    checkable: true
                    checked: UserSettings.mineDensity
                    onCheckedChanged: {
                        if (checked) {
                            const percentage = Math.round((countSpinBox.value / (widthSpinBox.value * heightSpinBox.value)) * 100)
                            percentSpinBox.value = Math.min(Math.max(percentage, 1), 30)
                        } else {
                            const mineCount = Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100)
                            countSpinBox.value = Math.min(Math.max(mineCount, 1),
                                Math.floor((widthSpinBox.value * heightSpinBox.value) * 0.3))
                        }
                        UserSettings.mineDensity = checked
                    }
                }

                NfSpinBox {
                    id: countSpinBox
                    Layout.rightMargin: 5
                    from: 1
                    to: Math.floor((widthSpinBox.value * heightSpinBox.value) * 0.25)
                    editable: true
                    value: UserSettings.customMines
                    onValueChanged: UserSettings.customMines = value
                }
            }

            RowLayout {
                visible: UserSettings.mineDensity
                Layout.alignment: Qt.AlignRight

                Label {
                    id: percentMineCountLabel
                    font.bold: true
                    Layout.rightMargin: 5
                    property int mineCount: Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100)
                    text: mineCount + " " + qsTr("mines")

                    Connections {
                        target: percentSpinBox
                        function onValueChanged() {
                            percentMineCountLabel.text = Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100) + " " + qsTr("mines")
                        }
                    }
                    Connections {
                        target: widthSpinBox
                        function onValueChanged() {
                            percentMineCountLabel.text = Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100) + " " + qsTr("mines")
                        }
                    }
                    Connections {
                        target: heightSpinBox
                        function onValueChanged() {
                            percentMineCountLabel.text = Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100) + " " + qsTr("mines")
                        }
                    }
                }

                InfoIcon {
                    visible: percentSpinBox.value >= 25
                    tooltipText: qsTr("Going above 25% may really slow down\nboard generation on large grids")
                    Layout.rightMargin: 5
                    Layout.leftMargin: 5
                }

                NfButton {
                    Layout.preferredWidth: height
                    text: "%"
                    checkable: true
                    checked: UserSettings.mineDensity
                    onCheckedChanged: {
                        if (checked) {
                            // Calculate percentage from current mine count
                            const percentage = Math.round((countSpinBox.value / (widthSpinBox.value * heightSpinBox.value)) * 100)
                            percentSpinBox.value = Math.min(Math.max(percentage, 1), 30)
                        } else {
                            // Calculate mine count from current percentage
                            const mineCount = Math.round((widthSpinBox.value * heightSpinBox.value) * percentSpinBox.value / 100)
                            countSpinBox.value = Math.min(Math.max(mineCount, 1),
                                Math.floor((widthSpinBox.value * heightSpinBox.value) * 0.3))
                        }
                        UserSettings.mineDensity = checked
                    }
                }

                NfSpinBox {
                    id: percentSpinBox
                    Layout.rightMargin: 5
                    from: 1
                    to: 25

                    Component.onCompleted: {
                        value = Math.round((UserSettings.customMines / (widthSpinBox.value * heightSpinBox.value)) * 100)
                    }

                    onValueChanged: {
                        const mineCount = Math.round((widthSpinBox.value * heightSpinBox.value) * value / 100)
                        UserSettings.customMines = mineCount
                    }
                }
            }
        }

        NfButton {
            enabled: UserSettings.difficulty === 4
            Layout.rightMargin: 5
            text: qsTr("Apply")
            Layout.alignment: Qt.AlignRight
            property int previousCustomWidth: 0
            property int previousCustomHeight: 0
            onClicked: {
                if (previousCustomWidth !== UserSettings.customWidth || previousCustomHeight !== UserSettings.customHeight) {
                    GridBridge.cellsCreated = 0
                }

                if (UserSettings.mineDensity) {
                    const mineCount = Math.round((UserSettings.customWidth * UserSettings.customHeight) * percentSpinBox.value / 100)
                    UserSettings.customMines = mineCount
                }

                GameState.gridSizeX = UserSettings.customWidth
                GameState.gridSizeY = UserSettings.customHeight
                GameState.mineCount = UserSettings.customMines

                previousCustomWidth = UserSettings.customWidth
                previousCustomHeight = UserSettings.customHeight

                GameState.ignoreInternalGameState = true

                GridBridge.initGame()

                if (SteamIntegration.isInMultiplayerGame && SteamIntegration.isHost) {
                    NetworkManager.resetMultiplayerGrid()
                }
            }

            Component.onCompleted: {
                previousCustomWidth = UserSettings.customWidth
                previousCustomHeight = UserSettings.customHeight
            }
        }
    }
}
