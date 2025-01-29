import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: loadWindow
    width: 300
    height: 320
    modal: true
    anchors.centerIn: parent

    Shortcut {
        sequence: "Esc"
        enabled: loadWindow.visible
        onActivated: {
            loadWindow.visible = false
        }
    }

    Shortcut {
        sequence: "Up"
        enabled: loadWindow.visible
        onActivated: {
            saveFilesList.currentIndex = Math.max(0, saveFilesList.currentIndex - 1)
        }
    }

    Shortcut {
        sequence: "Down"
        enabled: loadWindow.visible
        onActivated: {
            saveFilesList.currentIndex = Math.min(saveFilesList.model.count - 1, saveFilesList.currentIndex + 1)
        }
    }

    Shortcut {
        sequence: "Return"
        enabled: loadWindow.visible
        onActivated: {
            if (saveFilesList.currentIndex >= 0 &&
                saveFilesList.currentIndex < saveFilesList.model.count &&
                saveFilesList.model.count > 0) {

                let saveFileName = saveFilesList.model.get(saveFilesList.currentIndex).name

                let saveData = mainWindow.loadGameState(saveFileName)
                if (saveData) {
                    if (!loadGame(saveData)) {
                        errorWindow.visible = true
                    }
                    loadWindow.visible = false
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 10

        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: saveFilesList.model.count === 0
            text: qsTr("No saved games found")
            font.pointSize: 12
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: saveFilesList.model.count > 0
            ScrollBar.vertical.policy: saveFilesList.model.count > 5 ?
                                           ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

            ListView {
                id: saveFilesList
                model: ListModel {}
                focus: true
                clip: true
                highlightMoveDuration: 0
                currentIndex: 0
                delegate: ItemDelegate {
                    width: saveFilesList.width
                    height: 40
                    required property string name
                    required property int index
                    highlighted: saveFilesList.currentIndex === index
                    onClicked: {
                        saveFilesList.currentIndex = index
                        let saveData = mainWindow.loadGameState(name)
                        if (saveData) {
                            if (!loadGame(saveData)) {
                                errorWindow.visible = true
                            }
                            loadWindow.visible = false
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        anchors.leftMargin: 15
                        anchors.rightMargin: 5

                        Label {
                            Layout.fillWidth: true
                            text: name.replace(".json", "")
                            elide: Text.ElideRight
                        }

                        Button {
                            id: deleteButton
                            icon.source: "qrc:/icons/delete.png"
                            icon.color: root.darkMode ? "white" : "black"
                            icon.width: 26
                            icon.height: 26
                            Layout.preferredWidth: height
                            flat: true
                            onClicked: {
                                mainWindow.deleteSaveFile(name)
                                saveFilesList.model.remove(index)
                            }
                        }
                    }
                }
            }
        }

        Button {
            text: qsTr("Cancel")
            Layout.fillWidth: true
            onClicked: loadWindow.visible = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            saveFilesList.model.clear()
            let saves = mainWindow.getSaveFiles()

            if (saves.length === 0) {
                //saveFilesList.model.append({name: qsTr("No saved games found"), enabled: false})
            } else {
                saves.forEach(function(save) {
                    saveFilesList.model.append({name: save, enabled: true})
                })
            }
        }
    }
}
