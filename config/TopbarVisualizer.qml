import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Util.js" as Util

Item {
  id: root
  readonly property int barHeight: 14
  readonly property int squareSize: {
    const maxSize = Math.max(16, Math.min(30, root.parent ? root.parent.height - 4 : 26))
    return Math.max(16, Math.min(maxSize, Math.round(VisualizerState.bars / 2)))
  }
  Layout.preferredWidth: VisualizerState.mode === "bars" ? VisualizerState.bars * (VisualizerState.thickness + 1) - 1 : squareSize
  Layout.preferredHeight: VisualizerState.mode === "bars" ? barHeight : squareSize
  Layout.alignment: Qt.AlignVCenter

  property var levels: []
  property var waveLevels: []
  readonly property int topBars: VisualizerState.bars
  readonly property int idleMs: 20000

  property bool hasAudio: false
  property double lastActive: 0

  function noteSignal() {
    root.lastActive = Date.now()
    if (!root.hasAudio)
      root.hasAudio = true
  }

  Timer {
    id: idleCheck
    interval: 5000
    repeat: true
    running: root.hasAudio
    onTriggered: {
      if (Date.now() - root.lastActive > root.idleMs)
        root.hasAudio = false
    }
  }

  Connections {
    target: Mpris.players
    function onValuesChanged() {
      const pls = Mpris.players.values || []
      for (let i = 0; i < pls.length; i++) {
        if (pls[i] && pls[i].isPlaying) {
          root.noteSignal()
          return
        }
      }
    }
  }

  Process {
    id: visProc
    running: VisualizerState.topbar && !IdleManager.gaming
    command: ["sh", "-c", VisualizerState.command(VisualizerState.mode, root.topBars)]
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
        if (arr.length > 0) {
          root.levels = arr
          root.waveLevels = VisualizerState.stabilize(root.waveLevels, arr)
          if (peak > 4) root.noteSignal()
        }
      }
    }
  }

  Connections {
    target: VisualizerState
    function onModeChanged() {
      root.waveLevels = []
      if (visProc.running) {
        visProc.running = false
        visProc.running = true
      }
    }
    function onBackendChanged() {
      root.waveLevels = []
      if (visProc.running) {
        visProc.running = false
        visProc.running = true
      }
    }
    function onBarsChanged() {
      root.waveLevels = []
      if (visProc.running) {
        visProc.running = false
        visProc.running = true
      }
    }
    function onFpsChanged() {
      root.waveLevels = []
      if (visProc.running) {
        visProc.running = false
        visProc.running = true
      }
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
    property var pts: VisualizerState.mode === "oscilloscope" ? root.levels : root.waveLevels
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
        for (let i = 0; i < n; i++) {
          const x = Math.round((i / (n - 1)) * (width - 1))
          const y = Math.round(height - (Util.clampPct(pts[i] || 0) / 100) * (height - 1))
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
