import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id:topBar
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
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            icon.source: "qrc:/icons/menu.png"
            icon.color: root.darkMode ? "white" : "black"
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
                    onTriggered: root.initGame()
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Hint")
                    enabled: root.gameStarted && !root.gameOver && root.flaggedCount > 0
                    onTriggered: root.requestHint()
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Save game")
                    enabled: root.gameStarted
                    onTriggered: saveWindow.visible = true
                }
                MenuItem {
                    id: loadMenu
                    text: qsTr("Load game")
                    onTriggered: loadWindow.visible = true
                }

                MenuSeparator { }

                MenuItem {
                    text: qsTr("Settings")
                    onTriggered: settingsWindow.visible = true
                }

                MenuItem {
                    text: qsTr("About")
                    onTriggered: aboutPage.visible = true
                }

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
        Text {
            id: elapsedTimeLabel
            text: topBar.elapsedTimeLabelText
            color: root.darkMode ? "white" : "black"
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
        Image {
            Layout.alignment: Qt.AlignRight
            source: root.darkMode ? "qrc:/icons/bomb_light.png" : "qrc:/icons/bomb_dark.png"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
        Text {
            Layout.alignment: Qt.AlignRight
            text: ": " + (root.mineCount - root.flaggedCount)
            color: root.darkMode ? "white" : "black"
            font.pixelSize: 18
            font.bold: true
        }
    }
}
