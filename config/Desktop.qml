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

  readonly property var menuItems: {
    if (root.menuIndex >= 0) {
      return [
        { label: root.selectedPaths.length > 1 ? "Open Selected" : "Open", icon: "go-next", action: "open" },
        { label: "Open Containing Folder", icon: "folder-open", action: "folder" },
        { label: "Copy Path", icon: "content-copy", action: "copy" },
        { label: "Refresh", icon: "refresh", action: "refresh" }
      ]
    }
    const items = [
      { label: "New Folder", icon: "plus", action: "newfolder" },
      { label: "Open Desktop Folder", icon: "folder-open", action: "folder" },
      { label: "Open Terminal Here", icon: "terminal", action: "terminal" },
      { label: "Change Wallpaper", icon: "wallpaper", action: "wallpaper" },
      { label: "Refresh", icon: "refresh", action: "refresh" }
    ]
    if (!root.iconsHidden && root.entries.length > 0)
      items.push({ label: "Select All", icon: "select-all", action: "selectall" })
    items.push({
      label: root.iconsHidden ? "Show Desktop Icons" : "Hide Desktop Icons",
      icon: root.iconsHidden ? "eye" : "eye-off",
      action: "toggleicons"
    })
    return items
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

  function selectAll() {
    const list = []
    for (let i = 0; i < root.entries.length; i++)
      list.push(root.entries[i].path)
    root.selectedPaths = list
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
      const cx = root.leftMargin + Math.floor(i / root.rows) * (root.cellW + root.gapX)
      const cy = root.topMargin + (i % root.rows) * (root.cellH + root.gapY)
      if (cx < x2 && cx + root.cellW > x1 && cy < y2 && cy + root.cellH > y1) {
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
    if (scanProc.running)
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
    if (action === "refresh") {
      root.scan()
      return
    }
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
    if (action === "selectall") {
      root.selectAll()
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
      x: root.leftMargin + Math.floor(index / root.rows) * (root.cellW + root.gapX)
      y: root.topMargin + (index % root.rows) * (root.cellH + root.gapY)

      Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        color: cell.isSelected ? root.withAlpha(Theme.fg, 0.16) : (cell.hovered ? root.withAlpha(Theme.fg, 0.08) : "transparent")
        border.width: cell.isSelected ? 1 : 0
        border.color: Theme.fg
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
          border.color: cell.hovered || cell.isSelected ? root.withAlpha(Theme.fg, 0.8) : root.withAlpha(Theme.fg, 0.35)
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
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: cell.hovered = true
        onExited: cell.hovered = false
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            if (!cell.isSelected)
              root.selectOnly(cell.modelData.path)
            root.openMenu(index, mouse.x + cell.x, mouse.y + cell.y)
          } else {
            if (mouse.modifiers & Qt.ControlModifier)
              root.toggleSelected(cell.modelData.path)
            else if (!cell.isSelected)
              root.selectOnly(cell.modelData.path)
            if (root.menuOpen)
              root.menuOpen = false
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
    visible: root.banding && root.bandMoved
    x: Math.min(root.bandStartX, root.bandEndX)
    y: Math.min(root.bandStartY, root.bandEndY)
    width: Math.abs(root.bandEndX - root.bandStartX)
    height: Math.abs(root.bandEndY - root.bandStartY)
    color: root.withAlpha(Theme.fg, 0.08)
    border.width: 1
    border.color: root.withAlpha(Theme.fg, 0.65)
    z: 50
  }

  Rectangle {
    id: menu

    visible: root.menuOpen
    width: 210
    height: menuCol.implicitHeight + 8
    x: Math.max(8, Math.min(root.menuX, root.width - width - 8))
    y: Math.max(8, Math.min(root.menuY, root.height - height - 8))
    color: Theme.bg
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
          color: rowMa.containsMouse ? Theme.fg : "transparent"
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
              color: rowMa.containsMouse ? Theme.bg : Theme.fg
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: rowMa.containsMouse ? Theme.bg : Theme.fg
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
