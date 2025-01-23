import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: aboutPage
    width: 230
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

        RowLayout {
            spacing: 10
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Steam"
                icon.source: "qrc:/icons/steam.png"
                highlighted: true
                onClicked: Qt.openUrlExternally("https://store.steampowered.com/app/3478030/Retr0Mine")
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Github"
                icon.source: "qrc:/icons/github.png"
                onClicked: Qt.openUrlExternally("https://github.com/odizinne/Retr0Mine")
            }
        }
    }
}
