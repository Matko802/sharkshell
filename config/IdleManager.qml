pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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
    property bool gameLatched: false
    readonly property bool gaming: gameMode || fullscreenActive
    readonly property bool gameSession: gameLatched || gameMode || (fullscreenActive && !mediaPlaying)
    property bool stayAwake: false
    property bool taskRunning: false
    readonly property bool _inhibited: stayAwake || (!root.gameSession && (mediaPlaying || (audioActive && !mediaPaused)))

    onGamingChanged: if (root.gaming) root.markActive()

    onTaskRunningChanged: {
        if (!root.taskRunning && root.suspendStageArmed && root.suspendTimeout > 0 && root._idleSeconds >= root.suspendTimeout)
            root._idleSeconds = 0
    }

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
            if (LockState.locked) {
                root.gameLatched = root.gameSession
                root._idleSeconds = 0
                root.lockStageArmed = true
                root.screenOffStageArmed = true
            } else {
                root.gameLatched = false
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
            if (root.mediaPlaying && !root.gameSession)
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
            if (active && !root.gameMode)
                root.markActive()
            root.gameMode = active
        }
    }

    Process {
        id: audioCheck
        command: ["sh", "-c", "pw-dump 2>/dev/null | awk '/^  \\{$/ { b=\"\"; f=1; next } /^  \\},?$/ { if (f && b ~ /\"media.class\"[[:space:]]*:[[:space:]]*\"Stream\\/Output\\/Audio\"/ && b ~ /\"state\"[[:space:]]*:[[:space:]]*\"running\"/ && b !~ /\"pulse.corked\"[[:space:]]*:[[:space:]]*true/ && b !~ /\"node.name\"[[:space:]]*:[[:space:]]*\"alsa_(playback|capture)\\./) { print \"P\"; exit } f=0; next } f { b = b \"\\n\" $0 }' | grep -q P"]
        onExited: (exitCode) => {
            root.audioActive = (exitCode === 0)
            if (exitCode === 0 && !root.gameSession)
                root.markActive()
        }
    }

    Process {
        id: taskCheck
        command: ["sh", "-c", "command -v pgrep >/dev/null 2>&1 && pgrep -f '(^|/)(nh|nixos-rebuild)([ /]|$)|nix +(build|develop|shell|run|flake)([ /]|$)|opencode([-.]|[ /]|$)' >/dev/null"]
        onExited: (exitCode) => {
            root.taskRunning = (exitCode === 0)
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
            if (!locked && root.lockStageArmed && root.lockTimeout > 0 && root._idleSeconds >= root.lockTimeout) {
                LockState.locked = true
                root.lockStageArmed = false
            }
            if (locked && root.screenOffStageArmed && root.screenOffDelay > 0 && root._idleSeconds >= root.screenOffDelay) {
                root._setScreen(true)
                root.screenOffStageArmed = false
            }
            if (!root.gameSession && root.suspendStageArmed && !root.taskRunning && root.suspendTimeout > 0 && root._idleSeconds >= root.suspendTimeout) {
                suspendProc.running = true
                root.suspendStageArmed = false
            }
        }
    }

    Process { id: suspendProc; command: ["systemctl", "suspend"] }
}
