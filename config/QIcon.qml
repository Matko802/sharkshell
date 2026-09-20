import QtQuick
import "Material.js" as Material

Item {
  id: root

  property string name: ""
  property color color: Theme.fg
  property int size: 16

  implicitWidth: size
  implicitHeight: size

  readonly property real dy: {
    if (root.name === "wifi-none" || root.name === "wifi-weak") return -0.25 * root.size
    if (root.name === "wifi-ok") return -0.08 * root.size
    if (root.name === "wifi-good" || root.name === "wifi-excellent") return 0.08 * root.size
    if (root.name === "wifi-off") return 0.07 * root.size
    return 0
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.dy
    text: Material.resolve(root.name)
    color: root.color
    font.family: Theme.materialFontFamily
    font.pixelSize: root.size
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
  }
}
