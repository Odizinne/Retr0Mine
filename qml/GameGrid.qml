import QtQuick
import Odizinne.Retr0Mine

GridView {
    id: grid
    cellWidth: GameState.cellSize
    cellHeight: GameState.cellSize
    model: GameState.gridSizeX * GameState.gridSizeY
    interactive: false
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    property int generationAttempt

    Item {
        id: mouseTracker
        anchors.fill: parent
        z: 0

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton // Don't steal clicks

            onPositionChanged: (mouse) => {
                MouseTracker.globalMousePos = mapToGlobal(Qt.point(mouse.x, mouse.y))
                MouseTracker.isHovering = true
            }

            onExited: {
                MouseTracker.isHovering = false
            }
        }
    }

    GameAudio {
        id: audioEngine
        Component.onCompleted: {
            GridBridge.setAudioEngine(audioEngine)
        }
    }
}
