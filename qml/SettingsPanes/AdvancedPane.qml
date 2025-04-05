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
                text: qsTr("Color scheme")
                Layout.fillWidth: true
            }

            NfComboBox {
                id: colorSchemeComboBox
                model: [qsTr("System"), qsTr("Dark"), qsTr("Light")]
                Layout.rightMargin: 5
                currentIndex: UserSettings.colorSchemeIndex
                onActivated: {
                    if (UserSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(UserSettings.accentColorIndex)
                    }
                    UserSettings.colorSchemeIndex = currentIndex
                    GameCore.setThemeColorScheme(currentIndex)
                    if (UserSettings.accentColorIndex !== 0) {
                        GameCore.setApplicationPalette(UserSettings.accentColorIndex)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                        return UserSettings.accentColorIndex - 1;
                    } else {
                        return UserSettings.accentColorIndex;
                    }
                }
                onActivated: {
                    if (Qt.platform.os === "linux") {
                        UserSettings.accentColorIndex = currentIndex + 1;
                    } else {
                        UserSettings.accentColorIndex = currentIndex;
                    }
                    GameCore.setApplicationPalette(UserSettings.accentColorIndex)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

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
                currentIndex: UserSettings.renderingBackend
                onActivated: {
                    UserSettings.renderingBackend  = currentIndex;
                    GameCore.restartRetr0Mine()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
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
                checked: UserSettings.customCursor
                onCheckedChanged: {
                    UserSettings.customCursor = checked
                    GameCore.setCursor(checked)
                }
            }
        }

        RowLayout {
            enabled: Qt.platform.os === "windows"
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight

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
                checked: UserSettings.customTitlebar
                onCheckedChanged: {
                    UserSettings.customTitlebar = checked
                    if (checked) {
                        if (Constants.isDarkMode) {
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
            Layout.preferredHeight: Constants.settingsComponentsHeight
            opacity: 0.5
            Label {
                text: "QT_VERSION"
                Layout.fillWidth: true
            }

            Label {
                text: GameCore.qtVersion
                Layout.rightMargin: 8
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            opacity: 0.5
            Label {
                text: "QT_QPA_PLATFORM"
                Layout.fillWidth: true
            }

            Label {
                text: GameCore.platformPlugin
                Layout.rightMargin: 8
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Constants.settingsComponentsHeight
            opacity: 0.5

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Open log window")
                onClicked: ComponentsContext.logWindowVisible = true
                Layout.rightMargin: 5
            }
        }
    }
}
