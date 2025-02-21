import QtQuick
import QtMultimedia

Item {
    id: root
    required property var root
    property int packIndex: Retr0MineSettings.soundPackIndex
    property bool enabled: true
    property bool clickCooldown: false

    Timer {
        id: cooldownTimer
        interval: 100
        onTriggered: root.clickCooldown = false
    }

    Timer {
        id: clickDelayTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (!root.root.gameOver) {
                for (let effect of root.clickPool) {
                    if (!effect.playing) {
                        effect.play()
                        root.clickCooldown = true
                        cooldownTimer.restart()
                        return
                    }
                }
            }
        }
    }

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
        if (!Retr0MineSettings.soundEffects || clickCooldown) return
        clickDelayTimer.start()
    }

    function playWin() {
        if (!Retr0MineSettings.soundEffects) return
        winEffect.play()
    }

    function playLoose() {
        if (!Retr0MineSettings.soundEffects) return
        looseEffect.play()
    }
}
