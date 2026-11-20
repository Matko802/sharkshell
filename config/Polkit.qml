import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

Scope {
  id: root

  readonly property var flow: agent.flow

  PolkitAgent {
    id: agent
  }

  function submit() {
    if (!root.flow || !root.flow.isResponseRequired)
      return
    root.flow.submit(password.text)
    password.text = ""
  }

  function cancel() {
    if (root.flow)
      root.flow.cancelAuthenticationRequest()
  }

  function focusPassword() {
    password.text = ""
    if (!root.flow || !root.flow.isResponseRequired)
      return
    Qt.callLater(function() {
      if (dialogWindow.visible && root.flow && root.flow.isResponseRequired)
        password.forceActiveFocus()
    })
  }

  Connections {
    target: agent
    function onFlowChanged() {
      root.focusPassword()
    }
  }

  Connections {
    target: root.flow
    function onIsResponseRequiredChanged() {
      if (root.flow && root.flow.isResponseRequired)
        root.focusPassword()
    }
    function onSelectedIdentityChanged() {
      root.focusPassword()
    }
    function onAuthenticationFailed() {
      root.focusPassword()
    }
  }

  PanelWindow {
    id: dialogWindow

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-polkit"
    BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent && dialogWindow.visible ? card : null }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: root.flow !== null && !LockState.locked

    onVisibleChanged: {
      if (visible)
        root.focusPassword()
    }

    MouseArea {
      anchors.fill: parent
    }

    Rectangle {
      id: card

      anchors.centerIn: parent
      width: 380
      height: column.implicitHeight + 32
      color: Theme.bg
      border.color: Theme.outline
      border.width: 1
      focus: true

      Keys.onEscapePressed: root.cancel()

      MouseArea {
        anchors.fill: parent
      }

      ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter

            QIcon {
              anchors.centerIn: parent
              name: "lock"
              size: 22
              color: Theme.fg
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Authentication Required"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 1
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.flow?.message ?? ""
          color: Theme.fg
          font.family: Theme.fontFamily
          font.pixelSize: 12
          wrapMode: Text.Wrap
        }

        Text {
          Layout.fillWidth: true
          visible: text.length > 0
          text: root.flow?.supplementaryMessage ?? ""
          color: (root.flow?.supplementaryIsError ?? false) ? Theme.error : Theme.muted
          font.family: Theme.fontFamily
          font.pixelSize: 11
          wrapMode: Text.Wrap
        }

        RowLayout {
          Layout.fillWidth: true
          visible: (root.flow?.identities.length ?? 0) > 1
          spacing: 6

          Repeater {
            model: root.flow ? root.flow.identities : []

            delegate: Rectangle {
              id: identityButton

              required property var modelData

              implicitWidth: identityLabel.implicitWidth + 16
              implicitHeight: 24
              color: root.flow && root.flow.selectedIdentity === identityButton.modelData ? Theme.outline : "transparent"
              border.color: Theme.outline
              border.width: 1

              Text {
                id: identityLabel
                anchors.centerIn: parent
                text: identityButton.modelData.displayName
                color: root.flow && root.flow.selectedIdentity === identityButton.modelData ? Theme.bg : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 11
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.flow)
                    root.flow.selectedIdentity = identityButton.modelData
                }
              }
            }
          }
        }

        Rectangle {
          id: passwordBox

          Layout.fillWidth: true
          Layout.preferredHeight: 32
          visible: root.flow?.isResponseRequired ?? false
          color: "transparent"
          border.color: password.activeFocus ? Theme.fg : Theme.outline
          border.width: 1

          TextInput {
            id: password

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 13
            echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
            selectionColor: Theme.outline
            selectedTextColor: Theme.bg
            clip: true

            onAccepted: root.submit()

            Keys.onEscapePressed: root.cancel()
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: password.text.length === 0
            text: root.flow?.inputPrompt ?? ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: 82
            implicitHeight: 30
            color: cancelArea.containsMouse ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "Cancel"
              color: cancelArea.containsMouse ? Theme.bg : Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }

            MouseArea {
              id: cancelArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cancel()
            }
          }

          Rectangle {
            implicitWidth: 102
            implicitHeight: 30
            enabled: root.flow?.isResponseRequired ?? false
            color: submitArea.containsMouse && enabled ? Theme.fg : "transparent"
            border.color: Theme.outline
            border.width: 1
            opacity: enabled ? 1 : 0.4

            Text {
              anchors.centerIn: parent
              text: "Authenticate"
              color: submitArea.containsMouse && parent.enabled ? Theme.bg : Theme.fg
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }

            MouseArea {
              id: submitArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.submit()
            }
          }
        }
      }
    }
  }
}
