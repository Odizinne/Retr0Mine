import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    anchors.centerIn: parent
    id: gameOverWindow
    required property var root
    required property var settings
    required property var numberFont
    visible: false
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 300
    property int buttonWidth: Math.max(retryButton.implicitWidth, closeButton.implicitWidth)
    property string notificationText
    property bool notificationVisible: false
    property string gameOverLabelText: "Game Over"
    property string gameOverLabelColor: "#d12844"
    property bool newRecordVisible: false
    property int seed: -1
    property int clickX: -1
    property int clickY: -1

    Shortcut {
        sequence: "Return"
        enabled: gameOverWindow.visible
        onActivated: {
            gameOverWindow.visible = false
            gameOverWindow.root.initGame()
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: gameOverWindow.visible
        onActivated: gameOverWindow.visible = false
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
        id: popupLayout
        anchors.fill: parent
        columns: 2
        rowSpacing: 15
        Label {
            id: gameOverLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: gameOverWindow.gameOverLabelText
            color: gameOverWindow.gameOverLabelColor
            Layout.columnSpan: 2
            font.family: gameOverWindow.numberFont.name
            font.pixelSize: 16
        }

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: gameOverWindow.notificationText
            visible: gameOverWindow.notificationVisible
            font.pixelSize: 13
            font.bold: true
            Layout.columnSpan: 2
            color: "#28d13c"
        }

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("New record saved")
            visible: gameOverWindow.newRecordVisible
            Layout.columnSpan: 2
            font.pixelSize: 13
        }

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: gameOverWindow.settings.displaySeedAtGameOver
            text: qsTr("First click: X: %1, Y: %2, seed: %3").arg(gameOverWindow.clickX).arg(gameOverWindow.clickY).arg(gameOverWindow.seed)
            color: "#f7c220"
            Layout.columnSpan: 2
        }

        Button {
            id: retryButton
            text: qsTr("Retry")
            Layout.fillWidth: true
            Layout.preferredWidth: gameOverWindow.buttonWidth
            onClicked: {
                gameOverWindow.visible = false
                gameOverWindow.notificationVisible = false
                gameOverWindow.root.initGame()
            }
        }

        Button {
            id: closeButton
            text: qsTr("Close")
            Layout.fillWidth: true
            Layout.preferredWidth: gameOverWindow.buttonWidth
            onClicked: {
                gameOverWindow.visible = false
                gameOverWindow.notificationVisible = false
            }
        }
    }
}
