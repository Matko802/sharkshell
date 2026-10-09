pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DynamicColor.js" as DynColor
import "Util.js" as Util

Scope {
  id: root

  readonly property bool enabled: true
  property bool generating: false
  property bool appsThemed: false

  property var roles: ({})

  readonly property color bg: root.role("background", "#111111")
  readonly property color bgAlt: root.role("surface_container", "#111111")
  readonly property color fg: root.role("on_surface", "#ffffff")
  readonly property color outline: root.role("primary", "#ffffff")
  readonly property color border: root.role("outline_variant", "#444444")
  readonly property color borderStrong: root.role("outline", "#888888")
  readonly property color muted: root.role("on_surface_variant", "#888888")
  readonly property color muted2: root.role("outline", "#888888")
  readonly property color muted3: root.role("outline_variant", "#444444")

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"
  readonly property string genDir: Quickshell.env("HOME") + "/.config/sharkshell"
  readonly property string kittyConfName: "kitty-dynamic.conf"
  readonly property string footConfName: "foot-dynamic.ini"
  readonly property string niriDir: Quickshell.env("HOME") + "/.config/sharkshell"
  readonly property string niriBorders: root.niriDir + "/niri/borders.kdl"

  function toCamel(name) {
    var parts = String(name).split("_")
    var out = parts[0]
    for (var i = 1; i < parts.length; i++)
      out += parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
    return out
  }

  function toSnake(name) {
    return String(name).replace(/([A-Z])/g, function(m) { return "_" + m.toLowerCase() })
  }

  function role(name, fallback) {
    if (root.roles[name] && DynColor.isValid(root.roles[name]))
      return String(root.roles[name])
    var c = root.toCamel(name)
    if (root.roles[c] && DynColor.isValid(root.roles[c]))
      return String(root.roles[c])
    var s = root.toSnake(name)
    if (root.roles[s] && DynColor.isValid(root.roles[s]))
      return String(root.roles[s])
    return DynColor.validOr(root.roles[name], fallback)
  }

  function setEnabled(v) {
  }

  function toggle() {
  }

  property bool darkMode: true
  property string cachedSchemeMode: ""
  property string appliedMode: ""
  property string generatingFor: ""
  property string scheme: "dynamic"
  property string flavour: "default"
  property string variant: "tonalspot"

  function setDarkMode(v) {
    root.darkMode = !!v
  }

  function toggleDarkMode() {
    root.setDarkMode(!root.darkMode)
  }

  function schemeMode() {
    return root.darkMode ? "dark" : "light"
  }

  property string schemeTextDark: ""
  property string schemeTextLight: ""
  property string schemeWallDark: ""
  property string schemeWallLight: ""

  property bool startupDone: false
  property int startupLoads: 0
  property bool startupTimedOut: false
  property bool settleKitty: false
  property bool settleNiri: false
  property bool kittyDirty: false
  property bool niriDirty: false
  property string appliedKittyText: ""
  property string appliedFootText: ""
  property string appliedNiriText: ""
  property string appliedGtkCss: ""
  property string appliedKdeText: ""

  function applyCachedNow() {
    var txt = root.darkMode ? root.schemeTextDark : root.schemeTextLight
    var wl = root.darkMode ? root.schemeWallDark : root.schemeWallLight
    if (txt === "" || wl === "")
      return false
    if (WallpaperState.path !== "" && wl !== WallpaperState.path)
      return false
    if (!root.applySchemeText(txt))
      return false
    root.appliedMode = root.schemeMode()
    root.appsThemed = true
    root.writeThemedKitty()
    root.reloadKitty()
    root.writeThemedNiri()
    root.reloadNiri()
    root.pushAppThemes()
    root.maybePrewarm()
    return true
  }

  function noteStartup() {
    if (root.startupDone)
      return
    root.startupLoads++
    root.maybeStartup()
  }

  function maybeStartup() {
    if (root.startupDone)
      return
    if (root.startupLoads < 8 && !root.startupTimedOut)
      return
    root.startupApply()
  }

  function startupApply() {
    if (root.startupDone)
      return
    root.startupDone = true
    if (root.applyCachedNow())
      return
    if (Object.keys(root.roles).length > 0) {
      root.appliedMode = root.schemeMode()
      root.appsThemed = true
      root.writeThemedKitty()
      root.reloadKitty()
      root.writeThemedNiri()
      root.reloadNiri()
      root.pushAppThemes()
      root.maybePrewarm()
      if (WallpaperState.path !== "" && WallpaperState.path !== root.schemeWall)
        root.regenerate()
      return
    }
    if (WallpaperState.path !== "")
      root.regenerate()
  }

  onDarkModeChanged: {
    darkModeFile.setText(root.darkMode ? "1" : "0")
    if (!root.applyCachedNow())
      root.regenerate()
  }

  function regenerate() {
    if (!root.startupDone || root.generating)
      return
    root.lastDoneWall = "@@none@@"
    root.extractFor(WallpaperState.path)
  }

  Connections {
    target: WallpaperState
    function onPathChanged() {
      if (!root.startupDone) {
        root.maybeStartup()
        return
      }
      root.regenerate()
    }
  }

  IpcHandler {
    target: "dynamictheme"
    function regenerate(): void { root.regenerate() }
    function setDark(v: bool): void { root.setDarkMode(v) }
    function toggleDark(): void { root.toggleDarkMode() }
    function state(): string {
      return "enabled=true darkMode=" + root.darkMode
        + " generating=" + root.generating + " appsThemed=" + root.appsThemed
        + " roles=" + Object.keys(root.roles).length
        + " scheme=" + root.scheme + "/" + root.flavour + "/" + root.variant
        + " wall=" + root.schemeWall
        + " startup=" + root.startupDone + "/" + root.startupLoads
    }
  }

  FileView {
    id: schemeCache
    path: root.cacheDir + "/dynamic-scheme.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "" && root.applySchemeText(t)) {
        root.appsThemed = true
        root.writeThemedKitty()
        root.reloadKitty()
        root.writeThemedNiri()
        root.reloadNiri()
        root.pushAppThemes()
      }
      root.noteStartup()
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
      root.noteStartup()
    }
  }

  FileView {
    id: darkModeFile
    path: root.cacheDir + "/dynamic-theme-dark"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "")
        root.darkMode = (t === "1")
      root.noteStartup()
    }
  }

  FileView {
    id: schemeModeFile
    path: root.cacheDir + "/dynamic-scheme-mode"
    watchChanges: false
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t === "dark" || t === "light")
        root.cachedSchemeMode = t
      root.noteStartup()
    }
  }

  FileView {
    id: schemeCacheDark
    path: root.cacheDir + "/dynamic-scheme-dark.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.schemeTextDark = text()
      root.noteStartup()
    }
  }

  FileView {
    id: schemeCacheLight
    path: root.cacheDir + "/dynamic-scheme-light.json"
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.schemeTextLight = text()
      root.noteStartup()
    }
  }

  FileView {
    id: schemeWallDarkFile
    path: root.cacheDir + "/dynamic-scheme-wall-dark"
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.schemeWallDark = text().trim()
      root.noteStartup()
    }
  }

  FileView {
    id: schemeWallLightFile
    path: root.cacheDir + "/dynamic-scheme-wall-light"
    watchChanges: false
    printErrors: false
    onLoaded: {
      root.schemeWallLight = text().trim()
      root.noteStartup()
    }
  }

  property string pendingKittyText: ""
  property string pendingFootText: ""
  property string pendingNiriText: ""

  function themedKittyColors() {
    var t = []
    for (var ti = 0; ti < 16; ti++)
      t.push(root.role("term" + ti, "#000000"))
    return {
      source: "caelestia dynamic scheme (" + root.scheme + "/" + root.flavour + "/" + root.variant + ")",
      background: root.role("background", "#000000"),
      foreground: root.role("on_surface", "#ffffff"),
      cursor: root.role("primary", "#bbbbbb"),
      selBg: root.role("secondary", "#b5d5ff"),
      selFg: root.role("surface", "#000000"),
      ansi: t,
      tabActiveFg: root.role("inverse_on_surface", "#444444"),
      tabActiveBg: root.role("primary", "#b5d5ff"),
      tabInactiveFg: root.role("on_surface_variant", "#ffffff"),
      tabInactiveBg: root.role("surface", "#000000")
    }
  }

  Process {
    id: kittyOnlyProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingKittyText)
      + " > " + Util.shellQuote(root.genDir + "/kitty/" + root.kittyConfName) + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingFootText)
      + " > " + Util.shellQuote(root.genDir + "/foot/" + root.footConfName) + ";"
      + " exit 0"]
  }

  Process {
    id: footOnlyProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.genDir + "/foot") + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingFootText)
      + " > " + Util.shellQuote(root.genDir + "/foot/" + root.footConfName) + "; exit 0"]
  }

  function writeThemedKitty() {
    var tc = root.themedKittyColors()
    var kt = root.kittyText(tc)
    var ft = root.footText(tc)
    if (kt === root.appliedKittyText && ft === root.appliedFootText)
      return false
    root.pendingKittyText = kt
    root.pendingFootText = ft
    root.appliedKittyText = kt
    root.appliedFootText = ft
    root.kittyDirty = true
    if (!kittyOnlyProc.running)
      kittyOnlyProc.running = true
    return true
  }

  function writeThemedFoot() {
    root.pendingFootText = root.footText(root.themedKittyColors())
    if (!footOnlyProc.running)
      footOnlyProc.running = true
  }

  function writeDefaultFoot() {
    root.pendingFootText = root.footText(root.defaultKittyColors())
    if (!footOnlyProc.running)
      footOnlyProc.running = true
  }

  function refreshFoot() {
    if (root.appsThemed || Object.keys(root.roles).length > 0)
      root.writeThemedFoot()
    else
      root.writeDefaultFoot()
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
    if (!obj)
      return false
    if (obj.colours) {
      if (typeof obj.mode === "string" && (obj.mode === "dark" || obj.mode === "light") && obj.mode !== root.schemeMode())
        return false
      var cmap = obj.colours
      var cmapCheck = cmap["background"] && cmap["primary"]
      if (!cmapCheck)
        return false
      var nmap = {}
      for (var ck in cmap) {
        var cv = cmap[ck]
        if (typeof cv === "string" && /^[0-9a-fA-F]{6}$/.test(cv))
          nmap[ck] = "#" + String(cv).toLowerCase()
        else if (DynColor.isValid(cv))
          nmap[ck] = String(cv)
      }
      if (!nmap["background"] || !nmap["primary"])
        return false
      root.roles = nmap
      if (typeof obj.name === "string" && obj.name !== "")
        root.scheme = obj.name
      if (typeof obj.flavour === "string" && obj.flavour !== "")
        root.flavour = obj.flavour
      if (typeof obj.variant === "string" && obj.variant !== "")
        root.variant = obj.variant
      if (root.pendingWall !== "")
        root.schemeWall = root.pendingWall
      return true
    }
    return false
  }

  property string pendingWall: ""
  property string lastDoneWall: "@@none@@"
  property string retryWall: ""
  property string schemeWall: ""

  function extractFor(wall) {
    if (root.generating)
      return
    if (!wall || wall === "")
      return
    root.pendingWall = String(wall)
    if (root.pendingWall === root.lastDoneWall)
      return
    extractProc.output = ""
    root.generating = true
    root.generatingFor = root.schemeMode()
    extractProc.running = true
  }

  Process {
    id: extractProc
    property string output: ""
    command: ["bash", "-c",
      "set -o pipefail;"
      + " mkdir -p " + Util.shellQuote(root.cacheDir) + " " + Util.shellQuote(root.niriDir + "/niri") + " " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + ";"
      + " wall=" + Util.shellQuote(root.pendingWall) + ";"
      + " [ -f \"$wall\" ] || exit 4;"
      + " mode=" + (root.darkMode ? "dark" : "light") + ";"
      + " SC=\"\";"
      + " if command -v shark-colors >/dev/null 2>&1; then SC=$(shark-colors \"$wall\" --mode \"$mode\" 2>/dev/null); fi;"
      + " if [ -z \"$SC\" ] && command -v caelestia >/dev/null 2>&1; then SC=$(caelestia wallpaper -p \"$wall\" --no-smart 2>/dev/null); fi;"
      + " if [ -n \"$SC\" ]; then printf '%s' \"$SC\";"
      + " else exit 3; fi"]
    stdout: SplitParser {
      onRead: function(data) {
        extractProc.output += data + "\n"
      }
    }
    onExited: function(exitCode) {
      root.generating = false
      var stale = (root.generatingFor !== "" && root.generatingFor !== root.schemeMode())
      root.generatingFor = ""
      if (stale) {
        root.regenerate()
        return
      }
      if (exitCode !== 0 || extractProc.output.trim() === "") {
        if (root.retryWall !== root.pendingWall) {
          root.retryWall = root.pendingWall
          retryTimer.restart()
        }
        return
      }
      if (WallpaperState.path !== "" && WallpaperState.path !== root.pendingWall) {
        root.retryWall = ""
        root.extractFor(WallpaperState.path)
        return
      }
      var out = extractProc.output
      extractProc.output = ""
      if (out.trim() === "")
        return
      if (root.applySchemeText(out)) {
        root.retryWall = ""
        schemeCache.setText(out)
        schemeWallFile.setText(root.schemeWall)
        schemeModeFile.setText(root.schemeMode())
        if (root.darkMode) {
          root.schemeTextDark = out
          root.schemeWallDark = root.schemeWall
          schemeCacheDark.setText(out)
          schemeWallDarkFile.setText(root.schemeWall)
        } else {
          root.schemeTextLight = out
          root.schemeWallLight = root.schemeWall
          schemeCacheLight.setText(out)
          schemeWallLightFile.setText(root.schemeWall)
        }
        root.cachedSchemeMode = root.schemeMode()
        root.appliedMode = root.schemeMode()
        root.appsThemed = true
        root.writeThemedKitty()
        root.reloadKitty()
        root.writeThemedNiri()
        root.reloadNiri()
        root.pushAppThemes()
      }
      root.maybePrewarm()
      root.lastDoneWall = root.pendingWall
      if (WallpaperState.path !== "" && WallpaperState.path !== root.lastDoneWall)
        root.extractFor(WallpaperState.path)
      root.maybePrewarm()
    }
  }

  function storePrewarmText(text, mode, wall) {
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
    if (!obj || !obj.colours || obj.mode !== mode)
      return false
    if (!obj.colours["background"] || !obj.colours["primary"])
      return false
    if (wall === "" || wall !== WallpaperState.path)
      return false
    if (mode === "dark") {
      root.schemeTextDark = text
      root.schemeWallDark = wall
      schemeCacheDark.setText(text)
      schemeWallDarkFile.setText(wall)
    } else if (mode === "light") {
      root.schemeTextLight = text
      root.schemeWallLight = wall
      schemeCacheLight.setText(text)
      schemeWallLightFile.setText(wall)
    } else {
      return false
    }
    return true
  }

  function maybePrewarm() {
    if (root.generating || prewarmProc.running)
      return
    if (root.schemeWall === "" || WallpaperState.path === "" || WallpaperState.path !== root.schemeWall)
      return
    var other = root.darkMode ? "light" : "dark"
    var otxt = root.darkMode ? root.schemeTextLight : root.schemeTextDark
    var ow = root.darkMode ? root.schemeWallLight : root.schemeWallDark
    if (otxt !== "" && ow === root.schemeWall)
      return
    prewarmProc.wall = root.schemeWall
    prewarmProc.mode = other
    prewarmProc.output = ""
    prewarmProc.running = true
  }

  Process {
    id: prewarmProc
    property string output: ""
    property string wall: ""
    property string mode: ""
    command: ["bash", "-c",
      "set -o pipefail;"
      + " wall=" + Util.shellQuote(prewarmProc.wall) + ";"
      + " [ -f \"$wall\" ] || exit 4;"
      + " SC=\"\";"
      + " if command -v shark-colors >/dev/null 2>&1; then SC=$(shark-colors \"$wall\" --mode " + Util.shellQuote(prewarmProc.mode) + " 2>/dev/null); fi;"
      + " if [ -z \"$SC\" ] && command -v caelestia >/dev/null 2>&1; then SC=$(caelestia wallpaper -p \"$wall\" --no-smart 2>/dev/null); fi;"
      + " if [ -n \"$SC\" ]; then printf '%s' \"$SC\";"
      + " else exit 3; fi"]
    stdout: SplitParser {
      onRead: function(data) {
        prewarmProc.output += data + "\n"
      }
    }
    onExited: function(exitCode) {
      var out = prewarmProc.output
      var md = prewarmProc.mode
      var wl = prewarmProc.wall
      prewarmProc.output = ""
      if (exitCode !== 0 || out.trim() === "")
        return
      root.storePrewarmText(out, md, wl)
    }
  }

  Process {
    id: mkdirProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.cacheDir) + " " + Util.shellQuote(root.niriDir + "/niri") + " " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + " " + Util.shellQuote(Quickshell.env("HOME") + "/.config/qtengine")]
    onExited: root.ensureOutputs()
  }

  Process {
    id: reloadProc
    command: ["pkill", "-USR1", "kitty"]
  }

  Timer {
    id: settleTimer
    interval: 800
    onTriggered: {
      if (root.settleKitty && !reloadProc.running)
        reloadProc.running = true
      root.settleKitty = false
      if (root.settleNiri && !niriReloadProc.running)
        niriReloadProc.running = true
      root.settleNiri = false
    }
  }

  Timer {
    id: startupTimer
    interval: 4000
    running: true
    repeat: false
    onTriggered: {
      root.startupTimedOut = true
      root.maybeStartup()
    }
  }

  Timer {
    id: retryTimer
    interval: 2500
    repeat: false
    onTriggered: {
      if (root.retryWall !== "" && !root.generating)
        root.extractFor(root.retryWall)
    }
  }

  function reloadKitty() {
    if (!root.kittyDirty)
      return
    root.kittyDirty = false
    root.settleKitty = true
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
    if (!root.niriDirty)
      return
    root.niriDirty = false
    root.settleNiri = true
    settleTimer.restart()
  }

  function niriText(active, inactive) {
    return "// Generated by sharkshell dynamic theme - do not edit.\n"
      + "layout {\n  border {\n"
      + "    active-color \"" + active + "\"\n"
      + "    inactive-color \"" + inactive + "\"\n"
      + "  }\n}\n"
  }

  function writeThemedNiri() {
    var nt = root.niriText(root.role("primary", "#ffffff") + "ff", root.role("surface_container_highest", "#444444") + "ff")
    if (nt === root.appliedNiriText)
      return false
    root.appliedNiriText = nt
    root.niriDirty = true
    niriBordersFile.setText(nt)
    return true
  }

  function pushAppThemes() {
    var css = AppTheme.gtkCssText()
    var kde = AppTheme.kdeColorsText()
    if (css === root.appliedGtkCss && kde === root.appliedKdeText)
      return
    root.appliedGtkCss = css
    root.appliedKdeText = kde
    AppTheme.push()
  }

  FileView {
    id: niriBordersFile
    path: root.niriBorders
    watchChanges: false
    printErrors: false
  }

  function ensureOutputs() {
    if (Object.keys(root.roles).length === 0 && WallpaperState.path !== "") {
      root.regenerate()
    } else if (WallpaperState.path !== "") {
      root.maybePrewarm()
    }
    root.maybeStartup()
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

  function footHex(hex) {
    var m = /^#?([0-9a-fA-F]{6})/.exec(String(hex || ""))
    return m ? m[1].toLowerCase() : "ffffff"
  }

  function footAlpha() {
    var op = 1.0
    try {
      op = TransparencyState.transparent ? TransparencyState.terminalOpacity : 1.0
    } catch (e) {
    }
    return String(Math.round(Math.min(1, Math.max(0, op)) * 100) / 100)
  }

  function footText(o) {
    var L = []
    L.push("# Generated by sharkshell dynamic theme - do not edit.")
    L.push("# Source: " + o.source)
    L.push("[colors-dark]")
    L.push("background=" + root.footHex(o.background))
    L.push("foreground=" + root.footHex(o.foreground))
    L.push("selection-background=" + root.footHex(o.selBg))
    L.push("selection-foreground=" + root.footHex(o.selFg))
    L.push("alpha=" + root.footAlpha())
    for (var i = 0; i < 8; i++)
      L.push("regular" + i + "=" + root.footHex(o.ansi[i]))
    for (var j = 8; j < 16; j++)
      L.push("bright" + (j - 8) + "=" + root.footHex(o.ansi[j]))
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
