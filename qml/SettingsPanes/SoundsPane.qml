import QtQuick.Controls.Universal
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
            }
            NfSlider {
                id: soundVolumeSlider
                from: 0
                to: 1
                value: GameSettings.volume
                onValueChanged: GameSettings.volume = value
                onPressedChanged: {
                    if (!pressed) {
                        GridBridge.audioEngine.playClick()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: SteamIntegration.initialized
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Sound effects (remote player)")
                Layout.fillWidth: true
            }
            NfSlider {
                id: remoteSoundVolumeSlider
                from: 0
                to: 1
                value: GameSettings.remoteVolume
                onValueChanged: GameSettings.remoteVolume = value
                onPressedChanged: {
                    if (!pressed) {
                        GridBridge.audioEngine.playRemoteClick()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Message received")
                Layout.fillWidth: true
            }
            NfSlider {
                id: newChatMessageVolumeeSlider
                from: 0
                to: 1
                value: GameSettings.newChatMessageVolume
                onValueChanged: GameSettings.newChatMessageVolume = value
                onPressedChanged: {
                    if (!pressed) {
                        GridBridge.audioEngine.playMessage()
                    }
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
