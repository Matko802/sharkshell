pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string mode: "bars"
  property int bars: 48
  readonly property var modes: ["bars", "wave", "oscilloscope"]
  readonly property var barOptions: [24, 32, 48, 64]
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"

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
  onModeChanged: modeFile.setText(root.mode)
  onBarsChanged: barsFile.setText(String(root.bars))
}
