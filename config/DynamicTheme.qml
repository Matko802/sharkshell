pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DynamicColor.js" as DynColor
import "Util.js" as Util

Scope {
  id: root

  property bool enabled: false
  property bool generating: false
  property bool appsThemed: false

  property var roles: ({})

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"
  readonly property string kittyConfName: "kitty-dynamic.conf"
  readonly property string niriDir: Quickshell.env("HOME") + "/.config/niri-dynamic"
  readonly property string niriBorders: root.niriDir + "/borders.kdl"

  function role(name, fallback) {
    return DynColor.validOr(root.roles[name], fallback)
  }

  readonly property color dynBg: root.role("background", "#111111")
  readonly property color dynBgAlt: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.18)
  readonly property color dynFg: root.role("on_surface", "#ffffff")
  readonly property color dynOutline: root.role("primary", "#ffffff")
  readonly property color dynBorder: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.28)
  readonly property color dynBorderStrong: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.45)
  readonly property color dynMuted: root.role("on_surface_variant", "#888888")
  readonly property color dynMuted2: DynColor.mix(root.role("on_surface_variant", "#888888"), root.dynBg, 0.45)
  readonly property color dynMuted3: DynColor.mix(root.role("on_surface_variant", "#888888"), root.dynBg, 0.70)

  readonly property color bg: root.dynBg
  readonly property color bgAlt: root.dynBgAlt
  readonly property color fg: root.dynFg
  readonly property color outline: root.dynOutline
  readonly property color border: root.dynBorder
  readonly property color borderStrong: root.dynBorderStrong
  readonly property color muted: root.dynMuted
  readonly property color muted2: root.dynMuted2
  readonly property color muted3: root.dynMuted3

  function setEnabled(v) {
    root.enabled = !!v
  }

  function toggle() {
    root.setEnabled(!root.enabled)
  }

  function regenerate() {
    if (!root.enabled || root.generating)
      return
    root.lastDoneWall = "@@none@@"
    root.extractFor(WallpaperState.path)
  }

  onEnabledChanged: {
    enabledFile.setText(root.enabled ? "1" : "0")
    if (root.enabled) {
      if (!root.appsThemed || WallpaperState.path !== root.schemeWall)
        root.regenerate()
    } else {
      root.appsThemed = false
      root.restoreDefaults()
    }
  }

  Connections {
    target: WallpaperState
    function onPathChanged() {
      if (root.enabled)
        root.regenerate()
    }
  }

  IpcHandler {
    target: "dynamictheme"
    function toggle(): void { root.toggle() }
    function enable(): void { root.setEnabled(true) }
    function disable(): void { root.setEnabled(false) }
    function regenerate(): void { root.regenerate() }
  }

  FileView {
    id: enabledFile
    path: root.cacheDir + "/dynamic-theme-enabled"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "")
        root.enabled = (t === "1")
    }
    onFileChanged: reload()
  }

  FileView {
    id: schemeCache
    path: root.cacheDir + "/dynamic-scheme.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "")
        root.applySchemeText(t)
    }
  }

  FileView {
    id: schemeWallFile
    path: root.cacheDir + "/dynamic-scheme-wall"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "")
        root.schemeWall = t
    }
  }

  property string pendingKittyText: ""
  property string pendingNiriText: ""

  Process {
    id: defaultsProc
    command: ["bash", "-c",
      "printf '%s' " + Util.shellQuote(root.pendingKittyText)
      + " > " + Util.shellQuote(root.cacheDir + "/" + root.kittyConfName) + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingNiriText)
      + " > " + Util.shellQuote(root.niriBorders) + ";"
      + " pkill -USR1 kitty >/dev/null 2>&1;"
      + " rt=\"$XDG_RUNTIME_DIR\"; [ -z \"$rt\" ] && rt=\"/run/user/$(id -u)\";"
      + " for s in \"$rt\"/niri.*.sock; do"
      + " [ -S \"$s\" ] || continue;"
      + " NIRI_SOCKET=\"$s\" niri msg action load-config-file >/dev/null 2>&1;"
      + " done; exit 0"]
  }

  function restoreDefaults() {
    root.pendingKittyText = root.kittyText(root.defaultKittyColors())
    root.pendingNiriText = root.niriText("#ffffffff", "#444444ff")
    if (!defaultsProc.running)
      defaultsProc.running = true
  }

  function dimRow(hex) {
    var m = /^#?([0-9a-fA-F]{6})/.exec(String(hex || ""))
    if (!m) return String(hex)
    function hx(v) {
      var c = Math.max(0, Math.min(255, Math.round(v * 0.8)))
      var h = c.toString(16)
      return h.length < 2 ? "0" + h : h
    }
    return "#" + hx(parseInt(m[1].substr(0, 2), 16)) + hx(parseInt(m[1].substr(2, 2), 16)) + hx(parseInt(m[1].substr(4, 2), 16))
  }

  function dimBright(hex) {
    var m = /^#?([0-9a-fA-F]{6})/.exec(String(hex || ""))
    if (!m) return String(hex)
    var r = parseInt(m[1].substr(0, 2), 16)
    var g = parseInt(m[1].substr(2, 2), 16)
    var b = parseInt(m[1].substr(4, 2), 16)
    var mx = Math.max(r, Math.max(g, b))
    if (mx <= 200) return "#" + m[1].toLowerCase()
    var s = 200 / mx
    function hx(v) {
      var c = Math.max(0, Math.min(255, Math.round(v)))
      var h = c.toString(16)
      return h.length < 2 ? "0" + h : h
    }
    return "#" + hx(r * s) + hx(g * s) + hx(b * s)
  }

  function themedKittyColors() {
    return {
      source: "matugen scheme (white levels dimmed)",
      background: root.role("background", "#000000"),
      foreground: root.dimBright(root.role("on_surface", "#ffffff")),
      cursor: root.role("primary", "#bbbbbb"),
      selBg: root.role("primary_container", "#b5d5ff"),
      selFg: root.dimBright(root.role("on_primary_container", "#000000")),
      ansi: [
        root.role("surface", "#000000"),
        root.role("error", "#ff5555"),
        root.role("primary", "#55ff55"),
        root.role("secondary", "#ffff55"),
        root.role("tertiary", "#5555ff"),
        root.role("tertiary_fixed_dim", "#ff55ff"),
        root.role("secondary_fixed_dim", "#55ffff"),
        root.dimBright(root.role("on_surface_variant", "#999999")),
        root.dimRow(root.role("outline_variant", "#545454")),
        root.dimRow(root.role("on_error_container", "#ff5555")),
        root.dimRow(root.role("on_tertiary_container", "#55ff55")),
        root.dimRow(root.role("on_secondary_container", "#ffff55")),
        root.dimRow(root.role("primary_fixed", "#5555ff")),
        root.dimRow(root.role("secondary_fixed", "#ff55ff")),
        root.dimRow(root.role("tertiary_fixed", "#55ffff")),
        root.dimRow(root.role("on_surface", "#ffffff"))
      ],
      tabActiveFg: root.role("inverse_on_surface", "#444444"),
      tabActiveBg: root.role("primary", "#b5d5ff"),
      tabInactiveFg: root.dimBright(root.role("on_surface_variant", "#ffffff")),
      tabInactiveBg: root.role("surface", "#000000")
    }
  }

  Process {
    id: kittyOnlyProc
    command: ["bash", "-c",
      "printf '%s' " + Util.shellQuote(root.pendingKittyText)
      + " > " + Util.shellQuote(root.cacheDir + "/" + root.kittyConfName) + ";"
      + " pkill -USR1 kitty >/dev/null 2>&1; exit 0"]
  }

  function writeThemedKitty() {
    root.pendingKittyText = root.kittyText(root.themedKittyColors())
    if (!kittyOnlyProc.running)
      kittyOnlyProc.running = true
  }

  function applySchemeText(text) {
    var obj = null
    try {
      var start = text.indexOf("{")
      var end = text.lastIndexOf("}")
      if (start < 0 || end <= start)
        return false
      obj = JSON.parse(text.slice(start, end + 1))
    } catch (e) {
      return false
    }
    if (!obj || !obj.colors)
      return false
    var map = {}
    for (var k in obj.colors) {
      var entry = obj.colors[k]
      if (!entry)
        continue
      var c = (entry.dark && entry.dark.color) || entry.color || (entry.default && entry.default.color) || ""
      if (DynColor.isValid(c))
        map[k] = String(c)
    }
    if (!map["background"] || !map["primary"])
      return false
    root.roles = map
    if (root.pendingWall !== "")
      root.schemeWall = root.pendingWall
    return true
  }

  property string pendingWall: ""
  property string lastDoneWall: "@@none@@"
  property string schemeWall: ""

  function extractFor(wall) {
    if (!root.enabled || root.generating)
      return
    if (!wall || wall === "")
      return
    root.pendingWall = String(wall)
    if (root.pendingWall === root.lastDoneWall)
      return
    extractProc.output = ""
    root.generating = true
    extractProc.running = true
  }

  Process {
    id: extractProc
    property string output: ""
    command: ["bash", "-c",
      "set -o pipefail;"
      + " mkdir -p " + Util.shellQuote(root.cacheDir) + " " + Util.shellQuote(root.niriDir) + ";"
      + " command -v matugen >/dev/null 2>&1 || exit 3;"
      + " wall=" + Util.shellQuote(root.pendingWall) + ";"
      + " [ -f \"$wall\" ] || exit 4;"
      + " matugen image \"$wall\" --mode dark -j hex --source-color-index 0 2>/dev/null"]
    stdout: SplitParser {
      onRead: function(data) {
        extractProc.output += data + "\n"
      }
    }
    onExited: function(exitCode) {
      root.generating = false
      if (!root.enabled) {
        root.appsThemed = false
        root.restoreDefaults()
        return
      }
      if (exitCode !== 0)
        return
      var out = extractProc.output
      extractProc.output = ""
      if (out.trim() === "")
        return
      if (root.applySchemeText(out)) {
        schemeCache.setText(out)
        schemeWallFile.setText(root.schemeWall)
        root.appsThemed = true
        root.writeThemedKitty()
        root.reloadKitty()
        root.reloadNiri()
      }
      root.lastDoneWall = root.pendingWall
      if (root.enabled && WallpaperState.path !== "" && WallpaperState.path !== root.lastDoneWall)
        root.extractFor(WallpaperState.path)
    }
  }

  Process {
    id: mkdirProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.cacheDir) + " " + Util.shellQuote(root.niriDir)]
    onExited: root.ensureOutputs()
  }

  Process {
    id: reloadProc
    command: ["pkill", "-USR1", "kitty"]
  }

  Timer {
    id: settleTimer
    interval: 1500
    onTriggered: {
      if (!reloadProc.running)
        reloadProc.running = true
      if (!niriReloadProc.running)
        niriReloadProc.running = true
    }
  }

  function reloadKitty() {
    if (!reloadProc.running)
      reloadProc.running = true
    settleTimer.restart()
  }

  Process {
    id: niriReloadProc
    command: ["bash", "-c",
      "rt=\"$XDG_RUNTIME_DIR\"; [ -z \"$rt\" ] && rt=\"/run/user/$(id -u)\";"
      + " for s in \"$rt\"/niri.*.sock; do"
      + " [ -S \"$s\" ] || continue;"
      + " NIRI_SOCKET=\"$s\" niri msg action load-config-file >/dev/null 2>&1;"
      + " done; exit 0"]
  }

  function reloadNiri() {
    if (!niriReloadProc.running)
      niriReloadProc.running = true
    settleTimer.restart()
  }

  function niriText(active, inactive) {
    return "// Generated by sharkshell dynamic theme - do not edit.\n"
      + "layout {\n  border {\n"
      + "    active-color \"" + active + "\"\n"
      + "    inactive-color \"" + inactive + "\"\n"
      + "  }\n}\n"
  }

  function ensureOutputs() {
    if (!root.enabled) {
      root.appsThemed = false
      root.restoreDefaults()
    } else if (Object.keys(root.roles).length === 0 && WallpaperState.path !== "") {
      root.regenerate()
    } else if (Object.keys(root.roles).length === 0) {
      root.appsThemed = false
      root.restoreDefaults()
    }
  }

  function kittyText(o) {
    var L = []
    L.push("# Generated by sharkshell dynamic theme - do not edit.")
    L.push("# Source: " + o.source)
    L.push("background " + o.background)
    L.push("foreground " + o.foreground)
    L.push("cursor " + o.cursor)
    L.push("selection_background " + o.selBg)
    L.push("selection_foreground " + o.selFg)
    for (var i = 0; i < 16; i++)
      L.push("color" + i + " " + o.ansi[i])
    L.push("active_tab_foreground " + o.tabActiveFg)
    L.push("active_tab_background " + o.tabActiveBg)
    L.push("inactive_tab_foreground " + o.tabInactiveFg)
    L.push("inactive_tab_background " + o.tabInactiveBg)
    return L.join("\n") + "\n"
  }

  function defaultKittyColors() {
    return {
      source: "static default (dynamic theme off)",
      background: "#000000",
      foreground: "#e0e0e0",
      cursor: "#bbbbbb",
      selBg: "#b5d5ff",
      selFg: "#000000",
      ansi: ["#000000", "#ff5555", "#b2ffd5", "#fbffc2", "#8686ff", "#ff557d", "#25ffba", "#999999",
             "#434343", "#cc4444", "#44cc44", "#cccc44", "#4444cc", "#cc44cc", "#44cccc", "#b3b3b3"],
      tabActiveFg: "#444444",
      tabActiveBg: "#b5d5ff",
      tabInactiveFg: "#e0e0e0",
      tabInactiveBg: "#000000"
    }
  }

  Component.onCompleted: {
    if (!mkdirProc.running)
      mkdirProc.running = true
  }
}
