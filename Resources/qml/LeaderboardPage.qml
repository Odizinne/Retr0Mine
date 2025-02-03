import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: leaderboardPage
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    visible: false
    modal: true
    property string easyTime: ""
    property string mediumTime: ""
    property string hardTime: ""
    property string retr0Time: ""

    Shortcut {
        sequence: "Esc"
        enabled: leaderboardPage.visible
        onActivated: {
            leaderboardPage.visible = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Frame {
            Layout.preferredWidth: 300
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                Label {
                    text: qsTr("Easy")
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    text: leaderboardPage.easyTime
                    font.bold: true
                }
            }
        }
        Frame {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                Label {
                    text: qsTr("Medium")
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    text: leaderboardPage.mediumTime
                    font.bold: true
                }
            }
        }
        Frame {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                Label {
                    text: qsTr("Hard")
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    text: leaderboardPage.hardTime
                    font.bold: true
                }
            }
        }
        Frame {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                Label {
                    text: qsTr("Retr0")
                }
                Item {
                    Layout.fillWidth: true
                }
                Label {
                    text: leaderboardPage.retr0Time
                    font.bold: true
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            spacing: 10
            Button {
                text: qsTr("Clear")
                Layout.fillWidth: true
                Layout.bottomMargin: 15
                onClicked: {
                    leaderboardPage.easyTime = ""
                    leaderboardPage.mediumTime = ""
                    leaderboardPage.hardTime = ""
                    leaderboardPage.retr0Time = ""

                    let emptyLeaderboard = {
                        easyTime: "",
                        mediumTime: "",
                        hardTime: "",
                        retr0Time: ""
                    }

                    mainWindow.saveLeaderboard(JSON.stringify(emptyLeaderboard))
                }
            }

            Button {
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: leaderboardPage.visible = false
                Layout.bottomMargin: 15
            }
        }
    }
}
