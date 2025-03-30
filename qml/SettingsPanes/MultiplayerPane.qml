import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    id: mpPane
    property var colorModel: [
        qsTr("Contrasted"),
        qsTr("Orange"),
        qsTr("Magenta"),
        qsTr("Green"),
        qsTr("Blue"),
        qsTr("Purple"),
        qsTr("Red"),
        qsTr("Yellow")
    ]

    ColumnLayout {
        spacing: Constants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            enabled: SteamIntegration.initialized
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Show notification on invite received")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: mpShowInviteNotificationInGameSwitch.click()
                }
            }
            NfSwitch {
                id: mpShowInviteNotificationInGameSwitch
                checked: UserSettings.mpShowInviteNotificationInGame
                onCheckedChanged: {
                    UserSettings.mpShowInviteNotificationInGame = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            enabled: SteamIntegration.initialized
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Player colored flags")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: mpPlayerColoredFlagsSwitch.click()
                }
            }
            NfSwitch {
                id: mpPlayerColoredFlagsSwitch
                checked: UserSettings.mpPlayerColoredFlags
                onCheckedChanged: {
                    UserSettings.mpPlayerColoredFlags = checked
                }
            }
        }

        RowLayout {
            enabled: UserSettings.mpPlayerColoredFlags && SteamIntegration.initialized
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Local player")
                Layout.fillWidth: true
            }

            NfComboBox {
                Layout.rightMargin: 5
                model: mpPane.colorModel
                currentIndex: UserSettings.localFlagColorIndex
                onActivated: UserSettings.localFlagColorIndex = currentIndex
            }
        }

        RowLayout {
            enabled: UserSettings.mpPlayerColoredFlags && SteamIntegration.initialized
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Remote player")
                Layout.fillWidth: true
            }

            NfComboBox {
                Layout.rightMargin: 5
                model: mpPane.colorModel
                currentIndex: UserSettings.remoteFlagColorIndex
                onActivated: UserSettings.remoteFlagColorIndex = currentIndex
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

            Label {
                text: qsTr("Ping color")
                Layout.fillWidth: true
            }

            NfComboBox {
                Layout.rightMargin: 5
                model: mpPane.colorModel
                currentIndex: UserSettings.pingColorIndex
                onActivated: UserSettings.pingColorIndex = currentIndex
            }
        }
    }
}
