import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: saveWindow
    width: 300
    height: 140
    modal: true
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose

    Shortcut {
        sequence: "Esc"
        enabled: saveWindow.visible
        onActivated: {
            saveWindow.visible = false
        }
    }

    Shortcut {
        sequence: "Return"
        enabled: saveWindow.visible
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
                let hasInvalidChars = /[\\/:*?"<>|]/.test(text)
                let isReserved = /^(internalGameState|leaderboard)$/i.test(text.trim())

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

            Button {
                id: cancelButton
                text: qsTr("Cancel")
                Layout.fillWidth: true
                onClicked: saveWindow.visible = false
            }

            Button {
                id: saveButton
                text: qsTr("Save")
                Layout.fillWidth: true
                enabled: false
                onClicked: {
                    if (saveNameField.text.trim()) {
                        root.saveGame(saveNameField.text.trim() + ".json")
                        saveWindow.visible = false
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

