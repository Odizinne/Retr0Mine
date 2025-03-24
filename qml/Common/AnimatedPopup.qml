import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: fadePopup

    // Set default properties
    width: 300
    height: 200
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Center in parent
    anchors.centerIn: parent

    // Background
    background: Rectangle {
        color: "white"
        border.color: "gray"
        border.width: 1
        radius: 5
    }

    // Content - customize as needed
    contentItem: Text {
        text: "Popup Content"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Initial opacity state
    opacity: 0

    // Handle visibility changes
    onVisibleChanged: {
        if (visible) {
            fadeInAnimation.start()
        } else {
            fadeOutAnimation.start()
        }
    }

    // Separate animations for fade in and fade out
    NumberAnimation {
        id: fadeInAnimation
        target: fadePopup
        property: "opacity"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: fadeOutAnimation
        target: fadePopup
        property: "opacity"
        from: 1
        to: 0
        duration: 200
        easing.type: Easing.InOutQuad
    }

    // Override the open function to ensure proper state
    function open() {
        opacity = 0
        visible = true
        // The onVisibleChanged will trigger the fadeInAnimation
    }

    // Override the close function to allow animation completion
    function close() {
        fadeOutAnimation.start()
        fadeOutAnimation.finished.connect(function() {
            visible = false
            fadeOutAnimation.finished.disconnect(arguments.callee)
        })
    }
}
