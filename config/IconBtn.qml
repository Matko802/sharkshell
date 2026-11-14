import QtQuick

Rectangle {
  id: root

  property string icon: ""
  property int iconSize: 16
  property bool bordered: false

  signal clicked()

  radius: root.bordered ? Theme.radiusS : Theme.radiusFull
  color: "transparent"
  border.color: root.bordered ? Theme.outlineVariant : "transparent"
  border.width: root.bordered ? 1 : 0

  QIcon {
    anchors.centerIn: parent
    name: root.icon
    size: root.iconSize
    color: Theme.onSurfaceVariant
  }

  StateLayer {
    radius: root.radius
    color: Theme.onSurface
    onClicked: root.clicked()
  }
}
