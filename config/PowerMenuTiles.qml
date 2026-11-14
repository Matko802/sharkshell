import QtQuick
import Quickshell.Io

Rectangle {
  id: root

  property bool open: false
  readonly property string fontFamily: Theme.fontFamily
  readonly property int tile: 112
  readonly property int tileSpacing: 8
  property bool canHibernate: true
  property int selIdx: 0
  property int hoverIdx: -1

  readonly property var allEntries: [
    { name: "Lock", icon: "lock", cmd: ["quickshell", "ipc", "call", "lock", "lock"] },
    { name: "Hibernate", icon: "hibernate", cmd: ["sh", "-c", "systemctl hibernate"] },
    { name: "Log out", icon: "logout", cmd: ["sh", "-c", Env.logoutScript] },
    { name: "Reboot", icon: "reboot", cmd: ["sh", "-c", "systemctl reboot"] },
    { name: "Shutdown", icon: "shutdown", cmd: ["sh", "-c", "systemctl poweroff"] },
    { name: "Suspend", icon: "suspend", cmd: ["sh", "-c", "quickshell ipc call lock lock; systemctl suspend -i"] }
  ]
  readonly property var entries: root.canHibernate ? root.allEntries : root.allEntries.filter(e => e.name !== "Hibernate")

  width: root.entries.length * root.tile + Math.max(0, root.entries.length - 1) * root.tileSpacing + 32
  height: root.tile + 32
  color: Theme.bg
  border.color: Theme.outline
  border.width: 1

  onOpenChanged: {
    if (open) {
      root.selIdx = 0
      root.hoverIdx = -1
      meminfo.reload()
    }
  }

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
    PowerState.forceClose()
    runProc.command = entry.cmd
    runProc.running = true
  }

  Process {
    id: runProc
  }

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
