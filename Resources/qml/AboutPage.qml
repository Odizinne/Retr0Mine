import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: aboutPage
    //width: 250
    //height: 230
    anchors.centerIn: parent
    modal: true

    ColumnLayout {
        anchors.centerIn: parent
        anchors.margins: 6
        spacing: 10

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/icons/icon.png"
            sourceSize.height: 64
            sourceSize.width: 64
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
                //Layout.alignment: Qt.AlignHCenter
                text: "Steam"
                icon.source: "qrc:/icons/steam.png"
                highlighted: true
                onClicked: Qt.openUrlExternally("https://store.steampowered.com/app/3478030/Retr0Mine")
            }

            Button {
                //Layout.alignment: Qt.AlignHCenter
                text: "Github"
                icon.source: "qrc:/icons/github.png"
                onClicked: Qt.openUrlExternally("https://github.com/odizinne/Retr0Mine")
            }
        }
    }
}
