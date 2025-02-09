import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

Popup {
    id: leaderboardPage
    required property var root
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

        RowLayout {
            spacing: 10
            visible: typeof steamIntegration !== "undefined"
            Layout.alignment: Qt.AlignCenter
            Layout.preferredHeight: 40

            IconImage {
                source: "qrc:/icons/steam.png"
                color: leaderboardPage.root.darkMode ? "white" : "Dark"
                sourceSize.height: 20
                sourceSize.width: 20
                Layout.alignment: Qt.AlignCenter
            }

            Label {
                text: mainWindow.playerName
                font.bold: true
                font.pixelSize: 20
                Layout.alignment: Qt.AlignCenter
            }
        }

        Frame {
            Layout.preferredWidth: 300
            Layout.fillWidth: true

            ColumnLayout {
                spacing: 15
                anchors.fill: parent

                RowLayout {
                    Label {
                        text: qsTr("Easy")
                        Layout.fillWidth: true
                    }

                    Label {
                        text: leaderboardPage.easyTime
                        font.bold: true
                    }
                }

                RowLayout {
                    Label {
                        text: qsTr("Medium")
                        Layout.fillWidth: true
                    }

                    Label {
                        text: leaderboardPage.mediumTime
                        font.bold: true
                    }
                }

                RowLayout {
                    Label {
                        text: qsTr("Hard")
                        Layout.fillWidth: true
                    }

                    Label {
                        text: leaderboardPage.hardTime
                        font.bold: true
                    }
                }

                RowLayout {
                    Label {
                        text: qsTr("Retr0")
                        Layout.fillWidth: true
                    }

                    Label {
                        text: leaderboardPage.retr0Time
                        font.bold: true
                    }
                }
            }
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
