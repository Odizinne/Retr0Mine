import QtQuick
import QtMultimedia
import net.odizinne.retr0mine
Item {
    id: control
    property int packIndex: GameSettings.soundPackIndex
    property bool enabled: true
    property bool clickCooldown: false
    property bool remoteClickCooldown: false

    Timer {
        id: cooldownTimer
        interval: 25
        onTriggered: control.clickCooldown = false
    }

    Timer {
        id: remoteCooldownTimer
        interval: 25
        onTriggered: control.remoteClickCooldown = false
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

    Timer {
        id: remoteClickDelayTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (!GameState.gameOver) {
                for (let effect of control.remoteClickPool) {
                    if (!effect.playing) {
                        effect.play()
                        control.remoteClickCooldown = true
                        remoteCooldownTimer.restart()
                        return
                    }
                }
            }
        }
    }

    property list<SoundEffect> clickPool: [
        SoundEffect {
            source: control.getSoundPath("click")
            volume: GameSettings.volume
        },
        SoundEffect {
            source: control.getSoundPath("click")
            volume: GameSettings.volume
        },
        SoundEffect {
            source: control.getSoundPath("click")
            volume: GameSettings.volume
        }
    ]

    property list<SoundEffect> remoteClickPool: [
        SoundEffect {
            source: control.getSoundPath("remoteClick")
            volume: GameSettings.remoteVolume
        },
        SoundEffect {
            source: control.getSoundPath("remoteClick")
            volume: GameSettings.remoteVolume
        },
        SoundEffect {
            source: control.getSoundPath("remoteClick")
            volume: GameSettings.remoteVolume
        }
    ]

    SoundEffect {
        id: winEffect
        source: control.getSoundPath("win")
        volume: GameSettings.volume
    }

    SoundEffect {
        id: looseEffect
        source: control.getSoundPath("bomb")
        volume: GameSettings.volume
    }

    SoundEffect {
        id: messageSound
        source: "qrc:/sounds/message_received.wav"
        volume: GameSettings.newChatMessageVolume
    }

    SoundEffect {
        /*==========================================
         | prevent sound device sleeping           |
         | useful for some BT devices              |
         ==========================================*/
        id: silentKeepAlive
        source: "qrc:/sounds/empty.wav"
        volume: 0.01
        loops: SoundEffect.Infinite
        Component.onCompleted: {
            play()
        }
    }

    function getSoundPath(type) {
        const packs = {
            0: {
                click: "qrc:/sounds/pop/click.wav",
                remoteClick: "qrc:/sounds/pop/remoteClick.wav",
                win: "qrc:/sounds/pop/win.wav",
                bomb: "qrc:/sounds/pop/bomb.wav"
            },
            1: {
                click: "qrc:/sounds/w11/click.wav",
                remoteClick: "qrc:/sounds/w11/remoteClick.wav",
                win: "qrc:/sounds/w11/win.wav",
                bomb: "qrc:/sounds/w11/bomb.wav"
            },
            2: {
                click: "qrc:/sounds/kde-ocean/click.wav",
                remoteClick: "qrc:/sounds/kde-ocean/remoteClick.wav",
                win: "qrc:/sounds/kde-ocean/win.wav",
                bomb: "qrc:/sounds/kde-ocean/bomb.wav"
            },
            3: {
                click: "qrc:/sounds/floraphonic/click.wav",
                remoteClick: "qrc:/sounds/floraphonic/remoteClick.wav",
                win: "qrc:/sounds/floraphonic/win.wav",
                bomb: "qrc:/sounds/floraphonic/bomb.wav"
            }
        }
        return packs[packIndex][type]
    }

    function playClick() {
        if (GameSettings.volume === 0 || clickCooldown) return
        clickDelayTimer.start()
    }

    function playRemoteClick() {
        if (GameSettings.remoteVolume === 0 || remoteClickCooldown) return
        remoteClickDelayTimer.start()
    }

    function playWin() {
        if (GameSettings.volume === 0) return
        winEffect.play()
    }

    function playLoose() {
        if (GameSettings.volume === 0) return
        looseEffect.play()
    }

    function playMessage() {
        if (GameSettings.newChatMessageVolume === 0) return
        messageSound.play()
    }
}
