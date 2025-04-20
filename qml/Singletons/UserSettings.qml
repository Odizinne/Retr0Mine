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
    property bool contrastedNumbers: false
    property real gridScale: 1
    property bool radialMenu: true

    /*==========================================
     | Advanced                                |
     ==========================================*/
    property int colorSchemeIndex: 1
    property int accentColorIndex: 2
    property int renderingBackend: 0
    property bool customTitlebar: true
    property bool customCursor: true
    property bool logs: false

    /*==========================================
     | Difficulty                              |
     ==========================================*/
    property int difficulty: 0
    property int customWidth: 8
    property int customHeight: 8
    property int customMines: 10
    property bool mineDensity: true

    /*==========================================
     | Gameplay                                |
     ==========================================*/
    property bool hintReasoningInChat: true
    property bool safeFirstClick: true
    property bool loadLastGame: false
    property bool invertLRClick: false
    property bool autoreveal: true
    property bool rumble: true

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
     | Shortcuts                               |
     ==========================================*/
    property string revealShortcut: "Q"
    property string flagShortcut: "W"
    property string questionedShortcut: "E"

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
    property bool blur: true
    property bool cellFrame: true
    property bool startFullScreen: GameCore.gamescope
    property bool shakeUnifinishedNumbers: true
    property int cellSpacing: 2

    /*==========================================
     | Misc                                    |
     ==========================================*/
    property bool firstRunCompleted: true
}

