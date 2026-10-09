import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Util.js" as Util

Item {
  id: root
  Layout.preferredWidth: 46
  Layout.preferredHeight: 18
  Layout.alignment: Qt.AlignVCenter

  property var levels: []
  readonly property int topBars: 16
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
    interval: 1000
    repeat: true
    running: VisualizerState.topbar && !IdleManager.gaming
    triggeredOnStart: true
    onTriggered: {
      var sig = false
      var pls = Mpris.players.values || []
      for (var i = 0; i < pls.length; i++) {
        if (pls[i] && pls[i].isPlaying) {
          sig = true
          break
        }
      }
      if (sig) {
        root.noteSignal()
      } else if (root.hasAudio && Date.now() - root.lastActive > root.idleMs) {
        root.hasAudio = false
      }
    }
  }

  Process {
    id: visProc
    running: VisualizerState.topbar && !IdleManager.gaming
    command: ["sh", "-c", "V=\"$HOME/.cache/sharkshell/cava.conf\"; L=/mnt/ssd/My-Files/Projects/sharkvis/target/release/sharkvis; M=" + VisualizerState.mode + "; B=" + root.topBars + "; if [ -x \"$L\" ]; then exec \"$L\" --raw --raw-mode \"$M\" --bars \"$B\" --fps 30; elif command -v sharkvis >/dev/null 2>&1; then exec sharkvis --raw --raw-mode \"$M\" --bars \"$B\" --fps 30; elif command -v cava >/dev/null 2>&1; then exec cava -p \"$V\"; else exit 0; fi"]
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
          if (peak > 4) root.noteSignal()
        }
      }
    }
  }

  Connections {
    target: VisualizerState
    function onModeChanged() {
      if (visProc.running) {
        visProc.running = false
        visProc.running = true
      }
    }
  }

  Row {
    id: barRow
    anchors.fill: parent
    spacing: 2
    visible: VisualizerState.mode === "bars"
    Repeater {
      model: root.topBars
      delegate: Item {
        required property int index
        width: Math.max(1, (barRow.width - (root.topBars - 1) * barRow.spacing) / root.topBars)
        height: barRow.height
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Math.max(2, parent.height * ((root.levels[index] || 0) / 100))
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
    property var pts: root.levels
    onPtsChanged: requestPaint()
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
      ctx.lineWidth = 1.5
      ctx.beginPath()
      if (VisualizerState.mode === "oscilloscope") {
        if (n < 4) return
        const m = Math.floor(n / 2)
        for (let i = 0; i < m; i++) {
          const x = Util.clampPct(pts[2 * i] || 0) / 100 * width
          const y = height - Util.clampPct(pts[2 * i + 1] || 0) / 100 * height
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
      } else {
        if (n < 2) return
        for (let i = 0; i < n; i++) {
          const x = (i / (n - 1)) * width
          const y = height - Util.clampPct(pts[i] || 0) / 100 * height
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
