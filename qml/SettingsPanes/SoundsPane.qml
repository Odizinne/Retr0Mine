import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Pane {
    ColumnLayout {
        spacing: 20
        width: parent.width

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: qsTr("Sound effects")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: soundEffectSwitch.click()
                }
            }
            Switch {
                id: soundEffectSwitch
                checked: GameSettings.soundEffects
                onCheckedChanged: {
                    GameSettings.soundEffects = checked
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Volume")
                Layout.fillWidth: true
            }
            Slider {
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
            Label {
                text: qsTr("Soundpack")
                Layout.fillWidth: true
            }
            ComboBox {
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
