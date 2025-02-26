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
                text: qsTr("Language")
                Layout.fillWidth: true
            }

            ComboBox {
                id: languageComboBox
                model: [qsTr("System"),
                    "English",
                    "Français"
                ]
                property int previousLanguageIndex: currentIndex
                Layout.rightMargin: 5
                currentIndex: GameSettings.languageIndex
                onActivated: {
                    previousLanguageIndex = currentIndex
                    GameSettings.languageIndex = currentIndex
                    GameCore.setLanguage(currentIndex)
                    currentIndex = previousLanguageIndex
                }
            }
        }
    }
}
