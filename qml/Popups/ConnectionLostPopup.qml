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
            text: qsTr("Connection with ") + control.playerName + qsTr(" lost")
            Layout.alignment: Qt.AlignCenter
            color: "#d12844"
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
