import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Util.js" as Util

Item {
  id: root
  readonly property int visHeight: Theme.barHeight
  readonly property int squareSize: visHeight
  readonly property int waveWidth: VisualizerState.visWidth
  readonly property int barWidth: VisualizerState.bars * (VisualizerState.thickness + 1) - 1
  Layout.preferredWidth: VisualizerState.mode === "bars" ? barWidth : (VisualizerState.mode === "oscilloscope" ? squareSize : waveWidth)
  Layout.preferredHeight: visHeight
  Layout.alignment: Qt.AlignVCenter

  property var levels: []
  property var waveLevels: []
  property var waveHistory: []
  readonly property int historyCap: 2048
  readonly property int topBars: VisualizerState.bars
  readonly property int idleMs: 20000
  readonly property int silenceMs: 700
  readonly property int hideMs: 400
  readonly property bool visWanted: VisualizerState.topbar && VisualizerState.visualizerAvailable && !IdleManager.gaming

  property bool hasAudio: false
  property double lastActive: 0
  property double lastSound: 0
  property double lastFrame: 0
  property double lastRestart: 0

  function noteSignal() {
    root.lastActive = Date.now()
    if (!root.hasAudio)
      root.hasAudio = true
  }

  function clearVisual() {
    root.levels = []
    root.waveLevels = []
    root.waveHistory = []
  }

  function frameSilent(arr) {
    for (let i = 0; i < arr.length; i++) {
      const v = arr[i]
      if (VisualizerState.mode === "bars") {
        if (v > 0) return false
      } else if (VisualizerState.mode === "oscilloscope") {
        if (i % 2 === 1 && Math.abs(v - 50) > 0.5) return false
      } else if (v > 0.5 && Math.abs(v - 50) > 0.5) {
        return false
      }
    }
    return true
  }

  function visibleFlat() {
    const pts = VisualizerState.mode === "oscilloscope" ? root.levels : root.waveHistory
    const n = pts ? pts.length : 0
    if (n < 2) return true
    if (VisualizerState.mode === "oscilloscope") {
      for (let i = 1; i < n; i += 2)
        if (Math.abs(Util.clampPct(pts[i] || 0) - 50) > 0.5) return false
      return true
    }
    const count = Math.max(2, Math.min(n, Math.floor(root.width)))
    const start = n - count
    for (let i = start; i < n; i++) {
      const v = Util.clampPct(pts[i] || 0)
      if (VisualizerState.mode === "bars") {
        if (v > 0.5) return false
      } else if (v > 0.5 && Math.abs(v - 50) > 0.5) {
        return false
      }
    }
    return true
  }

  function restartVis() {
    hideTimer.stop()
    root.clearVisual()
    root.lastSound = 0
    root.lastFrame = 0
    root.lastRestart = Date.now()
    visProc.running = false
    restartTimer.restart()
  }

  onVisWantedChanged: {
    if (!root.visWanted) {
      hideTimer.stop()
      root.clearVisual()
      root.hasAudio = false
      root.lastSound = 0
      visProc.running = false
    }
  }

  Timer {
    id: idleCheck
    interval: 1000
    repeat: true
    running: root.visWanted
    onTriggered: {
      if (root.hasAudio && Date.now() - root.lastActive > root.idleMs) {
        hideTimer.stop()
        root.hasAudio = false
        root.clearVisual()
      }
    }
  }

  Timer {
    id: procWatch
    interval: 1000
    repeat: true
    running: root.visWanted
    triggeredOnStart: true
    onTriggered: {
      if (!root.visWanted) return
      const now = Date.now()
      if (!visProc.running) {
        if (now - root.lastRestart < 1000) return
        root.lastRestart = now
        visProc.running = true
        return
      }
      if (root.lastFrame > 0 && now - root.lastFrame > 5000 && now - root.lastRestart > 5000)
        root.restartVis()
    }
  }

  Timer {
    id: restartTimer
    interval: 200
    repeat: false
    onTriggered: if (root.visWanted) visProc.running = true
  }

  Timer {
    id: hideTimer
    interval: root.hideMs
    repeat: false
    onTriggered: {
      root.lastSound = 0
      root.hasAudio = false
      root.clearVisual()
    }
  }

  Process {
    id: visProc
    command: ["sh", "-c", VisualizerState.command(VisualizerState.mode, root.topBars)]
    onStarted: root.lastFrame = Date.now()
    onExited: {
      hideTimer.stop()
      root.clearVisual()
    }
    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).split(";")
        const arr = []
        for (let i = 0; i < parts.length; i++) {
          const v = parseInt(parts[i], 10)
          if (!isNaN(v)) arr.push(Util.clampPct(v))
        }
        if (arr.length === 0) return
        root.lastFrame = Date.now()
        const silent = root.frameSilent(arr)
        root.levels = arr
        root.waveLevels = VisualizerState.stabilize(root.waveLevels, arr)
        root.waveHistory = root.waveHistory.concat(root.waveLevels).slice(-root.historyCap)
        if (silent) {
          if (root.lastSound > 0 && Date.now() - root.lastSound > root.silenceMs) {
            if (root.visibleFlat()) {
              if (!hideTimer.running) hideTimer.restart()
            } else {
              hideTimer.stop()
            }
          }
          return
        }
        hideTimer.stop()
        root.lastSound = Date.now()
        root.noteSignal()
      }
    }
  }

  Connections {
    target: VisualizerState
    function onModeChanged() {
      root.restartVis()
    }
    function onBarsChanged() {
      root.restartVis()
    }
    function onFpsChanged() {
      root.restartVis()
    }
  }

  Row {
    id: barRow
    anchors.fill: parent
    spacing: 1
    visible: VisualizerState.mode === "bars"
    Repeater {
      model: root.topBars
      delegate: Item {
        required property int index
        width: Math.max(1, Math.min(VisualizerState.thickness, Math.round((barRow.width - (root.topBars - 1) * barRow.spacing) / root.topBars)))
        height: barRow.height
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Math.min(parent.height, Math.max(2, Math.round(parent.height * ((root.levels[index] || 0) / 100))))
          color: Theme.fg
          Behavior on height {
            NumberAnimation {
              duration: 90
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }

  Canvas {
    id: waveCanvas
    anchors.fill: parent
    visible: VisualizerState.mode !== "bars"
    property var pts: VisualizerState.mode === "oscilloscope" ? root.levels : root.waveHistory
    onPtsChanged: if (visible) requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onWidthChanged: if (visible) requestPaint()
    onHeightChanged: if (visible) requestPaint()
    Connections {
      target: VisualizerState
      function onModeChanged() {
        if (waveCanvas.visible) waveCanvas.requestPaint()
      }
    }
    function strokePath(ctx, w, a) {
      ctx.strokeStyle = Theme.fg
      ctx.lineWidth = w
      ctx.globalAlpha = a
      ctx.beginPath()
      const n = pts ? pts.length : 0
      const count = Math.max(2, Math.min(n, Math.floor(width)))
      const start = n - count
      for (var i = 0; i < count; i++) {
        var v = Util.clampPct(pts[start + i] || 0)
        var x = (i / (count - 1)) * width
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
        scopePath(ctx, VisualizerState.thickness, 1)
      } else {
        if (n < 2) return
        ctx.clearRect(0, 0, width, height)
        strokePath(ctx, VisualizerState.thickness, 1)
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: SettingsState.openTab(3, root.QsWindow.window)
    onWheel: VisualizerState.cycleMode()
  }
}
