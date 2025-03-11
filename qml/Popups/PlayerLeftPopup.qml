import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control
    property string playerName: ""
    modal: true
    closePolicy: Popup.NoAutoClose

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        Label {
            text: control.playerName + qsTr(" left the game")
            Layout.alignment: Qt.AlignCenter
            font.bold: true
        }

        Button {
            text: qsTr("Close")
            Layout.preferredWidth: implicitWidth + 20
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                control.visible = false
            }
        }
    }
}
