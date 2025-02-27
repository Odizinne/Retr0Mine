import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

RowLayout {
    id: control
    height: 40
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: 12
        leftMargin: 12
        rightMargin: 12
    }

    Button {
        Layout.alignment: Qt.AlignLeft
        Layout.preferredHeight: 35
        text: "Menu"
        onClicked: {
            mainMenu.visible = !mainMenu.visible
        }

        MainMenu {
            id: mainMenu
        }
    }

    Label {
        id: elapsedTimeLabel
        text: GameTimer.displayTime
        visible: GameSettings.displayTimer
        font.pixelSize: 18
        Layout.alignment: Qt.AlignCenter
    }

    Button {
        Layout.alignment: Qt.AlignRight
        icon.source: "qrc:/icons/bomb.png"
        icon.color: GameConstants.foregroundColor
        text: ": " + (GameState.mineCount - GameState.flaggedCount)
        font.pixelSize: 18
        font.bold: true
        onClicked: {
            GridBridge.requestHint()
        }
    }
}
