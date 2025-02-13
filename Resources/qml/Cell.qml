import QtQuick

Item {
    id: root
    
    property bool revealed: false
    property bool flagged: false
    property bool questioned: false
    property bool safeQuestioned: false
    property bool isBombClicked: false
    property bool animatingReveal: false
    property bool shouldBeFlat: false
    property int row: 0
    property int col: 0
    property int diagonalSum: row + col

    function highlightHint() {
        hintAnimation.start();
    }
}
