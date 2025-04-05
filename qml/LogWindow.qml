pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

ApplicationWindow {
    id: control
    title: qsTr("Log viewer")
    width: GameCore.gamescope ? 1280 : 800
    height: GameCore.gamescope ? 800 : 600
    visible: ComponentsContext.logWindowVisible
    transientParent: null
    Universal.theme: Constants.universalTheme
    Universal.accent: Constants.accentColor

    onClosing: {
        ComponentsContext.logWindowVisible = false
    }

    property bool autoScroll: true
    property bool followLive: true
    property string currentLogFile: ""

    onVisibleChanged: {
        if (visible) {
            refreshLogFilesList();
            if (followLive) {
                const files = logFilesList.model;
                if (files.length > 0) {
                    currentLogFile = files[0];
                    loadLogContent(currentLogFile);
                }
            }
        }
    }

    function refreshLogFilesList() {
        logFilesList.model = GameCore.getLogFiles();
    }

    function loadLogContent(filename) {
        currentLogFile = filename
        if (followLive) {
            const logLines = LogManager.getBuffer()
            const colorizedLines = []

            logLines.forEach(line => {
                                 const timeMatch = line.match(/\d{2}:\d{2}:\d{2}/)
                                 const timeOnly = timeMatch ? timeMatch[0] : ""
                                 const restOfLine = line.replace(/\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}/, "").trim()
                                 let formattedLine = timeOnly ? timeOnly + " " : ""
                                 formattedLine += restOfLine
                                 .replace(/\[ ERROR \]/g, '[ <font color="red">ERROR</font> ]')
                                 .replace(/\[ WARNING \]/g, '[ <font color="orange">WARNING</font> ]')
                                 .replace(/\[ INFO \]/g, '[ <font color="green">INFO</font> ]')
                                 .replace(/\[ DEBUG \]/g, '[ <font color="blue">DEBUG</font> ]')
                                 colorizedLines.push(formattedLine)
                             })

            logTextArea.text = colorizedLines.join("<br>")
        } else {
            logTextArea.text = GameCore.readLogFile(filename)
        }

        if (autoScroll) {
            logTextArea.cursorPosition = logTextArea.length
        }
    }

    Timer {
        interval: 1000
        running: control.visible && control.followLive
        repeat: true
        onTriggered: {
            if (control.followLive) {
                control.loadLogContent(control.currentLogFile);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: qsTr("Log Files:")
            }

            ComboBox {
                id: logFilesList
                Layout.fillWidth: true
                enabled: !control.followLive
                onCurrentTextChanged: {
                    if (currentText && !control.followLive) {
                        control.loadLogContent(currentText);
                    }
                }
            }

            NfButton {
                text: qsTr("Refresh")
                onClicked: control.refreshLogFilesList()
            }

            NfSwitch {
                text: qsTr("Live Log")
                checked: control.followLive
                onCheckedChanged: {
                    control.followLive = checked;
                    if (control.followLive) {
                        // Switch to memory buffer
                        control.loadLogContent("");
                    } else if (logFilesList.currentText) {
                        // Switch to selected file
                        control.loadLogContent(logFilesList.currentText);
                    }
                }
            }

            NfSwitch {
                text: qsTr("Auto-scroll")
                checked: control.autoScroll
                onCheckedChanged: {
                    control.autoScroll = checked;
                    if (control.autoScroll) {
                        logTextArea.cursorPosition = logTextArea.length;
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextArea {
                id: logTextArea
                readOnly: true
                wrapMode: TextEdit.NoWrap
                font.family: "Courier New, Courier, monospace"
                selectByMouse: true
                color: Constants.foregroundColor
                textFormat: TextEdit.RichText

                background: Rectangle {
                    color: Constants.settingsPaneColor
                    border.color: Constants.foregroundColor
                    border.width: 1
                    opacity: 0.5
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            NfButton {
                text: qsTr("Close")
                Layout.alignment: Qt.AlignRight
                onClicked: control.close()
            }

            NfButton {
                text: qsTr("Clear Buffer")
                visible: control.followLive
                onClicked: {
                    LogManager.clearBuffer();
                    if (control.followLive) {
                        control.loadLogContent("");
                    }
                }
            }
        }
    }
}
