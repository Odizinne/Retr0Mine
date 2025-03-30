import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ColumnLayout {
        spacing: Constants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("Sound effects")
                Layout.fillWidth: true
            }
            NfSlider {
                id: soundVolumeSlider
                from: 0
                to: 1
                value: UserSettings.volume
                onValueChanged: UserSettings.volume = value
                onPressedChanged: {
                    if (!pressed) {
                        AudioEngine.playClick()
                    }
                }
            }
        }

        RowLayout {
            enabled: SteamIntegration.initialized
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("Sound effects (remote player)")
                Layout.fillWidth: true
            }
            NfSlider {
                id: remoteSoundVolumeSlider
                from: 0
                to: 1
                value: UserSettings.remoteVolume
                onValueChanged: UserSettings.remoteVolume = value
                onPressedChanged: {
                    if (!pressed) {
                        AudioEngine.playRemoteClick()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("Message received")
                Layout.fillWidth: true
            }
            NfSlider {
                id: newChatMessageVolumeeSlider
                from: 0
                to: 1
                value: UserSettings.newChatMessageVolume
                onValueChanged: UserSettings.newChatMessageVolume = value
                onPressedChanged: {
                    if (!pressed) {
                        AudioEngine.playMessage()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("Soundpack")
                Layout.fillWidth: true
            }
            NfComboBox {
                id: soundpackComboBox
                Layout.rightMargin: 5
                model: ["Pop", "Windows", "KDE", "Floraphonic"]
                currentIndex: UserSettings.soundPackIndex
                onActivated: {
                    UserSettings.soundPackIndex = currentIndex
                }
            }
        }
    }
}
