import QtQuick.Controls

ScrollView {
    required property var root
    ScrollBar.vertical.policy: (root.cellSize + root.cellSpacing) * root.gridSizeY > parent.height ?
                                   ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    ScrollBar.horizontal.policy: (root.cellSize + root.cellSpacing) * root.gridSizeX > parent.width ?
                                     ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
}
