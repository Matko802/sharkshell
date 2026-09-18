import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  property bool opened: false
  property bool blurReady: false
  property bool entered: false
  property int selIdx: 0
  property bool imagesLoaded: false
  property string filterText: ""
  property bool editingDir: false
  property string imageDirs: ""
  property string selectedImage: ""
  property var imageArray: []

  readonly property string fontFamily: Theme.fontFamily
  readonly property int thumbW: 160
  readonly property int thumbH: 100
  readonly property int thumbSpacing: 6
  readonly property int visibleCount: 9

  property bool closePending: false

  property bool browsing: false
  property string browseDir: ""
  property var browseArray: []
  property int browseSel: 0
  property string browseFilter: ""
  readonly property int browseRowH: 34

  function requestClose() {
    if (!root.opened || root.closePending)
      return
    root.closePending = true
    root.entered = false
    closeTimer.restart()
  }

  function forceClose() {
    root.entered = false
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
    id: blurTimer
    interval: 270
    onTriggered: { if (root.opened) root.blurReady = true }
  }

  onOpenedChanged: {
    if (root.opened) {
      root.blurReady = false
      blurTimer.restart()
    } else {
      root.blurReady = false
      blurTimer.stop()
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
    closeTimer.stop()
    root.closePending = false
    root.editingDir = false
    root.filterText = ""
    dirsFile.reload()
    const custom = dirsFile.text().trim()
    const home = Quickshell.env("HOME")
    root.imageDirs = custom || waypaperIni.text().match(/^folder\s*=\s*(.+)$/m)?.[1]?.trim() || home + "/Pictures/Wallpapers"
    root.selectedImage = WallpaperState.path
    root.imageArray = []
    root.selIdx = 0
    root.imagesLoaded = false
    root.entered = false
    loadImagesProc.output = ""
    loadImagesProc.running = true
  }

  IpcHandler {
    target: "wallpaper"
    function toggle() {
      root.toggle()
    }
    function close() {
      root.forceClose()
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

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function fileUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function nameForPath(path) {
    return path.split("/").pop().replace(/\.[^/.]+$/, "")
  }

  function labelForPath(path) {
    return nameForPath(path).replace(/[-_]+/g, " ").replace(/\b\w/g, m => m.toUpperCase())
  }

  function currentLabel() {
    const e = root.results[root.selIdx]
    return e ? labelForPath(e.filePath) : (root.filterText ? "No matches" : "")
  }

  function itemMatches(filePath) {
    if (!filterText)
      return true
    const needle = filterText.toLowerCase()
    return nameForPath(filePath).toLowerCase().indexOf(needle) !== -1
        || labelForPath(filePath).toLowerCase().indexOf(needle) !== -1
  }

  readonly property var results: {
    const out = []
    for (let i = 0; i < imageArray.length; i++)
      if (itemMatches(imageArray[i].filePath))
        out.push(imageArray[i])
    return out
  }

  onFilterTextChanged: { root.selIdx = 0 }
  onResultsChanged: {
    if (root.selIdx >= root.results.length)
      root.selIdx = Math.max(0, root.results.length - 1)
  }
  onSelIdxChanged: {
    if (listView && root.results.length > 0)
      listView.positionViewAtIndex(Math.max(0, root.selIdx - Math.floor(root.visibleCount / 2)), ListView.Beginning)
  }

  function move(step) {
    root.selIdx = Math.max(0, Math.min(root.results.length - 1, root.selIdx + step))
  }

  function apply(i) {
    const entry = root.results[i]
    if (!entry)
      return
    root.selectedImage = entry.filePath
    WallpaperState.set(entry.filePath)
  }

  function openBrowser() {
    root.browsing = true
    const first = root.imageDirs.split("\n").map(s => s.trim()).find(s => s !== "")
    root.browseDir = first || Quickshell.env("HOME") || "/home/matko"
    root.browseFilter = ""
    root.browseSel = 0
    root.browseArray = []
    browseProc.output = ""
    browseProc.running = true
    browseView.forceActiveFocus()
  }

  function closeBrowser() {
    root.browsing = false
    listView.forceActiveFocus()
  }

  function browseGoUp() {
    const parts = root.browseDir.split("/").filter(p => p !== "")
    parts.pop()
    root.browseDir = "/" + parts.join("/")
    if (root.browseDir === "/")
      root.browseDir = "/"
    root.browseRefresh()
  }

  function browseGoHome() {
    root.browseDir = Quickshell.env("HOME") || "/home/matko"
    root.browseRefresh()
  }

  function browseRefresh() {
    root.browseFilter = ""
    root.browseSel = 0
    root.browseArray = []
    browseProc.output = ""
    browseProc.running = true
  }

  function browseDescend(i) {
    const entry = root.browseResults[i]
    if (!entry)
      return
    root.browseDir = entry.fullPath
    root.browseRefresh()
  }

  function browseUseFolder() {
    const next = root.browseDir
    root.browsing = false
    if (next === "" || next === root.imageDirs) {
      listView.forceActiveFocus()
      return
    }
    dirsFile.setText(next + "\n")
    root.imageDirs = next
    root.imageArray = []
    root.imagesLoaded = false
    loadImagesProc.output = ""
    loadImagesProc.running = true
    listView.forceActiveFocus()
  }

  function browseMatches(entry) {
    if (!browseFilter)
      return true
    return entry.name.toLowerCase().indexOf(browseFilter.toLowerCase()) !== -1
  }

  readonly property var browseResults: {
    const out = []
    for (let i = 0; i < browseArray.length; i++)
      if (browseMatches(browseArray[i]))
        out.push(browseArray[i])
    return out
  }

  onBrowseFilterChanged: { root.browseSel = 0 }
  onBrowseResultsChanged: {
    if (root.browseSel >= root.browseResults.length)
      root.browseSel = Math.max(0, root.browseResults.length - 1)
  }
  onBrowseSelChanged: {
    if (browseView && root.browseResults.length > 0)
      browseView.positionViewAtIndex(Math.max(0, root.browseSel - 2), ListView.Beginning)
  }

  function browseMove(step) {
    root.browseSel = Math.max(0, Math.min(root.browseResults.length - 1, root.browseSel + step))
  }

  Process {
    id: browseProc
    property string output: ""
    command: ["bash", "-c",
      "dir=" + shellQuote(root.browseDir) + ";"
      + " [[ -d \"$dir\" ]] || exit 0;"
      + " find -L \"$dir\" -maxdepth 1 -mindepth 1 -type d -printf '%f\\n' 2>/dev/null | sort"]
    stdout: SplitParser {
      onRead: function(data) {
        browseProc.output += data + "\n"
      }
    }
    onExited: root.loadBrowseRows(output)
  }

  function loadBrowseRows(rows) {
    const entries = []
    for (const row of rows.split("\n")) {
      if (!row || row.startsWith("."))
        continue
      const full = root.browseDir + (root.browseDir.endsWith("/") ? "" : "/") + row
      entries.push({ name: row, fullPath: full })
    }
    entries.sort((a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1)
    root.browseArray = entries
    browseView.forceActiveFocus()
  }

  Process {
    id: loadImagesProc
    property string output: ""
    command: ["bash", "-c",
      "cache_dir=\"$HOME/.cache/quickshell/image-selector\"; mkdir -p \"$cache_dir\";"
      + " while IFS= read -r dir; do [[ -n $dir && -d $dir ]] && find -L \"$dir\" -maxdepth 1 -type f"
      + " \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \\) -print0;"
      + " done <<< " + shellQuote(root.imageDirs)
      + " | sort -z | while IFS= read -r -d '' image; do"
      + " hash=$(md5sum \"$image\" | cut -d ' ' -f 1); thumb=\"$cache_dir/$hash.jpg\";"
      + " if [[ ! -f $thumb ]]; then"
      + " magick \"$image\"[0] -auto-orient -thumbnail '768x475^' -gravity center -extent 768x475 \"$thumb\" 2>/dev/null || thumb=$image;"
      + " fi; printf '%s\\t%s\\n' \"$image\" \"$thumb\"; done"]
    stdout: SplitParser {
      onRead: function(data) {
        loadImagesProc.output += data + "\n"
      }
    }
    onExited: root.loadRows(output)
  }

  function loadRows(rows) {
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
    root.imagesLoaded = true
    root.opened = true
    root.entered = true
    listView.forceActiveFocus()
  }

  PanelWindow {
    visible: (root.opened || root.closePending) && root.imagesLoaded && root.blurReady
    anchors.top: true
    anchors.left: true
    margins.top: 80
    margins.left: 20
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: panel.width
    implicitHeight: panel.height
    WlrLayershell.namespace: "quickshell-blur"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Theme.bg
    }
  }

  PanelWindow {
    visible: (root.opened || root.closePending) && root.imagesLoaded
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.top: 30
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-backdrop"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: root.requestClose()
    }

    Rectangle {
      id: panel
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: 50
      anchors.leftMargin: root.opened ? 20 : -width
      width: root.browsing ? 400 : root.thumbW + 16
      height: (root.browsing ? browseCol.implicitHeight : listViewCol.implicitHeight) + 16
      color: "transparent"
      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: root.blurReady ? 0 : 1
      }
      border.color: Theme.fg
      border.width: 1
      Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

      Column {
        id: listViewCol
        visible: !root.browsing
        anchors.fill: parent
        anchors.margins: 8

        ListView {
          id: listView
          width: parent.width
          height: root.visibleCount * (root.thumbH + root.thumbSpacing)
          clip: true
          spacing: root.thumbSpacing
          model: root.results
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          focus: true

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Left) {
              WallpaperState.setPosition(WallpaperState.positionX - 0.05, WallpaperState.positionY)
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Right) {
              WallpaperState.setPosition(WallpaperState.positionX + 0.05, WallpaperState.positionY)
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Up) {
              WallpaperState.setPosition(WallpaperState.positionX, WallpaperState.positionY - 0.05)
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Down) {
              WallpaperState.setPosition(WallpaperState.positionX, WallpaperState.positionY + 0.05)
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              if (root.editingDir) {
                root.editingDir = false
              } else if (root.filterText) {
                root.filterText = ""
              } else {
                root.requestClose()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.apply(root.selIdx)
              event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
              if (root.filterText.length > 0)
                root.filterText = root.filterText.slice(0, -1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.move(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              root.move(1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              root.move(-root.visibleCount)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              root.move(root.visibleCount)
              event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
              dirEditInput.open()
              event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.filterText += event.text
              event.accepted = true
            }
          }

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: listView.width
            height: root.thumbH
            color: "transparent"

            Image {
              anchors.fill: parent
              source: root.fileUrl(modelData.thumbnailPath)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              smooth: true
            }

            Rectangle {
              anchors.fill: parent
              color: modelData.filePath === root.selectedImage ? "#59ffffff" : "transparent"
              border.width: (root.selIdx === index || thumbMa.containsMouse) ? 2 : 0
              border.color: root.selIdx === index ? Theme.fg : Theme.muted
            }

            MouseArea {
              id: thumbMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.selIdx = index; root.apply(index) }
            }
          }

          Text {
            visible: root.results.length === 0
            anchors.centerIn: parent
            text: root.imageArray.length === 0 ? "no images found" : "no matches"
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
              value: WallpaperState.positionX
              onUserSet: v => WallpaperState.setPosition(v, WallpaperState.positionY)
            }
            Text {
              width: 26
              text: Math.round(WallpaperState.positionX * 100)
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
              value: WallpaperState.positionY
              onUserSet: v => WallpaperState.setPosition(WallpaperState.positionX, v)
            }
            Text {
              width: 26
              text: Math.round(WallpaperState.positionY * 100)
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
          width: parent.width
          height: 20
          visible: !root.editingDir

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, dirRow.implicitWidth + 16)
            height: 20
            color: "transparent"
            border.color: "#333333"
            border.width: 1

            Text {
              id: dirRow
              anchors.centerIn: parent
              width: Math.min(parent.width - 12, implicitWidth)
              elide: Text.ElideMiddle
              text: root.imageDirs.replace(/\n/g, " : ")
              color: Theme.fg
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: 9
              horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openBrowser()
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
            border.color: Theme.fg
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
                text = root.imageDirs
                forceActiveFocus()
                cursorPosition = text.length
              }

              function commit() {
                const next = text.trim()
                root.editingDir = false
                if (next === "" || next === root.imageDirs) {
                  listView.forceActiveFocus()
                  return
                }
                dirsFile.setText(next + "\n")
                root.imageDirs = next
                root.imageArray = []
                root.imagesLoaded = false
                loadImagesProc.output = ""
                loadImagesProc.running = true
                listView.forceActiveFocus()
              }

              Keys.onEscapePressed: {
                root.editingDir = false
                listView.forceActiveFocus()
              }
              Keys.onReturnPressed: commit()
              Keys.onEnterPressed: commit()
            }
          }
        }
      }

      Column {
        id: browseCol
        visible: root.browsing
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Text {
          width: parent.width
          text: "Wallpapers — pick a folder"
          color: Theme.fg
          font.family: root.fontFamily
          font.pixelSize: 11
        }

        RowLayout {
          width: parent.width
          spacing: 6
          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: 3
            color: browseUpMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.fg
            border.width: 1
            QIcon { anchors.centerIn: parent; name: "arrow-up"; size: 16; color: browseUpMa.containsMouse ? Theme.bg : Theme.fg }
            MouseArea { id: browseUpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.browseGoUp() }
          }
          Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 26
            radius: 3
            color: browseHomeMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.fg
            border.width: 1
            QIcon { anchors.centerIn: parent; name: "home"; size: 16; color: browseHomeMa.containsMouse ? Theme.bg : Theme.fg }
            MouseArea { id: browseHomeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.browseGoHome() }
          }
          Text {
            Layout.fillWidth: true
            text: root.browseDir
            color: Theme.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: 10
            elide: Text.ElideMiddle
          }
          Rectangle {
            Layout.preferredWidth: 84
            Layout.preferredHeight: 26
            radius: 3
            color: browseUseMa.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.fg
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "Use folder"
              color: browseUseMa.containsMouse ? Theme.bg : Theme.fg
              font.family: root.fontFamily
              font.pixelSize: 11
            }
            MouseArea { id: browseUseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.browseUseFolder() }
          }
        }

        ListView {
          id: browseView
          width: parent.width
          height: Math.min(root.visibleCount, Math.max(1, root.browseResults.length)) * (root.browseRowH + root.thumbSpacing)
          clip: true
          spacing: root.thumbSpacing
          model: root.browseResults
          highlightMoveDuration: 150
          highlightMoveVelocity: -1

          focus: true

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              if (root.browseFilter) {
                root.browseFilter = ""
              } else {
                root.closeBrowser()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.browseDescend(root.browseSel)
              event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
              if (root.browseFilter.length > 0)
                root.browseFilter = root.browseFilter.slice(0, -1)
              else
                root.browseGoUp()
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.browseMove(-1)
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              root.browseMove(1)
              event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
              root.browseMove(-root.visibleCount)
              event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
              root.browseMove(root.visibleCount)
              event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
              root.browseFilter += event.text
              event.accepted = true
            }
          }

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: browseView.width
            height: root.browseRowH
            color: root.browseSel === index ? Theme.fg : (browseRowMa.containsMouse ? "#33ffffff" : "transparent")

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
              id: browseRowMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.browseSel = index; root.browseDescend(index) }
            }
          }

          Text {
            visible: root.browseResults.length === 0
            anchors.centerIn: parent
            text: "no folders here"
            color: Theme.muted
            font.family: root.fontFamily
            font.pointSize: 11
          }
        }

        Text {
          visible: root.browseFilter !== ""
          width: parent.width
          text: "filter: " + root.browseFilter
          color: Theme.fg
          opacity: 0.6
          font.family: root.fontFamily
          font.pixelSize: 10
          elide: Text.ElideRight
        }
      }
    }
  }
}