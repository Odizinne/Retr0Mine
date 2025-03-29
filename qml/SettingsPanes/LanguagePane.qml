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
                text: qsTr("Language")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: languageComboBox
                model: [qsTr("System"),
                    "English",
                    "Français"
                ]
                property int previousLanguageIndex: currentIndex
                property int previousSettingsIndex: 0
                Layout.rightMargin: 5
                currentIndex: GameSettings.languageIndex
                onActivated: {
                    previousSettingsIndex = ComponentsContext.settingsIndex
                    ComponentsContext.settingsIndex = 0
                    previousLanguageIndex = currentIndex
                    GameSettings.languageIndex = currentIndex
                    GameCore.setLanguage(currentIndex)
                    currentIndex = previousLanguageIndex
                    ComponentsContext.settingsIndex = previousSettingsIndex
                }
            }
        }
    }
}
