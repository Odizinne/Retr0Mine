pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    readonly property int baseWidth: 700
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
        /*==========================================
         | Normalize cursor shape in gamescope     |
         ==========================================*/
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
            /*==========================================
             | close is needed for proper DWM          |
             | next opening animation                  |
             ==========================================*/
            control.close()
            ComponentsContext.settingsWindowVisible = false
        }
    }

    RestorePopup {
        anchors.centerIn: parent
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            Rectangle {
                anchors.fill: parent
                color: GameConstants.settingsPaneColor
                visible: GameCore.isUniversal
            }

            ColumnLayout {
                anchors.fill: parent
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
                    currentIndex: ComponentsContext.settingsIndex
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
                                ComponentsContext.settingsIndex = index
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

                NfButton {
                    text: qsTr("Close")
                    visible: GameCore.gamescope || false
                    onClicked: control.close()
                    Layout.fillWidth: true
                    Layout.leftMargin: 15
                    Layout.rightMargin: 15
                    Layout.preferredHeight: 30
                }

                NfButton {
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
            visible: GameCore.isFluent
        }

        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 5
            initialItem: difficultyPaneComponent
            property string direction: GameCore.isFluent ? "y" : "x"
            property int animationDuration: GameCore.isFluent ? 150 : 200

            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stackView.animationDuration; easing.type: Easing.InQuint }
                    NumberAnimation { property: stackView.direction; from: (stackView.mirrored ? -0.3 : 0.3) * -stackView.width; to: 0; duration: 400; easing.type: Easing.OutCubic }
                }
            }

            popExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stackView.animationDuration; easing.type: Easing.OutQuint }
            }

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stackView.animationDuration; easing.type: Easing.InQuint }
                    NumberAnimation { property: stackView.direction; from: (stackView.mirrored ? -0.3 : 0.3) * stackView.width; to: 0; duration: 400; easing.type: Easing.OutCubic }
                }
            }

            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stackView.animationDuration; easing.type: Easing.OutQuint }
            }

            replaceEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: stackView.animationDuration; easing.type: Easing.InQuint }
                    NumberAnimation { property: stackView.direction; from: (stackView.mirrored ? -0.3 : 0.3) * stackView.width; to: 0; duration: 400; easing.type: Easing.OutCubic }
                }
            }

            replaceExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: stackView.animationDuration; easing.type: Easing.OutQuint }
            }

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
