import QtQuick
import Odizinne.Retr0Mine

Item {
    opacity: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) ? 0 : 1
    visible: opacity !== 0
    Behavior on opacity {
        NumberAnimation {
            duration: 100
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        anchors.centerIn: parent
        width: sourceSize.width * 0.35
        height: sourceSize.height * 0.35

        property var sourceSize: Qt.size(756, 110)

        ImageProgressBar {
            anchors.fill: parent
            from: 0
            to: (GameState.gridSizeX * GameState.gridSizeY)
            value: GridBridge.cellsCreated
        }
    }
}
