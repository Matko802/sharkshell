import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: root

  property bool open: false
  property string query: ""
  property int selIdx: 0
  property int hoverIdx: -1
  readonly property string fontFamily: Theme.fontFamily
  readonly property int cols: 10
  readonly property int cellSize: 44
  readonly property int visibleRows: 5

  property bool closePending: false

  property bool blurReady: false
  property int blurNudge: 0

  Timer {
    id: blurNudgeTimer
    interval: 400
    onTriggered: {
      if (root.open && !root.closePending && root.blurReady)
        root.blurNudge = (root.blurNudge + 1) % 2
    }
  }

  function armBlur() {
    root.blurReady = false
  }

  function disarmBlur() {
    blurNudgeTimer.stop()
    root.blurReady = false
  }

  Connections {
    target: card
    function onCardProgChanged() {
      if (root.open && !root.closePending && card.cardProg >= 0.999) {
        root.blurReady = true
        blurNudgeTimer.restart()
      }
    }
  }

  function requestClose() {
    if (!root.open || root.closePending)
      return
    root.disarmBlur()
    root.closePending = true
    root.open = false
    closeTimer.restart()
  }

  function forceClose() {
    closeTimer.stop()
    root.disarmBlur()
    root.closePending = false
    root.open = false
  }

  Timer {
    id: closeTimer
    interval: 200
    onTriggered: {
      root.closePending = false
    }
  }

  function toggle() {
    if (root.closePending) {
      closeTimer.stop()
      root.closePending = false
      root.open = false
    }
    if (root.open) {
      root.requestClose()
      return
    }
    closeTimer.stop()
    root.closePending = false
    root.query = ""
    root.selIdx = 0
    root.hoverIdx = -1
    root.open = true
    root.armBlur()
  }

  function pick(i) {
    const entry = root.allEmojis[root.results[i]]
    if (!entry)
      return
    root.forceClose()
    pasteDelay.restart()
    pasteProc.command = ["sh", "-c", "printf %s '" + entry.replace(/'/g, "'\\''") + "' | wl-copy && sleep 0.15 && wtype -M ctrl v -m ctrl"]
  }

  Timer {
    id: pasteDelay
    interval: 100
    onTriggered: pasteProc.running = true
  }

  Process {
    id: pasteProc
  }

  IpcHandler {
    target: "emoji"
    function toggle() {
      root.toggle()
    }
    function close() {
      root.forceClose()
    }
    function update() {
      root.updateData()
    }
  }

  function updateData() {
    const xhr = new XMLHttpRequest()
    xhr.open("GET", "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json")
    xhr.timeout = 30000
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return
      try {
        const data = JSON.parse(xhr.responseText)
        const slim = data.map(e => [e.emoji, e.description || "", e.aliases || [], e.tags || []])
        dataFile.setText(JSON.stringify(slim))
      } catch (e) {}
    }
    xhr.send()
  }

  readonly property string dataPath: {
    const u = Qt.resolvedUrl("emojis.json").toString()
    return u.startsWith("file://") ? decodeURIComponent(u.slice(7)) : u
  }
  property var rows: []

  FileView {
    id: dataFile
    path: root.dataPath
    watchChanges: true
    onLoaded: {
      try {
        root.rows = JSON.parse(text())
      } catch (e) {
        root.rows = []
      }
    }
    onFileChanged: reload()
  }

  readonly property var allEmojis: rows.map(r => r[0])

  function nameOf(i) {
    const r = root.rows[i]
    return r ? r[1] : ""
  }

  function searchText(i) {
    const r = root.rows[i]
    if (!r)
      return ""
    return r[1] + " " + (r[2] || []).join(" ") + " " + (r[3] || []).join(" ")
  }

  function searchMatch(name, q) {
    if (name.indexOf(q) >= 0)
      return true
    let initials = ""
    for (const w of name.split(" "))
      if (w.length > 0)
        initials += w[0]
    if (initials.indexOf(q) >= 0)
      return true
    let j = 0
    for (let k = 0; k < name.length && j < q.length; k++)
      if (name[k] === q[j])
        j++
    return j === q.length
  }

  readonly property var lcSearch: root.rows.map((_, i) => root.searchText(i).toLowerCase())

  readonly property var results: {
    const q = query.toLowerCase().trim()
    const idxs = []
    for (let i = 0; i < rows.length; i++)
      if (q === "" || searchMatch(root.lcSearch[i], q))
        idxs.push(i)
    return idxs
  }

  onQueryChanged: {
    root.selIdx = 0
    root.hoverIdx = -1
  }
  onResultsChanged: {
    if (root.selIdx >= root.results.length)
      root.selIdx = Math.max(0, root.results.length - 1)
    if (root.hoverIdx >= root.results.length)
      root.hoverIdx = -1
  }
  onSelIdxChanged: {
    const g = grid
    if (!g) return
    const visH = g.height
    if (visH <= 0) return
    const top = Math.floor(root.selIdx / root.cols) * g.cellHeight
    let y = g.contentY
    if (top < y) y = top
    else if (top + g.cellHeight > y + visH) y = top + g.cellHeight - visH
    const maxY = Math.max(0, g.contentHeight - visH)
    g.contentY = Math.max(0, Math.min(maxY, y))
  }

  PanelWindow {
    id: panel
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { radius: root.blurNudge; item: root.blurReady ? card : null }
    mask: Region { item: card }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: root.open || root.closePending

    onVisibleChanged: { if (visible && root.open) search.forceActiveFocus() }

    Timer {
      running: root.open && !root.closePending
      repeat: true
      interval: 500
      onTriggered: { if (root.open && !search.activeFocus) search.forceActiveFocus() }
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.cols * root.cellSize + 20
      height: col.implicitHeight + 16
      color: Theme.bg
      border.color: Theme.outline
      border.width: 1
      property real cardProg: root.open ? 1 : 0
      scale: 0.92 + 0.08 * cardProg
      opacity: cardProg
      Behavior on cardProg { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 28
          color: "transparent"
          border.color: Theme.outline
          border.width: 1
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 6
            Item {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              Layout.alignment: Qt.AlignVCenter
              QIcon {
                anchors.centerIn: parent
                name: "search"
                size: 16
                color: Theme.fg
              }
            }
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Search"
                color: Theme.muted2
                font.family: root.fontFamily
                font.pixelSize: 12
                visible: search.text === ""
                elide: Text.ElideRight
              }
              TextInput {
                id: search
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                font.family: root.fontFamily
                font.pixelSize: 12
                color: Theme.fg
                clip: true
                focus: true
                onTextChanged: root.query = text
                onVisibleChanged: {
                  if (visible) {
                    text = ""
                    forceActiveFocus()
                  }
                }
                Keys.onEscapePressed: event => { root.requestClose(); event.accepted = true }
                Keys.onReturnPressed: root.pick(root.selIdx)
                Keys.onEnterPressed: root.pick(root.selIdx)
                Keys.onUpPressed: root.selIdx = Math.max(0, root.selIdx - root.cols)
                Keys.onDownPressed: root.selIdx = Math.min(root.results.length - 1, root.selIdx + root.cols)
                Keys.onLeftPressed: root.selIdx = Math.max(0, root.selIdx - 1)
                Keys.onRightPressed: root.selIdx = Math.min(root.results.length - 1, root.selIdx + 1)
              }
            }
          }
        }

        GridView {
          id: grid
          Layout.fillWidth: true
          Layout.preferredHeight: root.results.length === 0 ? 0 : Math.min(Math.ceil(root.results.length / root.cols), root.visibleRows) * root.cellSize
          visible: root.results.length > 0
          Behavior on Layout.preferredHeight { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
          clip: true
          interactive: true
          flickableDirection: Flickable.VerticalFlick
          cellWidth: root.cellSize
          cellHeight: root.cellSize
          model: root.results
          currentIndex: root.selIdx
          highlight: Rectangle { color: Theme.fg }
          highlightMoveDuration: 120

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool isKeyboardSelected: root.selIdx === index
            readonly property bool isHovered: root.hoverIdx === index
            color: isHovered ? Theme.hover : "transparent"

            Text {
              anchors.centerIn: parent
              text: root.allEmojis[parent.modelData] ?? ""
              font.pixelSize: 22
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.hoverIdx = index
              onExited: { if (root.hoverIdx === index) root.hoverIdx = -1 }
              onClicked: root.pick(index)
            }
          }
        }

        Text {
          visible: root.results.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: 18
          elide: Text.ElideRight
          font.family: root.fontFamily
          font.pointSize: 10
          color: Theme.fg
          text: {
            const i = root.results[root.selIdx]
            return i !== undefined ? root.nameOf(i) : ""
          }
        }
      }
    }
  }
}
