//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
  id: root
  property bool barEnabled: true
  readonly property var activeTop: ToplevelManager.activeToplevel
  readonly property bool fsActive: root.activeTop != null && root.activeTop.fullscreen
  readonly property bool barShown: barEnabled && (!root.fsActive
    || launcher.open || ControlState.open || ClockState.open || SettingsState.open
    || emojiPicker.open || clipboard.open)

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barEnabled = !root.barEnabled }
    function show(): void { root.barEnabled = true }
    function hide(): void { root.barEnabled = false }
  }

  Binding {
    target: IdleManager
    property: "fullscreenActive"
    value: root.fsActive
  }

  Connections {
    target: LockState
    function onLockedChanged() {
      NotificationServer.setDnd(LockState.locked)
    }
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 30
        color: "transparent"
        exclusionMode: ExclusionMode.Auto
        WlrLayershell.namespace: "quickshell"
        BackgroundEffect.blurRegion: Region { item: root.barShown ? barBg : null }
        readonly property bool barVisible: root.barShown || clockMenu.shown || settingsMenu.shown || controlCard.shown
        visible: barVisible
        mask: Region { item: root.barShown ? barBg : null }
        WlrLayershell.layer: WlrLayer.Overlay
        Rectangle {
          id: barBg
          anchors.fill: parent
          color: Theme.bg
          opacity: root.barShown ? 1 : 0
          visible: opacity > 0.01
          Bar { anchors.fill: parent }
        }
        ControlCenter {
          targetScreen: modelData
        }
        ControlCenterCard {
          id: controlCard
          targetScreen: modelData
        }
        ClockMenu {
          id: clockMenu
          targetScreen: modelData
        }
        SettingsMenu {
          id: settingsMenu
          targetScreen: modelData
          onChoose: action => {
            if (action === "wallpaper")
              wallpaperPicker.toggle()
            else if (action === "avatar")
              avatarPicker.toggle()
          }
        }
      }
    }
  }

  ToastStack {}
  Variants {
    model: Quickshell.screens
    delegate: Component {
      VolumeOSD {
        required property var modelData
        screen: modelData
      }
    }
  }
  Variants {
    model: Quickshell.screens
    delegate: Component {
      Wallpaper {
        required property var modelData
        screen: modelData
      }
    }
  }
  PanelWindow {
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-backdrop"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: (launcher.open || launcher.closePending)
      || (emojiPicker.open || emojiPicker.closePending)
      || (clipboard.open || clipboard.closePending)
      || (powerMenu.open || powerMenu.closePending)
      || ((wallpaperPicker.opened || wallpaperPicker.closePending) && wallpaperPicker.imagesLoaded)
      || (avatarPicker.opened || avatarPicker.closePending)

    MouseArea {
      anchors.fill: parent
      onClicked: {
        launcher.requestClose()
        emojiPicker.requestClose()
        clipboard.requestClose()
        powerMenu.requestClose()
        wallpaperPicker.requestClose()
        avatarPicker.requestClose()
      }
    }
  }
  Launcher {
    id: launcher
    onOpenChanged: if (open) { emojiPicker.requestClose(); clipboard.requestClose() }
  }
  EmojiPicker {
    id: emojiPicker
    onOpenChanged: if (open) { launcher.requestClose(); clipboard.requestClose() }
  }
  Clipboard {
    id: clipboard
    onOpenChanged: if (open) { launcher.requestClose(); emojiPicker.requestClose() }
  }
  WallpaperPicker {
    id: wallpaperPicker
  }
  AvatarPicker {
    id: avatarPicker
  }
  PowerMenu {
    id: powerMenu
  }
  Lock {}
}
