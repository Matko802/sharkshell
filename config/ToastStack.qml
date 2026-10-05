import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQml.Models

Scope {
  id: toastScope

  property var popupWindows: []

  function syncWindows() {
    var a = []
    for (var i = 0; i < inst.count; i++) {
      var o = inst.objectAt(i)
      if (o) a.push(o)
    }
    toastScope.popupWindows = a
    toastScope.scheduleReposition()
  }

  function scheduleReposition() {
    repositionTimer.restart()
  }

  Timer {
    id: repositionTimer
    interval: 32
    repeat: false
    onTriggered: toastScope.repositionAll()
  }

  function repositionAll() {
    var y = 38
    for (var i = 0; i < toastScope.popupWindows.length; i++) {
      var w = toastScope.popupWindows[i]
      if (!w || !w.setStackPosition) continue
      w.setStackPosition(y)
      var h = w.cardHeight || 0
      y += (h > 0 ? h : 80) + 8
    }
  }

  function dismissAllPopups() {
    for (var i = 0; i < inst.count; i++) {
      var o = inst.objectAt(i)
      if (o && o.dismissCard) o.dismissCard()
    }
  }

  Connections {
    target: ControlState
    function onOpenChanged() {
      if (ControlState.open) NotificationServer.hideAllPopups()
    }
  }
  Connections {
    target: ClockState
    function onOpenChanged() {
      if (ClockState.open) NotificationServer.hideAllPopups()
    }
  }
  Connections {
    target: SettingsState
    function onOpenChanged() {
      if (SettingsState.open) NotificationServer.hideAllPopups()
    }
  }

  Instantiator {
    id: inst
    model: NotificationServer.popupModel
    onObjectAdded: (index, obj) => toastScope.syncWindows()
    onObjectRemoved: (index, obj) => toastScope.syncWindows()

    delegate: PanelWindow {
      id: toastWin
      required property int notifId
      required property string app
      required property string appIcon
      required property string summary
      required property string body
      required property int urgency
      required property string image
      required property string desktopEntry
      required property string appName
      required property bool leaving
      onLeavingChanged: { if (leaving) toastWin.dismissCard() }

      anchors.top: true
      anchors.right: true
      anchors.bottom: true
      margins.top: 0
      margins.right: 8
      margins.bottom: 0
      property int cardY: 38
      property int lastCardY: 0
      property real yOff: 0
      onCardYChanged: {
        if (lastCardY > 0 && cardY !== lastCardY) {
          yOff = yOff + (lastCardY - cardY)
          yGlide.restart()
        }
        lastCardY = cardY
      }
      function setStackPosition(y) { toastWin.cardY = y }
      NumberAnimation { id: yGlide; target: toastWin; property: "yOff"; to: 0; duration: 200; easing.type: Easing.OutCubic }
      implicitWidth: card.implicitWidth
      implicitHeight: card.implicitHeight
      color: "transparent"
      WlrLayershell.namespace: "quickshell-modal"
      BackgroundEffect.blurRegion: Region { item: TransparencyState.transparent && toastWin.blurReady ? card : null }
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      visible: NotificationServer.popupModel.count > 0 && !ControlState.open && !ClockState.open && !SettingsState.open

      mask: Region { item: card }

      readonly property bool blurReady: card.entered && !card.dismissing && Math.abs(card.x) < 1
      readonly property int cardHeight: card.implicitHeight
      onCardHeightChanged: toastScope.scheduleReposition()

      property double lifetime: 5000
      property double deadline: 0
      property bool paused: false
      property double pauseTime: 0

      Component.onCompleted: {
        toastWin.deadline = Date.now() + toastWin.lifetime
        toastWin.lastCardY = toastWin.cardY
      }
      function pause() {
        if (!toastWin.paused) {
          toastWin.paused = true
          toastWin.pauseTime = Date.now()
        }
      }
      function resume() {
        if (toastWin.paused) {
          toastWin.paused = false
          toastWin.deadline += Date.now() - toastWin.pauseTime
        }
      }
      function dismissCard() { if (!card.dismissing) card.dismiss() }

      NotificationPopup {
        id: card
        y: toastWin.cardY + toastWin.yOff
        width: parent.width
        height: implicitHeight
        notifId: toastWin.notifId
        app: toastWin.app
        appIcon: toastWin.appIcon
        summary: toastWin.summary
        body: toastWin.body
        urgency: toastWin.urgency
        image: toastWin.image
        desktopEntry: toastWin.desktopEntry
        appName: toastWin.appName
        onHoveredChanged: {
          if (card.hovered) toastWin.pause()
          else toastWin.resume()
        }
        onDismissed: NotificationServer.removePopup(toastWin.notifId)
        onCloseRequested: toastWin.dismissCard()
        onCardClicked: NotificationServer.focusPopup(toastWin.notifId)
      }

      Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
          if (toastWin.paused) return
          if (Date.now() >= toastWin.deadline) toastWin.dismissCard()
        }
      }
    }
  }
}
