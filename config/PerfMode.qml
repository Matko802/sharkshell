pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
  id: root

  readonly property var modes: ["performance", "balanced", "power-saver"]
  readonly property var modeNames: ["Performance", "Balanced", "Power Saver"]
  readonly property var modeIcons: ["cpu", "tune", "hibernate"]
  readonly property var modeHints: [
    "Full effects, 30 fps visualizer",
    "Reduced effects, 15 fps visualizer",
    "Minimal effects, no visualizer"
  ]

  property string mode: "balanced"
  property bool autoSaver: false
  property bool _cacheHit: false

  readonly property bool onBattery: {
    try {
      const dev = UPower.displayDevice
      if (!dev || !dev.ready)
        return false
      return dev.state === UPowerDeviceState.Discharging
    } catch (e) {
      return false
    }
  }

  readonly property string effectiveMode: (root.autoSaver && root.onBattery) ? "power-saver" : root.mode
  readonly property bool isSaver: root.effectiveMode === "power-saver"
  readonly property bool isPerformance: root.effectiveMode === "performance"

  readonly property int fps: root.isSaver ? 0 : (root.isPerformance ? 30 : 15)
  readonly property bool visualizerAllowed: root.fps > 0
  readonly property bool lockBlurAllowed: !root.isSaver
  readonly property real animScale: root.isSaver ? 0 : 1
  readonly property real pollScale: root.isSaver ? 2 : (root.isPerformance ? 0.75 : 1)
  readonly property int netInterval: root.isSaver ? 4 : 2

  function modeLabel(m) {
    const i = root.modes.indexOf(m || root.effectiveMode)
    return i >= 0 ? root.modeNames[i] : "Balanced"
  }

  function setMode(m) {
    m = String(m || "").toLowerCase()
    if (m === "powersaver" || m === "power_saver")
      m = "power-saver"
    if (root.modes.indexOf(m) < 0)
      return
    root.mode = m
  }

  function cycle() {
    const i = root.modes.indexOf(root.mode)
    root.setMode(root.modes[(i + 1) % root.modes.length])
  }

  function setAutoSaver(v) {
    root.autoSaver = !!v
  }

  function toggleAutoSaver() {
    root.autoSaver = !root.autoSaver
  }

  IpcHandler {
    target: "perf"
    function set(m: string): void { root.setMode(m) }
    function cycle(): void { root.cycle() }
    function get(): string { return root.effectiveMode }
    function setAuto(v: bool): void { root.setAutoSaver(v) }
  }

  onModeChanged: {
    modeFile.setText(root.mode)
    root.applySystemProfile()
  }
  onAutoSaverChanged: autoFile.setText(root.autoSaver ? "1" : "0")

  function applySystemProfile() {
    if (sysProfile.running)
      sysProfile.running = false
    sysProfile.command = ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl set " + root.mode + " >/dev/null 2>&1; exit 0"]
    sysProfile.running = true
  }

  Process {
    id: sysProfile
  }

  FileView {
    id: modeFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/perf-mode"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim().toLowerCase()
      if (t !== "" && root.modes.indexOf(t) >= 0) {
        root._cacheHit = true
        root.mode = t
      }
    }
    onFileChanged: reload()
  }

  FileView {
    id: autoFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/perf-auto-saver"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim().toLowerCase()
      root.autoSaver = (t === "1" || t === "true" || t === "on")
    }
    onFileChanged: reload()
  }

  Process {
    id: mkdirProc
    running: true
    command: ["bash", "-c", "mkdir -p \"$HOME/.cache/sharkshell\""]
    onExited: sysProbe.running = true
  }

  Process {
    id: sysProbe
    command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get 2>/dev/null || echo \"" + root.mode + "\""]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root._cacheHit)
          return
        const t = String(text).trim().toLowerCase()
        if (root.modes.indexOf(t) >= 0 && t !== root.mode)
          root.mode = t
      }
    }
  }
}
