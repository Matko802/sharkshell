import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: ccCard

  property var targetScreen
  readonly property int cardWidth: 356
  readonly property bool shown: card.slideProg > 0
  property int maxCardHeight: Math.max(320, Math.min(640, (ccCard.targetScreen?.height ?? 900) - 80))
  readonly property int cardHeight: Math.min(card.contentHeight + 32, maxCardHeight)

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-modal"
  BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent && card.slideProg > 0 ? card : null }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  screen: ccCard.targetScreen
  visible: ccCard.shown && (!ControlState.screen || ControlState.screen === ccCard.targetScreen)

  MouseArea {
    anchors.fill: parent
    onClicked: ControlState.close()
  }

  Item {
    id: cardHolder
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 30
    anchors.rightMargin: 8
    width: ccCard.cardWidth
    height: ccCard.cardHeight

    QsCard {
      id: card
      width: parent.width
      height: parent.height
      active: ccCard.shown
      swallowClicks: true
      open: ControlState.open && (!ControlState.screen || ControlState.screen === ccCard.targetScreen)
    }
  }
}
