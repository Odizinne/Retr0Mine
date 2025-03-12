import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: control
    title: qsTr("Error")
    width: 300
    height: 150
    minimumWidth: 300
    minimumHeight: 150
    flags: Qt.Dialog

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
            text: qsTr("Failed to load save file. The file might be corrupted or incompatible.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        NfButton {
            text: qsTr("OK")
            Layout.alignment: Qt.AlignRight
            onClicked: control.close()
        }
    }
}
