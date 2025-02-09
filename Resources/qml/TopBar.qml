import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: topBar
    required property var root
    required property var settings
    required property var saveWindow
    required property var loadWindow
    required property var settingsWindow
    required property var leaderboardWindow
    required property var aboutPage
    height: 40
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.leftMargin: 12
    anchors.rightMargin: 12

    property string elapsedTimeLabelText: "HH:MM:SS"

    RowLayout {
        spacing: 6
        Layout.preferredWidth: parent.width / 3

        Button {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredHeight: 35
            text: "Menu"
            onClicked: {
                menu.visible ? menu.close() : menu.open()
            }

            Menu {
                topMargin: 60
                id: menu
                width: 150
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                MenuItem {
                    text: qsTr("New game")
                    onTriggered: topBar.root.initGame()
                }

                MenuItem {
                    text: qsTr("Save game")
                    enabled: topBar.root.gameStarted
                    onTriggered: topBar.saveWindow.visible = true
                }
                MenuItem {
                    id: loadMenu
                    text: qsTr("Load game")
                    onTriggered: topBar.loadWindow.visible = true
                }

                MenuItem {
                    text: qsTr("Hint")
                    enabled: topBar.root.gameStarted && !topBar.root.gameOver
                    onTriggered: topBar.root.requestHint()
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Settings")
                    onTriggered: topBar.settingsWindow.visible = true
                }

                MenuItem {
                    text: qsTr("Leaderboard")
                    onTriggered: topBar.leaderboardWindow.visible = true
                }

                MenuItem {
                    text: qsTr("About")
                    onTriggered: topBar.aboutPage.visible = true
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Exit")
                    onTriggered: Qt.quit()
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }


    RowLayout {
        Layout.preferredWidth: parent.width / 3
        Layout.fillWidth: true
        Label {
            id: elapsedTimeLabel
            text: topBar.elapsedTimeLabelText
            font.pixelSize: 18
            Layout.alignment: Qt.AlignCenter
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: 2
        spacing: 12
        Layout.preferredWidth: parent.width / 3
        Item {
            Layout.fillWidth: true
        }
        Button {
            icon.source: "qrc:/icons/bomb.png"
            icon.color: topBar.root.darkMode ? "white" : "dark"
            text: ": " + (topBar.root.mineCount - topBar.root.flaggedCount)
            font.pixelSize: 18
            font.bold: true
            onClicked: {
                topBar.root.requestHint()
            }
        }
    }
}
