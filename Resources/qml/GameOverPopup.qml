import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    anchors.centerIn: parent
    id: gameOverWindow
    visible: false
    modal: true
    closePolicy: Popup.NoAutoClose

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
            root.initGame()
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
            font.bold: true
            font.pixelSize: 16
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
            visible: settings.displaySeedAtGameOver
            text: qsTr("First click: X: %1, Y: %2, seed: %3").arg(gameOverWindow.clickX).arg(gameOverWindow.clickY).arg(gameOverWindow.seed)
            color: "#f7c220"
            Layout.columnSpan: 2
        }

        Button {
            text: qsTr("Retry")
            id: popupRetryButton
            implicitWidth: Math.max(popupRetryButton.width, popupCloseButton.width)
            Layout.fillWidth: true
            onClicked: {
                gameOverWindow.visible = false
                root.initGame()
            }
        }

        Button {
            text: qsTr("Close")
            id: popupCloseButton
            implicitWidth: Math.max(popupRetryButton.width, popupCloseButton.width)
            Layout.fillWidth: true
            onClicked: {
                gameOverWindow.visible = false
            }
        }
    }
}
