import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Controls.impl
import Odizinne.Retr0Mine

AnimatedPopup {
    id: control
    height: currentLayoutImplicitHeight + topPadding + bottomPadding + 16
    width: 400
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    modal: true
    property int currentLayoutImplicitHeight: initialConfig.implicitHeight
    property int buttonWidth: (Math.max(laterButton.implicitWidth, yesButton.implicitWidth, toVisualButton.implicitWidth, toAccessibilityButton.implicitWidth, closeButton.implicitWidth)) + 20

    ColumnLayout {
        opacity: 1
        id: initialConfig
        anchors.fill: parent
        anchors.margins: 8
        Label {
            text: qsTr("Welcome to Retr0Mine")
            color: GameConstants.accentColor
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 22
        }

        Label {
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            text: qsTr("Would you like to configure some quick settings to enhance your experience? Everything can still be adjusted later.")
        }

        RowLayout {
            spacing: 15
            Item {
                Layout.fillWidth: true
            }

            NfButton {
                id: laterButton
                text: qsTr("Later")
                Layout.preferredWidth: control.buttonWidth
                onClicked: {
                    control.visible = false
                    GameSettings.firstRunCompleted = true
                }
            }

            NfButton {
                id: yesButton
                text: qsTr("Yes")
                Layout.preferredWidth: control.buttonWidth
                highlighted: true
                onClicked: {
                    control.visible = false
                    initialConfig.visible = false
                    controlsConfig.visible = true
                    control.currentLayoutImplicitHeight = controlsConfig.implicitHeight
                    control.visible = true
                }
            }
        }
    }

    ColumnLayout {
        anchors.margins: 8
        opacity: 1
        visible: false
        anchors.fill: parent
        id: controlsConfig
        spacing: 20

        ColumnLayout {
            spacing: 20
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            Label {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Text.AlignHCenter
                Layout.fillWidth: true
                text: qsTr("Mouse settings")
                font.pixelSize: 18
                font.bold: true
            }

            RowLayout {
                property int labelSize: Math.max(leftCLabel.implicitWidth, rightCLabel.implicitWidth)
                Label {
                    id: leftCLabel
                    Layout.alignment: Qt.AlignTop
                    horizontalAlignment:  Text.AlignRight
                    text: GameConstants.leftClickExplanation
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.labelSize
                    wrapMode: Text.Wrap
                    font.pixelSize: 16
                }

                IconImage {
                    id: mouseBase
                    Layout.alignment: Qt.AlignHCenter
                    source: "qrc:/images/mouse_base.png"
                    color: GameConstants.foregroundColor
                    sourceSize.height: 164
                    sourceSize.width: 164
                    IconImage {
                        id: mouseLeft
                        anchors.fill: parent
                        source: "qrc:/images/mouse_left.png"
                        color: GameSettings.invertLRClick ? GameConstants.foregroundColor : GameConstants.accentColor
                        sourceSize.height: 164
                        sourceSize.width: 164
                    }

                    IconImage {
                        id: mouseRight
                        anchors.fill: parent
                        source: "qrc:/images/mouse_right.png"
                        color: GameSettings.invertLRClick ? GameConstants.accentColor : GameConstants.foregroundColor
                        sourceSize.height: 164
                        sourceSize.width: 164

                    }
                }

                Label {
                    id: rightCLabel
                    Layout.alignment: Qt.AlignTop
                    horizontalAlignment:  Text.AlignLeft
                    text: GameConstants.rightClickExplanation
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: 16
                    Layout.preferredWidth: parent.labelSize
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Text.AlignHCenter
                color: "#f6ae57"
                text: qsTr("Any click on satisfied number to reveal surroundings")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Label {
                text: gameplaySwitch.checked ? qsTr("Inverted") : qsTr("Normal")
            }

            Item {
                Layout.fillWidth: true
            }

            NfSwitch {
                id: gameplaySwitch
                checked: GameSettings.invertLRClick
                onCheckedChanged: {
                    GameSettings.invertLRClick = checked
                }
            }
        }

        RowLayout {
            Item {
                Layout.fillWidth: true
            }

            NfButton {
                id: toVisualButton
                Layout.preferredWidth: control.buttonWidth
                text: qsTr("Next")
                onClicked: {
                    control.visible = false
                    controlsConfig.visible = false
                    visualsConfig.visible = true
                    control.currentLayoutImplicitHeight = visualsConfig.implicitHeight
                    control.width = 350
                    control.visible = true
                }
            }
        }
    }

    ColumnLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        id: visualsConfig
        spacing: 10
        anchors.margins: 8

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            rows: 4
            columns: 3

            Repeater {
                model: [
                    { type: "number", value: "1", color: "#069ecc", dimWhenSatisfied: true },
                    { type: "flag" },
                    { type: "number", value: "3", color: "#d12844", dimWhenSatisfied: false },
                    { type: "number", value: "4", color: "#9328d1", dimWhenSatisfied: false },
                    { type: "number", value: "2", color: "#28d13c", dimWhenSatisfied: true },
                    { type: "number", value: "2", color: "#28d13c", dimWhenSatisfied: true },
                    { type: "number", value: "1", color: "#069ecc", dimWhenSatisfied: true },
                    { type: "flag" },
                    { type: "number", value: "3", color: "#d12844", dimWhenSatisfied: false }
                ]

                delegate: NfButton {
                    id: cell
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: modelData.type === "number"
                    required property var modelData

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        visible: cell.modelData.type === "number" && GameSettings.cellFrame
                        color: "transparent"
                        border.color: GameConstants.frameColor
                        opacity: cell.modelData.dimWhenSatisfied && GameSettings.dimSatisfied ? GameSettings.satisfiedOpacity : 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.value || ""
                        color: cell.modelData.color || ""
                        opacity: cell.modelData.dimWhenSatisfied && GameSettings.dimSatisfied ? 0.25 : 1
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: cell.modelData.type === "number"
                    }

                    IconImage {
                        anchors.centerIn: parent
                        source: "qrc:/icons/flag.png"
                        color: {
                            if (GameSettings.contrastFlag) return GameConstants.foregroundColor
                            else return GameConstants.accentColor
                        }
                        visible: cell.modelData.type === "flag"
                        sourceSize.width: 35 / 1.8
                        sourceSize.height: 35 / 1.8
                    }
                }
            }
        }

        RowLayout {
            Layout.topMargin: 30
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: qsTr("Dimm satisfied numbers")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: dimSwitch.click()
                }
            }

            NfSwitch {
                id: dimSwitch
                checked: GameSettings.dimSatisfied
                onCheckedChanged: {
                    GameSettings.dimSatisfied = checked
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: qsTr("Show cell frame")
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: frameSwitch.click()
                }
            }

            NfSwitch {
                id: frameSwitch
                checked: GameSettings.cellFrame
                onCheckedChanged: {
                    GameSettings.cellFrame = checked
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: qsTr("Colored flags")
                Layout.fillWidth: true
            }

            NfSwitch {
                id: accentFlagSwitch
                onCheckedChanged: {
                    GameSettings.contrastFlag = !checked
                }
                Component.onCompleted: {
                    checked = !GameSettings.contrastFlag
                }
            }
        }

        NfButton {
            id: toAccessibilityButton
            Layout.preferredWidth: control.buttonWidth
            Layout.alignment: Qt.AlignRight
            text: qsTr("Next")
            onClicked: {
                control.visible = false
                visualsConfig.visible = false
                accessibilityConfig.visible = true
                control.width = 400
                control.currentLayoutImplicitHeight = accessibilityConfig.implicitHeight
                control.visible = true
            }
        }
    }

    ColumnLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        anchors.margins: 8
        id: accessibilityConfig
        spacing: 30

        Label {
            text: qsTr("Color correction")
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 30

            GridLayout {
                rows: 4
                columns: 3

                Repeater {
                    model: [
                        { type: "number", value: "1", color: "#069ecc" },
                        { type: "number", value: "2", color: "#28d13c" },
                        { type: "number", value: "3", color: "#d12844" },
                        { type: "number", value: "4", color: "#9328d1" },
                        { type: "empty" },
                        { type: "number", value: "5", color: "#ebc034" },
                        { type: "number", value: "6", color: "#34ebb1" },
                        { type: "number", value: "7", color: "#eb8634" },
                        { type: "number", value: "8", color: GameConstants.foregroundColor }
                    ]

                    delegate: NfButton {
                        id: noneCell
                        required property var modelData
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 35
                        flat: noneCell.modelData.type === "number"

                        Rectangle {
                            anchors.fill: parent
                            border.width: 2
                            color: "transparent"
                            border.color: GameConstants.frameColor
                            visible: noneCell.modelData.type === "number" && GameSettings.cellFrame
                        }

                        Text {
                            anchors.centerIn: parent
                            text: noneCell.modelData.value || ""
                            color: noneCell.modelData.color || ""
                            font.pixelSize: 35 * 0.60
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: noneCell.modelData.type !== "empty"
                        }
                    }
                }

                NfButton {
                    text: qsTr("None")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        control.visible = false
                        GameSettings.colorBlindness = 0
                        accessibilityConfig.visible = false
                        control.currentLayoutImplicitHeight = finishedConfig.implicitHeight
                        finishedConfig.visible = true
                        control.visible = true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                rows: 4
                columns: 3

                Repeater {
                    model: [
                        { type: "number", value: "1", color: "#e41a1c" },
                        { type: "number", value: "2", color: "#377eb8" },
                        { type: "number", value: "3", color: "#4daf4a" },
                        { type: "number", value: "4", color: "#984ea3" },
                        { type: "empty" },
                        { type: "number", value: "5", color: "#ff7f00" },
                        { type: "number", value: "6", color: "#f781bf" },
                        { type: "number", value: "7", color: "#a65628" },
                        { type: "number", value: "8", color: GameConstants.foregroundColor }
                    ]

                    delegate: NfButton {
                        id: tritCell
                        required property var modelData
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 35
                        flat: tritCell.modelData.type === "number"

                        Rectangle {
                            anchors.fill: parent
                            border.width: 2
                            color: "transparent"
                            border.color: GameConstants.frameColor
                            visible: tritCell.modelData.type === "number" && GameSettings.cellFrame
                        }

                        Text {
                            anchors.centerIn: parent
                            text: tritCell.modelData.value || ""
                            color: tritCell.modelData.color || ""
                            font.pixelSize: 35 * 0.60
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: tritCell.modelData.type !== "empty"
                        }
                    }
                }

                NfButton {
                    text: qsTr("Tritanopia")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        control.visible = false
                        GameSettings.colorBlindness = 3
                        accessibilityConfig.visible = false
                        control.currentLayoutImplicitHeight = finishedConfig.implicitHeight
                        finishedConfig.visible = true
                        control.visible = true
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 30

            GridLayout {
                rows: 4
                columns: 3

                Repeater {
                    model: [
                        { type: "number", value: "1", color: "#66c2a5" },
                        { type: "number", value: "2", color: "#fc8d62" },
                        { type: "number", value: "3", color: "#8da0cb" },
                        { type: "number", value: "4", color: "#e78ac3" },
                        { type: "empty" },
                        { type: "number", value: "5", color: "#a6d854" },
                        { type: "number", value: "6", color: "#ffd92f" },
                        { type: "number", value: "7", color: "#e5c494" },
                        { type: "number", value: "8", color: GameConstants.foregroundColor }
                    ]

                    delegate: NfButton {
                        id: protCell
                        required property var modelData
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 35
                        flat: protCell.modelData.type === "number"

                        Rectangle {
                            anchors.fill: parent
                            border.width: 2
                            color: "transparent"
                            border.color: GameConstants.frameColor
                            visible: protCell.modelData.type === "number" && GameSettings.cellFrame
                        }

                        Text {
                            anchors.centerIn: parent
                            text: protCell.modelData.value || ""
                            color: protCell.modelData.color || ""
                            font.pixelSize: 35 * 0.60
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: protCell.modelData.type !== "empty"
                        }
                    }
                }

                NfButton {
                    text: qsTr("Protanopia")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        control.visible = false
                        GameSettings.colorBlindness = 2
                        accessibilityConfig.visible = false
                        control.currentLayoutImplicitHeight = finishedConfig.implicitHeight
                        finishedConfig.visible = true
                        control.visible = true
                    }
                }
            }

            GridLayout {
                rows: 4
                columns: 3

                Repeater {
                    model: [
                        { type: "number", value: "1", color: "#377eb8" },
                        { type: "number", value: "2", color: "#4daf4a" },
                        { type: "number", value: "3", color: "#e41a1c" },
                        { type: "number", value: "4", color: "#984ea3" },
                        { type: "empty" },
                        { type: "number", value: "5", color: "#ff7f00" },
                        { type: "number", value: "6", color: "#a65628" },
                        { type: "number", value: "7", color: "#f781bf" },
                        { type: "number", value: "8", color: GameConstants.foregroundColor }
                    ]

                    delegate: NfButton {
                        id: deutCell
                        required property var modelData
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 35
                        flat: modelData.type === "number"

                        Rectangle {
                            anchors.fill: parent
                            border.width: 2
                            color: "transparent"
                            border.color: GameConstants.frameColor
                            visible: deutCell.modelData.type === "number" && GameSettings.cellFrame
                        }

                        Text {
                            anchors.centerIn: parent
                            text: deutCell.modelData.value || ""
                            color: deutCell.modelData.color || ""
                            font.pixelSize: 35 * 0.60
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: deutCell.modelData.type !== "empty"
                        }
                    }
                }

                NfButton {
                    text: qsTr("Deuteranopia")
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    onClicked: {
                        control.visible = false
                        GameSettings.colorBlindness = 3
                        accessibilityConfig.visible = false
                        control.currentLayoutImplicitHeight = finishedConfig.implicitHeight
                        finishedConfig.visible = true
                        control.visible = true
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.margins: 8
        opacity: 1
        visible: false
        anchors.fill: parent
        id: finishedConfig

        Label {
            text: qsTr("You're all set!")
            color: GameConstants.accentColor
            font.pixelSize: 20
        }

        Label {
            text: qsTr("You can edit these changes anytime in settings.")
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        RowLayout {
            Item {
                Layout.fillWidth: true
            }

            NfButton {
                id: closeButton
                Layout.preferredWidth: control.buttonWidth
                text: qsTr("Close")
                onClicked: {
                    control.visible = false
                    GameSettings.firstRunCompleted = true
                }
            }
        }
    }
}
