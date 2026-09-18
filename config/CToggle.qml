import QtQuick

Rectangle {
  id: root

  property bool checked: false
  signal toggled(bool checked)

  implicitWidth: 32
  implicitHeight: 16
  color: checked ? Theme.fg : Theme.bg
  border.color: Theme.fg
  border.width: 1

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  Rectangle {
    x: root.checked ? parent.width - width - 2 : 2
    anchors.verticalCenter: parent.verticalCenter
    width: 12
    height: 12
    color: root.checked ? Theme.bg : Theme.fg

    Behavior on x {
      NumberAnimation {
        duration: 120
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
