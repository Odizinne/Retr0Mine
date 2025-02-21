pragma Singleton
import QtCore
import QtQuick

Item {
    id: root
    property var mainWindow: null

    Settings {
        id: settingsStorage
        property bool startFullScreen: false
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

    property alias startFullScreen: settingsStorage.startFullScreen
    property alias themeIndex: settingsStorage.themeIndex
    property alias languageIndex: settingsStorage.languageIndex
    property alias difficulty: settingsStorage.difficulty
    property alias invertLRClick: settingsStorage.invertLRClick
    property alias autoreveal: settingsStorage.autoreveal
    property alias enableQuestionMarks: settingsStorage.enableQuestionMarks
    property alias enableSafeQuestionMarks: settingsStorage.enableSafeQuestionMarks
    property alias loadLastGame: settingsStorage.loadLastGame
    property alias soundEffects: settingsStorage.soundEffects
    property alias volume: settingsStorage.volume
    property alias soundPackIndex: settingsStorage.soundPackIndex
    property alias animations: settingsStorage.animations
    property alias cellFrame: settingsStorage.cellFrame
    property alias contrastFlag: settingsStorage.contrastFlag
    property alias cellSize: settingsStorage.cellSize
    property alias customWidth: settingsStorage.customWidth
    property alias customHeight: settingsStorage.customHeight
    property alias customMines: settingsStorage.customMines
    property alias dimSatisfied: settingsStorage.dimSatisfied
    property alias colorBlindness: settingsStorage.colorBlindness
    property alias welcomeMessageShown: settingsStorage.welcomeMessageShown
    property alias flagSkinIndex: settingsStorage.flagSkinIndex
    property alias colorSchemeIndex: settingsStorage.colorSchemeIndex
    property alias gridResetAnimationIndex: settingsStorage.gridResetAnimationIndex
    property alias fontIndex: settingsStorage.fontIndex

    Component.onCompleted: {
        if (mainWindow && mainWindow.gamescope) {
            startFullScreen = true
        }
    }
}
