import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
  id: root

  property bool shown: false

  width: 380
  height: 56
  color: Theme.bg
  border.color: Theme.outline
  border.width: 1
  opacity: root.shown ? 1 : 0
  anchors.bottomMargin: root.shown ? 64 : -(root.height + 20)
  Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
  visible: opacity > 0.01

  RowLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12

    Item {
      Layout.preferredWidth: 24
      Layout.minimumWidth: 24
      Layout.maximumWidth: 24
      Layout.preferredHeight: 24
      QIcon {
        anchors.centerIn: parent
        name: Audio.icon
        size: 24
        color: Theme.fg
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Audio.toggleMute()
      }
    }

    CSlider {
      id: osdSlider
      Layout.fillWidth: true
      value: Audio.vol < 0 ? 0 : Audio.vol / 100
      onUserSet: v => {
        Audio.setVol(v * 100)
        hideTimer.restart()
      }
    }

    Text {
      text: Math.round(osdSlider.shown * 100) + "%"
      color: Theme.fg
      font.pixelSize: 12
      Layout.preferredWidth: 40
      Layout.minimumWidth: 40
      Layout.maximumWidth: 40
      horizontalAlignment: Text.AlignRight
    }
  }

  Timer {
    id: hideTimer
    interval: 1800
    onTriggered: root.shown = false
  }

  function show() {
    root.shown = true
    hideTimer.restart()
  }
}
