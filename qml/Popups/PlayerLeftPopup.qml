import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import net.odizinne.retr0mine

AnimatedPopup {
    id: control
    property string playerName: ""
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.playerLeftPopupVisible

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        Label {
            text: control.playerName + qsTr(" left the game")
            Layout.alignment: Qt.AlignCenter
            font.bold: true
        }

        NfButton {
            text: qsTr("Close")
            Layout.preferredWidth: implicitWidth + 20
            Layout.alignment: Qt.AlignCenter
            onClicked: {
                ComponentsContext.playerLeftPopupVisible = false
            }
        }
    }
}
