import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: loadWindow
    title: qsTr("Load Game")
    width: 300
    height: 320
    minimumWidth: 300
    minimumHeight: 320
    maximumWidth: 300
    maximumHeight: 320
    flags: Qt.Dialog

    Shortcut {
        sequence: "Esc"
        enabled: loadWindow.visible
        onActivated: {
            loadWindow.close()
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
                    loadWindow.close()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollBar.vertical.policy: saveFilesList.model.count > 5 ?
                                           ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

            ListView {
                id: saveFilesList
                model: ListModel {}
                focus: true  // Ensure the ListView can receive focus
                clip: true
                highlightMoveDuration: 0
                currentIndex: 0  // Set initial selection

                delegate: ItemDelegate {
                    width: saveFilesList.width
                    height: 40

                    required property string name
                    required property int index

                    text: name.replace(".json", "")

                    highlighted: saveFilesList.currentIndex === index

                    onClicked: {
                        saveFilesList.currentIndex = index
                        let saveData = mainWindow.loadGameState(name)
                        if (saveData) {
                            if (!loadGame(saveData)) {
                                errorWindow.visible = true
                            }
                            loadWindow.close()
                        }
                    }
                }
            }
        }

        Button {
            text: qsTr("Open save folder")
            Layout.fillWidth: true
            onClicked: {
                mainWindow.openSaveFolder()
                loadWindow.close()
            }
        }

        Button {
            text: qsTr("Cancel")
            Layout.fillWidth: true
            onClicked: loadWindow.close()
        }
    }

    onVisibleChanged: {
        if (visible) {
            saveFilesList.model.clear()
            let saves = mainWindow.getSaveFiles()

            if (saves.length === 0) {
                saveFilesList.model.append({name: qsTr("No saved games found"), enabled: false})
            } else {
                saves.forEach(function(save) {
                    saveFilesList.model.append({name: save, enabled: true})
                })
            }
        }
    }
}
