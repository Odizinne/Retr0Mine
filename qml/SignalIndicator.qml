import QtQuick 2.15
import net.odizinne.retr0mine

Item {
    Component.onCompleted: {
        circle1Animation.start()
    }

    Rectangle {
        id: circle1
        z: 999
        opacity: 0
        width: 10
        height: 10
        anchors.centerIn: parent
        radius: width / 2
        border.width: 4
        border.color: GameConstants.pingColor
        color: "transparent"

        ParallelAnimation {
            id: circle1Animation

            PropertyAnimation {
                target: circle1
                property: "opacity"
                from: 0
                to: 0.7
                duration: 200
            }

            PropertyAnimation {
                target: circle1
                properties: "width,height"
                from: 10
                to: GameState.cellSize * 3
                duration: 500
            }

            SequentialAnimation {
                PauseAnimation { duration: 250 }
                PropertyAnimation {
                    target: circle1
                    property: "opacity"
                    to: 0.0
                    duration: 250
                }
            }
        }
    }
}
