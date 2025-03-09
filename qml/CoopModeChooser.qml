import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine

Popup {
    anchors.centerIn: parent
    height: lyt.implicitHeight + 30
    width: lyt.implicitWidth + 30
    visible: ComponentsContext.coopModeChooserVisible
    ColumnLayout {
        anchors.fill: parent
        id: lyt
        spacing: 20

        Label {
            text: "Retr0Mine Coop"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignCenter
        }

        RowLayout {
            spacing: 15
            Button {
                text: qsTr("Private game")
                Layout.preferredWidth: implicitWidth + 20
                Layout.fillWidth: true
                onClicked: {
                    ComponentsContext.coopModeChooserVisible = false
                    ComponentsContext.multiplayerPopupVisible = true
                }
            }

            Button {
                text: qsTr("Matchmaking")
                Layout.preferredWidth: implicitWidth + 20
                Layout.fillWidth: true
                enabled: false
                onClicked: ComponentsContext.coopModeChooserVisible = false
            }
        }
    }
}
