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
  Layout.preferredHeight: 36
  radius: Theme.radiusM
  color: hover.hovered ? Theme.surfaceHigh : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: Theme.animFast
      easing.type: Theme.easingOut
    }
  }

  HoverHandler {
    id: hover
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 8
    spacing: 10

    Item {
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      QIcon {
        anchors.centerIn: parent
        name: root.icon
        size: 18
        color: Theme.onSurfaceVariant
      }
    }

    Text {
      text: root.label
      color: Theme.onSurface
      font.family: Theme.fontFamily
      font.pixelSize: 12
      font.weight: Font.Medium
    }

    CSlider {
      Layout.fillWidth: true
      value: root.value
      onUserSet: v => root.userSet(v)
    }

    Text {
      text: root.text
      color: Theme.onSurfaceVariant
      font.family: Theme.fontFamily
      font.pixelSize: 11
      Layout.preferredWidth: 40
      horizontalAlignment: Text.AlignRight
    }

    Rectangle {
      Layout.preferredWidth: 52
      Layout.preferredHeight: 24
      radius: Theme.radiusFull
      color: resetMa.pressed ? Theme.primaryContainer : resetMa.containsMouse ? Theme.surfaceHighest : "transparent"

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
          easing.type: Theme.easingOut
        }
      }

      Text {
        anchors.centerIn: parent
        text: "reset"
        color: resetMa.containsMouse ? Theme.primary : Theme.onSurfaceVariant
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.Medium
      }

      MouseArea {
        id: resetMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onClicked: root.reset()
      }
    }
  }
}
