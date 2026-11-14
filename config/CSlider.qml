import QtQuick

Rectangle {
  id: root

  property real value: 0
  signal userSet(real v)

  implicitWidth: 120
  implicitHeight: 20
  color: "transparent"

  readonly property real clamped: Math.max(0, Math.min(1, value))
  readonly property real pad: 8
  property bool dragging: false
  property real dragValue: 0
  readonly property real shown: dragging ? Math.max(0, Math.min(1, dragValue)) : clamped

  Rectangle {
    id: track

    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 4
    radius: Theme.radiusFull
    color: Theme.surfaceHighest

    readonly property real center: 8 + (width - 16) * root.shown

    Rectangle {
      width: Math.min(parent.width, parent.center)
      height: parent.height
      radius: parent.radius
      color: Theme.primary
    }
  }

  Rectangle {
    x: track.center - width / 2
    anchors.verticalCenter: parent.verticalCenter
    width: 16
    height: 16
    radius: Theme.radiusFull
    color: Theme.primary
  }

  Rectangle {
    x: track.center - width / 2
    anchors.verticalCenter: parent.verticalCenter
    width: 32
    height: 32
    radius: Theme.radiusFull
    color: Theme.primary
    opacity: root.dragging ? 0.12 : ma.containsMouse ? 0.08 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Theme.easingOut
      }
    }
  }

  MouseArea {
    id: ma

    anchors.fill: parent
    anchors.margins: -root.pad
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    hoverEnabled: true

    function apply(mouse) {
      const v = Math.max(0, Math.min(1, (mouse.x - root.pad) / root.width))
      root.dragValue = v
      root.userSet(v)
    }

    onPressed: mouse => {
      root.dragging = true
      ControlState.sliderDrags++
      apply(mouse)
    }
    onPositionChanged: mouse => {
      if (pressed)
        apply(mouse)
    }
    onReleased: {
      root.dragging = false
      if (ControlState.sliderDrags > 0)
        ControlState.sliderDrags--
    }
    onCanceled: {
      root.dragging = false
      if (ControlState.sliderDrags > 0)
        ControlState.sliderDrags--
    }
    onWheel: wheel => root.userSet(root.shown + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
  }
}
