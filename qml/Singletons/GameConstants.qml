pragma Singleton
import QtQuick
import net.odizinne.retr0mine 1.0

Item {
    SystemPalette {
        id: sysPalette
        colorGroup: SystemPalette.Active
    }

    function getForegroundColor() {
        if (GameCore.gamescope && (GameSettings.themeIndex === 0 || GameSettings.themeIndex === 1)) {
            return "white"
        }
        return Application.styleHints.colorScheme == Qt.Dark ? "white" : "dark"
    }

    function getFrameColor() {
        if (GameCore.gamescope && GameSettings.themeIndex === 0) {
            return Qt.rgba(1, 1, 1, 0.075)
        } else if (GameCore.gamescope && GameSettings.themeIndex === 1) {
            return Qt.rgba(1, 1, 1, 0.15)
        } else {
            if (GameSettings.themeIndex === 0) {
                return Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.15)
            }
            return Application.styleHints.colorScheme == Qt.Dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
        }
    }

    readonly property color accentColor: sysPalette.accent
    readonly property color foregroundColor: getForegroundColor()
    readonly property color frameColor: getFrameColor()
    readonly property var numberPalettes: ({
        1: { // Deuteranopia
            1: "#377eb8", 2: "#4daf4a", 3: "#e41a1c",
            4: "#984ea3", 5: "#ff7f00", 6: "#a65628",
            7: "#f781bf", 8: foregroundColor
        },
        2: { // Protanopia
            1: "#66c2a5", 2: "#fc8d62", 3: "#8da0cb",
            4: "#e78ac3", 5: "#a6d854", 6: "#ffd92f",
            7: "#e5c494", 8: foregroundColor
        },
        3: { // Tritanopia
            1: "#e41a1c", 2: "#377eb8", 3: "#4daf4a",
            4: "#984ea3", 5: "#ff7f00", 6: "#f781bf",
            7: "#a65628", 8: foregroundColor
        },
        0: { // Normal
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

    property string pingColor: {
        switch(GameSettings.pingColorIndex) {
            case 0:
                GameConstants.foregroundColor
            break;
            case 1:
                "#E95420"
            break;
            case 2:
                "#DD0077"
            break;
            case 3:
                "#26A269"
            break;
            case 4:
                "#3584E4"
            break;
            case 5:
                "#5E5CBB"
            break;
            case 6:
                "#E01B24"
            break;
            case 7:
                "#E5A50A"
            break;
            case 8:
                "#" + GameSettings.pingCustomColor
            break;

        }

    }
}




