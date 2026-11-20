pragma Singleton
import QtQuick
import Quickshell

Scope {
  id: root

  property bool open: false
  property bool closePending: false

  function requestClose() {
    if (!root.open || root.closePending)
      return
    root.open = false
    root.closePending = true
    closeTimer.restart()
  }

  function forceClose() {
    closeTimer.stop()
    root.closePending = false
    root.open = false
  }

  function toggle() {
    if (root.open) {
      root.requestClose()
      return
    }
    closeTimer.stop()
    root.closePending = false
    root.open = true
  }

  Timer {
    id: closeTimer
    interval: 250
    onTriggered: root.closePending = false
  }
}
