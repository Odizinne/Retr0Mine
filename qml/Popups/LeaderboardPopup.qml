pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
    id: control
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.leaderboardPopupVisible
    modal: true
    property string easyTime: ""
    property string mediumTime: ""
    property string hardTime: ""
    property string retr0Time: ""
    property int easyWins: 0
    property int mediumWins: 0
    property int hardWins: 0
    property int retr0Wins: 0

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: ComponentsContext.leaderboardPopupVisible = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        RowLayout {
            spacing: 10
            visible: SteamIntegration.initialized
            Layout.alignment: Qt.AlignCenter

            IconImage {
                source: "qrc:/icons/steam.png"
                color: GameConstants.foregroundColor
                sourceSize.height: 20
                sourceSize.width: 20
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignCenter
            }

            Label {
                id: baseLabel
                text: SteamIntegration.playerName
                font.bold: true
                font.pixelSize: 20
                Layout.preferredHeight: 30
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Frame {
            Layout.preferredWidth: 350
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: 15

                ColumnLayout {
                    Layout.preferredWidth: parent.width / 3
                    spacing: 15

                    Label {
                        text: qsTr("Difficulty")
                        font.bold: true
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    Label {
                        text: qsTr("Easy")
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    Label {
                        text: qsTr("Medium")
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    Label {
                        text: qsTr("Hard")
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    Label {
                        text: qsTr("Retr0")
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: parent.width / 3
                    spacing: 15

                    Label {
                        text: qsTr("Time")
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: control.easyTime
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: control.mediumTime
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: control.hardTime
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: control.retr0Time
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: parent.width / 3
                    spacing: 15

                    Label {
                        text: qsTr("Wins")
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    Label {
                        text: control.easyWins.toString()
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    Label {
                        text: control.mediumWins.toString()
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    Label {
                        text: control.hardWins.toString()
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    Label {
                        text: control.retr0Wins.toString()
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
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
                    control.easyTime = ""
                    control.mediumTime = ""
                    control.hardTime = ""
                    control.retr0Time = ""
                    control.easyWins = 0
                    control.mediumWins = 0
                    control.hardWins = 0
                    control.retr0Wins = 0

                    let emptyLeaderboard = {
                        easyTime: "",
                        mediumTime: "",
                        hardTime: "",
                        retr0Time: "",
                        easyWins: 0,
                        mediumWins: 0,
                        hardWins: 0,
                        retr0Wins: 0
                    }

                    GameCore.saveLeaderboard(JSON.stringify(emptyLeaderboard))
                }
            }

            Button {
                text: qsTr("Close")
                Layout.fillWidth: true
                onClicked: ComponentsContext.leaderboardPopupVisible = false
                Layout.bottomMargin: 15
            }
        }
    }
}
