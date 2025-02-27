pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    required property var grid
    readonly property int baseWidth: 600
    readonly property int baseHeight: 480
    required property int rootWidth
    required property int rootHeight
    required property int rootX
    required property int rootY

    width: GameCore.gamescope ? 1280 : baseWidth
    height: GameCore.gamescope ? 800 : baseHeight
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    visible: false
    flags: Qt.Dialog
    onVisibleChanged: {
        if (control.visible) {
            if (control.rootX + control.rootWidth + control.width + 10 <= Screen.width) {
                control.x = control.rootX + control.rootWidth + 20
            } else if (control.rootX - control.width - 10 >= 0) {
                control.x = control.rootX - control.width - 20
            } else {
                control.x = Screen.width - control.width - 20
            }
            control.y = control.rootY + (control.rootHeight - control.height) / 2
        }
    }

    BusyIndicator {
        // stupid, but allow continuous engine update
        // without too much hassle (needed for steam overlay)
        opacity: 0
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: {
            control.close()
        }
    }

    RestorePopup {
        id: restoreDefaultsPopup
    }

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
                                    case 7: stackView.push(advancedPaneComponent); break;
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
                    onClicked: {
                        restoreDefaultsPopup.open()
                    }
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
                    control: control
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: gameplayPaneComponent
                GameplayPane {
                    control: control
                    enabled: !GameState.isGeneratingGrid
                }
            }

            Component {
                id: visualsPaneComponent
                VisualsPane {
                    control: control
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
                id: advancedPaneComponent
                AdvancedPane {
                    enabled: !GameState.isGeneratingGrid
                }
            }
        }
    }
}
