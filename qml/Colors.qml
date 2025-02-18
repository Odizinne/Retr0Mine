import QtQuick

QtObject {
    required property var root
    required property var settings

    readonly property color foregroundColor: {
        if (root.isGamescope && (settings.themeIndex === 0 || settings.themeIndex === 1)) {
            return "white"
        } else {
            return Application.styleHints.colorScheme == Qt.Dark ? "white" : "dark"
        }
    }
    readonly property color frameColor: {
        if (root.isGamescope && settings.themeIndex === 0) {
            return Qt.rgba(1, 1, 1, 0.075)
        } else if (root.isGamescope && settings.themeIndex === 1) {
            return Qt.rgba(1, 1, 1, 0.15)
        } else {
            if (settings.themeIndex === 0) return Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.15)
            else return Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
        }
    }
}
