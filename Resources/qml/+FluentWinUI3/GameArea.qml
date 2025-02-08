import QtQuick.Controls.FluentWinUI3

ScrollView {
    ScrollBar.vertical: fluentVerticalScrollBar.createObject(scrollView)
    ScrollBar.horizontal: fluentHorizontalScrollBar.createObject(scrollView)
}