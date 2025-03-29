import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Odizinne.Retr0Mine

Item {
    opacity: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) ? 0 : 1
    Behavior on opacity {
        NumberAnimation {
            duration: 100
            easing.type: Easing.InOutQuad
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        Image {
            id: logo
            source: GameConstants.retr0mineLogo
            sourceSize.width: 756 * 0.35
            sourceSize.height: 110 * 0.35
            Layout.alignment: Qt.AlignCenter
            antialiasing: true
            mipmap: true
        }

        ProgressBar {
            Layout.preferredWidth: logo.sourceSize.width - 6
            Layout.alignment: Qt.AlignCenter
            from: 0
            to: (GameState.gridSizeX * GameState.gridSizeY)
            value: GridBridge.cellsCreated
        }
    }
}
