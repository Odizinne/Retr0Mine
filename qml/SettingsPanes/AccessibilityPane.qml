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
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Layout.fillWidth: true
            Label {
                text: qsTr("Cell size")
                Layout.fillWidth: true
            }
            NfComboBox {
                id: cellSizeComboBox
                model: [qsTr("Small"), qsTr("Normal"), qsTr("Large")]
                Layout.rightMargin: 5
                currentIndex: {
                    switch(GameSettings.cellSize) {
                        case 0: return 0;
                        case 1: return 1;
                        case 2: return 2;
                        default: return 0;
                    }
                }

                onActivated: {
                    GameSettings.cellSize = currentIndex
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
                onCheckedChanged: {
                    GameSettings.contrastFlag = checked
                }
            }
        }
    }
}
