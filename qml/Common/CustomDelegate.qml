import QtQuick.Controls.Universal
import QtQuick

ItemDelegate {
    id: del
    property bool isCurrentItem: false
    background: Rectangle {
        visible: enabled && (del.down || del.highlighted || del.visualFocus || del.hovered || del.isCurrentItem)
        color: del.down ? del.Universal.listMediumColor :
               del.hovered || del.isCurrentItem ? del.Universal.listLowColor : del.Universal.altMediumLowColor
        Rectangle {
            width: parent.width
            height: parent.height
            visible: del.visualFocus || del.highlighted
            color: del.Universal.accent
            opacity: del.Universal.theme === Universal.Light ? 0.4 : 0.6
        }
    }
}
