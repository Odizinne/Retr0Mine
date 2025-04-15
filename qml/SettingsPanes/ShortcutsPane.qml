import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ScrollingArea {
        anchors.fill: parent
        contentWidth: width - 12
        contentHeight: columnLayout.height

        ColumnLayout {
            id: columnLayout
            width: parent.width
            spacing: Constants.settingsColumnSpacing

            Label {
                text: qsTr("Gameplay")
                font.bold: true
                font.pixelSize: 20
                Layout.fillWidth: true
            }

            Frame {
                Layout.fillWidth: true
                RowLayout {
                    enabled: !GameCore.gamescope
                    anchors.fill: parent
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    Label {
                        text: qsTr("Reveal")
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
            }

            Frame {
                Layout.fillWidth: true
                RowLayout {
                    enabled: !GameCore.gamescope
                    anchors.fill: parent
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    Label {
                        text: qsTr("Flag")
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
            }

            Frame {
                Layout.fillWidth: true
                RowLayout {
                    enabled: !GameCore.gamescope
                    anchors.fill: parent
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    Label {
                        text: qsTr("Question mark")
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
            }

            Frame {
                Layout.fillWidth: true
                RowLayout {
                    enabled: !GameCore.gamescope
                    anchors.fill: parent
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    Label {
                        text: qsTr("Green question mark")
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

            Label {
                text: qsTr("Global")
                font.bold: true
                font.pixelSize: 20
                Layout.fillWidth: true
            }

            Repeater {
                model: ListModel {
                    ListElement {
                        title: qsTr("Fullscreen")
                        shortcut: "F11"
                    }
                    ListElement {
                        title: qsTr("Zoom")
                        shortcut: qsTr("Ctrl + Wheel")
                    }
                    ListElement {
                        title: qsTr("Signal a cell")
                        shortcut: qsTr("G / Mouse middle")
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
                        title: qsTr("Load game")
                        shortcut: "Ctrl + O"
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
                    id: frameElem
                    required property var model
                    Layout.fillWidth: true

                    RowLayout {
                        Layout.preferredHeight: Constants.settingsComponentsHeight
                        anchors.fill: parent
                        Label {
                            text: frameElem.model.title
                            Layout.fillWidth: true
                        }
                        Label {
                            color: Constants.accentColor
                            text: frameElem.model.shortcut
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
