import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
  id: root
  anchors.fill: parent

  property bool rightOnly: false
  property bool menuOpen: false
  property bool qsHover: false
  readonly property real qsBtnWidth: quickSettingsBtn.implicitWidth
  signal menuRequested(string section)

  onMenuOpenChanged: root.qsHover = false

  RowLayout {
    visible: !root.rightOnly
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: Theme.spacingS

    Workspaces {}
    MangoLayout {}
    ActiveWindow {
      Layout.maximumWidth: 280
      Layout.preferredWidth: 220
      Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
    }
  }

  Rectangle {
    id: clockCenterBtn
    visible: !root.rightOnly
    anchors.centerIn: parent
    implicitWidth: clockCenterRow.implicitWidth + 14
    implicitHeight: 22
    color: clockCenterMa.containsMouse ? Theme.fg : "transparent"
    border.color: clockCenterMa.containsMouse ? Theme.outline : "transparent"
    border.width: 1
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
    RowLayout {
      id: clockCenterRow
      anchors.centerIn: parent
      spacing: Theme.spacingS
      Text {
        id: clockCenterLabel
        color: clockCenterMa.containsMouse ? Theme.bg : Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 12
        property int notifCount: NotificationServer.meaningfulCount
        Timer {
          interval: 1000; running: true; repeat: true; triggeredOnStart: true
          onTriggered: {
            const d = new Date()
            const pad = n => String(n).padStart(2, "0")
            clockCenterLabel.text = pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
          }
        }
      }
      Rectangle {
        Layout.preferredWidth: 6; Layout.preferredHeight: 6
        Layout.alignment: Qt.AlignVCenter
        radius: 3
        visible: clockCenterLabel.notifCount > 0
        color: clockCenterMa.containsMouse ? Theme.bg : Theme.fg
      }
    }
    MouseArea {
      id: clockCenterMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ClockState.toggle(clockCenterBtn.QsWindow.window)
    }
  }

  RowLayout {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: Theme.spacingS

    Tray {
      visible: !root.rightOnly
    }
    Item {
      Layout.preferredWidth: langLabel.implicitWidth
      Layout.preferredHeight: 18
      Language {
        id: langLabel
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["/run/current-system/sw/bin/niri", "msg", "action", "switch-layout", "next"])
      }
    }

    Rectangle {
      id: quickSettingsBtn
      Layout.fillHeight: true
      Layout.topMargin: 4
      Layout.bottomMargin: 4
      implicitWidth: quickSettingsRow.implicitWidth + 14
      Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
      radius: Theme.rounding
      color: (root.qsHover && !root.menuOpen) ? Theme.fg : "transparent"
      border.color: (root.qsHover && !root.menuOpen) ? Theme.outline : "transparent"
      border.width: 1

      Battery { id: bat }

      RowLayout {
        id: quickSettingsRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; QIcon { anchors.centerIn: parent; name: Audio.icon; size: 18; color: (root.qsHover && !root.menuOpen) ? Theme.bg : Theme.fg } }
        Item { Layout.preferredWidth: 18; Layout.preferredHeight: 18; QIcon { anchors.centerIn: parent; name: Network.online ? Network.icon : "wifi-off"; size: 18; color: (root.qsHover && !root.menuOpen) ? Theme.bg : (Network.online ? Theme.fg : Theme.muted2) } }
        Item {
          Layout.preferredWidth: 18; Layout.preferredHeight: 18
          visible: bat.batName !== ""
          QIcon { anchors.centerIn: parent; name: bat.batName; size: 18; color: (root.qsHover && !root.menuOpen) ? Theme.bg : Theme.fg }
        }
      }

      MouseArea {
        id: quickSettingsMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.qsHover = true
        onExited: root.qsHover = false
        onClicked: {
          if (root.rightOnly)
            root.menuRequested("quick")
          else
            ControlState.toggle(quickSettingsBtn.QsWindow.window)
        }
        onWheel: wheel => {
          Audio.setVol((Audio.vol < 0 ? 50 : Audio.vol) + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
      }
    }
  }
}
