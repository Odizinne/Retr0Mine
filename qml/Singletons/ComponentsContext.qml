pragma Singleton
import QtQuick

QtObject {
    property bool savePopupVisible: false
    property bool loadPopupVisible: false
    property bool leaderboardPopupVisible: false
    property bool restorePopupVisible: false
    property bool aboutPopupVisible: false
    property bool rulesPopupVisible: false
    property bool multiplayerPopupVisible: false
    property bool multiplayerErrorPopupVisible: false
    property bool multiplayerChatVisible: false
    property bool settingsWindowVisible: false

    property string mpErrorReason: ""
    signal allCellsReady()
}
