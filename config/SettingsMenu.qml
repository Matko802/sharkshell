import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "Util.js" as Util

PanelWindow {
  id: root

  property var targetScreen: null

  anchors.top: true
  margins.top: 30
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
    WlrLayershell.namespace: "quickshell-modal"
    BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent && !slideIn.running && !slideOut.running ? card : null }
    mask: Region { item: card }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property bool shown: false

  signal choose(string action)
  property int activeTab: 0
  property int selIdx: 0
  property int hoverIdx: -1
  property int hoverTab: -1
  readonly property string fontFamily: Theme.fontFamily

  readonly property var tabs: [
    { name: "Theme", glyph: "wallpaper" },
    { name: "Sound", glyph: "audio-volume-high" },
    { name: "User", glyph: "user-circle" },
    { name: "Visual", glyph: "equalizer" },
    { name: "Power", glyph: "suspend" }
  ]

  function fmtDur(s) {
    if (s <= 0) return "off"
    if (s < 60) return s + "s"
    const m = Math.round(s / 6) / 10
    return (m % 1 === 0 ? String(m) : m.toFixed(1)) + "m"
  }

  readonly property var themeItems: [
    { name: "Wallpaper", glyph: "wallpaper", action: "wallpaper", hint: "Set desktop wallpaper" }
  ]

  readonly property var sources: Pipewire.nodes.values
    .filter(n => n && n.audio && !n.isStream && !n.isSink)
    .map(n => ({ id: n.id, name: String(n.name), desc: String(n.description || n.name) }))
  readonly property var sinks: Pipewire.nodes.values
    .filter(n => n && n.audio && !n.isStream && n.isSink)
    .map(n => ({ id: n.id, name: String(n.name), desc: String(n.description || n.name) }))

  function isDefaultSink(id) {
    return Pipewire.defaultAudioSink != null && Pipewire.defaultAudioSink.id === id
  }
  function isDefaultSource(id) {
    return Pipewire.defaultAudioSource != null && Pipewire.defaultAudioSource.id === id
  }

  readonly property var audioModel: {
    const arr = []
    arr.push({ header: true, label: "INPUT" })
    for (const s of root.sources) arr.push({ header: false, id: s.id, desc: s.desc, name: s.name, def: root.isDefaultSource(s.id), type: "source" })
    arr.push({ header: true, label: "OUTPUT" })
    for (const k of root.sinks) arr.push({ header: false, id: k.id, desc: k.desc, name: k.name, def: root.isDefaultSink(k.id), type: "sink" })
    return arr
  }

  readonly property var visualItems: [{ kind: "mode" }, { kind: "bars" }]
  readonly property var currentItems: root.activeTab === 0 ? root.themeItems : (root.activeTab === 3 ? root.visualItems : (root.activeTab === 4 ? [] : root.audioModel))

  function activate(i) {
    const item = root.currentItems[i]
    if (!item || item.header)
      return
    if (root.activeTab === 0) {
      SettingsState.close()
      root.choose(item.action)
    } else if (root.activeTab === 3) {
      root.selIdx = i
      if (i === 0) VisualizerState.cycleMode()
      else VisualizerState.cycleBars()
    } else {
      root.selIdx = i
      if (item.type === "source")
        Audio.setDefaultSource(item.id)
      else
        Audio.setDefaultSink(item.id)
    }
  }

  onActiveTabChanged: {
    root.selIdx = 0
    root.hoverIdx = -1
    root.skipHeader(1)
    pageFlick.contentY = 0
  }
  onCurrentItemsChanged: {
    if (root.selIdx >= root.currentItems.length)
      root.selIdx = Math.max(0, root.currentItems.length - 1)
  }

  function skipHeader(dir) {
    const items = root.currentItems
    let guard = 0
    while (root.selIdx >= 0 && root.selIdx < items.length && items[root.selIdx] && items[root.selIdx].header && guard++ < 50)
      root.selIdx += dir
    if (root.selIdx < 0) root.selIdx = 0
    if (root.selIdx >= items.length) root.selIdx = items.length - 1
  }

  screen: root.targetScreen
  visible: root.shown && (!SettingsState.screen || SettingsState.screen === root.targetScreen)
  implicitWidth: 700
  implicitHeight: 424

  Connections {
    target: SettingsState
    function onOpenChanged() {
      if (SettingsState.open && (!SettingsState.screen || SettingsState.screen === root.targetScreen)) {
        root.shown = true
        root.activeTab = 0
        root.selIdx = 0
        root.hoverIdx = -1
        root.hoverTab = -1
      }
      else if (!SettingsState.open && root.shown && !slideOut.running)
        slideOut.restart()
    }
  }
  onShownChanged: {
    if (shown) { card.y = -card.height - 8; slideIn.restart() }
  }
  NumberAnimation { id: slideIn; target: card; property: "y"; to: 0; duration: 250; easing.type: Easing.OutCubic }
  NumberAnimation { id: slideOut; target: card; property: "y"; to: -card.height - 12; duration: 250; easing.type: Easing.InCubic; onFinished: root.shown = false }
  Timer {
    running: root.shown
    repeat: true
    interval: 500
    onTriggered: {
      if (root.shown && !kbFocus.activeFocus)
        kbFocus.forceActiveFocus()
    }
  }

  Rectangle {
    id: card
    width: 700
    height: 424
    clip: true
    anchors.horizontalCenter: parent.horizontalCenter
    color: Theme.bg
    border.color: Theme.outline
    border.width: 1

      ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 424
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 16
          spacing: 0
          Item { Layout.fillWidth: true }
          Repeater {
            model: root.tabs
            delegate: Item {
              required property var modelData
              required property int index
              Layout.preferredWidth: 80
              Layout.preferredHeight: 28
              property bool active: root.activeTab === index
              Text {
                anchors.centerIn: parent
                text: modelData.name
                color: parent.active ? Theme.fg : Theme.muted2
                font.family: root.fontFamily
                font.pixelSize: 12
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = index
              }
            }
          }
          Item { Layout.fillWidth: true }
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          Flickable {
            id: pageFlick
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: swipeRow.width
            contentHeight: swipeRow.height
            contentX: root.activeTab * pageFlick.width
            Behavior on contentX { NumberAnimation { duration: 130; easing.type: Theme.easingOut } }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Row {
              id: swipeRow
              spacing: 0

              ColumnLayout {
                id: tab0col
                width: pageFlick.width
                spacing: 8

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  color: root.hoverIdx === 0 ? Theme.bgAlt : "transparent"
                  border.color: root.hoverIdx === 0 ? Theme.borderStrong : Theme.border
                  border.width: 1
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIdx = 0
                    onExited: { if (root.hoverIdx === 0) root.hoverIdx = -1 }
                    onClicked: root.activate(0)
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Item {
                      Layout.preferredWidth: 20
                      Layout.preferredHeight: 20
                      QIcon {
                        anchors.centerIn: parent
                        name: "wallpaper"
                        size: 18
                        color: Theme.fg
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 8
                      Layout.bottomMargin: 8
                      spacing: 2
                      Text {
                        text: "Wallpaper"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  color: root.hoverIdx === -8 ? Theme.bgAlt : "transparent"
                  border.color: root.hoverIdx === -8 ? Theme.borderStrong : Theme.border
                  border.width: 1
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIdx = -8
                    onExited: { if (root.hoverIdx === -8) root.hoverIdx = -1 }
                    onClicked: DynamicTheme.toggle()
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 56
                    spacing: 10
                    Item {
                      Layout.preferredWidth: 20
                      Layout.preferredHeight: 20
                      QIcon {
                        anchors.centerIn: parent
                        name: "preferences-desktop-theme"
                        size: 18
                        color: Theme.fg
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 8
                      Layout.bottomMargin: 8
                      spacing: 2
                      Text {
                        text: "Dynamic theme"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                      }
                    }
                  }
                  CToggle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: DynamicTheme.enabled
                    onToggled: v => DynamicTheme.setEnabled(v)
                  }
                }

                SettingSlider {
                  label: "Blur"
                  icon: "opacity"
                  value: BlurState.radius / BlurState.max
                  text: String(Math.round(BlurState.radius))
                  onUserSet: v => BlurState.setRadius(v * BlurState.max)
                  onReset: BlurState.reset()
                }

                SettingSlider {
                  label: "Transparency"
                  icon: "layers"
                  value: TransparencyState.amount / TransparencyState.amountMax
                  text: Math.round(TransparencyState.amount * 100) + "%"
                  onUserSet: v => {
                    const a = v * TransparencyState.amountMax
                    TransparencyState.setAmount(a)
                    TransparencyState.setTransparent(a > 0)
                  }
                  onReset: {
                    TransparencyState.resetAmount()
                    TransparencyState.setTransparent(true)
                  }
                }

              }

              ColumnLayout {
                id: tab1col
                width: pageFlick.width
                spacing: 6
                Repeater {
                  model: root.audioModel
                  delegate: audioCardComp
                }
              }

              ColumnLayout {
                id: tab2col
                width: pageFlick.width
                spacing: 8

                Text {
                  text: "PROFILE"
                  color: Theme.muted2
                  font.family: root.fontFamily
                  font.pixelSize: 9
                  font.letterSpacing: 2
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 48
                  color: Theme.bgAlt
                  border.color: Theme.border
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Rectangle {
                      Layout.preferredWidth: 36
                      Layout.preferredHeight: 36
                      radius: 18
                      clip: true
    color: Theme.bg
                      border.color: Theme.outline
                      border.width: 1
                      Image {
                        anchors.fill: parent
                        source: AvatarState.path !== "" ? Util.fileUrl(AvatarState.path) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                      }
                      Text {
                        anchors.centerIn: parent
                        visible: AvatarState.path === ""
                        text: "?"
                        color: Theme.muted3
                        font.family: root.fontFamily
                        font.pixelSize: 16
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 8
                      Layout.bottomMargin: 8
                      spacing: 2
                      Text {
                        Layout.fillWidth: true
                        text: AvatarState.path !== "" ? AvatarState.path.split("/").pop() : "No profile picture"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                      }
                    }
                    Rectangle {
                      Layout.preferredWidth: 60
                      Layout.preferredHeight: 26
                      color: root.hoverIdx === -6 ? Theme.fg : "transparent"
                      border.color: Theme.outline
                      border.width: 1
                      Text {
                        anchors.centerIn: parent
                        text: "Choose"
                        color: root.hoverIdx === -6 ? Theme.bg : Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverIdx = -6
                        onExited: { if (root.hoverIdx === -6) root.hoverIdx = -1 }
                        onClicked: root.choose("avatar")
                      }
                    }
                    Rectangle {
                      Layout.preferredWidth: 52
                      Layout.preferredHeight: 26
                      visible: AvatarState.path !== ""
                      color: root.hoverIdx === -7 ? Theme.fg : "transparent"
                      border.color: Theme.outline
                      border.width: 1
                      Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: root.hoverIdx === -7 ? Theme.bg : Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverIdx = -7
                        onExited: { if (root.hoverIdx === -7) root.hoverIdx = -1 }
                        onClicked: AvatarState.clear()
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 44
                  color: Theme.bgAlt
                  border.color: Theme.border
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    QIcon { name: "camera-photo"; size: 18; color: Theme.muted }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 6
                      Layout.bottomMargin: 6
                      spacing: 2
                      Text {
                        text: "Avatar file"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 11
                      }
                      Text {
                        text: AvatarState.path !== "" ? AvatarState.path : "No file selected"
                        color: Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideMiddle
                      }
                    }
                  }
                }
              }
              ColumnLayout {
                id: tab3col
                width: pageFlick.width
                spacing: 8

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  color: root.selIdx === 0 ? Theme.fg
                       : (root.hoverIdx === -10 ? Theme.bgAlt : "transparent")
                  border.color: root.selIdx === 0 ? Theme.outline
                       : (root.hoverIdx === -10 ? Theme.borderStrong : Theme.border)
                  border.width: 1
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIdx = -10
                    onExited: { if (root.hoverIdx === -10) root.hoverIdx = -1 }
                    onClicked: { root.selIdx = 0; VisualizerState.cycleMode() }
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Item {
                      Layout.preferredWidth: 20
                      Layout.preferredHeight: 20
                      QIcon {
                        anchors.centerIn: parent
                        name: "equalizer"
                        size: 18
                        color: root.selIdx === 0 ? Theme.bg : Theme.fg
                      }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: "Mode"
                      color: root.selIdx === 0 ? Theme.bg : Theme.fg
                      font.family: root.fontFamily
                      font.pixelSize: 12
                      font.weight: Font.DemiBold
                    }
                    Text {
                      text: VisualizerState.modeLabel()
                      color: root.selIdx === 0 ? Theme.bg : Theme.muted
                      font.family: root.fontFamily
                      font.pixelSize: 11
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  color: root.selIdx === 1 ? Theme.fg
                       : (root.hoverIdx === -11 ? Theme.bgAlt : "transparent")
                  border.color: root.selIdx === 1 ? Theme.outline
                       : (root.hoverIdx === -11 ? Theme.borderStrong : Theme.border)
                  border.width: 1
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIdx = -11
                    onExited: { if (root.hoverIdx === -11) root.hoverIdx = -1 }
                    onClicked: { root.selIdx = 1; VisualizerState.cycleBars() }
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    Item {
                      Layout.preferredWidth: 20
                      Layout.preferredHeight: 20
                      QIcon {
                        anchors.centerIn: parent
                        name: "tune"
                        size: 18
                        color: root.selIdx === 1 ? Theme.bg : Theme.fg
                      }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: "Bars"
                      color: root.selIdx === 1 ? Theme.bg : Theme.fg
                      font.family: root.fontFamily
                      font.pixelSize: 12
                      font.weight: Font.DemiBold
                    }
                    Text {
                      text: String(VisualizerState.bars)
                      color: root.selIdx === 1 ? Theme.bg : Theme.muted
                      font.family: root.fontFamily
                      font.pixelSize: 11
                    }
                  }
                }
              }

              ColumnLayout {
                id: tab4col
                width: pageFlick.width
                spacing: 8

                SettingSlider {
                  label: "Lock"
                  icon: "lock"
                  value: IdleManager.lockTimeout / 1800
                  text: root.fmtDur(IdleManager.lockTimeout)
                  onUserSet: v => IdleManager.setLockTimeout(v * 1800)
                  onReset: IdleManager.setLockTimeout(IdleManager.lockDef)
                }

                SettingSlider {
                  label: "Monitor"
                  icon: "device-desktop"
                  value: IdleManager.screenOffDelay / 1800
                  text: root.fmtDur(IdleManager.screenOffDelay)
                  onUserSet: v => IdleManager.setScreenOffDelay(v * 1800)
                  onReset: IdleManager.setScreenOffDelay(IdleManager.screenOffDef)
                }

                SettingSlider {
                  label: "Sleep"
                  icon: "suspend"
                  value: IdleManager.suspendTimeout / 3600
                  text: root.fmtDur(IdleManager.suspendTimeout)
                  onUserSet: v => IdleManager.setSuspendTimeout(v * 3600)
                  onReset: IdleManager.setSuspendTimeout(IdleManager.suspendDef)
                }
              }
            }
          }
        }
      }

      Item {
        id: kbFocus
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
            root.activeTab = (root.activeTab + 1) % root.tabs.length
            root.selIdx = 0
            root.hoverIdx = -1
            root.skipHeader(1)
            event.accepted = true
            return
          }
          if ((event.key === Qt.Key_Backtab) || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            root.activeTab = (root.activeTab - 1 + root.tabs.length) % root.tabs.length
            root.selIdx = 0
            root.hoverIdx = -1
            root.skipHeader(1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape) { SettingsState.close(); event.accepted = true; return }
          if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            root.activeTab = event.key === Qt.Key_Right
              ? (root.activeTab + 1) % root.tabs.length
              : (root.activeTab - 1 + root.tabs.length) % root.tabs.length
            root.selIdx = 0
            root.hoverIdx = -1
            root.skipHeader(1)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Up) { root.selIdx = Math.max(0, root.selIdx - 1); root.skipHeader(-1); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.selIdx = Math.min(root.currentItems.length - 1, root.selIdx + 1); root.skipHeader(1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.activate(root.selIdx); event.accepted = true }
        }
      }
    }

  Component {
    id: audioCardComp
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: modelData.header ? 18 : 32
      Rectangle {
        anchors.fill: parent
        visible: !modelData.header
        color: root.selIdx === index ? Theme.fg
             : (root.hoverIdx === index ? Theme.bgAlt : "transparent")
        border.color: root.selIdx === index ? Theme.outline
             : (modelData.def ? Theme.fg : (root.hoverIdx === index ? Theme.borderStrong : Theme.border))
        border.width: 1
        opacity: modelData.header ? 0 : 1
      }
      MouseArea {
        anchors.fill: parent
        visible: !modelData.header
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverIdx = index
        onExited: { if (root.hoverIdx === index) root.hoverIdx = -1 }
        onClicked: root.activate(index)
      }
      RowLayout {
        anchors.fill: parent
        visible: !modelData.header
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        Item {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          QIcon {
            anchors.centerIn: parent
            name: modelData.type === "source" ? "mic" : "audio-volume-high"
            size: 18
            color: root.selIdx === index ? Theme.bg : Theme.fg
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.topMargin: 8
          Layout.bottomMargin: 8
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: modelData.desc || ""
            color: root.selIdx === index ? Theme.bg : Theme.fg
            font.family: root.fontFamily
            font.pixelSize: 12
            elide: Text.ElideRight
          }
        }
      }
      Text {
        visible: modelData.header
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.label || ""
        color: Theme.muted2
        font.family: root.fontFamily
        font.pixelSize: 9
        font.letterSpacing: 2
      }
    }
  }
}
