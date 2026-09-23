import QtQuick
import Quickshell

Rectangle {
  id: root

  property bool active: true
  property bool swallowClicks: false
  property bool open: false
  readonly property real contentHeight: qs.implicitHeight
  property real slideProg: root.open ? 1 : 0
  Behavior on slideProg { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

  signal activity()

  color: Theme.bg
  border.color: Theme.outline
  border.width: 1

  transform: Translate { y: -(1 - root.slideProg) * (root.height + 8) }

  MouseArea {
    anchors.fill: parent
    enabled: root.swallowClicks
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 14
    contentWidth: flick.width
    contentHeight: qs.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    QuickSettings {
      id: qs
      width: flick.width
      active: root.active
      onActivity: root.activity()
    }
  }
}
