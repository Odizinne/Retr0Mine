import QtQuick.Controls.Universal
import QtQuick.Layouts
import net.odizinne.retr0mine

AnimatedPopup {
    id: control
    modal: true
    width: Math.max(pauseLabel.width, resumeButton.width) + 40
    closePolicy: Popup.NoAutoClose
    visible: GameState.paused

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        Label {
            id: pauseLabel
            text: qsTr("Paused")
            Layout.alignment: Qt.AlignCenter
        }

        NfButton {
            id: resumeButton
            text: qsTr("Resume")
            onClicked: GameState.paused = false
            Layout.alignment: Qt.AlignCenter
        }
    }
}
