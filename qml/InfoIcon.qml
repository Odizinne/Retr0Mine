import QtQuick
import QtQuick.Controls.Universal
import QtQuick.Controls.impl
import Odizinne.Retr0Mine

IconImage {
    id: control
    property string tooltipText: ""
    property int tooltipDelay: 500
    property color iconColor: Constants.warningColor
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
