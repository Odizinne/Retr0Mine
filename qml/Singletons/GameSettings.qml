pragma Singleton
import QtCore
import QtQuick
import net.odizinne.retr0mine 1.0

Settings {
    property bool startFullScreen: GameCore.gamescope
    property int themeIndex: 0
    property int languageIndex: 0
    property int difficulty: 0
    property bool invertLRClick: false
    property bool autoreveal: true
    property bool enableQuestionMarks: true
    property bool enableSafeQuestionMarks: false
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
    property int flagSkinIndex: 0
    property int colorSchemeIndex: 0
    property int gridResetAnimationIndex: 0
    property int fontIndex: 0
    property real satisfiedOpacity: 0.50
    property bool displayTimer: true
    property bool safeFirstClick: true
    property int pingColorIndex: 0
    property bool mpPlayerColoredFlags: true
    property int localFlagColorIndex: 4
    property int remoteFlagColorIndex: 1
    property bool mpShowInviteNotificationInGame: true
    property bool mpAudioNotificationOnNewMessage: true
    property bool shakeUnifinishedNumbers: true
    property bool hintReasoningInChat: true
    property real remoteVolume: 0.7
    property bool systemAccent: false

    property bool welcomeMessageShown: false
}

