import QtQuick 2.15

Item {
    // Start the animation sequence when component completes
    Component.onCompleted: {
        // Start the first circle animation immediately
        circle1Animation.start()

        // Start second circle after 1 second delay
        circle2Timer.start()

        // Start third circle after 2 seconds delay
        circle3Timer.start()
    }

    // Timer for second circle animation
    Timer {
        id: circle2Timer
        interval: 500
        repeat: false
        onTriggered: circle2Animation.start()
    }

    // Timer for third circle animation
    Timer {
        id: circle3Timer
        interval: 1000
        repeat: false
        onTriggered: circle3Animation.start()
    }

    // First circle
    Rectangle {
        id: circle1
        z: 999
        opacity: 0

        // Initial size
        width: 10
        height: 10

        // Center the circle in its parent
        anchors.centerIn: parent

        radius: width / 2  // Make sure it stays circular as it grows
        border.width: 3
        border.color: "red"
        color: "transparent"

        // Animation sequence for first circle
        ParallelAnimation {
            id: circle1Animation

            // Fade in
            PropertyAnimation {
                target: circle1
                property: "opacity"
                from: 0
                to: 1.0
                duration: 200
            }

            // Expand the circle
            PropertyAnimation {
                target: circle1
                properties: "width,height"
                from: 10
                to: 100  // 5x the original size
                duration: 1500
            }

            // Fade out before expansion completes
            SequentialAnimation {
                PauseAnimation { duration: 750 }  // Wait half of the expansion time
                PropertyAnimation {
                    target: circle1
                    property: "opacity"
                    to: 0.0
                    duration: 750  // Take the remaining time to fade out
                }
            }
        }
    }

    // Second circle
    Rectangle {
        id: circle2
        z: 999
        opacity: 0

        // Initial size
        width: 10
        height: 10

        // Center the circle in its parent
        anchors.centerIn: parent

        radius: width / 2  // Make sure it stays circular as it grows
        border.width: 3
        border.color: "red"
        color: "transparent"

        // Animation sequence for second circle
        ParallelAnimation {
            id: circle2Animation

            // Fade in
            PropertyAnimation {
                target: circle2
                property: "opacity"
                from: 0
                to: 1.0
                duration: 200
            }

            // Expand the circle
            PropertyAnimation {
                target: circle2
                properties: "width,height"
                from: 10
                to: 100  // 5x the original size
                duration: 1500
            }

            // Fade out before expansion completes
            SequentialAnimation {
                PauseAnimation { duration: 750 }  // Wait half of the expansion time
                PropertyAnimation {
                    target: circle2
                    property: "opacity"
                    to: 0.0
                    duration: 750  // Take the remaining time to fade out
                }
            }
        }
    }

    // Third circle
    Rectangle {
        id: circle3
        z: 999
        opacity: 0

        // Initial size
        width: 10
        height: 10

        // Center the circle in its parent
        anchors.centerIn: parent

        radius: width / 2  // Make sure it stays circular as it grows
        border.width: 3
        border.color: "red"
        color: "transparent"

        // Animation sequence for third circle
        ParallelAnimation {
            id: circle3Animation

            // Fade in
            PropertyAnimation {
                target: circle3
                property: "opacity"
                from: 0
                to: 1.0
                duration: 200
            }

            // Expand the circle
            PropertyAnimation {
                target: circle3
                properties: "width,height"
                from: 10
                to: 100  // 5x the original size
                duration: 1500
            }

            // Fade out before expansion completes
            SequentialAnimation {
                PauseAnimation { duration: 750 }  // Wait half of the expansion time
                PropertyAnimation {
                    target: circle3
                    property: "opacity"
                    to: 0.0
                    duration: 750  // Take the remaining time to fade out
                }
            }
        }
    }
}
