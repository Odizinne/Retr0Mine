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
        width: logo.sourceSize.width + 50
        height: width

        CircularProgressBar {
            anchors.fill: parent
            from: 0
            to: (GameState.gridSizeX * GameState.gridSizeY)
            value: GridBridge.cellsCreated
        }

        Image {
            id: logo
            anchors.centerIn: parent
            source: Constants.retr0mineLogo
            sourceSize.width: 756 * 0.25
            sourceSize.height: 110 * 0.25
            antialiasing: true
            mipmap: true
        }
    }
}
