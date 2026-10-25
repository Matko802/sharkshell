pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Scope {
  id: root

  property bool dnd: false
  property var notifications: []
  property var hiddenToasts: []
  property var notifPids: ({})
  property var pendingNotifs: []
  property var pendingSenders: []

  property int meaningfulCount: 0

  Process {
    id: senderWatch
    running: true
    command: ["sh", Quickshell.shellDir + "/notif-watch.sh"]
    stdout: SplitParser {
      onRead: data => root.handleSenderLine(data)
    }
    onExited: senderRestart.restart()
  }

  Timer {
    id: senderRestart
    interval: 1000
    onTriggered: senderWatch.running = true
  }

  function handleSenderLine(line) {
    const parts = String(line).split("\t")
    if (parts.length < 2)
      return
    const pid = parseInt(parts[0], 10)
    const app = parts.slice(1).join("\t")
    root.pendingSenders = [...root.pendingSenders, { "pid": isNaN(pid) ? -1 : pid, "app": app }]
    root.matchSenders()
  }

  function queueNotif(notif) {
    root.pendingNotifs = [...root.pendingNotifs, { "id": notif.id, "app": notif.appName || notif.desktopEntry || "" }]
    root.matchSenders()
  }

  function matchSenders() {
    const notifs = root.pendingNotifs.slice()
    const senders = root.pendingSenders.slice()
    const pids = Object.assign({}, root.notifPids)
    let changed = false
    while (notifs.length > 0 && senders.length > 0) {
      const n = notifs[0]
      let idx = -1
      for (let j = 0; j < senders.length; j++) {
        if (String(senders[j].app).toLowerCase() === String(n.app).toLowerCase()) {
          idx = j
          break
        }
      }
      if (idx < 0)
        idx = 0
      pids[n.id] = senders[idx].pid
      senders.splice(idx, 1)
      notifs.splice(0, 1)
      changed = true
    }
    if (changed)
      root.notifPids = pids
    root.pendingNotifs = notifs
    root.pendingSenders = senders
  }

  function forgetPid(id) {
    if (root.notifPids[id] === undefined)
      return
    const pids = Object.assign({}, root.notifPids)
    delete pids[id]
    root.notifPids = pids
  }

  function isMeaningful(n) {
    if (!n) return false
    const s = (n.summary || "").trim()
    const b = (n.body || "").trim()
    const im = n.image ? String(n.image) : ""
    return s !== "" || b !== "" || im !== ""
  }

  ListModel { id: popupModel }
  property alias popupModel: popupModel

  ListModel { id: centerModel }
  property alias centerModel: centerModel

  function centerIndex(id) {
    for (let i = 0; i < centerModel.count; i++)
      if (centerModel.get(i).notifId === id) return i
    return -1
  }

  function centerRemove(id) {
    const i = centerIndex(id)
    if (i >= 0) centerModel.remove(i)
  }

  function centerInsert(notif) {
    centerRemove(notif.id)
    centerModel.insert(0, {
      notifId: notif.id,
      app: notif.appName || notif.desktopEntry || "notification",
      desktopEntry: notif.desktopEntry || "",
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency ?? 1,
      expireTimeout: notif.expireTimeout ?? 0,
      image: notif.image || ""
    })
  }

  NotificationServer {
    id: server
    keepOnReload: true
    actionsSupported: true
    bodySupported: true
    imageSupported: true

    onNotification: notif => {
      root.queueNotif(notif)
      notif.tracked = true
      if (!root.isMeaningful(notif))
        return
      root.notifications = root.notifications.filter(n => n && n.id !== notif.id)
      root.notifications = [notif, ...root.notifications]
      root.meaningfulCount = root.notifications.length
      root.centerInsert(notif)
      console.log("QS notif", notif.id, notif.summary, "popup before", popupModel.count)
      if ((root.dnd && notif.urgency !== NotificationUrgency.Critical) || ControlState.open || ClockState.open || SettingsState.open) {
        root.hiddenToasts = [...root.hiddenToasts, notif.id]
        return
      }
      addPopup(notif)
      console.log("QS added popup", notif.id, "count", popupModel.count)
    }
  }

  function addPopup(notif) {
    popupModel.insert(0, {
      notifId: notif.id,
      app: notif.appName || notif.desktopEntry || "notification",
      desktopEntry: notif.desktopEntry || "",
      appName: notif.appName || "",
      appIcon: notif.appIcon || "",
      summary: notif.summary || "",
      body: notif.body || "",
      urgency: notif.urgency ?? 1,
      expireTimeout: notif.expireTimeout ?? 0,
      image: notif.image || "",
      leaving: false
    })
    while (popupModel.count > 4)
      popupModel.remove(popupModel.count - 1)
    if (popupModel.count > 3) {
      for (var i = popupModel.count - 1; i >= 0; i--) {
        if (!popupModel.get(i).leaving) {
          if (i === 0) popupModel.remove(0)
          else popupModel.setProperty(i, "leaving", true)
          break
        }
      }
    }
  }

  function findPopupIndex(id) {
    for (let i = 0; i < popupModel.count; i++)
      if (popupModel.get(i).notifId === id) return i
    return -1
  }

  function removePopup(id) {
    const i = findPopupIndex(id)
    if (i >= 0) popupModel.remove(i)
    root.hiddenToasts = root.hiddenToasts.filter(x => x !== id)
  }

  function hideToast(id) {
    if (!root.hiddenToasts.includes(id)) root.hiddenToasts = [...root.hiddenToasts, id]
    const i = findPopupIndex(id)
    if (i >= 0) popupModel.remove(i)
  }

  function hideAllPopups() {
    popupModel.clear()
  }

  function dismiss(notif) {
    if (!notif)
      return
    try { notif.dismiss() } catch (e) {}
    root.notifications = root.notifications.filter(n => n && n.id !== notif.id)
    root.meaningfulCount = root.notifications.length
    root.centerRemove(notif.id)
    root.hiddenToasts = root.hiddenToasts.filter(x => x !== notif.id)
    const i = findPopupIndex(notif.id)
    if (i >= 0) popupModel.remove(i)
    root.forgetPid(notif.id)
  }

  function dismissById(id) {
    const live = root.notifications.find(n => n && n.id === id) || null
    if (live) root.dismiss(live)
    else {
      root.centerRemove(id)
      root.hiddenToasts = root.hiddenToasts.filter(x => x !== id)
      const i = findPopupIndex(id)
      if (i >= 0) popupModel.remove(i)
      root.forgetPid(id)
    }
  }

  function clearAll() {
    root.notifications.forEach(n => { try { n.dismiss() } catch (e) {} })
    root.notifications = []
    root.meaningfulCount = 0
    root.centerModel.clear()
    root.hiddenToasts = []
    popupModel.clear()
    root.notifPids = ({})
    root.pendingNotifs = []
    root.pendingSenders = []
  }

  function getLive(id) {
    return root.notifications.find(n => n && n.id === id) || null
  }

  function setDnd(enabled) {
    root.dnd = enabled
    if (enabled) {
      for (let i = 0; i < popupModel.count; i++) {
        const row = popupModel.get(i)
        const live = root.notifications.find(n => n && n.id === row.notifId)
        if (!(live && live.urgency === NotificationUrgency.Critical))
          root.hiddenToasts = [...root.hiddenToasts, row.notifId]
      }
      popupModel.clear()
    }
  }

  function toggleDnd() { root.setDnd(!root.dnd) }

  function defaultAction(live) {
    if (!live || !live.actions)
      return null
    const acts = live.actions
    for (let i = 0; i < acts.length; i++) {
      const a = acts[i]
      if (!a)
        continue
      const text = String(a.text || "").toLowerCase()
      if (a.identifier === "default" || text === "view" || text === "open")
        return a
    }
    return null
  }

  function activate(id) {
    const live = root.notifications.find(n => n && n.id === id) || null
    if (!live)
      return false
    const action = root.defaultAction(live)
    if (action) {
      try {
        action.invoke()
      } catch (e) {
        console.log("[notif] default action failed:", e)
      }
    }
    const pid = root.notifPids[id] || -1
    AppFocus.focusPid(pid, live.desktopEntry || live.appName)
    return !!action
  }

  function focusPopup(id) {
    root.activate(id)
  }
}
