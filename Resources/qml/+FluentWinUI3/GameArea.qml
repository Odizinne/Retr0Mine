import QtQuick.Controls.FluentWinUI3
import QtQuick

ScrollView {
    property Component fluentVerticalScrollBar: TempScrollBar {
        parent: parent
        x: parent.width - width + 12
        y: 0
        height: parent.height
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > parent.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    property Component fluentHorizontalScrollBar: TempScrollBar {
        parent: parent
        x: 0
        y: parent.height - height + 12
        width: parent.width
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > parent.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        orientation: Qt.Horizontal
    }

    ScrollBar.vertical: fluentVerticalScrollBar.createObject(parent)
    ScrollBar.horizontal: fluentHorizontalScrollBar.createObject(parent)
}
