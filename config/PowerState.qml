pragma Singleton
import QtQuick

Scope {
  id: root

  property bool open: false
  property bool closePending: false

  function requestClose() {
    if (!root.open || root.closePending)
      return
    root.closePending = true
    closeTimer.restart()
  }

  function forceClose() {
    closeTimer.stop()
    closeCleanTimer.stop()
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
    onTriggered: root.open = false
  }

  Timer {
    id: closeCleanTimer
    interval: 250
    onTriggered: root.closePending = false
  }
}
