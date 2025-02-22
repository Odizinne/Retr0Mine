pragma Singleton
import QtCore
import QtQuick

Settings {
    property bool startFullScreen: GameCore.gamescope
    property int themeIndex: 0
    property int languageIndex: 0
    property int difficulty: 0
    property bool invertLRClick: false
    property bool autoreveal: false
    property bool enableQuestionMarks: true
    property bool enableSafeQuestionMarks: true
    property bool loadLastGame: false
    property bool soundEffects: true
    property real volume: 1.0
    property int soundPackIndex: 2
    property bool animations: true
    property bool cellFrame: true
    property bool contrastFlag: true
    property int cellSize: 1
    property int customWidth: 8
    property int customHeight: 8
    property int customMines: 10
    property bool dimSatisfied: false
    property int colorBlindness: 0
    property bool welcomeMessageShown: false
    property int flagSkinIndex: 0
    property int colorSchemeIndex: 0
    property int gridResetAnimationIndex: 0
    property int fontIndex: 0
}

