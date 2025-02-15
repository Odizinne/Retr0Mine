import QtQuick.Controls

ApplicationWindow {
    title: "Retr0Mine"


    BusyIndicator {
        // stupid, but allow continuous engine update without too much hassle (needed for steam overlay)
        opacity: 0
    }
}
