import QtQuick
import QtQuick.Layouts
import net.odizinne.retr0mine

AnimatedPopup {
    id: control
    width: lyt.implicitWidth + 40
    height: lyt.implicitHeight + 40
    modal: true
    visible: ComponentsContext.aboutPopupVisible
    property int buttonWidth: Math.max(steamButton.implicitWidth, githubButton.implicitHeight) + 20
    onVisibleChanged: {
        if (!visible) {
            ComponentsContext.aboutPopupVisible = false
        }
    }

    ColumnLayout {
        id: lyt
        anchors.fill: parent
        anchors.margins: 10
        spacing: 20

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: GameConstants.retr0mineLogo
            sourceSize.width: 756 * 0.35
            sourceSize.height: 110 * 0.35
        }

        RowLayout {
            spacing: 20
            NfButton {
                id: steamButton
                text: "Steam"
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                icon.width: 16
                icon.height: 16
                icon.source: "qrc:/icons/steam.png"
                highlighted: true
                onClicked: Qt.openUrlExternally("https://store.steampowered.com/app/3478030/Retr0Mine")
            }

            NfButton {
                id: githubButton
                text: "Github"
                Layout.preferredWidth: control.buttonWidth
                Layout.fillWidth: true
                icon.width: 16
                icon.height: 16
                icon.source: "qrc:/icons/github.png"
                onClicked: Qt.openUrlExternally("https://github.com/odizinne/Retr0Mine")
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: ComponentsContext.aboutPopupVisible = false
    }
}
