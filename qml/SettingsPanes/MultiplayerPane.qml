import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        spacing: GameConstants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Show notification on invite received")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: mpShowInviteNotificationInGameSwitch.click()
                }
            }
            Switch {
                id: mpShowInviteNotificationInGameSwitch
                checked: GameSettings.mpShowInviteNotificationInGame
                onCheckedChanged: {
                    GameSettings.mpShowInviteNotificationInGame = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Player colored flags")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: mpPlayerColoredFlagsSwitch.click()
                }
            }
            Switch {
                id: mpPlayerColoredFlagsSwitch
                checked: GameSettings.mpPlayerColoredFlags
                onCheckedChanged: {
                    GameSettings.mpPlayerColoredFlags = checked
                }
            }
        }

        RowLayout {
            enabled: GameSettings.mpPlayerColoredFlags
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Local player")
                Layout.fillWidth: true
            }

            ComboBox {
                Layout.rightMargin: 5
                model: [
                    qsTr("Contrasted"),
                    qsTr("Orange"),
                    qsTr("Magenta"),
                    qsTr("Green"),
                    qsTr("Blue"),
                    qsTr("Purple"),
                    qsTr("Red"),
                    qsTr("Yellow"),
                    ]
                currentIndex: GameSettings.localFlagColorIndex
                onActivated: GameSettings.localFlagColorIndex = currentIndex
            }
        }

        RowLayout {
            enabled: GameSettings.mpPlayerColoredFlags
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Remote player")
                Layout.fillWidth: true
            }

            ComboBox {
                Layout.rightMargin: 5
                model: [
                    qsTr("Contrasted"),
                    qsTr("Orange"),
                    qsTr("Magenta"),
                    qsTr("Green"),
                    qsTr("Blue"),
                    qsTr("Purple"),
                    qsTr("Red"),
                    qsTr("Yellow"),
                    ]
                currentIndex: GameSettings.remoteFlagColorIndex
                onActivated: GameSettings.remoteFlagColorIndex = currentIndex
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Ping color")
                Layout.fillWidth: true
            }

            ComboBox {
                Layout.rightMargin: 5
                model: [
                    qsTr("Contrasted"),
                    qsTr("Orange"),
                    qsTr("Magenta"),
                    qsTr("Green"),
                    qsTr("Blue"),
                    qsTr("Purple"),
                    qsTr("Red"),
                    qsTr("Yellow")
                    ]
                currentIndex: GameSettings.pingColorIndex
                onActivated: GameSettings.pingColorIndex = currentIndex
            }
        }
    }
}
