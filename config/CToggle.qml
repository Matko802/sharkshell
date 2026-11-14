import QtQuick

Rectangle {
  id: root

  property bool checked: false
  signal toggled(bool checked)

  implicitWidth: 40
  implicitHeight: 22

  radius: Theme.radiusFull
  color: root.checked ? Theme.primary : Theme.surfaceHighest
  border.color: root.checked ? "transparent" : Theme.outlineVariant
  border.width: 1

  Behavior on color {
    ColorAnimation {
      duration: Theme.animDefault
      easing.type: Theme.easingOut
    }
  }

  Rectangle {
    id: thumb

    width: 16
    height: 16
    radius: Theme.radiusFull
    anchors.verticalCenter: parent.verticalCenter
    x: root.checked ? parent.width - width - 3 : 3
    color: root.checked ? Theme.onPrimary : Theme.outline

    Behavior on x {
      NumberAnimation {
        duration: Theme.animDefault
        easing.type: Theme.easingOut
      }
    }

    Behavior on color {
      ColorAnimation {
        duration: Theme.animDefault
        easing.type: Theme.easingOut
      }
    }
  }

  MouseArea {
    id: ma

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Theme.onSurface
    opacity: ma.pressed ? 0.12 : ma.containsMouse ? 0.08 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Theme.easingOut
      }
    }
  }
}
