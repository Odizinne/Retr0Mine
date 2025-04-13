pragma Singleton

import QtQuick
import QtMultimedia
import Odizinne.Retr0Mine

Item {
    property int packIndex: UserSettings.soundPackIndex
    property bool enabled: true
    property bool clickCooldown: false
    property bool remoteClickCooldown: false
    property string currentAudioDevice: ""
    property var currentAudioOutput: null

    Component.onCompleted: {
        updateAudioDevice()
        playSilent()
    }

    MediaDevices {
        id: mediaDevices
        onAudioOutputsChanged: {
            AudioEngine.updateAudioDevice()
        }
    }

    function updateAudioDevice() {
        const device = mediaDevices.defaultAudioOutput

        if (device.id !== (currentAudioOutput ? currentAudioOutput.id : "")) {
            LogManager.info("Audio device changed to: " + device.description)

            currentAudioDevice = device.description
            currentAudioOutput = device

            applyAudioDeviceToAllPlayers(device)
        }
    }

    function applyAudioDeviceToAllPlayers(device) {
        for (let i = 0; i < clickPool.length; i++) {
            clickPool[i].audioOutput.device = device
        }

        for (let i = 0; i < remoteClickPool.length; i++) {
            remoteClickPool[i].audioOutput.device = device
        }

        winPlayer.audioOutput.device = device
        loosePlayer.audioOutput.device = device
        messagePlayer.audioOutput.device = device
        silentKeepAlive.audioOutput.device = device

        silentKeepAlive.stop()
        silentKeepAlive.play()
    }

    Timer {
        id: cooldownTimer
        interval: 25
        onTriggered: AudioEngine.clickCooldown = false
    }

    Timer {
        id: remoteCooldownTimer
        interval: 25
        onTriggered: AudioEngine.remoteClickCooldown = false
    }

    Timer {
        id: clickDelayTimer
        interval: 20
        repeat: false
        onTriggered: {
            if (!GameState.gameOver) {
                for (let player of AudioEngine.clickPool) {
                    if (player.playbackState !== MediaPlayer.PlayingState) {
                        player.play()
                        AudioEngine.clickCooldown = true
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
                for (let player of AudioEngine.remoteClickPool) {
                    if (player.playbackState !== MediaPlayer.PlayingState) {
                        player.play()
                        AudioEngine.remoteClickCooldown = true
                        remoteCooldownTimer.restart()
                        return
                    }
                }
            }
        }
    }

    property list<MediaPlayer> clickPool: [
        MediaPlayer {
            source: AudioEngine.getSoundPath("click")
            audioOutput: AudioOutput {
                volume: UserSettings.volume
                device: mediaDevices.defaultAudioOutput
            }
        },
        MediaPlayer {
            source: AudioEngine.getSoundPath("click")
            audioOutput: AudioOutput {
                volume: UserSettings.volume
                device: mediaDevices.defaultAudioOutput
            }
        },
        MediaPlayer {
            source: AudioEngine.getSoundPath("click")
            audioOutput: AudioOutput {
                volume: UserSettings.volume
                device: mediaDevices.defaultAudioOutput
            }
        }
    ]

    property list<MediaPlayer> remoteClickPool: [
        MediaPlayer {
            source: AudioEngine.getSoundPath("remoteClick")
            audioOutput: AudioOutput {
                volume: UserSettings.remoteVolume
                device: mediaDevices.defaultAudioOutput
            }
        },
        MediaPlayer {
            source: AudioEngine.getSoundPath("remoteClick")
            audioOutput: AudioOutput {
                volume: UserSettings.remoteVolume
                device: mediaDevices.defaultAudioOutput
            }
        },
        MediaPlayer {
            source: AudioEngine.getSoundPath("remoteClick")
            audioOutput: AudioOutput {
                volume: UserSettings.remoteVolume
                device: mediaDevices.defaultAudioOutput
            }
        }
    ]

    MediaPlayer {
        id: winPlayer
        source: AudioEngine.getSoundPath("win")
        audioOutput: AudioOutput {
            id: winAudio
            volume: UserSettings.volume
            device: mediaDevices.defaultAudioOutput
        }
    }

    MediaPlayer {
        id: loosePlayer
        source: AudioEngine.getSoundPath("bomb")
        audioOutput: AudioOutput {
            id: looseAudio
            volume: UserSettings.volume
            device: mediaDevices.defaultAudioOutput
        }
    }

    MediaPlayer {
        id: messagePlayer
        source: "qrc:/sounds/message_received.wav"
        audioOutput: AudioOutput {
            id: messageAudio
            volume: UserSettings.newChatMessageVolume
            device: mediaDevices.defaultAudioOutput
        }
    }

    MediaPlayer {
        id: silentKeepAlive
        source: "qrc:/sounds/empty.wav"
        audioOutput: AudioOutput {
            id: silentAudio
            volume: 0.01
            device: mediaDevices.defaultAudioOutput
        }
        loops: MediaPlayer.Infinite
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
        if (UserSettings.volume === 0 || clickCooldown) return
        clickDelayTimer.start()
    }

    function playRemoteClick() {
        if (UserSettings.remoteVolume === 0 || remoteClickCooldown) return
        remoteClickDelayTimer.start()
    }

    function playWin() {
        if (UserSettings.volume === 0) return
        winPlayer.stop()
        winPlayer.play()
    }

    function playLoose() {
        if (UserSettings.volume === 0) return
        loosePlayer.stop()
        loosePlayer.play()
    }

    function playMessage() {
        if (UserSettings.newChatMessageVolume === 0) return
        messagePlayer.stop()
        messagePlayer.play()
    }

    function playSilent() {
        silentKeepAlive.play()
    }
}
