import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: osd

  property bool armed: false

  anchors.bottom: true
  margins.bottom: 0
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-modal"
  BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent && bar.shown ? bar : null }
  WlrLayershell.layer: WlrLayer.Overlay
  implicitWidth: 380
  implicitHeight: 200
  visible: bar.shown || bar.anchors.bottomMargin > -(bar.height + 20)
  mask: Region { item: bar }

  Timer {
    id: armTimer
    interval: 1500
    running: true
    onTriggered: osd.armed = true
  }

  Connections {
    target: Audio
    function onVolChanged() {
      if (!osd.armed || ControlState.open || LockState.locked)
        return
      bar.show()
      if (ControlState.sliderDrags === 0)
        Audio.playVolumeSound()
    }
    function onMutedChanged() {
      if (!osd.armed || ControlState.open || LockState.locked)
        return
      bar.show()
      if (ControlState.sliderDrags === 0)
        Audio.playVolumeSound()
    }
  }

  VolumeCard {
    id: bar
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
  }
}
