import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  property real value: 0
  property string text: ""

  signal userSet(real v)
  signal reset()

  Layout.fillWidth: true
  Layout.preferredHeight: 32
  color: "transparent"
  border.color: Theme.border
  border.width: 1

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 10

    Item {
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      QIcon {
        anchors.centerIn: parent
        name: root.icon
        size: 18
        color: Theme.fg
      }
    }

    Text {
      text: root.label
      color: Theme.fg
      font.family: Theme.fontFamily
      font.pixelSize: 12
      font.weight: Font.DemiBold
    }

    CSlider {
      Layout.fillWidth: true
      value: root.value
      onUserSet: v => root.userSet(v)
    }

    Text {
      text: root.text
      color: Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: 11
      Layout.preferredWidth: 40
      horizontalAlignment: Text.AlignRight
    }

    Text {
      text: "reset"
      color: resetMa.containsMouse ? Theme.fg : Theme.muted
      font.family: Theme.fontFamily
      font.pixelSize: 10
      MouseArea {
        id: resetMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.reset()
      }
    }
  }
}
