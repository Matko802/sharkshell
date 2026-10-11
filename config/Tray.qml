import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Row {
  id: trayRoot
  spacing: Theme.spacingS

  property var menuOwner: null

  Repeater {
    model: SystemTray.items

    delegate: Item {
      id: trayItem
      required property var modelData
      property bool wantMenu: false
      width: 18
      height: 18

      function toggleTrayMenu() {
        if (trayItem.wantMenu && trayRoot.menuOwner === trayItem.modelData) {
          trayItem.wantMenu = false
          trayRoot.menuOwner = null
        } else {
          trayItem.wantMenu = true
          trayRoot.menuOwner = trayItem.modelData
        }
      }

      Image {
        anchors.centerIn: parent
        source: trayItem.modelData.icon
        width: 16
        height: 16
        sourceSize.width: 16
        sourceSize.height: 16
        fillMode: Image.PreserveAspectFit
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && trayItem.modelData.onlyMenu)) {
            if (!trayItem.modelData.hasMenu)
              return
            trayItem.toggleTrayMenu()
          } else if (mouse.button === Qt.MiddleButton) {
            trayItem.modelData.secondaryActivate()
          } else {
            trayItem.modelData.activate()
          }
        }
        onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false)
      }

      TrayMenu {
        trayData: trayItem.modelData
        anchorItem: trayItem
        anchorWindow: trayItem.QsWindow.window
        open: trayItem.wantMenu && trayRoot.menuOwner === trayItem.modelData
        onRequestClose: {
          trayItem.wantMenu = false
          if (trayRoot.menuOwner === trayItem.modelData)
            trayRoot.menuOwner = null
        }
      }
    }
  }
}
