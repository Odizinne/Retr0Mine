pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import net.odizinne.retr0mine 1.0

AnimatedPopup {
    id: control
    width: 400
    height: 400
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    visible: ComponentsContext.rulesPopupVisible

    Shortcut {
        sequence: "Esc"
        enabled: control.visible
        onActivated: ComponentsContext.rulesPopupVisible = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 6
        anchors.leftMargin: 6
        spacing: 18

        Label {
            text: qsTr("How to Play Minesweeper")
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "#28d13c"
        }

        ScrollingArea {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width - 12
            contentHeight: textContainer.height

            Item {
                id: textContainer
                anchors.centerIn: parent
                width: scrollArea.width - 12
                height: rulesText.height

                Text {
                    id: rulesText
                    anchors.centerIn: parent
                    width: textContainer.width
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    lineHeight: 1.2
                    font.pixelSize: 14
                    color: GameConstants.foregroundColor
                    text: qsTr(`<h2>Objective</h2>
<p>Find all the mines on the board without detonating any of them.</p>
<h3>Game Elements</h3>
<p><b>• Numbers:</b> When you reveal a cell, a number may appear. This indicates how many mines are adjacent to that cell (in the 8 surrounding cells).
<br><b>• Blank Cell:</b> If you reveal a cell with no adjacent mines, it will be blank and automatically reveal adjacent cells.
<br><b>• Flags:</b> Use flags to mark where you think mines are located.
<br><b>• Question Marks:</b> Use question marks (if enabled) to mark cells you're uncertain about.</p>
<h3>Game Strategies</h3>
<p><b>• Use the numbers:</b> If a '1' cell has only one unrevealed adjacent cell, that cell must contain a mine.
<br><b>• Use flagged mines:</b> Once a numbered cell has all its adjacent mines flagged, the remaining adjacent cells are safe.</p>
<h3>When You're Stuck</h3>
<p><b>• Try a different area:</b> If you're stuck in one area of the grid, move to another section where you might find new clues.
<br><b>• Look for new patterns:</b> Sometimes taking a fresh look at the board can reveal patterns you didn't notice before.
<br><b>• Use probability:</b> In some cases, you may need to make an educated guess based on the information available.</p>
<h3>Winning the Game</h3>
<p>You win when all non-mine cells have been revealed. You don't have to flag all mines to win, just reveal all safe cells.</p>
<p>Have fun and good luck finding those mines!</p>`)
                }
            }
        }

        NfButton {
            text: qsTr("Close")
            Layout.alignment: Qt.AlignRight
            Layout.bottomMargin: 10
            onClicked: ComponentsContext.rulesPopupVisible = false
        }
    }
}
