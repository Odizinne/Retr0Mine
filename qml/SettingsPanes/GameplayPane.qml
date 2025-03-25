import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        spacing: GameConstants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("First click protection")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: safeFirstClickSwitch.click()
                }
            }

            InfoIcon {
                tooltipText: qsTr("First click always lands on a safe tile")
            }

            NfSwitch {
                id: safeFirstClickSwitch
                checked: GameSettings.safeFirstClick
                onCheckedChanged: {
                    GameSettings.safeFirstClick = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Invert left and right click")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: invertLRSwitch.click()
                }
            }
            NfSwitch {
                id: invertLRSwitch
                checked: GameSettings.invertLRClick
                onCheckedChanged: {
                    GameSettings.invertLRClick = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Quick reveal connected cells")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: autorevealSwitch.click()
                }
            }
            NfSwitch {
                id: autorevealSwitch
                checked: GameSettings.autoreveal
                onCheckedChanged: {
                    GameSettings.autoreveal = checked
                }
            }
        }

        RowLayout {
            enabled: !SteamIntegration.isInMultiplayerGame
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Enable question marks")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: questionMarksSwitch.click()
                }
            }
            NfSwitch {
                id: questionMarksSwitch
                checked: GameSettings.enableQuestionMarks
                onCheckedChanged: {
                    GameSettings.enableQuestionMarks = checked
                    if (!checked) {
                        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                            let cell = GridBridge.grid.itemAtIndex(i) as Cell
                            if (cell && cell.questioned) {
                                cell.questioned = false
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            enabled: !SteamIntegration.isInMultiplayerGame
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Enable green question marks")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: safeQuestionMarksSwitch.click()
                }
            }
            NfSwitch {
                id: safeQuestionMarksSwitch
                checked: GameSettings.enableSafeQuestionMarks
                onCheckedChanged: {
                    GameSettings.enableSafeQuestionMarks = checked
                    if (!checked) {
                        for (let i = 0; i < GameState.gridSizeX * GameState.gridSizeY; i++) {
                            let cell = GridBridge.grid.itemAtIndex(i) as Cell
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
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Load last game on start")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: loadLastGameSwitch.click()
                }
            }
            NfSwitch {
                id: loadLastGameSwitch
                checked: GameSettings.loadLastGame
                onCheckedChanged: {
                    GameSettings.loadLastGame = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Show hint reasoning in chat")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: hintReasoningInChatSwitch.click()
                }
            }
            NfSwitch {
                id: hintReasoningInChatSwitch
                checked: GameSettings.hintReasoningInChat
                onCheckedChanged: {
                    GameSettings.hintReasoningInChat = checked
                }
            }
        }

        RowLayout {
            visible: SteamIntegration.isRunningOnSteamDeck && GameCore.gamescope
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("SteamDeck controls")
                Layout.fillWidth: true
            }
            Button {
                text: qsTr("Remap")
                onClicked: SteamIntegration.showControllerBindingPanel()
            }
        }
    }
}
