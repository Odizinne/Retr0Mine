import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

AnimatedPopup {
    id: control
    width: 300
    height: 140
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.savePopupVisible
    property int buttonWidth: Math.max(saveButton.implicitWidth, cancelButton.implicitWidth)

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: {
            ComponentsContext.savePopupVisible = false
        }
    }

    Shortcut {
        sequence: "Return"
        enabled: control.visible
        onActivated: {
            if (saveButton.enabled) {
                saveButton.click()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6

        TextField {
            id: saveNameField
            placeholderText: qsTr("Enter save file name")
            Layout.fillWidth: true
            onTextChanged: {
                let hasInvalidChars = text.match(/[\\/:*?"<>|]/) !== null
                let isReserved = text.trim().toLowerCase() === "internalgamestate" ||
                                 text.trim().toLowerCase() === "leaderboard"

                if (isReserved) {
                    errorLabel.text = qsTr("This filename is reserved for internal use")
                    saveButton.enabled = false
                } else {
                    errorLabel.text = hasInvalidChars ? qsTr("Filename cannot contain:") + " \\ / : * ? \" < > |" : ""
                    saveButton.enabled = text.trim() !== "" && !hasInvalidChars
                }
            }
        }
        Label {
            id: errorLabel
            color: "#f7c220"
            Layout.leftMargin: 3
            font.pointSize: 10
            Layout.fillWidth: true
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignRight
            spacing: 10

            NfButton {
                id: cancelButton
                text: qsTr("Cancel")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                onClicked: ComponentsContext.savePopupVisible = false
            }

            NfButton {
                id: saveButton
                text: qsTr("Save")
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                enabled: false
                onClicked: {
                    if (saveNameField.text.trim()) {
                        SaveManager.manualSave = true
                        SaveManager.saveGame(saveNameField.text.trim() + ".json")
                        ComponentsContext.savePopupVisible = false
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            saveNameField.text = ""
            saveNameField.forceActiveFocus()
        }
    }
}

