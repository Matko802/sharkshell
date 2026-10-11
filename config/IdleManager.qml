pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Power
import Quickshell.Services.Mpris
import Quickshell.Wayland

Item {
    id: root

    property bool enabled: true

    property int lockTimeout: 300
    property int screenOffDelay: 300
    property int suspendTimeout: 900
    readonly property int lockDef: 300
    readonly property int screenOffDef: 300
    readonly property int suspendDef: 900

    property int _idleSeconds: 0
    property bool screenIsOff: false

    property bool lockStageArmed: true
    property bool screenOffStageArmed: true
    property bool suspendStageArmed: true

    property bool mediaPlaying: {
        const ps = Mpris.players ? Mpris.players.values : []
        for (let i = 0; i < ps.length; i++) {
            if (ps[i] && ps[i].isPlaying) return true
        }
        return false
    }
    property bool mediaPaused: {
        const ps = Mpris.players ? Mpris.players.values : []
        let any = false
        for (let i = 0; i < ps.length; i++) {
            if (!ps[i]) continue
            any = true
            if (ps[i].isPlaying) return false
        }
        return any
    }
    property bool audioActive: false
    property bool gameMode: false
    property bool fullscreenActive: false
    readonly property bool gaming: gameMode || fullscreenActive
    property bool stayAwake: false
    property bool taskRunning: false
    readonly property bool _inhibited: mediaPlaying || gameMode || stayAwake || taskRunning || (audioActive && !mediaPaused)
    readonly property real batteryScale: PerfMode.saving ? 0.5 : 1
    readonly property int effLockTimeout: root.lockTimeout <= 0 ? 0 : Math.max(1, Math.round(root.lockTimeout * root.batteryScale))
    readonly property int effScreenOffDelay: root.screenOffDelay <= 0 ? 0 : Math.max(1, Math.round(root.screenOffDelay * root.batteryScale))
    readonly property int effSuspendTimeout: root.suspendTimeout <= 0 ? 0 : Math.max(1, Math.round(root.suspendTimeout * root.batteryScale))

    function _setScreen(off) {
        if (off === root.screenIsOff)
            return
        root.screenIsOff = off
        const action = off ? "power-off-monitors" : "power-on-monitors"
        screenProc.command = ["sh", "-c", "command -v niri >/dev/null 2>&1 && niri msg action " + action + " 2>/dev/null || exit 10"]
        screenProc.running = true
    }

    Process {
        id: screenProc
        running: false
        onExited: exitCode => {
            if (exitCode === 10)
                outputPower.setAllPower(!root.screenIsOff)
        }
    }

    function markActive() {
        root._idleSeconds = 0
        root.lockStageArmed = true
        root.screenOffStageArmed = true
        root.suspendStageArmed = true
        root._setScreen(false)
    }

    function setLockTimeout(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.lockTimeout = Math.min(1800, Math.max(0, v))
    }

    function setScreenOffDelay(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.screenOffDelay = Math.min(1800, Math.max(0, v))
    }

    function setSuspendTimeout(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.suspendTimeout = Math.min(3600, Math.max(0, v))
    }

    onLockTimeoutChanged: lockTimeoutFile.setText(String(root.lockTimeout))
    onScreenOffDelayChanged: screenOffDelayFile.setText(String(root.screenOffDelay))
    onSuspendTimeoutChanged: suspendTimeoutFile.setText(String(root.suspendTimeout))

    IpcHandler {
        target: "idle"
        function setLock(v: real): void { root.setLockTimeout(v) }
        function setScreenOff(v: real): void { root.setScreenOffDelay(v) }
        function setSuspend(v: real): void { root.setSuspendTimeout(v) }
    }

    FileView {
        id: lockTimeoutFile
        path: Quickshell.env("HOME") + "/.cache/sharkshell/lock-timeout"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const v = parseInt(text().trim())
            if (!isNaN(v)) root.lockTimeout = Math.min(1800, Math.max(0, v))
        }
        onFileChanged: reload()
    }

    FileView {
        id: screenOffDelayFile
        path: Quickshell.env("HOME") + "/.cache/sharkshell/screenoff-delay"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const v = parseInt(text().trim())
            if (!isNaN(v)) root.screenOffDelay = Math.min(1800, Math.max(0, v))
        }
        onFileChanged: reload()
    }

    FileView {
        id: suspendTimeoutFile
        path: Quickshell.env("HOME") + "/.cache/sharkshell/suspend-timeout"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const v = parseInt(text().trim())
            if (!isNaN(v)) root.suspendTimeout = Math.min(3600, Math.max(0, v))
        }
        onFileChanged: reload()
    }

    function toggle() {
        enabled = !enabled
    }

    IdleMonitor {
        id: nativeIdle
        enabled: root.enabled
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: if (!isIdle) root.markActive()
    }

    Process {
        id: activityWatch
        running: root.enabled
        command: ["sh", "-c", "command -v mmsg >/dev/null 2>&1 && exec stdbuf -oL mmsg watch all-devices || sleep 999999"]
        stdout: SplitParser {
            onRead: _ => root.markActive()
        }
    }

    Connections {
        target: LockState
        function onLockedChanged() {
            if (LockState.locked) {
                root._idleSeconds = 0
                root.lockStageArmed = true
                root.screenOffStageArmed = true
            } else {
                root._setScreen(false)
                root.screenOffStageArmed = true
            }
        }
    }

    Timer {
        interval: root.gameMode ? 10000 : 6000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            gameCheck.running = true
            if (!root.mediaPlaying)
                audioCheck.running = true
            taskCheck.running = true
            if (root.mediaPlaying)
                root.markActive()
        }
    }

    Process {
        id: mkdirProc
        running: true
        command: ["bash", "-c", "mkdir -p \"$HOME/.cache/sharkshell\""]
    }

    Process {
        id: gameCheck
        command: ["sh", "-c", "command -v gamemoded >/dev/null 2>&1 && gamemoded -s 2>/dev/null | grep -qi 'is active'"]
        onExited: (exitCode) => {
            const active = exitCode === 0
            root.gameMode = active
            if (active)
                root.markActive()
        }
    }

    Process {
        id: audioCheck
        command: ["sh", "-c", "pw-dump 2>/dev/null | awk '/^  \\{$/ { b=\"\"; f=1; next } /^  \\},?$/ { if (f && b ~ /\"media.class\"[[:space:]]*:[[:space:]]*\"Stream\\/Output\\/Audio\"/ && b ~ /\"state\"[[:space:]]*:[[:space:]]*\"running\"/ && b !~ /\"pulse.corked\"[[:space:]]*:[[:space:]]*true/ && b !~ /\"node.name\"[[:space:]]*:[[:space:]]*\"alsa_(playback|capture)\\./) { print \"P\"; exit } f=0; next } f { b = b \"\\n\" $0 }' | grep -q P"]
        onExited: (exitCode) => {
            root.audioActive = (exitCode === 0)
            if (exitCode === 0)
                root.markActive()
        }
    }

    Process {
        id: taskCheck
        command: ["sh", "-c", "command -v pgrep >/dev/null 2>&1 && pgrep -f '(^|/)(nh|nixos-rebuild)([ /]|$)|nix +(build|develop|shell|run|flake)([ /]|$)|opencode([-.]|[ /]|$)' >/dev/null"]
        onExited: (exitCode) => {
            root.taskRunning = (exitCode === 0)
            if (exitCode === 0)
                root.markActive()
        }
    }

    Timer {
        id: idleClock
        interval: 1000
        running: root.enabled
        repeat: true
        onTriggered: {
            if (root._inhibited) {
                root.markActive()
                return
            }
            root._idleSeconds += 1
            const locked = LockState.locked
            if (!locked && root.lockStageArmed && root.effLockTimeout > 0 && root._idleSeconds >= root.effLockTimeout) {
                LockState.locked = true
                root.lockStageArmed = false
            }
            if (locked && root.screenOffStageArmed && root.effScreenOffDelay > 0 && root._idleSeconds >= root.effScreenOffDelay) {
                root._setScreen(true)
                root.screenOffStageArmed = false
            }
            if (root.suspendStageArmed && root.effSuspendTimeout > 0 && root._idleSeconds >= root.effSuspendTimeout) {
                suspendProc.running = true
                root.suspendStageArmed = false
            }
        }
    }

    OutputPower {
        id: outputPower
    }

    Process { id: suspendProc; command: ["systemctl", "suspend"] }
}
