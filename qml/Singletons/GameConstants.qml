pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

Item {
    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }

    function getForegroundColor() {
        if (GameCore.gamescope) {
            return "white"
        }
        return Application.styleHints.colorScheme === Qt.Dark ? "white" : "black"
    }

    function getFrameColor() {
        if (GameCore.gamescope && GameCore.isFluent) {
            return Qt.rgba(1, 1, 1, 0.075)
        } else if (GameCore.gamescope && GameCore.isUniversal) {
            return Qt.rgba(1, 1, 1, 0.15)
        } else {
            if (GameCore.isFluent) {
                return Application.styleHints.colorScheme === Qt.Dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.15)
            }
            return Application.styleHints.colorScheme === Qt.Dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
        }
    }

    readonly property color accentColor: GameCore.isFluent ? sysPalette.accent : sysPalette.highlight
    readonly property color foregroundColor: getForegroundColor()
    readonly property color settingsPaneColor: Application.styleHints.colorScheme === Qt.Dark || GameCore.gamescope ? "#333333" : "#cccccc"
    readonly property color frameColor: getFrameColor()
    readonly property var numberPalettes: ({
        /*==========================================
         | 0: No correction                        |
         | 1: Deuteranopia                         |
         | 2: Protanopia                           |
         | 3: Tritanopia                           |
         ==========================================*/
        1: {
            1: "#377eb8", 2: "#4daf4a", 3: "#e41a1c",
            4: "#984ea3", 5: "#ff7f00", 6: "#a65628",
            7: "#f781bf", 8: foregroundColor
        },
        2: {
            1: "#66c2a5", 2: "#fc8d62", 3: "#8da0cb",
            4: "#e78ac3", 5: "#a6d854", 6: "#ffd92f",
            7: "#e5c494", 8: foregroundColor
        },
        3: {
            1: "#e41a1c", 2: "#377eb8", 3: "#4daf4a",
            4: "#984ea3", 5: "#ff7f00", 6: "#f781bf",
            7: "#a65628", 8: foregroundColor
        },
        0: {
            1: "#069ecc", 2: "#28d13c", 3: "#d12844",
            4: "#9328d1", 5: "#ebc034", 6: "#34ebb1",
            7: "#eb8634", 8: foregroundColor
        }
    })

    function getNumberColor(revealed, isMine, index, number) {
        if (!revealed) return "black"
        if (isMine) return "transparent"
        const palette = numberPalettes[GameSettings.colorBlindness] || numberPalettes[0]
        return palette[number] || "black"
    }

    readonly property FontLoader numberFont: FontLoader {
        source: switch (GameSettings.fontIndex) {
            case 0:
                "qrc:/fonts/FiraSans-SemiBold.ttf"
                break
            case 1:
                "qrc:/fonts/NotoSerif-Regular.ttf"
                break
            case 2:
                "qrc:/fonts/SpaceMono-Regular.ttf"
                break
            case 3:
                "qrc:/fonts/Orbitron-Regular.ttf"
                break
            case 4:
                "qrc:/fonts/PixelifySans-Regular.ttf"
                break
            default:
                "qrc:/fonts/FiraSans-Bold.ttf"
        }
    }

    property string localFlagColor: {
        switch(GameSettings.localFlagColorIndex) {
            case 0:
                GameConstants.foregroundColor
            break
            case 1:
                "#ff7747"
            break
            case 2:
                "#ff7dbe"
            break
            case 3:
                "#7ddb7d"
            break
            case 4:
                "#47ceff"
            break
            case 5:
                "#ae7dff"
            break
            case 6:
                "#ff6b6b"
            break
            case 7:
                "#ffe066"
            break
        }
    }

    property string remoteFlagColor: {
        switch(GameSettings.remoteFlagColorIndex) {
            case 0:
                GameConstants.foregroundColor
            break
            case 1:
                "#ff7747"
            break
            case 2:
                "#ff7dbe"
            break
            case 3:
                "#7ddb7d"
            break
            case 4:
                "#47ceff"
            break
            case 5:
                "#ae7dff"
            break
            case 6:
                "#ff6b6b"
            break
            case 7:
                "#ffe066"
            break
        }
    }

    property string pingColor: {
        switch(GameSettings.pingColorIndex) {
            case 0:
                GameConstants.foregroundColor
            break
            case 1:
                "#E95420"
            break
            case 2:
                "#DD0077"
            break
            case 3:
                "#26A269"
            break
            case 4:
                "#3584E4"
            break
            case 5:
                "#5E5CBB"
            break
            case 6:
                "#E01B24"
            break
            case 7:
                "#E5A50A"
            break
        }
    }

    property int settingsRowSpacing: 10
    property int settingsColumnSpacing: GameCore.isFluent ? 15 : 20
    property int settingsComponentsHeight: GameCore.isFluent ? 35 : 32
    property string retr0mineLogo: getForegroundColor() === "white" ? "qrc:/images/retr0mine_logo.png" : "qrc:/images/retr0mine_logo_dark.png"

    function getRightClickExplanation() {
        if (!GameSettings.invertLRClick) {
            return qsTr("Flag")
        } else {
            return qsTr("Reveal")
        }
    }

    function getLeftClickExplanation() {
        if (!GameSettings.invertLRClick) {
            return qsTr("Reveal")
        } else {
            return qsTr("Flag")
        }
    }

    property string leftClickExplanation: getLeftClickExplanation()
    property string rightClickExplanation: getRightClickExplanation()
}
