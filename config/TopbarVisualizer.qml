import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Util.js" as Util

Item {
  id: root
  readonly property int squareSize: 14
  readonly property int barWidth: VisualizerState.bars * (VisualizerState.thickness + 1) - 1
  Layout.preferredWidth: VisualizerState.mode === "oscilloscope" ? squareSize : barWidth
  Layout.preferredHeight: squareSize
  Layout.alignment: Qt.AlignVCenter

  property var levels: []
  property var waveLevels: []
  property var waveHistory: []
  readonly property int historyCap: 1024
  readonly property int topBars: VisualizerState.bars
  readonly property int idleMs: 20000
  readonly property int silenceMs: 700
  readonly property bool visWanted: VisualizerState.topbar && !IdleManager.gaming

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

  function restartVis() {
    root.clearVisual()
    root.lastFrame = 0
    root.lastRestart = Date.now()
    visProc.running = false
    restartTimer.restart()
  }

  onVisWantedChanged: {
    if (!root.visWanted) {
      root.clearVisual()
      root.hasAudio = false
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

  Process {
    id: visProc
    command: ["sh", "-c", VisualizerState.command(VisualizerState.mode, root.topBars)]
    onStarted: root.lastFrame = Date.now()
    onExited: root.clearVisual()
    stdout: SplitParser {
      onRead: data => {
        const parts = String(data).split(";")
        const arr = []
        let peak = 0
        for (let i = 0; i < parts.length; i++) {
          const v = parseInt(parts[i], 10)
          if (!isNaN(v)) {
            const c = Util.clampPct(v)
            arr.push(c)
            if (c > peak) peak = c
          }
        }
        if (arr.length === 0) return
        root.lastFrame = Date.now()
        if (peak <= 0) {
          if (root.lastSound > 0 && Date.now() - root.lastSound > root.silenceMs) {
            root.lastSound = 0
            root.clearVisual()
          }
          return
        }
        root.lastSound = Date.now()
        root.levels = arr
        root.waveLevels = VisualizerState.stabilize(root.waveLevels, arr)
        root.waveHistory = root.waveHistory.concat(root.waveLevels).slice(-root.historyCap)
        root.noteSignal()
      }
    }
  }

  Connections {
    target: VisualizerState
    function onModeChanged() {
      root.restartVis()
    }
    function onBackendChanged() {
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
    onPaint: {
      const ctx = getContext("2d")
      const n = pts ? pts.length : 0
      if (width <= 0 || height <= 0) return
      ctx.clearRect(0, 0, width, height)
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.strokeStyle = Theme.fg
      ctx.lineWidth = Math.max(1, VisualizerState.thickness)
      ctx.beginPath()
      if (VisualizerState.mode === "oscilloscope") {
        if (n < 4) return
        const m = Math.floor(n / 2)
        for (let i = 0; i < m; i++) {
          const x = Math.round((Util.clampPct(pts[2 * i] || 0) / 100) * (width - 1))
          const y = Math.round(height - (Util.clampPct(pts[2 * i + 1] || 0) / 100) * (height - 1))
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
      } else {
        if (n < 2) return
        const count = Math.max(2, Math.min(n, Math.floor(width)))
        const start = n - count
        for (let i = 0; i < count; i++) {
          const x = Math.round((i / (count - 1)) * (width - 1))
          const y = Math.round(height - (Util.clampPct(pts[start + i] || 0) / 100) * (height - 1))
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
      }
      ctx.stroke()
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: ClockState.toggle(root.QsWindow.window)
    onWheel: VisualizerState.cycleMode()
  }
}
