import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    anchors.centerIn: parent
    id: gameOverWindow
    height: 100
    width: 250
    visible: false

    property string gameOverLabelText: "Game Over :("
    property string gameOverLabelColor: "#d12844"

    Shortcut {
        sequence: "Return"
        enabled: gameOverWindow.visible
        onActivated: {
            gameOverWindow.close()
            root.initGame()
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: gameOverWindow.visible
        onActivated: gameOverWindow.close()
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: 10
        Label {
            id: gameOverLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: gameOverWindow.gameOverLabelText
            color: gameOverWindow.gameOverLabelColor
            Layout.columnSpan: 2
            font.bold: true
            font.pixelSize: 16
        }

        Button {
            text: qsTr("Retry")
            Layout.fillWidth: true
            onClicked: {
                gameOverWindow.close()
                root.initGame()
            }
        }

        Button {
            text: qsTr("Close")
            Layout.fillWidth: true
            onClicked: {
                gameOverWindow.close()
            }
        }
    }
}
