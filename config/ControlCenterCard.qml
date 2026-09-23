import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: ccCard

  property var targetScreen: null

  anchors.top: true
  anchors.right: true
  margins.top: 30
  margins.right: 8
  implicitWidth: 356
  property int maxCardHeight: Math.max(320, Math.min(640, (ccCard.targetScreen?.height ?? 900) - 80))
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-modal"
  BackgroundEffect.blurRegion: Region { item: card.slideProg >= 1 ? card : null }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  readonly property bool shown: card.slideProg > 0
  screen: ccCard.targetScreen
  visible: ccCard.shown && (!ControlState.screen || ControlState.screen === ccCard.targetScreen)
  implicitHeight: Math.min(card.contentHeight + 32, maxCardHeight)
  Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  QsCard {
    id: card
    width: parent.width
    height: parent.height
    active: ccCard.shown
    swallowClicks: true
    open: ControlState.open && (!ControlState.screen || ControlState.screen === ccCard.targetScreen)
  }
}
