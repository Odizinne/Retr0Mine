import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ScrollView {
        anchors.fill: parent

        ListView {
            anchors.fill: parent
            spacing: 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: ListModel {
                ListElement {
                    title: qsTr("Fullscreen")
                    shortcut: "F11"
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
                    anchors.fill: parent
                    Label {
                        text: shortcutLine.model.title
                        Layout.fillWidth: true
                    }
                    Label {
                        color: GameConstants.accentColor
                        text: shortcutLine.model.shortcut
                        font.bold: true
                    }
                }
            }
        }
    }
}
