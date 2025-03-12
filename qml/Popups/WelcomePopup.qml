import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import net.odizinne.retr0mine 1.0

Popup {
    id: control
    height: 200
    width: 400
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    modal: true
    visible: true

    ColumnLayout {
        opacity: 1
        id: initialConfig
        anchors.fill: parent
        Label {
            text: qsTr("Welcome to Retr0Mine")
            color: "#28d13c"
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 22
            font.bold: true
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
                text: qsTr("Later")
                onClicked: {
                    control.visible = false
                    GameSettings.welcomeMessageShown = true
                }
            }

            NfButton {
                text: qsTr("Yes")
                highlighted: true
                onClicked: {
                    control.visible = false
                    initialConfig.visible = false
                    controlsConfig.visible = true
                    control.height = 350
                    control.visible = true
                }
            }
        }
    }

    ColumnLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        id: controlsConfig
        spacing: 20

        ColumnLayout {
            spacing: 20
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            AnimatedImage {
                id: classicImage
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/images/classic.gif"
                sourceSize.height: 116
                sourceSize.width: 116
            }

            Label {
                id: classicLabel
                Layout.preferredHeight: chordLabel.height
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Qt.AlignHCenter
                text: qsTr("- Left click on cell to reveal\n- Right click on cell to flag")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            AnimatedImage {
                id: chordImage
                visible: false
                Layout.alignment: Qt.AlignHCenter
                source: "qrc:/images/chord.gif"
                sourceSize.height: 116
                sourceSize.width: 116
            }

            Label {
                id: chordLabel
                visible: false
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Qt.AlignHCenter
                text: qsTr("- Any click on satisfied number to reveal\n- Left click on cell to flag\n- Right click on cell to reveal")
                Layout.fillWidth: true
                wrapMode: Text.Wrap

            }
        }

        RowLayout {
            Label {
                text: gameplaySwitch.checked ? qsTr("Chord") : qsTr("Classic")
            }

            Item {
                Layout.fillWidth: true
            }

            NfSwitch {
                id: gameplaySwitch
                onCheckedChanged: {
                    chordLabel.visible = checked
                    chordImage.visible = checked
                    classicLabel.visible = !checked
                    classicImage.visible = !checked
                    GameSettings.autoreveal = checked
                    GameSettings.invertLRClick = checked
                }
            }
        }

        RowLayout {
            Item {
                Layout.fillWidth: true
            }

            NfButton {
                text: "Next"
                onClicked: {
                    control.visible = false
                    controlsConfig.visible = false
                    visualsConfig.visible = true
                    control.height = 300
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
        spacing: 15

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            rows: 4
            columns: 3

            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    color: "#069ecc"
                    text: "1"
                    opacity: visualsSwitch.checked ? 0.25 : 1
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35

                IconImage {
                    anchors.centerIn: parent
                    source: "qrc:/icons/flag.png"
                    color: {
                        if (  GameSettings.contrastFlag) return  GameConstants.foregroundColor
                        else return GameConstants.accentColor
                    }
                    visible: true
                    sourceSize.width: 35 / 1.8
                    sourceSize.height: 35 / 1.8
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "3"
                    color: "#d12844"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "4"
                    //opacity: visualsSwitch.checked ? 0.25 : 1
                    color: "#9328d1"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "2"
                    opacity: visualsSwitch.checked ? 0.25 : 1
                    color: "#28d13c"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "2"
                    opacity: visualsSwitch.checked ? 0.25 : 1
                    color: "#28d13c"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "1"
                    opacity: visualsSwitch.checked ? 0.25 : 1
                    color: "#069ecc"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                IconImage {
                    anchors.centerIn: parent
                    source: "qrc:/icons/flag.png"
                    color: {
                        if (  GameSettings.contrastFlag) return  GameConstants.foregroundColor
                        else return GameConstants.accentColor
                    }
                    visible: true
                    sourceSize.width: 35 / 1.8
                    sourceSize.height: 35 / 1.8
                }
            }
            NfButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                    border.width: 2
                    color: "transparent"
                    visible: visualsSwitch.checked ? false : true
                    border.color:  GameConstants.frameColor
                }

                Text {
                    anchors.centerIn: parent
                    text: "3"
                    color: "#d12844"
                    font.pixelSize: 35 * 0.60
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: qsTr("Enable enhanced visuals")
            }

            Item {
                Layout.fillWidth: true
            }

            NfSwitch {
                id: visualsSwitch
                onCheckedChanged: {
                    GameSettings.cellFrame = !checked
                    GameSettings.dimSatisfied = checked
                }
                Component.onCompleted: {
                    checked = !GameSettings.cellFrame && GameSettings.dimSatisfied
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Label {
                text: qsTr("System color for flags")
            }

            Item {
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
            Layout.alignment: Qt.AlignRight
            text: qsTr("Next")
            onClicked: {
                control.visible = false
                visualsConfig.visible = false
                accessibilityConfig.visible = true
                control.visible = true
                control.height = 440
                control.width = 400
            }
        }
    }

    ColumnLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        id: accessibilityConfig
        spacing: 30

        Label {
            text: qsTr("Color correction")
            font.pixelSize: 18
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 30

            GridLayout {
                rows: 4
                columns: 3

                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        color: "#069ecc"
                        text: "1"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "2"
                        color: "#28d13c"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "3"
                        color: "#d12844"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "4"
                        color: "#9328d1"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "5"
                        color: "#ebc034"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "6"
                        color: "#34ebb1"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "7"
                        color: "#eb8634"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color:  GameConstants.foregroundColor
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                        finishedConfig.visible = true
                        control.height = 150
                        control.visible = true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                rows: 4
                columns: 3

                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "1"
                        color: "#e41a1c"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "2"
                        color: "#377eb8"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "3"
                        color: "#4daf4a"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "4"
                        color: "#984ea3"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "5"
                        color: "#ff7f00"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "6"
                        color: "#f781bf"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "7"
                        color: "#a65628"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color:  GameConstants.foregroundColor
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                        finishedConfig.visible = true
                        control.height = 150
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

                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "1"
                        color: "#66c2a5"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "2"
                        color: "#fc8d62"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "3"
                        color: "#8da0cb"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "4"
                        color: "#e78ac3"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "5"
                        color: "#a6d854"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "6"
                        color: "#ffd92f"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "7"
                        color: "#e5c494"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color:  GameConstants.foregroundColor
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                        finishedConfig.visible = true
                        control.height = 150
                        control.visible = true
                    }
                }
            }


            GridLayout {
                rows: 4
                columns: 3

                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "1"
                        color: "#377eb8"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "2"
                        color: "#4daf4a"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "3"
                        color: "#e41a1c"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "4"
                        color: "#984ea3"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "5"
                        color: "#ff7f00"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "6"
                        color: "#a65628"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "7"
                        color: "#f781bf"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                NfButton {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        radius: GameCore.isFluent ? 4 : (GameCore.isUniversal ? 0 : 3)
                        border.width: 2
                        color: "transparent"
                        border.color:  GameConstants.frameColor
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color:  GameConstants.foregroundColor
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                        finishedConfig.visible = true
                        control.height = 150
                        control.visible = true
                    }
                }
            }
        }
    }
    ColumnLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        id: finishedConfig

        Label {
            text: qsTr("You're all set!")
            color: "#28d13c"
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
                text: qsTr("Close")
                onClicked: {
                    control.visible = false
                    GameSettings.welcomeMessageShown = true
                }
            }
        }
    }
}
