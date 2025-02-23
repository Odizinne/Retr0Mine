import QtQuick
import QtMultimedia

Item {
    id: control
    property int packIndex: GameSettings.soundPackIndex
    property bool enabled: true
    property bool clickCooldown: false

    Timer {
        id: cooldownTimer
        interval: 25
        onTriggered: control.clickCooldown = false
    }

    Timer {
        id: clickDelayTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (!GameState.gameOver) {
                for (let effect of control.clickPool) {
                    if (!effect.playing) {
                        effect.play()
                        control.clickCooldown = true
                        cooldownTimer.restart()
                        return
                    }
                }
            }
        }
    }

    property list<SoundEffect> clickPool: [
        SoundEffect {
            source: control.getSoundPath("click")
        },
        SoundEffect {
            source: control.getSoundPath("click")
        },
        SoundEffect {
            source: control.getSoundPath("click")
        }
    ]

    SoundEffect {
        id: winEffect
        source: control.getSoundPath("win")
    }

    SoundEffect {
        id: looseEffect
        source: control.getSoundPath("bomb")
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
        if (!GameSettings.soundEffects || clickCooldown) return
        clickDelayTimer.start()
    }

    function playWin() {
        if (!GameSettings.soundEffects) return
        winEffect.play()
    }

    function playLoose() {
        if (!GameSettings.soundEffects) return
        looseEffect.play()
    }
}
