import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

ColumnLayout {
  id: root

  property string pwFor: ""
  property bool appsExpanded: false
  property bool active: true
  onActiveChanged: {
    if (active) {
      Network.expanded = false
      root.appsExpanded = false
    }
  }

  signal activity()

  readonly property var sinkInputs: !root.active ? [] : (Pipewire.nodes.values || []).filter(n => n && n.isStream && n.audio && n.isSink)

  PwObjectTracker {
    objects: root.active ? root.sinkInputs : []
  }

  function submitPw() {
    if (root.pwFor === "")
      return
    Network.connectTo(root.pwFor, pwInput.text)
    root.pwFor = ""
  }

  Timer {
    running: Network.wifiEnabled && root.active
    interval: 15000
    repeat: true
    triggeredOnStart: true
    onTriggered: Network.scan()
  }

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
    visible: BrightnessState.available
    Layout.fillWidth: true
    spacing: 10
    Item {
      Layout.preferredWidth: 20
      Layout.minimumWidth: 20
      Layout.maximumWidth: 20
      Layout.preferredHeight: 20
      QIcon {
        anchors.centerIn: parent
        name: BrightnessState.bright < 0.25 ? "brightness-low" : "brightness"
        size: 20
        color: Theme.fg
      }
    }
    CSlider {
      id: brightSlider
      Layout.fillWidth: true
      value: BrightnessState.bright < 0 ? 0 : BrightnessState.bright
      onUserSet: v => BrightnessState.set(v)
    }
    Text {
      text: BrightnessState.bright < 0 ? "" : Math.round(brightSlider.shown * 100) + "%"
      color: Theme.fg
      font.pixelSize: 11
      Layout.preferredWidth: 40
      Layout.minimumWidth: 40
      Layout.maximumWidth: 40
      horizontalAlignment: Text.AlignRight
    }
  }

  RowLayout {
    visible: root.sinkInputs.length > 0
    Layout.fillWidth: true
    spacing: 8
    Item { Layout.fillWidth: true }
    IconBtn {
      implicitWidth: 18
      implicitHeight: 18
      icon: root.appsExpanded ? "pan-up" : "pan-down"
      iconSize: 14
      onClicked: root.appsExpanded = !root.appsExpanded
    }
  }

  Flickable {
    id: appsFlick
    Layout.fillWidth: true
    Layout.preferredHeight: root.appsExpanded ? Math.min(appsCol.implicitHeight, 150) : 0
    visible: root.appsExpanded || height > 0.5
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
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
        model: root.sinkInputs
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
            text: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
            color: Theme.fg
            font.pixelSize: 10
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }
  }

  Item {
    Layout.fillWidth: true
    implicitHeight: netRow.implicitHeight
    MouseArea {
      anchors.fill: parent
      enabled: Network.mode === "wifi"
      onClicked: {
        if (!Network.wifiEnabled)
          Network.selectMode("wifi")
        else
          Network.expanded = !Network.expanded
      }
    }
    RowLayout {
      id: netRow
      anchors.fill: parent
      spacing: 10
      Item {
        Layout.preferredWidth: 20
        Layout.minimumWidth: 20
        Layout.maximumWidth: 20
        Layout.preferredHeight: 20
        QIcon {
          anchors.centerIn: parent
          name: Network.online ? Network.icon : (Network.mode === "eth" ? "network-wired" : "wifi-off")
          size: 20
          color: Network.online ? Theme.fg : Theme.muted2
        }
      }
      Text {
        text: Network.kind === "wifi" ? Network.ssid : (Network.mode === "eth" ? "Ethernet" : (Network.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off"))
        color: Network.online ? Theme.fg : Theme.muted2
        font.pixelSize: 12
        elide: Text.ElideRight
        Layout.maximumWidth: 220
        Layout.fillWidth: true
      }
      Item {
        Layout.fillWidth: true
      }
      Rectangle {
        id: netModeSlider
        visible: Network.hasEthernet
        implicitWidth: 46
        implicitHeight: 18
        color: "transparent"
        border.color: Theme.outline
        border.width: 1
        Rectangle {
          id: netModeKnob
          width: 22
          height: parent.height - 4
          y: 2
          x: Network.mode === "eth" ? 2 : parent.width - width - 2
          color: Theme.fg
          Behavior on x {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut }
          }
        }
        QIcon {
          anchors.horizontalCenter: parent.left
          anchors.horizontalCenterOffset: 13
          anchors.verticalCenter: parent.verticalCenter
          name: "network-wired"
          size: 12
          color: Network.mode === "eth" ? Theme.bg : Theme.muted2
        }
        QIcon {
          anchors.horizontalCenter: parent.right
          anchors.horizontalCenterOffset: -13
          anchors.verticalCenter: parent.verticalCenter
          name: Network.wifiEnabled ? Network.sigIcon(Network.sig) : "wifi-off"
          size: 12
          color: Network.mode === "wifi" ? Theme.bg : Theme.muted2
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            Network.selectMode(mouse.x < parent.width / 2 ? "eth" : "wifi")
          }
        }
      }
      IconBtn {
        implicitWidth: 18
        implicitHeight: 18
        icon: Network.expanded ? "pan-up" : "pan-down"
        iconSize: 14
        visible: Network.wifiEnabled && Network.networks.length > 0
        onClicked: Network.expanded = !Network.expanded
      }
    }
  }

  Timer {
    id: connAnim
    running: Network.connecting !== ""
    interval: 250
    repeat: true
    property int step: 0
    onRunningChanged: if (running) step = 0
    onTriggered: step = (step + 1) % 5
  }

  ColumnLayout {
    id: netExpCol
    Layout.fillWidth: true
    visible: opacity > 0.01
    opacity: (Network.expanded && Network.mode === "wifi") ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "Networks"
        color: Theme.muted2
        font.pixelSize: 10
        font.letterSpacing: 1
      }
      Text {
        text: Network.connecting !== "" ? "connecting to " + Network.connecting : (Network.scanning ? "scanning" : "")
        color: Theme.muted2
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
        color: Theme.error
        font.pixelSize: 10
        visible: Network.lastError !== ""
        Layout.maximumWidth: 120
        elide: Text.ElideRight
      }
      IconBtn {
        implicitWidth: 18
        implicitHeight: 18
        icon: "refresh"
        iconSize: 14
        onClicked: Network.scan()
      }
    }

    ColumnLayout {
      visible: root.pwFor !== ""
      Layout.fillWidth: true
      spacing: 4
      Text {
        text: "password for " + root.pwFor
        color: Theme.fg
        font.pixelSize: 10
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 22
        color: Theme.bgAlt
        border.color: Theme.outline
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
          onTextChanged: root.activity()
          Keys.onPressed: root.activity()
          Keys.onReturnPressed: root.submitPw()
          Keys.onEnterPressed: root.submitPw()
          Keys.onEscapePressed: {
            root.pwFor = ""
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
          border.color: Theme.outline
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
            onClicked: root.submitPw()
          }
        }
        Rectangle {
          implicitWidth: 48
          implicitHeight: 20
          color: pwNoMa.pressed ? Theme.fg : Theme.bg
          border.color: Theme.outline
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
              root.pwFor = ""
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
      Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easingOut } }
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
          delegate: Item {
            required property var modelData
            readonly property bool isActive: modelData.active || modelData.ssid === Network.activeSsid
            readonly property bool isConnecting: Network.connecting === modelData.ssid
            readonly property bool needsPw: modelData.secure && (Network.knownSsids.indexOf(modelData.ssid) < 0 || modelData.ssid === Network.failedSsid)
            Layout.fillWidth: true
            implicitHeight: 20
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (Network.connecting !== "" || isActive)
                  return
                if (needsPw) {
                  root.pwFor = modelData.ssid
                  pwInput.text = ""
                } else {
                  Network.connectTo(modelData.ssid, "")
                }
              }
            }
            RowLayout {
              anchors.fill: parent
              spacing: 8
              Item {
                Layout.preferredWidth: 13
                Layout.preferredHeight: 13
                QIcon {
                  anchors.centerIn: parent
                  name: isConnecting ? Network.sigIcon(connAnim.step * 25) : Network.sigIcon(modelData.sig)
                  size: 13
                  color: (isActive || isConnecting) ? Theme.fg : Theme.muted2
                }
              }
              Text {
                text: modelData.ssid
                color: (isActive || isConnecting) ? Theme.fg : Theme.muted2
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Item {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                visible: isActive || needsPw
                QIcon {
                  anchors.centerIn: parent
                  name: isActive ? "check" : (needsPw ? "wifi-lock" : "")
                  size: 12
                  color: isActive ? Theme.fg : Theme.muted2
                }
              }
              IconBtn {
                implicitWidth: 16
                implicitHeight: 16
                icon: "trash"
                iconSize: 12
                visible: Network.knownSsids.indexOf(modelData.ssid) >= 0
                onClicked: Network.forget(modelData.ssid)
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
        name: "shutdown"
        size: 20
        color: Theme.fg
      }
      MouseArea {
        id: powerMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          ControlState.close()
          Quickshell.execDetached(["quickshell", "ipc", "call", "power", "toggle"])
        }
      }
    }
    Item { Layout.fillWidth: true }
  }
}
