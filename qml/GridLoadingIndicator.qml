import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

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
            source: "qrc:/images/retr0mine_logo.png"
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
