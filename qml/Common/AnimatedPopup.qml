import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: control
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; easing.type: Easing.Linear; duration: 83 }
        NumberAnimation { property: "scale"; from: control.modal ? 1.05 : 1; to: 1; easing.type: Easing.OutCubic; duration: 167 }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; easing.type: Easing.Linear; duration: 83 }
        NumberAnimation { property: "scale"; from: 1; to: control.modal ? 1.05 : 1; easing.type: Easing.OutCubic; duration: 167 }
    }
}
