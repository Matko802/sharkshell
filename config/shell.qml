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
    || (launcherLoader.item?.open ?? false) || ControlState.open || ClockState.open || SettingsState.open
    || (emojiLoader.item?.open ?? false) || (clipboardLoader.item?.open ?? false))

  property bool launcherNeeded: false
  property bool launcherPending: false
  property bool emojiNeeded: false
  property bool emojiPending: false
  property bool clipboardNeeded: false
  property bool clipboardPending: false
  property bool wallpaperNeeded: false
  property bool wallpaperPending: false
  property bool avatarNeeded: false
  property bool avatarPending: false
  property bool powerNeeded: false
  property bool powerPending: false

  function requestLauncher() {
    if (!root.launcherNeeded) {
      root.launcherNeeded = true
      root.launcherPending = true
      return
    }
    const it = launcherLoader.item
    if (it)
      it.toggle()
    else
      root.launcherPending = true
  }

  function requestEmoji() {
    if (!root.emojiNeeded) {
      root.emojiNeeded = true
      root.emojiPending = true
      return
    }
    const it = emojiLoader.item
    if (it)
      it.toggle()
    else
      root.emojiPending = true
  }

  function requestClipboard() {
    if (!root.clipboardNeeded) {
      root.clipboardNeeded = true
      root.clipboardPending = true
      return
    }
    const it = clipboardLoader.item
    if (it)
      it.toggle()
    else
      root.clipboardPending = true
  }

  function requestWallpaper() {
    if (!root.wallpaperNeeded) {
      root.wallpaperNeeded = true
      root.wallpaperPending = true
      return
    }
    const it = wallpaperLoader.item
    if (it)
      it.toggle()
    else
      root.wallpaperPending = true
  }

  function requestAvatar() {
    if (!root.avatarNeeded) {
      root.avatarNeeded = true
      root.avatarPending = true
      return
    }
    const it = avatarLoader.item
    if (it)
      it.toggle()
    else
      root.avatarPending = true
  }

  function requestPower() {
    if (!root.powerNeeded) {
      root.powerNeeded = true
      root.powerPending = true
      return
    }
    const it = powerLoader.item
    if (it)
      it.toggle()
    else
      root.powerPending = true
  }

  function closeModalsExcept(except) {
    if (except !== "launcher")
      launcherLoader.item?.requestClose()
    if (except !== "emoji")
      emojiLoader.item?.requestClose()
    if (except !== "clipboard")
      clipboardLoader.item?.requestClose()
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void { root.requestLauncher() }
    function close(): void { launcherLoader.item?.forceClose() }
  }

  IpcHandler {
    target: "emoji"
    function toggle(): void { root.requestEmoji() }
    function close(): void { emojiLoader.item?.forceClose() }
  }

  IpcHandler {
    target: "clipboard"
    function toggle(): void { root.requestClipboard() }
    function close(): void { clipboardLoader.item?.forceClose() }
  }

  IpcHandler {
    target: "wallpaper"
    function toggle(): void { root.requestWallpaper() }
    function close(): void { wallpaperLoader.item?.forceClose() }
    function openDesktop(): void {
      if (!root.wallpaperNeeded) {
        root.wallpaperNeeded = true
        root.wallpaperPending = true
        return
      }
      const it = wallpaperLoader.item
      if (it) {
        if (it.opened)
          it.switchTab(0)
        else
          it.openPickerWithTab(0)
      } else {
        root.wallpaperPending = true
      }
    }
  }

  IpcHandler {
    target: "avatar"
    function toggle(): void { root.requestAvatar() }
    function open(): void {
      if (!root.avatarNeeded) {
        root.avatarNeeded = true
        root.avatarPending = true
        return
      }
      const it = avatarLoader.item
      if (it)
        it.open()
      else
        root.avatarPending = true
    }
    function close(): void { avatarLoader.item?.forceClose() }
  }

  IpcHandler {
    target: "power"
    function toggle(): void { root.requestPower() }
    function close(): void { powerLoader.item?.forceClose() }
  }

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
        BackgroundEffect.blurRegion: Region { item: root.barShown && TransparencyState.transparent && !IdleManager.gaming ? barBg : null }
        readonly property bool barVisible: root.barShown || (clockLoader.item?.shown ?? false) || (settingsLoader.item?.shown ?? false) || (ccCardLoader.item?.shown ?? false)
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
        Loader {
          id: ccCardLoader
          property var scr: modelData
          active: (ControlState.open && (!ControlState.screen || ControlState.screen === scr)) || (item?.shown ?? false)
          sourceComponent: Component {
            ControlCenterCard {
              targetScreen: ccCardLoader.scr
            }
          }
        }
        Loader {
          id: clockLoader
          property var scr: modelData
          active: (ClockState.open && (!ClockState.screen || ClockState.screen === scr)) || (item?.shown ?? false)
          sourceComponent: Component {
            ClockMenu {
              targetScreen: clockLoader.scr
            }
          }
          onLoaded: {
            if (ClockState.open && (!ClockState.screen || ClockState.screen === scr))
              item.shown = true
          }
        }
        Loader {
          id: settingsLoader
          property var scr: modelData
          active: (SettingsState.open && (!SettingsState.screen || SettingsState.screen === scr)) || (item?.shown ?? false)
          sourceComponent: Component {
            SettingsMenu {
              targetScreen: settingsLoader.scr
              onChoose: action => {
                if (action === "wallpaper")
                  root.requestWallpaper()
                else if (action === "avatar")
                  root.requestAvatar()
              }
            }
          }
          onLoaded: {
            if (SettingsState.open && (!SettingsState.screen || SettingsState.screen === scr)) {
              item.shown = true
              item.activeTab = 0
              item.selIdx = 0
              item.hoverIdx = -1
              item.hoverTab = -1
            }
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
    mask: Region { }
    visible: (launcherLoader.item?.open ?? false) || (launcherLoader.item?.closePending ?? false)
      || (emojiLoader.item?.open ?? false) || (emojiLoader.item?.closePending ?? false)
      || (clipboardLoader.item?.open ?? false) || (clipboardLoader.item?.closePending ?? false)
      || (powerLoader.item?.open ?? false) || (powerLoader.item?.closePending ?? false)
      || (((wallpaperLoader.item?.opened ?? false) || (wallpaperLoader.item?.closePending ?? false)) && (wallpaperLoader.item?.imagesLoaded ?? false))
      || ((avatarLoader.item?.opened ?? false) || (avatarLoader.item?.closePending ?? false))

    MouseArea {
      anchors.fill: parent
      onClicked: {
        launcherLoader.item?.requestClose()
        emojiLoader.item?.requestClose()
        clipboardLoader.item?.requestClose()
        powerLoader.item?.requestClose()
        wallpaperLoader.item?.requestClose()
        avatarLoader.item?.requestClose()
      }
    }
  }
  Loader {
    id: launcherLoader
    active: root.launcherNeeded
    asynchronous: true
    sourceComponent: Component {
      Launcher {
        onOpenChanged: if (open) root.closeModalsExcept("launcher")
      }
    }
    onLoaded: {
      if (root.launcherPending) {
        root.launcherPending = false
        item.toggle()
      }
    }
  }
  Loader {
    id: emojiLoader
    active: root.emojiNeeded
    asynchronous: true
    sourceComponent: Component {
      EmojiPicker {
        onOpenChanged: if (open) root.closeModalsExcept("emoji")
      }
    }
    onLoaded: {
      if (root.emojiPending) {
        root.emojiPending = false
        item.toggle()
      }
    }
  }
  Loader {
    id: clipboardLoader
    active: root.clipboardNeeded
    asynchronous: true
    sourceComponent: Component {
      Clipboard {
        onOpenChanged: if (open) root.closeModalsExcept("clipboard")
      }
    }
    onLoaded: {
      if (root.clipboardPending) {
        root.clipboardPending = false
        item.toggle()
      }
    }
  }
  Loader {
    id: wallpaperLoader
    active: root.wallpaperNeeded
    asynchronous: true
    sourceComponent: Component { WallpaperPicker { } }
    onLoaded: {
      if (root.wallpaperPending) {
        root.wallpaperPending = false
        item.toggle()
      }
    }
  }
  Loader {
    id: avatarLoader
    active: root.avatarNeeded
    asynchronous: true
    sourceComponent: Component { AvatarPicker { } }
    onLoaded: {
      if (root.avatarPending) {
        root.avatarPending = false
        item.toggle()
      }
    }
  }
  Loader {
    id: powerLoader
    active: root.powerNeeded
    asynchronous: true
    sourceComponent: Component { PowerMenu { } }
    onLoaded: {
      if (root.powerPending) {
        root.powerPending = false
        item.toggle()
      }
    }
  }
  Lock {}
}
