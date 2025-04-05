pragma Singleton

import QtQuick
import Odizinne.Retr0Mine

QtObject {
    property var logBuffer: []
    property int maxBufferSize: 1000

    function log(message) {
        if (!UserSettings.logs) return
        const timestamp = new Date().toISOString().replace('T', ' ').substr(0, 19);
        const formattedMessage = timestamp + " | " + message;

        logBuffer.push(formattedMessage);

        if (logBuffer.length > maxBufferSize) {
            logBuffer.shift();
        }

        console.log(formattedMessage);
        GameCore.writeToLogFile(formattedMessage);
    }

    function error(message) {
        log("[ ERROR ] " + message);
    }

    function warn(message) {
        log("[ WARN ] " + message);
    }

    function info(message) {
        log("[ INFO ] " + message);
    }

    function debug(message) {
        log("[ DEBUG ] " + message);
    }

    function getBuffer() {
        return logBuffer;
    }

    function clearBuffer() {
        logBuffer = [];
    }
}
