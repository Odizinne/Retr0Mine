import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

AnimatedPopup {
    anchors.centerIn: parent
    id: control
    visible: ComponentsContext.restorePopupVisible
    modal: true
    closePolicy: Popup.NoAutoClose
    property int buttonWidth: Math.max(restoreButton.implicitWidth, cancelButton.implicitWidth)

    ColumnLayout {
        id: restoreDefaultLayout
        anchors.fill: parent
        spacing: 15

        Label {
            id: restoreDefaultsLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            text: qsTr("Restore all settings to default?")
            Layout.columnSpan: 2
            font.bold: true
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            spacing: 10

            NfButton {
                id: restoreButton
                text: qsTr("Restore")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                onClicked: {
                    GameState.bypassAutoSave = true
                    GameCore.resetRetr0Mine()
                }
            }

            NfButton {
                id: cancelButton
                text: qsTr("Cancel")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                onClicked: ComponentsContext.restorePopupVisible = false
            }
        }
    }
}
