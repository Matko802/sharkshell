import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
  id: root
  property int notifId: -1
  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property int urgency: 1
  property string image: ""
  property string desktopEntry: ""
  property string appName: ""
  property string fontFamily: Theme.fontFamily
  property var actions: []

  signal closeRequested()
  signal cardClicked()
  signal actionClicked(string actId)
  signal dismissed()

  readonly property string iconSource: {
    const ic = root.appIcon || ""
    if (ic !== "") return Quickshell.iconPath(ic, "dialog-information")
    const de = root.desktopEntry || ""
    if (de !== "") {
      const e = DesktopEntries.heuristicLookup(de)
      if (e && e.icon) return Quickshell.iconPath(e.icon, "dialog-information")
      return Quickshell.iconPath(de, "dialog-information")
    }
    return Quickshell.iconPath("dialog-information", "dialog-information")
  }

  color: Theme.surfaceContainerBg
  radius: Theme.radiusL
  clip: true
  border.color: root.urgency === 2 ? Theme.error : "transparent"
  border.width: root.urgency === 2 ? 2 : 0
  implicitWidth: 340
  implicitHeight: col.implicitHeight + Theme.paddingS * 2 + 4

  property bool entered: false
  property bool dismissing: false
  property real dragOff: 0

  Timer { id: enterTimer; interval: 16; running: true; repeat: false; onTriggered: root.entered = true }

  readonly property bool slidingOut: !entered || dismissing
  x: (slidingOut ? 360 : 0) + dragOff
  Behavior on x { NumberAnimation { duration: root.slidingOut ? 150 : 220; easing.type: root.slidingOut ? Easing.InCubic : Easing.OutCubic } }

  readonly property real dragFade: 1 - Math.min(0.8, Math.abs(root.dragOff) / root.width)
  opacity: root.dismissing ? 0 : (root.entered ? root.dragFade : 0)
  Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

  onDismissingChanged: if (root.dismissing) dismissTimer.start()
  Timer { id: dismissTimer; interval: 200; repeat: false; onTriggered: root.dismissed() }

  function dismiss() { root.dragOff = 0; root.dismissing = true }
  readonly property bool hovered: ma.containsMouse

  property real pressX: 0
  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: mouse => { root.pressX = mouse.x; root.dragOff = 0 }
    onPositionChanged: mouse => {
      if (pressed) {
        const dx = mouse.x - root.pressX
        root.dragOff = Math.max(-width, Math.min(width, dx))
      }
    }
    onReleased: {
      if (Math.abs(root.dragOff) > width * 0.3) root.closeRequested()
      else root.dragOff = 0
    }
    onClicked: mouse => {
      if (closeMa.containsMouse) return
      if (Math.abs(root.dragOff) > 10) return
      if (mouse.button === Qt.RightButton) root.closeRequested()
      else root.cardClicked()
    }
  }

  Rectangle {
    id: urgentBar
    anchors.left: parent.left
    anchors.leftMargin: root.urgency === 2 ? 0 : root.border.width
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.urgency === 2 ? 3 : 0
    color: Theme.error
    visible: root.urgency === 2
  }

  Column {
    id: col
    spacing: 6
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: 10
      rightMargin: 10
      topMargin: Theme.paddingS + 2
    }

    RowLayout {
      width: parent.width
      spacing: 10

      Item {
        id: iconBox
        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        Layout.alignment: Qt.AlignTop
        visible: {
          const im = root.image ? String(root.image) : ""
          return im !== "" || root.appIcon !== "" || root.desktopEntry !== ""
        }

        IconImage {
          id: iconImg
          anchors.fill: parent
          anchors.margins: 5
          visible: {
            const im = root.image ? String(root.image) : ""
            return !(im !== "" && (im.startsWith("/") || im.startsWith("file://") || im.startsWith("image://")))
          }
          source: root.iconSource
          implicitSize: 24
          onStatusChanged: if (status === Image.Error) console.log("[toast] icon failed:", root.iconSource, "appIcon:", root.appIcon, "entry:", root.desktopEntry)
        }

        Image {
          anchors.fill: parent
          anchors.margins: 5
          visible: {
            const im = root.image ? String(root.image) : ""
            return im !== "" && (im.startsWith("/") || im.startsWith("file://") || im.startsWith("image://"))
          }
          source: root.image ? String(root.image) : ""
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 3

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            Layout.fillWidth: true
            text: root.app.toUpperCase()
            color: Theme.muted
            font.pixelSize: 9
            font.letterSpacing: 1.5
            elide: Text.ElideRight
          }
          Text {
            visible: root.urgency === 2
            text: "!"
            color: Theme.error
            font.pixelSize: 10
            font.bold: true
          }
          Rectangle {
            implicitWidth: 20
            implicitHeight: 20
            radius: Theme.radiusFull
            color: closeMa.containsMouse || closeMa.pressed ? Theme.primaryContainer : "transparent"
            Text {
              anchors.centerIn: parent
              text: "✕"
              color: closeMa.pressed || closeMa.containsMouse ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
              font.pixelSize: 10
            }
            MouseArea {
              id: closeMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.summary
          color: Theme.onSurface
          font.pixelSize: 12
          font.bold: true
          wrapMode: Text.WordWrap
          visible: root.summary.length > 0
        }

        Text {
          Layout.fillWidth: true
          text: root.body
          color: Theme.onSurfaceVariant
          font.pixelSize: 10
          wrapMode: Text.WordWrap
          maximumLineCount: 5
          elide: Text.ElideRight
          visible: root.body.length > 0
        }
      }
    }

    Row {
      id: actionRow
      spacing: 6
      visible: root.actions.length > 0

      Repeater {
        model: root.actions.slice(0, 3)

        delegate: Rectangle {
          required property var modelData
          implicitWidth: Math.min(150, actMetrics.implicitWidth + 20)
          implicitHeight: 22
          radius: Theme.radiusFull
          color: actMa.containsMouse ? Theme.primaryContainer : Theme.secondaryContainer

          TextMetrics {
            id: actMetrics
            font.pixelSize: 9
            text: modelData.text
          }

          Text {
            id: actText
            anchors.centerIn: parent
            width: Math.min(130, actMetrics.implicitWidth)
            text: modelData.text
            color: actMa.containsMouse ? Theme.onPrimaryContainer : Theme.onSecondaryContainer
            font.pixelSize: 9
            elide: Text.ElideRight
          }
          MouseArea {
            id: actMa
            width: parent.width
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionClicked(modelData.id)
          }
        }
      }
    }
  }
}
