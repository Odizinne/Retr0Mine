pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Controls.impl
import QtQuick.Templates as T
import Odizinne.Retr0Mine

Popup {
    id: control
    width: 180
    height: 180
    modal: true
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    T.Overlay.modal: Rectangle {
        color: control.Universal.altMediumLowColor
    }

    T.Overlay.modeless: Rectangle {
        color: control.Universal.baseLowColor
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.5
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.8
                duration: 150
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 100
            }
        }
    }

    property int cellIndex: -1
    property bool isFlagged: false
    property bool isQuestioned: false
    property bool isRevealed: false

    property real innerRadius: 30
    property real outerRadius: width / 2 - 20

    background: Item { }

    contentItem: Item {
        anchors.fill: parent

        Repeater {
            model: 4

            Canvas {
                id: segmentCanvas
                anchors.fill: parent
                required property int index
                property int segmentIndex: index
                property bool isSelected: segmentIndex === menuMouseArea.hoveredSegment
                property bool isActive: (segmentIndex === 1 && control.isFlagged) ||
                                       (segmentIndex === 2 && control.isQuestioned)

                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Cooperative

                NumberAnimation on rotation {
                    from: -10
                    to: 0
                    duration: 200 + segmentCanvas.index * 30
                    running: control.visible
                    easing.type: Easing.OutBack
                }

                onIsSelectedChanged: requestPaint()
                onIsActiveChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    var centerX = width / 2
                    var centerY = height / 2

                    // Define angles for cardinal directions
                    var startAngle, endAngle

                    if (segmentIndex === 0) { // North
                        startAngle = -Math.PI / 4 - Math.PI / 2
                        endAngle = Math.PI / 4 - Math.PI / 2
                    } else if (segmentIndex === 1) { // East
                        startAngle = -Math.PI / 4
                        endAngle = Math.PI / 4
                    } else if (segmentIndex === 2) { // South
                        startAngle = -Math.PI / 4 + Math.PI / 2
                        endAngle = Math.PI / 4 + Math.PI / 2
                    } else { // West
                        startAngle = -Math.PI / 4 + Math.PI
                        endAngle = Math.PI / 4 + Math.PI
                    }

                    ctx.beginPath()
                    ctx.arc(centerX, centerY, control.outerRadius, startAngle, endAngle, false)
                    ctx.arc(centerX, centerY, control.innerRadius, endAngle, startAngle, true)
                    ctx.closePath()

                    if (isSelected) {
                        ctx.fillStyle = Constants.isDarkMode ? "#FF444444" : "#FFCCCCCC"
                    } else {
                        ctx.fillStyle = Constants.isDarkMode ? "#FF222222" : "#FFEEEEEE"
                    }
                    ctx.fill()

                    ctx.strokeStyle = Constants.foregroundColor
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }
        }

        Repeater {
            model: 4

            IconImage {
                id: icon
                required property int index

                property int segmentIndex: index
                property var iconSources: [
                    "qrc:/icons/reveal.png",
                    GameState.flagPath,
                    "qrc:/icons/questionmark.png",
                    "qrc:/icons/signal.png"
                ]

                // Cardinal positions for icons
                property real angle: {
                    if (index === 0) return -Math.PI / 2  // North
                    if (index === 1) return 0             // East
                    if (index === 2) return Math.PI / 2   // South
                    return Math.PI                        // West
                }

                property real iconRadius: (control.innerRadius + control.outerRadius) / 2
                x: (parent.width / 2) + iconRadius * Math.cos(angle) - width/2
                y: (parent.height / 2) + iconRadius * Math.sin(angle) - height/2

                source: iconSources[index]
                sourceSize.width: 20
                sourceSize.height: 20

                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: 250 + icon.index * 40
                    running: control.visible
                }

                color: {
                    if ((index === 1 && control.isFlagged) ||
                        (index === 2 && control.isQuestioned)) {
                        return Constants.accentColor
                    }

                    return Constants.foregroundColor
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }

                scale: menuMouseArea.hoveredSegment === segmentIndex ? 1.2 : 1.0
            }
        }

        MouseArea {
            id: menuMouseArea
            anchors.fill: parent
            hoverEnabled: true

            property int hoveredSegment: -1

            onPositionChanged: {
                var centerX = width / 2
                var centerY = height / 2
                var dx = mouseX - centerX
                var dy = mouseY - centerY
                var distance = Math.sqrt(dx * dx + dy * dy)

                if (distance <= control.outerRadius && distance >= control.innerRadius) {
                    var angle = Math.atan2(dy, dx)

                    // Convert angle to segment index based on cardinal directions
                    var segment
                    if (angle > -Math.PI/4 && angle <= Math.PI/4) {
                        segment = 1 // East
                    } else if (angle > Math.PI/4 && angle <= 3*Math.PI/4) {
                        segment = 2 // South
                    } else if (angle > 3*Math.PI/4 || angle <= -3*Math.PI/4) {
                        segment = 3 // West
                    } else {
                        segment = 0 // North
                    }

                    if (segment !== hoveredSegment) {
                        hoveredSegment = segment
                    }
                } else {
                    if (hoveredSegment !== -1) {
                        hoveredSegment = -1
                    }
                }
            }

            onExited: {
                hoveredSegment = -1
            }

            onClicked: {
                var centerX = width / 2
                var centerY = height / 2
                var dx = mouseX - centerX
                var dy = mouseY - centerY
                var distance = Math.sqrt(dx * dx + dy * dy)

                if (distance <= control.outerRadius && distance >= control.innerRadius && hoveredSegment >= 0) {
                    var action = ["reveal", "flag", "question", "signal"][hoveredSegment]
                    control.executeAction(action)
                    control.close()
                } else if (distance < control.innerRadius) {
                    control.close()
                }
            }
        }
    }

    function executeAction(action) {
        if (cellIndex < 0) return

        switch(action) {
            case "reveal":
                GridBridge.reveal(cellIndex, SteamIntegration.playerName)
                break
            case "flag":
                GridBridge.setFlag(cellIndex)
                break
            case "question":
                GridBridge.setQuestioned(cellIndex)
                break
            case "signal":
                NetworkManager.sendPing(cellIndex)
                break
        }
    }
}
