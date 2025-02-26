import QtQuick.Controls
import net.odizinne.retr0mine 1.0

ScrollView {
    id: control
    contentWidth: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX, control.width)
    contentHeight: Math.max((GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY, control.height)

    ScrollBar {
        id: defaultVerticalScrollBar
        parent: control
        orientation: Qt.Vertical
        x: parent.width - width + 12
        y: 0
        height: control.height
        visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
        active: !GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > control.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    ScrollBar {
        id: defaultHorizontalScrollBar
        parent: control
        orientation: Qt.Horizontal
        x: 0
        y: parent.height - height + 12
        width: control.width
        visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
        active: !GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > control.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    TempScrollBar {
        id: fluentVerticalScrollBar
        parent: control
        orientation: Qt.Vertical
        x: parent.width - width + 12
        y: 0
        height: control.height
        visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
        active: GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > control.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    TempScrollBar {
        id: fluentHorizontalScrollBar
        parent: control
        orientation: Qt.Horizontal
        x: 0
        y: parent.height - height + 12
        width: control.width
        visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
        active: GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > control.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    ScrollBar.vertical: GameCore.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
    ScrollBar.horizontal: GameCore.isFluent ? fluentHorizontalScrollBar : defaultHorizontalScrollBar
}
