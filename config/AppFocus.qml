pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  Process { id: runProc; running: false }

  function focus(n) {
    const raw = n ? (n.desktopEntry || n.appName || "") : ""
    if (!raw) return
    const app = String(raw).replace(/"/g, '\\"')
    runProc.command = ["sh", "-c",
      "ID=$(niri msg -j windows 2>/dev/null | tr '}' '\\n' | grep -i \"" + app + "\" | head -1 | grep -o '\"id\":[0-9]*' | cut -d: -f2)"
      + " && [ -n \"$ID\" ] && niri msg action focus-window --id \"$ID\" 2>/dev/null"
    ]
    runProc.running = true
  }
}
