//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
  id: root
  property bool barEnabled: true
  property bool fullscreenActive: false
  readonly property bool barShown: barEnabled && (!root.fullscreenActive
    || launcher.open || ControlState.open || ClockState.open || SettingsState.open
    || emojiPicker.open || clipboard.open)

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barEnabled = !root.barEnabled }
    function show(): void { root.barEnabled = true }
    function hide(): void { root.barEnabled = false }
  }

  Connections {
    target: LockState
    function onLockedChanged() {
      NotificationServer.setDnd(LockState.locked)
    }
  }

  property int focusedWindowId: -1
  property int focusedWorkspaceId: -1
  property var windowLayouts: ({})

  function isFsLayout(l) {
    if (!l || !l.tile_size) return false
    for (let i = 0; i < Quickshell.screens.length; ++i) {
      const s = Quickshell.screens[i]
      if (Math.abs(l.tile_size[0] - s.width) <= 2 && Math.abs(l.tile_size[1] - s.height) <= 2) return true
    }
    return false
  }
  function refreshFs() {
    root.fullscreenActive = isFsLayout(root.windowLayouts[root.focusedWindowId])
  }
  function pollFs() {
    if (!niriFsPoll.running) niriFsPoll.running = true
  }
  Process {
    id: niriFsPoll
    running: false
    command: ["/run/current-system/sw/bin/niri", "msg", "-j", "windows"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const wins = JSON.parse(text.trim())
          const layouts = {}
          let fid = -1
          for (const w of wins) {
            if (w.layout) layouts[w.id] = w.layout
            if (w.is_focused) fid = w.id
          }
          root.windowLayouts = layouts
          if (fid >= 0) root.focusedWindowId = fid
          refreshFs()
        } catch (e) {}
      }
    }
  }
  Process {
    id: niriFsWatch
    running: true
    command: ["sh", "-c", "command -v niri >/dev/null 2>&1 && stdbuf -oL niri msg -j event-stream 2>/dev/null || sleep 999999"]
    stdout: SplitParser {
      onRead: data => {
        let j = null
        try { j = JSON.parse(data) } catch (e) { return }
        if (j.WindowsChanged) {
          const layouts = {}
          let fid = -1
          for (const w of j.WindowsChanged.windows) {
            if (w.layout) layouts[w.id] = w.layout
            if (w.is_focused) fid = w.id
          }
          root.windowLayouts = layouts
          if (fid >= 0) root.focusedWindowId = fid
          refreshFs()
          return
        }
        if (j.WindowOpenedOrChanged && j.WindowOpenedOrChanged.window) {
          const w = j.WindowOpenedOrChanged.window
          if (w.layout) root.windowLayouts[w.id] = w.layout
          if (w.is_focused) {
            root.focusedWindowId = w.id
            refreshFs()
          }
          return
        }
        if (j.WindowFocusChanged !== undefined) {
          const id = j.WindowFocusChanged ? j.WindowFocusChanged.id : -1
          root.focusedWindowId = (id == null ? -1 : id)
          if (root.windowLayouts[root.focusedWindowId]) refreshFs()
          else if (root.focusedWindowId >= 0) pollFs()
          else refreshFs()
          return
        }
        if (j.WindowLayoutsChanged && j.WindowLayoutsChanged.changes) {
          let hit = false
          for (const c of j.WindowLayoutsChanged.changes) {
            root.windowLayouts[c[0]] = c[1]
            if (c[0] === root.focusedWindowId) hit = true
          }
          if (hit) refreshFs()
          return
        }
        if (j.WindowClosed !== undefined) {
          const cid = (typeof j.WindowClosed === "number") ? j.WindowClosed : j.WindowClosed.id
          if (cid !== undefined) {
            delete root.windowLayouts[cid]
            if (cid === root.focusedWindowId) pollFs()
          }
          return
        }
        if (j.WorkspacesChanged && j.WorkspacesChanged.workspaces) {
          for (const ws of j.WorkspacesChanged.workspaces) {
            if (ws.is_focused) root.focusedWorkspaceId = ws.id
          }
          return
        }
        if (j.WorkspaceActiveWindowChanged) {
          const e = j.WorkspaceActiveWindowChanged
          if (e.workspace_id === root.focusedWorkspaceId && e.active_window_id != null) {
            root.focusedWindowId = e.active_window_id
            if (root.windowLayouts[e.active_window_id]) refreshFs()
            else pollFs()
          }
          return
        }
      }
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
        WlrLayershell.layer: WlrLayer.Top
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
    WlrLayershell.layer: WlrLayer.Overlay
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
