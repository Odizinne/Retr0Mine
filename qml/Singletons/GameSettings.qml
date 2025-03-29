pragma Singleton
import QtCore
import QtQuick
import Odizinne.Retr0Mine

Settings {
    /*==========================================
     | Accessibility                           |
     ==========================================*/
    property int colorBlindness: 0
    property bool contrastFlag: false
    property real gridScale: 1

    /*==========================================
     | Advanced                                |
     ==========================================*/
    property int colorSchemeIndex: 1
    property int accentColorIndex: 2
    property int renderingBackend: 0
    property bool customTitlebar: true
    property bool customCursor: true

    /*==========================================
     | Difficulty                              |
     ==========================================*/
    property int difficulty: 0
    property int customWidth: 8
    property int customHeight: 8
    property int customMines: 10

    /*==========================================
     | Gameplay                                |
     ==========================================*/
    property bool hintReasoningInChat: true
    property bool safeFirstClick: true
    property bool loadLastGame: false
    property bool invertLRClick: false
    property bool autoreveal: true
    property bool enableQuestionMarks: true
    property bool enableSafeQuestionMarks: false

    /*==========================================
     | Language                                |
     ==========================================*/
    property int languageIndex: 0

    /*==========================================
     | Multiplayer                             |
     ==========================================*/
    property int pingColorIndex: 0
    property bool mpPlayerColoredFlags: true
    property int localFlagColorIndex: 4
    property int remoteFlagColorIndex: 1
    property bool mpShowInviteNotificationInGame: true

    /*==========================================
     | Sounds                                  |
     ==========================================*/
    property real volume: 1.0
    property real remoteVolume: 0.7
    property real newChatMessageVolume: 1
    property int soundPackIndex: 2

    /*==========================================
     | Visual                                  |
     ==========================================*/
    property int flagSkinIndex: 0
    property int gridResetAnimationIndex: 0
    property int fontIndex: 0
    property real satisfiedOpacity: 0.50
    property bool displayTimer: true
    property bool dimSatisfied: true
    property bool animations: true
    property bool cellFrame: true
    property bool startFullScreen: GameCore.gamescope
    property bool shakeUnifinishedNumbers: true

    /*==========================================
     | Misc                                    |
     ==========================================*/
    property bool firstRunCompleted: true
}

