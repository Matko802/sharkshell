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
        exclusiveZone: OverviewState.open ? 0 : 30
        WlrLayershell.namespace: "quickshell"
        readonly property bool blurWanted: root.barShown && TransparencyState.transparent && !IdleManager.gaming
        property bool blurActive: false
        property real blurProg: 0
        Timer {
          id: blurSettle
          interval: 200
          onTriggered: {
            if (barWindow.blurActive !== barWindow.blurWanted) {
              barWindow.blurActive = barWindow.blurWanted
              barWindow.blurProg = 0
            }
          }
        }
        Timer {
          id: blurSlice
          interval: 16
          repeat: true
          running: barWindow.visible && barWindow.blurActive && barWindow.blurProg < 1
          onTriggered: barWindow.blurProg = Math.min(1, barWindow.blurProg + 0.1)
        }
        onBlurWantedChanged: blurSettle.restart()
        Component.onCompleted: blurSettle.restart()
        onVisibleChanged: {
          if (visible) {
            blurSettle.restart()
            barWindow.blurProg = 0
          } else {
            blurSettle.stop()
            barWindow.blurActive = false
            barWindow.blurProg = 0
          }
        }
        readonly property bool barVisible: root.barShown || clockMenu.shown || settingsMenu.shown || controlCard.shown
        visible: barVisible
        mask: Region { item: root.barShown ? barBg : null }
        WlrLayershell.layer: WlrLayer.Overlay
        BackgroundEffect.blurRegion: Region { item: blurTracker }
        Rectangle {
          id: barBg
          anchors.fill: parent
          color: Theme.bg
          opacity: root.barShown ? 1 : 0
          visible: opacity > 0.01
          Bar { anchors.fill: parent }
        }
        Rectangle {
          id: blurTracker
          anchors.top: parent.top
          anchors.left: parent.left
          width: Math.ceil(parent.width * barWindow.blurProg)
          height: Math.ceil(parent.height * barWindow.blurProg)
          color: "transparent"
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
  Variants {
    model: Quickshell.screens
    delegate: Component {
      Desktop {
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
    mask: Region { }
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

  Timer {
    id: wallpaperPrewarmTimer
    interval: 4000
    repeat: false
    running: true
    onTriggered: wallpaperPicker.prewarm()
  }

  Timer {
    id: avatarPrewarmTimer
    interval: 7000
    repeat: false
    running: true
    onTriggered: avatarPicker.prewarm()
  }
}
