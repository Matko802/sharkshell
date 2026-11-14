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
  readonly property string fontFamily: Theme.fontFamily

  GridView {
    id: navGrid
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
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
        property bool dragStarted: false
        property point pressPos
        onPressed: mouse => {
          dragStarted = false
          pressPos = Qt.point(mouse.x, mouse.y)
        }
        onPositionChanged: mouse => {
          if (!pressed || dragStarted)
            return
          if (Math.abs(mouse.x - pressPos.x) > 6 || Math.abs(mouse.y - pressPos.y) > 6) {
            dragStarted = true
            page.picker.startPanDrag(page.tab, index, gridMa.mapToItem(null, mouse.x, mouse.y))
          }
        }
        onReleased: mouse => {
          if (dragStarted) {
            page.picker.endPanDrag()
          } else {
            page.picker.chooseImage(page.tab, index)
          }
        }
        onCanceled: page.picker.endPanDrag()
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

}
