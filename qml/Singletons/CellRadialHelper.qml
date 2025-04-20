pragma Singleton

import QtQuick

QtObject {
    signal longPressDetected(int cellIndex, real globalX, real globalY, bool isFlagged, bool isQuestioned, bool isRevealed)
}
