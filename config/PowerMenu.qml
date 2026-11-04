import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
  id: root

  IpcHandler {
    target: "power"
    function toggle() {
      PowerState.toggle()
    }
    function close() {
      PowerState.forceClose()
    }
  }

  PanelWindow {
    id: menuWindow
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent ? panel : null }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: Region { item: panel }
    visible: (PowerState.open || PowerState.closePending) && !LockState.locked

    Rectangle {
      id: panel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: PowerState.open ? 30 : -(panel.height + 250)
      width: tiles.width + 32
      height: tiles.height + 32
      color: Theme.bg
      opacity: PowerState.open ? 1 : 0
      Behavior on anchors.topMargin { NumberAnimation { duration: 170; easing.type: Easing.OutExpo } }
      Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          PowerState.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          tiles.activate(tiles.selIdx)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
          tiles.move(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
          tiles.move(1)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N) {
          tiles.move(1)
          event.accepted = true
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_P) {
          tiles.move(-1)
          event.accepted = true
        }
      }

      MouseArea { anchors.fill: parent }

      PowerMenuTiles {
        id: tiles
        anchors.centerIn: parent
        open: PowerState.open
      }
    }
  }
}
