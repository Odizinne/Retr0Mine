import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

IconImage {
    id: control
    property string tooltipText: ""
    property int tooltipDelay: 500
    property string iconColor: "#f6ae57"
    source: "qrc:/icons/info.png"
    color: iconColor
    sourceSize.height: 18
    sourceSize.width: 18
    mipmap: true
    ToolTip {
        visible: mouseArea.containsMouse
        text: control.tooltipText
        delay: control.tooltipDelay
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
