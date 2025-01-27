import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: leaderboardPage
    anchors.centerIn: parent
    visible: false
    modal: true
    property string easyTime: ""
    property string mediumTime: ""
    property string hardTime: ""
    property string retr0Time: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Frame {
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

        Button {
            text: "Close"
            Layout.alignment: Qt.AlignHCenter
            onClicked: leaderboardPage.visible = false
            Layout.bottomMargin: 15
        }
    }
}
