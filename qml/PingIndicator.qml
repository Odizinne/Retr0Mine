import QtQuick 2.15
import net.odizinne.retr0mine

Item {
    Component.onCompleted: {
        circle1Animation.start()
        circle2Timer.start()
        circle3Timer.start()
    }

    Timer {
        id: circle2Timer
        interval: 350
        repeat: false
        onTriggered: circle2Animation.start()
    }

    Timer {
        id: circle3Timer
        interval: 700
        repeat: false
        onTriggered: circle3Animation.start()
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
                to: 150
                duration: 1250
            }

            SequentialAnimation {
                PauseAnimation { duration: 625 }
                PropertyAnimation {
                    target: circle1
                    property: "opacity"
                    to: 0.0
                    duration: 625
                }
            }
        }
    }

    Rectangle {
        id: circle2
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
            id: circle2Animation

            PropertyAnimation {
                target: circle2
                property: "opacity"
                from: 0
                to: 0.7
                duration: 200
            }

            PropertyAnimation {
                target: circle2
                properties: "width,height"
                from: 10
                to: 150
                duration: 1250
            }

            SequentialAnimation {
                PauseAnimation { duration: 625 }
                PropertyAnimation {
                    target: circle2
                    property: "opacity"
                    to: 0.0
                    duration: 625
                }
            }
        }
    }

    Rectangle {
        id: circle3
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
            id: circle3Animation

            PropertyAnimation {
                target: circle3
                property: "opacity"
                from: 0
                to: 0.7
                duration: 200
            }

            PropertyAnimation {
                target: circle3
                properties: "width,height"
                from: 10
                to: 150
                duration: 1250
            }

            SequentialAnimation {
                PauseAnimation { duration: 625 }
                PropertyAnimation {
                    target: circle3
                    property: "opacity"
                    to: 0.0
                    duration: 625
                }
            }
        }
    }
}
