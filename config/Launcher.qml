import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
  id: root

  property bool open: false
  property string query: ""
  property string filterQuery: ""
  property int selIdx: 0
  property int hoverIdx: -1
  property bool mouseOverList: false
  readonly property string fontFamily: Theme.fontFamily
  readonly property color matchColor: Theme.outline

  property var pinnedIds: []
  property int holdIdx: -1
  property real holdProgress: 0
  property bool holdFired: false
  property string holdSource: ""
  property int holdDuration: 800
  property double holdStartMs: 0
  readonly property int pinHoldMsKbd: 2000
  readonly property int pinHoldMsMouse: 800

  function entryId(e) {
    if (!e)
      return ""
    if (e.id && e.id.length > 0)
      return e.id
    if (e.execString && e.execString.length > 0)
      return e.execString
    return e.name ?? ""
  }
  function isPinned(entry) {
    return root.pinnedIds.indexOf(root.entryId(entry)) >= 0
  }
  function savePinned() {
    pinFile.setText(JSON.stringify(root.pinnedIds))
  }
  function togglePinAt(i) {
    const entry = root.results[i]
    if (!entry)
      return false
    const id = root.entryId(entry)
    if (id === "")
      return false
    let arr = root.pinnedIds.slice()
    const at = arr.indexOf(id)
    if (at >= 0)
      arr.splice(at, 1)
    else
      arr.push(id)
    root.pinnedIds = arr
    root.savePinned()
    return at < 0
  }
  function startHold(idx, source, duration) {
    if (idx < 0 || idx >= root.results.length)
      return
    root.holdIdx = idx
    root.holdSource = source
    root.holdFired = false
    root.holdProgress = 0
    root.holdDuration = duration
    root.holdStartMs = Date.now()
    holdTimer.interval = duration
    holdTimer.restart()
  }
  function cancelHold() {
    holdTimer.stop()
    root.holdIdx = -1
    root.holdProgress = 0
    root.holdFired = false
    root.holdSource = ""
  }
  function activateIdx(i) {
    if (root.query.trim() !== "" && root.results.length === 0)
      root.runCommand()
    else
      root.launch(i)
  }

  Timer {
    id: holdTimer
    interval: root.holdDuration
    onTriggered: {
      if (root.holdIdx < 0 || root.holdIdx >= root.results.length) {
        root.cancelHold()
        return
      }
      const id = root.entryId(root.results[root.holdIdx])
      root.holdFired = true
      root.holdProgress = 1
      root.togglePinAt(root.holdIdx)
      for (let i = 0; i < root.results.length; i++) {
        if (root.entryId(root.results[i]) === id) {
          root.holdIdx = i
          root.selIdx = i
          break
        }
      }
    }
  }
  Timer {
    id: holdTick
    interval: 50
    repeat: true
    running: root.holdIdx >= 0 && !root.holdFired
    onTriggered: {
      const el = Date.now() - root.holdStartMs
      root.holdProgress = Math.min(1, Math.max(0, el / Math.max(1, root.holdDuration)))
    }
  }

  FileView {
    id: pinFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/launcher-pinned.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        const v = JSON.parse(text())
        if (Array.isArray(v))
          root.pinnedIds = v.filter(x => typeof x === "string")
        else
          root.pinnedIds = []
      } catch (e) {
        root.pinnedIds = []
      }
    }
    onFileChanged: reload()
  }
  Process {
    id: pinMkdir
    running: true
    command: ["bash", "-c", "mkdir -p \"$HOME/.cache/sharkshell\""]
  }

  property var terminalCmd: ["kitty", "-e"]
  property int termProbeIdx: 0
  readonly property var termCandidates: [
    { bin: "xdg-terminal-exec", cmd: ["xdg-terminal-exec"] },
    { bin: "kitty", cmd: ["kitty", "-e"] },
    { bin: "alacritty", cmd: ["alacritty", "-e"] },
    { bin: "foot", cmd: ["foot"] },
    { bin: "wezterm", cmd: ["wezterm", "start", "--"] },
    { bin: "gnome-terminal", cmd: ["gnome-terminal", "--"] },
    { bin: "konsole", cmd: ["konsole", "-e"] },
    { bin: "xfce4-terminal", cmd: ["xfce4-terminal", "-e"] },
    { bin: "tilix", cmd: ["tilix", "-e"] },
    { bin: "xterm", cmd: ["xterm", "-e"] }
  ]
  Component.onCompleted: {
    const envTerm = Quickshell.env("TERMINAL")
    if (envTerm && envTerm.length > 0) {
      const t = envTerm.trim().split(/\s+/)[0]
      if (t === "foot") root.terminalCmd = ["foot"]
      else if (t === "wezterm") root.terminalCmd = ["wezterm", "start", "--"]
      else if (t === "gnome-terminal") root.terminalCmd = ["gnome-terminal", "--"]
      else if (t === "xdg-terminal-exec") root.terminalCmd = ["xdg-terminal-exec"]
      else root.terminalCmd = [t, "-e"]
      return
    }
    termProbe.running = true
  }
  Process {
    id: termProbe
    running: false
    onExited: exitCode => {
      const cand = root.termCandidates[root.termProbeIdx]
      if (exitCode === 0 && cand) {
        root.terminalCmd = cand.cmd
        return
      }
      root.termProbeIdx += 1
      if (root.termProbeIdx < root.termCandidates.length) {
        termProbe.command = ["sh", "-c", "command -v " + root.termCandidates[root.termProbeIdx].bin + " >/dev/null"]
        termProbe.running = true
      }
    }
    Component.onCompleted: {
      if (root.termCandidates.length > 0) {
        termProbe.command = ["sh", "-c", "command -v " + root.termCandidates[0].bin + " >/dev/null"]
      }
    }
  }

  Timer {
    id: searchTimer
    interval: 60
    onTriggered: root.filterQuery = root.query
  }

  Process {
    id: cmdRunner
  }

  property bool closePending: false

  function requestClose() {
    if (!root.open || root.closePending)
      return
    root.cancelHold()
    root.closePending = true
    root.open = false
    closeTimer.restart()
  }

  function forceClose() {
    closeTimer.stop()
    root.cancelHold()
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
    root.filterQuery = ""
    searchTimer.stop()
    root.selIdx = 0
    root.hoverIdx = -1
    root.cancelHold()
    root.open = true
  }

  function launch(i) {
    const entry = root.results[i]
    if (!entry)
      return
    root.forceClose()
    if (entry.runInTerminal) {
      if (entry.command && entry.command.length > 0) {
        Quickshell.execDetached(root.terminalCmd.concat(entry.command))
      } else {
        let exec = entry.execString ?? ""
        exec = exec.replace(/%[fFuUickdDnNvm]/g, "").trim()
        if (exec === "") exec = entry.execString
        Quickshell.execDetached(root.terminalCmd.concat(["sh", "-c", exec]))
      }
    } else {
      entry.execute()
    }
  }
  function runCommand() {
    const cmd = root.query.trim()
    if (cmd === "")
      return
    root.forceClose()
    cmdRunner.running = false
    cmdRunner.command = ["setsid", "-f", "sh", "-c", cmd]
    cmdRunner.running = true
  }
  function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  readonly property int maxNameChars: Math.max(8, Math.floor((30 * tm.advanceWidth - 26) / tm.advanceWidth))

  function fit(name) {
    return name.length > root.maxNameChars ? name.slice(0, root.maxNameChars - 1) + "\u2026" : name
  }

  function hl(rawName, selected) {
    const name = root.fit(rawName)
    const q = root.query.toLowerCase()
    if (q === "")
      return esc(name)
    const i = name.toLowerCase().indexOf(q)
    if (i < 0)
      return esc(name)
    const c = selected ? "#000000" : root.matchColor
    return esc(name.slice(0, i)) + "<font color=\"" + c + "\">" + esc(name.slice(i, i + q.length)) + "</font>" + esc(name.slice(i + q.length))
  }

  IpcHandler {
    target: "launcher"
    function toggle() {
      root.toggle()
    }
    function close() {
      root.forceClose()
    }
  }

  readonly property var sortedApps: {
    const pins = root.pinnedIds
    const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
    const alpha = all.slice().sort((a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1)
    if (!pins || pins.length === 0)
      return alpha
    const byId = {}
    for (let i = 0; i < alpha.length; i++) {
      const id = root.entryId(alpha[i])
      if (!(id in byId))
        byId[id] = alpha[i]
    }
    const out = []
    const seen = {}
    for (let p = 0; p < pins.length; p++) {
      const e = byId[pins[p]]
      if (e && !seen[pins[p]]) {
        out.push(e)
        seen[pins[p]] = true
      }
    }
    for (let i = 0; i < alpha.length; i++) {
      const id = root.entryId(alpha[i])
      if (!seen[id])
        out.push(alpha[i])
    }
    return out
  }

  readonly property var lcNames: root.sortedApps.map(e => e.name.toLowerCase())

  readonly property var results: {
    const q = root.filterQuery.toLowerCase()
    if (q === "")
      return root.sortedApps
    const out = []
    for (let i = 0; i < root.sortedApps.length; i++)
      if (root.lcNames[i].includes(q))
        out.push(root.sortedApps[i])
    return out
  }

  onQueryChanged: {
    root.cancelHold()
    root.selIdx = 0
    root.hoverIdx = -1
    searchTimer.restart()
  }
  onResultsChanged: {
    if (root.selIdx >= root.results.length)
      root.selIdx = Math.max(0, root.results.length - 1)
    if (root.hoverIdx >= root.results.length)
      root.hoverIdx = -1
    if (root.holdIdx >= root.results.length)
      root.cancelHold()
  }
  onSelIdxChanged: {
    if (list)
      list.positionViewAtIndex(root.selIdx, ListView.Contain)
  }

  TextMetrics {
    id: tm
    font.family: root.fontFamily
    font.pointSize: 12
    text: "M"
  }
  readonly property int boxWidth: Math.round(30 * tm.advanceWidth) + 82

  PanelWindow {
    id: panel
    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { item: card.cardProg >= 1 ? card : null }
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
      width: root.boxWidth
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
                anchors.leftMargin: 0
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
                Keys.onEscapePressed: event => { root.cancelHold(); root.requestClose(); event.accepted = true }
                Keys.onUpPressed: { root.cancelHold(); root.mouseOverList = false; root.selIdx = Math.max(0, root.selIdx - 1) }
                Keys.onDownPressed: { root.cancelHold(); root.mouseOverList = false; root.selIdx = Math.min(root.results.length - 1, root.selIdx + 1) }
                Keys.onPressed: event => {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.isAutoRepeat) {
                      event.accepted = true
                      return
                    }
                    if (root.query.trim() !== "" && root.results.length === 0) {
                      root.holdIdx = -1
                      root.holdSource = "kbd-cmd"
                      root.holdFired = false
                      event.accepted = true
                      return
                    }
                    if (root.selIdx < 0 || root.selIdx >= root.results.length) {
                      event.accepted = true
                      return
                    }
                    root.startHold(root.selIdx, "kbd", root.pinHoldMsKbd)
                    event.accepted = true
                  } else if ((event.key === Qt.Key_N || event.key === Qt.Key_P) && (event.modifiers & Qt.ControlModifier)) {
                    root.cancelHold(); root.mouseOverList = false; root.selIdx = event.key === Qt.Key_N ? Math.min(root.results.length - 1, root.selIdx + 1) : Math.max(0, root.selIdx - 1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageDown) {
                    root.cancelHold(); root.mouseOverList = false; root.selIdx = Math.min(root.results.length - 1, root.selIdx + 5)
                    event.accepted = true
                  } else if (event.key === Qt.Key_PageUp) {
                    root.cancelHold(); root.mouseOverList = false; root.selIdx = Math.max(0, root.selIdx - 5)
                    event.accepted = true
                  }
                }
                Keys.onReleased: event => {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.isAutoRepeat) {
                      event.accepted = true
                      return
                    }
                    if (root.holdSource === "kbd-cmd") {
                      root.holdSource = ""
                      root.runCommand()
                      event.accepted = true
                      return
                    }
                    if (root.holdSource !== "kbd")
                      return
                    const fired = root.holdFired
                    const idx = root.holdIdx
                    root.cancelHold()
                    if (!fired) {
                      root.activateIdx(idx >= 0 ? idx : root.selIdx)
                    }
                    event.accepted = true
                  }
                }
              }
            }
          }
        }

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.preferredHeight: root.results.length === 0 ? 0 : Math.min(root.results.length * 28, 15 * 28)
          visible: root.results.length > 0
          Behavior on Layout.preferredHeight { NumberAnimation { duration: 70; easing.type: Easing.OutCubic } }
          clip: true
          interactive: true
          spacing: 0
          model: root.results
          currentIndex: root.selIdx
          highlight: Rectangle { color: Theme.fg }
          highlightMoveDuration: 120

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width
            height: 28
            readonly property bool isKeyboardSelected: root.selIdx === index
            readonly property bool isHovered: root.hoverIdx === index
            readonly property bool pinned: root.isPinned(modelData)
            readonly property bool holding: root.holdIdx === index && (root.holdSource === "kbd" || root.holdSource === "mouse")
            color: isHovered ? Theme.hover : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 0
              anchors.rightMargin: 6
              spacing: 10
              IconImage {
                source: Quickshell.iconPath(modelData.icon !== "" ? modelData.icon : "application-x-executable", "application-x-executable")
                implicitSize: 16
                Layout.alignment: Qt.AlignVCenter
              }
              Text {
                textFormat: Text.RichText
                text: root.hl(modelData.name, isKeyboardSelected)
                color: isKeyboardSelected ? Theme.onSelect : Theme.fg
                font.family: root.fontFamily
                font.pointSize: 12
                clip: true
                Layout.fillWidth: true
              }
              Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                visible: pinned
                QIcon {
                  anchors.centerIn: parent
                  name: "push_pin"
                  size: 14
                  color: isKeyboardSelected ? "#000000" : "#ffffff"
                }
              }
            }

            Rectangle {
              anchors.left: parent.left
              anchors.bottom: parent.bottom
              height: 2
              width: holding ? parent.width * root.holdProgress : 0
              visible: holding && root.holdProgress > 0
              color: isKeyboardSelected ? "#000000" : "#ffffff"
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.hoverIdx = index; root.mouseOverList = true }
              onExited: { if (root.hoverIdx === index) root.hoverIdx = -1; root.mouseOverList = false }
              onPressed: mouse => {
                if (mouse.button === Qt.LeftButton)
                  root.startHold(index, "mouse", root.pinHoldMsMouse)
              }
              onReleased: mouse => {
                if (mouse.button !== Qt.LeftButton)
                  return
                if (root.holdSource !== "mouse" || root.holdIdx !== index) {
                  if (root.holdSource === "mouse")
                    root.cancelHold()
                  return
                }
                const fired = root.holdFired
                root.cancelHold()
                if (!fired)
                  root.launch(index)
              }
              onClicked: mouse => {}
              onCanceled: root.cancelHold()
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.query.trim() !== "" && root.results.length === 0 ? 28 : 0
          visible: height > 0
          color: "transparent"
          border.color: Theme.outline
          border.width: 1
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 8
            Text {
              text: "Run command"
              color: root.matchColor
              font.family: root.fontFamily
              font.pointSize: 12
              Layout.alignment: Qt.AlignVCenter
            }
            Text {
              Layout.fillWidth: true
              text: root.fit(root.query)
              color: Theme.fg
              font.family: root.fontFamily
              font.pointSize: 12
              elide: Text.ElideRight
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runCommand()
          }
        }
      }
    }
  }
}
