import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    anchors.centerIn: parent
    id: control
    required property var grid
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

    Shortcut {
        sequence: "Return"
        enabled: control.visible
        onActivated: {
            control.visible = false
            control.grid.initGame()
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: control.visible = false
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
            text: control.gameOverLabelText
            color: control.gameOverLabelColor
            Layout.columnSpan: 2
            font.family: GameConstants.numberFont.name
            font.pixelSize: 16
        }

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: control.notificationText
            visible: control.notificationVisible
            font.pixelSize: 13
            font.bold: true
            Layout.columnSpan: 2
            color: "#28d13c"
        }

        Label {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("New record saved")
            visible: control.newRecordVisible
            Layout.columnSpan: 2
            font.pixelSize: 13
        }

        Button {
            id: retryButton
            text: qsTr("Retry")
            Layout.fillWidth: true
            Layout.preferredWidth: control.buttonWidth
            onClicked: {
                control.visible = false
                control.notificationVisible = false
                control.grid.initGame()
            }
        }

        Button {
            id: closeButton
            text: qsTr("Close")
            Layout.fillWidth: true
            Layout.preferredWidth: control.buttonWidth
            onClicked: {
                control.visible = false
                control.notificationVisible = false
            }
        }
    }
}
