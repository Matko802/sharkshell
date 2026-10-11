pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
  id: root

  property bool autoSaver: false

  readonly property bool onBattery: UPower.onBattery
  readonly property bool saving: root.autoSaver && root.onBattery

  function setAutoSaver(v) {
    root.autoSaver = !!v
  }

  function toggleAutoSaver() {
    root.autoSaver = !root.autoSaver
  }

  IpcHandler {
    target: "perf"
    function get(): string { return root.saving ? "saving" : "normal" }
    function setAuto(v: bool): void { root.setAutoSaver(v) }
  }

  onAutoSaverChanged: autoFile.setText(root.autoSaver ? "1" : "0")

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
