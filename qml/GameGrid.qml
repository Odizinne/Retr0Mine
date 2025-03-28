import QtQuick
import net.odizinne.retr0mine 1.0

GridView {
    id: grid
    cellWidth: GameState.cellSize
    cellHeight: GameState.cellSize
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
