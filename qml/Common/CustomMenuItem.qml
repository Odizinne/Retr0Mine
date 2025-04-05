import QtQuick.Controls.Universal
import QtQuick

MenuItem {
    id: control
    height: implicitHeight
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 40

        color: !control.enabled ? control.Universal.altMediumLowColor :
                control.down ? control.Universal.listMediumColor :
                control.highlighted ? control.Universal.listLowColor : control.Universal.altMediumLowColor

        Rectangle {
            x: 1; y: 1
            width: parent.width - 2
            height: parent.height - 2

            visible: control.visualFocus
            color: control.Universal.accent
            opacity: control.Universal.theme === Universal.Light ? 0.4 : 0.6
        }
    }
}
