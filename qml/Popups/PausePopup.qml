import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine
import QtQuick

AnimatedPopup {
    id: control
    modal: true
    width: Math.max(pauseLabel.implicitWidth, resumeButton.implicitWidth) + 60
    height: lyt.implicitHeight + 40
    closePolicy: Popup.NoAutoClose
    visible: GameState.paused

    ColumnLayout {
        id: lyt
        anchors.fill: parent
        spacing: 15
        anchors.margins: 10
        Label {
            id: pauseLabel
            text: qsTr("Paused")
            Layout.alignment: Qt.AlignCenter
            font.bold: true
        }

        NfButton {
            id: resumeButton
            text: qsTr("Resume")
            onClicked: GameState.paused = false
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            highlighted: true
        }
    }
}
