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
                text: qsTr("Sound effects")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: soundEffectSwitch.click()
                }
            }
            NfSwitch {
                id: soundEffectSwitch
                checked: GameSettings.soundEffects
                onCheckedChanged: {
                    GameSettings.soundEffects = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Notification for new messages")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: mpAudioNotificationOnNewMessageSwitch.click()
                }
            }
            NfSwitch {
                id: mpAudioNotificationOnNewMessageSwitch
                checked: GameSettings.mpAudioNotificationOnNewMessage
                onCheckedChanged: {
                    GameSettings.mpAudioNotificationOnNewMessage = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Volume")
                Layout.fillWidth: true
            }
            NfSlider {
                id: soundVolumeSlider
                from: 0
                to: 1
                value: GameSettings.volume
                onValueChanged: {
                    GameSettings.volume = value
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: SteamIntegration.initialized
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Volume (remote player)")
                Layout.fillWidth: true
            }
            NfSlider {
                id: remoteSoundVolumeSlider
                from: 0
                to: 1
                value: GameSettings.remoteVolume
                onValueChanged: {
                    GameSettings.remoteVolume = value
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Soundpack")
                Layout.fillWidth: true
            }
            NfComboBox {
                id: soundpackComboBox
                Layout.rightMargin: 5
                model: ["Pop", "Windows", "KDE", "Floraphonic"]
                currentIndex: GameSettings.soundPackIndex
                onActivated: {
                    GameSettings.soundPackIndex = currentIndex
                }
            }
        }
    }
}
