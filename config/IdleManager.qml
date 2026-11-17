pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland

Item {
    id: root

    property bool enabled: true

    property int dimTimeout: 300
    property int lockTimeout: 300
    property int screenOffDelay: 300
    property int lockedScreenOffDelay: 60
    property int suspendTimeout: 900
    readonly property int dimDef: 300
    readonly property int lockDef: 300
    readonly property int screenOffDef: 300
    readonly property int lockedScreenOffDef: 60
    readonly property int suspendDef: 900
    readonly property int _screenOffSec: screenOffDelay > 0 ? Math.max(screenOffDelay, 30) : 0
    readonly property int _lockedScreenOffSec: lockedScreenOffDelay < 0 ? _screenOffSec
        : (lockedScreenOffDelay > 0 ? Math.max(lockedScreenOffDelay, 10) : 0)

    property int _idleSeconds: 0
    property int _offSeconds: 0
    property bool screenIsOff: false

    property bool dimStageArmed: true
    property bool lockStageArmed: true
    property bool screenOffStageArmed: true
    property bool suspendStageArmed: true

    readonly property real dimRatio: 0.3
    property bool dimmed: false
    property real _dimBase: -1
    property real _dimTarget: -1

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
    property bool opencodeRunning: false
    readonly property bool inhibited: stayAwake || gaming || opencodeRunning || mediaPlaying || (audioActive && !mediaPaused)
    readonly property bool sessionInhibited: inhibited || taskRunning

    onInhibitedChanged: {
        root._restartTimers()
        root.undimScreen()
    }
    onTaskRunningChanged: root._restartTimers()

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
            if (exitCode === 10 && powerBridge.item)
                powerBridge.item.setAllPower(!root.screenIsOff)
        }
    }

    Loader {
        id: powerBridge
        source: "OutputPowerBridge.qml"
    }

    function _restartTimers() {
        root._idleSeconds = 0
        root._offSeconds = 0
        root.dimStageArmed = true
        root.lockStageArmed = true
        root.screenOffStageArmed = true
        root.suspendStageArmed = true
    }

    function markActive() {
        root._restartTimers()
        root.undimScreen()
        root._setScreen(false)
    }

    function dimScreen() {
        if (root.dimmed || root.screenIsOff || !BrightnessState.available || BrightnessState.bright < 0)
            return
        root._dimBase = BrightnessState.bright
        root._dimTarget = root._dimBase * root.dimRatio
        root.dimmed = true
        BrightnessState.set(root._dimTarget)
    }

    function undimScreen() {
        if (!root.dimmed)
            return
        root.dimmed = false
        const base = root._dimBase
        const target = root._dimTarget
        root._dimBase = -1
        root._dimTarget = -1
        if (base < 0)
            return
        const cur = BrightnessState.bright
        if (cur >= 0 && Math.abs(cur - target) > 0.08 && Math.abs(cur - base) > 0.08)
            return
        BrightnessState.set(base)
    }

    function setDimTimeout(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.dimTimeout = Math.min(1800, Math.max(0, v))
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

    function setLockedScreenOffDelay(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.lockedScreenOffDelay = Math.min(3600, Math.max(-1, v))
    }

    function setSuspendTimeout(v) {
        v = Math.round(v)
        if (isNaN(v)) return
        root.suspendTimeout = Math.min(3600, Math.max(0, v))
    }

    onDimTimeoutChanged: dimTimeoutFile.setText(String(root.dimTimeout))
    onLockTimeoutChanged: lockTimeoutFile.setText(String(root.lockTimeout))
    onScreenOffDelayChanged: screenOffDelayFile.setText(String(root.screenOffDelay))
    onLockedScreenOffDelayChanged: lockedScreenOffDelayFile.setText(String(root.lockedScreenOffDelay))
    onSuspendTimeoutChanged: suspendTimeoutFile.setText(String(root.suspendTimeout))

    IpcHandler {
        target: "idle"
        function setDim(v: real): void { root.setDimTimeout(v) }
        function setLock(v: real): void { root.setLockTimeout(v) }
        function setScreenOff(v: real): void { root.setScreenOffDelay(v) }
        function setLockedScreenOff(v: real): void { root.setLockedScreenOffDelay(v) }
        function setSuspend(v: real): void { root.setSuspendTimeout(v) }
    }

    FileView {
        id: dimTimeoutFile
        path: Quickshell.env("HOME") + "/.cache/sharkshell/dim-timeout"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const v = parseInt(text().trim())
            if (!isNaN(v)) root.dimTimeout = Math.min(1800, Math.max(0, v))
        }
        onFileChanged: reload()
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
        id: lockedScreenOffDelayFile
        path: Quickshell.env("HOME") + "/.cache/sharkshell/locked-screenoff-delay"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const v = parseInt(text().trim())
            if (!isNaN(v)) root.lockedScreenOffDelay = Math.min(3600, Math.max(-1, v))
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

    property string gamepadWatchScript: [
        "declare -A readers",
        "declare -A kinds",
        "declare -A axes",
        "",
        "emit_activity() {",
        "  echo active",
        "  sleep 0.2",
        "}",
        "",
        "filter_events() {",
        "  local line type code low high value key base delta",
        "",
        "  while read -r line; do",
        "    set -- $line",
        "    [ $# -ge 12 ] || continue",
        "    type=$9",
        "    code=${10}",
        "    low=${11}",
        "    high=${12}",
        "    value=$(( low + high * 65536 ))",
        "    [ \"$value\" -ge 2147483648 ] && value=$(( value - 4294967296 ))",
        "    key=$code",
        "",
        "    if [ \"$type\" -eq 1 ]; then",
        "      if [ \"$value\" -gt 0 ]; then",
        "        emit_activity",
        "      fi",
        "    elif [ \"$type\" -eq 3 ]; then",
        "      if [ \"$code\" -eq 16 ] || [ \"$code\" -eq 17 ]; then",
        "        if [ \"$value\" -ne \"${axes[$key]:-99}\" ]; then",
        "          axes[$key]=$value",
        "          emit_activity",
        "        fi",
        "      elif [ -z \"${axes[$key]+set}\" ]; then",
        "        axes[$key]=$value",
        "      else",
        "        base=${axes[$key]}",
        "        delta=$(( value - base ))",
        "        [ \"$delta\" -lt 0 ] && delta=$(( -delta ))",
        "        if [ \"$delta\" -ge 128 ]; then",
        "          axes[$key]=$value",
        "          emit_activity",
        "        fi",
        "      fi",
        "    fi",
        "  done",
        "}",
        "",
        "is_joystick() {",
        "  udevadm info --query=property --name=\"$1\" 2>/dev/null | grep -qx 'ID_INPUT_JOYSTICK=1'",
        "}",
        "",
        "while :; do",
        "  for dev in /dev/input/event*; do",
        "    [ -e \"$dev\" ] || continue",
        "    if [ -z \"${kinds[$dev]}\" ]; then",
        "      if is_joystick \"$dev\"; then",
        "        kinds[$dev]=1",
        "      else",
        "        kinds[$dev]=0",
        "      fi",
        "    fi",
        "    [ \"${kinds[$dev]}\" = 1 ] || continue",
        "    if [ -n \"${readers[$dev]}\" ] && kill -0 \"${readers[$dev]}\" 2>/dev/null; then",
        "      continue",
        "    fi",
        "    (",
        "      exec 2>/dev/null",
        "      dd if=\"$dev\" bs=24 iflag=fullblock status=none | stdbuf -oL od -An -tu2 -w24 | filter_events",
        "    ) &",
        "    readers[$dev]=$!",
        "  done",
        "  sleep 5",
        "done",
    ].join("\n")

    Process {
        id: gamepadWatch
        running: root.enabled
        command: ["bash", "-c", root.gamepadWatchScript]
        stdout: SplitParser {
            onRead: _ => root.markActive()
        }
    }

    Connections {
        target: LockState
        function onLockedChanged() {
            root._offSeconds = 0
            root.screenOffStageArmed = true
            if (LockState.locked) {
                root.dimStageArmed = false
                root.undimScreen()
            } else {
                root._idleSeconds = 0
                root.dimStageArmed = true
                root.lockStageArmed = true
                root._setScreen(false)
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
            opencodeCheck.running = true
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
            root.gameMode = exitCode === 0
        }
    }

    Process {
        id: audioCheck
        command: ["sh", "-c", "pw-dump 2>/dev/null | awk '/^  \\{$/ { b=\"\"; f=1; next } /^  \\},?$/ { if (f && b ~ /\"media.class\"[[:space:]]*:[[:space:]]*\"Stream\\/Output\\/Audio\"/ && b ~ /\"state\"[[:space:]]*:[[:space:]]*\"running\"/ && b !~ /\"pulse.corked\"[[:space:]]*:[[:space:]]*true/ && b !~ /\"node.name\"[[:space:]]*:[[:space:]]*\"alsa_(playback|capture)\\./) { print \"P\"; exit } f=0; next } f { b = b \"\\n\" $0 }' | grep -q P"]
        onExited: (exitCode) => {
            root.audioActive = (exitCode === 0)
        }
    }

    Process {
        id: taskCheck
        command: ["sh", "-c", "command -v pgrep >/dev/null 2>&1 && pgrep -f '(^|/)(nh|nixos-rebuild)([ /]|$)|nix +(build|develop|shell|run|flake)([ /]|$)' >/dev/null"]
        onExited: (exitCode) => {
            root.taskRunning = (exitCode === 0)
        }
    }

    Process {
        id: opencodeCheck
        command: ["sh", "-c", "command -v pgrep >/dev/null 2>&1 && pgrep -f 'opencode([-.]|[ /]|$)' >/dev/null"]
        onExited: (exitCode) => {
            root.opencodeRunning = (exitCode === 0)
        }
    }

    Timer {
        id: idleClock
        interval: 1000
        running: root.enabled
        repeat: true
        onTriggered: {
            if (LockState.locked) {
                if (root.sessionInhibited)
                    root._idleSeconds = 0
                else
                    root._idleSeconds += 1
                root._offSeconds += 1
                if (root.screenOffStageArmed && root._lockedScreenOffSec > 0 && root._offSeconds >= root._lockedScreenOffSec) {
                    root._setScreen(true)
                    root.screenOffStageArmed = false
                }
                if (!root.sessionInhibited && root.suspendStageArmed && root.suspendTimeout > 0 && root._idleSeconds >= root.suspendTimeout) {
                    suspendProc.running = true
                    root.suspendStageArmed = false
                }
                return
            }
            if (root.inhibited) {
                root._idleSeconds = 0
                root._offSeconds = 0
                root.lockStageArmed = true
                root.screenOffStageArmed = true
                root.suspendStageArmed = true
                return
            }
            root._idleSeconds += 1
            root._offSeconds += 1
            if (root.dimStageArmed && root.dimTimeout > 0 && root._idleSeconds >= root.dimTimeout) {
                root.dimScreen()
                root.dimStageArmed = false
            }
            if (root.lockStageArmed && root.lockTimeout > 0 && root._idleSeconds >= root.lockTimeout) {
                LockState.locked = true
                root.lockStageArmed = false
            }
            if (root.screenOffStageArmed && root._screenOffSec > 0 && root._offSeconds >= root._screenOffSec) {
                root._setScreen(true)
                root.screenOffStageArmed = false
            }
            if (root.suspendStageArmed && root.suspendTimeout > 0 && root._idleSeconds >= root.suspendTimeout) {
                suspendProc.running = true
                root.suspendStageArmed = false
            }
        }
    }

    Process { id: suspendProc; command: ["systemctl", "suspend"] }
}
