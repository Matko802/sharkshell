pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DynamicColor.js" as DynColor

// Dynamic (wallpaper) theme, Noctalia-style.
//
// When disabled (default) everything uses the declarative Theme defaults
// and kitty + niri keep their static files.
// When enabled, one matugen run renders the app templates
// (~/.config/matugen, see sharkshell/matugen/) and dumps JSON that feeds
// the shell palette (Theme.*) with a smooth animated transition.
// App reloads (kitty SIGUSR1, niri load-config-file) are triggered here.
//
// Generated state lives in ~/.cache/sharkshell/ :
//   dynamic-theme-enabled  "1"/"0"
//   dynamic-scheme.json    cached matugen output
//   dynamic-scheme-wall    wallpaper path the cache belongs to
Scope {
  id: root

  property bool enabled: false
  property bool generating: false
  // True when the app files on disk (kitty/niri templates output) hold
  // dynamic content. Tracked because re-enabling with a matching cached
  // scheme must still re-render when the files hold defaults.
  property bool appsThemed: false

  // Flat map of material role name -> "#rrggbb" (dark scheme from matugen)
  property var roles: ({})

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"
  readonly property string kittyConfName: "kitty-dynamic.conf"
  // Separate folder for the niri selection (active) / inactive border theme.
  // Stock niri config includes this file; quickshell rewrites it.
  readonly property string niriDir: Quickshell.env("HOME") + "/.config/niri-dynamic"
  readonly property string niriBorders: root.niriDir + "/borders.kdl"

  function role(name, fallback) {
    return DynColor.validOr(root.roles[name], fallback)
  }

  // --- Shell palette: same background colors as the generated apps ---
  // bg matches the scheme background (and kitty) exactly.
  readonly property color dynBg: root.role("background", "#111111")
  readonly property color dynBgAlt: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.18)
  readonly property color dynFg: root.role("on_surface", "#ffffff")
  readonly property color dynOutline: root.role("primary", "#ffffff")
  readonly property color dynBorder: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.28)
  readonly property color dynBorderStrong: DynColor.mix(root.dynBg, root.role("primary", "#ffffff"), 0.45)
  readonly property color dynMuted: root.role("on_surface_variant", "#888888")
  readonly property color dynMuted2: DynColor.mix(root.role("on_surface_variant", "#888888"), root.dynBg, 0.45)
  readonly property color dynMuted3: DynColor.mix(root.role("on_surface_variant", "#888888"), root.dynBg, 0.70)

  // --- public API used by Theme.qml ---
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

  // Force a fresh matugen run (re-renders the app templates even when
  // the scheme is already cached - enabling must restore app files that
  // the disable path overwrote with defaults).
  function regenerate() {
    if (!root.enabled || root.generating)
      return
    root.lastDoneWall = "@@none@@"
    root.extractFor(WallpaperState.path)
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  onEnabledChanged: {
    enabledFile.setText(root.enabled ? "1" : "0")
    if (root.enabled) {
      // Cached scheme already drives the shell via bindings.
      // App files refresh below unless they already hold this scheme.
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

  // Wallpaper path the cached scheme was generated from.
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

  // Off-state files are flushed synchronously through bash (write and
  // app reloads happen in one chain, so reloads can never overtake
  // the writes).
  property string pendingKittyText: ""
  property string pendingNiriText: ""

  Process {
    id: defaultsProc
    command: ["bash", "-c",
      "printf '%s' " + root.shellQuote(root.pendingKittyText)
      + " > " + root.shellQuote(root.cacheDir + "/" + root.kittyConfName) + ";"
      + "printf '%s' " + root.shellQuote(root.pendingNiriText)
      + " > " + root.shellQuote(root.niriBorders) + ";"
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
    // One run renders the matugen templates (kitty + niri files) and
    // dumps the scheme JSON that feeds the shell palette.
    command: ["bash", "-c",
      "set -o pipefail;"
      + " mkdir -p " + root.shellQuote(root.cacheDir) + " " + root.shellQuote(root.niriDir) + ";"
      + " command -v matugen >/dev/null 2>&1 || exit 3;"
      + " wall=" + root.shellQuote(root.pendingWall) + ";"
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
        // Toggled off mid-run: matugen rendered dynamic files anyway,
        // so restore the off-state files and reload.
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
        // Templates were rendered above: reload the apps.
        root.appsThemed = true
        root.reloadKitty()
        root.reloadNiri()
      }
      root.lastDoneWall = root.pendingWall
      // wallpaper changed while we were working: catch up
      if (root.enabled && WallpaperState.path !== "" && WallpaperState.path !== root.lastDoneWall)
        root.extractFor(WallpaperState.path)
    }
  }

  Process {
    id: mkdirProc
    command: ["bash", "-c",
      "mkdir -p " + root.shellQuote(root.cacheDir) + " " + root.shellQuote(root.niriDir)]
    onExited: root.ensureOutputs()
  }

  Process {
    id: reloadProc
    command: ["pkill", "-USR1", "kitty"]
  }

  // File writes can still be flushing when a reload fires; the settle
  // timer re-fires both reloads once things have landed.
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
    }
  }

  // --- kitty defaults for dynamic-off (matugen templates cover on) ---
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
      foreground: "#ffffff",
      cursor: "#bbbbbb",
      selBg: "#b5d5ff",
      selFg: "#000000",
      ansi: ["#000000", "#ff5555", "#b2ffd5", "#fbffc2", "#8686ff", "#ff557d", "#25ffba", "#999999",
             "#545454", "#ff5555", "#55ff55", "#ffff55", "#5555ff", "#ff55ff", "#55ffff", "#ffffff"],
      tabActiveFg: "#444444",
      tabActiveBg: "#b5d5ff",
      tabInactiveFg: "#ffffff",
      tabInactiveBg: "#000000"
    }
  }

  Component.onCompleted: {
    if (!mkdirProc.running)
      mkdirProc.running = true
  }
}
