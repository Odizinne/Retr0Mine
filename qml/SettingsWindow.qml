pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

ApplicationWindow {
    id: control
    title: qsTr("Settings")
    readonly property int baseWidth: 740
    readonly property int baseHeight: 480

    width: GameCore.gamescope ? 1280 : baseWidth
    height: GameCore.gamescope ? 800 : baseHeight
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    visible: ComponentsContext.settingsWindowVisible
    flags: Qt.Dialog
    transientParent: null
    Universal.theme: Constants.universalTheme
    Universal.accent: Constants.accentColor

    onClosing: ComponentsContext.settingsWindowVisible = false
    property bool initialAnimationPlayed: false

    onVisibleChanged: {
        if (visible && !initialAnimationPlayed) {
            sidebarList.opacity = 1
            stackView.push(difficultyPaneComponent)
            ComponentsContext.settingsIndex = 0
            initialAnimationPlayed = true
        }
    }

    BusyIndicator {
        /*==========================================
         | continous window update                 |
         | needed for steam overlay                |
         ==========================================*/
        opacity: 0
        visible: SteamIntegration.initialized && !GameCore.gamescope
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
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            Rectangle {
                anchors.fill: parent
                color: Constants.settingsPaneColor
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                ListView {
                    opacity: 0
                    id: sidebarList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                            text: qsTr("Multiplayer"),
                            icon: "qrc:/icons/multiplayer.png",
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
                    currentIndex: ComponentsContext.settingsIndex

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.InCubic
                        }
                    }

                    delegate: CustomDelegate {
                        id: del
                        width: parent.width
                        height: 43
                        required property var modelData
                        required property int index
                        icon.source: modelData.icon
                        icon.width: 16
                        icon.height: 16
                        text: modelData.text
                        isCurrentItem: ListView.isCurrentItem
                        onClicked: {
                            if (sidebarList.currentIndex !== index) {
                                ComponentsContext.settingsIndex = index
                                switch(index) {
                                    case 0: stackView.push(difficultyPaneComponent); break;
                                    case 1: stackView.push(gameplayPaneComponent); break;
                                    case 2: stackView.push(visualsPaneComponent); break;
                                    case 3: stackView.push(soundPaneComponent); break;
                                    case 4: stackView.push(shortcutsPaneComponent); break;
                                    case 5: stackView.push(multiplayerPaneComponent); break;
                                    case 6: stackView.push(accessibilityPaneComponent); break;
                                    case 7: stackView.push(languagePaneComponent); break;
                                    case 8: stackView.push(advancedPaneComponent); break;
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: 26
                            width: 4
                            opacity: parent.isCurrentItem ? 1 : 0
                            color: Constants.accentColor

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 187
                                    easing.type: Easing.InCubic
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

        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 5
            initialItem: emptyPaneComponent

            Component {
                id: emptyPaneComponent
                Item {}
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
                id: multiplayerPaneComponent
                MultiplayerPane {
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
