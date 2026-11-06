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

  readonly property var folderResults: {
    const out = []
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
  onBrowseSelChanged: {
    if (folderView && root.folderResults.length > 0)
      folderView.positionViewAtIndex(Math.max(0, root.browseSel - 2), ListView.Beginning)
  }

  function navigate(dir) {
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

  function ascend() {
    if (root.navDir === root.rootDir)
      return
    const parts = root.navDir.split("/").filter(p => p !== "")
    parts.pop()
    root.navigate("/" + parts.join("/"))
  }

  function goRoot() {
    root.navigate(root.rootDir)
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
    const entry = root.imageResults[i]
    if (!entry)
      return
    root.selectedImage = entry.filePath
    if (root.isLockTab)
      WallpaperState.setLock(entry.filePath)
    else
      WallpaperState.set(entry.filePath)
  }

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
    BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent ? panel : null }
    mask: Region { item: panel }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      id: panel
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: 50
      anchors.leftMargin: root.opened ? 20 : -width
      width: 400
      height: navCol.implicitHeight + 16
      color: Theme.bg
      opacity: (panel.anchors.leftMargin + panel.width) / (20 + panel.width)
      border.color: Theme.outline
      border.width: 1
      Behavior on anchors.leftMargin { NumberAnimation { duration: 170; easing.type: Easing.OutExpo } }

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
          } else if (root.filterText) {
            root.filterText = ""
          } else if (root.navDir !== root.rootDir) {
            root.ascend()
          } else {
            root.requestClose()
          }
          event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) && !root.editingDir) {
          root.descend(root.browseSel)
          event.accepted = true
        } else if (event.key === Qt.Key_Left && !root.editingDir) {
          root.ascend()
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
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
          dirEditInput.open()
          event.accepted = true
        } else if (!root.editingDir && event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
          root.filterText += event.text
          event.accepted = true
        }
      }

      Column {
        id: navCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        Row {
          width: parent.width
          height: 26
          spacing: 4

          Repeater {
            model: 2
            delegate: Rectangle {
              required property int index
              width: (parent.width - 4) / 2
              height: 26
              radius: Theme.rounding
              color: root.activeTab === index ? Theme.fg : "transparent"
              border.color: Theme.outline
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: parent.index === 0 ? "Desktop" : "Lockscreen"
                color: root.activeTab === parent.index ? Theme.bg : Theme.fg
                font.family: root.fontFamily
                font.pixelSize: 11
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.switchTab(index)
              }
            }
          }
        }

        Text {
          visible: root.isLockTab
          width: parent.width
          text: WallpaperState.lockPath === "" ? "following desktop" : "custom lockscreen"
          color: Theme.fg
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: 10
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        RowLayout {
          width: parent.width
          spacing: 6

          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: Theme.rounding
            color: upMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1
            QIcon { anchors.centerIn: parent; name: "arrow-up"; size: 16; color: upMa.containsMouse ? Theme.bg : Theme.fg }
            MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ascend() }
          }
          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: Theme.rounding
            color: rootMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "root"
              color: rootMa.containsMouse ? Theme.bg : Theme.fg
              font.family: root.fontFamily
              font.pixelSize: 9
            }
            MouseArea { id: rootMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goRoot() }
          }
          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: Theme.rounding
            color: homeMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1
            QIcon { anchors.centerIn: parent; name: "home"; size: 16; color: homeMa.containsMouse ? Theme.bg : Theme.fg }
            MouseArea { id: homeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.goHome() }
          }
          Text {
            Layout.fillWidth: true
            text: root.navDir
            color: Theme.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: 10
            elide: Text.ElideMiddle
          }
          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: Theme.rounding
            color: dirMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "edit"
              color: dirMa.containsMouse ? Theme.bg : Theme.fg
              font.family: root.fontFamily
              font.pixelSize: 9
            }
            MouseArea { id: dirMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dirEditInput.open() }
          }
        }

        ListView {
          id: folderView
          width: parent.width
          visible: root.folderResults.length > 0
          height: visible ? Math.min(root.visibleCount, root.folderResults.length) * (root.browseRowH + root.thumbSpacing) : 0
          clip: true
          spacing: root.thumbSpacing
          model: root.folderResults
          highlightMoveDuration: 120
          highlightMoveVelocity: -1

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: folderView.width
            height: root.browseRowH
            color: root.browseSel === index ? Theme.fg : (folderMa.containsMouse ? Theme.hover : "transparent")

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 10
              Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                QIcon {
                  anchors.centerIn: parent
                  name: "folder"
                  size: 20
                  color: root.browseSel === index ? Theme.bg : Theme.fg
                }
              }
              Text {
                Layout.fillWidth: true
                text: modelData.name
                color: root.browseSel === index ? Theme.bg : Theme.fg
                font.family: root.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: folderMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.browseSel = index; root.descend(index) }
            }
          }

          Text {
            visible: root.folderResults.length === 0
            anchors.centerIn: parent
            text: "no folders here"
            color: Theme.muted
            font.family: root.fontFamily
            font.pointSize: 11
          }
        }

        Text {
          visible: root.filterText !== "" && !root.editingDir
          width: parent.width
          text: "filter: " + root.filterText
          color: Theme.fg
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: 10
          elide: Text.ElideRight
        }

        GridView {
          id: navGrid
          width: parent.width
          property int totalRows: Math.ceil(root.imageResults.length / 2)
          height: Math.min(5, Math.max(1, totalRows)) * 118
          clip: true
          cellWidth: Math.floor(width / 2)
          cellHeight: 118
          model: root.imageResults
          interactive: totalRows > 5

          delegate: Item {
            required property var modelData
            required property int index
            width: navGrid.cellWidth
            height: navGrid.cellHeight

            Image {
              anchors.fill: parent
              anchors.margins: 3
              source: Util.fileUrl(modelData.thumbnailPath)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              smooth: true
            }

            Rectangle {
              anchors.fill: parent
              anchors.margins: 3
              color: modelData.filePath === root.selectedImage ? Theme.hover : "transparent"
              border.width: gridMa.containsMouse ? 2 : (modelData.filePath === root.selectedImage ? 2 : 0)
              border.color: Theme.outline
            }

            MouseArea {
              id: gridMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.applyImage(index)
            }
          }

          Text {
            visible: root.imageArray.length === 0
            anchors.centerIn: parent
            text: (foldersProc.running || thumbProc.running) ? "loading..." : "no images in this folder"
            color: Theme.muted
            font.family: root.fontFamily
            font.pointSize: 11
          }
        }

        Column {
          width: parent.width
          spacing: 4

          Row {
            width: parent.width
            spacing: 6
            Text {
              width: 12
              text: "X"
              color: Theme.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
            }
            CSlider {
              width: parent.width - 44
              anchors.verticalCenter: parent.verticalCenter
              value: root.isLockTab ? WallpaperState.lockPositionX : WallpaperState.positionX
              onUserSet: v => root.setCurrentPosition(v, root.currentPosY())
            }
            Text {
              width: 26
              text: Math.round((root.isLockTab ? WallpaperState.lockPositionX : WallpaperState.positionX) * 100)
              color: Theme.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignRight
            }
          }

          Row {
            width: parent.width
            spacing: 6
            Text {
              width: 12
              text: "Y"
              color: Theme.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
            }
            CSlider {
              width: parent.width - 44
              anchors.verticalCenter: parent.verticalCenter
              value: root.isLockTab ? WallpaperState.lockPositionY : WallpaperState.positionY
              onUserSet: v => root.setCurrentPosition(root.currentPosX(), v)
            }
            Text {
              width: 26
              text: Math.round((root.isLockTab ? WallpaperState.lockPositionY : WallpaperState.positionY) * 100)
              color: Theme.fg
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: 10
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignRight
            }
          }
        }

        Item {
          visible: root.isLockTab && WallpaperState.lockPath !== ""
          width: parent.width
          height: 26

          Rectangle {
            anchors.centerIn: parent
            width: 130
            height: 24
            radius: Theme.rounding
            color: useDesktopMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "Use desktop"
              color: useDesktopMa.containsMouse ? Theme.bg : Theme.fg
              font.family: root.fontFamily
              font.pixelSize: 11
            }

            MouseArea {
              id: useDesktopMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                WallpaperState.clearLock()
                root.selectedImage = WallpaperState.effectiveLockPath
              }
            }
          }
        }

        Item {
          width: parent.width
          height: 22
          visible: root.editingDir

          Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border.color: Theme.outline
            border.width: 1

            TextInput {
              id: dirEditInput
              anchors.fill: parent
              anchors.margins: 4
              verticalAlignment: TextInput.AlignVCenter
              font.family: root.fontFamily
              font.pixelSize: 9
              color: Theme.fg

              function open() {
                root.editingDir = true
                text = root.rootDir
                forceActiveFocus()
                cursorPosition = text.length
              }

              function commit() {
                const next = text.trim()
                root.editingDir = false
                if (next === "" || next === root.rootDir) {
                  panel.forceActiveFocus()
                  return
                }
                dirsFile.setText(next + "\n")
                root.rootDir = next
                root.navigate(next)
                panel.forceActiveFocus()
              }

              Keys.onEscapePressed: {
                root.editingDir = false
                panel.forceActiveFocus()
              }
              Keys.onReturnPressed: commit()
              Keys.onEnterPressed: commit()
            }
          }
        }
      }
    }
  }
}
