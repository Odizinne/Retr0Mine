import QtQuick.Controls.Universal
import QtQuick

ScrollView {
    ScrollBar.vertical: defaultVerticalScrollBar
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    ScrollBar {
        id: defaultVerticalScrollBar
        enabled: parent.enabled
        opacity: parent.opacity
        orientation: Qt.Vertical
        anchors.right: parent.right
        anchors.rightMargin: -8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: policy === ScrollBar.AlwaysOn
        active: true
        policy: (parent.contentHeight > parent.height) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    }
}
