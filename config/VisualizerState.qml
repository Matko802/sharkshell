pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  VisualizerProfile {
    id: topbarProfileObj
    profileName: "topbar"
  }
  VisualizerProfile {
    id: mediaProfileObj
    profileName: "media"
  }

  readonly property var topbarProfile: topbarProfileObj
  readonly property var mediaProfile: mediaProfileObj

  property string settingsTarget: "topbar"
  readonly property var active: root.settingsTarget === "media" ? root.mediaProfile : root.topbarProfile

  readonly property string mode: root.active.mode
  readonly property int bars: root.active.bars
  readonly property int thickness: root.active.thickness
  readonly property int fps: root.active.fps
  readonly property int visWidth: root.active.visWidth
  readonly property double waveSmoothing: root.active.waveSmoothing
  readonly property string backend: root.active.backend
  readonly property var modes: root.active.modes
  readonly property var barOptions: root.active.barOptions
  readonly property var widthOptions: root.active.widthOptions
  readonly property var thicknessOptions: root.active.thicknessOptions
  readonly property var fpsOptions: root.active.fpsOptions
  readonly property var waveSmoothOptions: root.active.waveSmoothOptions
  readonly property var backends: root.active.backends

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"

  property bool topbar: false

  Process {
    id: mediaMigrate
    running: true
    command: ["sh", "-c", "cd \"$HOME/.cache/sharkshell\" 2>/dev/null || exit 0; for f in mode bars thickness fps width wave-smoothing backend; do [ -f \"visualizer-media-$f\" ] || cp \"visualizer-$f\" \"visualizer-media-$f\" 2>/dev/null || true; done"]
    onExited: root.mediaProfile.reloadAll()
  }

  function cycleMode() { root.active.cycleMode() }
  function cycleBars() { root.active.cycleBars() }
  function cycleWidth() { root.active.cycleWidth() }
  function cycleThickness() { root.active.cycleThickness() }
  function cycleFps() { root.active.cycleFps() }
  function cycleWaveSmoothing() { root.active.cycleWaveSmoothing() }
  function cycleBackend() { root.active.cycleBackend() }
  function fpsLabel() { return root.fps + " fps" }
  function waveSmoothLabel() {
    if (root.waveSmoothing <= 0) return "Off"
    return Math.round(root.waveSmoothing * 100) + "%"
  }
  function modeLabel() {
    if (root.mode === "wave") return "Wave"
    if (root.mode === "oscilloscope") return "Oscilloscope"
    return "Bars"
  }
  function widthLabel() { return root.visWidth + "px" }
  function backendLabel() { return root.backend === "cava" ? "Cava" : "Sharkvis" }
  function setBackend(v) { root.active.setBackend(v) }
  function stabilize(prev, next) { return root.active.stabilize(prev, next) }
  function command(mode, bars) { return root.active.command(mode, bars) }
  function setTopbar(v) {
    root.topbar = !!v
  }
  function toggleTopbar() {
    root.topbar = !root.topbar
  }
  function setSettingsTarget(v) {
    if (v === "topbar" || v === "media")
      root.settingsTarget = v
  }

  FileView {
    id: topbarFile
    path: root.cacheDir + "/visualizer-topbar"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim().toLowerCase()
      root.topbar = (t === "1" || t === "true" || t === "on")
    }
    onFileChanged: reload()
  }
  FileView {
    id: targetFile
    path: root.cacheDir + "/visualizer-settings-target"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t === "topbar" || t === "media") root.settingsTarget = t
    }
    onFileChanged: reload()
  }
  onTopbarChanged: topbarFile.setText(root.topbar ? "1" : "0")
  onSettingsTargetChanged: targetFile.setText(root.settingsTarget)
}
