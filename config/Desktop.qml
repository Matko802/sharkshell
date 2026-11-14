import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "Util.js" as Util

PanelWindow {
  id: root

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-desktop"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  BackgroundEffect.blurRegion: Region {
    Region { item: root.menuOpen ? menu : null }
    Region { item: root.banding && root.bandMoved ? band : null }
  }

  readonly property string desktopDir: Quickshell.env("HOME") + "/Plocha"
  readonly property int cellW: 128
  readonly property int cellH: 108
  readonly property int iconSize: 68
  readonly property int leftMargin: 16
  readonly property int topMargin: 46
  readonly property int bottomMargin: 16
  readonly property int gapX: 8
  readonly property int gapY: 4
  readonly property int rows: Math.max(1, Math.floor((height - topMargin - bottomMargin + gapY) / (cellH + gapY)))

  property var entries: []
  property var selectedPaths: []
  property var iconPositions: ({})
  property var layout: ({})
  property bool positionsLoaded: false
  property bool iconDragging: false
  property var dragOrigins: ({})
  property var dragPositions: ({})
  property string lastRows: ""
  property string pendingSelectPath: ""
  property bool iconsHidden: false
  property bool menuOpen: false
  property int menuIndex: -1
  property real menuX: 0
  property real menuY: 0
  property bool banding: false
  property bool bandMoved: false
  property real bandStartX: 0
  property real bandStartY: 0
  property real bandEndX: 0
  property real bandEndY: 0
  property var bandBase: []

  onEntriesChanged: root.rebuildLayout()
  onIconPositionsChanged: root.rebuildLayout()
  onWidthChanged: root.rebuildLayout()
  onHeightChanged: root.rebuildLayout()

  readonly property var menuItems: {
    if (root.menuIndex >= 0) {
      return [
        { label: root.selectedPaths.length > 1 ? "Open Selected" : "Open", icon: "go-next", action: "open" },
        { label: "Open Containing Folder", icon: "folder-open", action: "folder" },
        { label: "Copy Path", icon: "content-copy", action: "copy" }
      ]
    }
    return [
      { label: "New Folder", icon: "plus", action: "newfolder" },
      { label: "Open Desktop Folder", icon: "folder-open", action: "folder" },
      { label: "Open Terminal Here", icon: "terminal", action: "terminal" },
      { label: "Change Wallpaper", icon: "wallpaper", action: "wallpaper" },
      {
        label: root.iconsHidden ? "Show Icons" : "Hide Icons",
        icon: root.iconsHidden ? "eye" : "eye-off",
        action: "toggleicons"
      }
    ]
  }

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }

  function isSelected(path) {
    return root.selectedPaths.indexOf(path) >= 0
  }

  function selectOnly(path) {
    root.selectedPaths = [path]
  }

  function toggleSelected(path) {
    const list = root.selectedPaths.slice()
    const idx = list.indexOf(path)
    if (idx >= 0)
      list.splice(idx, 1)
    else
      list.push(path)
    root.selectedPaths = list
  }

  function clearSelection() {
    root.selectedPaths = []
  }

  function slotPosition(slot) {
    return {
      x: root.leftMargin + Math.floor(slot / root.rows) * (root.cellW + root.gapX),
      y: root.topMargin + (slot % root.rows) * (root.cellH + root.gapY)
    }
  }

  function rectOverlaps(a, b) {
    return a.x < b.x + root.cellW && a.x + root.cellW > b.x && a.y < b.y + root.cellH && a.y + root.cellH > b.y
  }

  function rebuildLayout() {
    const out = {}
    const occupied = []
    for (let i = 0; i < root.entries.length; i++) {
      const path = root.entries[i].path
      const saved = root.iconPositions[path]
      if (!saved)
        continue
      const x = Math.max(0, Math.min(root.width - root.cellW, saved.x))
      const y = Math.max(0, Math.min(root.height - root.cellH, saved.y))
      out[path] = { x: x, y: y }
      occupied.push({ x: x, y: y })
    }
    let slot = 0
    for (let i = 0; i < root.entries.length; i++) {
      const path = root.entries[i].path
      if (out[path])
        continue
      let pos = root.slotPosition(slot)
      while (occupied.some(function(rect) { return root.rectOverlaps(pos, rect) })) {
        slot++
        pos = root.slotPosition(slot)
      }
      out[path] = pos
      occupied.push(pos)
      slot++
    }
    root.layout = out
  }

  function persistLayout() {
    if (!root.positionsLoaded)
      return
    const map = Object.assign({}, root.iconPositions)
    let changed = false
    for (let i = 0; i < root.entries.length; i++) {
      const path = root.entries[i].path
      if (!map[path] && root.layout[path]) {
        map[path] = { x: root.layout[path].x, y: root.layout[path].y }
        changed = true
      }
    }
    if (changed) {
      root.iconPositions = map
      root.savePositions()
    }
  }

  function loadPositions(raw) {
    let parsed = null
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      return
    }
    if (!parsed || typeof parsed !== "object")
      return
    const clean = {}
    for (const key in parsed) {
      const v = parsed[key]
      if (v && typeof v.x === "number" && typeof v.y === "number" && isFinite(v.x) && isFinite(v.y))
        clean[key] = { x: v.x, y: v.y }
    }
    if (JSON.stringify(clean) === JSON.stringify(root.iconPositions))
      return
    root.iconPositions = clean
  }

  function savePositions() {
    if (!root.positionsLoaded)
      return
    positionsFile.setText(JSON.stringify(root.iconPositions))
  }

  function positionFor(path) {
    const dragged = root.dragPositions[path]
    if (dragged)
      return dragged
    return root.layout[path] || { x: 0, y: 0 }
  }

  function beginIconDrag(path) {
    const origins = {}
    const list = root.isSelected(path) ? root.selectedPaths.slice() : [path]
    if (!root.isSelected(path))
      root.selectOnly(path)
    for (let i = 0; i < list.length; i++) {
      const pos = root.layout[list[i]]
      if (pos)
        origins[list[i]] = { x: pos.x, y: pos.y }
    }
    root.dragOrigins = origins
    root.dragPositions = origins
    root.iconDragging = true
  }

  function moveIconDrag(dx, dy) {
    let minX = Infinity
    let maxX = -Infinity
    let minY = Infinity
    let maxY = -Infinity
    for (const path in root.dragOrigins) {
      const pos = root.dragOrigins[path]
      minX = Math.min(minX, pos.x)
      maxX = Math.max(maxX, pos.x)
      minY = Math.min(minY, pos.y)
      maxY = Math.max(maxY, pos.y)
    }
    if (minX === Infinity)
      return
    dx = Math.max(-minX, Math.min(root.width - root.cellW - maxX, dx))
    dy = Math.max(-minY, Math.min(root.height - root.cellH - maxY, dy))
    const next = {}
    for (const path in root.dragOrigins)
      next[path] = { x: root.dragOrigins[path].x + dx, y: root.dragOrigins[path].y + dy }
    root.dragPositions = next
  }

  function endIconDrag() {
    if (!root.iconDragging)
      return
    const map = Object.assign({}, root.iconPositions)
    for (const path in root.dragPositions)
      map[path] = root.dragPositions[path]
    root.iconPositions = map
    root.savePositions()
    root.dragPositions = ({})
    root.dragOrigins = ({})
    root.iconDragging = false
  }

  function cancelIconDrag() {
    root.dragPositions = ({})
    root.dragOrigins = ({})
    root.iconDragging = false
  }

  function updateBandSelection() {
    if (!root.bandMoved)
      return
    const x1 = Math.min(root.bandStartX, root.bandEndX)
    const x2 = Math.max(root.bandStartX, root.bandEndX)
    const y1 = Math.min(root.bandStartY, root.bandEndY)
    const y2 = Math.max(root.bandStartY, root.bandEndY)
    const list = root.bandBase.slice()
    for (let i = 0; i < root.entries.length; i++) {
      const pos = root.layout[root.entries[i].path]
      if (!pos)
        continue
      if (pos.x < x2 && pos.x + root.cellW > x1 && pos.y < y2 && pos.y + root.cellH > y1) {
        const path = root.entries[i].path
        if (list.indexOf(path) < 0)
          list.push(path)
      }
    }
    root.selectedPaths = list
  }

  function setIconsHidden(hidden) {
    root.iconsHidden = hidden
    root.clearSelection()
    hiddenFile.setText(hidden ? "1" : "0")
  }

  function scan() {
    if (root.iconDragging || scanProc.running)
      return
    scanProc.output = ""
    scanProc.running = true
  }

  function applyScan(rows) {
    if (rows === root.lastRows)
      return
    root.lastRows = rows
    const prevSel = root.selectedPaths.slice()
    const list = []
    const lines = rows.split("\n")
    for (let i = 0; i < lines.length; i++) {
      if (lines[i] === "")
        continue
      const cols = lines[i].split("\t")
      if (cols.length < 6)
        continue
      list.push({
        isDir: cols[0] === "d",
        display: cols[1],
        path: cols[2],
        thumb: cols[3],
        icon: cols[4],
        kind: cols[5],
        exec: cols[6] || ""
      })
    }
    list.sort(function(a, b) {
      if (a.isDir !== b.isDir)
        return a.isDir ? -1 : 1
      const an = a.display.toLowerCase()
      const bn = b.display.toLowerCase()
      return an < bn ? -1 : an > bn ? 1 : 0
    })
    root.entries = list
    if (root.pendingSelectPath !== "") {
      const target = root.pendingSelectPath
      root.pendingSelectPath = ""
      root.selectedPaths = list.some(entry => entry.path === target) ? [target] : []
    } else {
      const sel = []
      for (let i = 0; i < list.length; i++) {
        if (prevSel.indexOf(list[i].path) >= 0)
          sel.push(list[i].path)
      }
      root.selectedPaths = sel
    }
    if (root.menuOpen)
      root.menuOpen = false
    root.persistLayout()
  }

  function iconFor(entry) {
    if (!entry)
      return "text-x-generic"
    if (entry.kind === "folder")
      return "folder"
    if (entry.kind === "audio")
      return "audio-x-generic"
    if (entry.kind === "pdf")
      return "application-pdf"
    if (entry.kind === "archive")
      return "package-x-generic"
    if (entry.kind === "text")
      return "text-x-generic"
    if (entry.kind === "image")
      return "image-x-generic"
    if (entry.kind === "video")
      return "video-x-generic"
    if (entry.kind === "desktop")
      return entry.icon !== "" ? entry.icon : "application-x-executable"
    return "text-x-generic"
  }

  function iconSource(entry) {
    if (entry && entry.kind === "desktop" && entry.icon.startsWith("/"))
      return Util.fileUrl(entry.icon)
    return Quickshell.iconPath(root.iconFor(entry), "text-x-generic")
  }

  function desktopExec(entry) {
    let cmd = String(entry.exec || "")
    cmd = cmd.replace(/%%/g, "\u0000")
    cmd = cmd.replace(/%c/g, Util.shellQuote(entry.display))
    cmd = cmd.replace(/%k/g, Util.shellQuote(entry.path))
    cmd = cmd.replace(/%i/g, entry.icon !== "" ? "--icon " + Util.shellQuote(entry.icon) : "")
    cmd = cmd.replace(/%[fFuUdDnNickvm]/g, "")
    cmd = cmd.replace(/\u0000/g, "%")
    return cmd.trim()
  }

  function openEntryPath(entry) {
    if (!entry)
      return
    if (entry.kind === "desktop") {
      const cmd = root.desktopExec(entry)
      if (cmd !== "")
        Quickshell.execDetached(["bash", "-c", cmd])
      else
        Quickshell.execDetached(["xdg-open", entry.path])
      return
    }
    Quickshell.execDetached(["xdg-open", entry.path])
  }

  function openEntry(index) {
    root.openEntryPath(root.entries[index])
  }

  function openSelected(fallback) {
    const list = []
    for (let i = 0; i < root.entries.length; i++) {
      if (root.isSelected(root.entries[i].path))
        list.push(root.entries[i])
    }
    if (list.length === 0 && fallback)
      list.push(fallback)
    for (let i = 0; i < list.length; i++)
      root.openEntryPath(list[i])
  }

  function createFolder() {
    newFolderProc.command = ["bash", "-c",
      "dir=" + Util.shellQuote(root.desktopDir) + "; "
      + "name='New Folder'; n=2; "
      + "while [ -e \"$dir/$name\" ]; do name=\"New Folder $n\"; n=$((n+1)); done; "
      + "mkdir -- \"$dir/$name\" && printf '%s' \"$dir/$name\""]
    newFolderProc.running = true
  }

  function openTerminal() {
    const term = DefaultApps.hasTerminalChoice && DefaultApps.terminalCmd.length > 0 ? DefaultApps.terminalCmd[0] : "kitty"
    Quickshell.execDetached(["bash", "-c",
      "cd " + Util.shellQuote(root.desktopDir) + " && exec " + Util.shellQuote(term)])
  }

  function copySelection() {
    if (root.selectedPaths.length === 0)
      return
    copyProc.command = ["wl-copy", root.selectedPaths.join("\n")]
    copyProc.running = true
  }

  function openMenu(index, x, y) {
    root.menuIndex = index
    root.menuX = x
    root.menuY = y
    root.menuOpen = true
  }

  function runMenu(action) {
    const entry = root.entries[root.menuIndex]
    root.menuOpen = false
    if (action === "folder") {
      Quickshell.execDetached(["xdg-open", root.desktopDir])
      return
    }
    if (action === "newfolder") {
      root.createFolder()
      return
    }
    if (action === "terminal") {
      root.openTerminal()
      return
    }
    if (action === "wallpaper") {
      Quickshell.execDetached(["quickshell", "ipc", "call", "wallpaper", "openDesktop"])
      return
    }
    if (action === "toggleicons") {
      root.setIconsHidden(!root.iconsHidden)
      return
    }
    if (action === "copy") {
      root.copySelection()
      return
    }
    if (!entry)
      return
    if (action === "open")
      root.openSelected(entry)
  }

  Process {
    id: scanProc
    property string output: ""
    command: ["bash", "-c",
      "dir=" + Util.shellQuote(root.desktopDir) + "; "
      + "cache=\"$HOME/.cache/quickshell/desktop-icons\"; "
      + "[[ -d \"$dir\" ]] || exit 0; "
      + "mkdir -p \"$cache\"; "
      + "find -L \"$dir\" -mindepth 1 -maxdepth 1 \\( -type f -o -type d \\) ! -name '.*' ! -name '*~' -printf '%y\\t%s\\t%T@\\t%f\\t%p\\n' | "
      + "while IFS=$'\\t' read -r type size mtime name path; do "
      + "kind=file; thumb=\"\"; icon=\"\"; cmd=\"\"; display=\"$name\"; lower=${name,,}; "
      + "case \"$lower\" in "
      + "*.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.avif) kind=image ;; "
      + "*.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v) kind=video ;; "
      + "*.mp3|*.wav|*.flac|*.ogg|*.m4a|*.opus) kind=audio ;; "
      + "*.pdf) kind=pdf ;; "
      + "*.zip|*.tar|*.tgz|*.gz|*.xz|*.zst|*.7z|*.rar) kind=archive ;; "
      + "*.txt|*.md|*.log|*.conf|*.json|*.js|*.ts|*.py|*.sh|*.c|*.cpp|*.h|*.html|*.css|*.yml|*.yaml|*.toml|*.kdl) kind=text ;; "
      + "*.desktop) kind=desktop; "
      + "icon=$(sed -n 's/^Icon=//p' \"$path\" | head -n 1); "
      + "cmd=$(sed -n 's/^Exec=//p' \"$path\" | head -n 1); "
      + "n=$(sed -n 's/^Name=//p' \"$path\" | head -n 1); [[ -n \"$n\" ]] && display=\"$n\" ;; "
      + "esac; "
      + "[[ \"$type\" == \"d\" ]] && kind=folder; "
      + "if [[ \"$kind\" == \"image\" || \"$kind\" == \"video\" ]]; then "
      + "key=$(printf '%s|%s|%s' \"$path\" \"$mtime\" \"$size\" | md5sum | cut -d ' ' -f 1); "
      + "thumb=\"$cache/$key.jpg\"; "
      + "if [[ ! -f \"$thumb\" ]]; then "
      + "tmp=\"$cache/$key.tmp.$$.jpg\"; rm -f \"$tmp\"; "
      + "if [[ \"$kind\" == \"image\" ]]; then "
      + "magick \"$path\"[0] -auto-orient -thumbnail '192x192^' -gravity center -extent 192x192 \"$tmp\" 2>/dev/null || true; "
      + "else "
      + "ffmpeg -v error -y -ss 1 -i \"$path\" -frames:v 1 -vf \"scale=192:192:force_original_aspect_ratio=increase,crop=192:192\" \"$tmp\" 2>/dev/null || ffmpeg -v error -y -i \"$path\" -frames:v 1 -vf \"scale=192:192:force_original_aspect_ratio=increase,crop=192:192\" \"$tmp\" 2>/dev/null || true; "
      + "fi; "
      + "if [[ -s \"$tmp\" ]]; then mv -f \"$tmp\" \"$thumb\"; else rm -f \"$tmp\"; thumb=\"\"; fi; "
      + "fi; fi; "
      + "printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$type\" \"$display\" \"$path\" \"$thumb\" \"$icon\" \"$kind\" \"$cmd\"; "
      + "done"]
    stdout: SplitParser {
      onRead: function(data) {
        scanProc.output += data + "\n"
      }
    }
    onExited: root.applyScan(scanProc.output)
  }

  Process {
    id: newFolderProc
    stdout: StdioCollector {
      id: newFolderOut
      waitForEnd: true
    }
    onExited: {
      root.pendingSelectPath = newFolderOut.text.trim()
      root.scan()
    }
  }

  Process {
    id: copyProc
  }

  FileView {
    id: hiddenFile
    path: Quickshell.env("HOME") + "/.cache/quickshell-desktop-icons-hidden"
    watchChanges: true
    printErrors: false
    onLoaded: root.iconsHidden = text().trim() === "1"
    onFileChanged: reload()
  }

  FileView {
    id: positionsFile
    path: Quickshell.env("HOME") + "/.cache/quickshell-desktop-positions.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.loadPositions(text())
      root.positionsLoaded = true
      root.persistLayout()
    }
    onLoadFailed: {
      root.positionsLoaded = true
      root.persistLayout()
    }
    onFileChanged: reload()
  }

  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.scan()
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: function(mouse) {
      if (root.menuOpen)
        root.menuOpen = false
      if (mouse.button === Qt.LeftButton && !root.iconsHidden) {
        root.bandBase = mouse.modifiers & Qt.ControlModifier ? root.selectedPaths.slice() : []
        if (!(mouse.modifiers & Qt.ControlModifier))
          root.clearSelection()
        root.bandStartX = mouse.x
        root.bandStartY = mouse.y
        root.bandEndX = mouse.x
        root.bandEndY = mouse.y
        root.bandMoved = false
        root.banding = true
      }
    }
    onPositionChanged: function(mouse) {
      if (!root.banding)
        return
      root.bandEndX = mouse.x
      root.bandEndY = mouse.y
      if (!root.bandMoved && (Math.abs(root.bandEndX - root.bandStartX) > 3 || Math.abs(root.bandEndY - root.bandStartY) > 3))
        root.bandMoved = true
      root.updateBandSelection()
    }
    onReleased: function(mouse) {
      if (mouse.button === Qt.LeftButton && root.banding)
        root.banding = false
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton)
        root.openMenu(-1, mouse.x, mouse.y)
      else if (root.bandMoved)
        root.bandMoved = false
    }
  }

  Repeater {
    model: root.iconsHidden ? [] : root.entries
    delegate: Item {
      id: cell

      required property var modelData
      required property int index

      readonly property bool isSelected: root.isSelected(cell.modelData.path)
      property bool hovered: false

      width: root.cellW
      height: root.cellH
      x: root.positionFor(cell.modelData.path).x
      y: root.positionFor(cell.modelData.path).y
      z: root.dragPositions[cell.modelData.path] ? 10 : 0

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: cell.isSelected ? root.withAlpha(Theme.outline, 0.18) : (cell.hovered ? root.withAlpha(Theme.fg, 0.08) : "transparent")
        border.width: cell.isSelected ? 1 : 0
        border.color: Theme.outline
        Behavior on color {
          ColorAnimation { duration: Theme.animFast }
        }
      }

      Item {
        id: thumbBox
        width: root.iconSize
        height: root.iconSize
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter

        Image {
          id: thumb
          anchors.fill: parent
          source: cell.modelData.thumb !== "" ? Util.fileUrl(cell.modelData.thumb) : ""
          visible: cell.modelData.thumb !== "" && status === Image.Ready
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: 192
          sourceSize.height: 192
          asynchronous: true
          cache: true
          smooth: true
        }

        IconImage {
          anchors.centerIn: parent
          visible: cell.modelData.thumb === "" || thumb.status !== Image.Ready
          source: root.iconSource(cell.modelData)
          implicitSize: 56
          asynchronous: true
        }

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.width: cell.modelData.thumb !== "" && thumb.status === Image.Ready ? 1 : 0
          border.color: cell.hovered || cell.isSelected ? root.withAlpha(Theme.outline, 0.9) : root.withAlpha(Theme.fg, 0.35)
          Behavior on border.color {
            ColorAnimation { duration: Theme.animFast }
          }
        }

        Rectangle {
          visible: cell.modelData.kind === "video"
          width: 20
          height: 20
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: 3
          color: root.withAlpha(Theme.bgBase, 0.85)
          border.width: 1
          border.color: root.withAlpha(Theme.fg, 0.5)

          QIcon {
            anchors.centerIn: parent
            name: "player-play"
            size: 11
            color: Theme.fg
          }
        }
      }

      Text {
        anchors.top: thumbBox.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        text: cell.modelData.display
        color: Theme.fg
        style: Text.Outline
        styleColor: Theme.bgBase
        font.family: Theme.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      MouseArea {
        id: cellMouse

        property bool holding: false
        property bool moved: false
        property real pressSceneX: 0
        property real pressSceneY: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.dragPositions[cell.modelData.path] ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onEntered: cell.hovered = true
        onExited: cell.hovered = false
        onPressed: function(mouse) {
          if (mouse.button !== Qt.LeftButton)
            return
          holding = true
          moved = false
          pressSceneX = mouse.x + cell.x
          pressSceneY = mouse.y + cell.y
          if (root.menuOpen)
            root.menuOpen = false
          if (mouse.modifiers & Qt.ControlModifier)
            root.toggleSelected(cell.modelData.path)
          else if (!cell.isSelected)
            root.selectOnly(cell.modelData.path)
        }
        onPositionChanged: function(mouse) {
          if (!holding)
            return
          const dx = mouse.x + cell.x - pressSceneX
          const dy = mouse.y + cell.y - pressSceneY
          if (!moved && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
            moved = true
            root.beginIconDrag(cell.modelData.path)
          }
          if (moved)
            root.moveIconDrag(dx, dy)
        }
        onReleased: function(mouse) {
          if (mouse.button !== Qt.LeftButton)
            return
          holding = false
          if (moved) {
            moved = false
            root.endIconDrag()
          }
        }
        onCanceled: {
          holding = false
          moved = false
          if (root.iconDragging)
            root.cancelIconDrag()
        }
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            if (!cell.isSelected)
              root.selectOnly(cell.modelData.path)
            root.openMenu(index, mouse.x + cell.x, mouse.y + cell.y)
          }
        }
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.LeftButton)
            root.openEntry(index)
        }
      }
    }
  }

  Rectangle {
    id: band

    visible: root.banding && root.bandMoved
    x: Math.min(root.bandStartX, root.bandEndX)
    y: Math.min(root.bandStartY, root.bandEndY)
    width: Math.abs(root.bandEndX - root.bandStartX)
    height: Math.abs(root.bandEndY - root.bandStartY)
    color: root.withAlpha(Theme.outline, 0.12)
    border.width: 1
    border.color: root.withAlpha(Theme.outline, 0.85)
    z: 50
  }

  Rectangle {
    id: menu

    visible: root.menuOpen
    width: 210
    height: menuCol.implicitHeight + 8
    x: Math.max(8, Math.min(root.menuX, root.width - width - 8))
    y: Math.max(8, Math.min(root.menuY, root.height - height - 8))
    color: root.withAlpha(Theme.bgBase, Math.min(Theme.bg.a, 0.8))
    border.width: 1
    border.color: Theme.outline
    z: 100

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Column {
      id: menuCol
      anchors.fill: parent
      anchors.margins: 4
      spacing: 0

      Repeater {
        model: root.menuItems
        delegate: Rectangle {
          required property var modelData

          width: menuCol.width
          height: 30
          color: rowMa.containsMouse ? Theme.outline : "transparent"
          Behavior on color {
            ColorAnimation { duration: Theme.animFast }
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            QIcon {
              anchors.verticalCenter: parent.verticalCenter
              name: modelData.icon
              size: 14
              color: rowMa.containsMouse ? Theme.bgBase : Theme.fg
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: rowMa.containsMouse ? Theme.bgBase : Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }
          }

          MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runMenu(modelData.action)
          }
        }
      }
    }
  }
}
