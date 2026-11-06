import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Util.js" as Util

Scope {
  id: root

  property bool opened: false
  property bool closePending: false
  property bool editingDir: false
  property string filterText: ""
  property string rootDir: ""
  property string navDir: ""
  property var navHistory: []
  property int navPos: -1
  property var folderArray: []
  property var imageArray: []
  property string selectedImage: ""
  property int browseSel: 0
  property int activeTab: 0
  readonly property bool isLockTab: activeTab === 1

  readonly property string fontFamily: Theme.fontFamily
  readonly property int browseRowH: 34
  readonly property int thumbSpacing: 6
  readonly property int visibleCount: 9

  function requestClose() {
    if (!root.opened || root.closePending)
      return
    root.closePending = true
    closeTimer.restart()
  }

  function forceClose() {
    closeTimer.stop()
    root.closePending = false
    root.opened = false
  }

  Timer {
    id: closeTimer
    interval: 250
    onTriggered: {
      root.opened = false
      closeCleanTimer.restart()
    }
  }

  Timer {
    id: closeCleanTimer
    interval: 250
    onTriggered: {
      root.closePending = false
    }
  }

  function toggle() {
    if (root.opened) {
      root.requestClose()
      return
    }
    root.openPicker()
  }

  function openPicker() {
    root.openPickerWithTab(0)
  }

  function resolveImageDirs() {
    dirsFile.reload()
    const custom = dirsFile.text().trim()
    const home = Quickshell.env("HOME")
    const all = custom || waypaperIni.text().match(/^folder\s*=\s*(.+)$/m)?.[1]?.trim()
        || home + "/Pictures/Wallpapers"
    return all.split("\n")[0].trim() || home + "/Pictures/Wallpapers"
  }

  function openPickerWithTab(tab) {
    closeTimer.stop()
    root.closePending = false
    root.editingDir = false
    root.filterText = ""
    root.activeTab = tab === 1 ? 1 : 0
    root.selectedImage = root.isLockTab ? WallpaperState.effectiveLockPath : WallpaperState.path
    if (root.rootDir === "")
      root.rootDir = root.resolveImageDirs()
    if (root.navDir === "")
      root.navigate(root.rootDir)
    root.opened = true
    panel.forceActiveFocus()
  }

  function prewarm() {
    if (root.opened || root.closePending)
      return
    if (root.navDir !== "")
      return
    if (foldersProc.running || thumbProc.running)
      return
    root.rootDir = root.resolveImageDirs()
    root.selectedImage = WallpaperState.path
    root.navigate(root.rootDir)
  }

  function switchTab(idx) {
    idx = idx === 1 ? 1 : 0
    if (root.activeTab === idx)
      return
    root.activeTab = idx
    root.selectedImage = idx === 1 ? WallpaperState.effectiveLockPath : WallpaperState.path
    panel.forceActiveFocus()
  }


  function currentPosX() {
    return root.isLockTab ? WallpaperState.lockPositionX : WallpaperState.positionX
  }

  function currentPosY() {
    return root.isLockTab ? WallpaperState.lockPositionY : WallpaperState.positionY
  }

  function setCurrentPosition(x, y) {
    if (root.isLockTab)
      WallpaperState.setLockPosition(x, y)
    else
      WallpaperState.setPosition(x, y)
  }

  IpcHandler {
    target: "wallpaper"
    function toggle() {
      root.toggle()
    }
    function close() {
      root.forceClose()
    }
    function openDesktop() {
      if (root.opened)
        root.switchTab(0)
      else
        root.openPickerWithTab(0)
    }
    function openLock() {
      if (root.opened)
        root.switchTab(1)
      else
        root.openPickerWithTab(1)
    }
  }

  FileView {
    id: dirsFile
    path: Quickshell.env("HOME") + "/.config/quickshell-wallpaper-dirs"
    watchChanges: false
    printErrors: false
  }

  FileView {
    id: waypaperIni
    path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
    watchChanges: false
    printErrors: false
  }

  function nameForPath(path) {
    return path.split("/").pop().replace(/\.[^/.]+$/, "")
  }

  function labelForPath(path) {
    return nameForPath(path).replace(/[-_]+/g, " ").replace(/\b\w/g, m => m.toUpperCase())
  }

  function imageMatches(entry) {
    if (!root.filterText)
      return true
    const needle = root.filterText.toLowerCase()
    return nameForPath(entry.filePath).toLowerCase().indexOf(needle) !== -1
        || labelForPath(entry.filePath).toLowerCase().indexOf(needle) !== -1
  }

  function folderMatches(entry) {
    if (!root.filterText)
      return true
    return entry.name.toLowerCase().indexOf(root.filterText.toLowerCase()) !== -1
  }

  readonly property var folderResults: {    const out = []
    for (let i = 0; i < folderArray.length; i++)
      if (root.folderMatches(folderArray[i]))
        out.push(folderArray[i])
    return out
  }

  readonly property var imageResults: {
    const out = []
    for (let i = 0; i < imageArray.length; i++)
      if (root.imageMatches(imageArray[i]))
        out.push(imageArray[i])
    return out
  }

  onFilterTextChanged: { root.browseSel = 0 }
  onFolderResultsChanged: {
    if (root.browseSel >= root.folderResults.length)
      root.browseSel = Math.max(0, root.folderResults.length - 1)
  }
  function loadDir(dir) {
    root.editingDir = false
    root.filterText = ""
    root.browseSel = 0
    root.navDir = dir
    root.folderArray = []
    root.imageArray = []
    foldersProc.requestDir = dir
    thumbProc.requestDir = dir
    foldersProc.output = ""
    thumbProc.output = ""
    foldersProc.running = true
    thumbProc.running = true
  }

  function navigate(dir) {
    root.navHistory = root.navHistory.slice(0, root.navPos + 1)
    root.navHistory.push(dir)
    root.navPos = root.navHistory.length - 1
    root.loadDir(dir)
  }

  function navBack() {
    if (root.navPos <= 0)
      return
    root.navPos = root.navPos - 1
    root.loadDir(root.navHistory[root.navPos])
  }

  function navFwd() {
    if (root.navPos >= root.navHistory.length - 1)
      return
    root.navPos = root.navPos + 1
    root.loadDir(root.navHistory[root.navPos])
  }

  function ascend() {
    if (root.navDir === root.rootDir)
      return
    const parts = root.navDir.split("/").filter(p => p !== "")
    parts.pop()
    root.navigate("/" + parts.join("/"))
  }

  function goHome() {
    root.navigate(Quickshell.env("HOME") || "/home/matko")
  }

  function descend(i) {
    const entry = root.folderResults[i]
    if (!entry)
      return
    root.navigate(entry.fullPath)
  }

  function moveSel(step) {
    root.browseSel = Math.max(0, Math.min(root.folderResults.length - 1, root.browseSel + step))
  }

  function applyImage(i) {
    root.chooseImage(root.activeTab, i)
  }

  function chooseImage(tab, i) {
    const entry = root.imageResults[i]
    if (!entry)
      return
    root.selectedImage = entry.filePath
    if (tab === 1)
      WallpaperState.setLock(entry.filePath)
    else
      WallpaperState.set(entry.filePath)
  }

  function posXFor(tab) {
    return tab === 1 ? WallpaperState.lockPositionX : WallpaperState.positionX
  }

  function posYFor(tab) {
    return tab === 1 ? WallpaperState.lockPositionY : WallpaperState.positionY
  }

  function setPosFor(tab, x, y) {
    if (tab === 1)
      WallpaperState.setLockPosition(x, y)
    else
      WallpaperState.setPosition(x, y)
  }

  function grabFocus() {
    panel.forceActiveFocus()
  }

  readonly property bool loadingDirs: foldersProc.running || thumbProc.running

  Process {
    id: foldersProc
    property string requestDir: ""
    property string output: ""
    command: ["bash", "-c",
      "dir=" + Util.shellQuote(root.navDir) + ";"
      + " [[ -d \"$dir\" ]] || exit 0;"
      + " find -L \"$dir\" -maxdepth 1 -mindepth 1 -type d -printf '%f\\n' 2>/dev/null | sort"]
    stdout: SplitParser {
      onRead: function(data) {
        foldersProc.output += data + "\n"
      }
    }
    onExited: {
      if (foldersProc.requestDir !== root.navDir)
        return
      const entries = []
      for (const row of foldersProc.output.split("\n")) {
        if (!row || row.startsWith("."))
          continue
        const full = root.navDir + (root.navDir.endsWith("/") ? "" : "/") + row
        entries.push({ name: row, fullPath: full })
      }
      entries.sort((a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1)
      root.folderArray = entries
    }
  }

  Process {
    id: thumbProc
    property string requestDir: ""
    property string output: ""
    command: ["bash", "-c",
      "cache_dir=\"$HOME/.cache/quickshell/image-selector\"; mkdir -p \"$cache_dir\";"
      + " dir=" + Util.shellQuote(root.navDir) + "; [[ -d \"$dir\" ]] || exit 0;"
      + " find -L \"$dir\" -maxdepth 1 -type f"
      + " \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \\) -print0"
      + " | sort -z | while IFS= read -r -d '' image; do"
      + " hash=$(md5sum \"$image\" | cut -d ' ' -f 1); thumb=\"$cache_dir/$hash.jpg\";"
      + " if [[ ! -f $thumb ]]; then"
      + " magick \"$image\"[0] -auto-orient -thumbnail '768x475^' -gravity center -extent 768x475 \"$thumb\" 2>/dev/null || thumb=$image;"
      + " fi; printf '%s\\t%s\\n' \"$image\" \"$thumb\"; done"]
    stdout: SplitParser {
      onRead: function(data) {
        thumbProc.output += data + "\n"
      }
    }
    onExited: {
      if (thumbProc.requestDir !== root.navDir)
        return
      const rows = thumbProc.output
      const newImages = []
      const seen = {}
      for (const row of rows.split("\n")) {
        if (!row)
          continue
        const columns = row.split("\t")
        const path = columns[0]
        if (!path)
          continue
        const fileName = path.split("/").pop()
        if (seen[fileName])
          continue
        seen[fileName] = true
        newImages.push({ filePath: path, fileName: fileName, thumbnailPath: columns[1] || path })
      }
      root.imageArray = newImages
    }
  }

  PanelWindow {
    visible: root.opened || root.closePending
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.top: 30
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region {
      item: TransparencyState.transparent ? panel : null
      Region { item: tabsPill }
    }
    mask: Region {
      item: panel
      Region { item: tabsPill }
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      id: tabsPill
      anchors.horizontalCenter: panel.horizontalCenter
      anchors.bottom: panel.top
      anchors.bottomMargin: 8
      width: panel.width
      height: 28
      color: Theme.bg
      border.color: Theme.outline
      border.width: 1
      opacity: panel.opacity
      scale: panel.slideProg

      RowLayout {
        anchors.fill: parent
        spacing: 0
        Repeater {
          model: [
            { label: "Desktop", idx: 0 },
            { label: "Lockscreen", idx: 1 }
          ]
          delegate: Item {
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            property bool active: root.activeTab === modelData.idx
            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: parent.active ? Theme.fg : Theme.muted2
              font.family: root.fontFamily
              font.pixelSize: 11
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.switchTab(modelData.idx)
            }
          }
        }
      }
    }

    Rectangle {
      id: panel
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: 50
      anchors.leftMargin: root.opened ? 20 : -width
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 10
      width: 176
      readonly property real slideProg: (panel.anchors.leftMargin + panel.width) / (20 + panel.width)
      color: Theme.bg
      opacity: (panel.anchors.leftMargin + panel.width) / (20 + panel.width)
      border.color: Theme.outline
      border.width: 1
      Behavior on anchors.leftMargin { NumberAnimation { duration: 170; easing.type: Easing.OutExpo } }
      Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutExpo } }

      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Left) {
          root.setCurrentPosition(root.currentPosX() - 0.05, root.currentPosY())
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Right) {
          root.setCurrentPosition(root.currentPosX() + 0.05, root.currentPosY())
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Up) {
          root.setCurrentPosition(root.currentPosX(), root.currentPosY() - 0.05)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Down) {
          root.setCurrentPosition(root.currentPosX(), root.currentPosY() + 0.05)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Tab) {
          root.switchTab(root.activeTab === 0 ? 1 : 0)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_1 || event.key === Qt.Key_2)) {
          root.switchTab(event.key === Qt.Key_1 ? 0 : 1)
          event.accepted = true
        } else if (event.key === Qt.Key_Tab && root.filterText === "") {
          root.switchTab(root.activeTab === 0 ? 1 : 0)
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.editingDir) {
            root.editingDir = false
            panel.forceActiveFocus()
          } else {
            root.requestClose()
          }
          event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !root.editingDir) {
          root.descend(root.browseSel)
          event.accepted = true
        } else if (event.key === Qt.Key_Right && !root.editingDir) {
          root.navFwd()
          event.accepted = true
        } else if (event.key === Qt.Key_Left && !root.editingDir) {
          root.navBack()
          event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
          if (root.editingDir)
            event.accepted = false
          else if (root.filterText.length > 0)
            root.filterText = root.filterText.slice(0, -1)
          else
            root.ascend()
          event.accepted = true
        } else if (event.key === Qt.Key_Up && !root.editingDir) {
          root.moveSel(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down && !root.editingDir) {
          root.moveSel(1)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp && !root.editingDir) {
          root.moveSel(-root.visibleCount)
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown && !root.editingDir) {
          root.moveSel(root.visibleCount)
          event.accepted = true
        } else if (!root.editingDir && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
          root.filterText += event.text
          event.accepted = true
        }
      }

    Flickable {
      id: pageFlick
      anchors.fill: parent
      clip: true
      interactive: false
      contentWidth: panel.width * 2
      contentHeight: height
      contentX: root.activeTab * panel.width
      Behavior on contentX { NumberAnimation { duration: Theme.animSwipe; easing.type: Theme.easingSwipe } }

      Row {
        spacing: 0

        WallpaperBrowsePage {
          width: panel.width
          height: pageFlick.height
          tab: 0
          picker: root
        }

        WallpaperBrowsePage {
          width: panel.width
          height: pageFlick.height
          tab: 1
          picker: root
        }
      }
    }
    }
  }
}
