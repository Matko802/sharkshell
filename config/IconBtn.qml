import QtQuick

Rectangle {
  id: root

  property string icon: ""
  property int iconSize: 16
  property bool bordered: false

  signal clicked()

  color: ma.containsMouse || ma.pressed ? Theme.fg : "transparent"
  border.color: Theme.outline
  border.width: bordered ? 1 : 0

  QIcon {
    anchors.centerIn: parent
    name: root.icon
    size: root.iconSize
    color: ma.containsMouse || ma.pressed ? Theme.bg : Theme.fg
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
