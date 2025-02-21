import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: control
    required property var root
    required property var saveWindow
    required property var loadWindow
    required property var settingsWindow
    required property var leaderboardWindow
    required property var aboutLoader

    height: 40
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.leftMargin: 12
    anchors.rightMargin: 12

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
                    onTriggered: control.root.initGame()
                }

                MenuItem {
                    text: qsTr("Save game")
                    enabled: GameState.gameStarted && !GameState.gameOver
                    onTriggered: control.saveWindow.visible = true
                }

                MenuItem {
                    id: loadMenu
                    text: qsTr("Load game")
                    onTriggered: control.loadWindow.visible = true
                }

                MenuItem {
                    text: qsTr("Hint")
                    enabled: GameState.gameStarted && !GameState.gameOver
                    onTriggered: control.root.requestHint()
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Settings")
                    onTriggered: control.settingsWindow.visible = true
                }

                MenuItem {
                    text: qsTr("Leaderboard")
                    onTriggered: control.leaderboardWindow.visible = true
                }

                MenuItem {
                    text: qsTr("About")
                    height: !SteamIntegration.initialized ? implicitHeight : 0
                    visible: height > 0
                    onTriggered: control.aboutLoader.item.visible = true
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
            text: GameTimer.displayTime
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
            icon.color: Colors.foregroundColor
            text: ": " + (GameState.mineCount - GameState.flaggedCount)
            font.pixelSize: 18
            font.bold: true
            onClicked: {
                control.root.requestHint()
            }
        }
    }
}
