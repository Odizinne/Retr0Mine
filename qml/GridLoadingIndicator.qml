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
        spacing: 20

        Label {
            id: loadingLabel
            text: qsTr("Creating cells...")
            font.pixelSize: 18
            font.family: GameConstants.numberFont.name
            Layout.alignment: Qt.AlignCenter
        }

        ProgressBar {
            Layout.preferredWidth: loadingLabel.width
            Layout.alignment: Qt.AlignCenter
            from: 0
            to: (GameState.gridSizeX * GameState.gridSizeY)
            value: GridBridge.cellsCreated
        }
    }
}
