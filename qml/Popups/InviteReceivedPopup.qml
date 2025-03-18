import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine

Popup {
    id: invitePopup
    width: contentColumn.width + 30
    height: contentColumn.height + 30
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    property string friendName: ""
    property string connectData: ""
    property real timeRemaining: 10000

    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 8

        ProgressBar {
            Layout.fillWidth: true
            id: inviteExpireBar
            from: 0
            to: 1
            value: invitePopup.timeRemaining / 10000
        }

        RowLayout {
            spacing: 8
            Label {
                text: "<b>" + invitePopup.friendName + "</b>" + qsTr(" wants to play!")
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.rightMargin: 5
                textFormat: Text.RichText
            }

            NfButton {
                Layout.preferredWidth: 35
                Layout.preferredHeight: 35
                onClicked: {
                    if (SteamIntegration.isInMultiplayerGame) {
                        SteamIntegration.leaveLobby()
                    }
                    NetworkManager.sessionRunning = false
                    SteamIntegration.acceptInvite(invitePopup.connectData)
                    invitePopup.visible = false
                }
                IconImage {
                    source: "qrc:/icons/accept.png"
                    anchors.centerIn: parent
                    sourceSize.width: 20
                    sourceSize.height: 20
                    mipmap: true
                }
            }

            NfButton {
                Layout.preferredWidth: 35
                Layout.preferredHeight: 35
                onClicked: invitePopup.visible = false
                IconImage {
                    source: "qrc:/icons/deny.png"
                    anchors.centerIn: parent
                    sourceSize.width: 20
                    sourceSize.height: 20
                    mipmap: true
                }
            }
        }
    }

    function showInvite(name, data) {
        friendName = name
        connectData = data
        timeRemaining = 10000
        inviteTimer.restart()
        updateTimer.restart()
        open()
    }

    Timer {
        id: inviteTimer
        interval: 10000
        running: invitePopup.visible
        onTriggered: invitePopup.visible = false
    }

    Timer {
        id: updateTimer
        interval: 16
        repeat: true
        running: invitePopup.visible
        onTriggered: {
            invitePopup.timeRemaining = Math.max(0, invitePopup.timeRemaining - interval)
            if (invitePopup.timeRemaining <= 0) {
                stop()
            }
        }
    }
}
