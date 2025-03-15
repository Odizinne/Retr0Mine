pragma Singleton
import QtQuick

QtObject {
    property bool savePopupVisible: false
    property bool loadPopupVisible: false
    property bool leaderboardPopupVisible: false
    property bool restorePopupVisible: false
    property bool aboutPopupVisible: false
    property bool rulesPopupVisible: false
    property bool privateSessionPopupVisible: false
    property bool multiplayerErrorPopupVisible: false
    property bool playerLeftPopupVisible: false
    property bool multiplayerChatVisible: false
    property bool settingsWindowVisible: false
    property int settingsIndex: 0

    property string mpErrorReason: ""

    signal allCellsReady()
}
