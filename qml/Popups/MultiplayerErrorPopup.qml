import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.multiplayerErrorPopupVisible
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        Label {
            text: qsTr("Error joining multiplayer session")
            font.pixelSize: 14
            font.bold: true
            Layout.alignment: Qt.AlignCenter
            color: "#d12844"
        }

        Label {
            text: qsTr("Reason: ") + ComponentsContext.mpErrorReason
            Layout.alignment: Qt.AlignCenter
        }

        Button {
            text: qsTr("Close")
            onClicked: ComponentsContext.multiplayerErrorPopupVisible = false
            Layout.alignment: Qt.AlignCenter
        }
    }
}
