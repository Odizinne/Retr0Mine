pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    readonly property int baseWidth: 600
    readonly property int baseHeight: 480

    width: GameCore.gamescope ? 1280 : baseWidth
    height: GameCore.gamescope ? 800 : baseHeight
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    visible: ComponentsContext.settingsWindowVisible
    flags: Qt.Dialog
    onClosing: ComponentsContext.settingsWindowVisible = false

    MouseArea {
        // Normalize cursor shape in gamescope
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        propagateComposedEvents: true
        visible: GameCore.gamescope
        z: -1
        onPressed: function(mouse) { mouse.accepted = false; }
        onReleased: function(mouse) { mouse.accepted = false; }
        onClicked: function(mouse) { mouse.accepted = false; }
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: {
            // close is needed for proper DWM next opening animation
            control.close()
            ComponentsContext.settingsWindowVisible = false
        }
    }

    RestorePopup { }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Pane {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            padding: 0
            z: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 10

                ListView {
                    id: sidebarList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 10
                    interactive: false
                    model: [
                        {
                            text: qsTr("Difficulty"),
                            icon: "qrc:/icons/difficulty.png",
                        },
                        {
                            text: qsTr("Gameplay"),
                            icon: "qrc:/icons/controls.png",
                        },
                        {
                            text: qsTr("Visuals"),
                            icon: "qrc:/icons/visuals.png",
                        },
                        {
                            text: qsTr("Sound"),
                            icon: "qrc:/icons/audio.png",
                        },
                        {
                            text: qsTr("Shortcuts"),
                            icon: "qrc:/icons/keyboard.png",
                        },
                        {
                            text: qsTr("Accessibility"),
                            icon: "qrc:/icons/accessibility.png",
                        },
                        {
                            text: qsTr("Language"),
                            icon: "qrc:/icons/language.png",
                        },
                        {
                            text: qsTr("Multiplayer"),
                            icon: "qrc:/icons/multiplayer.png",
                        },
                        {
                            text: qsTr("Advanced"),
                            icon: "qrc:/icons/debug.png",
                        }
                    ]
                    currentIndex: 0
                    delegate: ItemDelegate {
                        width: parent.width
                        height: 40
                        required property var modelData
                        required property int index
                        icon.source: modelData.icon
                        icon.color: GameConstants.foregroundColor
                        text: GameCore.isFluent ? "  " + modelData.text : modelData.text
                        highlighted: ListView.isCurrentItem
                        onClicked: {
                            if (sidebarList.currentIndex !== index) {
                                sidebarList.currentIndex = index
                                switch(index) {
                                    case 0: stackView.push(difficultyPaneComponent); break;
                                    case 1: stackView.push(gameplayPaneComponent); break;
                                    case 2: stackView.push(visualsPaneComponent); break;
                                    case 3: stackView.push(soundPaneComponent); break;
                                    case 4: stackView.push(shortcutsPaneComponent); break;
                                    case 5: stackView.push(accessibilityPaneComponent); break;
                                    case 6: stackView.push(languagePaneComponent); break;
                                    case 7: stackView.push(multiplayerPaneComponent); break;
                                    case 8: stackView.push(advancedPaneComponent); break;
                                }
                            }
                        }
                    }
                }

                Button {
                    text: qsTr("Close")
                    visible: GameCore.gamescope || false
                    onClicked: control.close()
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 30
                }

                Button {
                    id: resetDefaultSettingsButton
                    Layout.fillWidth: true
                    Layout.bottomMargin: 15
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 30
                    text: qsTr("Restore defaults")
                    highlighted: true
                    onClicked: ComponentsContext.restorePopupVisible = true
                }
            }
        }

        ToolSeparator {
            Layout.fillHeight: true
            Layout.leftMargin: {
                if (GameCore.isUniversal) return -15
                else return -10
            }

            z: 2
        }

        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: difficultyPaneComponent

            Component {
                id: difficultyPaneComponent
                DifficultyPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: gameplayPaneComponent
                GameplayPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: visualsPaneComponent
                VisualsPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: soundPaneComponent
                SoundsPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: shortcutsPaneComponent
                ShortcutsPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: accessibilityPaneComponent
                AccessibilityPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: languagePaneComponent
                LanguagePane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: multiplayerPaneComponent
                MultiplayerPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: advancedPaneComponent
                AdvancedPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }
        }
    }
}
