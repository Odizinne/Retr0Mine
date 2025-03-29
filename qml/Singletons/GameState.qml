pragma Singleton
import QtQuick
import Odizinne.Retr0Mine

QtObject {
    property bool gameOver: false
    property int revealedCount: 0
    property int flaggedCount: 0
    property int firstClickIndex: -1
    property bool gameStarted: false
    property int gridSizeX: 9
    property int gridSizeY: 9
    property int mineCount: 10
    property var mines: []
    property var numbers: []
    property int cellSize: GameCore.gamescope ? 43 : 45
    property bool bypassAutoSave: false
    property bool isGeneratingGrid: false
    property int cellSpacing: 2
    property int currentHintCount: 0
    property bool isManuallyLoaded: false
    property bool firstRun: true
    property bool noAnimReset: false
    property bool blockAnim: true
    readonly property var difficultySettings: [
        { text: qsTr("Easy"), x: 9, y: 9, mines: 10 },
        { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
        { text: qsTr("Hard"), x: 30, y: 16, mines: 99 },
        { text: "Retr0", x: 50, y: 32, mines: 320 },
        { text: qsTr("Custom"), x: GameSettings.customWidth, y: GameSettings.customHeight, mines: GameSettings.customMines },
    ]
    property bool flag1Unlocked: SteamIntegration.unlockedFlag1
    property bool flag2Unlocked: SteamIntegration.unlockedFlag2
    property bool flag3Unlocked: SteamIntegration.unlockedFlag3
    property bool anim1Unlocked: SteamIntegration.unlockedAnim1
    property bool anim2Unlocked: SteamIntegration.unlockedAnim2
    readonly property string flagPath: {
        if (SteamIntegration.initialized && GameSettings.flagSkinIndex === 1) return "qrc:/icons/flag1.png"
        if (SteamIntegration.initialized && GameSettings.flagSkinIndex === 2) return "qrc:/icons/flag2.png"
        if (SteamIntegration.initialized && GameSettings.flagSkinIndex === 3) return "qrc:/icons/flag3.png"
        else return "qrc:/icons/flag.png"
    }

    function getDifficultyLevel() {
        if (GameState.gridSizeX === 9 && GameState.gridSizeY === 9 && GameState.mineCount === 10) {
            return 'easy'
        } else if (GameState.gridSizeX === 16 && GameState.gridSizeY === 16 && GameState.mineCount === 40) {
            return 'medium'
        } else if (GameState.gridSizeX === 30 && GameState.gridSizeY === 16 && GameState.mineCount === 99) {
            return 'hard'
        } else if (GameState.gridSizeX === 50 && GameState.gridSizeY === 32 && GameState.mineCount === 320) {
            return 'retr0'
        }
        return null
    }

    property bool gameWon: false
    property string postgameText: gameWon ? qsTr("Victory") : qsTr("Game over")
    property string postgameColor: gameWon ? "#28d13c" : "#d12844"
    property string notificationText: ""
    property bool displayNotification: false
    property bool displayNewRecord: false
    property bool displayPostGame: false
    property bool difficultyChanged: false
    property bool paused: false
    property bool nextClickIsSignal: false
    property bool ignoreInternalGameState: false
    property string bombClickedBy: ""
    property int hostRevealed: 0
    property int clientRevealed: 0
    property int firstClickRevealed: 0
    signal botMessageSent()

    onPausedChanged: {
        if (paused) GameTimer.pause()
        else GameTimer.resume()
    }
}
