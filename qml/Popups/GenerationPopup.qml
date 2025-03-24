import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick 2.15
import net.odizinne.retr0mine 1.0

AnimatedPopup {
    id: control
    modal: true
    closePolicy: Popup.NoAutoClose
    height: implicitHeight + 20
    width: 300
    visible: false

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
        qsTr("Calculation of multipliers based on colors..."),
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
        id: mainLayout
        anchors.centerIn: parent
        spacing: 15

        Label {
            id: stupidMessagesLabel
            text: control.currentMessage
            Layout.preferredWidth: mineProgress.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        ProgressBar {
            id: mineProgress
            value: GameLogic.minesPlaced
            from: 0
            to: Math.max(1, GameLogic.totalMines)
            Layout.preferredWidth: 220
            Layout.alignment: Qt.AlignHCenter
        }

        NfButton {
            text: qsTr("Cancel")
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            onClicked: {
                if (!GameState.gameStarted) {
                    GridBridge.cancelGeneration()
                }
            }
        }
    }
}
