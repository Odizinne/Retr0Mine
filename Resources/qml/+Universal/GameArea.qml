import QtQuick.Controls.Universal

ScrollView {
    ScrollBar.vertical: defaultVerticalScrollBar.createObject(scrollView)
    ScrollBar.horizontal: defaultHorizontalScrollBar.createObject(scrollView)
}