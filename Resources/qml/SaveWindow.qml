import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: saveWindow
    title: qsTr("Save Game")
    width: 300
    height: 130
    minimumWidth: 300
    minimumHeight: 130
    maximumWidth: 300
    maximumHeight: 130
    flags: Qt.Dialog
    Shortcut {
        sequence: "Esc"
        onActivated: {
            saveWindow.close()
        }
    }

    Keys.onEscapePressed: saveWindow.close()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12

        TextField {
            id: saveNameField
            placeholderText: qsTr("Enter save file name")
            Layout.fillWidth: true
            onTextChanged: {
                let hasInvalidChars = /[\\/:*?"<>|]/.test(text)
                let isReserved = /^internalGameState$/i.test(text.trim())

                if (isReserved) {
                    errorLabel.text = qsTr("This filename is reserved for internal use")
                    saveButton.enabled = false
                } else {
                    errorLabel.text = hasInvalidChars ? qsTr("Filename cannot contain:") + " \\ / : * ? \" < > |" : ""
                    saveButton.enabled = text.trim() !== "" && !hasInvalidChars
                }
            }
            Keys.onReturnPressed: {
                if (saveButton.enabled) {
                    saveButton.clicked()
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
                Layout.preferredWidth: Math.max(cancelButton.implicitWidth, saveButton.implicitWidth)
                onClicked: saveWindow.close()
            }

            Button {
                id: saveButton
                text: qsTr("Save")
                Layout.preferredWidth: Math.max(cancelButton.implicitWidth, saveButton.implicitWidth)
                enabled: false
                onClicked: {
                    if (saveNameField.text.trim()) {
                        saveGame(saveNameField.text.trim() + ".json")
                        saveWindow.close()
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

