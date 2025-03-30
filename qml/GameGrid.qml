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
}
