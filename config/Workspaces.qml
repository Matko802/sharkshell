import QtQuick
import Quickshell
import Quickshell.Io

Row {
  spacing: 4
  property var wsItems: []

  function commit(next) {
    const json = JSON.stringify(next)
    if (json !== repeater.lastJson) {
      repeater.lastJson = json
      wsItems = next
      repeater.model = next
    }
  }

  function prune(list) {
    return list.filter(w => w.active || w.occupied || w.urgent)
  }

  function markActiveWorkspace(id, focused) {
    const focus = focused !== false
    let known = false
    const next = prune(wsItems.map(w => {
      if (w.id === id) known = true
      return {
        index: w.index,
        id: w.id,
        active: w.id === id ? focus : (focus ? false : w.active),
        occupied: w.occupied,
        urgent: w.urgent
      }
    }))
    if (!known) { requestRefresh(); return }
    commit(next)
  }

  function setActiveByIndex(idx) {
    let known = false
    const next = prune(wsItems.map(w => {
      if (w.index === idx) known = true
      return {
        index: w.index,
        id: w.id,
        active: w.index === idx,
        occupied: w.occupied,
        urgent: w.urgent
      }
    }))
    if (known) commit(next)
  }

  function markWorkspaceWindows(wsId, winId) {
    let known = false
    const next = prune(wsItems.map(w => {
      if (w.id !== wsId) return w
      known = true
      return {
        index: w.index,
        id: w.id,
        active: w.active,
        occupied: winId !== null && winId !== undefined,
        urgent: w.urgent
      }
    }))
    if (!known) { requestRefresh(); return }
    commit(next)
  }

  function requestRefresh() { refreshDebounce.restart() }

  Repeater {
    id: repeater
    model: []
    property string lastJson: ""
    delegate: Rectangle {
      property bool hovered: workspaceMa.containsMouse
      width: 20
      height: 20
      color: modelData.urgent ? Theme.error : (modelData.active ? Theme.outline : (hovered ? Theme.borderStrong : "transparent"))

      Text {
        anchors.centerIn: parent
        text: modelData.index
        color: modelData.urgent || modelData.active ? Theme.bg : (hovered ? Theme.fg : Theme.muted2)
        font.pixelSize: 11
      }

      MouseArea {
        id: workspaceMa
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
          if (niriCheck.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData.index)])
            setActiveByIndex(modelData.index)
          } else {
            if (mouse.button === Qt.RightButton)
              Quickshell.execDetached(["mmsg", "dispatch", "toggle," + modelData.index])
            else
              Quickshell.execDetached(["mmsg", "dispatch", "view," + modelData.index + ",0"])
          }
        }
      }
    }
  }

  Process {
    id: niriCheck
    property bool isNiri: false
    running: true
    command: ["sh", "-c", "command -v niri >/dev/null 2>&1 && niri msg -j workspaces >/dev/null 2>&1 && echo niri || echo mango"]
    stdout: SplitParser {
      onRead: data => {
        niriCheck.isNiri = data.trim() === "niri"
        if (niriCheck.isNiri) {
          niriInit.running = true
        } else {
          mangoWatch.running = true
        }
      }
    }
  }

  Process {
    id: niriInit
    running: false
    command: ["niri", "msg", "-j", "workspaces"]
    stdout: SplitParser {
      onRead: data => {
        try {
          const arr = JSON.parse(data)
          updateFromNiri(arr)
        } catch (e) {}
      }
    }
  }

  Process {
    id: niriWatch
    running: true
    command: ["sh", "-c", "command -v niri >/dev/null 2>&1 && stdbuf -oL niri msg -j event-stream 2>/dev/null || sleep 999999"]
    stdout: SplitParser {
      onRead: data => {
        try {
          const j = JSON.parse(data)
          const ws = j.WorkspacesChanged?.workspaces
          if (ws) { updateFromNiri(ws); return }
          const act = j.WorkspaceActivated
          if (act !== undefined) { markActiveWorkspace(act.id, act.focused); return }
          const waw = j.WorkspaceActiveWindowChanged
          if (waw !== undefined) { markWorkspaceWindows(waw.workspace_id, waw.active_window_id); return }
          if (j.OverviewOpenedOrClosed !== undefined
            || j.WindowUrgencyChanged !== undefined
            || j.WindowOpenedOrChanged !== undefined
            || j.WindowClosed !== undefined) requestRefresh()
        } catch (e) {}
      }
    }
  }
  Timer {
    id: refreshDebounce
    interval: 120
    repeat: false
    onTriggered: {
      if (!niriPoll.running) niriPoll.running = true
      else refreshDebounce.restart()
    }
  }
  Timer {
    interval: 2000
    running: niriCheck.isNiri
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!niriWatch.running) niriWatch.running = true
      else if (!niriPoll.running) niriPoll.running = true
    }
  }
  Process {
    id: niriPoll
    running: false
    command: ["niri", "msg", "-j", "workspaces"]
    stdout: SplitParser {
      onRead: data => {
        try {
          const arr = JSON.parse(data)
          updateFromNiri(arr)
        } catch (e) {}
      }
    }
  }

  function updateFromNiri(arr) {
    commit(arr.filter(w => w.is_focused || w.active_window_id !== null || w.is_urgent).map(w => ({
      index: w.idx,
      id: w.id,
      active: !!w.is_focused,
      occupied: w.active_window_id !== null,
      urgent: !!w.is_urgent
    })).sort((a, b) => a.index - b.index))
  }

  Process {
    id: mangoWatch
    running: false
    command: ["stdbuf", "-oL", "mmsg", "watch", "all-tags"]
    stdout: SplitParser {
      onRead: data => {
        try {
          const d = JSON.parse(data)
          const groups = d.all_tags || []
          const arr = groups.length ? (groups[0].tags || []) : []
          const next = arr
            .filter(t => t.is_active || (t.client_count || 0) > 0 || !!t.is_urgent)
            .map(t => ({
              index: t.index,
              active: !!t.is_active,
              occupied: (t.client_count || 0) > 0,
              urgent: !!t.is_urgent
            }))
          const json = JSON.stringify(next)
          if (json !== repeater.lastJson) {
            repeater.lastJson = json
            repeater.model = next
          }
        } catch (e) {}
      }
    }
  }
}
