import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: control
    modal: true
    closePolicy: Popup.NoAutoClose
    height: implicitHeight + 20
    width: height
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        BusyIndicator {
            Layout.preferredHeight: 48
            Layout.preferredWidth: 48
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Generating..."
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
