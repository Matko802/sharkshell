import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire

PanelWindow {
  id: ccCard

  property var targetScreen: null
  property string pwFor: ""
  property bool appsExpanded: false

  PwObjectTracker {
    objects: Pipewire.nodes.values.filter(n => n && n.isStream && n.audio && n.isSink)
  }

  anchors.top: true
  anchors.right: true
  margins.top: 30
  margins.right: 8
  implicitWidth: 356
  property int maxCardHeight: Math.max(320, Math.min(640, (ccCard.targetScreen?.height ?? 900) - 80))
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "quickshell-modal"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  property bool shown: false
  screen: ccCard.targetScreen
  visible: ccCard.shown && (!ControlState.screen || ControlState.screen === ccCard.targetScreen)
  implicitHeight: Math.min(col.implicitHeight + 32, maxCardHeight)

  Process { id: focusProc; running: false }
  function focusApp(n) {
    const raw = n ? (n.desktopEntry || n.appName || "") : ""
    if (!raw) return
    const cmd = 'app="' + String(raw).replace(/"/g, '\\"') + '"; id=$(mmsg get all-clients 2>/dev/null | python3 -c "import json,sys; app=sys.argv[1].lower(); data=json.load(sys.stdin); cs=data.get(\'clients\',[]); m=[c for c in cs if app==c.get(\'appid\',\'\').lower() or app in c.get(\'appid\',\'\').lower() or app in c.get(\'title\',\'\').lower()]; print(m[0][\'id\'] if m else \'\')" "$app" 2>/dev/null); [ -n "$id" ] && mmsg dispatch focusid client,$id 2>/dev/null || true'
    focusProc.command = ["bash", "-c", cmd]
    focusProc.running = true
  }

  Connections {
    target: ControlState
    function onOpenChanged() {
      if (ControlState.open && (!ControlState.screen || ControlState.screen === ccCard.targetScreen))
        ccCard.shown = true
      else if (!ControlState.open && ccCard.shown && slideOut.running === false)
        slideOut.restart()
    }
  }

  onShownChanged: {
    if (shown) {
      card.y = -card.height - 8
      slideIn.restart()
    }
  }

  NumberAnimation {
    id: slideIn
    target: card
    property: "y"
    to: 4
    duration: 250
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    id: slideOut
    target: card
    property: "y"
    to: -ccCard.height - 8
    duration: 250
    easing.type: Easing.InCubic
    onFinished: ccCard.shown = false
  }

  function submitPw() {
    if (ccCard.pwFor === "")
      return
    Network.connectTo(ccCard.pwFor, pwInput.text)
    ccCard.pwFor = ""
  }

  Timer {
    running: Network.expanded && Network.wifiEnabled && ccCard.visible
    interval: 15000
    repeat: true
    onTriggered: Network.scan()
  }

  Rectangle {
    id: card
    width: parent.width
    height: parent.height - 4
    color: Theme.bg
    border.color: Theme.outline
    border.width: 1

    MouseArea {
      anchors.fill: parent
    }

    Flickable {
      id: cardFlick
      anchors.fill: parent
      anchors.margins: 14
      contentWidth: cardFlick.width
      contentHeight: col.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      ColumnLayout {
        id: col
        width: cardFlick.width
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Quick Settings"
            color: Theme.fg
            font.pixelSize: 12
            font.letterSpacing: 1
          }
          Item {
            Layout.fillWidth: true
          }
        }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Item {
          Layout.preferredWidth: 20
          Layout.minimumWidth: 20
          Layout.maximumWidth: 20
          Layout.preferredHeight: 20
          QIcon {
            anchors.centerIn: parent
            name: Audio.icon
            size: 20
            color: Theme.fg
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.toggleMute()
          }
        }
        CSlider {
          id: volSlider
          Layout.fillWidth: true
          value: Audio.vol < 0 ? 0 : Audio.vol / 100
          onUserSet: v => Audio.setVol(v * 100)
        }
        Text {
          text: Math.round(volSlider.shown * 100) + "%"
          color: Theme.fg
          font.pixelSize: 11
          Layout.preferredWidth: 40
          Layout.minimumWidth: 40
          Layout.maximumWidth: 40
          horizontalAlignment: Text.AlignRight
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Item {
          Layout.preferredWidth: 20
          Layout.minimumWidth: 20
          Layout.maximumWidth: 20
          Layout.preferredHeight: 20
          QIcon {
            anchors.centerIn: parent
            name: Audio.micIcon
            size: 20
            color: Theme.fg
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.toggleMicMute()
          }
        }
        CSlider {
          id: micSlider
          Layout.fillWidth: true
          value: Audio.micVol < 0 ? 0 : Audio.micVol / 100
          onUserSet: v => Audio.setMicVol(v * 100)
        }
        Text {
          text: Math.round(micSlider.shown * 100) + "%"
          color: Theme.fg
          font.pixelSize: 11
          Layout.preferredWidth: 40
          Layout.minimumWidth: 40
          Layout.maximumWidth: 40
          horizontalAlignment: Text.AlignRight
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          text: "Apps"
          color: Theme.muted
          font.pixelSize: 10
          font.letterSpacing: 1
          Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          implicitWidth: 18
          implicitHeight: 18
          color: appsExpMa.containsMouse || appsExpMa.pressed ? Theme.fg : "transparent"
          QIcon {
            anchors.centerIn: parent
            name: ccCard.appsExpanded ? "pan-up" : "pan-down"
            size: 14
            color: appsExpMa.pressed ? Theme.bg : (appsExpMa.containsMouse ? Theme.bg : Theme.fg)
          }
          MouseArea {
            id: appsExpMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ccCard.appsExpanded = !ccCard.appsExpanded
          }
        }
      }

      Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(appsCol.implicitHeight, 150)
        visible: ccCard.appsExpanded
        contentWidth: width
        contentHeight: appsCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ColumnLayout {
          id: appsCol
          width: parent.width
          spacing: 6
        Repeater {
          model: Pipewire.nodes.values.filter(n => n && n.isStream && n.audio && n.isSink)
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Text {
              Layout.fillWidth: true
              Layout.maximumWidth: 110
              text: {
                const p = modelData.properties || {}
                return (p["application.name"] || modelData.description || modelData.name || "app").toString().slice(0, 22)
              }
              color: Theme.fg
              font.pixelSize: 10
              elide: Text.ElideRight
            }
            Item {
              Layout.preferredWidth: 16
              Layout.preferredHeight: 16
              QIcon {
                anchors.centerIn: parent
                name: modelData.audio && modelData.audio.muted ? "audio-volume-muted" : "audio-volume-high"
                size: 16
                color: Theme.fg
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
              }
            }
            CSlider {
              Layout.fillWidth: true
              value: modelData.audio ? modelData.audio.volume : 0
              onUserSet: v => { if (modelData.audio) modelData.audio.volume = Math.max(0, Math.min(1.5, v)) }
            }
            Text {
              text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "—"
              color: Theme.fg
              font.pixelSize: 10
              Layout.preferredWidth: 32
              horizontalAlignment: Text.AlignRight
            }
          }
        }
        Text {
          Layout.fillWidth: true
          text: Pipewire.nodes.values.filter(n => n && n.isStream && n.audio && n.isSink).length === 0 ? "no apps playing" : ""
          color: "#666666"
          font.pixelSize: 10
          visible: Pipewire.nodes.values.filter(n => n && n.isStream && n.audio && n.isSink).length === 0
          horizontalAlignment: Text.AlignHCenter
        }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Item {
          Layout.preferredWidth: 20
          Layout.minimumWidth: 20
          Layout.maximumWidth: 20
          Layout.preferredHeight: 20
          QIcon {
            anchors.centerIn: parent
            name: Network.online ? Network.icon : "wifi-off"
            size: 20
            color: Network.online ? Theme.fg : "#777777"
          }
        }
        Text {
          text: Network.kind === "wifi" ? Network.ssid : (Network.kind === "eth" ? "Ethernet" : (Network.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"))
          color: Network.online ? Theme.fg : "#777777"
          font.pixelSize: 12
          elide: Text.ElideRight
          Layout.maximumWidth: 220
          Layout.fillWidth: true
        }
        Item {
          Layout.fillWidth: true
        }
        CToggle {
          checked: Network.wifiEnabled
          onToggled: c => Network.toggleWifi()
        }
        Rectangle {
          implicitWidth: 18
          implicitHeight: 18
          color: expMa.containsMouse || expMa.pressed ? Theme.fg : "transparent"
          QIcon {
            anchors.centerIn: parent
            name: Network.expanded ? "pan-up" : "pan-down"
            size: 14
            color: expMa.pressed ? Theme.bg : (expMa.containsMouse ? Theme.bg : Theme.fg)
          }
          MouseArea {
            id: expMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Network.expanded = !Network.expanded
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: Network.expanded && Network.wifiEnabled
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Networks"
            color: Theme.muted
            font.pixelSize: 10
            font.letterSpacing: 1
          }
          Text {
            text: Network.connecting !== "" ? "connecting to " + Network.connecting + "…" : (Network.scanning ? "scanning…" : "")
            color: Theme.muted
            font.pixelSize: 10
            Layout.leftMargin: 6
            Layout.fillWidth: text !== ""
            Layout.maximumWidth: 150
            elide: Text.ElideRight
          }
          Item {
            Layout.fillWidth: true
          }
          Text {
            text: Network.lastError
            color: "#ff7777"
            font.pixelSize: 10
            visible: Network.lastError !== ""
            Layout.maximumWidth: 120
            elide: Text.ElideRight
          }
          Rectangle {
            implicitWidth: 18
            implicitHeight: 18
            color: rescanMa.containsMouse || rescanMa.pressed ? Theme.fg : "transparent"
            border.color: Theme.fg
            border.width: 1
            QIcon {
              anchors.centerIn: parent
              name: "refresh"
              size: 14
              color: rescanMa.pressed ? Theme.bg : Theme.fg
            }
            MouseArea {
              id: rescanMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Network.scan()
            }
          }
        }

        ColumnLayout {
          visible: ccCard.pwFor !== ""
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: "password for " + ccCard.pwFor
            color: Theme.fg
            font.pixelSize: 10
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 22
            color: Theme.bg
            border.color: Theme.fg
            border.width: 1
            TextInput {
              id: pwInput
              anchors.fill: parent
              anchors.margins: 4
              echoMode: TextInput.Password
              color: Theme.fg
              font.pixelSize: 11
              clip: true
              onVisibleChanged: {
                if (visible)
                  forceActiveFocus()
              }
              Keys.onReturnPressed: ccCard.submitPw()
              Keys.onEnterPressed: ccCard.submitPw()
              Keys.onEscapePressed: {
                ccCard.pwFor = ""
                text = ""
              }
            }
          }
          RowLayout {
            spacing: 6
            layoutDirection: Qt.RightToLeft
            Rectangle {
              implicitWidth: 54
              implicitHeight: 20
              color: pwOkMa.pressed ? Theme.fg : Theme.bg
              border.color: Theme.fg
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: "connect"
                color: pwOkMa.pressed ? Theme.bg : Theme.fg
                font.pixelSize: 9
              }
              MouseArea {
                id: pwOkMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ccCard.submitPw()
              }
            }
            Rectangle {
              implicitWidth: 48
              implicitHeight: 20
              color: pwNoMa.pressed ? Theme.fg : Theme.bg
              border.color: Theme.fg
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: "cancel"
                color: pwNoMa.pressed ? Theme.bg : Theme.fg
                font.pixelSize: 9
              }
              MouseArea {
                id: pwNoMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  ccCard.pwFor = ""
                  pwInput.text = ""
                }
              }
            }
          }
        }

        Flickable {
          id: netFlick
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(netCol.height, 170)
          clip: true
          contentWidth: netFlick.width
          contentHeight: netCol.height
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          ColumnLayout {
            id: netCol
            width: netFlick.width
            spacing: 3
            Repeater {
              model: Network.networks
              delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8
                height: 20
                Item {
                  Layout.preferredWidth: 13
                  Layout.preferredHeight: 13
                  QIcon {
                    anchors.centerIn: parent
                    name: Network.sigIcon(modelData.sig)
                    size: 13
                    color: modelData.active ? Theme.fg : "#aaaaaa"
                  }
                }
                Text {
                  text: modelData.ssid
                  color: modelData.active ? Theme.fg : "#cccccc"
                  font.pixelSize: 11
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Item {
                  Layout.preferredWidth: 12
                  Layout.preferredHeight: 12
                  visible: modelData.active || modelData.secure
                  QIcon {
                    anchors.centerIn: parent
                    name: modelData.active ? "check" : (modelData.secure ? "wifi-lock" : "")
                    size: 12
                    color: modelData.active ? Theme.fg : "#777777"
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (Network.connecting !== "" || modelData.active)
                      return
                    if (modelData.secure) {
                      ccCard.pwFor = modelData.ssid
                      pwInput.text = ""
                    } else {
                      Network.connectTo(modelData.ssid, "")
                    }
                  }
                }
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Item {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          QIcon {
            anchors.centerIn: parent
            name: "lock"
            size: 20
            color: Theme.fg
          }
          MouseArea {
            id: lockMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              ControlState.close()
              LockState.locked = true
            }
          }
        }
        Item { Layout.fillWidth: true }
        }
      }
      }
    }
  }
