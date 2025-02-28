pragma Singleton
import QtQuick

QtObject {
    property bool savePopupVisible: false
    property bool loadPopupVisible: false
    property bool leaderboardPopupVisible: false
    property bool restorePopupVisible: false
    property bool aboutPopupVisible: false
    property bool rulesPopupVisible: false
    property bool settingsWindowVisible: false

    signal allCellsReady()
}
