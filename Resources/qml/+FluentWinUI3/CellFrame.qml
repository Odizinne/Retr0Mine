import QtQuick

Rectangle {
    radius: 4
    border.color: Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.15)
}
