import QtQuick.Controls
import QtQuick
import net.odizinne.retr0mine 1.0

Flickable {
    id: control

    ScrollBar {
        id: defaultVerticalScrollBar
        parent: control
        orientation: Qt.Vertical
        visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
        active: !GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > control.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    ScrollBar {
        id: defaultHorizontalScrollBar
        parent: control
        visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
        active: !GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > control.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    TempScrollBar {
        id: fluentVerticalScrollBar
        parent: control
        visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
        active: GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeY > control.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    TempScrollBar {
        id: fluentHorizontalScrollBar
        parent: control
        visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
        active: GameCore.isFluent
        policy: (GameState.cellSize + GameState.cellSpacing) * GameState.gridSizeX > control.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    ScrollBar.vertical: GameCore.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
    ScrollBar.horizontal: GameCore.isFluent ? fluentHorizontalScrollBar : defaultHorizontalScrollBar
}
