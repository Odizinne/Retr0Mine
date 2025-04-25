import QtQuick
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
                currentIndex: UserSettings.colorBlindness
                onActivated: {
                    UserSettings.colorBlindness = currentIndex
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.contrastFlag
                onCheckedChanged: UserSettings.contrastFlag = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("High contrast numbers")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: contrastedNumbersSwitch.click()
                }
            }
            NfSwitch {
                id: contrastedNumbersSwitch
                checked: UserSettings.contrastedNumbers
                onCheckedChanged: UserSettings.contrastedNumbers = checked
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            Label {
                text: qsTr("Grid scale")
                Layout.fillWidth: true
            }
            NfSlider {
                id: gridScaleSlider
                from: 1
                to: 2
                value: UserSettings.gridScale
                onValueChanged: UserSettings.gridScale = value
            }
        }
    }
}
