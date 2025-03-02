import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    id: control
    modal: true
    width: Math.max(pauseLabel.width, resumeButton.width) + 40
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    visible: GameState.paused

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        Label {
            id: pauseLabel
            text: qsTr("Paused")
            Layout.alignment: Qt.AlignCenter
        }

        Button {
            id: resumeButton
            text: qsTr("Resume")
            onClicked: GameState.paused = false
            Layout.alignment: Qt.AlignCenter
        }
    }
}
