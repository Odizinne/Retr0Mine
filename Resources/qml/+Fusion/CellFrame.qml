import QtQuick

Rectangle {
    radius: 3
    border.color: Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
}
