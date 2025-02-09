import QtQuick.Controls.Fusion
import QtQuick

ScrollView {
    property Component defaultVerticalScrollBar: ScrollBar {
        parent: parent
        x: parent.width - width + 12
        y: 0
        height: parent.height
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > parent.height ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }
    property Component defaultHorizontalScrollBar: ScrollBar {
        parent: parent
        x: 0
        y: parent.height - height + 12
        width: parent.width
        active: true
        policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > parent.width ?
                    ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        orientation: Qt.Horizontal
    }

    ScrollBar.vertical: defaultVerticalScrollBar.createObject(parent)
    ScrollBar.horizontal: defaultHorizontalScrollBar.createObject(parent)
}
