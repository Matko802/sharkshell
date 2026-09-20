import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Util.js" as Util

Scope {
  id: root

  property string displayUser: Quickshell.env("USER") || ""
  property bool blurEnabled: true

  IpcHandler {
    target: "lock"
    function lock() { LockState.locked = true }
    function toggleBlur() { root.blurEnabled = !root.blurEnabled }
    function setBlur(v: bool) { root.blurEnabled = v }
  }

  LockContext {
    id: lockContext

    onUnlocked: {
      LockState.locked = false;
    }
  }

  WlSessionLock {
    id: lock
    locked: LockState.locked

      surface: Component {
      WlSessionLockSurface {
        id: surf
        color: Theme.lockBg

        property bool graceActive: false
        property bool uiVisible: true
        property string lockWallpaper: WallpaperState.effectiveLockPath
        property bool menuOpen: false
        readonly property bool contentShown: surf.uiVisible && !surf.graceActive

        function layoutLockImage(img) {
          if (lockBg.width <= 0 || lockBg.height <= 0)
            return
          if (!img || img.status !== Image.Ready) {
            if (img) {
              img.x = 0
              img.y = 0
              img.width = lockBg.width
              img.height = lockBg.height
            }
            return
          }
          var iw = img.implicitWidth
          var ih = img.implicitHeight
          if (iw <= 0 || ih <= 0)
            return
          var scale = Math.max(lockBg.width / iw, lockBg.height / ih)
          var dw = iw * scale
          var dh = ih * scale
          var px = Util.clamp01(WallpaperState.lockPositionX)
          var py = Util.clamp01(WallpaperState.lockPositionY)
          img.width = dw
          img.height = dh
          img.x = (lockBg.width - dw) * px
          img.y = (lockBg.height - dh) * py
        }

        function layoutAllLock() {
          surf.layoutLockImage(lockImgA)
          surf.layoutLockImage(lockImgB)
        }

        function showLock(path) {
          if (!path || path === "")
            return
          const back = lockBg.frontIsA ? lockImgB : lockImgA
          const front = lockBg.frontIsA ? lockImgA : lockImgB
          if (String(front.source) === Util.fileUrl(path))
            return
          back.source = Util.fileUrl(path)
          lockBg.pending = back
          if (back.status === Image.Ready) {
            surf.layoutLockImage(back)
            lockBg.pending = null
            lockBg.frontIsA = back === lockImgA
            lockImgA.opacity = back === lockImgA ? 1 : 0
            lockImgB.opacity = back === lockImgB ? 1 : 0
          }
        }

        function wake() {
          if (surf.graceActive)
            return
          surf.uiVisible = true
          idleTimer.restart()
          passwordBox.forceActiveFocus()
        }

        function goIdle() {
          if (surf.graceActive)
            return
          surf.uiVisible = false
          surf.menuOpen = false
        }

        function openMenu(section) {
          if (surf.graceActive)
            return
          if (surf.menuOpen) {
            surf.menuOpen = false
          } else {
            surf.menuOpen = true
            surf.uiVisible = true
            idleTimer.restart()
            Network.expanded = true
            Network.scan()
          }
        }

        Connections {
          target: WallpaperState
          function onEffectiveLockPathChanged() {
            surf.showLock(WallpaperState.effectiveLockPath)
          }
          function onLockPositionXChanged() { surf.layoutAllLock() }
          function onLockPositionYChanged() { surf.layoutAllLock() }
          function onPathChanged() {
            if (WallpaperState.lockPath === "")
              surf.showLock(WallpaperState.path)
          }
        }

        Item {
          id: lockBg
          anchors.fill: parent
          clip: true

          property bool frontIsA: true
          property var pending: null

          layer.enabled: root.blurEnabled
          layer.smooth: true
          layer.textureSize: Qt.size(Math.max(1, Math.round(lockBg.width / 2)), Math.max(1, Math.round(lockBg.height / 2)))
          layer.effect: GaussianBlur {
            radius: surf.contentShown ? BlurState.radius : 0
            cached: true
            Behavior on radius { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
          }

          onWidthChanged: surf.layoutAllLock()
          onHeightChanged: surf.layoutAllLock()
          Component.onCompleted: surf.showLock(WallpaperState.effectiveLockPath)

          Image {
            id: lockImgA
            fillMode: Image.Stretch
            asynchronous: true
            cache: false
            sourceSize: Qt.size(3840, 2160)
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            onStatusChanged: {
              if (status === Image.Ready) {
                surf.layoutLockImage(lockImgA)
                if (lockBg.pending === lockImgA) {
                  lockBg.pending = null
                  lockBg.frontIsA = true
                  lockImgA.opacity = 1
                  lockImgB.opacity = 0
                }
              } else if (status === Image.Error && lockBg.pending === lockImgA) {
                lockBg.pending = null
              }
            }
            onImplicitWidthChanged: surf.layoutLockImage(lockImgA)
            onImplicitHeightChanged: surf.layoutLockImage(lockImgA)
          }

          Image {
            id: lockImgB
            fillMode: Image.Stretch
            asynchronous: true
            cache: false
            sourceSize: Qt.size(3840, 2160)
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            onStatusChanged: {
              if (status === Image.Ready) {
                surf.layoutLockImage(lockImgB)
                if (lockBg.pending === lockImgB) {
                  lockBg.pending = null
                  lockBg.frontIsA = false
                  lockImgB.opacity = 1
                  lockImgA.opacity = 0
                }
              } else if (status === Image.Error && lockBg.pending === lockImgB) {
                lockBg.pending = null
              }
            }
            onImplicitWidthChanged: surf.layoutLockImage(lockImgB)
            onImplicitHeightChanged: surf.layoutLockImage(lockImgB)
          }
        }

        Rectangle {
          anchors.fill: parent
          color: "black"
          opacity: surf.lockWallpaper !== "" ? 0.25 : 0
          visible: opacity > 0.01
        }

        ShaderEffect {
          anchors.fill: parent
          visible: surf.lockWallpaper !== ""
          opacity: 0.04
          fragmentShader: "varying highp vec2 qt_TexCoord0; float hash(highp vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); } void main() { float g = hash(qt_TexCoord0 * vec2(1920.0, 1080.0)); gl_FragColor = vec4(vec3(g), 1.0); }"
        }

        Rectangle {
          id: loginCard
          anchors.centerIn: parent
          width: 340
          height: content.height + 48
          color: root.blurEnabled ? "transparent" : Theme.bg
          opacity: surf.contentShown ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }

        ColumnLayout {
          id: content
          anchors.centerIn: parent
          spacing: 8

          ColumnLayout {
            id: topBlock
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: surf.contentShown ? implicitHeight : 0
            spacing: 8
            clip: true
            opacity: surf.contentShown ? 1 : 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              visible: AvatarState.path !== ""
              Layout.preferredWidth: 96
              Layout.preferredHeight: 96
              radius: 48
              clip: true
              color: Theme.bgAlt
              border.color: Theme.fg
              border.width: 2
              Image {
                anchors.fill: parent
                source: AvatarState.path !== "" ? Util.fileUrl(AvatarState.path) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
              }
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              visible: root.displayUser !== ""
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: root.displayUser
              color: Theme.muted
              font.pixelSize: 14
              font.family: Theme.fontFamily
            }
          }

          Text {
            id: clock
            property var date: new Date()
            Layout.alignment: Qt.AlignHCenter

            color: Theme.fg
            renderType: Text.NativeRendering
            font.pointSize: 72
            font.family: Theme.fontFamily

            Timer {
              running: true
              repeat: true
              interval: 1000

              onTriggered: clock.date = new Date();
            }

            text: {
              const hours = clock.date.getHours().toString().padStart(2, '0');
              const minutes = clock.date.getMinutes().toString().padStart(2, '0');
              return hours + ":" + minutes;
            }
          }

          ColumnLayout {
            id: bottomBlock
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: surf.contentShown ? implicitHeight : 0
            spacing: 8
            clip: true
            opacity: surf.contentShown ? 1 : 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            TextField {
              id: passwordBox
              Layout.alignment: Qt.AlignHCenter

              implicitWidth: 260
              padding: 10

              color: Theme.fg
              font.pixelSize: 14
              font.family: Theme.fontFamily
              selectedTextColor: Theme.bg
              selectionColor: Theme.fg

              background: Rectangle {
                color: Theme.bg
                border.color: lockContext.showFailure ? Theme.error : Theme.fg
                border.width: 1
              }

              focus: true
              enabled: !lockContext.unlockInProgress
              echoMode: TextInput.Password
              inputMethodHints: Qt.ImhSensitiveData

              onTextChanged: {
                lockContext.currentText = passwordBox.text
                surf.wake()
              }

              Keys.onPressed: surf.wake()

              onAccepted: {
                if (passwordBox.text !== "")
                  lockContext.tryUnlock()
              }

              Connections {
                target: lockContext

                function onCurrentTextChanged() {
                  passwordBox.text = lockContext.currentText;
                }
              }
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              Layout.fillWidth: true
              visible: lockContext.showFailure
              horizontalAlignment: Text.AlignHCenter

              text: "This Password is Incorrect"
              color: Theme.error
              font.pixelSize: 12
              font.family: Theme.fontFamily
            }
          }
        }

        Item {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 30
          opacity: surf.contentShown ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

          Bar {
            rightOnly: true
            menuOpen: surf.menuOpen
            onMenuRequested: section => surf.openMenu(section)
          }
        }

        Item {
          anchors.fill: parent
          anchors.topMargin: 30
          clip: true

          QsCard {
            id: lockMenu
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.rightMargin: 8
            width: 356
            height: Math.min(lockMenu.contentHeight + 28, 500)
            visible: lockMenu.open || lockMenu.sliding
            active: surf.menuOpen && surf.contentShown
            open: surf.menuOpen && surf.contentShown
            onActivity: surf.wake()
            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          }
        }

        Text {
          visible: graceActive
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          text: "Move your mouse or press any key to unlock"
          color: Theme.muted
          font.pixelSize: 13
          font.family: Theme.fontFamily
        }

        Timer {
          id: graceTimer
          interval: 5000
          onTriggered: {
            graceActive = false
            idleTimer.restart()
            passwordBox.forceActiveFocus()
          }
        }

        Timer {
          id: idleTimer
          interval: 10000
          onTriggered: surf.goIdle()
        }

        Connections {
          target: LockState
          function onLockedChanged() {
            if (LockState.locked) {
              graceActive = true
              surf.uiVisible = true
              surf.menuOpen = false
              passwordBox.text = ""
              lockContext.currentText = ""
              graceTimer.restart()
              idleTimer.stop()
            } else {
              graceActive = false
              passwordBox.text = ""
              lockContext.currentText = ""
              graceTimer.stop()
              idleTimer.stop()
            }
          }
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape && surf.menuOpen && !graceActive) {
            surf.menuOpen = false
            event.accepted = true
          } else if (graceActive) {
            LockState.locked = false
          } else {
            surf.wake()
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onPositionChanged: {
            if (graceActive)
              LockState.locked = false
            else
              surf.wake()
          }
          onPressed: function(mouse) {
            if (graceActive) {
              LockState.locked = false
            } else {
              surf.wake()
              mouse.accepted = false
            }
          }
        }
      }
    }
  }
}
