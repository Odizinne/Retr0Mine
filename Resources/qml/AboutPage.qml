import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: aboutPage
    width: 180
    height: 230
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height
    title: qsTr("About")
    flags: Qt.Dialog

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/icons/icon.png"
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Retr0Mine"
            font.pixelSize: 24
            font.bold: true
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("by Odizinne")
            font.pixelSize: 14
        }

        Item {
            Layout.fillHeight: true
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: "Check on Github"
            highlighted: true
            onClicked: Qt.openUrlExternally("https://github.com/odizinne/Retr0Mine")
        }
    }
}
