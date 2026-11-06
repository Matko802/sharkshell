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
  readonly property real posX: isLock ? WallpaperState.lockPositionX : WallpaperState.positionX
  readonly property real posY: isLock ? WallpaperState.lockPositionY : WallpaperState.positionY
  readonly property bool xCentered: Math.abs(page.posX - 0.5) < 0.001
  readonly property bool yCentered: Math.abs(page.posY - 0.5) < 0.001
  readonly property string fontFamily: Theme.fontFamily

  GridView {
    id: navGrid
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
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

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        opacity: 0.55
        gradient: Gradient {
          orientation: Gradient.Horizontal
          stops: [
            GradientStop { position: 0.0; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0) },
            GradientStop { position: 0.12; color: Theme.border },
            GradientStop { position: 0.88; color: Theme.border },
            GradientStop { position: 1.0; color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0) }
          ]
        }
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
        visible: !page.xCentered || ControlState.sliderDrags > 0
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
          value: page.posX
          onUserSet: v => page.picker.setPosFor(page.tab, v, page.posY)
        }
        Text {
          width: 26
          text: Math.round(page.posX * 100)
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
        }
      }

      Row {
        visible: !page.yCentered || ControlState.sliderDrags > 0
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
          value: page.posY
          onUserSet: v => page.picker.setPosFor(page.tab, page.posX, v)
        }
        Text {
          width: 26
          text: Math.round(page.posY * 100)
          color: Theme.fg
          opacity: 0.6
          font.family: page.fontFamily
          font.pixelSize: 10
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
