pragma Singleton
import QtQuick

QtObject {
    property point globalMousePos: Qt.point(0, 0)
    property bool isHovering: false

    // Radius of effect in pixels
    property real effectRadius: GameState.cellSize * 2

    // Color for the hover effect
    property color hoverColor: GameConstants.accentColor
}
