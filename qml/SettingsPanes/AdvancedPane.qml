import QtQuick
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
                text: qsTr("Color scheme")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: colorSchemeComboBox
                model: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                Layout.rightMargin: 5
                currentIndex: GameSettings.colorSchemeIndex
                onActivated: {
                    if (GameSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(GameSettings.accentColorIndex)
                    }
                    GameSettings.colorSchemeIndex = currentIndex
                    GameCore.setThemeColorScheme(currentIndex)
                    if (GameSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(GameSettings.accentColorIndex)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            Label {
                text: qsTr("Accent color")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: accentColorComboBox
                model: Qt.platform.os === "linux" ?
                           [qsTr("Blue"), qsTr("Orange"), qsTr("Red"), qsTr("Green"), qsTr("Purple")] :
                           [qsTr("System"), qsTr("Blue"), qsTr("Orange"), qsTr("Red"), qsTr("Green"), qsTr("Purple")]
                Layout.rightMargin: 5
                currentIndex: {
                    if (Qt.platform.os === "linux") {
                        return GameSettings.accentColorIndex - 1;
                    } else {
                        return GameSettings.accentColorIndex;
                    }
                }
                onActivated: {
                    if (Qt.platform.os === "linux") {
                        GameSettings.accentColorIndex = currentIndex + 1;
                    } else {
                        GameSettings.accentColorIndex = currentIndex;
                    }
                    GameCore.setApplicationPalette(GameSettings.accentColorIndex)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Rendering backend")
                Layout.fillWidth: true
            }

            InfoIcon {
                tooltipText: qsTr("You probably have next to no reason to change this\nApplication will restart on change\nCurrent game will be saved and restored")
                Layout.rightMargin: 5
            }

            NfComboBox {
                id: renderingBackendComboBox
                model: Qt.platform.os === "linux" ?
                           ["OpenGL", "Vulkan"] :
                           ["OpenGL", "DirectX11", "DirectX12"]
                Layout.rightMargin: 5
                currentIndex: GameSettings.renderingBackend
                onActivated: {
                    GameSettings.renderingBackend  = currentIndex;
                    GameCore.restartRetr0Mine()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            enabled: !GameCore.gamescope
            Label {
                text: qsTr("Enable custom cursor")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: customCursorSwitch.click()
                }
            }

            NfSwitch {
                id: customCursorSwitch
                checked: GameSettings.customCursor
                onCheckedChanged: {
                    GameSettings.customCursor = checked
                    GameCore.setCursor(checked)
                }
            }
        }

        RowLayout {
            enabled: Qt.platform.os === "windows"
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight

            Label {
                text: qsTr("Enable custom titlebar")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: customTitlebarSwitch.click()
                }
            }

            InfoIcon {
                tooltipText: qsTr("Disable to use native windows titlebar color\nApplication will restart on change\nCurrent game will be saved and restored")
                Layout.rightMargin: 5
            }

            NfSwitch {
                id: customTitlebarSwitch
                checked: GameSettings.customTitlebar
                onCheckedChanged: {
                    GameSettings.customTitlebar = checked
                    if (checked) {
                        if (GameConstants.isDarkMode) {
                            GameCore.setTitlebarColor(0)
                        } else {
                            GameCore.setTitlebarColor(1)
                        }
                    } else {
                        if (GameState.gameStarted && !GameState.gameOver) {
                            SaveManager.saveGame("internalGameState.json")
                        }
                        GameState.bypassAutoSave = true
                        GameCore.restartRetr0Mine()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            enabled: false
            Label {
                text: qsTr("Qt version")
                Layout.fillWidth: true
            }

            Label {
                text: GameCore.qtVersion
                Layout.rightMargin: 5
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: GameConstants.settingsComponentsHeight
            enabled: false
            Label {
                text: qsTr("QT_QPA_PLATFORM")
                Layout.fillWidth: true
            }

            Label {
                text: GameCore.platformPlugin
                Layout.rightMargin: 5
            }
        }
    }
}
