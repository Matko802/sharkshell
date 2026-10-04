import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
  id: root

  required property var entry
  property bool showArrow: false

  signal clicked()

  function cleanLabel(t) {
    return String(t ?? "").replace(/_(?=[^_]|$)/g, "")
  }

  readonly property bool checkable: root.entry.buttonType === QsMenuButtonType.CheckBox
    || root.entry.buttonType === QsMenuButtonType.RadioButton
  readonly property bool checked: root.entry.checkState === Qt.Checked

  height: root.entry.isSeparator ? 9 : 28
  color: rowMa.containsMouse && !root.entry.isSeparator && root.entry.enabled ? Theme.fg : "transparent"

  Rectangle {
    visible: root.entry.isSeparator
    anchors.centerIn: parent
    width: parent.width - 16
    height: 1
    color: Theme.muted
    opacity: 0.4
  }

  RowLayout {
    visible: !root.entry.isSeparator
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    spacing: 8

    Item {
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      Layout.alignment: Qt.AlignVCenter

      QIcon {
        anchors.centerIn: parent
        visible: root.checkable && root.checked
        name: "check"
        size: 14
        color: rowMa.containsMouse && root.entry.enabled ? Theme.bg : Theme.fg
      }

      Rectangle {
        anchors.centerIn: parent
        visible: root.checkable && !root.checked
        width: 8
        height: 8
        color: "transparent"
        border.color: rowMa.containsMouse && root.entry.enabled ? Theme.bg : Theme.muted
        border.width: 1
      }

      Image {
        anchors.centerIn: parent
        visible: !root.checkable && root.entry.icon !== ""
        source: root.entry.icon
        width: 16
        height: 16
        sourceSize.width: 16
        sourceSize.height: 16
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.cleanLabel(root.entry.text)
      color: !root.entry.enabled ? Theme.muted
        : (rowMa.containsMouse ? Theme.bg : Theme.fg)
      font.family: Theme.fontFamily
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Item {
      Layout.preferredWidth: 14
      Layout.preferredHeight: 14
      Layout.alignment: Qt.AlignVCenter
      visible: root.showArrow
      QIcon {
        anchors.centerIn: parent
        name: "chevron-right"
        size: 14
        color: rowMa.containsMouse && root.entry.enabled ? Theme.bg : Theme.fg
      }
    }
  }

  MouseArea {
    id: rowMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.entry.enabled && !root.entry.isSeparator ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.entry.isSeparator || !root.entry.enabled)
        return
      root.clicked()
    }
  }
}
