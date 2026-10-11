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
    "Full system performance",
    "Balanced power and performance",
    "Lower power use, quieter fans"
  ]

  property string mode: "balanced"
  property bool autoSaver: false
  property bool _syncing: false

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
  readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
  readonly property bool degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

  function enumFor(m) {
    if (m === "performance")
      return PowerProfile.Performance
    if (m === "power-saver")
      return PowerProfile.PowerSaver
    return PowerProfile.Balanced
  }

  function stringFor(p) {
    if (p === PowerProfile.Performance)
      return "performance"
    if (p === PowerProfile.PowerSaver)
      return "power-saver"
    return "balanced"
  }

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
    if (m === "performance" && !root.hasPerformance)
      m = "balanced"
    root.mode = m
  }

  function cycle() {
    const order = root.hasPerformance ? root.modes : ["balanced", "power-saver"]
    const i = order.indexOf(root.mode)
    root.setMode(order[(i + 1) % order.length])
  }

  function setAutoSaver(v) {
    root.autoSaver = !!v
  }

  function toggleAutoSaver() {
    root.autoSaver = !root.autoSaver
  }

  function applySystemProfile() {
    if (root.effectiveMode === "performance" && !root.hasPerformance)
      return
    const target = root.enumFor(root.effectiveMode)
    if (PowerProfiles.profile === target)
      return
    root._syncing = true
    PowerProfiles.profile = target
  }

  Connections {
    target: PowerProfiles
    function onProfileChanged() {
      if (root._syncing) {
        root._syncing = false
        return
      }
      const s = root.stringFor(PowerProfiles.profile)
      if (s !== root.mode)
        root.mode = s
    }
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
  onEffectiveModeChanged: root.applySystemProfile()
  onAutoSaverChanged: autoFile.setText(root.autoSaver ? "1" : "0")

  FileView {
    id: modeFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/perf-mode"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const t = text().trim().toLowerCase()
      if (t !== "" && root.modes.indexOf(t) >= 0)
        root.mode = t
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
  }
}
