import QtQuick
import Quickshell
import Quickshell.Wayland
import "Util.js" as Util

PanelWindow {
  id: window

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: Theme.bg
  WlrLayershell.namespace: "quickshell-wallpaper"
  WlrLayershell.layer: WlrLayer.Background

  Item {
    id: bg

    anchors.fill: parent
    clip: true

    property bool frontIsA: true
    property var pending: null
    property int retryCount: 0
    readonly property int maxRetries: 4

    function checkReady(img) {
      if (bg.pending !== img || img.status !== Image.Ready)
        return
      bg.pending = null
      bg.retryCount = 0
      bg.frontIsA = img === imgA
      imgA.opacity = img === imgA ? 1 : 0
      imgB.opacity = img === imgB ? 1 : 0
    }

    function checkError(img) {
      if (bg.pending !== img)
        return
      bg.pending = null
      if (bg.retryCount >= bg.maxRetries)
        return
      bg.retryCount += 1
      retryTimer.img = img
      retryTimer.url = String(img.source)
      retryTimer.interval = Math.min(15000, 1500 * Math.pow(2, bg.retryCount - 1))
      retryTimer.restart()
    }

    function onImageStatus(img) {
      if (img.status === Image.Ready) {
        bg.layoutImage(img)
        bg.checkReady(img)
      } else if (img.status === Image.Error) {
        bg.checkError(img)
      }
    }

    function layoutImage(img) {
      if (bg.width <= 0 || bg.height <= 0)
        return
      if (!img || img.status !== Image.Ready) {
        if (img) {
          img.x = 0
          img.y = 0
          img.width = bg.width
          img.height = bg.height
        }
        return
      }
      var iw = img.implicitWidth
      var ih = img.implicitHeight
      if (iw <= 0 || ih <= 0)
        return
      var scale = Math.max(bg.width / iw, bg.height / ih)
      var dw = iw * scale
      var dh = ih * scale
      var px = Util.clamp01(WallpaperState.positionX)
      var py = Util.clamp01(WallpaperState.positionY)
      img.width = dw
      img.height = dh
      img.x = (bg.width - dw) * px
      img.y = (bg.height - dh) * py
    }

    function layoutAll() {
      bg.layoutImage(imgA)
      bg.layoutImage(imgB)
    }

    onWidthChanged: bg.layoutAll()
    onHeightChanged: bg.layoutAll()

    Timer {
      id: retryTimer

      interval: 1500
      property var img: null
      property string url: ""

      onTriggered: {
        if (bg.pending !== null)
          return
        const target = retryTimer.img
        if (!target || String(target.source) !== retryTimer.url)
          return
        target.source = ""
        target.source = retryTimer.url
        bg.pending = target
        bg.checkReady(target)
      }
    }

    function show(path) {
      if (path === "")
        return
      const back = bg.frontIsA ? imgB : imgA
      const front = bg.frontIsA ? imgA : imgB
      if (front.source === Util.fileUrl(path))
        return
      back.source = Util.fileUrl(path)
      bg.pending = back
      bg.checkReady(back)
    }

    Connections {
      target: WallpaperState
      function onPathChanged() {
        bg.show(WallpaperState.path)
      }
      function onPositionXChanged() {
        bg.layoutAll()
      }
      function onPositionYChanged() {
        bg.layoutAll()
      }
    }

    Component.onCompleted: {
      bg.show(WallpaperState.path)
      bg.layoutAll()
    }

    Image {
      id: imgA
      fillMode: Image.Stretch
      asynchronous: true
      cache: false
      sourceSize: Qt.size(3840, 2160)
      opacity: 0
      Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
      onStatusChanged: bg.onImageStatus(imgA)
      onImplicitWidthChanged: bg.layoutImage(imgA)
      onImplicitHeightChanged: bg.layoutImage(imgA)
    }

    Image {
      id: imgB
      fillMode: Image.Stretch
      asynchronous: true
      cache: false
      sourceSize: Qt.size(3840, 2160)
      opacity: 0
      Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
      onStatusChanged: bg.onImageStatus(imgB)
      onImplicitWidthChanged: bg.layoutImage(imgB)
      onImplicitHeightChanged: bg.layoutImage(imgB)
    }
  }
}
