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

    RowLayout {
        id: contentColumn
        anchors.centerIn: parent
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

        Button {
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            focusPolicy: Qt.NoFocus
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

        Button {
            Layout.preferredWidth: 35
            Layout.preferredHeight: 35
            focusPolicy: Qt.NoFocus
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

    function showInvite(name, data) {
        friendName = name
        connectData = data
        open()
    }

    Timer {
        interval: 10000
        running: invitePopup.visible
        onTriggered: invitePopup.visible = false
    }
}
