import QtQuick

MouseArea {
  id: root

  property bool disabled: false
  property color color: Theme.onSurface
  property real hoverOpacity: 0.08
  property real pressOpacity: 0.12
  property real radius: 0

  anchors.fill: parent
  enabled: !root.disabled
  hoverEnabled: !root.disabled
  cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.color
    opacity: root.pressed ? root.pressOpacity : root.containsMouse ? root.hoverOpacity : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Theme.easingOut
      }
    }
  }
}
