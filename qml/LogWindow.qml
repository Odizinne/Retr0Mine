pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

ApplicationWindow {
    id: control
    title: qsTr("Retr0Mine Log Viewer")
    width: GameCore.gamescope ? 1280 : 800
    height: GameCore.gamescope ? 800 : 600
    visible: ComponentsContext.logWindowVisible

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
                // Set the current log file to the latest
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
        currentLogFile = filename;
        if (followLive) {
            logTextArea.text = LogManager.getBuffer().join("\n");
        } else {
            logTextArea.text = GameCore.readLogFile(filename);
        }

        // Auto scroll to bottom
        if (autoScroll) {
            logTextArea.cursorPosition = logTextArea.length;
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
