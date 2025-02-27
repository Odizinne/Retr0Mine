import QtQuick
import net.odizinne.retr0mine 1.0

GridView {
    id: grid
    anchors.centerIn: parent
    cellWidth: GameState.cellSize + GameState.cellSpacing
    cellHeight: GameState.cellSize + GameState.cellSpacing
    width: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX
    height: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY
    model: GameState.gridSizeX * GameState.gridSizeY
    interactive: false
    property bool initialAnimationPlayed: false
    property int cellsCreated: 0
    property int generationAttempt

    GameAudio {
        id: audioEngine
        Component.onCompleted: {
            GridBridge.setAudioEngine(audioEngine)
        }
    }
}
