import QtQuick.Controls
import QtQuick

ToolTip {
    id: flagToast
    font.pixelSize: 18
    timeout: 3000
    x: Math.round((parent.width - width) / 2)
    y: parent.y + parent.height - height - 30
    property string notificationText

    contentItem: Item {
        Text {
            anchors.centerIn: parent
            text: flagToast.notificationText
            color: "#28d13c"
            font.pixelSize: 18
            font.bold: true
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 200 }
    }
}
