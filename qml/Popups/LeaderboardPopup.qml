pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

AnimatedPopup {
    id: control
    closePolicy: Popup.NoAutoClose
    visible: ComponentsContext.leaderboardPopupVisible
    modal: true
    property bool confirmErase: false
    property string easyTime: ""
    property string mediumTime: ""
    property string hardTime: ""
    property string retr0Time: ""
    property int easyWins: 0
    property int mediumWins: 0
    property int hardWins: 0
    property int retr0Wins: 0
    property int buttonWidth: Math.min(closeButton.width, clearButton.width)

    onVisibleChanged: {
        if (!visible) {
            control.confirmErase = false
        }
    }

    Connections {
        target: GridBridge
        function onLeaderboardUpdated(timeField, timeValue, winsField, winsValue) {
            if (timeField === "easyTime") {
                control.easyTime = timeValue
                control.easyWins = winsValue
            } else if (timeField === "mediumTime") {
                control.mediumTime = timeValue
                control.mediumWins = winsValue
            } else if (timeField === "hardTime") {
                control.hardTime = timeValue
                control.hardWins = winsValue
            } else if (timeField === "retr0Time") {
                control.retr0Time = timeValue
                control.retr0Wins = winsValue
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: closeButton.click()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        RowLayout {
            spacing: 10
            visible: SteamIntegration.initialized
            Layout.alignment: Qt.AlignCenter

            Image {
                source: {
                    if (SteamIntegration.initialized) {
                        var avatarHandle = SteamIntegration.getAvatarHandleForPlayerName(SteamIntegration.playerName)
                        return avatarHandle > 0 ? SteamIntegration.getAvatarImageForHandle(avatarHandle) : "qrc:/icons/steam.png"
                    } else {
                        return ""
                    }
                }
                mipmap: true
                sourceSize.height: 24
                sourceSize.width: 24
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                Layout.alignment: Qt.AlignCenter
                fillMode: Image.PreserveAspectFit
                Rectangle {
                    width: 26
                    height: 26
                    anchors.centerIn: parent
                    color: "transparent"
                    opacity: 0.5
                    border.color: Constants.foregroundColor
                    border.width: Constants.isDarkMode ? 1 : 2
                }
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

        Item {
            Layout.preferredWidth: 350
            Layout.fillWidth: true
            Layout.preferredHeight: frame.implicitHeight

            Rectangle {
                anchors.fill: parent
                color: Constants.settingsPaneColor
            }

            Frame {
                anchors.fill: parent
                id: frame

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
        }
        RowLayout {
            spacing: 10
            NfButton {
                id: clearButton
                text: control.confirmErase ? qsTr("Confirm?") : qsTr("Clear")
                Layout.fillWidth: true
                Layout.preferredWidth: control.buttonWidth
                Layout.bottomMargin: 15
                onClicked: {
                    if (!control.confirmErase) {
                        control.confirmErase = true
                        return
                    }

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
                    control.confirmErase = false
                }
            }

            NfButton {
                id: closeButton
                text: qsTr("Close")
                Layout.fillWidth: true
                Layout.preferredWidth: control.buttonWidth
                Layout.bottomMargin: 15
                onClicked: ComponentsContext.leaderboardPopupVisible = false
            }
        }
    }
}
