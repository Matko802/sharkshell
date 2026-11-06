import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Util.js" as Util

Item {
  id: page

  property var picker
  property int tab: 0
  readonly property bool isLock: tab === 1
  readonly property string fontFamily: Theme.fontFamily
  readonly property int browseRowH: 34
  readonly property int thumbSpacing: 6
  readonly property int visibleCount: 9

  Column {
    id: topCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 8
    spacing: 6

    Row {
      width: parent.width
      spacing: 6

      Rectangle {
        width: 30
        height: 26
        radius: Theme.rounding
        readonly property bool backEnabled: page.picker.navPos > 0
        color: backMa.containsMouse ? Theme.fg : "transparent"
        border.color: backEnabled ? Theme.outline : Theme.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: "<"
          color: backMa.containsMouse ? Theme.bg : (parent.backEnabled ? Theme.fg : Theme.muted3)
          font.family: page.fontFamily
          font.pixelSize: 13
          font.bold: true
        }
        MouseArea {
          id: backMa
          anchors.fill: parent
          enabled: parent.backEnabled
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.picker.navBack()
        }
      }
      Rectangle {
        width: 30
        height: 26
        radius: Theme.rounding
        readonly property bool fwdEnabled: page.picker.navPos < page.picker.navHistory.length - 1
        color: fwdMa.containsMouse ? Theme.fg : "transparent"
        border.color: fwdEnabled ? Theme.outline : Theme.border
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: ">"
          color: fwdMa.containsMouse ? Theme.bg : (parent.fwdEnabled ? Theme.fg : Theme.muted3)
          font.family: page.fontFamily
          font.pixelSize: 13
          font.bold: true
        }
        MouseArea {
          id: fwdMa
          anchors.fill: parent
          enabled: parent.fwdEnabled
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.picker.navFwd()
        }
      }
      Rectangle {
        width: 30
        height: 26
        radius: Theme.rounding
        color: homeMa.containsMouse ? Theme.fg : "transparent"
        border.color: Theme.outline
        border.width: 1
        QIcon { anchors.centerIn: parent; name: "home"; size: 16; color: homeMa.containsMouse ? Theme.bg : Theme.fg }
        MouseArea { id: homeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.picker.goHome() }
      }
    }

    Rectangle {
      width: parent.width
      height: 22
      color: page.picker.editingDir ? Theme.fg : "transparent"
      border.color: Theme.outline
      border.width: 1

      TextInput {
        id: dirInput
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        verticalAlignment: TextInput.AlignVCenter
        font.family: page.fontFamily
        font.pixelSize: 9
        color: page.picker.editingDir ? Theme.bg : Theme.fg
        text: page.picker.navDir
        readOnly: !page.picker.editingDir

        function open() {
          page.picker.editingDir = true
          text = page.picker.navDir
          forceActiveFocus()
          cursorPosition = text.length
        }

        function commit() {
          page.picker.editingDir = false
          page.picker.grabFocus()
          const next = text.trim().replace(/^~(?=\/|$)/, Quickshell.env("HOME") || "")
          if (next !== "" && next !== page.picker.navDir) {
            page.picker.navigate(next)
          } else {
            text = page.picker.navDir
          }
        }

        Keys.onReturnPressed: commit()
        Keys.onEnterPressed: commit()
        Keys.onEscapePressed: {
          page.picker.editingDir = false
          text = page.picker.navDir
          page.picker.grabFocus()
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: !page.picker.editingDir
        cursorShape: Qt.PointingHandCursor
        onClicked: dirInput.open()
      }
    }

    ListView {
      id: folderView
      width: parent.width
      visible: page.picker.folderResults.length > 0
      height: visible ? Math.min(page.visibleCount, page.picker.folderResults.length) * (page.browseRowH + page.thumbSpacing) : 0
      clip: true
      spacing: page.thumbSpacing
      model: page.picker.folderResults
      highlightMoveDuration: 120
      highlightMoveVelocity: -1

      delegate: Rectangle {
        required property var modelData
        required property int index
        width: folderView.width
        height: page.browseRowH
        color: page.picker.browseSel === index ? Theme.fg : (folderMa.containsMouse ? Theme.hover : "transparent")

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 10
          Item {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            QIcon {
              anchors.centerIn: parent
              name: "folder"
              size: 20
              color: page.picker.browseSel === index ? Theme.bg : Theme.fg
            }
          }
          Text {
            Layout.fillWidth: true
            text: modelData.name
            color: page.picker.browseSel === index ? Theme.bg : Theme.fg
            font.family: page.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: folderMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { page.picker.browseSel = index; page.picker.descend(index) }
        }
      }
    }

    Text {
      visible: page.picker.filterText !== "" && !page.picker.editingDir
      width: parent.width
      text: "filter: " + page.picker.filterText
      color: Theme.fg
      opacity: 0.6
      font.family: page.fontFamily
      font.pixelSize: 10
      elide: Text.ElideRight
    }
  }

  GridView {
    id: navGrid
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: topCol.bottom
    anchors.topMargin: 6
    anchors.bottom: bottomCol.top
    anchors.bottomMargin: 6
    clip: true
    cellWidth: width
    cellHeight: 118
    model: page.picker.imageResults
    interactive: true

    delegate: Item {
      required property var modelData
      required property int index
      width: navGrid.cellWidth
      height: navGrid.cellHeight

      Image {
        anchors.fill: parent
        anchors.margins: 3
        source: Util.fileUrl(modelData.thumbnailPath)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        color: modelData.filePath === page.picker.selectedImage ? Theme.hover : "transparent"
        border.width: gridMa.containsMouse ? 2 : (modelData.filePath === page.picker.selectedImage ? 2 : 0)
        border.color: Theme.outline
      }

      MouseArea {
        id: gridMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: page.picker.chooseImage(page.tab, index)
      }
    }

    Text {
      visible: page.picker.imageArray.length === 0
      anchors.centerIn: parent
      text: page.picker.loadingDirs ? "loading..." : "no images in this folder"
      color: Theme.muted
      font.family: page.fontFamily
      font.pointSize: 11
    }
  }

  Column {
    id: bottomCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 8
    spacing: 6

    Column {
      width: parent.width
      spacing: 4

      Row {
        width: parent.width
        spacing: 6
        Text {
          width: 12
          text: "X"
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
        }
        CSlider {
          width: parent.width - 44
          anchors.verticalCenter: parent.verticalCenter
          value: page.isLock ? WallpaperState.lockPositionX : WallpaperState.positionX
          onUserSet: v => page.picker.setPosFor(page.tab, v, page.isLock ? WallpaperState.lockPositionY : WallpaperState.positionY)
        }
        Text {
          width: 26
          text: Math.round((page.isLock ? WallpaperState.lockPositionX : WallpaperState.positionX) * 100)
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
        }
      }

      Row {
        width: parent.width
        spacing: 6
        Text {
          width: 12
          text: "Y"
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
        }
        CSlider {
          width: parent.width - 44
          anchors.verticalCenter: parent.verticalCenter
          value: page.isLock ? WallpaperState.lockPositionY : WallpaperState.positionY
          onUserSet: v => page.picker.setPosFor(page.tab, page.isLock ? WallpaperState.lockPositionX : WallpaperState.positionX, v)
        }
        Text {
          width: 26
          text: Math.round((page.isLock ? WallpaperState.lockPositionY : WallpaperState.positionY) * 100)
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    Item {
      visible: page.isLock && WallpaperState.lockPath !== ""
      width: parent.width
      height: 26

      Rectangle {
        anchors.centerIn: parent
        width: 130
        height: 24
        radius: Theme.rounding
        color: useDesktopMa.containsMouse ? Theme.fg : "transparent"
        border.color: Theme.outline
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "Use desktop"
          color: useDesktopMa.containsMouse ? Theme.bg : Theme.fg
          font.family: page.fontFamily
          font.pixelSize: 11
        }

        MouseArea {
          id: useDesktopMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperState.clearLock()
            page.picker.selectedImage = WallpaperState.effectiveLockPath
          }
        }
      }
    }
  }
}
