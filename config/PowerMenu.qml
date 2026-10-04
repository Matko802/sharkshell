import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  property bool open: false
  property bool closePending: false
  property int selIdx: 0
  property int hoverIdx: -1
  readonly property string fontFamily: Theme.fontFamily
  readonly property int tile: 112
  readonly property int tileSpacing: 8

  function requestClose() {
    if (!root.open || root.closePending)
      return
    root.closePending = true
    closeTimer.restart()
  }
  function forceClose() {
    closeTimer.stop()
    root.closePending = false
    root.open = false
  }

  Timer {
    id: closeTimer
    interval: 250
    onTriggered: {
      root.open = false
      closeCleanTimer.restart()
    }
  }

  Timer {
    id: closeCleanTimer
    interval: 250
    onTriggered: {
      root.closePending = false
    }
  }

  function toggle() {
    if (root.open) {
      root.requestClose()
      return
    }
    closeTimer.stop()
    root.closePending = false
    root.open = true
    root.selIdx = 0
    root.hoverIdx = -1
    meminfo.reload()
  }

  IpcHandler {
    target: "power"
    function toggle() {
      root.toggle()
    }
    function close() {
      root.forceClose()
    }
  }

  property bool canHibernate: true

  FileView {
    id: meminfo
    path: "/proc/meminfo"
    watchChanges: false
    printErrors: false
    onLoaded: {
      let mem = 0, swap = 0
      for (const line of text().split("\n")) {
        const m = line.match(/^(MemTotal|SwapTotal):\s+(\d+)/)
        if (m) {
          if (m[1] === "MemTotal") mem = parseInt(m[2])
          else swap = parseInt(m[2])
        }
      }
      if (mem > 0) root.canHibernate = swap >= mem
    }
  }

  readonly property var allEntries: [
    { name: "Lock", icon: "lock", cmd: ["quickshell", "ipc", "call", "lock", "lock"] },
    { name: "Hibernate", icon: "hibernate", cmd: ["sh", "-c", "systemctl hibernate"] },
    { name: "Log out", icon: "logout", cmd: ["sh", "-c", "if command -v niri >/dev/null 2>&1; then niri msg action quit --skip-confirmation; else mmsg dispatch quit 2>/dev/null || loginctl terminate-user \"\" 2>/dev/null || systemctl --user exit; fi"] },
    { name: "Reboot", icon: "reboot", cmd: ["sh", "-c", "systemctl reboot"] },
    { name: "Shutdown", icon: "shutdown", cmd: ["sh", "-c", "systemctl poweroff"] },
    { name: "Suspend", icon: "suspend", cmd: ["sh", "-c", "quickshell ipc call lock lock; systemctl suspend -i"] }
  ]
  readonly property var entries: root.canHibernate ? root.allEntries : root.allEntries.filter(e => e.name !== "Hibernate")
  onEntriesChanged: {
    if (root.selIdx >= root.entries.length)
      root.selIdx = Math.max(0, root.entries.length - 1)
    if (root.hoverIdx >= root.entries.length)
      root.hoverIdx = -1
  }

  function move(step) {
    root.selIdx = Math.max(0, Math.min(root.entries.length - 1, root.selIdx + step))
  }

  function activate(i) {
    const entry = root.entries[i]
    if (!entry)
      return
    root.forceClose()
    runProc.command = entry.cmd
    runProc.running = true
  }

  Process {
    id: runProc
  }

  PanelWindow {
    id: menuWindow
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { item: panel.anchors.topMargin >= 30 ? panel : null }
    mask: Region { item: panel }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: root.open || root.closePending

    Rectangle {
      id: panel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: root.open ? 30 : -220
      width: root.entries.length * root.tile + Math.max(0, root.entries.length - 1) * root.tileSpacing + 32
      height: root.tile + 32
      color: Theme.bg
      opacity: (panel.anchors.topMargin + 220) / 250
      border.color: Theme.outline
      border.width: 1
      Behavior on anchors.topMargin { NumberAnimation { duration: 170; easing.type: Easing.OutExpo } }
      Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activate(root.selIdx)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
          root.move(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
          root.move(1)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
          root.move(1)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
          root.move(-1)
          event.accepted = true
        }
      }

      MouseArea { anchors.fill: parent }

      Row {
        id: tileRow
        anchors.centerIn: parent
        spacing: root.tileSpacing

        Repeater {
          model: root.entries

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: root.tile
            height: root.tile
            readonly property bool isSel: root.selIdx === index
            readonly property bool isHover: root.hoverIdx === index
            readonly property bool active: isSel || isHover
            color: active ? Theme.outline : Theme.bg
            border.color: Theme.outline
            border.width: 1

            Column {
              anchors.centerIn: parent
              spacing: 8

              QIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: modelData.icon
                size: 34
                color: parent.parent.active ? Theme.bg : Theme.fg
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.name
                color: parent.parent.active ? Theme.bg : Theme.fg
                font.family: root.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.hoverIdx = index; root.selIdx = index }
              onExited: { if (root.hoverIdx === index) root.hoverIdx = -1 }
              onClicked: root.activate(index)
            }
          }
        }
      }
    }
  }
}
