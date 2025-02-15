pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

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
    property int easyWins: 0
    property int mediumWins: 0
    property int hardWins: 0
    property int retr0Wins: 0
    property bool isShining: root.shineUnlocked

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
        spacing: 15

        RowLayout {
            spacing: 10
            visible: leaderboardPage.root.isSteamEnabled
            Layout.alignment: Qt.AlignCenter

            IconImage {
                source: "qrc:/icons/steam.png"
                color: leaderboardPage.root.darkMode ? "white" : "Dark"
                sourceSize.height: 20
                sourceSize.width: 20
            }

            Label {
                id: baseLabel
                text: leaderboardPage.root.mainWindow.playerName
                font.bold: true
                font.pixelSize: 20
                layer.enabled: leaderboardPage.isShining
                layer.effect: LinearGradient {
                    id: shineEffect
                    property real offset: shineAnim.value
                    start: Qt.point(offset * (width * 1.5) - width, offset * (height * 1.5) - height)
                    end: Qt.point(offset * (width * 1.5), offset * (height * 1.5))
                    source: baseLabel
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: baseLabel.color }
                        GradientStop { position: 0.35; color: baseLabel.color }
                        GradientStop { position: 0.5; color: "#7fFFFFFF" }
                        GradientStop { position: 0.65; color: baseLabel.color }
                        GradientStop { position: 1.0; color: baseLabel.color }
                    }
                }

                PropertyAnimation {
                    id: shineAnim
                    property real value: 0
                    target: shineAnim
                    property: "value"
                    from: 0.0
                    to: 1.0
                    duration: 3000
                    loops: Animation.Infinite
                    running: true
                }
            }
        }

        Frame {
            Layout.preferredWidth: 300
            Layout.fillWidth: true
            GridLayout {
                anchors.fill: parent
                columns: 3
                columnSpacing: 15
                rowSpacing: 15

                Label {
                    text: qsTr("Difficulty")
                    font.bold: true
                    Layout.preferredWidth: parent.width / 3
                }
                Label {
                    text: qsTr("Time")
                    font.bold: true
                    Layout.preferredWidth: parent.width / 3
                }
                Label {
                    text: qsTr("Wins")
                    font.bold: true
                    Layout.preferredWidth: parent.width / 3
                }

                Label {
                    text: qsTr("Easy")
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.easyTime
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.easyWins.toString()
                    Layout.minimumWidth: parent.width / 3
                }

                Label {
                    text: qsTr("Medium")
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.mediumTime
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.mediumWins.toString()
                    Layout.minimumWidth: parent.width / 3
                }

                Label {
                    text: qsTr("Hard")
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.hardTime
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.hardWins.toString()
                    Layout.minimumWidth: parent.width / 3
                }

                Label {
                    text: qsTr("Retr0")
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.retr0Time
                    Layout.minimumWidth: parent.width / 3
                }
                Label {
                    text: leaderboardPage.retr0Wins.toString()
                    Layout.minimumWidth: parent.width / 3
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
                    leaderboardPage.easyWins = 0
                    leaderboardPage.mediumWins = 0
                    leaderboardPage.hardWins = 0
                    leaderboardPage.retr0Wins = 0

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

                    leaderboardPage.root.mainWindow.saveLeaderboard(JSON.stringify(emptyLeaderboard))
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
