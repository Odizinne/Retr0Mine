import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ColumnLayout {
        spacing: Constants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.safeFirstClick
                onCheckedChanged: {
                    UserSettings.safeFirstClick = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.invertLRClick
                onCheckedChanged: {
                    UserSettings.invertLRClick = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.autoreveal
                onCheckedChanged: {
                    UserSettings.autoreveal = checked
                }
            }
        }

        RowLayout {
            enabled: !SteamIntegration.isInMultiplayerGame
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.enableQuestionMarks
                onCheckedChanged: {
                    UserSettings.enableQuestionMarks = checked
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
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.enableSafeQuestionMarks
                onCheckedChanged: {
                    UserSettings.enableSafeQuestionMarks = checked
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
            Layout.preferredHeight: Constants.settingsComponentsHeight

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
                checked: UserSettings.loadLastGame
                onCheckedChanged: {
                    UserSettings.loadLastGame = checked
                }
            }
        }

        RowLayout {
            enabled: false
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Show hint reasoning in chat")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: hintReasoningInChatSwitch.click()
                }
            }

            InfoIcon {
                tooltipText: "Disabled for now as it is inacurate\nRework is needed"
            }

            NfSwitch {
                id: hintReasoningInChatSwitch
                checked: UserSettings.hintReasoningInChat
                onCheckedChanged: UserSettings.hintReasoningInChat = checked
            }
        }

        RowLayout {
            visible: SteamIntegration.isRunningOnSteamDeck && GameCore.gamescope
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("SteamDeck controls")
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Remap")
                onClicked: SteamIntegration.showControllerBindingPanel()
                Layout.rightMargin: 5
            }
        }
    }
}
