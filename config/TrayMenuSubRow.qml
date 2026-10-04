import QtQuick
import Quickshell

Item {
  id: root

  property var entry: ({ isSeparator: false, enabled: false, text: "", icon: "", buttonType: 0, checkState: 0, hasChildren: false })

  signal activate()

  height: view.height

  TrayMenuRowView {
    id: view
    anchors.fill: parent
    anchors.leftMargin: 12
    entry: root.entry
    showArrow: false
    onClicked: {
      root.entry.triggered()
      root.activate()
    }
  }
}
