pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property string kind: "off"
  property int sig: 0
  property string ssid: ""
  property bool wifiEnabled: false
  property string iface: ""
  property real downRate: 0
  property real upRate: 0

  property var networks: []
  property bool scanning: false
  property string connecting: ""
  property string lastError: ""
  property bool expanded: false
  property string activeSsid: ""
  property var knownSsids: []
  property string failedSsid: ""
  property var ethIfaces: []
  property string modeIntent: ""

  readonly property bool hasEthernet: ethIfaces.length > 0
  readonly property string mode: modeIntent !== "" ? modeIntent : ((kind === "eth" || (!wifiEnabled && hasEthernet)) ? "eth" : "wifi")

  readonly property bool online: kind === "eth" || kind === "wifi"
  readonly property string icon: {
    if (kind === "eth")
      return "network-wired"
    if (kind === "wifi")
      return sigIcon(sig)
    return "wifi-off"
  }

  function sigIcon(s) {
    const names = ["wifi-none", "wifi-weak", "wifi-ok", "wifi-good", "wifi-excellent"]
    let idx = Math.floor(s / 20)
    idx = Math.min(4, Math.max(0, idx))
    if (s >= 100) idx = 4
    else if (s === 0) idx = 0
    return names[idx]
  }

  function fmtRate(r) {
    r = Math.max(0, Math.round(r))
    if (r < 1024)
      return r + " B/s"
    if (r < 1048576)
      return (r / 1024).toFixed(1) + " KiB/s"
    return (r / 1048576).toFixed(1) + " MiB/s"
  }

  readonly property string tooltip: {
    if (kind === "wifi")
      return (ssid || "wifi") + " (" + sig + "%)\n↓ " + fmtRate(downRate) + "  ↑ " + fmtRate(upRate)
    if (kind === "eth")
      return (iface || "ethernet") + "\n↓ " + fmtRate(downRate) + "  ↑ " + fmtRate(upRate)
    return "no network"
  }

  function toggleWifi() {
    const target = root.wifiEnabled ? "off" : "on"
    console.log("[net] toggling wifi radio:", target)
    toggleProc.command = ["/run/current-system/sw/bin/nmcli", "radio", "wifi", target]
    toggleProc.running = true
    if (!root.wifiEnabled)
      scanTimer.restart()
  }

  Process {
    id: toggleProc
    onExited: ok => console.log("[net] toggle exit code:", ok)
    stderr: StdioCollector {
      onStreamFinished: {
        if (this.text.trim() !== "")
          console.log("[net] toggle stderr:", this.text.trim())
      }
    }
  }

  function selectMode(target) {
    if (modeProc.running || (target !== "eth" && target !== "wifi"))
      return
    if (target === "wifi" && root.mode === "wifi" && root.wifiEnabled)
      return
    if (target === "eth" && root.mode === "eth" && root.kind === "eth")
      return
    root.modeIntent = target
    modeIntentTimer.restart()
    if (target === "eth") {
      console.log("[net] selecting ethernet")
      root.wifiEnabled = false
      root.expanded = false
      modeProc.command = ["sh", "-c", "nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{print $1}' | while read -r d; do nmcli device connect \"$d\" >/dev/null 2>&1; done; nmcli radio wifi off"]
    } else {
      console.log("[net] selecting wifi")
      root.wifiEnabled = true
      root.expanded = true
      modeProc.command = ["sh", "-c", "nmcli radio wifi on; nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{print $1}' | while read -r d; do nmcli device disconnect \"$d\" >/dev/null 2>&1; done"]
      scanTimer.restart()
    }
    modeProc.running = true
  }

  Process {
    id: modeProc
    onExited: ok => console.log("[net] mode switch exit code:", ok)
    stderr: StdioCollector {
      onStreamFinished: {
        if (this.text.trim() !== "")
          console.log("[net] mode switch stderr:", this.text.trim())
      }
    }
  }

  function scan() {
    if (!root.wifiEnabled)
      return
    root.scanning = true
    if (scanProc.running)
      scanProc.running = false
    scanProc.running = true
    if (knownProc.running)
      knownProc.running = false
    knownProc.running = true
  }

  Process {
    id: knownProc
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          if (!line.endsWith(":802-11-wireless"))
            continue
          out.push(line.slice(0, -16).replace(/\\:/g, ":"))
        }
        root.knownSsids = out
      }
    }
  }

  function forget(ssid) {
    if (forgetProc.running || root.knownSsids.indexOf(ssid) < 0)
      return
    forgetProc.ssid = ssid
    forgetProc.command = ["nmcli", "connection", "delete", ssid]
    root.lastError = ""
    forgetProc.running = true
  }

  Process {
    id: forgetProc
    property string ssid: ""
    onExited: code => {
      if (code === 0) {
        console.log("[net] forgot", forgetProc.ssid)
        root.knownSsids = root.knownSsids.filter(s => s !== forgetProc.ssid)
      } else {
        root.lastError = "failed to forget " + forgetProc.ssid
        errTimer.restart()
      }
      scanTimer.restart()
    }
  }

  function connectTo(ssid, password) {
    if (root.connecting !== "")
      return
    root.lastError = ""
    root.failedSsid = ""
    root.connecting = ssid
    connProc.command = password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password] : ["nmcli", "device", "wifi", "connect", ssid]
    connProc.running = true
  }

  function reportConnectDone(ok) {
    const was = root.connecting
    root.connecting = ""
    if (!ok)
      root.lastError = "failed to connect to " + was
    else {
      root.activeSsid = was
      root.failedSsid = ""
    }
    errTimer.restart()
    scanTimer.restart()
  }

  Timer {
    id: errTimer
    interval: 3000
    onTriggered: root.lastError = ""
  }

  Timer {
    id: scanTimer
    interval: 800
    onTriggered: root.scan()
  }

  Timer {
    id: modeIntentTimer
    interval: 5000
    onTriggered: root.modeIntent = ""
  }

  Process {
    id: scanProc
    command: ["nmcli", "-t", "-e", "no", "-f", "in-use,signal,security,ssid", "device", "wifi", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const seen = {}
        const list = []
        this.text.split("\n").forEach(line => {
          if (!line.trim())
            return
          const p = line.split(":")
          if (p.length < 3)
            return
          const inUse = p[0] === "*"
          const signal = parseInt(p[1]) || 0
          const secure = (p[2] || "").trim() !== ""
          const name = p.slice(3).join(":")
          if (!name)
            return
          if (seen[name] !== undefined) {
            if (signal > seen[name].sig) {
              seen[name].sig = signal
              seen[name].secure = seen[name].secure || secure
            }
            seen[name].active = seen[name].active || inUse
            return
          }
          const obj = {
            "ssid": name,
            "sig": signal,
            "secure": secure,
            "active": inUse
          }
          seen[name] = obj
          list.push(obj)
        })
        list.sort((a, b) => (b.active - a.active) || (b.sig - a.sig))
        root.networks = list
        root.scanning = false
      }
    }
  }

  Process {
    id: connProc
    onExited: ok => root.reportConnectDone(ok === 0)
  }

  onExpandedChanged: {
    if (root.expanded)
      root.scan()
  }

  Process {
    id: watcher
    running: !IdleManager.gaming
    command: ["stdbuf", "-oL", "sh", "-c", "L=\"\"; PR=-1; PT=-1; while :; do R=$(nmcli radio wifi 2>/dev/null); K=off; S=0; N=\"\"; IF=\"\"; if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^ethernet:connected'; then K=eth; IF=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"ethernet\"&&$3==\"connected\"{print $1; exit}'); else L2=$(nmcli -t -f in-use,signal,ssid dev wifi 2>/dev/null | grep '^\\*' | head -n1); if [ -n \"$L2\" ]; then K=wifi; S=$(printf '%s' \"$L2\" | cut -d: -f2); N=$(printf '%s' \"$L2\" | cut -d: -f3-); IF=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$2==\"wifi\"&&$3==\"connected\"{print $1; exit}'); fi; fi; AC=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$NF==\"wifi\"{sub(/:wifi$/,\"\");print;exit}'); ED=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"ethernet\"{printf \"%s,\",$1}'); RX=$(cat /sys/class/net/$IF/statistics/rx_bytes 2>/dev/null || echo 0); TX=$(cat /sys/class/net/$IF/statistics/tx_bytes 2>/dev/null || echo 0); DN=0; UP=0; if [ -n \"$IF\" ] && [ \"$PR\" -ge 0 ]; then DN=$(((RX-PR)/2)); UP=$(((TX-PT)/2)); fi; [ $DN -lt 0 ] && DN=0; [ $UP -lt 0 ] && UP=0; PR=$RX; PT=$TX; V=\"kind:$K|sig:$S|ssid:$N|radio:$R|if:$IF|dn:$DN|up:$UP|ac:$AC|eth:$ED\"; if [ \"$V\" != \"$L\" ]; then printf '%s\\n' \"$V\"; L=\"$V\"; fi; sleep 2; done"]
    stdout: SplitParser {
      onRead: data => {
        let k = "off", s = 0, n = "", r = "", ifn = "", dn = 0, up = 0
        data.split("|").forEach(seg => {
          const i = seg.indexOf(":")
          if (i < 0)
            return
          const key = seg.slice(0, i)
          const val = seg.slice(i + 1)
          if (key === "kind") k = val
          else if (key === "sig") s = parseInt(val) || 0
          else if (key === "ssid") n = val
          else if (key === "radio") r = val
          else if (key === "if") ifn = val
          else if (key === "dn") dn = parseInt(val) || 0
          else if (key === "up") up = parseInt(val) || 0
          else if (key === "ac") root.activeSsid = val
          else if (key === "eth") root.ethIfaces = val.split(",").filter(x => x !== "")
        })
        root.kind = k
        root.sig = s
        root.ssid = n
        root.wifiEnabled = r.trim() === "enabled"
        root.iface = ifn
        root.downRate = dn
        root.upRate = up
      }
    }
  }
}
