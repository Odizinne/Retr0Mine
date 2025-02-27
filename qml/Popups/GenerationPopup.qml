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

    property bool generating: false
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

    Timer {
        id: showDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (control.generating) {
                control.currentMessage = control.generationMessages[Math.floor(Math.random() * control.generationMessages.length)]
                control.visible = true
            }
        }
    }

    onGeneratingChanged: {
        if (generating) {
            showDelayTimer.restart()
        } else {
            showDelayTimer.stop()
            control.visible = false
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        BusyIndicator {
            Layout.preferredHeight: 48
            Layout.preferredWidth: 48
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            id: stupidMessagesLabel
            text: control.currentMessage
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
