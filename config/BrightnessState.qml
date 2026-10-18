pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property bool available: false
  property string device: ""
  property real bright: -1

  function set(p) {
    if (!root.available)
      return
    if (setProc.running)
      return
    setProc.pct = Math.round(Math.min(1, Math.max(0, p)) * 100)
    setProc.command = root.setCommand(setProc.pct)
    setProc.running = true
  }

  function setCommand(pct) {
    const dev = root.device
    let s = "if command -v brightnessctl >/dev/null 2>&1; then"
    s += " brightnessctl --quiet set " + pct + "%;"
    s += " elif [ -n \"" + dev + "\" ]; then"
    s += " m=$(cat /sys/class/backlight/" + dev + "/max_brightness 2>/dev/null);"
    s += " v=$((m * " + pct + " / 100));"
    s += " [ \"$v\" -lt 1 ] && v=1;"
    s += " busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager SetBrightness ssu backlight \"" + dev + "\" \"$v\";"
    s += " fi"
    return ["bash", "-c", s]
  }

  Process {
    id: watcher
    running: true
    command: ["stdbuf", "-oL", "bash", "-c",
      "L=\"\"; while :; do"
      + " D=$(ls /sys/class/backlight 2>/dev/null | head -n1);"
      + " A=no; V=-1; M=-1;"
      + " if [ -n \"$D\" ]; then"
      + " A=yes;"
      + " M=$(cat /sys/class/backlight/$D/max_brightness 2>/dev/null);"
      + " V=$(cat /sys/class/backlight/$D/brightness 2>/dev/null);"
      + " fi;"
      + " X=\"a:$A|d:$D|v:$V|m:$M\";"
      + " if [ \"$X\" != \"$L\" ]; then printf '%s\\n' \"$X\"; L=\"$X\"; fi;"
      + " sleep 2; done"]
    stdout: SplitParser {
      onRead: data => {
        let a = "no", d = "", v = -1, m = -1
        data.split("|").forEach(seg => {
          const i = seg.indexOf(":")
          if (i < 0)
            return
          const key = seg.slice(0, i)
          const val = seg.slice(i + 1)
          if (key === "a") a = val
          else if (key === "d") d = val
          else if (key === "v") v = parseInt(val)
          else if (key === "m") m = parseInt(val)
        })
        root.available = a === "yes"
        root.device = d
        root.bright = v >= 0 && m > 0 ? Math.min(1, Math.max(0, v / m)) : -1
      }
    }
  }

  Process {
    id: setProc
    property int pct: 50
  }
}
