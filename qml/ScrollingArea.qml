import QtQuick.Controls
import QtQuick
import net.odizinne.retr0mine 1.0

ScrollView {
    ScrollBar.vertical: GameCore.isFluent ? fluentVerticalScrollBar : defaultVerticalScrollBar
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    TempScrollBar {
        id: fluentVerticalScrollBar
        enabled: parent.enabled
        opacity: parent.opacity
        orientation: Qt.Vertical
        anchors.right: parent.right
        anchors.rightMargin: -8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: policy === ScrollBar.AlwaysOn && GameCore.isFluent
        active: GameCore.isFluent
        policy: (parent.contentHeight > parent.height) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }

    ScrollBar {
        id: defaultVerticalScrollBar
        enabled: parent.enabled
        opacity: parent.opacity
        orientation: Qt.Vertical
        anchors.right: parent.right
        anchors.rightMargin: -8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: policy === ScrollBar.AlwaysOn && !GameCore.isFluent
        active: !GameCore.isFluent
        policy: (parent.contentHeight > parent.height) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }
}
