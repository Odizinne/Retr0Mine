import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ScrollingArea {
        anchors.fill: parent
        contentWidth: width - 12
        contentHeight: list.contentHeight
        ListView {
            id: list
            anchors.fill: parent
            spacing: Constants.settingsColumnSpacing
            clip: true
            interactive: false
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
                id: shortcutLine
                required property var model
                width: ListView.view.width -5

                RowLayout {
                    Layout.preferredHeight: Constants.settingsComponentsHeight
                    anchors.fill: parent
                    Label {
                        text: shortcutLine.model.title
                        Layout.fillWidth: true
                    }
                    Label {
                        color: Constants.accentColor
                        text: shortcutLine.model.shortcut
                        font.bold: true
                    }
                }
            }
        }
    }
}
