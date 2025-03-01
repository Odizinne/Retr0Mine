import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Item {
    opacity: GridBridge.cellsCreated === (GameState.gridSizeX * GameState.gridSizeY) ? 0 : 1
    // opacity: 0 instead of visible: false
    // allow constant window update (needed for steam overlay)
    Behavior on opacity {
        NumberAnimation {
            duration: 100
            easing.type: Easing.InOutQuad
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        BusyIndicator {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
        }

        Label {
            text: qsTr("Creating cells...")
            font.pixelSize: 18
            font.family: GameConstants.numberFont.name
            Layout.alignment: Qt.AlignCenter
        }
    }
}
