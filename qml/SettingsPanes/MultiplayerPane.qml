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
            Layout.fillWidth: true

            Label {
                text: qsTr("Ping color")
                Layout.fillWidth: true
            }

            ComboBox {
                model: [
                    qsTr("Contrasted"),
                    qsTr("Orange"),
                    qsTr("Magenta"),
                    qsTr("Green"),
                    qsTr("Blue"),
                    qsTr("Purple"),
                    qsTr("Red"),
                    qsTr("Yellow"),
                    qsTr("Custom")
                    ]
                currentIndex: GameSettings.pingColorIndex
                onActivated: GameSettings.pingColorIndex = currentIndex
            }
        }

        RowLayout {
            enabled: GameSettings.pingColorIndex === 8
            Label {
                text: qsTr("Custom color")
                Layout.fillWidth: true
            }

            Label {
                text: "#"
            }

            TextField {
                maximumLength: 6
                Layout.preferredWidth: 80
                validator: RegularExpressionValidator { regularExpression: /[0-9A-Fa-f]{0,6}/ }
                inputMethodHints: Qt.ImhNoPredictiveText
                text: GameSettings.pingCustomColor
                onTextChanged: {
                    if (text.length === 6) {
                        GameSettings.pingCustomColor = text
                    }
                }
            }
        }
    }
}
