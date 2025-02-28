import QtQuick.Controls
import QtQuick.Layouts
import QtQuick 2.15

Popup {
    id: control
    modal: true
    closePolicy: Popup.NoAutoClose
    height: implicitHeight + 40
    width: stupidMessagesLabel.width + 40
    visible: false
    anchors.centerIn: parent

    property bool generating: GameState.isGeneratingGrid
    property var generationMessages: [
        qsTr("Generating board..."),
        qsTr("Placing mines in corners..."),
        qsTr("Checking if 1 + 1 = 2..."),
        qsTr("Counting digits very carefully..."),
        qsTr("Asking mines to play fair..."),
        qsTr("Calibrating mine detectors..."),
        qsTr("Convincing mines not to move..."),
        qsTr("Consulting probability experts..."),
        qsTr("Hiding mines under suspicious squares..."),
        qsTr("Calculation of multipliers based on colors"),
        qsTr("Running out of clever loading messages...")
    ]

    property string currentMessage: ""
    property string previousMessage: ""

    function getRandomMessage() {
        if (generationMessages.length <= 1) {
            return generationMessages[0];
        }

        var message;
        do {
            var randomIndex = Math.floor(Math.random() * generationMessages.length);
            message = generationMessages[randomIndex];
        } while (message === previousMessage);

        previousMessage = message;
        return message;
    }

    Timer {
        id: showDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (control.generating) {
                control.currentMessage = control.getRandomMessage();
                control.visible = true;
            }
        }
    }

    onGeneratingChanged: {
        if (generating) {
            showDelayTimer.restart();
        } else {
            showDelayTimer.stop();
            control.visible = false;
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        BusyIndicator {
            Layout.preferredHeight: 48
            Layout.preferredWidth: 48
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            id: stupidMessagesLabel
            text: control.currentMessage
            font.italic: true
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            text: qsTr("Cancel")
            onClicked: GridBridge.cancelGeneration()
        }
    }
}
