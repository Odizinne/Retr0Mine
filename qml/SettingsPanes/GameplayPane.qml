import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ScrollingArea {
        anchors.fill: parent
        contentWidth: width - 12
        contentHeight: lyt.implicitHeight

        ColumnLayout {
            id: lyt
            spacing: Constants.settingsColumnSpacing
            anchors.fill: parent

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
                    tooltipText: qsTr("Work in progress\nCan be inaccurate")
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

                NfButton {
                    text: qsTr("Remap")
                    onClicked: SteamIntegration.showControllerBindingPanel()
                    Layout.rightMargin: 5
                }
            }

            RowLayout {
                visible: SteamIntegration.isRunningOnSteamDeck
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight

                Label {
                    text: qsTr("Haptic fedback")
                    Layout.fillWidth: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: rumbleSwitch.click()
                    }
                }

                NfSwitch {
                    id: rumbleSwitch
                    checked: UserSettings.rumble
                    onCheckedChanged: {
                        UserSettings.rumble = checked
                        if (checked) {
                            SteamIntegration.triggerRumble(1, 1, 0.5)
                        }
                    }

                }
            }

            RowLayout {
                enabled: !GameCore.gamescope
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight
                Label {
                    text: qsTr("Reveal key")
                    Layout.fillWidth: true
                }
                TextField {
                    id: revealKeyField
                    text: UserSettings.revealShortcut
                    Layout.rightMargin: 5
                    maximumLength: 1
                    inputMethodHints: Qt.ImhUppercaseOnly
                    implicitWidth: 50
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: 16
                    onEditingFinished: {
                        if (text.length > 0) {
                            UserSettings.revealShortcut = text.toUpperCase()
                        } else {
                            text = UserSettings.revealShortcut
                        }
                    }
                }
            }

            RowLayout {
                enabled: !GameCore.gamescope
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight
                Label {
                    text: qsTr("Flag key")
                    Layout.fillWidth: true
                }
                TextField {
                    id: flagKeyField
                    text: UserSettings.flagShortcut
                    Layout.rightMargin: 5
                    maximumLength: 1
                    inputMethodHints: Qt.ImhUppercaseOnly
                    implicitWidth: 50
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: 16
                    onEditingFinished: {
                        if (text.length > 0) {
                            UserSettings.flagShortcut = text.toUpperCase()
                        } else {
                            text = UserSettings.flagShortcut
                        }
                    }
                }
            }

            RowLayout {
                enabled: !GameCore.gamescope
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight
                Label {
                    text: qsTr("Question mark key")
                    Layout.fillWidth: true
                }
                TextField {
                    id: questionmarkKeyField
                    text: UserSettings.questionedShortcut
                    Layout.rightMargin: 5
                    maximumLength: 1
                    inputMethodHints: Qt.ImhUppercaseOnly
                    implicitWidth: 50
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: 16
                    onEditingFinished: {
                        if (text.length > 0) {
                            UserSettings.questionedShortcut = text.toUpperCase()
                        } else {
                            text = UserSettings.questionedShortcut
                        }
                    }
                }
            }

            RowLayout {
                enabled: !GameCore.gamescope
                Layout.fillWidth: true
                Layout.preferredHeight: Constants.settingsComponentsHeight
                Label {
                    text: qsTr("Green question mark key")
                    Layout.fillWidth: true
                }
                TextField {
                    id: safeQuestionmarkKeyField
                    text: UserSettings.safeQuestionedShortcut
                    Layout.rightMargin: 5
                    maximumLength: 1
                    inputMethodHints: Qt.ImhUppercaseOnly
                    implicitWidth: 50
                    horizontalAlignment: TextInput.AlignHCenter
                    font.pixelSize: 16
                    onEditingFinished: {
                        if (text.length > 0) {
                            UserSettings.safeQuestionedShortcut = text.toUpperCase()
                        } else {
                            text = UserSettings.safeQuestionedShortcut
                        }
                    }
                }
            }
        }
    }
}
