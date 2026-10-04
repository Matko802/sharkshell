import QtQuick
import Quickshell

Column {
  id: root

  property var entry: ({ isSeparator: false, enabled: false, text: "", icon: "", buttonType: 0, checkState: 0, hasChildren: false })
  property bool expanded: false

  signal activate()

  spacing: 0

  function setShown(show) {
    try {
      if (root.entry && root.entry.hasChildren)
        root.entry.showChildren = show
    } catch (e) {
    }
  }

  onExpandedChanged: root.setShown(root.expanded)

  TrayMenuRowView {
    width: parent.width
    entry: root.entry
    showArrow: root.entry.hasChildren
    onClicked: {
      if (root.entry.hasChildren) {
        root.expanded = !root.expanded
      } else {
        root.entry.triggered()
        root.activate()
      }
    }
  }

  QsMenuOpener {
    id: subOpener
    menu: root.expanded && root.entry.hasChildren ? root.entry : null
  }

  Repeater {
    model: root.expanded ? subOpener.children : null
    delegate: TrayMenuSubRow {
      width: root.width
      Component.onCompleted: entry = modelData
      onActivate: root.activate()
    }
  }
}
