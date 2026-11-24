pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string mode: "bars"
  property int bars: 48
  property int thickness: 1
  property int fps: 15
  property int visWidth: 140
  property double waveSmoothing: 0.5
  property bool topbar: false
  property bool sharkvisAvailable: false
  property bool cavaAvailable: false
  readonly property bool visualizerAvailable: root.sharkvisAvailable || root.cavaAvailable
  readonly property var modes: ["bars", "wave", "oscilloscope"]
  readonly property var barOptions: [24, 32, 48, 64]
  readonly property var widthOptions: [80, 100, 120, 140, 160, 180, 200, 240]
  readonly property var thicknessOptions: [1, 2, 3, 4]
  readonly property var fpsOptions: [10, 15, 20, 30, 45, 60, 90, 120, 144, 165, 240]
  readonly property var waveSmoothOptions: [0, 0.25, 0.5, 0.75, 0.9, 0.95]
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"
  readonly property string localSharkvis: "/mnt/ssd/My-Files/Projects/sharkvis/target/release/sharkvis"

  function cavaConfText() {
    return "[general]\nbars = " + root.bars + "\nframerate = " + root.fps + "\n[input]\nmethod = pulse\nsource = auto\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n"
  }

  function cycleMode() {
    var i = root.modes.indexOf(root.mode)
    root.mode = root.modes[(i + 1) % root.modes.length]
  }
  function cycleBars() {
    var i = root.barOptions.indexOf(root.bars)
    root.bars = root.barOptions[(i + 1) % root.barOptions.length]
  }
  function cycleWidth() {
    var i = root.widthOptions.indexOf(root.visWidth)
    if (i < 0) {
      root.visWidth = root.widthOptions[3]
      return
    }
    root.visWidth = root.widthOptions[(i + 1) % root.widthOptions.length]
  }
  function widthLabel() {
    return root.visWidth + "px"
  }
  function cycleThickness() {
    var i = root.thicknessOptions.indexOf(root.thickness)
    root.thickness = root.thicknessOptions[(i + 1) % root.thicknessOptions.length]
  }
  function cycleFps() {
    var i = root.fpsOptions.indexOf(root.fps)
    if (i < 0) {
      root.fps = root.fpsOptions[1]
      return
    }
    root.fps = root.fpsOptions[(i + 1) % root.fpsOptions.length]
  }
  function cycleWaveSmoothing() {
    var i = root.waveSmoothOptions.indexOf(root.waveSmoothing)
    if (i < 0) {
      root.waveSmoothing = root.waveSmoothOptions[2]
      return
    }
    root.waveSmoothing = root.waveSmoothOptions[(i + 1) % root.waveSmoothOptions.length]
  }
  function fpsLabel() {
    return root.fps + " fps"
  }
  function waveSmoothLabel() {
    if (root.waveSmoothing <= 0) return "Off"
    return Math.round(root.waveSmoothing * 100) + "%"
  }
  function stabilize(prev, next) {
    if (!next || next.length === 0) return next
    var s = Math.max(0, Math.min(0.95, root.waveSmoothing))
    if (s <= 0) return next
    var k = Math.pow(s, 60 / Math.max(1, root.fps))
    var same = prev && prev.length === next.length
    var out = []
    for (var i = 0; i < next.length; i++) {
      var target = next[i]
      var base = same ? prev[i] : target
      out.push(base + (target - base) * (1 - k))
    }
    return out
  }
  function modeLabel() {
    if (root.mode === "wave") return "Wave"
    if (root.mode === "oscilloscope") return "Oscilloscope"
    return "Bars"
  }
  function command(mode, bars) {
    const cfg = "$HOME/.cache/sharkshell/cava.conf"
    const sharkvis = "if [ -x \"" + root.localSharkvis + "\" ]; then exec \"" + root.localSharkvis + "\" --raw --raw-mode \"" + mode + "\" --bars " + bars + " --fps " + root.fps + "; elif command -v sharkvis >/dev/null 2>&1; then exec sharkvis --raw --raw-mode \"" + mode + "\" --bars " + bars + " --fps " + root.fps + "; fi"
    const cava = "if command -v cava >/dev/null 2>&1; then exec cava -p \"" + cfg + "\"; fi"
    return sharkvis + "; " + cava + "; exit 0"
  }
  function checkBackends() {
    if (!backendCheck.running)
      backendCheck.running = true
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
    id: widthFile
    path: root.cacheDir + "/visualizer-width"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = parseInt(text().trim(), 10)
      if (!isNaN(t) && root.widthOptions.indexOf(t) >= 0) root.visWidth = t
    }
    onFileChanged: reload()
  }
  FileView {
    id: thicknessFile
    path: root.cacheDir + "/visualizer-thickness"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = parseInt(text().trim(), 10)
      if (!isNaN(t) && root.thicknessOptions.indexOf(t) >= 0) root.thickness = t
    }
    onFileChanged: reload()
  }
  FileView {
    id: fpsFile
    path: root.cacheDir + "/visualizer-fps"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = parseInt(text().trim(), 10)
      if (!isNaN(t) && root.fpsOptions.indexOf(t) >= 0) root.fps = t
    }
    onFileChanged: reload()
  }
  FileView {
    id: waveSmoothFile
    path: root.cacheDir + "/visualizer-wave-smoothing"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = parseFloat(text().trim())
      if (!isNaN(t) && t >= 0 && t <= 0.95) root.waveSmoothing = t
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
    id: cavaConfFile
    path: root.cacheDir + "/cava.conf"
    printErrors: false
  }
  Process {
    id: cavaConfInit
    running: true
    command: ["mkdir", "-p", root.cacheDir]
    onExited: cavaConfFile.setText(root.cavaConfText())
  }
  property bool foundSharkvis: false
  property bool foundCava: false
  Process {
    id: backendCheck
    running: true
    command: ["sh", "-c", "if [ -x \"" + root.localSharkvis + "\" ] || command -v sharkvis >/dev/null 2>&1; then echo sharkvis; fi; if command -v cava >/dev/null 2>&1; then echo cava; fi"]
    onStarted: {
      root.foundSharkvis = false
      root.foundCava = false
    }
    stdout: SplitParser {
      onRead: data => {
        const t = String(data).trim()
        if (t === "sharkvis") root.foundSharkvis = true
        else if (t === "cava") root.foundCava = true
      }
    }
    onExited: {
      root.sharkvisAvailable = root.foundSharkvis
      root.cavaAvailable = root.foundCava
    }
  }
  onModeChanged: modeFile.setText(root.mode)
  onBarsChanged: {
    barsFile.setText(String(root.bars))
    cavaConfFile.setText(root.cavaConfText())
  }
  onThicknessChanged: thicknessFile.setText(String(root.thickness))
  onVisWidthChanged: widthFile.setText(String(root.visWidth))
  onFpsChanged: {
    fpsFile.setText(String(root.fps))
    cavaConfFile.setText(root.cavaConfText())
  }
  onWaveSmoothingChanged: waveSmoothFile.setText(String(root.waveSmoothing))
  onTopbarChanged: topbarFile.setText(root.topbar ? "1" : "0")
}
