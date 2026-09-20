pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  readonly property real def: 16
  readonly property real max: 32
  property real radius: root.def

  function setRadius(v) {
    v = parseFloat(v)
    if (isNaN(v)) return
    root.radius = Math.min(root.max, Math.max(0, v))
  }

  function reset() {
    root.setRadius(root.def)
  }

  onRadiusChanged: radiusFile.setText(String(Math.round(root.radius * 10) / 10))

  IpcHandler {
    target: "blur"
    function set(v: real): void { root.setRadius(v) }
    function reset(): void { root.reset() }
  }

  FileView {
    id: radiusFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/blur-radius"
    watchChanges: true
    printErrors: false
    onLoaded: {
      const v = parseFloat(text().trim())
      if (!isNaN(v)) root.radius = Math.min(root.max, Math.max(0, v))
    }
    onFileChanged: reload()
  }

  Process {
    id: mkdirProc
    running: true
    command: ["bash", "-c", "mkdir -p \"$HOME/.cache/sharkshell\""]
  }
}
