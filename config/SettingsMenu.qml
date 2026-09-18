import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
  id: root

  property var targetScreen: null

  anchors.top: true
  anchors.bottom: true
  margins.top: 30
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-backdrop"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property bool shown: false
  property bool blurReady: false

  signal choose(string action)
  property int activeTab: 0
  property int prevTab: 0
  property int selIdx: 0
  property int hoverIdx: -1
  property int hoverTab: -1
  readonly property string fontFamily: Theme.fontFamily

  readonly property var tabs: [
    { name: "Theme", glyph: "wallpaper" },
    { name: "Sound", glyph: "audio-volume-high" },
    { name: "User", glyph: "user-circle" }
  ]

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

  readonly property var currentItems: root.activeTab === 0 ? root.themeItems : root.audioModel

  function activate(i) {
    const item = root.currentItems[i]
    if (!item || item.header)
      return
    if (root.activeTab === 0) {
      SettingsState.close()
      root.choose(item.action)
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
    // Slide + fade the incoming page in (clock-menu style).
    var dir = root.activeTab >= root.prevTab ? 48 : -48
    var pages = [tab0col, tab1col, tab2col]
    var behs = [[tab0slideBeh, tab0fadeBeh], [tab1slideBeh, tab1fadeBeh], [tab2slideBeh, tab2fadeBeh]]
    for (var i = 0; i < 3; i++) {
      behs[i][0].enabled = false
      behs[i][1].enabled = false
    }
    var page = pages[root.activeTab]
    if (page) {
      page.slideX = dir
      page.pageOpacity = 0
    }
    for (var j = 0; j < 3; j++) {
      behs[j][0].enabled = true
      behs[j][1].enabled = true
    }
    if (page) {
      page.slideX = 0
      page.pageOpacity = 1
    }
    root.prevTab = root.activeTab
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
      } else if (!SettingsState.open && root.shown && !slideOut.running) {
        root.blurReady = false
        slideOut.restart()
      }
    }
  }
  onShownChanged: {
    if (shown) { root.blurReady = false; card.y = -card.height - 8; slideIn.restart() }
  }
  NumberAnimation { id: slideIn; target: card; property: "y"; to: 4; duration: 250; easing.type: Easing.OutCubic; onFinished: root.blurReady = true }
  NumberAnimation {
    id: slideOut; target: card; property: "y"; to: -card.height - 12
    duration: 250; easing.type: Easing.InCubic; onFinished: root.shown = false
  }
  Timer {
    running: root.shown
    repeat: true
    interval: 500
    onTriggered: {
      if (root.shown && !kbFocus.activeFocus)
        kbFocus.forceActiveFocus()
    }
  }

  MouseArea { anchors.fill: parent; onClicked: SettingsState.close() }

  Rectangle {
    id: card
    width: 700
    height: 424
    anchors.horizontalCenter: parent.horizontalCenter
    color: "transparent"
    Rectangle {
      anchors.fill: parent
      color: Theme.bg
      opacity: root.blurReady ? 0 : 1
    }
    border.color: Theme.outline
    border.width: 1

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 16
          Layout.leftMargin: 14
          Layout.rightMargin: 14
          spacing: 0
          Repeater {
            model: root.tabs
            delegate: Item {
              required property var modelData
              required property int index
              Layout.fillWidth: true
              Layout.preferredHeight: 28
              property bool active: root.activeTab === index
              Text {
                anchors.centerIn: parent
                text: modelData.name
                color: parent.active ? Theme.fg : Theme.muted
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
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 10
          height: 1
          color: Theme.border
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: contentCol.height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: contentCol
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: 12

              ColumnLayout {
                id: tab0col
                visible: root.activeTab === 0
                Layout.fillWidth: true
                spacing: 10
                property real slideX: 0
                property real pageOpacity: 1
                transform: Translate { x: tab0col.slideX }
                opacity: tab0col.pageOpacity
                Behavior on slideX { id: tab0slideBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }
                Behavior on pageOpacity { id: tab0fadeBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }

                Text {
                  text: "APPEARANCE"
                  color: Theme.muted2
                  font.family: root.fontFamily
                  font.pixelSize: 9
                  font.letterSpacing: 2
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 56
                  color: root.selIdx === 0 ? Theme.fg
                       : (root.hoverIdx === 0 ? Theme.bgAlt : "transparent")
                  border.color: root.selIdx === 0 ? Theme.fg
                       : (root.hoverIdx === 0 ? Theme.borderStrong : Theme.border)
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
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Item {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      QIcon {
                        anchors.centerIn: parent
                        name: "wallpaper"
                        size: 22
                        color: root.selIdx === 0 ? Theme.bg : Theme.fg
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 10
                      Layout.bottomMargin: 10
                      spacing: 3
                      Text {
                        text: "Wallpaper"
                        color: root.selIdx === 0 ? Theme.bg : Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                      }
                      Text {
                        text: "Set desktop wallpaper"
                        color: root.selIdx === 0 ? Theme.bgAlt : Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                    }
                    Item {
                      Layout.preferredWidth: 20
                      Layout.preferredHeight: 20
                      QIcon {
                        anchors.centerIn: parent
                        name: "go-next"
                        size: 16
                        color: root.selIdx === 0 ? Theme.bg : Theme.muted
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 56
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
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Item {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      QIcon {
                        anchors.centerIn: parent
                        name: "preferences-desktop-theme"
                        size: 22
                        color: Theme.fg
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 10
                      Layout.bottomMargin: 10
                      spacing: 3
                      Text {
                        text: "Dynamic theme"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                      }
                      Text {
                        text: DynamicTheme.enabled ? "Colored by wallpaper" : "Color shell and kitty from wallpaper"
                        color: Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                    }
                    CToggle {
                      Layout.alignment: Qt.AlignVCenter
                      checked: DynamicTheme.enabled
                      onToggled: v => DynamicTheme.setEnabled(v)
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 56
                  color: root.hoverIdx === -9 ? Theme.bgAlt : "transparent"
                  border.color: root.hoverIdx === -9 ? Theme.borderStrong : Theme.border
                  border.width: 1
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverIdx = -9
                    onExited: { if (root.hoverIdx === -9) root.hoverIdx = -1 }
                    onClicked: TransparencyState.toggle()
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Item {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      QIcon {
                        anchors.centerIn: parent
                        name: "opacity"
                        size: 22
                        color: Theme.fg
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 10
                      Layout.bottomMargin: 10
                      spacing: 3
                      Text {
                        text: "Transparency"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                      }
                      Text {
                        text: TransparencyState.transparent ? "Translucent blurred shell and terminal" : "Opaque shell and terminal (toggle for blur)"
                        color: Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                    }
                    CToggle {
                      Layout.alignment: Qt.AlignVCenter
                      checked: TransparencyState.transparent
                      onToggled: v => TransparencyState.setTransparent(v)
                    }
                  }
                }

              }

              ColumnLayout {
                id: tab1col
                visible: root.activeTab === 1
                Layout.fillWidth: true
                spacing: 8
                property real slideX: 0
                property real pageOpacity: 1
                transform: Translate { x: tab1col.slideX }
                opacity: tab1col.pageOpacity
                Behavior on slideX { id: tab1slideBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }
                Behavior on pageOpacity { id: tab1fadeBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }
                Repeater {
                  model: root.audioModel
                  delegate: audioCardComp
                }
              }

              ColumnLayout {
                id: tab2col
                visible: root.activeTab === 2
                Layout.fillWidth: true
                spacing: 10
                property real slideX: 0
                property real pageOpacity: 1
                transform: Translate { x: tab2col.slideX }
                opacity: tab2col.pageOpacity
                Behavior on slideX { id: tab2slideBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }
                Behavior on pageOpacity { id: tab2fadeBeh; NumberAnimation { duration: 200; easing.type: Theme.easingOut } }

                Text {
                  text: "PROFILE"
                  color: Theme.muted2
                  font.family: root.fontFamily
                  font.pixelSize: 9
                  font.letterSpacing: 2
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 64
                  color: Theme.bgAlt
                  border.color: Theme.border
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    Rectangle {
                      Layout.preferredWidth: 44
                      Layout.preferredHeight: 44
                      radius: 22
                      clip: true
                      color: Theme.bg
                      border.color: Theme.fg
                      border.width: 1
                      Image {
                        anchors.fill: parent
                        source: AvatarState.path !== "" ? "file://" + AvatarState.path.split("/").map(encodeURIComponent).join("/") : ""
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
                        font.pixelSize: 18
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 12
                      Layout.bottomMargin: 12
                      spacing: 2
                      Text {
                        Layout.fillWidth: true
                        text: AvatarState.path !== "" ? AvatarState.path.split("/").pop() : "No profile picture"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                      }
                      Text {
                        text: "Shown on lockscreen"
                        color: Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 10
                      }
                    }
                    Rectangle {
                      Layout.preferredWidth: 64
                      Layout.preferredHeight: 28
                      color: root.hoverIdx === -6 ? Theme.fg : "transparent"
                      border.color: Theme.fg
                      border.width: 1
                      Text {
                        anchors.centerIn: parent
                        text: "Choose"
                        color: root.hoverIdx === -6 ? Theme.bg : Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 11
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
                      Layout.preferredWidth: 56
                      Layout.preferredHeight: 28
                      visible: AvatarState.path !== ""
                      color: root.hoverIdx === -7 ? Theme.fg : "transparent"
                      border.color: Theme.fg
                      border.width: 1
                      Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        color: root.hoverIdx === -7 ? Theme.bg : Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 11
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
                  Layout.preferredHeight: 50
                  color: Theme.bgAlt
                  border.color: Theme.border
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    QIcon { name: "camera-photo"; size: 18; color: Theme.muted }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.topMargin: 8
                      Layout.bottomMargin: 8
                      spacing: 2
                      Text {
                        text: "Avatar file"
                        color: Theme.fg
                        font.family: root.fontFamily
                        font.pixelSize: 12
                      }
                      Text {
                        text: AvatarState.path !== "" ? AvatarState.path : "No file selected"
                        color: Theme.muted2
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                      }
                    }
                  }
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
      Layout.preferredHeight: modelData.header ? 20 : 54
      Rectangle {
        anchors.fill: parent
        visible: !modelData.header
        color: root.selIdx === index ? Theme.fg
             : (root.hoverIdx === index ? Theme.bgAlt : "transparent")
        border.color: root.selIdx === index ? Theme.fg
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
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12
        Item {
          Layout.preferredWidth: 24
          Layout.preferredHeight: 24
          QIcon {
            anchors.centerIn: parent
            name: modelData.type === "source" ? "mic" : "audio-volume-high"
            size: 20
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
          Text {
            Layout.fillWidth: true
            text: modelData.name || ""
            color: root.selIdx === index ? Theme.bgAlt : Theme.muted2
            font.family: root.fontFamily
            font.pixelSize: 9
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