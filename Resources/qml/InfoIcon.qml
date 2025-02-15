import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

IconImage {
    id: root
    property string tooltipText: ""
    property int tooltipDelay: 500
    property string iconColor: "#e6ae17"
    source: "qrc:/icons/info.png"
    color: root.iconColor
    sourceSize.height: 18
    sourceSize.width: 18
    mipmap: true
    ToolTip {
        visible: mouseArea.containsMouse
        text: root.tooltipText
        delay: root.tooltipDelay
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
