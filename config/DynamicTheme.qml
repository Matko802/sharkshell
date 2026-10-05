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
  property var palettes: ({})
  property var wallColors: ([])

  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/sharkshell"
  readonly property string genDir: Quickshell.env("HOME") + "/.config/sharkshell"
  readonly property string kittyConfName: "kitty-dynamic.conf"
  readonly property string footConfName: "foot-dynamic.ini"
  readonly property string niriDir: Quickshell.env("HOME") + "/.config/sharkshell"
  readonly property string niriBorders: root.niriDir + "/niri/borders.kdl"

  function role(name, fallback) {
    return DynColor.validOr(root.roles[name], fallback)
  }

  function satRole(name, fallback, amt) {
    return DynColor.saturate(root.role(name, fallback), amt)
  }

  function pal(name, levels, fallback) {
    var p = root.palettes[name]
    if (p) {
      for (var i = 0; i < levels.length; i++) {
        var c = p[levels[i]]
        if (c && DynColor.isValid(c)) return String(c)
      }
    }
    return fallback
  }

  function palAll(name, levels) {
    var out = []
    var p = root.palettes[name]
    if (!p) return out
    if (levels) {
      for (var i = 0; i < levels.length; i++) {
        var c = p[levels[i]]
        if (c && DynColor.isValid(c)) out.push(String(c))
      }
      return out
    }
    for (var k in p) {
      if (p[k] && DynColor.isValid(p[k])) out.push(String(p[k]))
    }
    return out
  }

  readonly property color dynBg: root.role("background", "#111111")
  readonly property color dynBgAlt: DynColor.saturate(DynColor.mix(root.dynBg, root.role("secondary", "#ffffff"), 0.16), 0.3)
  readonly property color dynFg: root.role("on_surface", "#ffffff")
  readonly property color dynOutline: DynColor.saturate(root.role("primary", "#ffffff"), 0.5)
  readonly property color dynBorder: DynColor.saturate(DynColor.mix(root.dynBg, root.role("secondary", "#ffffff"), 0.30), 0.8)
  readonly property color dynBorderStrong: DynColor.saturate(DynColor.mix(root.dynBg, root.role("secondary", "#ffffff"), 0.48), 0.8)
  readonly property color dynMuted: root.role("on_surface_variant", "#888888")
  readonly property color dynMuted2: DynColor.saturate(DynColor.mix(DynColor.mix(root.role("on_surface_variant", "#888888"), root.role("tertiary", "#888888"), 0.35), root.dynBg, 0.30), 1.0)
  readonly property color dynMuted3: DynColor.saturate(DynColor.mix(DynColor.mix(root.role("on_surface_variant", "#888888"), root.role("tertiary", "#888888"), 0.35), root.dynBg, 0.60), 1.0)

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

  property bool darkMode: true
  property string cachedSchemeMode: ""
  property string appliedMode: ""

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

  onDarkModeChanged: {
    darkModeFile.setText(root.darkMode ? "1" : "0")
    if (!root.enabled)
      return
    var txt = root.darkMode ? root.schemeTextDark : root.schemeTextLight
    var wl = root.darkMode ? root.schemeWallDark : root.schemeWallLight
    if (txt !== "" && wl !== "" && wl === WallpaperState.path && root.applySchemeText(txt)) {
      root.appliedMode = root.schemeMode()
      root.appsThemed = true
      root.writeThemedKitty()
      root.reloadKitty()
      root.writeThemedNiri()
      root.reloadNiri()
    }
    root.regenerate()
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
      if (!root.appsThemed || WallpaperState.path !== root.schemeWall || root.cachedSchemeMode !== root.schemeMode())
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
    function setDark(v: bool): void { root.setDarkMode(v) }
    function toggleDark(): void { root.toggleDarkMode() }
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

  FileView {
    id: darkModeFile
    path: root.cacheDir + "/dynamic-theme-dark"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var t = text().trim()
      if (t !== "")
        root.darkMode = (t === "1")
    }
    onFileChanged: reload()
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
    }
  }

  FileView {
    id: schemeCacheDark
    path: root.cacheDir + "/dynamic-scheme-dark.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.schemeTextDark = text()
  }

  FileView {
    id: schemeCacheLight
    path: root.cacheDir + "/dynamic-scheme-light.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.schemeTextLight = text()
  }

  FileView {
    id: schemeWallDarkFile
    path: root.cacheDir + "/dynamic-scheme-wall-dark"
    watchChanges: false
    printErrors: false
    onLoaded: root.schemeWallDark = text().trim()
  }

  FileView {
    id: schemeWallLightFile
    path: root.cacheDir + "/dynamic-scheme-wall-light"
    watchChanges: false
    printErrors: false
    onLoaded: root.schemeWallLight = text().trim()
  }

  property string pendingKittyText: ""
  property string pendingFootText: ""
  property string pendingNiriText: ""

  Process {
    id: defaultsProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.niriDir + "/niri") + " " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingKittyText)
      + " > " + Util.shellQuote(root.genDir + "/kitty/" + root.kittyConfName) + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingFootText)
      + " > " + Util.shellQuote(root.genDir + "/foot/" + root.footConfName) + ";"
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
    root.pendingFootText = root.footText(root.defaultKittyColors())
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
    var bg = root.role("background", "#000000")
    var wc = root.wallColors.length > 0 ? root.wallColors : []

    var neutralAll = root.palAll("neutral")
    var blackCands = ["#000000"].concat(neutralAll).concat([root.role("surface_container_lowest", "#000000"), bg])
    if (wc.length > 0) blackCands = blackCands.concat(wc)
    var black = DynColor.pickDarkest(blackCands) || "#000000"

    var greyBase = root.pal("neutral", ["50", "60", "40", "35"], "#767872")
    var whiteBase = root.pal("neutral", ["80", "90", "70"], root.role("on_surface_variant", "#c6c7c1"))
    if (wc.length > 0) {
      var sortedByLum = wc.slice().sort(function(a, b) {
        return DynColor.luminance(a) - DynColor.luminance(b)
      })
      if (sortedByLum.length >= 6)
        greyBase = sortedByLum[Math.floor(sortedByLum.length * 0.45)]
      var lightCands = sortedByLum.filter(function(c) {
        var l = DynColor.lightnessOf(c)
        return l > 0.55 && l < 0.95
      })
      if (lightCands.length > 0) whiteBase = lightCands[lightCands.length - 1]
    }
    var grey = DynColor.ensureContrastOnDark(greyBase, bg, 3.5)
    var white = DynColor.ensureContrastOnDark(DynColor.vivid(whiteBase, 0.72, 0.1), bg, 7.0)
    var brightWhite = "#ffffff"

    var usedHues = []
    function takeHue(hue, minSat) {
      var c = DynColor.closestByHueExcluding(wc, hue, minSat, usedHues)
      if (c && DynColor.hueDist(DynColor.hueDeg(c), hue) > 65)
        return null
      if (c) usedHues.push(c)
      return c
    }
    var redBase = wc.length > 0 ? takeHue(0, 0.12) : null
    var greenBase = wc.length > 0 ? takeHue(120, 0.12) : null
    var yellowBase = wc.length > 0 ? takeHue(55, 0.15) : null
    var blueBase = wc.length > 0 ? takeHue(215, 0.15) : null
    var cyanBase = wc.length > 0 ? takeHue(185, 0.12) : null
    var magentaBase = wc.length > 0 ? takeHue(300, 0.12) : null

    var midLevels = ["30", "35", "40", "50", "60", "70"]
    if (!redBase)
      redBase = DynColor.pickExtreme(root.palAll("error", midLevels), DynColor.redness)
        || root.pal("error", ["50", "60", "40"], root.role("error", "#ff5449"))
    if (!greenBase)
      greenBase = DynColor.pickExtreme(root.palAll("primary", midLevels), DynColor.greenness)
        || root.pal("primary", ["60", "50", "70"], root.role("primary", "#4cc38a"))
    if (!cyanBase)
      cyanBase = DynColor.pickExtreme(root.palAll("tertiary", midLevels), DynColor.cyanness)
        || root.pal("tertiary", ["60", "70", "50"], root.role("tertiary", "#56b6c2"))
    if (!yellowBase) yellowBase = "#e5c07b"
    if (!blueBase) blueBase = "#61afef"
    if (!magentaBase) magentaBase = "#c678dd"

    var red = DynColor.ensureContrastOnDark(DynColor.vivid(redBase, 0.65, 0.8), bg, 4.5)
    var green = DynColor.ensureContrastOnDark(DynColor.vivid(greenBase, 0.65, 0.8), bg, 4.5)
    var yellow = DynColor.ensureContrastOnDark(DynColor.vivid(yellowBase, 0.65, 0.6), bg, 4.5)
    var blue = DynColor.ensureContrastOnDark(DynColor.vivid(blueBase, 0.65, 0.6), bg, 4.5)
    var magenta = DynColor.ensureContrastOnDark(DynColor.vivid(magentaBase, 0.65, 0.6), bg, 4.5)
    var cyan = DynColor.ensureContrastOnDark(DynColor.vivid(cyanBase, 0.65, 0.8), bg, 4.5)
    var redBright = DynColor.ensureContrastOnDark(DynColor.vivid(redBase, 0.75, 0.8), bg, 5.5)
    var greenBright = DynColor.ensureContrastOnDark(DynColor.vivid(greenBase, 0.75, 0.8), bg, 5.5)
    var yellowBright = DynColor.ensureContrastOnDark(DynColor.vivid(yellowBase, 0.75, 0.6), bg, 5.5)
    var blueBright = DynColor.ensureContrastOnDark(DynColor.vivid(blueBase, 0.75, 0.6), bg, 5.5)
    var magentaBright = DynColor.ensureContrastOnDark(DynColor.vivid(magentaBase, 0.75, 0.6), bg, 5.5)
    var cyanBright = DynColor.ensureContrastOnDark(DynColor.vivid(cyanBase, 0.75, 0.8), bg, 5.5)

    return {
      source: "pywal-style wallpaper hues + matugen UI",
      background: bg,
      foreground: root.dimBright(root.role("on_surface", "#ffffff")),
      cursor: root.role("primary", "#bbbbbb"),
      selBg: root.role("primary_container", "#b5d5ff"),
      selFg: root.dimBright(root.role("on_primary_container", "#000000")),
      ansi: [
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        grey,
        redBright,
        greenBright,
        yellowBright,
        blueBright,
        magentaBright,
        cyanBright,
        brightWhite
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
      "mkdir -p " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingKittyText)
      + " > " + Util.shellQuote(root.genDir + "/kitty/" + root.kittyConfName) + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingFootText)
      + " > " + Util.shellQuote(root.genDir + "/foot/" + root.footConfName) + ";"
      + " pkill -USR1 kitty >/dev/null 2>&1; exit 0"]
  }

  Process {
    id: footOnlyProc
    command: ["bash", "-c",
      "mkdir -p " + Util.shellQuote(root.genDir + "/foot") + ";"
      + "printf '%s' " + Util.shellQuote(root.pendingFootText)
      + " > " + Util.shellQuote(root.genDir + "/foot/" + root.footConfName) + "; exit 0"]
  }

  function writeThemedKitty() {
    root.pendingKittyText = root.kittyText(root.themedKittyColors())
    root.pendingFootText = root.footText(root.themedKittyColors())
    if (!kittyOnlyProc.running)
      kittyOnlyProc.running = true
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
    if (root.enabled && root.appsThemed)
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
    if (!obj || !obj.colors)
      return false
    var want = root.darkMode ? "dark" : "light"
    var map = {}
    for (var k in obj.colors) {
      var entry = obj.colors[k]
      if (!entry)
        continue
      var c = (entry[want] && entry[want].color) || (entry.default && entry.default.color) || entry.color || ""
      if (DynColor.isValid(c))
        map[k] = String(c)
    }
    if (!map["background"] || !map["primary"])
      return false
    root.roles = map
    var pmap = {}
    if (obj.palettes) {
      for (var pname in obj.palettes) {
        var pentry = obj.palettes[pname]
        if (!pentry) continue
        var lmap = {}
        for (var lvl in pentry) {
          var lentry = pentry[lvl]
          if (!lentry) continue
          var lc = (lentry[want] && lentry[want].color) || (lentry.default && lentry.default.color) || lentry.color || ""
          if (DynColor.isValid(lc))
            lmap[String(lvl)] = String(lc)
        }
        pmap[pname] = lmap
      }
    }
    root.palettes = pmap
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
    root.extractWallColors(root.pendingWall)
  }

  property string wallColorsWall: ""

  function extractWallColors(wall) {
    if (!wall || wall === "")
      return
    root.wallColorsWall = String(wall)
    magickProc.output = ""
    if (!magickProc.running)
      magickProc.running = true
  }

  Process {
    id: magickProc
    property string output: ""
    command: ["bash", "-c",
      " wall=" + Util.shellQuote(root.wallColorsWall) + ";"
      + " [ -f \"$wall\" ] || exit 4;"
      + " command -v magick >/dev/null 2>&1 || exit 3;"
      + " magick \"$wall\" -resize 200x200! -colors 16 -depth 8 -format \"%c\" histogram:info: 2>/dev/null"]
    stdout: SplitParser {
      onRead: function(data) {
        magickProc.output += data + "\n"
      }
    }
    onExited: function(exitCode) {
      var out = magickProc.output
      magickProc.output = ""
      if (exitCode !== 0 || out.trim() === "")
        return
      var cols = DynColor.parseHistogramColors(out)
      if (cols.length >= 4) {
        root.wallColors = cols
        if (root.enabled && root.appsThemed) {
          root.writeThemedKitty()
          root.reloadKitty()
        }
      }
    }
  }

  Process {
    id: extractProc
    property string output: ""
    command: ["bash", "-c",
      "set -o pipefail;"
      + " mkdir -p " + Util.shellQuote(root.cacheDir) + " " + Util.shellQuote(root.niriDir + "/niri") + " " + Util.shellQuote(root.genDir + "/kitty") + " " + Util.shellQuote(root.genDir + "/foot") + ";"
      + " command -v matugen >/dev/null 2>&1 || exit 3;"
      + " wall=" + Util.shellQuote(root.pendingWall) + ";"
      + " [ -f \"$wall\" ] || exit 4;"
      + " matugen image \"$wall\" --mode " + (root.darkMode ? "dark" : "light") + " -j hex --source-color-index 0 2>/dev/null"]
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
      }
      root.lastDoneWall = root.pendingWall
      if (root.enabled && WallpaperState.path !== "" && WallpaperState.path !== root.lastDoneWall)
        root.extractFor(WallpaperState.path)
      else if (root.enabled && root.appliedMode !== "" && root.appliedMode !== root.schemeMode()) {
        root.lastDoneWall = "@@none@@"
        root.extractFor(WallpaperState.path)
      }
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

  function writeThemedNiri() {
    var active = root.satRole("primary", "#ffffff", 0.5) + "ff"
    var inactive = root.role("surface_container_highest", "#444444") + "ff"
    niriBordersFile.setText(root.niriText(active, inactive))
  }

  FileView {
    id: niriBordersFile
    path: root.niriBorders
    watchChanges: false
    printErrors: false
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
    } else if (WallpaperState.path !== "") {
      root.extractWallColors(WallpaperState.path)
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
