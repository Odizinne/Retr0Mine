pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

AnimatedPopup {
    id: control
    width: 300
    height: 320
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.loadPopupVisible
    ErrorWindow {
        id: errorWindow
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: {
            ComponentsContext.loadPopupVisible = false
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
                    id: saveFile
                    width: saveFilesList.width - 10
                    height: 40
                    required property string name
                    required property int index
                    text: name.replace(".json", "")
                    onClicked: {
                        saveFilesList.currentIndex = index
                        let saveData = GameCore.loadGameState(name)
                        if (saveData) {
                            if (!SaveManager.loadGame(saveData)) {
                                errorWindow.visible = true
                            }
                            ComponentsContext.loadPopupVisible = false
                        }
                    }

                    IconImage {
                        id: deleteButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10
                        source: "qrc:/icons/delete.png"
                        color: GameConstants.foregroundColor
                        height: 16
                        width: 40
                        MouseArea {
                            height: 32
                            width: 32
                            anchors.centerIn: parent
                            onClicked: {
                                GameCore.deleteSaveFile(saveFile.name)
                                saveFilesList.model.remove(saveFile.index)
                            }
                        }
                    }
                }
            }
        }

        NfButton {
            text: qsTr("Cancel")
            Layout.fillWidth: true
            onClicked: ComponentsContext.loadPopupVisible = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            saveFilesList.model.clear()
            let saves = GameCore.getSaveFiles()

            if (saves.length > 0) {
                saves.forEach(function(save) {
                    saveFilesList.model.append({name: save, enabled: true})
                })
            }
        }
    }
}
