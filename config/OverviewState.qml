pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool open: false

  Process {
    id: niriWatch
    running: true
    command: ["sh", "-c", "command -v niri >/dev/null 2>&1 && stdbuf -oL niri msg -j event-stream 2>/dev/null || sleep 999999"]
    stdout: SplitParser {
      onRead: data => {
        try {
          const j = JSON.parse(data)
          const o = j.OverviewOpenedOrClosed
          if (o !== undefined)
            root.open = !!o.is_open
        } catch (e) {
        }
      }
    }
  }
}
