import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Pane {
    ColumnLayout {
        spacing: GameConstants.settingsColumnSpacing
        width: parent.width

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Color correction")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: colorComboBox
                model: [qsTr("None"),
                    qsTr("Deuteranopia"),
                    qsTr("Protanopia"),
                    qsTr("Tritanopia")
                ]
                Layout.rightMargin: 5
                currentIndex: GameSettings.colorBlindness
                onActivated: {
                    GameSettings.colorBlindness = currentIndex
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("High contrast flags")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: highContrastFlagSwitch.click()
                }
            }
            NfSwitch {
                id: highContrastFlagSwitch
                checked: GameSettings.contrastFlag
                onCheckedChanged: GameSettings.contrastFlag = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Grid scale")
                Layout.fillWidth: true
            }
            NfSlider {
                id: gridScaleSlider
                from: 1
                to: 2
                value: GameSettings.gridScale
                onValueChanged: GameSettings.gridScale = value
            }
        }
    }
}
