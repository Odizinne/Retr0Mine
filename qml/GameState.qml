// GameState.qml
pragma Singleton
import QtQuick

QtObject {
    property bool gameOver: false
    property int revealedCount: 0
    property int flaggedCount: 0
    property int firstClickIndex: -1
    property bool gameStarted: false
    property int gridSizeX: 8
    property int gridSizeY: 8
    property int mineCount: 10
    property var mines: []
    property var numbers: []
    property int cellSize: {
        switch (Retr0MineSettings.cellSize) {
            case 0: return 35;
            case 1: return MainWindow.gamescope ? 43 : 45;
            case 2: return 55;
            default: return MainWindow.gamescope ? 43 : 45;
        }
    }
    property int cellSpacing: 2
    property int currentHintCount: 0
    property bool gridFullyInitialized: false
    property bool isManuallyLoaded: false
    property bool noAnimReset: false
    property bool blockAnim: true
    readonly property var difficultySettings: [
        { text: qsTr("Easy"), x: 9, y: 9, mines: 10 },
        { text: qsTr("Medium"), x: 16, y: 16, mines: 40 },
        { text: qsTr("Hard"), x: 30, y: 16, mines: 99 },
        { text: "Retr0", x: 50, y: 32, mines: 320 },
        { text: qsTr("Custom"), x: Retr0MineSettings.customWidth, y: Retr0MineSettings.customHeight, mines: Retr0MineSettings.customMines },
    ]
    property bool flag1Unlocked: SteamIntegration.unlockedFlag1
    property bool flag2Unlocked: SteamIntegration.unlockedFlag2
    property bool flag3Unlocked: SteamIntegration.unlockedFlag3
    property bool anim1Unlocked: SteamIntegration.unlockedAnim1
    property bool anim2Unlocked: SteamIntegration.unlockedAnim2
    readonly property string flagPath: {
        if (SteamIntegration.initialized && Retr0MineSettings.flagSkinIndex === 1) return "qrc:/icons/flag1.png"
        if (SteamIntegration.initialized && Retr0MineSettings.flagSkinIndex === 2) return "qrc:/icons/flag2.png"
        if (SteamIntegration.initialized && Retr0MineSettings.flagSkinIndex === 3) return "qrc:/icons/flag3.png"
        else return "qrc:/icons/flag.png"
    }
    signal gridSizeChanged()

    onGridSizeXChanged: gridSizeChanged()
    onGridSizeYChanged: gridSizeChanged()
}
