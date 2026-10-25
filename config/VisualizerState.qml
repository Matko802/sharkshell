pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string mode: "bars"
  property int bars: 48
  property bool topbar: false
  property string backend: "sharkvis"
  readonly property var modes: ["bars", "wave", "oscilloscope"]
  readonly property var barOptions: [24, 32, 48, 64]
  readonly property var backends: ["sharkvis", "cava"]
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"

  readonly property string cavaConf: "[general]\nbars = " + root.bars + "\nframerate = 15\n[input]\nmethod = pulse\nsource = auto\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n"

  function cycleMode() {
    var i = root.modes.indexOf(root.mode)
    root.mode = root.modes[(i + 1) % root.modes.length]
  }
  function cycleBars() {
    var i = root.barOptions.indexOf(root.bars)
    root.bars = root.barOptions[(i + 1) % root.barOptions.length]
  }
  function modeLabel() {
    if (root.mode === "wave") return "Wave"
    if (root.mode === "oscilloscope") return "Oscilloscope"
    return "Bars"
  }
  function setBackend(v) {
    if (root.backends.indexOf(v) >= 0)
      root.backend = v
  }
  function cycleBackend() {
    root.backend = root.backend === "sharkvis" ? "cava" : "sharkvis"
  }
  function backendLabel() {
    return root.backend === "cava" ? "Cava" : "Sharkvis"
  }
  function command(mode, bars) {
    const cfg = "$HOME/.cache/sharkshell/cava.conf"
    const local = "/mnt/ssd/My-Files/Projects/sharkvis/target/release/sharkvis"
    const sharkvis = "if [ -x \"" + local + "\" ]; then exec \"" + local + "\" --raw --raw-mode \"" + mode + "\" --bars " + bars + " --fps 15; elif command -v sharkvis >/dev/null 2>&1; then exec sharkvis --raw --raw-mode \"" + mode + "\" --bars " + bars + " --fps 15; fi"
    const cava = "if command -v cava >/dev/null 2>&1; then exec cava -p \"" + cfg + "\"; fi"
    if (root.backend === "cava")
      return cava + "; " + sharkvis + "; exit 0"
    return sharkvis + "; " + cava + "; exit 0"
  }
  function setTopbar(v) {
    root.topbar = !!v
  }
  function toggleTopbar() {
    root.topbar = !root.topbar
  }

  FileView {
    id: modeFile
    path: root.cacheDir + "/visualizer-mode"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "" && root.modes.indexOf(t) >= 0) root.mode = t
    }
    onFileChanged: reload()
  }
  FileView {
    id: barsFile
    path: root.cacheDir + "/visualizer-bars"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = parseInt(text().trim(), 10)
      if (!isNaN(t) && root.barOptions.indexOf(t) >= 0) root.bars = t
    }
    onFileChanged: reload()
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
    id: backendFile
    path: root.cacheDir + "/visualizer-backend"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "" && root.backends.indexOf(t) >= 0) root.backend = t
    }
    onFileChanged: reload()
  }
  FileView {
    id: cavaConfFile
    path: root.cacheDir + "/cava.conf"
    printErrors: false
  }
  Process {
    id: cavaConfInit
    running: true
    command: ["mkdir", "-p", root.cacheDir]
    onExited: cavaConfFile.setText(root.cavaConf)
  }
  onModeChanged: modeFile.setText(root.mode)
  onBarsChanged: {
    barsFile.setText(String(root.bars))
    cavaConfFile.setText(root.cavaConf)
  }
  onTopbarChanged: topbarFile.setText(root.topbar ? "1" : "0")
  onBackendChanged: backendFile.setText(root.backend)
}
