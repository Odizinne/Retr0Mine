pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQuick.Controls.impl
import Odizinne.Retr0Mine

Popup {
    id: control
    width: lyt.implicitWidth + 40
    height: lyt.implicitHeight + 40
    modal: true
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    T.Overlay.modal: Rectangle {
        color: control.Universal.altMediumLowColor
    }

    T.Overlay.modeless: Rectangle {
        color: control.Universal.baseLowColor
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.8
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.8
                duration: 150
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 100
            }
        }
    }

    property int cellIndex: -1
    property bool isFlagged: false
    property bool isQuestioned: false
    property bool isRevealed: false

    background: Item {}

    Rectangle {
        height: lyt.implicitHeight + 10
        width: lyt.implicitWidth + 20
        color: Constants.settingsPaneColor
        border.width: 1
        border.color: Constants.foregroundColor
        radius: 5

        RowLayout {
            id: lyt
            anchors.fill: parent
            anchors.margins: 4
            spacing: 8

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                IconImage {
                    id: revealIcon
                    anchors.centerIn: parent
                    source: "qrc:/icons/reveal.png"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    color: Constants.foregroundColor
                    scale: revealArea.containsMouse ? 1.2 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                MouseArea {
                    id: revealArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        GridBridge.reveal(control.cellIndex, SteamIntegration.playerName)
                        control.close()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                IconImage {
                    id: flagIcon
                    anchors.centerIn: parent
                    source: GameState.flagPath
                    sourceSize.width: 20
                    sourceSize.height: 20
                    color: control.isFlagged ? Constants.accentColor : Constants.foregroundColor
                    scale: flagArea.containsMouse ? 1.2 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                MouseArea {
                    id: flagArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        GridBridge.setFlag(control.cellIndex)
                        control.close()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                IconImage {
                    id: questionIcon
                    anchors.centerIn: parent
                    source: "qrc:/icons/questionmark.png"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    color: control.isQuestioned ? Constants.accentColor : Constants.foregroundColor
                    scale: questionArea.containsMouse ? 1.2 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                MouseArea {
                    id: questionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        GridBridge.setQuestioned(control.cellIndex)
                        control.close()
                    }
                }
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                visible: SteamIntegration.isInMultiplayerGame

                IconImage {
                    id: signalIcon
                    anchors.centerIn: parent
                    source: "qrc:/icons/signal.png"
                    sourceSize.width: 20
                    sourceSize.height: 20
                    color: Constants.foregroundColor
                    scale: signalArea.containsMouse ? 1.2 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                MouseArea {
                    id: signalArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        NetworkManager.sendPing(control.cellIndex)
                        control.close()
                    }
                }
            }
        }
    }
}
