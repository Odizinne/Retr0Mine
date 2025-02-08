import QtQuick.Controls.Fusion

ScrollView {
    ScrollBar.vertical: defaultVerticalScrollBar.createObject(scrollView)
    ScrollBar.horizontal: defaultHorizontalScrollBar.createObject(scrollView)
}