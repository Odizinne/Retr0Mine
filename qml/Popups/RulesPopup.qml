pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

Popup {
    id: control
    width: 400
    height: 400
    modal: true
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    visible: ComponentsContext.rulesPopupVisible

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: ComponentsContext.rulesPopupVisible = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Label {
            text: qsTr("How to Play Minesweeper")
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "#28d13c"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn
            clip: true

            Flickable {
                contentWidth: rulesText.width
                contentHeight: rulesText.height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Text {
                    id: rulesText
                    width: control.width - 40
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                    lineHeight: 1.2
                    font.pixelSize: 14
                    color: GameConstants.foregroundColor
                    //text: qsTr("### Objective") + "\n" +
                    //      qsTr("Find all the mines on the board without detonating any of them.") + "\n\n" +
                    //      qsTr("### Basic Controls") + "\n" +
                    //      qsTr("**Classic Mode:**") + "\n" +
                    //      qsTr("- Left click: Reveal a cell") + "\n" +
                    //      qsTr("- Right click: Flag a suspected mine") + "\n\n" +
                    //      qsTr("**Chord Mode:**") + "\n" +
                    //      qsTr("- Left click: Flag a suspected mine") + "\n" +
                    //      qsTr("- Right click: Reveal a cell") + "\n" +
                    //      qsTr("- Click on a revealed number: Reveal adjacent cells if enough flags placed") + "\n\n" +
                    //      qsTr("### Game Elements") + "\n" +
                    //      qsTr("**Numbers:** When you reveal a cell, a number may appear. This indicates how many mines are adjacent to that cell (in the 8 surrounding cells).") + "\n" +
                    //      qsTr("**Blank Cell:** If you reveal a cell with no adjacent mines, it will be blank and automatically reveal adjacent cells.") + "\n" +
                    //      qsTr("**Flags:** Use flags to mark where you think mines are located.") + "\n" +
                    //      qsTr("**Question Marks:** Use question marks (if enabled) to mark cells you're uncertain about.") + "\n\n" +
                    //      qsTr("### Game Strategies") + "\n" +
                    //      qsTr("**Start in a corner or edge:** This gives you fewer adjacent cells to worry about initially.") + "\n" +
                    //      qsTr("**Use the numbers:** If a '1' cell has only one unrevealed adjacent cell, that cell must contain a mine.") + "\n" +
                    //      qsTr("**Use flagged mines:** Once a numbered cell has all its adjacent mines flagged, the remaining adjacent cells are safe.") + "\n" +
                    //      qsTr("**Chord technique:** Click on a number when you've flagged all its adjacent mines to reveal all other adjacent cells at once.") + "\n\n" +
                    //      qsTr("### Winning the Game") + "\n" +
                    //      qsTr("You win when all non-mine cells have been revealed. You don't have to flag all mines to win, just reveal all safe cells.")
                }
            }
        }

        Button {
            text: qsTr("Close")
            Layout.alignment: Qt.AlignRight
            Layout.bottomMargin: 10
            onClicked: ComponentsContext.rulesPopupVisible = false
        }
    }
}
