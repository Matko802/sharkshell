import QtQuick
import Quickshell

Rectangle {
  id: root

  property bool active: true
  property bool swallowClicks: false
  property bool open: false
  readonly property real contentHeight: qs.implicitHeight
  readonly property bool sliding: slideIn.running || slideOut.running

  signal activity()

  color: Theme.bg
  border.color: Theme.outline
  border.width: 1

  transform: Translate { id: slide }

  NumberAnimation { id: slideIn; target: slide; property: "y"; to: 0; duration: 250; easing.type: Easing.OutCubic }
  NumberAnimation { id: slideOut; target: slide; property: "y"; to: -root.height - 8; duration: 250; easing.type: Easing.InCubic }

  onOpenChanged: {
    if (root.open) {
      slide.y = -root.height - 8
      slideIn.restart()
    } else {
      slideOut.restart()
    }
  }

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
