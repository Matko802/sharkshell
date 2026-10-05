import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Util.js" as Util

PanelWindow {
  id: root

  property var targetScreen: null

  anchors.top: true
  margins.top: 30
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-modal"
  BackgroundEffect.blurRegion: Region { item: (!slideIn.running && !slideOut.running) ? card : null }
  mask: Region { item: card }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property bool shown: false
  property int activeTab: 0
  property date calDate: new Date()
  property int mediaIdx: 0
  onMediaIdxChanged: {
    if (mediaIdx < 0) mediaIdx = 0
    if (Mpris.players.values && Mpris.players.values.length > 0 && mediaIdx >= Mpris.players.values.length) mediaIdx = Mpris.players.values.length - 1
    if (Mpris.players.values.length === 0) mediaIdx = 0
  }
  Connections {
    target: Mpris.players
    function onValuesChanged() {
      if (Mpris.players.values && root.mediaIdx >= Mpris.players.values.length) root.mediaIdx = Math.max(0, Mpris.players.values.length - 1)
      if (Mpris.players.values && Mpris.players.values.length > 0) {
        const last = Mpris.players.values ? Mpris.players.values.length - 1 : -1
        const p = Mpris.players.values[last]
        if (p && p.isPlaying) root.mediaIdx = last
      }
    }
  }
  property var _wasPlaying: []
  Timer {
    interval: 1000
    running: root.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const vals = Mpris.players.values || []
      const prev = root._wasPlaying
      let latest = -1
      for (let i = 0; i < vals.length; i++) {
        if (vals[i] && vals[i].isPlaying && prev[i] !== true) latest = i
      }
      root._wasPlaying = vals.map(v => !!(v && v.isPlaying))
      if (latest >= 0) root.mediaIdx = latest
    }
  }

  property var sysVals: ["--", "--", "--", "--"]
  property var cpuHist: []
  property var memHist: []
  property var diskHist: []
  property var gpuHist: []
  property var _prevCpu: null

  screen: root.targetScreen
  visible: root.shown && (!ClockState.screen || ClockState.screen === root.targetScreen)
  implicitWidth: 700
  implicitHeight: 424

  function pushHist(arr, v) {
    let a = arr.slice()
    a.push(Util.clampPct(v))
    if (a.length > 30) a.shift()
    return a
  }

  property var _iconCache: ({})
  function fileArt(n) {
    const im = n && n.image ? String(n.image) : ""
    return (im !== "" && (im.startsWith("/") || im.startsWith("file://") || im.startsWith("image://"))) ? im : ""
  }
  function iconSrc(n) {
    const key = "i|" + ((n && n.appIcon) || "") + "|" + ((n && n.desktopEntry) || "")
    const hit = root._iconCache[key]
    if (hit !== undefined) return hit
    let s = Quickshell.iconPath("dialog-information", "dialog-information")
    const ic = (n && n.appIcon) || ""
    if (ic !== "") {
      s = Quickshell.iconPath(ic, "dialog-information")
    } else {
      const de = (n && n.desktopEntry) || ""
      if (de !== "") {
        const e = DesktopEntries.heuristicLookup(de)
        if (e && e.icon) s = Quickshell.iconPath(e.icon, "dialog-information")
        else s = Quickshell.iconPath(de, "dialog-information")
      }
    }
    if (Object.keys(root._iconCache).length < 200) root._iconCache[key] = s
    return s
  }
  readonly property string cavaConf: "[general]\nbars = 48\nframerate = 30\n[input]\nmethod = pulse\nsource = auto\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n"
  FileView {
    id: cavaConfFile
    path: Quickshell.env("HOME") + "/.cache/sharkshell/cava.conf"
  }
  Process {
    id: cavaConfInit
    running: true
    command: ["bash", "-c", "mkdir -p \"$HOME/.cache/sharkshell\""]
    onExited: cavaConfFile.setText(root.cavaConf)
  }
  FileView { id: statFile; path: "/proc/stat" }
  FileView { id: memFile; path: "/proc/meminfo" }
  Process {
    id: diskProc
    command: ["sh", "-c", "df --output=pcent / 2>/dev/null | tail -1 | tr -d ' %'"]
    stdout: StdioCollector {
      onStreamFinished: {
        const v = text.trim()
        if (v !== "" && !isNaN(parseInt(v))) {
          const iv = Util.clampPct(parseInt(v))
          const cur = root.sysVals.slice()
          while (cur.length < 4) cur.push("--")
          cur[2] = String(iv)
          root.sysVals = cur
          root.diskHist = root.pushHist(root.diskHist, iv)
        }
      }
    }
  }
  Process {
    id: gpuProc
    command: ["sh", "-c", "for f in /sys/class/drm/card*/device/gpu_busy_percent; do v=$(cat \"$f\" 2>/dev/null); if [ -n \"$v\" ]; then printf '%s' \"$v\"; break; fi; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        const v = text.trim()
        if (v !== "" && !isNaN(parseInt(v))) {
          const iv = Util.clampPct(parseInt(v))
          const cur = root.sysVals.slice()
          while (cur.length < 4) cur.push("--")
          cur[3] = String(iv)
          root.sysVals = cur
          root.gpuHist = root.pushHist(root.gpuHist, iv)
        }
      }
    }
  }
  Timer {
    interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
    onTriggered: { statFile.reload(); memFile.reload(); diskProc.running = true; gpuProc.running = true }
  }
  Connections {
    target: statFile
    function onLoaded() {
      const txt = statFile.text()
      if (!txt) return
      const m = txt.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/m)
      if (!m) return
      const idle = parseInt(m[4]) + parseInt(m[5])
      const total = m.slice(1,9).reduce((a,b)=>a+parseInt(b),0)
      if (root._prevCpu && root._prevCpu.total > 0) {
        const dT = total - root._prevCpu.total
        const dI = idle - root._prevCpu.idle
        if (dT > 0) {
          const iv = Util.clampPct(Math.round((1 - dI/dT)*100))
          const cur = root.sysVals.slice()
          while (cur.length < 4) cur.push("--")
          cur[0] = String(iv)
          root.sysVals = cur
          root.cpuHist = root.pushHist(root.cpuHist, iv)
        }
      }
      root._prevCpu = { total, idle }
    }
  }
  Connections {
    target: memFile
    function onLoaded() {
      const txt = memFile.text()
      if (!txt) return
      const tM = txt.match(/MemTotal:\s+(\d+)\s+kB/)
      const aM = txt.match(/MemAvailable:\s+(\d+)\s+kB/)
      if (!tM) return
      const total = parseInt(tM[1])
      let avail = aM ? parseInt(aM[1]) : 0
      if (!aM) {
        const fM = txt.match(/MemFree:\s+(\d+)\s+kB/)
        const bM = txt.match(/Buffers:\s+(\d+)\s+kB/)
        const cM = txt.match(/Cached:\s+(\d+)\s+kB/)
        avail = (fM?parseInt(fM[1]):0)+(bM?parseInt(bM[1]):0)+(cM?parseInt(cM[1]):0)
      }
      if (total > 0) {
        const iv = Util.clampPct(Math.round((total - avail)/total*100))
        const cur = root.sysVals.slice()
        while (cur.length < 4) cur.push("--")
        cur[1] = String(iv)
        root.sysVals = cur
        root.memHist = root.pushHist(root.memHist, iv)
      }
    }
  }

  Connections {
    target: ClockState
    function onOpenChanged() {
      if (ClockState.open && (!ClockState.screen || ClockState.screen === root.targetScreen))
        root.shown = true
      else if (!ClockState.open && root.shown && !slideOut.running)
        slideOut.restart()
    }
  }
  onShownChanged: {
    if (shown) { card.y = -card.height - 8; slideIn.restart() }
  }
  NumberAnimation { id: slideIn; target: card; property: "y"; to: 0; duration: 250; easing.type: Easing.OutCubic }
  NumberAnimation { id: slideOut; target: card; property: "y"; to: -card.height - 12; duration: 250; easing.type: Easing.InCubic; onFinished: root.shown = false }
  onActiveTabChanged: {
    if (root.activeTab === 2 && root.shown) mediaSingle.fetchWebArt()
  }
  Timer {
    running: root.shown
    repeat: true
    interval: 500
    onTriggered: {
      if (root.shown && !card.activeFocus)
        card.forceActiveFocus()
    }
  }

  Rectangle {
    id: card
    width: 700
    height: 424
    clip: true
    anchors.horizontalCenter: parent.horizontalCenter
    color: Theme.bg
    border.color: Theme.outline
    border.width: 1
    focus: true
    Keys.onTabPressed: root.activeTab = (root.activeTab + 1) % 3
    Keys.onBacktabPressed: root.activeTab = (root.activeTab + 2) % 3
    Keys.onEscapePressed: ClockState.close()

    MouseArea { anchors.fill: parent }

    ColumnLayout {
      id: col
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      anchors.topMargin: 12
      height: 400
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
          model: [
            { label: "Calendar", idx: 0 },
            { label: "System",   idx: 1 },
            { label: "Media",    idx: 2 }
          ]
          delegate: Item {
            required property var modelData
            Layout.preferredWidth: 80
            Layout.preferredHeight: 28
            property bool active: root.activeTab === modelData.idx
            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: parent.active ? Theme.fg : Theme.muted2
              font.family: Theme.fontFamily
              font.pixelSize: 12
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = modelData.idx
            }
          }
        }
        Item { Layout.fillWidth: true }
        IconBtn {
          Layout.preferredWidth: 28
          Layout.preferredHeight: 28
          icon: NotificationServer.dnd ? "notifications-disabled" : "notifications"
          iconSize: 16
          onClicked: NotificationServer.setDnd(!NotificationServer.dnd)
        }
          IconBtn {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            icon: IdleManager.stayAwake ? "coffee" : "coffee-off"
            iconSize: 16
            onClicked: IdleManager.stayAwake = !IdleManager.stayAwake
          }
          IconBtn {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            icon: "settings"
            iconSize: 16
            onClicked: { ClockState.close(); SettingsState.toggle({ screen: root.targetScreen }) }
          }
      }

      Item {
        id: swipeContainer
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Row {
          id: swipeRow
          x: root.activeTab * -(swipeContainer.width)
          Behavior on x {
            NumberAnimation { duration: 130; easing.type: Theme.easingOut }
          }

          Item {
            width: swipeContainer.width
            height: swipeContainer.height

            ColumnLayout {
              anchors.left: parent.left
              anchors.right: parent.horizontalCenter
              anchors.rightMargin: 8
              anchors.top: parent.top
              anchors.topMargin: 8
              anchors.bottom: parent.bottom
              spacing: 4

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  IconBtn {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    icon: "chevron-left"
                    iconSize: 16
                    onClicked: {
                      const d = root.calDate
                      root.calDate = new Date(d.getFullYear(), d.getMonth() - 1, 1)
                    }
                  }
                  Item { Layout.fillWidth: true; Layout.preferredHeight: 28
                    Text {
                      anchors.centerIn: parent
                      text: root.calDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                      color: Theme.fg
                      font.family: Theme.fontFamily
                      font.pixelSize: 12
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.calDate = new Date()
                    }
                  }
                  IconBtn {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    icon: "chevron-right"
                    iconSize: 16
                    onClicked: {
                      const d = root.calDate
                      root.calDate = new Date(d.getFullYear(), d.getMonth() + 1, 1)
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Repeater {
                    model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                    delegate: Text {
                      text: modelData
                      color: Theme.muted2
                      font.family: Theme.fontFamily
                      font.pixelSize: 9
                      Layout.fillWidth: true
                      Layout.preferredHeight: 20
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }
                  }
                }

                MonthGrid {
                  id: grid
                  Layout.fillWidth: true
                  Layout.preferredHeight: implicitHeight
                  month: root.calDate.getMonth()
                  year: root.calDate.getFullYear()
                  locale: Qt.locale()
                  spacing: 0
                  delegate: Item {
                    required property var model
                    implicitWidth: 32
                    implicitHeight: 30
                    Rectangle {
                      anchors.centerIn: parent
                      width: 24; height: 24
                      color: model.today ? Theme.fg : "transparent"
                    }
                    Text {
                      anchors.centerIn: parent
                      text: grid.locale.toString(model.date, "d")
                      color: model.today ? Theme.bg : (model.month === grid.month ? Theme.fg : Theme.muted3)
                      font.family: Theme.fontFamily
                      font.pixelSize: 11
                    }
                  }
                }
              }

              Item {
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                ColumnLayout {
                  anchors.fill: parent
                  spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  Text {
                    text: "Notifications"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                  }
                  Item { Layout.fillWidth: true; height: 1 }
                  Text {
                    text: NotificationServer.meaningfulCount > 0
                          ? String(NotificationServer.meaningfulCount) : ""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                  }
                  Text {
                    id: clearBtn
                    text: "Clear"
                    color: clearBtnMa.containsMouse ? Theme.fg : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    visible: NotificationServer.meaningfulCount > 0
                    MouseArea {
                      id: clearBtnMa
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: NotificationServer.clearAll()
                    }
                  }
                }

                ListView {
                  id: notifList
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  clip: true
                  spacing: 4
                  interactive: true
                  boundsBehavior: Flickable.StopAtBounds
                  model: NotificationServer.centerModel

                  add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Theme.easingOut }
                    NumberAnimation { property: "x"; from: 60; to: 0; duration: 200; easing.type: Theme.easingOut }
                  }
                  populate: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Theme.easingOut }
                    NumberAnimation { property: "x"; from: 60; to: 0; duration: 200; easing.type: Theme.easingOut }
                  }
                  remove: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Theme.easingIn }
                    NumberAnimation { property: "x"; from: 0; to: 60; duration: 150; easing.type: Theme.easingIn }
                  }
                  displaced: Transition {
                    NumberAnimation { property: "y"; duration: 200; easing.type: Theme.easingOut }
                  }
                  delegate: Rectangle {
                    width: notifList.width
                    height: nRow.implicitHeight + 16
                    color: Theme.bgAlt
                    border.color: Theme.border
                    border.width: 1
                    RowLayout {
                      id: nRow
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: 8
                      spacing: 8
                      Item {
                        Layout.preferredWidth: 20; Layout.preferredHeight: 20; Layout.alignment: Qt.AlignTop
                        visible: {
                          const ic = model.appIcon || ""
                          const de = model.desktopEntry || ""
                          const im = model.image ? String(model.image) : ""
                          return im !== "" || ic !== "" || de !== ""
                        }
                        IconImage {
                          anchors.fill: parent; anchors.margins: 1
                          visible: { const im = model.image ? String(model.image) : ""; return !(im !== "" && (im.startsWith("/") || im.startsWith("file://") || im.startsWith("image://"))) }
                          source: root.iconSrc(model)
                          implicitSize: 20
                        }
                        Image {
                          anchors.fill: parent; anchors.margins: 1
                          visible: { const im = model.image ? String(model.image) : ""; return im !== "" && (im.startsWith("/") || im.startsWith("file://") || im.startsWith("image://")) }
                          source: model.image ? String(model.image) : ""
                          fillMode: Image.PreserveAspectCrop
                          sourceSize.width: 40; sourceSize.height: 40; asynchronous: true
                        }
                      }
                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 2
                        Text { text: (model.appName || model.desktopEntry || "").toUpperCase(); color: Theme.muted2; font.family: Theme.fontFamily; font.pixelSize: 8; font.letterSpacing: 1; elide: Text.ElideRight; Layout.fillWidth: true; visible: text !== "" }
                         Text { text: model.summary || ""; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                         Text { text: model.body || ""; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 9; Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: (model.body || "") !== "" }
                      }
                      Rectangle {
                        Layout.preferredWidth: 14; Layout.preferredHeight: 14; Layout.alignment: Qt.AlignTop
                        color: dMa.containsMouse ? Theme.fg : "transparent"
                        Text { anchors.centerIn: parent; text: "x"; color: dMa.containsMouse ? Theme.bg : Theme.muted2; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true }
                        MouseArea { id: dMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotificationServer.dismissById(model.notifId) }
                      }
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor; z: -1
                      onClicked: {
                        const live = NotificationServer.getLive(model.notifId)
                        const acts = live && live.actions ? live.actions : []
                        for (let i = 0; i < acts.length; i++) { const a = acts[i]; if (a && (a.identifier === "default" || (a.text || "").toLowerCase() === "view" || (a.text || "").toLowerCase() === "open")) { try { a.invoke() } catch(e) {} break } }
                        AppFocus.focus(model); ClockState.close(); NotificationServer.dismissById(model.notifId)
                      }
                    }
                  }
                }
                }

                Text {
                  anchors.centerIn: parent
                  text: "no notifications"
                  color: Theme.muted2
                  font.family: Theme.fontFamily
                  font.pixelSize: 10
                   visible: NotificationServer.meaningfulCount === 0
                }
              }
            }

          Item {
            width: swipeContainer.width
            height: swipeContainer.height

            GridLayout {
              anchors.fill: parent
              anchors.margins: 8
              columns: 2
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: [
                  { label: "CPU",  icon: "brand-speedtest", idx: 0 },
                  { label: "MEM",  icon: "cpu", idx: 1 },
                  { label: "DISK", icon: "database", idx: 2 },
                  { label: "GPU",  icon: "device-desktop", idx: 3 }
                ]
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  color: Theme.bgAlt
                  border.color: Theme.border
                  border.width: 1
                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      Item { Layout.preferredWidth: 14; Layout.preferredHeight: 14; QIcon { anchors.centerIn: parent; name: modelData.icon; size: 14; color: Theme.fg } }
                      Text { text: "  " + modelData.label; color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 10 }
                      Item { Layout.fillWidth: true; height: 1 }
                      Text {
                        text: { const v = root.sysVals[modelData.idx]; return v !== undefined && v !== "--" ? v + "%" : "--" }
                        color: Theme.fg; font.family: Theme.fontFamily; font.pixelSize: 11
                      }
                    }

                    Item {
                      Layout.fillWidth: true; Layout.fillHeight: true
                      Canvas {
                        anchors.centerIn: parent; width: 72; height: 72
                        property real pct: { const v = parseInt(root.sysVals[modelData.idx] || "0"); return Util.clampPct(isNaN(v) ? 0 : v) / 100 }
                        onPctChanged: requestPaint()
                        onPaint: {
                          const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                          const cx = width/2, cy = height/2, r = 28, lw = 3
                          ctx.lineWidth = lw; ctx.lineCap = "round"
                          ctx.beginPath(); ctx.strokeStyle = Theme.border; ctx.arc(cx, cy, r, 0, Math.PI*2); ctx.stroke()
                          if (pct > 0) { ctx.beginPath(); ctx.strokeStyle = Theme.fg; ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + Math.PI*2*pct); ctx.stroke() }
                        }
                        QIcon { anchors.centerIn: parent; name: modelData.icon; size: 16; color: Theme.fg }
                      }
                    }

                    Canvas {
                      Layout.fillWidth: true; Layout.preferredHeight: 20
                      property var hist: { if (modelData.idx === 0) return root.cpuHist; if (modelData.idx === 1) return root.memHist; if (modelData.idx === 2) return root.diskHist; return root.gpuHist }
                      onHistChanged: requestPaint()
                      onPaint: {
                        const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                        if (!hist || hist.length < 2) return
                        ctx.strokeStyle = Theme.fg; ctx.lineWidth = 1; ctx.beginPath()
                        for (let i = 0; i < hist.length; i++) {
                          const x = i / Math.max(1, hist.length - 1) * width; const y = height - (hist[i] / 100 * height)
                          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                      }
                    }
                  }
                }
              }
            }
          }

          Item {
            width: swipeContainer.width
            height: swipeContainer.height

            ColumnLayout {
              anchors.fill: parent
              spacing: 0



                Item {
                  id: mediaSingle
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  visible: true
                  property var levels: []
                  readonly property int visBars: VisualizerState.bars
                 property var cur: (Mpris.players.values && Mpris.players.values.length > root.mediaIdx) ? Mpris.players.values[root.mediaIdx] : null
                 property string rawArt: cur && cur.trackArtUrl ? String(cur.trackArtUrl) : ""
                 property bool artFallback: false
                 onRawArtChanged: artFallback = false
                 property string hiResArt: {
                   let u = rawArt
                   if (u === "") return ""
                   if (u.indexOf("googleusercontent.com") !== -1 || u.indexOf("ggpht.com") !== -1) {
                     u = u.replace(/=s\d+/, "=s544")
                     u = u.replace(/=w\d+-h\d+/, "=w544-h544")
                   }
                   if (u.indexOf("ytimg.com") !== -1) {
                     u = u.replace(/\/(hqdefault|mqdefault|sddefault)\./, "/maxresdefault.")
                     u = u.replace(/\/default\./, "/maxresdefault.")
                   }
                   return u
                 }
                 property string artUrl: (artFallback || hiResArt === "") ? rawArt : hiResArt
                 property string trackKey: (cur ? (cur.trackTitle || "") : "") + "\n" + (cur ? (cur.trackArtist || "") : "")
                 onTrackKeyChanged: fetchWebArt()
                 property string webKey: ""
                 property string webArt: ""
                 property string webFailedKey: ""
                 function normName(s) {
                   return String(s || "").toLowerCase().replace(/\(.*?\)|\[.*?\]/g, "").replace(/\s+/g, " ").trim()
                 }
                 function artMatches(rTitle, rArtist, qTitle, qArtist) {
                   const rt = normName(rTitle)
                   const qt = normName(qTitle)
                   if (rt === "" || qt === "") return false
                   if (rt.indexOf(qt) === -1 && qt.indexOf(rt) === -1) return false
                   const ra = normName(rArtist)
                   const qa = normName(qArtist)
                   if (qa === "" || ra === "") return true
                   return ra.indexOf(qa) !== -1 || qa.indexOf(ra) !== -1
                 }
                  function fetchWebArt() {
                    if (root.activeTab !== 2) return
                    const title = cur ? (cur.trackTitle || "") : ""
                   const artist = cur ? (cur.trackArtist || "") : ""
                   const key = artist + " - " + title
                   if (key !== "" && key === webKey && webArt !== "") return
                   webKey = key
                   webArt = ""
                   if (title === "" && artist === "") return
                   requestArt(key, (artist + " " + title).trim(), artist, title)
                 }
                 function requestArt(key, query, qArtist, qTitle) {
                   const xhr = new XMLHttpRequest()
                   xhr.open("GET", "https://api.deezer.com/search?q=" + encodeURIComponent(query))
                   xhr.timeout = 8000
                   xhr.onreadystatechange = function() {
                     if (xhr.readyState !== XMLHttpRequest.DONE) return
                     if (webKey !== key) return
                     let u = ""
                     try {
                       const j = JSON.parse(xhr.responseText)
                       const list = j && j.data ? j.data : []
                       for (let i = 0; i < list.length && i < 5; i++) {
                         const r = list[i]
                         const al = r ? r.album : null
                         if (!r || !al) continue
                         if (!artMatches(r.title || "", (r.artist && r.artist.name) || "", qTitle, qArtist)) continue
                         u = al.cover_xl || al.cover_big || al.cover_medium || al.cover || ""
                         if (u !== "") break
                       }
                     } catch (e) {}
                     if (u !== "") {
                       if (webKey === key) webArt = String(u)
                     } else if (qArtist !== "" && query !== qTitle) {
                       requestArt(key, qTitle, "", qTitle)
                     }
                   }
                   xhr.send()
                 }
                 property string displayArt: (webArt !== "" && webFailedKey !== webKey) ? webArt : artUrl
                 ColumnLayout {
                    id: msRoot
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                      id: msBody
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      spacing: 0

                       ColumnLayout {
                          id: msLeft
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          Layout.leftMargin: 12
                          Layout.rightMargin: 12
                          Layout.bottomMargin: 6
                          spacing: 6

                        ColumnLayout {
                          visible: true
                          spacing: 2
                          Text {
                            Layout.fillWidth: true
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: mediaSingle.cur ? (mediaSingle.cur.trackTitle || "Unknown") : "no songs playing"
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            wrapMode: Text.Wrap
                          }
                          Text {
                            Layout.fillWidth: true
                            text: {
                              if (!mediaSingle.cur) return ""
                              const a = mediaSingle.cur.trackArtist || ""
                              const b = mediaSingle.cur.trackAlbum || ""
                              if (a && b) return a + " — " + b
                              return a || b || (mediaSingle.cur.identity || "")
                            }
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                          }
                        }

                        Rectangle {
                          id: termRect
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          Layout.preferredHeight: 150
                          color: "transparent"
                          clip: true
                          Process {
                            id: visProc
                            running: root.shown && root.activeTab === 2
                            command: ["sh", "-c", "V=\"$HOME/.cache/sharkshell/cava.conf\"; L=/mnt/ssd/My-Files/Projects/sharkvis/target/release/sharkvis; M=" + VisualizerState.mode + "; B=" + VisualizerState.bars + "; if [ -x \"$L\" ]; then exec \"$L\" --raw --raw-mode \"$M\" --bars \"$B\" --fps 30; elif command -v sharkvis >/dev/null 2>&1; then exec sharkvis --raw --raw-mode \"$M\" --bars \"$B\" --fps 30; elif command -v cava >/dev/null 2>&1; then exec cava -p \"$V\"; else exit 0; fi"]
                            stdout: SplitParser {
                              onRead: data => {
                                const parts = String(data).split(";")
                                const arr = []
                                for (let i = 0; i < parts.length; i++) {
                                  const v = parseInt(parts[i], 10)
                                  if (!isNaN(v)) arr.push(Util.clampPct(v))
                                }
                                if (arr.length > 0) mediaSingle.levels = arr
                              }
                            }
                          }
                          Row {
                            id: barRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            visible: VisualizerState.mode === "bars"
                            Repeater {
                              model: mediaSingle.visBars
                              delegate: Item {
                                required property int index
                                width: Math.max(1, (barRow.width - (mediaSingle.visBars - 1) * barRow.spacing) / mediaSingle.visBars)
                                height: barRow.height
                                Rectangle {
                                  anchors.bottom: parent.bottom
                                  anchors.left: parent.left
                                  anchors.right: parent.right
                                  height: Math.max(2, parent.height * ((mediaSingle.levels[index] || 0) / 100))
                                  color: Theme.fg
                                  Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                                }
                              }
                            }
                          }
                          Canvas {
                            id: waveCanvas
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: VisualizerState.mode !== "bars"
                            property var pts: mediaSingle.levels
                            onPtsChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()
                            function strokePath(ctx, w, a) {
                              ctx.strokeStyle = Theme.fg
                              ctx.lineWidth = w
                              ctx.globalAlpha = a
                              ctx.beginPath()
                              const n = pts ? pts.length : 0
                              for (var i = 0; i < n; i++) {
                                var v = Util.clampPct(pts[i] || 0)
                                var x = (i / (n - 1)) * width
                                var y = height - (v / 100) * height
                                if (i === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                              }
                              ctx.stroke()
                              ctx.globalAlpha = 1
                            }
                            function scopePath(ctx, w, a) {
                              ctx.strokeStyle = Theme.fg
                              ctx.lineWidth = w
                              ctx.globalAlpha = a
                              ctx.beginPath()
                              const n = Math.floor((pts ? pts.length : 0) / 2)
                              for (var i = 0; i < n; i++) {
                                var x = Util.clampPct(pts[2 * i] || 0) / 100 * width
                                var y = height - Util.clampPct(pts[2 * i + 1] || 0) / 100 * height
                                if (i === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                              }
                              ctx.stroke()
                              ctx.globalAlpha = 1
                            }
                            onPaint: {
                              var ctx = getContext("2d")
                              var n = pts ? pts.length : 0
                              if (width <= 0 || height <= 0) return
                              ctx.lineJoin = "round"
                              if (VisualizerState.mode === "oscilloscope") {
                                if (n < 4) return
                                ctx.clearRect(0, 0, width, height)
                                scopePath(ctx, 2, 1)
                              } else {
                                if (n < 2) return
                                ctx.clearRect(0, 0, width, height)
                                strokePath(ctx, 2, 1)
                              }
                            }
                          }
                          Connections {
                            target: VisualizerState
                            function onModeChanged() { visProc.running = false; visProc.running = true }
                            function onBarsChanged() { visProc.running = false; visProc.running = true }
                          }
                        }

                        Rectangle {
                          Layout.alignment: Qt.AlignHCenter
                          Layout.topMargin: -4
                          implicitWidth: 148
                          implicitHeight: 36
                          color: Theme.bgAlt
                          border.color: Theme.border
                          border.width: 1
                          RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            Item {
                              Layout.preferredWidth: 44
                              Layout.fillHeight: true
                              Rectangle {
                                anchors.fill: parent
                                color: mPrevMa.pressed ? Theme.fg : "transparent"
                              }
                              QIcon {
                                anchors.centerIn: parent
                                name: "player-skip-back"
                                size: 18
                                color: mPrevMa.pressed ? Theme.bg : Theme.fg
                              }
                              MouseArea {
                                id: mPrevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: if (mediaSingle.cur) mediaSingle.cur.previous()
                              }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border }
                            Item {
                              Layout.preferredWidth: 56
                              Layout.fillHeight: true
                              Rectangle {
                                anchors.fill: parent
                                color: mPlayMa.pressed ? Theme.fg : "transparent"
                              }
                              QIcon {
                                anchors.centerIn: parent
                                name: mediaSingle.cur && mediaSingle.cur.isPlaying ? "player-pause" : "player-play"
                                size: 22
                                color: mPlayMa.pressed ? Theme.bg : Theme.fg
                              }
                              MouseArea {
                                id: mPlayMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: if (mediaSingle.cur) mediaSingle.cur.togglePlaying()
                              }
                            }
                            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.border }
                            Item {
                              Layout.preferredWidth: 44
                              Layout.fillHeight: true
                              Rectangle {
                                anchors.fill: parent
                                color: mNextMa.pressed ? Theme.fg : "transparent"
                              }
                              QIcon {
                                anchors.centerIn: parent
                                name: "player-skip-forward"
                                size: 18
                                color: mNextMa.pressed ? Theme.bg : Theme.fg
                              }
                              MouseArea {
                                id: mNextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: if (mediaSingle.cur) mediaSingle.cur.next()
                              }
                            }
                          }
                        }

                        Rectangle {
                          id: progressBar
                          Layout.alignment: Qt.AlignHCenter
                          Layout.topMargin: 4
                          implicitWidth: 220
                          Layout.preferredHeight: 18
                          color: "transparent"
                          visible: mediaSingle.cur && mediaSingle.cur.lengthSupported
                          property bool hovered: false
                          property bool scrubbing: false
                          function fmtTime(t) {
                            if (!t || t < 0) t = 0
                            const m = Math.floor(t / 60)
                            const s = Math.floor(t % 60)
                            return m + ":" + (s < 10 ? "0" : "") + s
                          }
                          function seek(x) {
                            if (mediaSingle.cur && mediaSingle.cur.positionSupported)
                              mediaSingle.cur.position = (x / width) * mediaSingle.cur.length
                          }
                          Rectangle {
                            id: progBox
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            width: progressBar.hovered ? parent.width : 200
                            height: progressBar.hovered ? 14 : 8
                            color: progressBar.hovered ? Theme.bgAlt : Theme.border
                            border.color: Theme.border
                            border.width: progressBar.hovered ? 1 : 0
                            clip: true
                            property real fillW: width * Math.max(0, Math.min(1, mediaSingle.cur ? mediaSingle.cur.position / Math.max(1, mediaSingle.cur.length) : 0))
                            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Rectangle {
                              z: 0
                              anchors.left: parent.left
                              anchors.verticalCenter: parent.verticalCenter
                              height: progressBar.hovered ? 8 : 6
                              width: parent.width * Math.max(0, Math.min(1, (mediaSingle.cur ? mediaSingle.cur.position / Math.max(1, mediaSingle.cur.length) : 0)))
                              color: Theme.fg
                            }
                          }
                          Text {
                            z: 1
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: progressBar.fmtTime(mediaSingle.cur ? mediaSingle.cur.position : 0)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            visible: progressBar.hovered
                          }
                          Item {
                            z: 2
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: progBox.fillW
                            clip: true
                            visible: progressBar.hovered
                            Text {
                              anchors.left: parent.left
                              anchors.leftMargin: 6
                              anchors.verticalCenter: parent.verticalCenter
                              text: progressBar.fmtTime(mediaSingle.cur ? mediaSingle.cur.position : 0)
                              color: Theme.bg
                              font.family: Theme.fontFamily
                              font.pixelSize: 9
                            }
                          }
                          Text {
                            z: 1
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: progressBar.fmtTime(mediaSingle.cur ? mediaSingle.cur.length : 0)
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            visible: progressBar.hovered
                          }
                          Item {
                            z: 2
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: progBox.fillW
                            clip: true
                            visible: progressBar.hovered
                            Text {
                              x: progBox.width - 6 - width
                              anchors.verticalCenter: parent.verticalCenter
                              text: progressBar.fmtTime(mediaSingle.cur ? mediaSingle.cur.length : 0)
                              color: Theme.bg
                              font.family: Theme.fontFamily
                              font.pixelSize: 9
                            }
                          }
                          MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: progressBar.hovered = true
                            onExited: progressBar.hovered = false
                            onPressed: mouse => { progressBar.scrubbing = true; progressBar.seek(mouse.x) }
                            onReleased: progressBar.scrubbing = false
                            onPositionChanged: mouse => { if (progressBar.scrubbing) progressBar.seek(mouse.x) }
                          }
                        }
                      }

                        Item {
                          id: msRight
                          visible: true
                          Layout.fillHeight: true
                          Layout.preferredWidth: msRight.height
                          Layout.fillWidth: false
                          clip: true
                        Image {
                          id: artImg
                          anchors.fill: parent
                          source: mediaSingle.displayArt
                          onStatusChanged: {
                            if (status !== Image.Error) return
                            if (mediaSingle.displayArt === mediaSingle.webArt && mediaSingle.webArt !== "") {
                              mediaSingle.webFailedKey = mediaSingle.webKey
                            } else if (!mediaSingle.artFallback && mediaSingle.hiResArt !== "" && mediaSingle.hiResArt !== mediaSingle.rawArt) {
                              mediaSingle.artFallback = true
                            }
                          }
                          fillMode: Image.PreserveAspectCrop
                          asynchronous: true
                          cache: false
                          smooth: true
                          mipmap: true
                          autoTransform: true
                          retainWhileLoading: true
                          sourceSize: {
                            const dpr = Screen.devicePixelRatio ?? 1
                            return Qt.size(Math.max(1, Math.ceil(width * dpr)), Math.max(1, Math.ceil(height * dpr)))
                          }
                          visible: mediaSingle.displayArt !== "" && artImg.status !== Image.Error
                        }
                        Rectangle {
                          anchors.fill: parent
                          color: Theme.bgAlt
                          visible: !artImg.visible
                          QIcon {
                            anchors.centerIn: parent
                            name: "music"
                            size: 48
                            color: Theme.muted2
                          }
                        }
                        Item {
                          id: tabContainer
                          anchors.bottom: parent.bottom
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.bottomMargin: 6
                          width: tabRow.implicitWidth + 12
                          height: (tabHover.containsMouse) ? 16 : 10
                          visible: Mpris.players.values && Mpris.players.values.length > 1
                          Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                          Rectangle {
                            anchors.fill: parent
                            color: (tabHover.containsMouse) ? Theme.bgAlt : "transparent"
                            border.color: Theme.border
                            border.width: (tabHover.containsMouse) ? 1 : 0
                            radius: 0
                          }
                          RowLayout {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: (tabHover.containsMouse) ? 2 : 4
                            Repeater {
                              model: Mpris.players.values ? Mpris.players.values.length : 0
                              delegate: Rectangle {
                                required property int index
                                implicitWidth: (tabHover.containsMouse) ? (index === root.mediaIdx ? 18 : 10) : 6
                                implicitHeight: (tabHover.containsMouse) ? 8 : 6
                                radius: 0
                                color: index === root.mediaIdx ? Theme.fg : Theme.muted2
                                Behavior on implicitWidth { NumberAnimation { duration: 120 } }
                                Behavior on implicitHeight { NumberAnimation { duration: 120 } }
                                MouseArea {
                                  anchors.fill: parent
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: root.mediaIdx = index
                                }
                              }
                            }
                          }
                          MouseArea {
                            id: tabHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                          }
                        }
                      }
                    }
                  }
              }

            }
          }

        }
      }
    }
  }
}
