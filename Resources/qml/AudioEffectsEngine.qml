import QtQuick
import QtMultimedia

Item {
    id: root
    property int packIndex: 2
    property bool enabled: true

    property list<SoundEffect> clickPool: [
        SoundEffect {
            source: root.getSoundPath("click")
        },
        SoundEffect {
            source: root.getSoundPath("click")
        },
        SoundEffect {
            source: root.getSoundPath("click")
        }
    ]

    SoundEffect {
        id: winEffect
        source: root.getSoundPath("win")
    }

    SoundEffect {
        id: looseEffect
        source: root.getSoundPath("bomb")
    }

    function getSoundPath(type) {
        const packs = {
            0: {
                click: "qrc:/sounds/pop/pop_click.wav",
                win: "qrc:/sounds/pop/pop_win.wav",
                bomb: "qrc:/sounds/pop/pop_bomb.wav"
            },
            1: {
                click: "qrc:/sounds/w11/w11_click.wav",
                win: "qrc:/sounds/w11/w11_win.wav",
                bomb: "qrc:/sounds/w11/w11_bomb.wav"
            },
            2: {
                click: "qrc:/sounds/kde-ocean/kde-ocean_click.wav",
                win: "qrc:/sounds/kde-ocean/kde-ocean_win.wav",
                bomb: "qrc:/sounds/kde-ocean/kde-ocean_bomb.wav"
            },
            3: {
                click: "qrc:/sounds/floraphonic/floraphonic_click.wav",
                win: "qrc:/sounds/floraphonic/floraphonic_win.wav",
                bomb: "qrc:/sounds/floraphonic/floraphonic_bomb.wav"
            }
        }

        return packs[packIndex][type]
    }

    function playClick() {
        if (!enabled) return
        for (let effect of clickPool) {
            if (!effect.playing) {
                effect.play()
                return
            }
        }
    }

    function playWin() {
        if (enabled) winEffect.play()
    }

    function playLoose() {
        if (enabled) looseEffect.play()
    }
}
