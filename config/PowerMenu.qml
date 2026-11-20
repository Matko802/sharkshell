import QtQuick
import Quickshell
import Quickshell.Io
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
    visible: (PowerState.open || PowerState.closePending) && !LockState.locked

    onVisibleChanged: {
      if (visible && PowerState.open)
        panel.forceActiveFocus()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: PowerState.requestClose()
    }

    Item {
      id: panel
      anchors.centerIn: parent
      width: tiles.width
      height: tiles.height
      opacity: PowerState.open ? 1 : 0
      scale: PowerState.open ? 1 : 0.94
      focus: true
      Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

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
