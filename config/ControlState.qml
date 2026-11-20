pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool open: false
  property var screen: null
  property int sliderDrags: 0

  IpcHandler {
    target: "control"
    function toggle(): void { root.toggle(null) }
    function close(): void { root.close() }
  }

  function toggle(win) {
    const s = win ? win.screen : null
    if (root.open && root.screen === s)
      root.open = false
    else {
      root.screen = s
      root.open = true
      ClockState.close()
      SettingsState.close()
    }
  }

  function close() {
    root.open = false
  }
}
