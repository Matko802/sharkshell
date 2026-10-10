pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool open: false
  property var screen: null

  IpcHandler {
    target: "settings"
    function toggle(): void { root.toggle(null) }
    function open(): void { root.open = true }
    function close(): void { root.open = false }
  }

  function toggle(win) {
    const s = win ? win.screen : null
    if (root.open && root.screen === s)
      root.open = false
    else {
      root.screen = s
      root.open = true
      ControlState.close()
      ClockState.close()
    }
  }

  property bool enterFromRight: false

  function openFromClock(win) {
    const s = win ? win.screen : null
    root.screen = s
    root.enterFromRight = true
    root.open = true
    ControlState.close()
  }

  function close() {
    root.open = false
  }
}
