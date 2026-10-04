import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root

  required property var trayData
  required property var anchorItem
  required property var anchorWindow
  property bool open: false

  signal requestClose()

  readonly property real cardW: 240
  readonly property point iconPos: root.anchorItem
    ? root.anchorItem.mapToItem(null, root.anchorItem.width / 2, root.anchorItem.height)
    : Qt.point(0, 0)
  readonly property real cardX: Math.max(8, Math.min(root.anchorWindow.width - root.cardW - 8, root.iconPos.x - root.cardW / 2))
  readonly property real cardY: root.anchorWindow.height + 4

  property real showProg: root.open ? 1 : 0
  Behavior on showProg { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

  function setShown(show) {
    try {
      if (root.trayData.menu)
        root.trayData.menu.showChildren = show
    } catch (e) {
    }
  }

  QsMenuOpener {
    id: rootOpener
    menu: root.open ? root.trayData.menu : null
  }

  onOpenChanged: root.setShown(root.open)

  PanelWindow {
    id: win
    screen: root.anchorWindow.screen
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { item: card }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: root.open

    onVisibleChanged: {
      if (visible)
        kbGrab.forceActiveFocus()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.requestClose()
    }

    Item {
      id: kbGrab
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: {
        root.requestClose()
        event.accepted = true
      }
    }

    Rectangle {
      id: card
      x: root.cardX
      y: root.cardY - 8 * (1 - root.showProg)
      opacity: root.showProg
      width: root.cardW
      height: Math.min(380, flick.contentHeight + 16)
      color: Theme.bg
      border.color: Theme.outline
      border.width: 1

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        interactive: contentHeight > height

        Column {
          id: col
          width: flick.width
          spacing: 0

          Repeater {
            model: rootOpener.children
            delegate: TrayMenuRow {
              width: col.width
              Component.onCompleted: entry = modelData
              onActivate: root.requestClose()
            }
          }

          Text {
            visible: rootOpener.children.values.length === 0
            width: col.width
            text: "No actions"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
