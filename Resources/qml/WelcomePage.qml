import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: welcomePage
    height: 200
    width: 400
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose
    modal: true

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

            Button {
                text: qsTr("Later")
                onClicked: {
                    welcomePage.visible = false
                    settings.welcomeMessageShown = true
                }
            }

            Button {
                text: qsTr("Yes")
                onClicked: {
                    welcomePage.visible = false
                    initialConfig.visible = false
                    controlsConfig.visible = true
                    welcomePage.height = 300
                    welcomePage.visible = true
                }
            }
        }
    }

    RowLayout {
        opacity: 1
        visible: false
        anchors.fill: parent
        id: controlsConfig



        ColumnLayout {
            spacing: 20
            Layout.preferredWidth: parent.width * 0.5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            AnimatedImage {
                Layout.alignment: Qt.AlignHCenter

                source: "qrc:/images/classic.gif"
                sourceSize.height: 116
                sourceSize.width: 116
            }

            Label {
                Layout.preferredHeight: chordLabel.height
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Qt.AlignHCenter

                text: qsTr("Click cell to reveal")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Button {
                Layout.alignment: Qt.AlignHCenter

                text: qsTr("Classic")
                onClicked: {
                    welcomePage.visible = false
                    settings.autoreveal = false
                    controlsConfig.visible = false
                    visualsConfig.visible = true
                    welcomePage.width = 350
                    welcomePage.visible = true
                }
            }
        }

        ColumnLayout {
            spacing: 20
            Layout.preferredWidth: parent.width * 0.5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            AnimatedImage {
                Layout.alignment: Qt.AlignHCenter

                source: "qrc:/images/chord.gif"
                sourceSize.height: 116
                sourceSize.width: 116
            }

            Label {
                id: chordLabel
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment:  Qt.AlignHCenter

                text: qsTr("Click cell or satisfied number to reveal")
                Layout.fillWidth: true
                wrapMode: Text.Wrap

            }

            Button {
                text: qsTr("Chord")
                Layout.alignment: Qt.AlignHCenter

                onClicked: {
                    welcomePage.visible = false
                    settings.autoreveal = true
                    controlsConfig.visible = false
                    visualsConfig.visible = true
                    welcomePage.height = 250
                    welcomePage.width = 350
                    welcomePage.visible = true
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

        // video

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            rows: 4
            columns: 3

            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35

                Image {
                    anchors.centerIn: parent
                    source: {
                        if(settings.contrastFlag)
                            return darkMode ? "qrc:/icons/flag.png" : "qrc:/icons/flag_dark.png"
                        return flagIcon
                    }
                    visible: true
                    sourceSize.width: 35 / 2.1
                    sourceSize.height: 35 / 2.1
                }
            }
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    visible: visualsSwitch.checked ? false : true
                    color: "transparent"
                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                Image {
                    anchors.centerIn: parent
                    source: {
                        if(settings.contrastFlag)
                            return darkMode ? "qrc:/icons/flag.png" : "qrc:/icons/flag_dark.png"
                        return flagIcon
                    }
                    visible: true
                    sourceSize.width: 35 / 2.1
                    sourceSize.height: 35 / 2.1
                }

            }
            Button {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 35
                flat: true

                Rectangle {
                    anchors.fill: parent
                    border.width: 2
                    color: "transparent"
                    visible: visualsSwitch.checked ? false : true

                    radius: {
                        if (isUniversalTheme) return 0
                        else if (isFluentWinUI3Theme) return 4
                        else if (isFusionTheme) return 3
                        else return 2
                    }
                    border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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

            Switch {
                id: visualsSwitch
                onCheckedChanged: {
                    settings.cellFrame = !checked
                    settings.dimmSatisfied = checked
                    settings.animations = checked
                }
                Component.onCompleted: {
                    checked = !settings.cellFrame && settings.dimmSatisfied && settings.animations
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignRight
            text: qsTr("Next")
            onClicked: {
                welcomePage.visible = false
                visualsConfig.visible = false
                accessibilityConfig.visible = true
                welcomePage.visible = true
                welcomePage.height = 440
                welcomePage.width = 400
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

                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color: root.darkMode ? "white" : "black"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: qsTr("None")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        welcomePage.visible = false
                        settings.colorBlindness = 0
                        accessibilityConfig.visible = false
                        finishedConfig.visible = true
                        welcomePage.height = 150
                        welcomePage.visible = true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                rows: 4
                columns: 3

                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color: root.darkMode ? "white" : "black"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: qsTr("Tritanopia")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        welcomePage.visible = false
                        settings.colorBlindness = 3
                        accessibilityConfig.visible = false
                        finishedConfig.visible = true
                        welcomePage.height = 150
                        welcomePage.visible = true
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

                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color: root.darkMode ? "white" : "black"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: qsTr("Protanopia")
                    Layout.fillWidth: true
                    Layout.columnSpan: 3
                    onClicked: {
                        welcomePage.visible = false
                        settings.colorBlindness = 2
                        accessibilityConfig.visible = false
                        finishedConfig.visible = true
                        welcomePage.height = 150
                        welcomePage.visible = true
                    }
                }
            }


            GridLayout {
                rows: 4
                columns: 3

                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
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
                Button {
                    Layout.preferredHeight: 35
                    Layout.preferredWidth: 35
                    flat: true

                    Rectangle {
                        anchors.fill: parent
                        border.width: 2
                        color: "transparent"
                        radius: {
                            if (isUniversalTheme) return 0
                            else if (isFluentWinUI3Theme) return 4
                            else if (isFusionTheme) return 3
                            else return 2
                        }
                        border.color: darkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "8"
                        color: root.darkMode ? "white" : "black"
                        font.pixelSize: 35 * 0.60
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: qsTr("Deuteranopia")
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    onClicked: {
                        welcomePage.visible = false
                        settings.colorBlindness = 3
                        accessibilityConfig.visible = false
                        finishedConfig.visible = true
                        welcomePage.height = 150
                        welcomePage.visible = true
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

            Button {
                text: qsTr("Close")
                onClicked: {
                    welcomePage.visible = false
                    settings.welcomeMessageShown = true
                }
            }
        }
    }
}
